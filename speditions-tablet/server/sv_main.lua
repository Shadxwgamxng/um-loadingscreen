-- =========================================================
-- Session-Initialisierung & Geschäftsführungs-Dashboard
-- =========================================================

math.randomseed(os.time())

--- Wird von der NUI beim Öffnen des Tablets aufgerufen. Liefert Rolle,
--- Mitarbeiterdaten und die für die Oberfläche benötigten Stammdaten
--- (Berechtigungskatalog, Fahrzeugklassen, ...).
RPC.Register('session:init', function(src)
    local emp = Employees.Resolve(src)
    if not emp then
        return { ok = false, reason = 'not_employee' }
    end
    if emp.status ~= 'aktiv' then
        return { ok = false, reason = 'employee_inactive' }
    end

    if emp.role == Config.Roles.FAHRER then
        Drivers.EnsureDriverRecord(emp.id)
    end

    return {
        ok = true,
        employee = { id = emp.id, name = emp.name, role = emp.role, hiredAt = emp.hired_at },
        roleLabels = Config.RoleLabels,
        driverPermissions = Config.DriverPermissions,
        vehicleClasses = Config.VehicleClasses,
        vehicleStatuses = Config.VehicleStatus,
        currency = Config.Currency,
    }
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
