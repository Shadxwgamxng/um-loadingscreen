-- =========================================================
-- Client: Be-/Entladepunkte
--
-- An jedem Config.Locations-Standort steht ein NPC. Hat ein Fahrer gerade
-- einen angenommenen Auftrag mit Beladepunkt hier, oder einen unterwegs
-- befindlichen Auftrag mit Zielort hier, kann er per Taste (E) mit dem NPC
-- interagieren - das startet das Be-/Entladen (Zeitfenster + Fortschrittsbalken,
-- siehe Config.LoadUnloadSeconds). Danach läuft der Auftragsstatus
-- automatisch weiter (angenommen -> beladen -> unterwegs, bzw. unterwegs ->
-- abgeschlossen) - keine manuellen Tablet-Buttons mehr dafür nötig.
-- =========================================================

local INTERACT_CONTROL = 51 -- INPUT_CONTEXT ("E")
local PED_MODEL = GetHashKey('a_m_m_business_01')

local myRole = nil
local myOrders = {}
local spawnedPeds = {} -- [locationName] = pedHandle
local busy = false

local function loadModel(model)
    if not IsModelValid(model) then return false end
    RequestModel(model)
    local tries = 0
    while not HasModelLoaded(model) and tries < 200 do
        Wait(10)
        tries = tries + 1
    end
    return HasModelLoaded(model)
end

local function spawnLocationPed(loc)
    if spawnedPeds[loc.name] then return end
    if not loadModel(PED_MODEL) then return end

    local ped = CreatePed(4, PED_MODEL, loc.coords.x, loc.coords.y, loc.coords.z - 1.0, loc.coords.w, false, false)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    TaskStartScenario(ped, 'WORLD_HUMAN_CLIPBOARD', 0.0, true)
    spawnedPeds[loc.name] = ped
end

local function despawnLocationPed(name)
    local ped = spawnedPeds[name]
    if ped then
        if DoesEntityExist(ped) then DeleteEntity(ped) end
        spawnedPeds[name] = nil
    end
end

local function refreshMyOrders()
    ServerCall('driver:myOrders', nil, function(res)
        myOrders = (res and res.ok and res.result and res.result.orders) or {}
    end)
end

--- Liefert den relevanten Auftrag (falls vorhanden) für einen Standort: ein
--- angenommener Auftrag, dessen Beladepunkt hier ist ("pickup"), oder ein
--- unterwegs befindlicher Auftrag, dessen Zielort hier ist ("dropoff").
local function findRelevantOrder(locationName)
    for _, o in ipairs(myOrders) do
        if o.status == 'angenommen' and o.start_location == locationName then
            return o, 'pickup'
        elseif o.status == 'unterwegs' and o.end_location == locationName then
            return o, 'dropoff'
        end
    end
    return nil
end

local function drawProgressBar(label, pct)
    local x, y, w, h = 0.5, 0.88, 0.25, 0.035
    DrawRect(x, y, w, h, 0, 0, 0, 160)
    DrawRect(x - (w / 2) + (w * (pct / 100) / 2), y, w * (pct / 100), h, 59, 130, 246, 220)

    SetTextFont(4)
    SetTextScale(0.34, 0.34)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(('%s... %d%%'):format(label, pct))
    EndTextCommandDisplayText(x, y - 0.022)
end

--- Startet das Be-/Entladen: friert den Fahrer in einer Szenario-Animation
--- ein, zeigt Config.LoadUnloadSeconds lang einen Fortschrittsbalken, bricht
--- ab, wenn der Spieler zu weit weggeht, und schaltet danach automatisch den
--- Auftragsstatus weiter.
local function startLoadUnload(order, phase, ped)
    busy = true
    local playerPed = PlayerPedId()
    local duration = (Config.LoadUnloadSeconds or 150) * 1000
    local startedAt = GetGameTimer()
    local cancelled = false

    ClearPedTasksImmediately(playerPed)
    TaskStartScenario(playerPed, 'WORLD_HUMAN_CLIPBOARD', 0.0, true)

    while GetGameTimer() - startedAt < duration do
        Wait(0)
        DisableControlAction(0, 30, true) -- Bewegen
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 21, true) -- Sprinten
        DisableControlAction(0, 22, true) -- Springen
        DisableControlAction(0, 23, true) -- Fahrzeug betreten
        DisableControlAction(0, 75, true) -- Fahrzeug verlassen

        if DoesEntityExist(ped) and #(GetEntityCoords(playerPed) - GetEntityCoords(ped)) > 5.0 then
            cancelled = true
            break
        end

        local pct = math.floor(((GetGameTimer() - startedAt) / duration) * 100)
        drawProgressBar(phase == 'pickup' and 'Wird beladen' or 'Wird entladen', pct)
    end

    ClearPedTasksImmediately(playerPed)
    busy = false

    if cancelled then
        TriggerEvent('speditions-tablet:client:notify', 'Vorgang abgebrochen - zu weit vom Standort entfernt.', 'error')
        return
    end

    if phase == 'pickup' then
        ServerCall('driver:updateCargoStatus', { orderId = order.id, status = 'beladen' }, function(res)
            if res and res.ok then
                ServerCall('driver:updateCargoStatus', { orderId = order.id, status = 'unterwegs' }, function()
                    refreshMyOrders()
                end)
            else
                refreshMyOrders()
            end
        end)
    else
        ServerCall('driver:completeOrder', { orderId = order.id }, function()
            refreshMyOrders()
        end)
    end
end

CreateThread(function()
    while true do
        Wait(3000)
        ServerCall('session:whoami', nil, function(res)
            myRole = (res and res.ok and res.result and res.result.loggedIn) and res.result.employee.role or nil
        end)
        if myRole == Config.Roles.FAHRER then
            refreshMyOrders()
        else
            myOrders = {}
        end
    end
end)

-- Spawn/Despawn-Loop (Performance: NPCs nur in der Nähe erzeugen).
CreateThread(function()
    while true do
        Wait(1500)
        local playerCoords = GetEntityCoords(PlayerPedId())
        for _, loc in ipairs(Config.Locations) do
            local dist = #(playerCoords - vector3(loc.coords.x, loc.coords.y, loc.coords.z))
            if dist <= (Config.LocationPedSpawnRadius or 60.0) then
                spawnLocationPed(loc)
            else
                despawnLocationPed(loc.name)
            end
        end
    end
end)

-- Interaktions-Loop: zeigt "Drücke E" an und startet bei Tastendruck das
-- Be-/Entladen, wenn der Fahrer gerade einen passenden Auftrag hat.
CreateThread(function()
    while true do
        local sleep = 500

        if myRole == Config.Roles.FAHRER and not busy then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local nearestName, nearestPed, nearestDist = nil, nil, (Config.LocationInteractRadius or 2.5)

            for name, ped in pairs(spawnedPeds) do
                if DoesEntityExist(ped) then
                    local d = #(playerCoords - GetEntityCoords(ped))
                    if d <= nearestDist then
                        nearestName, nearestPed, nearestDist = name, ped, d
                    end
                end
            end

            if nearestName then
                local order, phase = findRelevantOrder(nearestName)
                if order then
                    sleep = 0
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName(('~INPUT_CONTEXT~ %s'):format(phase == 'pickup' and 'Fracht abholen' or 'Fracht abliefern'))
                    EndTextCommandDisplayHelp(0, false, true, -1)

                    if IsControlJustPressed(0, INTERACT_CONTROL) then
                        startLoadUnload(order, phase, nearestPed)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for name in pairs(spawnedPeds) do
        despawnLocationPed(name)
    end
end)
