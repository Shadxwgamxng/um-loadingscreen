-- =========================================================
-- Fahrer / Fahrerkarte / Fahrerakte
-- =========================================================

Drivers = {}

function Drivers.GetByEmployeeId(employeeId)
    return MySQL.single.await('SELECT * FROM st_drivers WHERE employee_id = ? LIMIT 1', { employeeId })
end

function Drivers.GetById(driverId)
    return MySQL.single.await('SELECT * FROM st_drivers WHERE id = ? LIMIT 1', { driverId })
end

--- Stellt sicher, dass ein Fahrer-Datensatz (inkl. Statistik-Zeile) existiert,
--- sobald ein Mitarbeiter die Rolle "fahrer" innehat.
function Drivers.EnsureDriverRecord(employeeId)
    local driver = Drivers.GetByEmployeeId(employeeId)
    if driver then return driver end

    local driverId = MySQL.insert.await(
        "INSERT INTO st_drivers (employee_id, rank, current_status) VALUES (?, 'Fahrer', 'offline')",
        { employeeId }
    )
    MySQL.insert.await(
        'INSERT INTO st_driver_statistics (driver_id) VALUES (?) ON DUPLICATE KEY UPDATE driver_id = driver_id',
        { driverId }
    )
    return Drivers.GetById(driverId)
end

local DRIVER_STATUS_VALUES = { 'offline', 'verfuegbar', 'im_einsatz', 'pause' }

function Drivers.SetStatus(src, status)
    local emp = Employees.RequireRole(src, { Config.Roles.FAHRER })
    if not Utils.InTable(DRIVER_STATUS_VALUES, status) then error('invalid_status') end

    local driver = Drivers.EnsureDriverRecord(emp.id)
    MySQL.update.await('UPDATE st_drivers SET current_status = ? WHERE id = ?', { status, driver.id })

    RPC.PushToRole(Config.Roles.DISPONENT, 'dispatch:driversChanged', {})
    RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'dispatch:driversChanged', {})

    return { ok = true, status = status }
end

--- Rechnet die Fahrerstatistik aus den tatsächlichen Auftragsdaten neu (kein
--- inkrementelles +1 das aus dem Ruder laufen könnte - immer aus der
--- Quelle-der-Wahrheit (st_orders) neu berechnet).
function Drivers.RecomputeStatistics(driverId)
    local totals = MySQL.single.await([[
        SELECT
            COUNT(*) AS total_orders,
            COALESCE(SUM(CASE WHEN status = 'abgeschlossen' THEN distance_km ELSE 0 END), 0) AS total_km,
            SUM(CASE WHEN status = 'abgeschlossen' THEN 1 ELSE 0 END) AS successful_deliveries,
            SUM(CASE WHEN status IN ('abgebrochen', 'abgelehnt') THEN 1 ELSE 0 END) AS cancelled_orders,
            SUM(CASE WHEN status = 'abgeschlossen' AND punctual = 1 THEN 1 ELSE 0 END) AS on_time_deliveries
        FROM st_orders
        WHERE driver_id = ?
    ]], { driverId })

    local successful = totals and tonumber(totals.successful_deliveries) or 0
    local onTime = totals and tonumber(totals.on_time_deliveries) or 0
    local punctuality = successful > 0 and Utils.Round2((onTime / successful) * 100) or 0

    MySQL.query.await([[
        INSERT INTO st_driver_statistics (driver_id, total_orders, total_km, successful_deliveries, cancelled_orders, on_time_deliveries, punctuality_rate)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            total_orders = VALUES(total_orders),
            total_km = VALUES(total_km),
            successful_deliveries = VALUES(successful_deliveries),
            cancelled_orders = VALUES(cancelled_orders),
            on_time_deliveries = VALUES(on_time_deliveries),
            punctuality_rate = VALUES(punctuality_rate)
    ]], {
        driverId,
        totals and tonumber(totals.total_orders) or 0,
        totals and Utils.Round2(totals.total_km) or 0,
        successful,
        totals and tonumber(totals.cancelled_orders) or 0,
        onTime,
        punctuality,
    })
