-- =========================================================
-- Client: Be-/Entladepunkte
--
-- An jedem relevanten Standort (Beladepunkt eines "in Anfahrt"-Auftrags,
-- oder Zielort eines "beladen"-Auftrags) markiert ein Bodenkreis die
-- Interaktionsstelle - Taste E dort startet das Be-/Entladen (Zeitfenster +
-- Fortschrittsbalken, siehe Config.LoadUnloadSeconds). Danach läuft der
-- Auftragsstatus automatisch weiter (anfahrt -> beladen, bzw. beladen ->
-- entladen -> abgeschlossen) - keine manuellen Tablet-Buttons mehr dafür
-- nötig. Bewusst KEIN NPC (Pedestrian-KI war zu unzuverlässig/buggy) -
-- stattdessen ein reiner Bodenmarker ohne Entity.
-- =========================================================

local INTERACT_CONTROL = 51 -- INPUT_CONTEXT ("E")
local MARKER_TYPE = 1 -- Cylinder

local myRole = nil
local myOrders = {}
local busy = false
local lastDebugPrint = 0

local function refreshMyOrders()
    ServerCall('driver:myOrders', nil, function(res)
        myOrders = (res and res.ok and res.result and res.result.orders) or {}
    end)
end

--- Liefert den relevanten Auftrag (falls vorhanden) für einen Standort: ein
--- Auftrag "in Anfahrt", dessen Beladepunkt hier ist ("pickup"), oder ein
--- "beladen" (= beladen, zum Zielort unterwegs) befindlicher Auftrag,
--- dessen Zielort hier ist ("dropoff").
local function findRelevantOrder(locationName)
    for _, o in ipairs(myOrders) do
        if o.status == 'anfahrt' and o.start_location == locationName then
            return o, 'pickup'
        elseif o.status == 'beladen' and o.end_location == locationName then
            return o, 'dropoff'
        end
    end
    return nil
end

local function drawProgressBar(label, pct, secondsLeft)
    local x, y, w, h = 0.5, 0.88, 0.3, 0.045
    DrawRect(x, y, w, h, 0, 0, 0, 180)
    DrawRect(x - (w / 2) + (w * (pct / 100) / 2), y, w * (pct / 100), h, 59, 130, 246, 230)

    SetTextFont(4)
    SetTextScale(0.4, 0.4)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(('%s (%d%%) - noch %ds'):format(label, pct, secondsLeft))
    EndTextCommandDisplayText(x, y - 0.012)
end

--- Startet das Be-/Entladen: friert den Fahrer in einer Szenario-Animation
--- ein, zeigt Config.LoadUnloadSeconds lang einen Fortschrittsbalken, bricht
--- ab, wenn der Spieler zu weit vom Markierungskreis weggeht, und schaltet
--- danach automatisch den Auftragsstatus weiter.
local function startLoadUnload(order, phase, markerCoords)
    print(('^3[speditions-tablet debug]^7 startLoadUnload gestartet: orderId=%s phase=%s'):format(tostring(order.id), tostring(phase)))
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

        if #(GetEntityCoords(playerPed) - markerCoords) > 5.0 then
            cancelled = true
            break
        end

        local elapsed = GetGameTimer() - startedAt
        local pct = math.floor((elapsed / duration) * 100)
        local secondsLeft = math.max(0, math.ceil((duration - elapsed) / 1000))
        drawProgressBar(phase == 'pickup' and 'Wird beladen' or 'Wird entladen', pct, secondsLeft)
    end

    ClearPedTasksImmediately(playerPed)
    busy = false
    print(('^3[speditions-tablet debug]^7 startLoadUnload Schleife beendet: cancelled=%s'):format(tostring(cancelled)))

    if cancelled then
        TriggerEvent('speditions-tablet:client:notify', 'Vorgang abgebrochen - zu weit vom Standort entfernt.', 'error')
        return
    end

    if phase == 'pickup' then
        -- "beladen" ist der durchgehende Status waehrend der Fahrt zum
        -- Zielort - kein zweiter Zwischenschritt mehr noetig.
        ServerCall('driver:updateCargoStatus', { orderId = order.id, status = 'beladen' }, function(res)
            print(('^3[speditions-tablet debug]^7 updateCargoStatus(beladen) Antwort: ok=%s error=%s'):format(tostring(res and res.ok), tostring(res and res.error)))
            refreshMyOrders()
        end)
    else
        ServerCall('driver:updateCargoStatus', { orderId = order.id, status = 'entladen' }, function(res)
            print(('^3[speditions-tablet debug]^7 updateCargoStatus(entladen) Antwort: ok=%s error=%s'):format(tostring(res and res.ok), tostring(res and res.error)))
            if res and res.ok then
                ServerCall('driver:completeOrder', { orderId = order.id }, function()
                    refreshMyOrders()
                end)
            else
                refreshMyOrders()
            end
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

-- Marker-/Interaktions-Loop: zeichnet an Standorten, die gerade zu einem
-- aktiven Auftrag gehören, bei Nähe einen Bodenkreis, zeigt "Drücke E" bei
-- noch engerer Nähe und startet bei Tastendruck das Be-/Entladen.
CreateThread(function()
    while true do
        local sleep = 1000

        if myRole == Config.Roles.FAHRER and not busy and #myOrders > 0 then
            local playerCoords = GetEntityCoords(PlayerPedId())

            for _, loc in ipairs(Config.Locations) do
                local order, phase = findRelevantOrder(loc.name)
                if order then
                    local markerCoords = vector3(loc.coords.x, loc.coords.y, loc.coords.z)
                    local dist = #(playerCoords - markerCoords)

                    if dist <= (Config.LocationMarkerRadius or 60.0) then
                        sleep = 0

                        local now = GetGameTimer()
                        if now - lastDebugPrint > 2000 then
                            lastDebugPrint = now
                            print(('^3[speditions-tablet debug]^7 Standort "%s" (%s) dist=%.1fm interactRadius=%.1fm'):format(
                                loc.name, phase, dist, Config.LocationInteractRadius or 2.5
                            ))
                        end

                        DrawMarker(
                            MARKER_TYPE, loc.coords.x, loc.coords.y, loc.coords.z - 1.0,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 1.0,
                            30, 144, 255, 140, false, true, 2, false, nil, nil, false
                        )

                        if dist <= (Config.LocationInteractRadius or 2.5) then
                            BeginTextCommandDisplayHelp('STRING')
                            AddTextComponentSubstringPlayerName(('~INPUT_CONTEXT~ %s'):format(phase == 'pickup' and 'Fracht abholen' or 'Fracht abliefern'))
                            EndTextCommandDisplayHelp(0, false, true, -1)

                            if IsControlJustPressed(0, INTERACT_CONTROL) then
                                print('^3[speditions-tablet debug]^7 E gedrueckt - rufe startLoadUnload auf')
                                startLoadUnload(order, phase, markerCoords)
                            end
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
