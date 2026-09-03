-- =========================================================
-- Client: NUI-Steuerung & RPC-Relay
-- =========================================================

local tabletOpen = false
local pendingRpc = {}
local rpcCounter = 0

--- Ruft eine RPC-Action serverseitig auf - identischer Weg wie die NUI, aber
--- direkt aus Client-Lua nutzbar (z.B. für den Lenkzeit-Tracker, der auch
--- laufen muss, wenn das Tablet gar nicht geöffnet ist).
--- cb(response) erhält { ok = true, result = ... } oder { ok = false, error = ... }.
function ServerCall(action, payload, cb)
    rpcCounter = rpcCounter + 1
    local reqId = rpcCounter
    if cb then pendingRpc[reqId] = cb end
    TriggerServerEvent('speditions-tablet:server:rpc', action, payload, reqId)
end

local function openTablet()
    if tabletOpen then return end
    tabletOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'open', companyName = Config.CompanyName })
end

local function closeTablet()
    if not tabletOpen then return end
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
end

RegisterCommand(Config.OpenCommand, function()
    if tabletOpen then
        closeTablet()
    else
        openTablet()
    end
end, false)

RegisterKeyMapping(Config.OpenCommand, 'Speditions-Tablet öffnen/schließen', 'keyboard', Config.OpenKey or 'F6')

exports('OpenTablet', openTablet)
exports('CloseTablet', closeTablet)
exports('IsTabletOpen', function() return tabletOpen end)

-- ---------------------------------------------------------
-- NUI <-> Server RPC-Relay
-- Die NUI ruft ausschließlich den generischen 'rpc'-Callback auf,
-- der Client leitet die Anfrage 1:1 an den Server weiter und
-- routet die Antwort über die reqId wieder zurück an die NUI.
-- ---------------------------------------------------------

RegisterNUICallback('rpc', function(data, cb)
    ServerCall(data.action, data.payload, cb)
end)

RegisterNetEvent('speditions-tablet:client:rpcResponse', function(reqId, response)
    local cb = pendingRpc[reqId]
    if cb then
        cb(response)
        pendingRpc[reqId] = nil
    end
end)

RegisterNetEvent('speditions-tablet:client:push', function(event, data)
    if not tabletOpen then return end
    SendNUIMessage({ type = 'push', event = event, data = data })
end)

RegisterNUICallback('close', function(_, cb)
    closeTablet()
    cb('ok')
end)

-- ---------------------------------------------------------
-- Native In-Game-Hinweise & GPS-Wegpunkte
-- Funktionieren unabhängig davon, ob das Tablet gerade geöffnet ist.
-- ---------------------------------------------------------

RegisterNetEvent('speditions-tablet:client:notify', function(message, notifyType)
    local prefix = '~b~Speditions-Tablet~s~'
    if notifyType == 'error' then prefix = '~r~Speditions-Tablet~s~'
    elseif notifyType == 'warning' then prefix = '~y~Speditions-Tablet~s~'
    elseif notifyType == 'success' then prefix = '~g~Speditions-Tablet~s~' end

    SetNotificationTextEntry('STRING')
    AddTextComponentString(('%s\n%s'):format(prefix, message))
    DrawNotification(false, true)
end)

RegisterNetEvent('speditions-tablet:client:waypoint', function(x, y, label)
    SetNewWaypoint(x + 0.0, y + 0.0)
    TriggerEvent('speditions-tablet:client:notify', ('Wegpunkt gesetzt: %s'):format(label or 'Ziel'), 'info')
end)
