-- =========================================================
-- Aktivitätsprotokoll
-- =========================================================

Logs = {}

--- Schreibt einen Eintrag ins Aktivitätsprotokoll.
---@param employeeId number|nil Mitarbeiter-ID des Ausführenden (nil = System)
---@param action string kurzer Aktions-Code, z.B. 'vehicle_create'
---@param details string menschlich lesbare Beschreibung
function Logs.Write(employeeId, action, details)
    MySQL.insert.await(
        'INSERT INTO st_activity_logs (employee_id, action, details) VALUES (?, ?, ?)',
        { employeeId, action, details }
    )
    Utils.DebugPrint(('LOG [%s] %s'):format(action, details))
end

--- Liest die letzten Protokolleinträge (nur für Geschäftsführung, Prüfung erfolgt im RPC-Handler).
function Logs.GetRecent(limit)
    limit = tonumber(limit) or 100
    if limit > 500 then limit = 500 end
    return MySQL.query.await([[
        SELECT l.id, l.action, l.details, l.created_at,
               e.name AS employee_name, e.role AS employee_role
        FROM st_activity_logs l
        LEFT JOIN st_employees e ON e.id = l.employee_id
        ORDER BY l.created_at DESC, l.id DESC
        LIMIT ?
    ]], { limit })
end

RPC.Register('gf:activityLog', function(src, payload)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    local limit = Utils.SanitizeNumber(payload.limit, 1, 500) or 100
    return { entries = Logs.GetRecent(limit) }
end)