end

function Drivers.GetStatistics(driverId)
    local stats = MySQL.single.await('SELECT * FROM st_driver_statistics WHERE driver_id = ?', { driverId })
    return stats or {
        total_orders = 0, total_km = 0, successful_deliveries = 0,
        cancelled_orders = 0, on_time_deliveries = 0, punctuality_rate = 0,
    }
end

function Drivers.GetPermissions(driverId)
    local rows = MySQL.query.await('SELECT permission_key, granted_at FROM st_driver_permissions WHERE driver_id = ?', { driverId })
    local set = {}
    for _, row in ipairs(rows) do
        set[row.permission_key] = row.granted_at
    end

    local result = {}
    for _, perm in ipairs(Config.DriverPermissions) do
        result[#result + 1] = {
            key = perm.key,
            label = perm.label,
            granted = set[perm.key] ~= nil,
            grantedAt = set[perm.key],
        }
    end
    return result
end

function Drivers.GetVehicle(driverId)
    return MySQL.single.await(
        'SELECT * FROM st_vehicles WHERE id = (SELECT assigned_vehicle_id FROM st_drivers WHERE id = ?)',
        { driverId }
    )
end

function Drivers.GetHistory(driverId, limit)
    limit = Utils.SanitizeNumber(limit, 1, 200) or 50
    return MySQL.query.await([[
        SELECT o.id, o.cargo, o.start_location, o.end_location, o.distance_km, o.value,
               o.status, o.punctual, o.created_at, o.completed_at
        FROM st_orders o
        WHERE o.driver_id = ? AND o.status IN ('abgeschlossen', 'abgebrochen', 'abgelehnt')
        ORDER BY COALESCE(o.completed_at, o.created_at) DESC
        LIMIT ?
    ]], { driverId, limit })
end

--- Vollständige digitale Fahrerkarte für den Fahrer selbst.
function Drivers.GetOwnCard(src)
    local emp = Employees.RequireRole(src, { Config.Roles.FAHRER })
    local driver = Drivers.EnsureDriverRecord(emp.id)
    local stats = Drivers.GetStatistics(driver.id)
    local vehicle = Drivers.GetVehicle(driver.id)
    local earnings = Finance.GetDriverEarnings(driver.id)

    return {
        employee = { id = emp.id, name = emp.name, hiredAt = emp.hired_at, status = emp.status },
        driver = { id = driver.id, rank = driver.rank, currentStatus = driver.current_status, notes = driver.notes },
        statistics = stats,
        permissions = Drivers.GetPermissions(driver.id),
        vehicle = vehicle,
        earnings = earnings,
    }
end

--- Fahrerakte für die Geschäftsführung (inkl. Notizen-Bearbeitung).
function Drivers.GetFile(driverId)
    local driver = Drivers.GetById(driverId)
    if not driver then error('driver_not_found') end
    local emp = MySQL.single.await('SELECT * FROM st_employees WHERE id = ?', { driver.employee_id })
    local stats = Drivers.GetStatistics(driverId)
    local vehicle = Drivers.GetVehicle(driverId)
    local earnings = Finance.GetDriverEarnings(driverId)
    local history = Drivers.GetHistory(driverId, 25)

    return {
        employee = emp,
        driver = driver,
        statistics = stats,
        permissions = Drivers.GetPermissions(driverId),
        vehicle = vehicle,
        earnings = earnings,
        history = history,
    }
end

function Drivers.SetNote(src, driverId, note)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    local driver = Drivers.GetById(driverId)
    if not driver then error('driver_not_found') end

    note = note ~= nil and Utils.SanitizeString(note, 2000) or nil
    MySQL.update.await('UPDATE st_drivers SET notes = ? WHERE id = ?', { note, driverId })
    Logs.Write(emp.id, 'driver_note', ('%s hat eine Notiz für Fahrer #%s hinterlegt.'):format(emp.name, driverId))
    return { ok = true }
