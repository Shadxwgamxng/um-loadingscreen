-- =========================================================
-- Zentraler RPC-Dispatcher zwischen NUI <-> Client <-> Server
--
-- Jede sicherheitsrelevante Aktion läuft über GENAU EINEN
-- Einstiegspunkt (RPC.Register). Der Client kann NIEMALS Werte
-- wie Auszahlungsbeträge oder "Auftrag abgeschlossen" selbst
-- setzen - jeder Handler validiert Rolle & Eingaben serverseitig
-- neu, unabhängig davon was die NUI geschickt hat.
-- =========================================================

RPC = {}
local Handlers = {}

--- Registriert einen RPC-Handler.
--- handler(src, payload) -> result (wird als JSON an die NUI zurückgegeben)
--- Der Handler kann `error('irgendein_code')` werfen, dies wird als
--- { ok = false, error = 'irgendein_code' } an die NUI zurückgegeben.
function RPC.Register(action, handler)
    if Handlers[action] then
        error(('[speditions-tablet] RPC-Action "%s" wurde bereits registriert'):format(action))
    end
    Handlers[action] = handler
end

RegisterNetEvent('speditions-tablet:server:rpc', function(action, payload, reqId)
    local src = source

    local handler = Handlers[action]
    if not handler then
        Utils.DebugPrint('Unbekannte RPC-Action:', action)
        TriggerClientEvent('speditions-tablet:client:rpcResponse', src, reqId, { ok = false, error = 'unknown_action' })
        return
    end

    local ok, resultOrErr = pcall(handler, src, payload or {})

    if ok then
        TriggerClientEvent('speditions-tablet:client:rpcResponse', src, reqId, { ok = true, result = resultOrErr })
    else
        local errMsg = tostring(resultOrErr)
        -- Nur den letzten Teil der Fehlermeldung (nach dem letzten ':') an den Client geben,
        -- interne Details/Stacktraces bleiben serverseitig in der Konsole.
        print(('^1[speditions-tablet]^7 RPC-Fehler in Action "%s" (source %s): %s'):format(action, src, errMsg))
        local shortCode = errMsg:match(':%d+:%s*(.+)$') or errMsg
        TriggerClientEvent('speditions-tablet:client:rpcResponse', src, reqId, { ok = false, error = shortCode })
    end
end)

--- Sendet eine asynchrone Push-Nachricht an einen bestimmten Spieler
--- (z.B. neuer Auftrag, neue Nachricht vom Disponenten).
function RPC.Push(targetSrc, event, data)
    TriggerClientEvent('speditions-tablet:client:push', targetSrc, event, data)
end

--- Sendet eine Push-Nachricht an alle aktuell verbundenen Mitarbeiter einer Rolle.
function RPC.PushToRole(role, event, data)
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local emp = Employees.GetLoggedIn(src)
        if emp and emp.role == role then
            RPC.Push(src, event, data)
        end
    end
end

function RPC.PushBroadcast(event, data)
    for _, playerId in ipairs(GetPlayers()) do
        RPC.Push(tonumber(playerId), event, data)
    end
end
