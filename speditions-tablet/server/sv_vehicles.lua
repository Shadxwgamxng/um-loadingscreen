-- =========================================================
-- Fuhrparkverwaltung
--
-- Erstellen / Bearbeiten / Löschen / Zuweisen ist ausschließlich
-- der Geschäftsführung vorbehalten (serverseitig erzwungen).
-- Der Disponent bekommt lesenden Zugriff über sv_drivers.lua
-- (dispatch:drivers zeigt Fahrer + deren aktuelles Fahrzeug).
-- =========================================================

Vehicles = {}

local STATUS_VALUES = { 'verfuegbar', 'im_einsatz', 'wartung', 'defekt', 'ausser_betrieb' }

function Vehicles.GetById(vehicleId)
    return MySQL.single.await('SELECT * FROM st_vehicles WHERE id = ? LIMIT 1', { vehicleId })
end

function Vehicles.List(includeArchived)
    local where = includeArchived and '' or 'WHERE v.archived = 0'
    return MySQL.query.await(([[
        SELECT v.*, d.id AS driver_id, e.name AS driver_name
        FROM st_vehicles v
        LEFT JOIN st_drivers d ON d.assigned_vehicle_id = v.id
        LEFT JOIN st_employees e ON e.id = d.employee_id
        %s
        ORDER BY v.archived ASC, v.name ASC
    ]]):format(where))
end

local function logVehicleEvent(vehicleId, eventType, description, relatedOrderId)
    MySQL.insert.await(
        'INSERT INTO st_vehicle_history (vehicle_id, event_type, description, related_order_id) VALUES (?, ?, ?, ?)',
        { vehicleId, eventType, description, relatedOrderId }
    )
end
Vehicles.LogEvent = logVehicleEvent

function Vehicles.Create(src, data)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })

    local name = Utils.SanitizeString(data.name, 100)
    local model = Utils.SanitizeString(data.model, 100)
    local plate = Utils.SanitizeString(data.plate, 20)
    local vehicleClass = Utils.SanitizeString(data.vehicleClass, 50)
    local mileage = Utils.SanitizeNumber(data.mileage, 0) or 0
    local fuel = Utils.SanitizeNumber(data.fuel, 0, 100) or 100
    local vehicleIdentifier = Utils.SanitizeString(data.vehicleIdentifier, 50)

    if not (name and model and plate and vehicleClass) then error('missing_fields') end

    local existing = MySQL.single.await('SELECT id FROM st_vehicles WHERE plate = ? LIMIT 1', { plate })
    if existing then error('plate_taken') end

    local vehicleId = MySQL.insert.await(
        [[INSERT INTO st_vehicles (name, model, plate, vehicle_class, mileage, fuel, status, vehicle_identifier)
          VALUES (?, ?, ?, ?, ?, ?, 'verfuegbar', ?)]],
        { name, model, plate, vehicleClass, mileage, fuel, vehicleIdentifier }
    )

    logVehicleEvent(vehicleId, 'created', ('Fahrzeug von %s erstellt.'):format(emp.name))
    Logs.Write(emp.id, 'vehicle_create', ('%s hat Fahrzeug %s (%s) erstellt.'):format(emp.name, name, plate))
    RPC.PushToRole(Config.Roles.DISPONENT, 'fleet:changed', {})
    RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'fleet:changed', {})

    return { vehicleId = vehicleId }
end

