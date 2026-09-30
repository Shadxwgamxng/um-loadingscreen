-- =========================================================
-- Fehler-Konsole (Reiter "Konsole", Berechtigung console_view)
--
-- Sammelt Fehler, die im EIGENEN Code auftreten, in einem Ringpuffer im
-- Arbeitsspeicher - überlebt bewusst KEINEN Ressourcen-Neustart (kein
-- DB-Schema nötig, und bei den meisten relevanten Bugs startet die
-- Ressource ohnehin neu). WICHTIG: FiveM isoliert jede Ressource in einer
-- eigenen Lua-Umgebung - print()-Ausgaben ANDERER Ressourcen (z.B.
-- oxmysql selbst, siehe der "Unknown column 'NaN'"-Bug) sind von hier aus
-- NICHT einsehbar und können technisch nicht mitgelesen werden. Diese
-- Konsole deckt deshalb ab, was der eigene Code selbst als Fehler erkennt:
--   - jeder RPC-Fehler, den server/sv_rpc.lua ohnehin schon in die
--     Server-Konsole druckt (außer dem erwarteten "not_logged_in")
--   - jeder Fehler, den eine DB-Abfrage TATSÄCHLICH als Lua-Fehler wirft
--     (siehe wrapAwait unten - manche oxmysql-Fehler werden nur intern
--     geloggt und nie als Lua-Fehler geworfen, DIE kann auch dieser
--     Wrapper nicht erkennen)
--   - Client-Fehler, die client-seitig per pcall abgefangen und über
--     console:clientError gemeldet werden
-- =========================================================

Console = {}

local MAX_ENTRIES = 300
local entries = {}
local nextId = 1

--- kind: 'rpc_error' | 'db_error' | 'client_error'
function Console.Log(kind, message, context)
    entries[#entries + 1] = {
        id = nextId,
        at = Utils.Now(),
        kind = kind,
        message = tostring(message),
        context = context,
    }
    nextId = nextId + 1
    if #entries > MAX_ENTRIES then
        table.remove(entries, 1)
    end
end

function Console.List()
    return entries
end

RPC.Register('console:list', function(src)
    Employees.RequirePermission(src, 'console_view')
    -- Version direkt mitschicken (aus fxmanifest.lua) - damit im Tablet
    -- selbst nachprüfbar ist, welcher Skript-Stand auf dem Server tatsächlich
    -- läuft, ohne dass dafür Server-/Konsolenzugriff nötig ist (z.B. um nach
    -- einem Update-Versuch zu bestätigen, dass der neue Code wirklich aktiv
    -- ist, statt nur zu vermuten).
    local version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)
    return { entries = Console.List(), version = version }
end)

RPC.Register('console:clientError', function(src, payload)
    local emp = Employees.GetLoggedIn(src)
    local name = emp and emp.name or ('Spieler ' .. tostring(src))
    Console.Log('client_error', Utils.SanitizeString(payload and payload.message, 2000) or 'Unbekannter Client-Fehler', name)
end)

-- ---------------------------------------------------------
-- DB-Fehler abfangen: MySQL.<x>.await wird so gewrappt, dass ein
-- tatsächlich als Lua-Fehler geworfener Query-Fehler in der Konsole
-- landet, BEVOR er ganz normal weitergeworfen wird - das bestehende
-- Verhalten für alle Aufrufer im Rest des Codes bleibt unverändert.
-- ---------------------------------------------------------
local function wrapAwait(fnTable, methodName)
    local original = fnTable[methodName]
    fnTable[methodName] = function(query, params)
        local ok, resultOrErr = pcall(original, query, params)
        if not ok then
            Console.Log('db_error', resultOrErr, query)
            error(resultOrErr, 0)
        end
        return resultOrErr
    end
end

if MySQL then
    for _, name in ipairs({ 'single', 'scalar', 'query', 'insert', 'update' }) do
        if MySQL[name] and MySQL[name].await then
            wrapAwait(MySQL[name], 'await')
        end
    end
end
