-- =========================================================
-- Aufträge: automatische Generierung, Disposition, Lebenszyklus
--
-- Der Client kann NIEMALS "Auftrag abgeschlossen" oder einen
-- Auszahlungsbetrag selbst setzen - jeder Statuswechsel wird hier
-- serverseitig gegen den tatsächlichen, in der DB gespeicherten
-- Auftragsstatus samt Fahrer-/Fahrzeugzuordnung geprüft.
-- =========================================================

Orders = {}

-- Frachtstatus-Fortschritt NACH der Annahme, automatisch getrieben durch die
-- Tasteninteraktion (E) an den Standort-NPCs (siehe client/cl_orders.lua):
-- anfahrt (zum Beladepunkt unterwegs) -> beladen (beladen, zum Zielort
-- unterwegs) -> entladen (wird gerade entladen) -> abgeschlossen (separat
-- über Orders.Complete()).
local CARGO_FLOW = { 'anfahrt', 'beladen', 'entladen' }

local function insertOrderHistory(orderId, status, changedBy, note)
    MySQL.insert.await(
        'INSERT INTO st_order_history (order_id, status, changed_by, note) VALUES (?, ?, ?, ?)',
        { orderId, status, changedBy, note }
    )
end

--- Prüft, ob ein Fahrer eine bestimmte Fahrerberechtigung besitzt (z.B.
--- "gefahrgut"). Wird u.a. genutzt, um Gefahrgut-Aufträge NICHT an Fahrer
--- ohne die passende Berechtigung disponieren/neu zuweisen zu können.
local function driverHasPermission(driverId, permissionKey)
    if not permissionKey then return true end
    local row = MySQL.single.await(
        'SELECT 1 AS ok FROM st_driver_permissions WHERE driver_id = ? AND permission_key = ? LIMIT 1',
        { driverId, permissionKey }
    )
    return row ~= nil
end

--- Prüft, ob gerade ein Disponent ODER die Geschäftsführung online UND am
--- Tablet erkannt ist (d.h. das Tablet in dieser Verbindung schon einmal
--- geöffnet hat). Nur wenn das NICHT der Fall ist, dürfen Fahrer sich
--- offene Aufträge selbst zuweisen.
local function isDispatcherAvailable()
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local emp = Employees.GetLoggedIn(src)
        if emp and Utils.InTable({ Config.Roles.DISPONENT, Config.Roles.GESCHAEFTSFUEHRUNG }, emp.role) then
            return true
        end
    end
    return false
end

function Orders.GetById(orderId)
    return MySQL.single.await('SELECT * FROM st_orders WHERE id = ? LIMIT 1', { orderId })
end

function Orders.CountOpen()
    local row = MySQL.single.await("SELECT COUNT(*) AS c FROM st_orders WHERE status = 'offen'")
    return row and tonumber(row.c) or 0
end

-- ---------------------------------------------------------
-- Frachtart -> mögliche Abhol-/Zielstandorte (aus Config.Locations
-- aufgebaut, siehe dort für die Erklärung von sourceCargo/destCargo).
-- ---------------------------------------------------------

local sourcesByCargo = {}
local destsByCargo = {}
for _, loc in ipairs(Config.Locations) do
    for _, cargo in ipairs(loc.sourceCargo or {}) do
        sourcesByCargo[cargo] = sourcesByCargo[cargo] or {}
        table.insert(sourcesByCargo[cargo], loc)
    end
    for _, cargo in ipairs(loc.destCargo or {}) do
        destsByCargo[cargo] = destsByCargo[cargo] or {}
        table.insert(destsByCargo[cargo], loc)
    end
end

--- Distanz zwischen zwei Standorten in km (echte Luftlinie aus den
--- konfigurierten Weltkoordinaten - keine Streckenpflege mehr nötig).
local function locationDistanceKm(a, b)
    local dx, dy, dz = a.coords.x - b.coords.x, a.coords.y - b.coords.y, a.coords.z - b.coords.z
    return math.sqrt(dx * dx + dy * dy + dz * dz) / 1000.0
end

