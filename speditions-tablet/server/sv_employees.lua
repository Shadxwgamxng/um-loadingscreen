-- =========================================================
-- Mitarbeiterverwaltung (nur Geschäftsführung)
-- Ergänzt das globale `Employees`-Modul aus sv_bootstrap.lua.
-- Kein Login mehr: ein Mitarbeiter wird immer anhand des FiveM-Charakters
-- eines gerade ONLINEN Spielers angelegt (Utils.GetIdentifier).
-- =========================================================

local VALID_ROLES = { 'fahrer', 'disponent', 'geschaeftsfuehrung' }

function Employees.List()
    return MySQL.query.await([[
        SELECT e.id, e.name, e.role, e.status, e.hired_at,
               d.id AS driver_id, d.current_status AS driver_current_status
        FROM st_employees e
        LEFT JOIN st_drivers d ON d.employee_id = e.id
        ORDER BY FIELD(e.role, 'geschaeftsfuehrung', 'disponent', 'fahrer'), e.name ASC
    ]])
end

local function countActiveGf(excludeId)
    local row = MySQL.single.await(
        "SELECT COUNT(*) AS c FROM st_employees WHERE role = 'geschaeftsfuehrung' AND status = 'aktiv' AND id != ?",
        { excludeId or 0 }
    )
    return row and tonumber(row.c) or 0
end

--- Legt ein neues Mitarbeiterkonto für einen gerade ONLINEN Spieler an -
--- die Zuordnung läuft über dessen FiveM-Charakter (Utils.GetIdentifier),
--- kein Benutzername/Passwort mehr nötig.
function Employees.Hire(src, data)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })

    local targetId = Utils.SanitizeNumber(data.targetId, 1)
    local name = Utils.SanitizeString(data.name, 100)
    local role = data.role

    if not targetId or not name then error('missing_fields') end
    if not Utils.InTable(VALID_ROLES, role) then error('invalid_role') end
    if not GetPlayerName(targetId) then error('player_not_online') end

    local identifier = Utils.GetIdentifier(targetId)
    if not identifier then error('player_not_online') end

    local existing = MySQL.single.await('SELECT id FROM st_employees WHERE identifier = ? LIMIT 1', { identifier })
    if existing then error('employee_already_exists') end

    local employeeId = MySQL.insert.await(
        'INSERT INTO st_employees (identifier, name, role, status) VALUES (?, ?, ?, ?)',
        { identifier, name, role, 'aktiv' }
    )

    if role == Config.Roles.FAHRER then
        Drivers.EnsureDriverRecord(employeeId)
    end

    Logs.Write(emp.id, 'employee_hired', ('%s hat %s als "%s" eingestellt.'):format(emp.name, name, role))

    return { employeeId = employeeId }
end

function Employees.ChangeRole(src, employeeId, newRole)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    if not Utils.InTable(VALID_ROLES, newRole) then error('invalid_role') end

    local target = MySQL.single.await('SELECT * FROM st_employees WHERE id = ?', { employeeId })
    if not target then error('employee_not_found') end

    if target.role == Config.Roles.GESCHAEFTSFUEHRUNG and newRole ~= Config.Roles.GESCHAEFTSFUEHRUNG then
        if countActiveGf(employeeId) < 1 then error('last_management_account') end
    end

    MySQL.update.await('UPDATE st_employees SET role = ? WHERE id = ?', { newRole, employeeId })

    if newRole == Config.Roles.FAHRER then
        Drivers.EnsureDriverRecord(employeeId)
    end

    Employees.RefreshLoginById(employeeId)
    Logs.Write(emp.id, 'employee_role_change', ('%s hat die Rolle von %s auf "%s" geändert.'):format(emp.name, target.name, newRole))

    return { ok = true }
end

function Employees.SetStatus(src, employeeId, status)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    if not Utils.InTable({ 'aktiv', 'inaktiv' }, status) then error('invalid_status') end

    local target = MySQL.single.await('SELECT * FROM st_employees WHERE id = ?', { employeeId })
    if not target then error('employee_not_found') end

    if status == 'inaktiv' and target.role == Config.Roles.GESCHAEFTSFUEHRUNG then
        if countActiveGf(employeeId) < 1 then error('last_management_account') end
    end

    MySQL.update.await('UPDATE st_employees SET status = ? WHERE id = ?', { status, employeeId })
    Employees.RefreshLoginById(employeeId)
    Logs.Write(emp.id, 'employee_status_change', ('%s hat %s auf Status "%s" gesetzt.'):format(emp.name, target.name, status))

    return { ok = true }
end

-- =========================================================
-- RPC-Handler
-- =========================================================

RPC.Register('gf:employees:list', function(src)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    return { employees = Employees.List() }
end)

--- Liste aller aktuell online Spieler (Server-ID + Name), die noch KEIN
--- Mitarbeiterkonto haben - für das "Mitarbeiter einstellen"-Formular.
RPC.Register('gf:employees:onlinePlayers', function(src)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })

    local hired = {}
    for _, row in ipairs(MySQL.query.await('SELECT identifier FROM st_employees WHERE identifier IS NOT NULL')) do
        hired[row.identifier] = true
    end

    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        local identifier = Utils.GetIdentifier(id)
        if identifier and not hired[identifier] then
            players[#players + 1] = { serverId = id, name = GetPlayerName(id) }
        end
    end

    return { players = players }
end)

RPC.Register('gf:employees:hire', function(src, payload)
    return Employees.Hire(src, payload)
end)

RPC.Register('gf:employees:changeRole', function(src, payload)
    local employeeId = Utils.SanitizeNumber(payload.employeeId, 1)
    if not employeeId then error('invalid_payload') end
    return Employees.ChangeRole(src, employeeId, payload.role)
end)

RPC.Register('gf:employees:setStatus', function(src, payload)
    local employeeId = Utils.SanitizeNumber(payload.employeeId, 1)
    if not employeeId then error('invalid_payload') end
    return Employees.SetStatus(src, employeeId, payload.status)
end)

