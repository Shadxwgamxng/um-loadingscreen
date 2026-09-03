-- =========================================================
-- Client: Lenk-/Ruhezeiten-Tracker
--
-- Läuft unabhängig davon, ob das Tablet geöffnet ist. Ein Fahrer "fährt"
-- im Sinne des Systems, solange er auf dem Fahrersitz eines Fahrzeugs
-- sitzt, dessen Kennzeichen mit dem in der Spedition zugewiesenen
-- Firmenfahrzeug übereinstimmt (SetVehicleNumberPlateText muss vom
-- jeweiligen Fahrzeug-/Garagen-Skript entsprechend gesetzt werden).
-- =========================================================

local myRole = nil
local assignedPlate = nil
local wasDriving = false

local function normalizePlate(plate)
    if not plate then return nil end
    return (plate:gsub('%s+', '')):upper()
end

local function refreshContext()
    ServerCall('session:init', nil, function(res)
        if res and res.ok and res.result and res.result.ok then
            myRole = res.result.employee.role
        else
            myRole = nil
        end

        if myRole ~= 'fahrer' then
            assignedPlate = nil
            return
        end

        ServerCall('driver:vehicle', nil, function(vRes)
            if vRes and vRes.ok and vRes.result and vRes.result.vehicle then
                assignedPlate = normalizePlate(vRes.result.vehicle.plate)
            else
                assignedPlate = nil
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

        if myRole == 'fahrer' and assignedPlate then
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
            ServerCall('driver:drivingTick', { seconds = math.floor(interval / 1000) })
        elseif wasDriving then
            wasDriving = false
            ServerCall('driver:drivingStopped', {})
        end
    end
end)
