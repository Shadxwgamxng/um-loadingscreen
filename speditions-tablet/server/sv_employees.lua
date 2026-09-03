-- =========================================================
-- Mitarbeiterverwaltung (nur Geschäftsführung)
-- Ergänzt das globale `Employees`-Modul aus sv_bootstrap.lua.
-- =========================================================

local VALID_ROLES = { 'fahrer', 'disponent', 'geschaeftsfuehrung' }

function Employees.List()
    return MySQL.query.await([[
        SELECT e.id, e.identifier, e.name, e.role, e.status, e.hired_at,
               d.id AS driver_id, d.current_status AS driver_current_status
        FROM st_employees e
        LEFT JOIN st_drivers d ON d.employee_id = e.id
        ORDER BY FIELD(e.role, 'geschaeftsfuehrung', 'disponent', 'fahrer'), e.name ASC
    ]])
end

--- Sucht den aktuell verbundenen Server-Slot für einen Mitarbeiter (falls online)
--- und aktualisiert dessen Session-Cache. Wird nach Rollen-/Statusänderungen
--- aufgerufen, damit Berechtigungsprüfungen sofort greifen.
function Employees.RefreshByIdentifier(identifier)
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if Utils.GetIdentifier(src) == identifier then
            Employees.Refresh(src)
            return src
        end
    end
    return nil
end

local function countActiveGf(excludeId)
    local row = MySQL.single.await(
        "SELECT COUNT(*) AS c FROM st_employees WHERE role = 'geschaeftsfuehrung' AND status = 'aktiv' AND id != ?",
        { excludeId or 0 }
    )
    return row and tonumber(row.c) or 0
end

--- Stellt einen neuen Mitarbeiter aus einem online befindlichen Spieler ein.
function Employees.Hire(src, targetServerId, role)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })

    if not Utils.InTable(VALID_ROLES, role) then error('invalid_role') end

    local identifier = Utils.GetIdentifier(targetServerId)
    if not identifier then error('target_not_found') end

    local existing = MySQL.single.await('SELECT id FROM st_employees WHERE identifier = ? LIMIT 1', { identifier })
    if existing then error('already_employee') end

    local name = Utils.GetPlayerName(targetServerId)
    local employeeId = MySQL.insert.await(
        'INSERT INTO st_employees (identifier, name, role, status) VALUES (?, ?, ?, ?)',
        { identifier, name, role, 'aktiv' }
    )

    if role == Config.Roles.FAHRER then
        Drivers.EnsureDriverRecord(employeeId)
    end

    Employees.RefreshByIdentifier(identifier)
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

    Employees.RefreshByIdentifier(target.identifier)
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
    Employees.RefreshByIdentifier(target.identifier)
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

RPC.Register('gf:employees:hire', function(src, payload)
    local targetServerId = Utils.SanitizeNumber(payload.serverId, 1)
    if not targetServerId then error('invalid_payload') end
    return Employees.Hire(src, targetServerId, payload.role)
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
