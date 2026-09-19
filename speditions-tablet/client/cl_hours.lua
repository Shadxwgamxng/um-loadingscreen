-- =========================================================
-- Client: Lenk-/Ruhezeiten-Tracker
--
-- Läuft unabhängig davon, ob das Tablet gerade GEÖFFNET ist - erfordert aber,
-- dass der Spieler-Charakter einem Mitarbeiterkonto mit der Berechtigung
-- "driver_actions" zugeordnet ist (NICHT an den festen Rollenschlüssel
-- "fahrer" gebunden - die Geschäftsführung kann im Reiter "Rollen" beliebige
-- eigene Rollen mit dieser Berechtigung anlegen, siehe server/sv_roles.lua).
-- Ein Fahrer "fährt" im Sinne des Systems nur, wenn ZWEI Dinge gleichzeitig
-- zutreffen: die Fahrerkarte ist eingesteckt (on_shift, siehe
-- Drivers.StartShift/EndShift) UND er sitzt auf dem Fahrersitz eines
-- Fahrzeugs, dessen Kennzeichen mit dem zugewiesenen Firmenfahrzeug
-- übereinstimmt. Vorher zählte NUR die Fahrzeugübereinstimmung - die
-- Fahrerkarte hatte für sich genommen gar keine Wirkung auf die Zähler, was
-- der Erwartung widersprach ("Karte eingesteckt, aber Zeit ändert sich
-- nicht").
-- =========================================================

local myHasDriverActions = false
local onShift = false
local assignedPlate = nil
local wasDriving = false
local warnedNoVehicleAssigned = false

local function normalizePlate(plate)
    if not plate then return nil end
    return (plate:gsub('%s+', '')):upper()
end

local function inTable(list, value)
    if type(list) ~= 'table' then return false end
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

local function refreshContext()
    ServerCall('session:whoami', nil, function(res)
        if res and res.ok and res.result and res.result.loggedIn then
            myHasDriverActions = inTable(res.result.permissions, 'driver_actions')
        else
            myHasDriverActions = false
        end

        if not myHasDriverActions then
            assignedPlate = nil
            onShift = false
            return
        end

        ServerCall('driver:vehicle', nil, function(vRes)
            if vRes and vRes.ok and vRes.result then
                onShift = vRes.result.onShift == true
                if vRes.result.vehicle then
                    assignedPlate = normalizePlate(vRes.result.vehicle.plate)
                else
                    assignedPlate = nil
                end

                -- Fahrerkarte eingesteckt, aber kein Fahrzeug zugewiesen -
                -- die Lenkzeit-Erfassung bleibt sonst ohne jede Erklärung
                -- für immer bei 0. Nur einmal pro Schicht hinweisen, nicht
                -- bei jedem Kontextabgleich (alle 60s) erneut.
                if onShift and not assignedPlate and not warnedNoVehicleAssigned then
                    warnedNoVehicleAssigned = true
                    TriggerEvent('speditions-tablet:client:notify', 'Dir ist noch kein Fahrzeug zugewiesen - deine Lenkzeit wird erst erfasst, sobald die Geschäftsführung dir im Fuhrpark ein Fahrzeug zuweist.', 'warning')
                elseif not onShift then
                    warnedNoVehicleAssigned = false
                end
            else
                assignedPlate = nil
                onShift = false
            end
        end)
    end)
end

CreateThread(function()
    refreshContext()
    while true do
        Wait(60000)
        refreshContext()
    end
end)

CreateThread(function()
    while true do
        local interval = (Config.DrivingRules and Config.DrivingRules.heartbeatIntervalMs) or 30000
        Wait(interval)

        local isDriving = false

        if myHasDriverActions and onShift and assignedPlate then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                if GetPedInVehicleSeat(veh, -1) == ped then
                    isDriving = normalizePlate(GetVehicleNumberPlateText(veh)) == assignedPlate
                end
            end
        end

        if isDriving then
            wasDriving = true
            ServerCall('driver:drivingTick', { seconds = math.floor(interval / 1000) }, function(res)
                if not res or not res.ok then
                    print(('^1[speditions-tablet]^7 Lenkzeit-Meldung fehlgeschlagen: %s'):format(res and res.error or 'keine Antwort'))
                end
            end)
        elseif wasDriving then
            wasDriving = false
            ServerCall('driver:drivingStopped', {}, function(res)
                if not res or not res.ok then
                    print(('^1[speditions-tablet]^7 Lenkzeit-Stopp-Meldung fehlgeschlagen: %s'):format(res and res.error or 'keine Antwort'))
                end
            end)
        end
    end
end)