--- Erzeugt einen neuen, unbearbeiteten Pool-Auftrag: wählt eine Frachtart,
--- für die es mindestens einen Abhol- UND einen (anderen) Zielstandort
--- gibt, und berechnet Distanz/Wert/Menge daraus.
function Orders.GenerateOne()
    local possibleCargoTypes = {}
    for cargo in pairs(sourcesByCargo) do
        if destsByCargo[cargo] then
            possibleCargoTypes[#possibleCargoTypes + 1] = cargo
        end
    end
    if #possibleCargoTypes == 0 then return nil end

    local cargo = possibleCargoTypes[math.random(1, #possibleCargoTypes)]
    local sources = sourcesByCargo[cargo]
    local dests = destsByCargo[cargo]

    local from = sources[math.random(1, #sources)]
    local to = dests[math.random(1, #dests)]
    if to.name == from.name then
        -- Einziger möglicher "Umweg": bei nur einem Ziel, das zufällig mit
        -- der Quelle identisch ist, diesen Durchlauf einfach überspringen.
        if #dests <= 1 then return nil end
        repeat
            to = dests[math.random(1, #dests)]
        until to.name ~= from.name
    end

    local distanceKm = Utils.Round2(locationDistanceKm(from, to))
    local value = Utils.Round2(distanceKm * (Config.OrderValuePerKm.min + math.random() * (Config.OrderValuePerKm.max - Config.OrderValuePerKm.min)))
    local requiresPermission = Utils.InTable(Config.HazardousCargo, cargo) and 'gefahrgut' or nil

    local unitCfg = Config.CargoUnits[cargo]
    local cargoAmount = unitCfg and math.random(unitCfg.min, unitCfg.max) or nil
    local cargoUnit = unitCfg and unitCfg.unit or nil

    local orderId = MySQL.insert.await(
        [[INSERT INTO st_orders (cargo, start_location, end_location, distance_km, value, status, source, requires_permission, cargo_amount, cargo_unit)
          VALUES (?, ?, ?, ?, ?, 'offen', 'auto', ?, ?, ?)]],
        { cargo, from.name, to.name, distanceKm, value, requiresPermission, cargoAmount, cargoUnit }
    )

    insertOrderHistory(orderId, 'offen', nil, 'Automatisch generiert.')
    RPC.PushToRole(Config.Roles.DISPONENT, 'orders:newOpenOrder', { orderId = orderId })
    RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'orders:newOpenOrder', { orderId = orderId })

    return orderId
end

CreateThread(function()
    while true do
        Wait(Config.OrderGeneration.intervalMs or 360000)
        if Config.OrderGeneration.enabled then
            local ok, err = pcall(function()
                if Orders.CountOpen() < (Config.OrderGeneration.maxOpenOrders or 12) then
                    Orders.GenerateOne()
                end
            end)
            if not ok then
                print('^1[speditions-tablet]^7 Fehler bei automatischer Auftragsgenerierung:', err)
            end
        end
    end
end)

local ORDER_JOIN_SELECT = [[
    SELECT o.*, de.name AS driver_name, v.name AS vehicle_name, v.plate AS vehicle_plate,
           disp.name AS dispatcher_name
    FROM st_orders o
    LEFT JOIN st_drivers d ON d.id = o.driver_id
    LEFT JOIN st_employees de ON de.id = d.employee_id
    LEFT JOIN st_vehicles v ON v.id = o.vehicle_id
    LEFT JOIN st_employees disp ON disp.id = o.dispatcher_id
]]

function Orders.ListOpen()
    return MySQL.query.await(ORDER_JOIN_SELECT .. " WHERE o.status = 'offen' ORDER BY o.created_at ASC")
end

function Orders.ListActive()
    return MySQL.query.await(ORDER_JOIN_SELECT .. [[
        WHERE o.status IN ('disponiert', 'angenommen', 'anfahrt', 'beladen', 'entladen')
        ORDER BY o.created_at ASC
    ]])
end

function Orders.ListCompleted(limit)
    limit = Utils.SanitizeNumber(limit, 1, 300) or 50
    return MySQL.query.await(ORDER_JOIN_SELECT .. [[
        WHERE o.status IN ('abgeschlossen', 'abgebrochen', 'abgelehnt')
        ORDER BY o.completed_at DESC
        LIMIT ?
    ]], { limit })
end

function Orders.ListAll(limit, statusFilter)
    limit = Utils.SanitizeNumber(limit, 1, 500) or 100
    local where = ''
    local params = {}
    local validStatuses = { 'offen', 'disponiert', 'angenommen', 'anfahrt', 'beladen', 'entladen', 'unterwegs', 'abgeschlossen', 'abgebrochen', 'abgelehnt' }
    if statusFilter and Utils.InTable(validStatuses, statusFilter) then
        where = 'WHERE o.status = ?'
        params[#params + 1] = statusFilter
    end
    params[#params + 1] = limit
    return MySQL.query.await(ORDER_JOIN_SELECT .. (' %s ORDER BY o.created_at DESC LIMIT ?'):format(where), params)
end

function Orders.MyOrders(driverId)
    return MySQL.query.await(ORDER_JOIN_SELECT .. [[
        WHERE o.driver_id = ? AND o.status IN ('disponiert', 'angenommen', 'anfahrt', 'beladen', 'entladen')
        ORDER BY o.created_at ASC
    ]], { driverId })
end

--- Reichert Aufträge um die GPS-Koordinaten ihres Abhol-/Zielstandorts an
--- (für den ausführlichen Lieferschein im Tablet). Nur x/y, da die Höhe (z)
--- für die Anzeige im Tablet nicht relevant ist.
function Orders.AttachLocationCoords(orders)
    for _, o in ipairs(orders) do
        local from = Utils.GetLocationByName(o.start_location)
        local to = Utils.GetLocationByName(o.end_location)
        o.start_coords = from and { x = Utils.Round2(from.coords.x), y = Utils.Round2(from.coords.y) } or nil
        o.end_coords = to and { x = Utils.Round2(to.coords.x), y = Utils.Round2(to.coords.y) } or nil
    end
    return orders
end

--- Weist einen offenen (oder neu zu disponierenden) Auftrag einem Fahrer zu.
function Orders.Dispatch(src, orderId, driverId, vehicleId)
    local emp = Employees.RequireRole(src, { Config.Roles.DISPONENT, Config.Roles.GESCHAEFTSFUEHRUNG })

    local order = Orders.GetById(orderId)
    if not order then error('order_not_found') end
    if order.status ~= 'offen' then error('order_not_open') end

    local driver = MySQL.single.await('SELECT d.*, e.name, e.status AS emp_status FROM st_drivers d JOIN st_employees e ON e.id = d.employee_id WHERE d.id = ?', { driverId })
    if not driver or driver.emp_status ~= 'aktiv' then error('driver_not_found') end

    if not driverHasPermission(driverId, order.requires_permission) then
        error('driver_missing_permission')
    end

    local finalVehicleId = vehicleId
    if not finalVehicleId or finalVehicleId == 0 then
        finalVehicleId = driver.assigned_vehicle_id
    end

    if finalVehicleId then
        local vehicle = Vehicles.GetById(finalVehicleId)
        if not vehicle then error('vehicle_not_found') end
        if Utils.ToBool(vehicle.archived) then error('vehicle_archived') end
        if Config.VehicleBlockedForDispatch[vehicle.status] then error('vehicle_unavailable') end
    end

    MySQL.update.await(
        "UPDATE st_orders SET driver_id = ?, vehicle_id = ?, dispatcher_id = ?, status = 'disponiert' WHERE id = ?",
        { driverId, finalVehicleId, emp.id, orderId }
    )
    insertOrderHistory(orderId, 'disponiert', emp.id, ('Disponiert von %s an %s.'):format(emp.name, driver.name))

    Notifications.Send(nil, driver.employee_id, 'Neuer Auftrag', ('Dir wurde Auftrag #%s zugewiesen (%s -> %s).'):format(orderId, order.start_location, order.end_location), emp.id)
    local driverSrc = Utils.FindSrcByEmployeeId(driver.employee_id)
    if driverSrc then
        Utils.NotifyClient(driverSrc, ('Neuer Auftrag #%s: %s -> %s. Oeffne dein Tablet fuer Details.'):format(orderId, order.start_location, order.end_location), 'info')
    end

    return { ok = true }
end

--- Erlaubt einem Fahrer, sich einen offenen Auftrag SELBST zuzuweisen -
--- aber NUR, solange gerade kein Disponent/Geschäftsführung online ist.
--- Sobald wieder ein Disponent verfügbar ist, greift wieder die normale
--- Disposition (Orders.Dispatch). Nach der Selbstzuweisung läuft der
--- Auftrag wie gewohnt über Orders.AcceptByDriver weiter.
function Orders.SelfAssign(src, orderId)
    local emp = Employees.RequireRole(src, { Config.Roles.FAHRER })
    local driver = Drivers.EnsureDriverRecord(emp.id)

    if isDispatcherAvailable() then error('dispatcher_available') end

    local order = Orders.GetById(orderId)
    if not order then error('order_not_found') end
    if order.status ~= 'offen' then error('order_not_open') end

    if not driverHasPermission(driver.id, order.requires_permission) then
        error('driver_missing_permission')
    end

    local vehicleId = driver.assigned_vehicle_id
    if vehicleId then
        local vehicle = Vehicles.GetById(vehicleId)
        if not vehicle then error('vehicle_not_found') end
        if Utils.ToBool(vehicle.archived) then error('vehicle_archived') end
        if Config.VehicleBlockedForDispatch[vehicle.status] then error('vehicle_unavailable') end
    end

    MySQL.update.await(
        "UPDATE st_orders SET driver_id = ?, vehicle_id = ?, dispatcher_id = NULL, status = 'disponiert' WHERE id = ?",
        { driver.id, vehicleId, orderId }
    )
    insertOrderHistory(orderId, 'disponiert', emp.id, ('%s hat sich den Auftrag selbst zugewiesen (kein Disponent online).'):format(emp.name))

    RPC.PushToRole(Config.Roles.DISPONENT, 'orders:activeChanged', { orderId = orderId })
    RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'orders:activeChanged', { orderId = orderId })

    return { ok = true }
end

function Orders.Reassign(src, orderId, newDriverId)
    local emp = Employees.RequireRole(src, { Config.Roles.DISPONENT, Config.Roles.GESCHAEFTSFUEHRUNG })

    local order = Orders.GetById(orderId)
    if not order then error('order_not_found') end
    if not Utils.InTable({ 'disponiert', 'angenommen', 'anfahrt', 'beladen' }, order.status) then
        error('order_not_reassignable')
    end

    local driver = MySQL.single.await('SELECT d.*, e.name, e.status AS emp_status FROM st_drivers d JOIN st_employees e ON e.id = d.employee_id WHERE d.id = ?', { newDriverId })
    if not driver or driver.emp_status ~= 'aktiv' then error('driver_not_found') end

    if not driverHasPermission(newDriverId, order.requires_permission) then
        error('driver_missing_permission')
    end

    MySQL.update.await(
        "UPDATE st_orders SET driver_id = ?, vehicle_id = ?, status = 'disponiert', accepted_at = NULL WHERE id = ?",
        { newDriverId, driver.assigned_vehicle_id, orderId }
    )
    insertOrderHistory(orderId, 'disponiert', emp.id, ('Neu disponiert von %s an %s.'):format(emp.name, driver.name))

    Notifications.Send(nil, driver.employee_id, 'Auftrag neu zugewiesen', ('Auftrag #%s wurde dir neu zugewiesen.'):format(orderId), emp.id)
    local driverSrc = Utils.FindSrcByEmployeeId(driver.employee_id)
    if driverSrc then
        Utils.NotifyClient(driverSrc, ('Auftrag #%s wurde dir neu zugewiesen.'):format(orderId), 'info')
    end

    return { ok = true }
end

local function requireOwnOrder(src, orderId)
    local emp = Employees.RequireRole(src, { Config.Roles.FAHRER })
    local driver = Drivers.EnsureDriverRecord(emp.id)
    local order = Orders.GetById(orderId)
    if not order then error('order_not_found') end
    if order.driver_id ~= driver.id then error('not_your_order') end
    return emp, driver, order
end

function Orders.AcceptByDriver(src, orderId)
    local emp, driver, order = requireOwnOrder(src, orderId)
    if order.status ~= 'disponiert' then error('order_not_pending') end
    if not Utils.ToBool(driver.on_shift) then error('shift_not_started') end

    local minutes = (tonumber(order.distance_km) / (Config.AverageSpeedKmh or 65)) * 60 + (Config.DeadlineBufferMinutes or 8)

    MySQL.update.await(
        "UPDATE st_orders SET status = 'angenommen', accepted_at = NOW(), deadline = DATE_ADD(NOW(), INTERVAL ? MINUTE) WHERE id = ?",
        { minutes, orderId }
    )
    insertOrderHistory(orderId, 'angenommen', emp.id, ('%s hat den Auftrag angenommen.'):format(emp.name))

    -- Direkter automatischer Übergang: sobald angenommen, beginnt sofort die
    -- Anfahrt zum Beladepunkt - keine separate manuelle Bestätigung nötig.
    MySQL.update.await("UPDATE st_orders SET status = 'anfahrt' WHERE id = ?", { orderId })
    insertOrderHistory(orderId, 'anfahrt', emp.id, 'Anfahrt zum Beladepunkt gestartet.')

    Utils.SetClientWaypoint(src, order.start_location, ('Beladepunkt (%s)'):format(order.start_location))

    RPC.PushToRole(Config.Roles.DISPONENT, 'orders:activeChanged', { orderId = orderId })
    RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'orders:activeChanged', { orderId = orderId })

    return { ok = true }
end

function Orders.DeclineByDriver(src, orderId, reason)
    local emp, driver, order = requireOwnOrder(src, orderId)
    if order.status ~= 'disponiert' then error('order_not_pending') end

    reason = Utils.SanitizeString(reason, 255) or 'Kein Grund angegeben'

    MySQL.update.await("UPDATE st_orders SET status = 'abgelehnt', completed_at = NOW() WHERE id = ?", { orderId })
    insertOrderHistory(orderId, 'abgelehnt', emp.id, ('%s hat abgelehnt: %s'):format(emp.name, reason))

    Drivers.RecomputeStatistics(driver.id)

    RPC.PushToRole(Config.Roles.DISPONENT, 'orders:activeChanged', { orderId = orderId })
    RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'orders:activeChanged', { orderId = orderId })

    return { ok = true }
end

--- Frachtstatus-Fortschritt: anfahrt -> beladen -> entladen.
function Orders.UpdateCargoStatus(src, orderId, newStatus)
    local emp, driver, order = requireOwnOrder(src, orderId)

    local currentIdx, targetIdx
    for i, s in ipairs(CARGO_FLOW) do
        if s == order.status then currentIdx = i end
        if s == newStatus then targetIdx = i end
    end

    if not targetIdx or not currentIdx or targetIdx ~= currentIdx + 1 then
        error('invalid_status_transition')
    end

    MySQL.update.await('UPDATE st_orders SET status = ? WHERE id = ?', { newStatus, orderId })
    insertOrderHistory(orderId, newStatus, emp.id, nil)

    if newStatus == 'beladen' then
        if order.vehicle_id then
            MySQL.update.await("UPDATE st_vehicles SET status = 'im_einsatz' WHERE id = ? AND status = 'verfuegbar'", { order.vehicle_id })
        end
        Utils.SetClientWaypoint(src, order.end_location, ('Zielort (%s)'):format(order.end_location))
    end

    RPC.PushToRole(Config.Roles.DISPONENT, 'orders:activeChanged', { orderId = orderId })
    RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'orders:activeChanged', { orderId = orderId })

    return { ok = true, status = newStatus }
end

function Orders.Complete(src, orderId)
    local emp, driver, order = requireOwnOrder(src, orderId)
    if order.status ~= 'entladen' then error('order_not_in_transit') end

    local punctual = 1
    if order.deadline then
        local deadlineRow = MySQL.single.await('SELECT (NOW() <= ?) AS ok FROM dual', { order.deadline })
        punctual = (deadlineRow and tonumber(deadlineRow.ok) == 1) and 1 or 0
    end

    MySQL.update.await(
        "UPDATE st_orders SET status = 'abgeschlossen', completed_at = NOW(), punctual = ? WHERE id = ?",
        { punctual, orderId }
    )
    insertOrderHistory(orderId, 'abgeschlossen', emp.id, ('%s hat den Auftrag abgeschlossen (%s).'):format(emp.name, punctual == 1 and 'pünktlich' or 'verspätet'))

    if order.vehicle_id then
        MySQL.update.await('UPDATE st_vehicles SET mileage = mileage + ? WHERE id = ?', { math.floor(tonumber(order.distance_km) + 0.5), order.vehicle_id })
        MySQL.update.await("UPDATE st_vehicles SET status = 'verfuegbar' WHERE id = ? AND status = 'im_einsatz'", { order.vehicle_id })
        Vehicles.LogEvent(order.vehicle_id, 'order_completed', ('Auftrag #%s abgeschlossen von %s.'):format(orderId, emp.name), orderId)
    end

    Finance.RecordOrderRevenue(orderId, driver.id, order.value, ('Auftrag #%s abgeschlossen (%s -> %s)'):format(orderId, order.start_location, order.end_location))
    Drivers.RecomputeStatistics(driver.id)

    Logs.Write(emp.id, 'order_completed', ('%s hat Auftrag #%s abgeschlossen. +%s Unternehmensumsatz.'):format(emp.name, orderId, order.value))

    RPC.PushToRole(Config.Roles.DISPONENT, 'orders:completed', { orderId = orderId })
    RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'orders:completed', { orderId = orderId })

    return { ok = true, value = order.value }
end

--- Bricht einen aktiven Auftrag ab (Disponent/GF, z.B. wenn ein Fahrer nicht
--- mehr reagiert). Fahrzeug wird wieder freigegeben.
function Orders.Cancel(src, orderId, reason)
    local emp = Employees.RequireRole(src, { Config.Roles.DISPONENT, Config.Roles.GESCHAEFTSFUEHRUNG })
    local order = Orders.GetById(orderId)
    if not order then error('order_not_found') end
    if Utils.InTable({ 'abgeschlossen', 'abgebrochen', 'abgelehnt' }, order.status) then
        error('order_already_closed')
    end

    reason = Utils.SanitizeString(reason, 255) or 'Kein Grund angegeben'

    MySQL.update.await("UPDATE st_orders SET status = 'abgebrochen', completed_at = NOW() WHERE id = ?", { orderId })
    insertOrderHistory(orderId, 'abgebrochen', emp.id, ('%s hat abgebrochen: %s'):format(emp.name, reason))

    if order.vehicle_id then
        MySQL.update.await("UPDATE st_vehicles SET status = 'verfuegbar' WHERE id = ? AND status = 'im_einsatz'", { order.vehicle_id })
    end

    if order.driver_id then
        Drivers.RecomputeStatistics(order.driver_id)
        local driver = Drivers.GetById(order.driver_id)
        if driver then
            Notifications.Send(nil, driver.employee_id, 'Auftrag abgebrochen', ('Auftrag #%s wurde von %s abgebrochen: %s'):format(orderId, emp.name, reason), emp.id)
        end
    end

    Logs.Write(emp.id, 'order_cancelled', ('%s hat Auftrag #%s abgebrochen: %s'):format(emp.name, orderId, reason))

    RPC.PushToRole(Config.Roles.DISPONENT, 'orders:activeChanged', { orderId = orderId })
    RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'orders:activeChanged', { orderId = orderId })

    return { ok = true }
end

-- =========================================================
-- RPC-Handler
-- =========================================================

RPC.Register('dispatch:openOrders', function(src)
    Employees.RequireRole(src, { Config.Roles.DISPONENT, Config.Roles.GESCHAEFTSFUEHRUNG })
    return { orders = Orders.ListOpen() }
end)

RPC.Register('dispatch:activeOrders', function(src)
    Employees.RequireRole(src, { Config.Roles.DISPONENT, Config.Roles.GESCHAEFTSFUEHRUNG })
    return { orders = Orders.ListActive() }
end)

RPC.Register('dispatch:completedOrders', function(src, payload)
    Employees.RequireRole(src, { Config.Roles.DISPONENT, Config.Roles.GESCHAEFTSFUEHRUNG })
    return { orders = Orders.ListCompleted(payload.limit) }
end)

RPC.Register('dispatch:assignOrder', function(src, payload)
    local orderId = Utils.SanitizeNumber(payload.orderId, 1)
    local driverId = Utils.SanitizeNumber(payload.driverId, 1)
    if not orderId or not driverId then error('invalid_payload') end
    return Orders.Dispatch(src, orderId, driverId, Utils.SanitizeNumber(payload.vehicleId, 1))
end)

RPC.Register('dispatch:reassignOrder', function(src, payload)
    local orderId = Utils.SanitizeNumber(payload.orderId, 1)
    local driverId = Utils.SanitizeNumber(payload.driverId, 1)
    if not orderId or not driverId then error('invalid_payload') end
    return Orders.Reassign(src, orderId, driverId)
end)

RPC.Register('dispatch:cancelOrder', function(src, payload)
    local orderId = Utils.SanitizeNumber(payload.orderId, 1)
    if not orderId then error('invalid_payload') end
    return Orders.Cancel(src, orderId, payload.reason)
end)

RPC.Register('driver:myOrders', function(src)
    local emp = Employees.RequireRole(src, { Config.Roles.FAHRER })
    local driver = Drivers.EnsureDriverRecord(emp.id)
    return { orders = Orders.AttachLocationCoords(Orders.MyOrders(driver.id)) }
end)

--- Offener Auftragspool für Fahrer - zum Selbst-Übernehmen, wenn gerade
--- kein Disponent verfügbar ist (siehe dispatcherAvailable im Ergebnis).
RPC.Register('driver:openOrders', function(src)
    local emp = Employees.RequireRole(src, { Config.Roles.FAHRER })
    local driver = Drivers.EnsureDriverRecord(emp.id)
    return {
        orders = Orders.ListOpen(),
        dispatcherAvailable = isDispatcherAvailable(),
        onShift = Utils.ToBool(driver.on_shift),
        debugEnabled = Config.AllowManualOrderGeneration == true,
    }
end)

--- Nur zum Testen (siehe Config.AllowManualOrderGeneration): erzeugt sofort
--- einen neuen Pool-Auftrag, unabhängig vom automatischen Intervall.
RPC.Register('driver:debugGenerateOrder', function(src)
    Employees.RequireRole(src, { Config.Roles.FAHRER })
    if not Config.AllowManualOrderGeneration then error('unknown_action') end
    local orderId = Orders.GenerateOne()
    if not orderId then error('no_cargo_route_available') end
    return { ok = true, orderId = orderId }
end)

RPC.Register('driver:selfAssignOrder', function(src, payload)
    local orderId = Utils.SanitizeNumber(payload.orderId, 1)
    if not orderId then error('invalid_payload') end
    return Orders.SelfAssign(src, orderId)
end)

RPC.Register('driver:acceptOrder', function(src, payload)
    local orderId = Utils.SanitizeNumber(payload.orderId, 1)
    if not orderId then error('invalid_payload') end
    return Orders.AcceptByDriver(src, orderId)
end)

RPC.Register('driver:declineOrder', function(src, payload)
    local orderId = Utils.SanitizeNumber(payload.orderId, 1)
    if not orderId then error('invalid_payload') end
    return Orders.DeclineByDriver(src, orderId, payload.reason)
end)

RPC.Register('driver:updateCargoStatus', function(src, payload)
    local orderId = Utils.SanitizeNumber(payload.orderId, 1)
    if not orderId then error('invalid_payload') end
    return Orders.UpdateCargoStatus(src, orderId, payload.status)
end)

RPC.Register('driver:completeOrder', function(src, payload)
    local orderId = Utils.SanitizeNumber(payload.orderId, 1)
    if not orderId then error('invalid_payload') end
    return Orders.Complete(src, orderId)
end)

RPC.Register('gf:orders:all', function(src, payload)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    return { orders = Orders.ListAll(payload.limit, payload.statusFilter) }
end)
