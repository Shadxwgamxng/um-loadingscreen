-- =========================================================
-- Live-Karte für die Disposition
--
-- Serverseitig ausschließlich: liest die Weltposition jedes gerade
-- angemeldeten Mitarbeiters mit der Berechtigung "driver_actions" direkt
-- über GetEntityCoords aus (funktioniert server-seitig für jeden
-- verbundenen Spieler, ganz ohne Client-Mitwirkung/eigenen Heartbeat-Call -
-- dadurch auch kein Spam von RPC-Fehlern für Mitarbeiter ohne diese
-- Berechtigung). Positionen werden NICHT in der Datenbank gespeichert -
-- rein transient im Arbeitsspeicher, jede Sekunde... genauer: alle
-- POSITION_INTERVAL_MS neu aufgebaut, damit nicht mehr online/angemeldete
-- Fahrer automatisch aus der Karte verschwinden statt als "Geisterposition"
-- stehen zu bleiben.
-- =========================================================

Tracking = {}

local POSITION_INTERVAL_MS = 5000
local positions = {} -- employeeId -> { x, y, updatedAt }

CreateThread(function()
    while true do
        Wait(POSITION_INTERVAL_MS)

        local fresh = {}
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            local emp = Employees.GetLoggedIn(src)
            if emp and Roles.HasPermission(emp.role, 'driver_actions') then
                local ped = GetPlayerPed(src)
                if ped and ped ~= 0 then
                    local coords = GetEntityCoords(ped)
                    fresh[emp.id] = { x = coords.x, y = coords.y, updatedAt = os.time() }
                end
            end
        end
        positions = fresh
    end
end)

--- Ermittelt, welcher Standort gerade als GPS-Wegpunkt für einen laufenden
--- Auftrag gilt (identische Logik wie der automatische Wegpunkt beim
--- Annehmen/Beladen - siehe server/sv_orders.lua, Utils.SetClientWaypoint).
local function currentWaypointForOrder(order)
    if not order then return nil end
    if order.status == 'anfahrt' then
        local loc = Utils.GetLocationByName(order.start_location)
        if loc then return { x = Utils.Round2(loc.coords.x), y = Utils.Round2(loc.coords.y), label = order.start_location } end
    elseif order.status == 'beladen' or order.status == 'entladen' then
        local loc = Utils.GetLocationByName(order.end_location)
        if loc then return { x = Utils.Round2(loc.coords.x), y = Utils.Round2(loc.coords.y), label = order.end_location } end
    end
    return nil
end

RPC.Register('dispatch:liveMap', function(src)
    Employees.RequirePermission(src, 'live_map_view')

    local drivers = MySQL.query.await([[
        SELECT d.id AS driver_id, d.employee_id, e.name, d.current_status, d.on_shift
        FROM st_drivers d
        JOIN st_employees e ON e.id = d.employee_id
        WHERE e.status = 'aktiv'
        ORDER BY e.name ASC
    ]])

    local out = {}
    for _, driver in ipairs(drivers) do
        local order = MySQL.single.await([[
            SELECT id, status, cargo, start_location, end_location
            FROM st_orders
            WHERE driver_id = ? AND status IN ('angenommen', 'anfahrt', 'beladen', 'entladen')
            ORDER BY id DESC LIMIT 1
        ]], { driver.driver_id })

        local pos = positions[driver.employee_id]

        out[#out + 1] = {
            employeeId = driver.employee_id,
            name = driver.name,
            onShift = Utils.ToBool(driver.on_shift),
            status = driver.current_status,
            position = pos and { x = Utils.Round2(pos.x), y = Utils.Round2(pos.y) } or nil,
            positionAgeSeconds = pos and (os.time() - pos.updatedAt) or nil,
            order = order and {
                id = order.id,
                status = order.status,
                cargo = order.cargo,
                startLocation = order.start_location,
                endLocation = order.end_location,
            } or nil,
            waypoint = currentWaypointForOrder(order),
        }
    end

    local locations = {}
    for _, loc in ipairs(Config.Locations) do
        locations[#locations + 1] = { name = loc.name, x = Utils.Round2(loc.coords.x), y = Utils.Round2(loc.coords.y) }
    end

    return { drivers = out, locations = locations }
end)