end

function Drivers.SetPermission(src, driverId, permKey, granted)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    local driver = Drivers.GetById(driverId)
    if not driver then error('driver_not_found') end

    local validKey = false
    for _, perm in ipairs(Config.DriverPermissions) do
        if perm.key == permKey then validKey = true break end
    end
    if not validKey then error('invalid_permission') end

    if granted then
        MySQL.insert.await(
            'INSERT INTO st_driver_permissions (driver_id, permission_key, granted_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE granted_by = VALUES(granted_by), granted_at = NOW()',
            { driverId, permKey, emp.id }
        )
    else
        MySQL.update.await('DELETE FROM st_driver_permissions WHERE driver_id = ? AND permission_key = ?', { driverId, permKey })
    end

    Logs.Write(emp.id, 'driver_permission', ('%s hat Berechtigung "%s" für Fahrer #%s %s.'):format(emp.name, permKey, driverId, granted and 'erteilt' or 'entzogen'))
    return { ok = true }
end

--- Fahrerübersicht für den Disponenten (und die Geschäftsführung): wer ist
--- eingeloggt, welchen Status hat er, welches Fahrzeug fährt er gerade.
function Drivers.ListForDispatch()
    return MySQL.query.await([[
        SELECT d.id AS driver_id, e.name, e.status AS employment_status, d.current_status,
               v.id AS vehicle_id, v.name AS vehicle_name, v.plate AS vehicle_plate, v.status AS vehicle_status
        FROM st_drivers d
        JOIN st_employees e ON e.id = d.employee_id
        LEFT JOIN st_vehicles v ON v.id = d.assigned_vehicle_id
        WHERE e.status = 'aktiv'
        ORDER BY d.current_status = 'verfuegbar' DESC, e.name ASC
    ]])
end

-- =========================================================
-- RPC-Handler
-- =========================================================

RPC.Register('driver:card', function(src)
    return Drivers.GetOwnCard(src)
end)

RPC.Register('driver:setStatus', function(src, payload)
    return Drivers.SetStatus(src, payload.status)
end)

RPC.Register('driver:history', function(src, payload)
    local emp = Employees.RequireRole(src, { Config.Roles.FAHRER })
    local driver = Drivers.EnsureDriverRecord(emp.id)
    return { history = Drivers.GetHistory(driver.id, payload.limit) }
end)

RPC.Register('driver:earnings', function(src)
    local emp = Employees.RequireRole(src, { Config.Roles.FAHRER })
    local driver = Drivers.EnsureDriverRecord(emp.id)
    return Finance.GetDriverEarnings(driver.id)
end)

RPC.Register('driver:vehicle', function(src)
    local emp = Employees.RequireRole(src, { Config.Roles.FAHRER })
    local driver = Drivers.EnsureDriverRecord(emp.id)
    return { vehicle = Drivers.GetVehicle(driver.id) }
end)

RPC.Register('dispatch:drivers', function(src)
    Employees.RequireRole(src, { Config.Roles.DISPONENT, Config.Roles.GESCHAEFTSFUEHRUNG })
    return { drivers = Drivers.ListForDispatch() }
end)

RPC.Register('gf:drivers:file', function(src, payload)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    local driverId = Utils.SanitizeNumber(payload.driverId, 1)
    if not driverId then error('invalid_driver') end
    return Drivers.GetFile(driverId)
end)

RPC.Register('gf:drivers:setNote', function(src, payload)
    local driverId = Utils.SanitizeNumber(payload.driverId, 1)
    if not driverId then error('invalid_driver') end
    return Drivers.SetNote(src, driverId, payload.note)
end)

RPC.Register('gf:drivers:setPermission', function(src, payload)
    local driverId = Utils.SanitizeNumber(payload.driverId, 1)
    if not driverId then error('invalid_driver') end
    return Drivers.SetPermission(src, driverId, payload.permissionKey, payload.granted == true)
end)
