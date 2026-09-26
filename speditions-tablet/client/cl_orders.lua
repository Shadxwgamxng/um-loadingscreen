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
local CANCEL_GRACE_MS = 1500 -- Schonfrist, bevor die Abstandsprüfung greift (Szenario-Einstiegsanimation kann den Ped kurz verschieben)

local myHasDriverActions = false
local myOrders = {}
local busy = false
local locations = {}
local locationsLoaded = false

local function inTable(list, value)
    if type(list) ~= 'table' then return false end
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

local function refreshMyOrders()
    ServerCall('driver:myOrders', nil, function(res)
        myOrders = (res and res.ok and res.result and res.result.orders) or {}
    end)
end

--- Orte kommen seit der Umstellung auf st_locations (Reiter "Orte") nicht
--- mehr aus der statischen Config.Locations, sondern werden vom Server
--- geladen und bei Änderungen (Ort angelegt/bearbeitet/gelöscht) automatisch
--- aktualisiert (siehe 'locations:changed'-Broadcast unten).
--- WICHTIG: 'locations:list' verlangt eine aktive Tablet-Anmeldung
--- (Employees.RequireRole) - beim allerersten Aufruf direkt nach
--- Ressourcenstart ist noch niemand angemeldet, der Aufruf schlägt also so
--- gut wie immer fehl. locationsLoaded sorgt dafür, dass der Poll-Loop
--- unten es alle 3s erneut versucht, bis es einmal geklappt hat - sonst
--- blieb `locations` für die gesamte Spielsitzung leer und damit jeder
--- Bodenmarker/Wegpunkt komplett aus, sobald der Fahrer sich erst NACH
--- diesem einen fehlgeschlagenen Versuch einloggt (der Normalfall).
local function refreshLocations()
    ServerCall('locations:list', nil, function(res)
        if res and res.ok and res.result then
            locations = res.result.locations or {}
            locationsLoaded = true
        end
    end)
end

CreateThread(function()
    refreshLocations()
end)

RegisterNetEvent('speditions-tablet:client:push', function(event, _data)
    if event == 'locations:changed' then
        refreshLocations()
    end
end)

--- Baut einmal pro Marker-Tick eine Standortname -> {Auftrag, Phase}-Tabelle
--- aus myOrders. Der Marker-Loop unten prüft das pro Ressourcen-Tick gegen
--- JEDEN Ort (bei GF-weise frei erweiterbarer Ortsliste potenziell viele) -
--- eine vorab gebaute Lookup-Tabelle macht das zu einem O(1)-Zugriff pro Ort
--- statt bei jedem Ort erneut die komplette (kurze, aber trotzdem bei jedem
--- der ggf. vielen Orte wiederholte) Auftragsliste zu durchsuchen.
local function buildRelevantOrderIndex()
    local index = {}
    for _, o in ipairs(myOrders) do
        if o.status == 'anfahrt' then
            index[o.start_location] = { o, 'pickup' }
        elseif o.status == 'beladen' then
            index[o.end_location] = { o, 'dropoff' }
        end
    end
    return index
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

--- Der eigentliche Be-/Entlade-Ablauf (läuft geschützt in Orders.startLoadUnload
--- per pcall, damit ein unerwarteter Fehler NIE den Fahrer dauerhaft in
--- "busy" hängen lässt).
local function runLoadUnload(order, phase, markerCoords)
    local playerPed = PlayerPedId()
    local duration = (Config.LoadUnloadSeconds or 150) * 1000
    local startedAt = GetGameTimer()
    local cancelled = false

    ClearPedTasksImmediately(playerPed)
    TaskStartScenarioInPlace(playerPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)

    while GetGameTimer() - startedAt < duration do
        Wait(0)
        DisableControlAction(0, 30, true) -- Bewegen
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 21, true) -- Sprinten
        DisableControlAction(0, 22, true) -- Springen
        DisableControlAction(0, 23, true) -- Fahrzeug betreten
        DisableControlAction(0, 75, true) -- Fahrzeug verlassen

        local elapsed = GetGameTimer() - startedAt

        -- Erst nach der Schonfrist prüfen, ob der Spieler zu weit weg ist -
        -- die Szenario-Einstiegsanimation kann den Ped im allerersten Moment
        -- kurz verschieben, was sonst einen sofortigen Fehlabbruch auslöst.
        if elapsed > CANCEL_GRACE_MS and #(GetEntityCoords(playerPed) - markerCoords) > 5.0 then
            cancelled = true
            break
        end

        local pct = math.floor((elapsed / duration) * 100)
        local secondsLeft = math.max(0, math.ceil((duration - elapsed) / 1000))
        drawProgressBar(phase == 'pickup' and 'Wird beladen' or 'Wird entladen', pct, secondsLeft)
    end

    ClearPedTasksImmediately(playerPed)

    if cancelled then
        TriggerEvent('speditions-tablet:client:notify', 'Vorgang abgebrochen - zu weit vom Standort entfernt.', 'error')
        return
    end

    if phase == 'pickup' then
        -- "beladen" ist der durchgehende Status waehrend der Fahrt zum
        -- Zielort - kein zweiter Zwischenschritt mehr noetig.
        ServerCall('driver:updateCargoStatus', { orderId = order.id, status = 'beladen' }, function()
            refreshMyOrders()
        end)
    else
        ServerCall('driver:updateCargoStatus', { orderId = order.id, status = 'entladen' }, function(res)
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

--- Startet das Be-/Entladen und garantiert dabei, dass "busy" IMMER wieder
--- freigegeben wird - auch wenn irgendwo ein unerwarteter Fehler auftritt
--- (sonst würde der Fahrer bei einem Bug dauerhaft "hängen" bleiben, ohne
--- dass je wieder ein Marker/Fortschrittsbalken erscheint).
local function startLoadUnload(order, phase, markerCoords)
    busy = true
    local ok, err = pcall(runLoadUnload, order, phase, markerCoords)
    busy = false
    if not ok then
        print(('^1[speditions-tablet]^7 Fehler beim Be-/Entladen: %s'):format(tostring(err)))
        TriggerEvent('speditions-tablet:client:notify', 'Beim Be-/Entladen ist ein Fehler aufgetreten - bitte erneut versuchen.', 'error')
    end
end

CreateThread(function()
    while true do
        Wait(3000)
        ServerCall('session:whoami', nil, function(res)
            myHasDriverActions = (res and res.ok and res.result and res.result.loggedIn)
                and inTable(res.result.permissions, 'driver_actions') or false
        end)
        if myHasDriverActions then
            refreshMyOrders()
            if not locationsLoaded then refreshLocations() end
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

        if myHasDriverActions and not busy and #myOrders > 0 then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local relevantOrders = buildRelevantOrderIndex()

            for _, loc in ipairs(locations) do
                local relevant = relevantOrders[loc.name]
                if relevant then
                    local order, phase = relevant[1], relevant[2]
                    local markerCoords = vector3(loc.coords.x, loc.coords.y, loc.coords.z)
                    local dist = #(playerCoords - markerCoords)

                    if dist <= (Config.LocationMarkerRadius or 60.0) then
                        sleep = 0
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
