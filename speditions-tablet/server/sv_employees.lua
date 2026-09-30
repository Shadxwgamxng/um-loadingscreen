-- =========================================================
-- Mitarbeiterverwaltung (nur Geschäftsführung)
-- Ergänzt das globale `Employees`-Modul aus sv_bootstrap.lua.
-- Ein neues Mitarbeiterkonto bekommt Name + Passwort direkt bei der
-- Einstellung - die Zielperson muss dafür NICHT online sein.
-- =========================================================

function Employees.List()
    return MySQL.query.await([[
        SELECT e.id, e.username, e.name, e.role, e.status, e.hired_at, e.discord_id,
               d.id AS driver_id, d.current_status AS driver_current_status
        FROM st_employees e
        LEFT JOIN st_drivers d ON d.employee_id = e.id
        ORDER BY FIELD(e.role, 'geschaeftsfuehrung', 'disponent', 'fahrer'), e.name ASC
    ]])
end

--- Legt ein neues Mitarbeiterkonto mit Login-Name + Passwort an - die
--- Zielperson muss dafür nicht online sein. `discordId` ist optional und
--- nur relevant für Config.Website (Website-Sync) - verknüpft das Konto mit
--- einem Discord-Nutzer, damit sich das zugehörige Website-Konto per
--- Discord-OAuth anmelden kann.
function Employees.Hire(src, data)
    local emp = Employees.RequirePermission(src, 'employees_manage')

    local username = Utils.SanitizeString(data.username, 50)
    local password = Utils.SanitizeString(data.password, 100)
    local name = Utils.SanitizeString(data.name, 100)
    local discordId = Utils.SanitizeString(data.discordId, 32)
    local role = data.role

    if not username or not password or not name then error('missing_fields') end
    if not Roles.Exists(role) then error('invalid_role') end

    local existing = MySQL.single.await('SELECT id FROM st_employees WHERE username = ? LIMIT 1', { username })
    if existing then error('employee_already_exists') end

    local employeeId = MySQL.insert.await(
        'INSERT INTO st_employees (username, name, role, status, discord_id) VALUES (?, ?, ?, ?, ?)',
        { username, name, role, 'aktiv', discordId }
    )
    Employees.SetPassword(employeeId, password)

    if Roles.HasPermission(role, 'driver_actions') then
        local driver = Drivers.EnsureDriverRecord(employeeId)
        Drivers.GrantPermissionsRaw(driver.id, data.driverPermissions)
    end

    Logs.Write(emp.id, 'employee_hired', ('%s hat %s ("%s") als "%s" eingestellt.'):format(emp.name, name, username, role))
    if WebsiteBridge then WebsiteBridge.PushEmployeeUpdate(employeeId) end

    return { employeeId = employeeId }
end

--- System-Variante von Employees.Hire für den Website-Sync (kein Spieler-
--- `src`, keine Berechtigungsprüfung - wird ausschließlich aus einem
--- bereits API-Key-geprüften Website-Befehl heraus aufgerufen, siehe
--- server/sv_website_bridge.lua). Die Website kennt nur ihre eigenen 9
--- festen Rollen, keine frei benannten Tablet-Rollen - deshalb wird über
--- Roles.FindTabletRoleForWebsiteKey die passende Tablet-Rolle gesucht;
--- ist die Zuordnung nicht eindeutig (keine oder mehrere Tablet-Rollen mit
--- dieser Website-Rolle), schlägt das Anlegen fehl, bis die
--- Geschäftsführung im Rollen-Editor für genau eine Tablet-Rolle diese
--- Website-Rolle einträgt.
function Employees.HireFromWebsite(username, password, name, websiteRoleKey, discordId, driverPermissions)
    username = Utils.SanitizeString(username, 50)
    password = Utils.SanitizeString(password, 100)
    name = Utils.SanitizeString(name, 100)
    discordId = Utils.SanitizeString(discordId, 32)

    if not username or not password or not name then error('missing_fields') end

    local roleKey, matchCount = Roles.FindTabletRoleForWebsiteKey(websiteRoleKey)
    if matchCount == 0 then error('no_tablet_role_mapped_to_website_role') end
    if matchCount > 1 then error('ambiguous_tablet_role_mapping') end

    local existing = MySQL.single.await('SELECT id FROM st_employees WHERE username = ? LIMIT 1', { username })
    if existing then error('employee_already_exists') end

    local employeeId = MySQL.insert.await(
        'INSERT INTO st_employees (username, name, role, status, discord_id) VALUES (?, ?, ?, ?, ?)',
        { username, name, roleKey, 'aktiv', discordId }
    )
    Employees.SetPassword(employeeId, password)

    if Roles.HasPermission(roleKey, 'driver_actions') then
        local driver = Drivers.EnsureDriverRecord(employeeId)
        Drivers.GrantPermissionsRaw(driver.id, driverPermissions)
    end

    Logs.Write(nil, 'employee_hired_website', ('Mitarbeiter %s ("%s") wurde von der Website aus als "%s" eingestellt.'):format(name, username, roleKey))
    if WebsiteBridge then WebsiteBridge.PushEmployeeUpdate(employeeId) end

    return { employeeId = employeeId }
