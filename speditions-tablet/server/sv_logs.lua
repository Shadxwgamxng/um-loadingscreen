-- =========================================================
-- Aktivitätsprotokoll
-- =========================================================

Logs = {}

--- Schreibt einen Eintrag ins Aktivitätsprotokoll.
---@param employeeId number|nil Mitarbeiter-ID des Ausführenden (nil = System)
---@param action string kurzer Aktions-Code, z.B. 'vehicle_create'
---@param details string menschlich lesbare Beschreibung
---
--- Läuft bewusst in einem EIGENEN Thread statt blockierend über
--- MySQL.insert.await direkt hier - Logs.Write wird aus zahlreichen
--- RPC-Handlern heraus aufgerufen (server/sv_rpc.lua führt jeden Handler
--- synchron per pcall aus und antwortet der NUI erst NACH dessen
--- Rückkehr). Hängt die DB-Verbindung kurz (Sperre, Netzwerk-Hänger),
--- würde ein blockierendes .await hier den kompletten aufrufenden RPC-
--- Handler mit auf unbestimmte Zeit lahmlegen - für den Nutzer sichtbar
--- als Aktion, die einfach nie eine Antwort/Rückmeldung bekommt (kein
--- Fehler, keine Konsolenausgabe, einfach nichts), obwohl das eigentliche
--- Feature (z.B. Funk beitreten) inhaltlich gar nichts mit dem Protokoll
--- zu tun hat. Das Protokoll selbst ist reine Nebensache (kein Aufrufer
--- wertet den Rückgabewert aus) und darf daher nie eine echte Funktion
--- blockieren.
function Logs.Write(employeeId, action, details)
    CreateThread(function()
        local ok, err = pcall(function()
            MySQL.insert.await(
                'INSERT INTO st_activity_logs (employee_id, action, details) VALUES (?, ?, ?)',
                { employeeId, action, details }
            )
        end)
        if not ok then
            print(('^1[speditions-tablet]^7 Logs.Write fehlgeschlagen (Action "%s"): %s'):format(action, tostring(err)))
        end
    end)
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
    Employees.RequirePermission(src, 'activity_log_view')
    local limit = Utils.SanitizeNumber(payload.limit, 1, 500) or 100
    return { entries = Logs.GetRecent(limit) }
end)