function Vehicles.Update(src, vehicleId, data)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })

    local vehicle = Vehicles.GetById(vehicleId)
    if not vehicle then error('vehicle_not_found') end

    local name = Utils.SanitizeString(data.name, 100) or vehicle.name
    local model = Utils.SanitizeString(data.model, 100) or vehicle.model
    local plate = Utils.SanitizeString(data.plate, 20) or vehicle.plate
    local vehicleClass = Utils.SanitizeString(data.vehicleClass, 50) or vehicle.vehicle_class
    local mileage = Utils.SanitizeNumber(data.mileage, 0)
    if mileage == nil then mileage = vehicle.mileage end
    local fuel = Utils.SanitizeNumber(data.fuel, 0, 100)
    if fuel == nil then fuel = vehicle.fuel end
    local status = data.status
    if status ~= nil and not Utils.InTable(STATUS_VALUES, status) then error('invalid_status') end
    status = status or vehicle.status
    local notes = data.notes ~= nil and Utils.SanitizeString(data.notes, 2000) or vehicle.notes
    local vehicleIdentifier = Utils.SanitizeString(data.vehicleIdentifier, 50) or vehicle.vehicle_identifier

    if plate ~= vehicle.plate then
        local existing = MySQL.single.await('SELECT id FROM st_vehicles WHERE plate = ? AND id != ? LIMIT 1', { plate, vehicleId })
        if existing then error('plate_taken') end
    end

    MySQL.update.await(
        [[UPDATE st_vehicles SET name = ?, model = ?, plate = ?, vehicle_class = ?, mileage = ?,
          fuel = ?, status = ?, notes = ?, vehicle_identifier = ? WHERE id = ?]],
        { name, model, plate, vehicleClass, mileage, fuel, status, notes, vehicleIdentifier, vehicleId }
    )

    if status ~= vehicle.status then
        logVehicleEvent(vehicleId, 'status_change', ('Status geändert: %s -> %s (von %s)'):format(vehicle.status, status, emp.name))
    end

    Logs.Write(emp.id, 'vehicle_update', ('%s hat Fahrzeug %s (%s) bearbeitet.'):format(emp.name, name, plate))
    RPC.PushToRole(Config.Roles.DISPONENT, 'fleet:changed', {})
    RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'fleet:changed', {})

    return { ok = true }
end

--- Löscht ein Fahrzeug. mode = 'archive' (Standard, sicher) oder 'hard'.
--- Hard-Delete wird serverseitig verweigert, wenn das Fahrzeug bereits in
--- Aufträgen referenziert wird, um die Fahrzeughistorie nicht zu zerstören.
function Vehicles.Delete(src, vehicleId, mode)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    local vehicle = Vehicles.GetById(vehicleId)
    if not vehicle then error('vehicle_not_found') end

    local usedInOrders = MySQL.single.await('SELECT COUNT(*) AS c FROM st_orders WHERE vehicle_id = ?', { vehicleId })
    local hasHistory = usedInOrders and tonumber(usedInOrders.c) > 0

    if mode == 'hard' and not hasHistory then
        -- Zuweisung des Fahrers lösen
        MySQL.update.await('UPDATE st_drivers SET assigned_vehicle_id = NULL WHERE assigned_vehicle_id = ?', { vehicleId })
        MySQL.update.await('DELETE FROM st_vehicles WHERE id = ?', { vehicleId })
        Logs.Write(emp.id, 'vehicle_delete_hard', ('%s hat Fahrzeug %s (%s) endgültig gelöscht.'):format(emp.name, vehicle.name, vehicle.plate))
        RPC.PushToRole(Config.Roles.DISPONENT, 'fleet:changed', {})
        RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'fleet:changed', {})
        return { ok = true, mode = 'hard' }
    end

    -- Archivieren: Historie bleibt vollständig erhalten
    MySQL.update.await('UPDATE st_drivers SET assigned_vehicle_id = NULL WHERE assigned_vehicle_id = ?', { vehicleId })
    MySQL.update.await("UPDATE st_vehicles SET archived = 1, status = 'ausser_betrieb' WHERE id = ?", { vehicleId })
    logVehicleEvent(vehicleId, 'archived', ('Fahrzeug von %s archiviert.'):format(emp.name))
    Logs.Write(emp.id, 'vehicle_archive', ('%s hat Fahrzeug %s (%s) archiviert.'):format(emp.name, vehicle.name, vehicle.plate))
    RPC.PushToRole(Config.Roles.DISPONENT, 'fleet:changed', {})
    RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'fleet:changed', {})

    local forced = (mode == 'hard' and hasHistory)
    return { ok = true, mode = 'archive', forced = forced }
end

function Vehicles.Reactivate(src, vehicleId)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    local vehicle = Vehicles.GetById(vehicleId)
    if not vehicle then error('vehicle_not_found') end
    MySQL.update.await("UPDATE st_vehicles SET archived = 0, status = 'verfuegbar' WHERE id = ?", { vehicleId })
    logVehicleEvent(vehicleId, 'reactivated', ('Fahrzeug von %s reaktiviert.'):format(emp.name))
    Logs.Write(emp.id, 'vehicle_reactivate', ('%s hat Fahrzeug %s (%s) reaktiviert.'):format(emp.name, vehicle.name, vehicle.plate))
    return { ok = true }
end