end

--- Setzt das Passwort eines Mitarbeiters zurück (Geschäftsführung).
function Employees.ResetPassword(src, employeeId, newPassword)
    local emp = Employees.RequirePermission(src, 'employees_manage')
    newPassword = Utils.SanitizeString(newPassword, 100)
    if not newPassword then error('missing_fields') end

    local target = MySQL.single.await('SELECT * FROM st_employees WHERE id = ?', { employeeId })
    if not target then error('employee_not_found') end

    Employees.SetPassword(employeeId, newPassword)
    Employees.RefreshLoginById(employeeId)
    Logs.Write(emp.id, 'employee_password_reset', ('%s hat das Passwort von %s zurückgesetzt.'):format(emp.name, target.name))

    return { ok = true }
end

--- Ändert das eigene Passwort (jeder angemeldete Mitarbeiter).
function Employees.ChangeOwnPassword(src, currentPassword, newPassword)
    local emp = Employees.RequireRole(src)
    currentPassword = Utils.SanitizeString(currentPassword, 100)
    newPassword = Utils.SanitizeString(newPassword, 100)
    if not currentPassword or not newPassword then error('missing_fields') end

    if Employees.HashPassword(currentPassword, emp.password_salt) ~= emp.password_hash then
        error('invalid_credentials')
    end

    Employees.SetPassword(emp.id, newPassword)
    Employees.RefreshLoginById(emp.id)
    Logs.Write(emp.id, 'password_changed', ('%s hat das eigene Passwort geändert.'):format(emp.name))

    return { ok = true }
end

function Employees.ChangeRole(src, employeeId, newRole)
    local emp = Employees.RequirePermission(src, 'employees_manage')
    if not Roles.Exists(newRole) then error('invalid_role') end

    local target = MySQL.single.await('SELECT * FROM st_employees WHERE id = ?', { employeeId })
    if not target then error('employee_not_found') end

    -- Verhindert, dass sich die Geschäftsführung versehentlich komplett
    -- aussperrt: die letzte aktive Person mit "employees_manage" (i.d.R.
    -- Geschäftsführung) kann nicht in eine Rolle ohne diese Berechtigung
    -- verschoben werden, solange niemand sonst sie noch hat.
    if Roles.HasPermission(target.role, 'employees_manage') and not Roles.HasPermission(newRole, 'employees_manage') then
        if Roles.CountActiveEmployeesWithPermission('employees_manage', employeeId) < 1 then
            error('last_management_account')
        end
    end

    MySQL.update.await('UPDATE st_employees SET role = ? WHERE id = ?', { newRole, employeeId })

    if Roles.HasPermission(newRole, 'driver_actions') then
        Drivers.EnsureDriverRecord(employeeId)
    end

    Employees.RefreshLoginById(employeeId)
    Logs.Write(emp.id, 'employee_role_change', ('%s hat die Rolle von %s auf "%s" geändert.'):format(emp.name, target.name, Roles.GetLabel(newRole)))
    if WebsiteBridge then WebsiteBridge.PushEmployeeUpdate(employeeId) end

    return { ok = true }
end

function Employees.SetStatus(src, employeeId, status)
    local emp = Employees.RequirePermission(src, 'employees_manage')
    if not Utils.InTable({ 'aktiv', 'inaktiv' }, status) then error('invalid_status') end

    local target = MySQL.single.await('SELECT * FROM st_employees WHERE id = ?', { employeeId })
    if not target then error('employee_not_found') end

    if status == 'inaktiv' and Roles.HasPermission(target.role, 'employees_manage') then
        if Roles.CountActiveEmployeesWithPermission('employees_manage', employeeId) < 1 then
            error('last_management_account')
        end
    end

    MySQL.update.await('UPDATE st_employees SET status = ? WHERE id = ?', { status, employeeId })
    Employees.RefreshLoginById(employeeId)
    Logs.Write(emp.id, 'employee_status_change', ('%s hat %s auf Status "%s" gesetzt.'):format(emp.name, target.name, status))
    if WebsiteBridge then WebsiteBridge.PushEmployeeUpdate(employeeId) end

    return { ok = true }
