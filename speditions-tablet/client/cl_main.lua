-- =========================================================
-- Client: NUI-Steuerung & RPC-Relay
-- =========================================================

local tabletOpen = false
local pendingRpc = {}
local rpcCounter = 0
local tabletPropEntity = nil

--- Hängt das konfigurierte Tablet-Prop an die Hand des Spielers, solange
--- das Tablet geöffnet ist (rein optisch, keine Animation/Bewegungssperre).
local function attachTabletProp()
    local cfg = Config.TabletProp
    if not (cfg and cfg.enabled) then return end

    local modelHash = GetHashKey(cfg.model)
    RequestModel(modelHash)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(modelHash) then
        print(('^1[speditions-tablet]^7 Tablet-Prop-Modell "%s" konnte nicht geladen werden.'):format(cfg.model))
        return
    end

    local ped = PlayerPedId()
    tabletPropEntity = CreateObject(modelHash, GetEntityCoords(ped), true, true, false)
    local off, rot = cfg.offset or {}, cfg.rotation or {}
    AttachEntityToEntity(
        tabletPropEntity, ped, GetPedBoneIndex(ped, cfg.bone or 28422),
        off.x or 0.0, off.y or 0.0, off.z or 0.0,
        rot.x or 0.0, rot.y or 0.0, rot.z or 0.0,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(modelHash)
end

local function removeTabletProp()
    if tabletPropEntity and DoesEntityExist(tabletPropEntity) then
        DeleteEntity(tabletPropEntity)
    end
    tabletPropEntity = nil
end

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
    attachTabletProp()
end

local function closeTablet()
    if not tabletOpen then return end
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
    removeTabletProp()
end

local itemRequired = Config.RequireItem and Config.RequireItem.enabled

if not itemRequired then
    RegisterCommand(Config.OpenCommand, function()
        if tabletOpen then
            closeTablet()
        else
            openTablet()
        end
    end, false)

    RegisterKeyMapping(Config.OpenCommand, 'Speditions-Tablet öffnen/schließen', 'keyboard', Config.OpenKey or 'F6')
end

--- Wird ausgelöst, wenn das konfigurierte Item benutzt wurde (siehe
--- server/sv_main.lua). Funktioniert unabhängig von Config.RequireItem,
--- damit andere Ressourcen das Tablet immer per Item öffnen können.
RegisterNetEvent('speditions-tablet:client:openFromItem', function()
    openTablet()
end)

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

--- Sicherheitsnetz: NUI-Fokus ist ein globaler, nicht ressourcen-gebundener
--- Spielzustand - bleibt er aus irgendeinem Grund (z.B. ein früherer,
--- inzwischen behobener Bug mit einem blockierenden JS-Dialog) hängen,
--- überlebt das sogar einen Ressourcen-Neustart und sperrt den Spieler
--- dauerhaft in der UI. Bei jedem Stopp dieser Ressource daher hart
--- zurücksetzen, unabhängig vom zuletzt bekannten tabletOpen-Zustand.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    removeTabletProp()
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

    if Config.NotificationSound then
        PlaySoundFrontend(-1, Config.NotificationSound.name, Config.NotificationSound.set, true)
    end
end)

RegisterNetEvent('speditions-tablet:client:waypoint', function(x, y, label)
    SetNewWaypoint(x + 0.0, y + 0.0)
    TriggerEvent('speditions-tablet:client:notify', ('Wegpunkt gesetzt: %s'):format(label or 'Ziel'), 'info')
end)