--- Weist ein Fahrzeug einem Fahrer zu (oder hebt die Zuweisung auf, wenn driverId = nil).
function Vehicles.Assign(src, vehicleId, driverId)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    local vehicle = Vehicles.GetById(vehicleId)
    if not vehicle then error('vehicle_not_found') end
    if Utils.ToBool(vehicle.archived) then error('vehicle_archived') end

    -- Vorherigen Fahrer dieses Fahrzeugs entkoppeln
    local previousDriver = MySQL.single.await('SELECT id FROM st_drivers WHERE assigned_vehicle_id = ?', { vehicleId })
    if previousDriver then
        MySQL.update.await('UPDATE st_drivers SET assigned_vehicle_id = NULL WHERE id = ?', { previousDriver.id })
        MySQL.update.await(
            'UPDATE st_vehicle_assignments SET unassigned_at = NOW() WHERE vehicle_id = ? AND driver_id = ? AND unassigned_at IS NULL',
            { vehicleId, previousDriver.id }
        )
    end

    if driverId ~= nil and driverId ~= 0 then
        local driver = MySQL.single.await('SELECT d.*, e.name FROM st_drivers d JOIN st_employees e ON e.id = d.employee_id WHERE d.id = ?', { driverId })
        if not driver then error('driver_not_found') end

        -- Falls der Fahrer bereits ein anderes Fahrzeug hatte, dieses freigeben
        if driver.assigned_vehicle_id and driver.assigned_vehicle_id ~= vehicleId then
            MySQL.update.await(
                'UPDATE st_vehicle_assignments SET unassigned_at = NOW() WHERE vehicle_id = ? AND driver_id = ? AND unassigned_at IS NULL',
                { driver.assigned_vehicle_id, driverId }
            )
        end

        MySQL.update.await('UPDATE st_drivers SET assigned_vehicle_id = ? WHERE id = ?', { vehicleId, driverId })
        MySQL.insert.await(
            'INSERT INTO st_vehicle_assignments (vehicle_id, driver_id, assigned_by) VALUES (?, ?, ?)',
            { vehicleId, driverId, emp.id }
        )
        logVehicleEvent(vehicleId, 'assignment', ('%s hat Fahrzeug %s dem Fahrer zugewiesen.'):format(emp.name, vehicle.name))
        Logs.Write(emp.id, 'vehicle_assign', ('%s hat Fahrzeug %s (%s) %s zugewiesen.'):format(emp.name, vehicle.name, vehicle.plate, driver.name))
    else
        logVehicleEvent(vehicleId, 'unassigned', ('%s hat die Fahrzeugzuweisung aufgehoben.'):format(emp.name))
        Logs.Write(emp.id, 'vehicle_unassign', ('%s hat die Zuweisung von Fahrzeug %s (%s) aufgehoben.'):format(emp.name, vehicle.name, vehicle.plate))
    end

    RPC.PushToRole(Config.Roles.DISPONENT, 'fleet:changed', {})
    RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'fleet:changed', {})

    return { ok = true }
end

--- Vollständige Fahrzeugakte inkl. letzter Aufträge.
function Vehicles.GetFile(vehicleId)
    local vehicle = Vehicles.GetById(vehicleId)
    if not vehicle then error('vehicle_not_found') end

    local currentDriver = MySQL.single.await(
        'SELECT e.name FROM st_drivers d JOIN st_employees e ON e.id = d.employee_id WHERE d.assigned_vehicle_id = ?',
        { vehicleId }
    )

    local orderCount = MySQL.single.await("SELECT COUNT(*) AS c FROM st_orders WHERE vehicle_id = ? AND status = 'abgeschlossen'", { vehicleId })
    local kmDriven = MySQL.single.await("SELECT COALESCE(SUM(distance_km), 0) AS total FROM st_orders WHERE vehicle_id = ? AND status = 'abgeschlossen'", { vehicleId })

    local recentOrders = MySQL.query.await([[
        SELECT o.id, o.start_location, o.end_location, o.status, o.completed_at, e.name AS driver_name
        FROM st_orders o
        LEFT JOIN st_drivers d ON d.id = o.driver_id
        LEFT JOIN st_employees e ON e.id = d.employee_id
        WHERE o.vehicle_id = ?
        ORDER BY o.created_at DESC
        LIMIT 15
    ]], { vehicleId })

    local lastMaintenance = MySQL.single.await(
        "SELECT created_at FROM st_vehicle_history WHERE vehicle_id = ? AND event_type = 'maintenance' ORDER BY created_at DESC LIMIT 1",
        { vehicleId }
    )

    return {
        vehicle = vehicle,
        currentDriverName = currentDriver and currentDriver.name or nil,
        totalOrders = orderCount and tonumber(orderCount.c) or 0,
        totalKm = kmDriven and Utils.Round2(kmDriven.total) or 0,
        recentOrders = recentOrders,
        lastMaintenance = lastMaintenance and lastMaintenance.created_at or nil,
    }
