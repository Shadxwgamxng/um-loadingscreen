-- =========================================================
-- Live-Karte
--
-- Trackt AUSSCHLIESSLICH eingestempelte Fahrer (st_drivers.on_shift = 1) -
-- alle anderen verursachen keinerlei Last (kein Dauer-Polling für
-- Nicht-Fahrer/nicht eingestempelte Fahrer). Rein transient im
-- Arbeitsspeicher, keine Datenbank-Tabelle, keine Historie.
--
-- Dient zwei Abnehmern:
--   - Der Tablet-eigenen NUI (Reiter "Live-Karte", RPC 'dispatch:liveMap').
--   - Optional, sofern Config.Website.enabled, per HTTP-Push an die externe
--     Website (server/sv_website_bridge.lua, WebsiteBridge.PushDriverPosition/
--     -PushDriverPositionRemove) - bei jedem Tracking-Tick für jeden gerade
--     getrackten Fahrer, sowie sofort (nicht erst beim nächsten Tick) bei
--     "Fahrerkarte abziehen" (server/sv_drivers.lua, Drivers.EndShift) und
--     bei Disconnect.
-- =========================================================

Tracking = {}

local positions = {} -- employeeId -> Payload (siehe buildPositionPayload)
local trackedBySrc = {} -- src -> employeeId, nur für den Sofort-Entfernen-Pfad bei Disconnect

local function currentOrderInfo(order)
    if not order then return nil end
    return {
        cargo = order.cargo,
        startLocation = order.start_location,
        endLocation = order.end_location,
        status = order.status,
    }
end

--- Baut den Live-Karten-Datensatz eines einzelnen, gerade getrackten
--- Fahrers. `vehiclePlate` bevorzugt das Kennzeichen des Fahrzeugs, in dem
--- der Fahrer GERADE tatsächlich sitzt (GetVehiclePedIsIn) - ist er gerade
--- zu Fuß (z.B. beim Be-/Entladen), fällt es auf das ihm für diese Schicht
--- zugewiesene Fahrzeug zurück (st_drivers.assigned_vehicle_id), damit der
--- Marker nicht ohne Fahrzeugangabe dasteht.
local function buildPositionPayload(src, emp, driverRow)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local coords = GetEntityCoords(ped)

    local vehiclePlate, vehicleLabel = nil, nil
    local vehicleEntity = GetVehiclePedIsIn(ped, false)
    if vehicleEntity ~= 0 then
        vehiclePlate = GetVehicleNumberPlateText(vehicleEntity)
    end

    if driverRow.assigned_vehicle_id then
        local vehicle = Vehicles.GetById(driverRow.assigned_vehicle_id)
        if vehicle then
            vehicleLabel = ('%s (%s)'):format(vehicle.name, vehicle.vehicle_class)
            vehiclePlate = vehiclePlate or vehicle.plate
        end
    end

    local order = MySQL.single.await([[
        SELECT id, status, cargo, start_location, end_location
        FROM st_orders
        WHERE driver_id = ? AND status IN ('angenommen', 'anfahrt', 'beladen', 'entladen')
        ORDER BY id DESC LIMIT 1
    ]], { driverRow.id })

    return {
        tabletEmployeeId = emp.id,
        name = emp.name,
        x = Utils.Round2(coords.x),
        y = Utils.Round2(coords.y),
        z = Utils.Round2(coords.z),
        vehiclePlate = vehiclePlate,
        vehicleLabel = vehicleLabel,
        order = currentOrderInfo(order),
    }
end

--- Entfernt einen Fahrer sofort von der Live-Karte (lokal + Website-Push),
--- statt bis zum nächsten Tracking-Tick zu warten.
function Tracking.RemoveDriver(employeeId)
    if not employeeId or not positions[employeeId] then return end
    positions[employeeId] = nil
    if WebsiteBridge then WebsiteBridge.PushDriverPositionRemove(employeeId) end
end

CreateThread(function()
    while true do
        Wait((Config.LiveMap and Config.LiveMap.trackingIntervalMs) or 3000)

        local onShiftDrivers = MySQL.query.await([[
            SELECT d.id, d.employee_id, d.assigned_vehicle_id
            FROM st_drivers d
            JOIN st_employees e ON e.id = d.employee_id
            WHERE d.on_shift = 1 AND e.status = 'aktiv'
        ]])
        local onShiftByEmployeeId = {}
        for _, row in ipairs(onShiftDrivers) do
            onShiftByEmployeeId[row.employee_id] = row
        end

        local freshPositions, freshTrackedBySrc = {}, {}
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            local emp = Employees.GetLoggedIn(src)
            local driverRow = emp and onShiftByEmployeeId[emp.id]
            if driverRow then
                local payload = buildPositionPayload(src, emp, driverRow)
                if payload then
                    freshPositions[emp.id] = payload
                    freshTrackedBySrc[src] = emp.id
                    if WebsiteBridge then WebsiteBridge.PushDriverPosition(payload) end
                end
            end
        end

        -- Sicherheitsnetz: wer im letzten Tick noch getrackt war, jetzt aber
        -- nicht mehr, UND nicht schon über Drivers.EndShift/Disconnect sofort
        -- entfernt wurde (z.B. weil on_shift anderweitig auf 0 gesetzt
        -- wurde) - trotzdem eine Entfernen-Meldung nachschicken, damit auf
        -- der Website kein Geisterfahrer stehen bleibt.
        for employeeId in pairs(positions) do
            if not freshPositions[employeeId] and WebsiteBridge then
                WebsiteBridge.PushDriverPositionRemove(employeeId)
            end
        end

        positions = freshPositions
        trackedBySrc = freshTrackedBySrc
    end
end)

AddEventHandler('playerDropped', function()
    local employeeId = trackedBySrc[source]
    if employeeId then
        trackedBySrc[source] = nil
        Tracking.RemoveDriver(employeeId)
    end
end)

--- Live-Karte für die Tablet-NUI (Reiter "Live-Karte").
RPC.Register('dispatch:liveMap', function(src)
    Employees.RequirePermission(src, 'live_map_view')
    local out = {}
    for _, pos in pairs(positions) do
        out[#out + 1] = pos
    end
    return { drivers = out }
end)
