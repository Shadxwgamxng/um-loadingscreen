-- =========================================================
-- Rollen & Berechtigungen
--
-- Jede Rolle - die drei mitgelieferten Basisrollen (Fahrer/Disponent/
-- Geschäftsführung, Rollenschlüssel fix) ebenso wie alles, was die
-- Geschäftsführung im Tablet unter "Rollen" selbst anlegt - besteht aus
-- einem eindeutigen Rollenschlüssel und einer Menge von
-- Berechtigungsschlüsseln aus Config.Permissions. `Employees.RequirePermission`
-- (server/sv_bootstrap.lua) prüft ausschließlich gegen diese Tabelle -
-- Config.Roles.* dient nur noch als Bezeichner für die drei mitgelieferten
-- Basisrollen (Fahrerakten-Anlage, Config.InitialAccounts, tablet_grant-
-- Kurzform), nicht mehr als eigene Berechtigungsquelle.
--
-- Der Rollen-Cache wird beim ersten Zugriff (nicht in einem eigenen
-- CreateThread) geladen/erstbefüllt - das vermeidet jede Ladereihenfolge-
-- Abhängigkeit zu server/sv_bootstrap.lua (dessen Konten-Ersteinrichtung
-- ebenfalls in einem eigenen, asynchronen CreateThread läuft und schon
-- beim allerersten Login wissen muss, ob z.B. "fahrer" die Berechtigung
-- "driver_actions" hat).
-- =========================================================

Roles = {}

local cache = nil -- role_key -> { id, key, label, permissions = { [permKey]=true }, isBuiltin } | nil = noch nicht geladen

local function decodePermissions(jsonText)
    local perms = {}
    local ok, decoded = pcall(json.decode, jsonText or '[]')
    if ok and type(decoded) == 'table' then
        for _, p in ipairs(decoded) do
            perms[p] = true
        end
    end
    return perms
end

local function reload()
    local rows = MySQL.query.await('SELECT * FROM st_roles ORDER BY id ASC')
    local fresh = {}
    for _, row in ipairs(rows) do
        fresh[row.role_key] = {
            id = row.id,
            key = row.role_key,
            label = row.label,
            permissions = decodePermissions(row.permissions),
            isBuiltin = Utils.ToBool(row.is_builtin),
        }
    end
    cache = fresh
end

--- Erstbefüllung der drei mitgelieferten Basisrollen aus
--- Config.DefaultRolePermissions, falls sie noch nicht existieren (z.B.
--- Bestandsinstallationen nach sql/upgrade_v10.sql). ON DUPLICATE KEY
--- macht das race-sicher, falls zwei Aufrufer gleichzeitig zum ersten Mal
--- laden.
local function seedBuiltinRoles()
    for roleKey, label in pairs(Config.RoleLabels) do
        local perms = Config.DefaultRolePermissions[roleKey] or {}
        MySQL.insert.await(
            'INSERT INTO st_roles (role_key, label, permissions, is_builtin) VALUES (?, ?, ?, 1) ON DUPLICATE KEY UPDATE role_key = role_key',
            { roleKey, label, json.encode(perms) }
        )
    end
end

local function ensureLoaded()
    if cache then return end
    seedBuiltinRoles()
    reload()
end

--- Erzwingt ein Neuladen des Caches (nach Create/Update/Delete).
function Roles.Reload()
    reload()
end