end

--- Fahrer meldet vor der Abmeldung den aktuellen Zustand seines zugewiesenen
--- Fahrzeugs (Tankstand, Mängel, ggf. Werkstatt nötig). Wird von der NUI vor
--- dem tatsächlichen Logout erzwungen (siehe app.js requestLogout()).
--- Hat der Fahrer kein Fahrzeug zugewiesen, passiert einfach nichts.
function Vehicles.ReportCondition(src, fuel, notes, needsWorkshop)
    local emp = Employees.RequireRole(src, { Config.Roles.FAHRER })
    local driver = Drivers.EnsureDriverRecord(emp.id)

    if not driver.assigned_vehicle_id then
        return { ok = true, reported = false }
    end

    local vehicle = Vehicles.GetById(driver.assigned_vehicle_id)
    if not vehicle then
        return { ok = true, reported = false }
    end

    fuel = Utils.SanitizeNumber(fuel, 0, 100)
    if fuel == nil then fuel = vehicle.fuel end
    notes = Utils.SanitizeString(notes, 500)

    local newNotes = vehicle.notes
    if notes then
        local entry = ('[%s] %s: %s'):format(Utils.Now(), emp.name, notes)
        newNotes = vehicle.notes and (vehicle.notes .. '\n' .. entry) or entry
    end

    local newStatus = vehicle.status
    if needsWorkshop and not Config.VehicleBlockedForDispatch[vehicle.status] then
        newStatus = 'wartung'
    end

    MySQL.update.await('UPDATE st_vehicles SET fuel = ?, notes = ?, status = ? WHERE id = ?', { fuel, newNotes, newStatus, vehicle.id })
    logVehicleEvent(vehicle.id, 'condition_report', ('%s hat Tankstand (%s%%) und Zustand gemeldet%s.'):format(emp.name, fuel, needsWorkshop and ' (Werkstatt erforderlich)' or ''))
    Logs.Write(emp.id, 'vehicle_condition_report', ('%s hat den Zustand von %s (%s) gemeldet.'):format(emp.name, vehicle.name, vehicle.plate))

    RPC.PushToRole(Config.Roles.DISPONENT, 'fleet:changed', {})
    RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'fleet:changed', {})

    return { ok = true, reported = true }
end

-- =========================================================
-- RPC-Handler
-- =========================================================

RPC.Register('gf:vehicles:list', function(src, payload)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    return { vehicles = Vehicles.List(payload.includeArchived == true) }
end)

RPC.Register('gf:vehicles:create', function(src, payload)
    return Vehicles.Create(src, payload)
end)

RPC.Register('gf:vehicles:update', function(src, payload)
    local vehicleId = Utils.SanitizeNumber(payload.vehicleId, 1)
    if not vehicleId then error('invalid_vehicle') end
    return Vehicles.Update(src, vehicleId, payload)
end)

RPC.Register('gf:vehicles:delete', function(src, payload)
    local vehicleId = Utils.SanitizeNumber(payload.vehicleId, 1)
    if not vehicleId then error('invalid_vehicle') end
    return Vehicles.Delete(src, vehicleId, payload.mode)
end)

RPC.Register('gf:vehicles:reactivate', function(src, payload)
    local vehicleId = Utils.SanitizeNumber(payload.vehicleId, 1)
    if not vehicleId then error('invalid_vehicle') end
    return Vehicles.Reactivate(src, vehicleId)
end)

RPC.Register('gf:vehicles:assign', function(src, payload)
    local vehicleId = Utils.SanitizeNumber(payload.vehicleId, 1)
    if not vehicleId then error('invalid_vehicle') end
    local driverId = Utils.SanitizeNumber(payload.driverId, 1)
    return Vehicles.Assign(src, vehicleId, driverId)
end)

RPC.Register('gf:vehicles:file', function(src, payload)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    local vehicleId = Utils.SanitizeNumber(payload.vehicleId, 1)
    if not vehicleId then error('invalid_vehicle') end
    return Vehicles.GetFile(vehicleId)
end)

RPC.Register('driver:reportVehicleCondition', function(src, payload)
    return Vehicles.ReportCondition(src, payload.fuel, payload.notes, payload.needsWorkshop == true)
end)
