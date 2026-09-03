-- =========================================================
-- Mitarbeiterverwaltung (nur Geschäftsführung) + Passwort-Selbstverwaltung
-- Ergänzt das globale `Employees`-Modul aus sv_bootstrap.lua.
-- =========================================================

local VALID_ROLES = { 'fahrer', 'disponent', 'geschaeftsfuehrung' }

function Employees.List()
    return MySQL.query.await([[
        SELECT e.id, e.username, e.name, e.role, e.status, e.hired_at,
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

--- Legt ein neues Mitarbeiterkonto mit Zugangsdaten an. Die Zielperson muss
--- dafür NICHT online sein - Zugangsdaten werden außerhalb des Spiels
--- weitergegeben (Discord, TeamSpeak, ...).
function Employees.Hire(src, data)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })

    local username = Utils.SanitizeString(data.username, 50)
    local password = Utils.SanitizeString(data.password, 100)
    local name = Utils.SanitizeString(data.name, 100)
    local role = data.role

    if not username or not password or not name then error('missing_fields') end
    if #password < 4 then error('password_too_short') end
    if not Utils.InTable(VALID_ROLES, role) then error('invalid_role') end

    local existing = MySQL.single.await('SELECT id FROM st_employees WHERE username = ? LIMIT 1', { username })
    if existing then error('username_taken') end

    local employeeId = MySQL.insert.await(
        'INSERT INTO st_employees (username, name, role, status) VALUES (?, ?, ?, ?)',
        { username, name, role, 'aktiv' }
    )
    Employees.SetPassword(employeeId, password)

    if role == Config.Roles.FAHRER then
        Drivers.EnsureDriverRecord(employeeId)
    end

    Logs.Write(emp.id, 'employee_hired', ('%s hat %s (Benutzername "%s") als "%s" eingestellt.'):format(emp.name, name, username, role))

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

--- Geschäftsführung setzt das Passwort eines Mitarbeiters neu (z.B. vergessen).
function Employees.ResetPassword(src, employeeId, newPassword)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    newPassword = Utils.SanitizeString(newPassword, 100)
    if not newPassword or #newPassword < 4 then error('password_too_short') end

    local target = MySQL.single.await('SELECT * FROM st_employees WHERE id = ?', { employeeId })
    if not target then error('employee_not_found') end

    Employees.SetPassword(employeeId, newPassword)
    Employees.RefreshLoginById(employeeId)
    Logs.Write(emp.id, 'password_reset', ('%s hat das Passwort von %s zurückgesetzt.'):format(emp.name, target.name))

    return { ok = true }
end

--- Selbstständige Passwortänderung durch den angemeldeten Mitarbeiter selbst.
function Employees.ChangeOwnPassword(src, oldPassword, newPassword)
    local emp = Employees.RequireRole(src)
    oldPassword = Utils.SanitizeString(oldPassword, 100)
    newPassword = Utils.SanitizeString(newPassword, 100)
    if not oldPassword or not newPassword then error('missing_fields') end
    if #newPassword < 4 then error('password_too_short') end
    if not Employees.VerifyPassword(emp.id, oldPassword) then error('wrong_password') end

    Employees.SetPassword(emp.id, newPassword)
    Logs.Write(emp.id, 'password_change', ('%s hat sein Passwort geändert.'):format(emp.name))

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

RPC.Register('gf:employees:resetPassword', function(src, payload)
    local employeeId = Utils.SanitizeNumber(payload.employeeId, 1)
    if not employeeId then error('invalid_payload') end
    return Employees.ResetPassword(src, employeeId, payload.newPassword)
end)

RPC.Register('me:changePassword', function(src, payload)
    return Employees.ChangeOwnPassword(src, payload.oldPassword, payload.newPassword)
end)