--- Liste aller Rollen für die NUI (Rollenverwaltung + Rollen-Dropdown bei
--- der Mitarbeiterverwaltung).
function Roles.List()
    ensureLoaded()
    local out = {}
    for _, role in pairs(cache) do
        local perms = {}
        for permKey in pairs(role.permissions) do perms[#perms + 1] = permKey end
        table.sort(perms)
        out[#out + 1] = { id = role.id, key = role.key, label = role.label, permissions = perms, isBuiltin = role.isBuiltin }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Roles.Exists(roleKey)
    ensureLoaded()
    return cache[roleKey] ~= nil
end

function Roles.GetLabel(roleKey)
    ensureLoaded()
    local role = cache[roleKey]
    return role and role.label or roleKey
end

--- Prüft, ob eine Rolle eine bestimmte Berechtigung besitzt. Zentrale
--- Prüffunktion für Employees.RequirePermission und RPC.PushToPermission.
function Roles.HasPermission(roleKey, permissionKey)
    ensureLoaded()
    local role = cache[roleKey]
    return role ~= nil and role.permissions[permissionKey] == true
end

--- Zählt aktive Mitarbeiter, deren AKTUELLE Rolle die angegebene
--- Berechtigung besitzt (optional einen Mitarbeiter ausgenommen) -
--- verhindert, dass sich die Geschäftsführung versehentlich komplett
--- aussperrt (letztes Konto/letzte Rolle mit "employees_manage" bzw.
--- "roles_manage").
function Roles.CountActiveEmployeesWithPermission(permissionKey, excludeEmployeeId)
    ensureLoaded()
    local rows = MySQL.query.await("SELECT id, role FROM st_employees WHERE status = 'aktiv' AND id != ?", { excludeEmployeeId or 0 })
    local count = 0
    for _, row in ipairs(rows) do
        if Roles.HasPermission(row.role, permissionKey) then
            count = count + 1
        end
    end
    return count
end

local function validatePermissionKeys(list)
    if type(list) ~= 'table' then return nil end
    local valid = {}
    for _, p in ipairs(Config.Permissions) do valid[p.key] = true end
    local out, seen = {}, {}
    for _, key in ipairs(list) do
        if type(key) == 'string' and valid[key] and not seen[key] then
            seen[key] = true
            out[#out + 1] = key
        end
    end
    return out
end

local function slugify(label)
    local slug = (label or ''):lower()
    slug = slug:gsub('ä', 'ae'):gsub('ö', 'oe'):gsub('ü', 'ue'):gsub('ß', 'ss')
    slug = slug:gsub('[^a-z0-9]+', '_'):gsub('^_+', ''):gsub('_+$', '')
    if slug == '' then slug = 'rolle' end
    return slug
end

--- Legt eine neue, frei benannte Rolle mit einer Auswahl an Berechtigungen an.
function Roles.Create(src, label, permissionKeys)
    local emp = Employees.RequirePermission(src, 'roles_manage')
    ensureLoaded()

    label = Utils.SanitizeString(label, 100)
    if not label then error('missing_fields') end
    local permissions = validatePermissionKeys(permissionKeys)
    if not permissions or #permissions == 0 then error('missing_permissions') end

    local baseKey, key, suffix = slugify(label), nil, 2
    key = baseKey
    while cache[key] do
        key = baseKey .. '_' .. suffix
        suffix = suffix + 1
    end

    MySQL.insert.await(
        'INSERT INTO st_roles (role_key, label, permissions, is_builtin) VALUES (?, ?, ?, 0)',
        { key, label, json.encode(permissions) }
    )
    reload()
    RPC.PushBroadcast('roles:changed', {})
    Logs.Write(emp.id, 'role_created', ('%s hat die Rolle "%s" angelegt.'):format(emp.name, label))
    return { ok = true, key = key }
end

--- Bearbeitet Bezeichnung und/oder Berechtigungen einer bestehenden Rolle
--- (auch der drei Basisrollen - nur der Rollenschlüssel selbst bleibt fix).
--- Verweigert eine Änderung, die "roles_manage" aus der letzten Rolle
--- entfernen würde, der noch aktive Mitarbeiter zugeordnet sind (sonst
--- könnte sich die Geschäftsführung komplett aussperren).
function Roles.Update(src, roleKey, label, permissionKeys)
    local emp = Employees.RequirePermission(src, 'roles_manage')
    ensureLoaded()
    local role = cache[roleKey]
    if not role then error('role_not_found') end

    label = Utils.SanitizeString(label, 100) or role.label
    local permissions = validatePermissionKeys(permissionKeys)
    if not permissions or #permissions == 0 then error('missing_permissions') end

    local hadRolesManage = role.permissions['roles_manage'] == true
    local willHaveRolesManage = Utils.InTable(permissions, 'roles_manage')
    if hadRolesManage and not willHaveRolesManage then
        local otherRoleHasIt = false
        for key, r in pairs(cache) do
            if key ~= roleKey and r.permissions['roles_manage'] then otherRoleHasIt = true break end
        end
        if not otherRoleHasIt then
            local employeesOnThisRole = MySQL.single.await("SELECT COUNT(*) AS c FROM st_employees WHERE role = ? AND status = 'aktiv'", { roleKey })
            if employeesOnThisRole and tonumber(employeesOnThisRole.c) > 0 then
                error('last_roles_manage_role')
            end
        end
    end

    MySQL.update.await('UPDATE st_roles SET label = ?, permissions = ? WHERE role_key = ?', { label, json.encode(permissions), roleKey })
    reload()
    RPC.PushBroadcast('roles:changed', {})
    Logs.Write(emp.id, 'role_updated', ('%s hat die Rolle "%s" bearbeitet.'):format(emp.name, label))
    return { ok = true }
end

--- Löscht eine selbst angelegte Rolle. Die drei Basisrollen können nicht
--- gelöscht werden; ebenso wenig eine Rolle, der noch Mitarbeiter
--- zugeordnet sind (erst umverteilen, dann löschen).
function Roles.Delete(src, roleKey)
    local emp = Employees.RequirePermission(src, 'roles_manage')
    ensureLoaded()
    local role = cache[roleKey]
    if not role then error('role_not_found') end
    if role.isBuiltin then error('role_is_builtin') end

    local inUse = MySQL.single.await('SELECT COUNT(*) AS c FROM st_employees WHERE role = ?', { roleKey })
    if inUse and tonumber(inUse.c) > 0 then error('role_in_use') end

    MySQL.update.await('DELETE FROM st_roles WHERE role_key = ?', { roleKey })
    reload()
    RPC.PushBroadcast('roles:changed', {})
    Logs.Write(emp.id, 'role_deleted', ('%s hat die Rolle "%s" gelöscht.'):format(emp.name, role.label))
    return { ok = true }
end

-- =========================================================
-- RPC-Handler
-- =========================================================

--- Jeder angemeldete Mitarbeiter darf die Rollenliste (Labels +
--- Berechtigungen) sehen, z.B. für das Rollen-Dropdown bei "Mitarbeiter
--- einstellen" oder um die eigenen Berechtigungen clientseitig
--- auszuwerten (rein UI-seitig - serverseitig wird bei jeder Aktion
--- ohnehin erneut geprüft).
RPC.Register('roles:list', function(src)
    Employees.RequireRole(src)
    return { roles = Roles.List(), permissionCatalog = Config.Permissions }
end)

RPC.Register('gf:roles:create', function(src, payload)
    return Roles.Create(src, payload.label, payload.permissions)
end)

RPC.Register('gf:roles:update', function(src, payload)
    local roleKey = Utils.SanitizeString(payload.roleKey, 50)
    if not roleKey then error('invalid_payload') end
    return Roles.Update(src, roleKey, payload.label, payload.permissions)
end)

RPC.Register('gf:roles:delete', function(src, payload)
    local roleKey = Utils.SanitizeString(payload.roleKey, 50)
    if not roleKey then error('invalid_payload') end
    return Roles.Delete(src, roleKey)
end)