end

--- System-Variante von Employees.SetStatus(..., 'inaktiv') für den Website-
--- Sync: wird aufgerufen, wenn auf der Website ein mit dem Tablet
--- verknüpftes Konto gelöscht wird (server/sv_website_bridge.lua, Befehl
--- deactivate_employee). Kein hartes SQL-Löschen im Tablet - würde
--- Auftrags-/Transaktions-/Log-Historie verwaisen lassen, die noch auf
--- diesen Mitarbeiter verweist; Deaktivieren ist im Tablet ohnehin die
--- etablierte "Entfernen"-Variante für Mitarbeiter (siehe Employees.SetStatus).
function Employees.DeactivateFromWebsite(employeeId)
    local target = MySQL.single.await('SELECT * FROM st_employees WHERE id = ?', { employeeId })
    if not target then error('employee_not_found') end
    if target.status == 'inaktiv' then return { ok = true } end

    if Roles.HasPermission(target.role, 'employees_manage') then
        if Roles.CountActiveEmployeesWithPermission('employees_manage', employeeId) < 1 then
            error('last_management_account')
        end
    end

    MySQL.update.await("UPDATE st_employees SET status = 'inaktiv' WHERE id = ?", { employeeId })
    Employees.RefreshLoginById(employeeId)
    Logs.Write(nil, 'employee_status_change', ('%s wurde deaktiviert (Konto auf der Website gelöscht).'):format(target.name))

    return { ok = true }
end

--- Setzt/ändert die Discord-Nutzer-ID eines Mitarbeiters (nur relevant für
--- Config.Website/Website-Sync - verknüpft das Konto für den
--- Discord-OAuth-Login auf der Website). Leerer String hebt die Verknüpfung
--- wieder auf.
function Employees.SetDiscordId(src, employeeId, discordId)
    local emp = Employees.RequirePermission(src, 'employees_manage')
    discordId = Utils.SanitizeString(discordId, 32)

    local target = MySQL.single.await('SELECT * FROM st_employees WHERE id = ?', { employeeId })
    if not target then error('employee_not_found') end

    MySQL.update.await('UPDATE st_employees SET discord_id = ? WHERE id = ?', { discordId, employeeId })
    Logs.Write(emp.id, 'employee_discord_link', ('%s hat die Discord-ID von %s aktualisiert.'):format(emp.name, target.name))
    if WebsiteBridge then WebsiteBridge.PushEmployeeUpdate(employeeId) end

    return { ok = true }
end

-- =========================================================
-- RPC-Handler
-- =========================================================

RPC.Register('gf:employees:list', function(src)
    Employees.RequirePermission(src, 'employees_manage')
    return { employees = Employees.List() }
end)

RPC.Register('gf:employees:hire', function(src, payload)
    return Employees.Hire(src, payload)
end)

RPC.Register('gf:employees:changeRole', function(src, payload)
    local employeeId = Utils.SanitizeNumber(payload.employeeId, 1)
    if not employeeId then error('invalid_payload') end
    return Employees.ChangeRole(src, employeeId, payload.role)
end)

RPC.Register('gf:employees:resetPassword', function(src, payload)
    local employeeId = Utils.SanitizeNumber(payload.employeeId, 1)
    if not employeeId then error('invalid_payload') end
    return Employees.ResetPassword(src, employeeId, payload.newPassword)
end)

RPC.Register('me:changePassword', function(src, payload)
    return Employees.ChangeOwnPassword(src, payload.currentPassword, payload.newPassword)
end)

RPC.Register('gf:employees:setStatus', function(src, payload)
    local employeeId = Utils.SanitizeNumber(payload.employeeId, 1)
    if not employeeId then error('invalid_payload') end
    return Employees.SetStatus(src, employeeId, payload.status)
end)

RPC.Register('gf:employees:setDiscordId', function(src, payload)
    local employeeId = Utils.SanitizeNumber(payload.employeeId, 1)
    if not employeeId then error('invalid_payload') end
    return Employees.SetDiscordId(src, employeeId, payload.discordId)
end)

