-- =========================================================
-- Session-Initialisierung & Geschäftsführungs-Dashboard
-- =========================================================

math.randomseed(os.time())

local function sessionPayload(emp)
    return {
        ok = true,
        loggedIn = true,
        employee = { id = emp.id, name = emp.name, role = emp.role, hiredAt = emp.hired_at },
        roleLabels = Config.RoleLabels,
        driverPermissions = Config.DriverPermissions,
        vehicleClasses = Config.VehicleClasses,
        vehicleStatuses = Config.VehicleStatus,
    }
end

--- Reiner Statusabfrage-Endpunkt ohne Seiteneffekte: meldet, ob dieser
--- Server-Slot (anhand seines FiveM-Charakters) einem Mitarbeiterkonto
--- zugeordnet werden kann. Kein Login-Bildschirm - wird sowohl von der NUI
--- beim Entsperren des Tablets als auch von client/cl_hours.lua im
--- Hintergrund abgefragt.
RPC.Register('session:whoami', function(src)
    local emp = Employees.EnsureSession(src)
    if not emp then
        return { ok = true, loggedIn = false }
    end
    return sessionPayload(emp)
end)

--- TEST-KONTEN: wechselt den Server-Slot direkt auf eines der drei festen
--- Testkonten (siehe Employees.TestSwitch in sv_bootstrap.lua) - ganz ohne
--- Bezug zum FiveM-Charakter. Nur zum Ausprobieren der Basisfunktionen!
RPC.Register('session:testSwitch', function(src, payload)
    local emp = Employees.TestSwitch(src, payload.role)
    return sessionPayload(emp)
end)

local function countRows(query, params)
    local row = MySQL.single.await(query, params)
    return row and tonumber(row.c) or 0
end

RPC.Register('gf:dashboard', function(src)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })

    local overview = Finance.GetOverview()

    local totalOrders = countRows("SELECT COUNT(*) AS c FROM st_orders WHERE status = 'abgeschlossen'")
    local totalDrivers = countRows("SELECT COUNT(*) AS c FROM st_employees WHERE role = 'fahrer' AND status = 'aktiv'")
    local totalDispatchers = countRows("SELECT COUNT(*) AS c FROM st_employees WHERE role = 'disponent' AND status = 'aktiv'")
    local totalVehicles = countRows('SELECT COUNT(*) AS c FROM st_vehicles WHERE archived = 0')
    local vehiclesInUse = countRows("SELECT COUNT(*) AS c FROM st_vehicles WHERE archived = 0 AND status = 'im_einsatz'")
    local vehiclesAvailable = countRows("SELECT COUNT(*) AS c FROM st_vehicles WHERE archived = 0 AND status = 'verfuegbar'")
    local vehiclesMaintenance = countRows("SELECT COUNT(*) AS c FROM st_vehicles WHERE archived = 0 AND status IN ('wartung', 'defekt')")
    local openOrders = countRows("SELECT COUNT(*) AS c FROM st_orders WHERE status = 'offen'")
    local activeOrders = countRows("SELECT COUNT(*) AS c FROM st_orders WHERE status IN ('disponiert', 'angenommen', 'beladen', 'unterwegs')")

    local recentActivity = Logs.GetRecent(15)

    return {
        balance = overview.balance,
        revenueToday = overview.revenueToday,
        revenueWeek = overview.revenueWeek,
        revenueMonth = overview.revenueMonth,
        totalOrders = totalOrders,
        openOrders = openOrders,
        activeOrders = activeOrders,
        drivers = totalDrivers,
        dispatchers = totalDispatchers,
        vehicles = totalVehicles,
        vehiclesInUse = vehiclesInUse,
        vehiclesAvailable = vehiclesAvailable,
        vehiclesMaintenance = vehiclesMaintenance,
        recentActivity = recentActivity,
    }
end)

RPC.Register('gf:stats', function(src)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })

    local revenueByDay = MySQL.query.await([[
        SELECT DATE(created_at) AS day, COALESCE(SUM(amount), 0) AS total
        FROM st_transactions
        WHERE type = 'einnahme' AND created_at >= DATE_SUB(CURDATE(), INTERVAL 13 DAY)
        GROUP BY DATE(created_at)
        ORDER BY day ASC
    ]])

    local topDrivers = MySQL.query.await([[
        SELECT e.name, s.total_orders, s.total_km, s.successful_deliveries, s.punctuality_rate
        FROM st_driver_statistics s
        JOIN st_drivers d ON d.id = s.driver_id
        JOIN st_employees e ON e.id = d.employee_id
        ORDER BY s.successful_deliveries DESC
        LIMIT 10
    ]])

    local ordersByStatus = MySQL.query.await([[
        SELECT status, COUNT(*) AS c FROM st_orders GROUP BY status
    ]])

    return {
        revenueByDay = revenueByDay,
        topDrivers = topDrivers,
        ordersByStatus = ordersByStatus,
    }
end)

CreateThread(function()
    Utils.DebugPrint('speditions-tablet gestartet.')
end)

-- =========================================================
-- Item-gesteuertes Öffnen (siehe Config.RequireItem)
-- =========================================================

--- Für Inventarsysteme ohne ESX.RegisterUsableItem: das eigene Item-Skript
--- kann dieses Event beim Gebrauch selbst feuern (src = der Spieler, der
--- das Item benutzt hat).
RegisterNetEvent('speditions-tablet:server:openFromItem', function()
    TriggerClientEvent('speditions-tablet:client:openFromItem', source)
end)

CreateThread(function()
    if not (Config.RequireItem and Config.RequireItem.enabled) then return end

    local esx = nil
    for _ = 1, 30 do
        esx = Bridge.GetEsx()
        if esx and esx.RegisterUsableItem then break end
        Wait(1000)
    end

    if esx and esx.RegisterUsableItem then
        esx.RegisterUsableItem(Config.RequireItem.itemName, function(playerSrc)
            TriggerClientEvent('speditions-tablet:client:openFromItem', playerSrc)
        end)
        print(('^2[speditions-tablet]^7 Tablet oeffnet sich ueber Item "%s" (ESX.RegisterUsableItem).'):format(Config.RequireItem.itemName))
    else
        print('^1[speditions-tablet]^7 Config.RequireItem ist aktiv, aber ESX wurde nicht gefunden - das Tablet kann so nicht per Item geoeffnet werden. Fuer andere Inventare feuere selbst das Event speditions-tablet:server:openFromItem.')
    end
end)
