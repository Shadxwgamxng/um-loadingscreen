-- =========================================================
-- Website-Sync (Config.Website)
--
-- Synchronisiert Aufträge/Disposition, Fuhrpark, Fahrerkarte/Lenkzeiten und
-- Mitarbeiterkonten mit der separaten Speditions-Website. Läuft
-- ausschließlich über AUSGEHENDE HTTP-Requests vom FiveM-Server:
--   - Push: bei jeder relevanten Änderung wird sofort ein Event an
--     .../api/tablet/webhook geschickt (WebsiteBridge.PushEvent, aufgerufen
--     aus server/sv_employees.lua, sv_orders.lua, sv_vehicles.lua).
--   - Pull: alle Config.Website.pollIntervalMs wird .../api/tablet/commands
--     abgefragt - Dispositionsaktionen, die auf der Website für einen
--     "tablet"-Auftrag ausgelöst wurden, werden hier ausgeführt und das
--     Ergebnis über .../api/tablet/commands/{id}/ack zurückgemeldet.
-- Der Spielserver muss dafür KEINEN eingehenden Port öffnen. Komplett
-- inaktiv (keine einzige Anfrage), solange Config.Website.enabled = false
-- ist (Standard).
-- =========================================================

WebsiteBridge = {}

local function websiteConfigured()
    return Config.Website and Config.Website.enabled and Config.Website.baseUrl and Config.Website.apiKey
        and Config.Website.apiKey ~= 'CHANGE_ME'
end

--- Führt einen HTTP-Request gegen die Website-API aus. No-op (ruft cb nicht
--- auf), solange Config.Website nicht vollständig konfiguriert ist. Fehler
--- werden nur geloggt - ein Website-Ausfall darf den Spielserver niemals
--- blockieren oder eine Aktion im Tablet fehlschlagen lassen.
local function apiRequest(method, path, bodyTable, cb)
    if not websiteConfigured() then return end

    local url = Config.Website.baseUrl .. path
    local headers = { ['Content-Type'] = 'application/json; charset=UTF-8', ['X-Api-Key'] = Config.Website.apiKey }
    local body = bodyTable and json.encode(bodyTable) or ''

    PerformHttpRequest(url, function(statusCode, responseText, _responseHeaders)
        local ok = type(statusCode) == 'number' and statusCode >= 200 and statusCode < 300

        local decoded = nil
        if responseText and responseText ~= '' then
            local success, result = pcall(json.decode, responseText)
            if success then decoded = result end
        end

        if not ok then
            local reason = (decoded and decoded.error) or (responseText ~= '' and responseText) or 'keine Antwort (Server nicht erreichbar/Timeout?)'
            print(('^1[speditions-tablet]^7 Website-Sync: %s %s fehlgeschlagen (HTTP %s): %s'):format(method, path, tostring(statusCode), tostring(reason)))
        end

        if not cb then return end
        cb(ok, statusCode, decoded)
    end, method, body, headers)
end

--- Meldet ein Ereignis an die Website (siehe README "Website-Sync" für die
--- Event-Typen). Aufrufer prüfen selbst NICHT, ob Website-Sync aktiv ist -
--- das übernimmt apiRequest (websiteConfigured()). Der Erfolgsfall wird nur
--- noch mit Config.Debug = true geloggt (Utils.DebugPrint) - bei jedem
--- erfolgreichen Sync unbedingt zu drucken war beim ursprünglichen Aufbau
--- hilfreich (Serverkonsole war sonst komplett still), im Dauerbetrieb aber
--- reiner Lärm, weil Sync-Ereignisse ständig feuern (jede Statusänderung,
--- Lenkzeit-Meldungen alle 60s, ...). Fehlschläge (siehe apiRequest oben)
--- werden weiterhin unbedingt gedruckt.
function WebsiteBridge.PushEvent(eventType, data)
    apiRequest('POST', '/api/tablet/webhook', { type = eventType, data = data }, function(ok)
        if ok then
            Utils.DebugPrint(('Website-Sync: Ereignis "%s" erfolgreich übertragen.'):format(eventType))
        end
    end)
end

--- Meldet einen Mitarbeiter an die Website. Erfordert, dass seiner Rolle im
--- Rollen-Editor bereits eine Website-Rolle zugeordnet wurde
--- (Roles.SetWebsiteRoleKey) - ohne Zuordnung wird NICHT synchronisiert
--- (kein Rätselraten, welche der 9 Website-Rollen gemeint sein könnte).
function WebsiteBridge.PushEmployeeUpdate(employeeId)
    if not websiteConfigured() then return end
    local emp = MySQL.single.await('SELECT * FROM st_employees WHERE id = ?', { employeeId })
    if not emp then return end

    local websiteRoleKey = Roles.GetWebsiteRoleKey(emp.role)
    if not websiteRoleKey then
        Utils.DebugPrint(('Website-Sync: Rolle "%s" hat keine Website-Rolle zugeordnet - Mitarbeiter #%s wird nicht synchronisiert.'):format(emp.role, employeeId))
        return
    end

    WebsiteBridge.PushEvent('employee.upsert', {
        tabletEmployeeId = emp.id,
        name = emp.name,
        discordId = emp.discord_id,
        websiteRoleKey = websiteRoleKey,
        status = emp.status,
    })
end

--- Meldet den aktuellen Zustand eines Auftrags an die Website (Fahrer-/
--- Fahrzeugname statt interner IDs, da die Website nur diese kennt).
function WebsiteBridge.PushOrderUpdate(orderId)
    if not websiteConfigured() then return end
    local order = Orders.GetById(orderId)
    if not order then return end

    local driverName = nil
    if order.driver_id then
        local driver = Drivers.GetById(order.driver_id)
        if driver then
            local drvEmp = MySQL.single.await('SELECT name FROM st_employees WHERE id = ?', { driver.employee_id })
            driverName = drvEmp and drvEmp.name or nil
        end
    end

    local vehiclePlate = nil
    if order.vehicle_id then
        local vehicle = Vehicles.GetById(order.vehicle_id)
        vehiclePlate = vehicle and vehicle.plate or nil
    end

    WebsiteBridge.PushEvent('order.upsert', {
        tabletOrderId = order.id,
        cargo = order.cargo,
        startLocation = order.start_location,
        endLocation = order.end_location,
        distanceKm = tonumber(order.distance_km) or 0,
        status = order.status,
        driverName = driverName,
        vehiclePlate = vehiclePlate,
    })
end

--- Meldet den aktuellen Zustand eines Fahrzeugs an die Website - inklusive
--- des aktuell zugewiesenen Fahrers (falls einer per Drivers.StartShift/
--- EndShift oder Vehicles.Assign zugewiesen/freigegeben wurde), damit die
--- "Aktive Fahrzeuge"-Übersicht in der Website-Disposition den echten
--- Stand aus dem Spiel zeigt statt nur website-eigener Fahrzeug-Logins.
function WebsiteBridge.PushVehicleUpdate(vehicleId)
    if not websiteConfigured() then return end
    local vehicle = Vehicles.GetById(vehicleId)
    if not vehicle then return end

    local driverName, activeSince = nil, nil
    local assignment = MySQL.single.await([[
        SELECT e.name, va.assigned_at FROM st_vehicle_assignments va
        JOIN st_drivers d ON d.id = va.driver_id
        JOIN st_employees e ON e.id = d.employee_id
        WHERE va.vehicle_id = ? AND va.unassigned_at IS NULL
        ORDER BY va.assigned_at DESC LIMIT 1
    ]], { vehicleId })
    if assignment then
        driverName = assignment.name
        activeSince = assignment.assigned_at
    end

    WebsiteBridge.PushEvent('vehicle.upsert', {
        tabletVehicleId = vehicle.id,
        plate = vehicle.plate,
        vehicleClass = vehicle.vehicle_class,
        mileage = tonumber(vehicle.mileage) or 0,
        status = vehicle.status,
        driverName = driverName,
        activeSince = activeSince,
    })
end

--- Meldet einen Stempeluhr-Vorgang (Ein-/Ausstempeln) an die Website - siehe
--- Payroll.ClockIn/ClockOut/PayEmployee (server/sv_payroll.lua). `at` ist der
--- exakte Zeitpunkt, der auch in st_timeclock_sessions geschrieben wurde
--- (Utils.Now()), damit Tablet und Website nie leicht auseinanderlaufen.
function WebsiteBridge.PushTimeclockUpdate(tabletEmployeeId, clockedIn, at)
    if not websiteConfigured() then return end
    WebsiteBridge.PushEvent('timeclock.update', {
        tabletEmployeeId = tabletEmployeeId,
        clockedIn = clockedIn,
        at = at,
    })
end

--- Meldet Schichtbeginn/-ende (Fahrerkarte einstecken/abziehen) an die
--- Website - siehe Drivers.StartShift/EndShift (server/sv_drivers.lua).
function WebsiteBridge.PushDriverShiftUpdate(tabletEmployeeId, onShift)
    if not websiteConfigured() then return end
    WebsiteBridge.PushEvent('driver_shift.update', {
        tabletEmployeeId = tabletEmployeeId,
        onShift = onShift,
    })
end

--- Meldet eine abgeschlossene Fracht als Fahrtenbuch-Eintrag an die Website -
--- siehe Orders.Complete (server/sv_orders.lua). `tabletOrderId` ist der
--- Abgleichsschlüssel, damit ein erneuter Push (z.B. nach Ressourcen-Neustart)
--- niemals einen doppelten Eintrag im Website-Fahrtenbuch erzeugt.
function WebsiteBridge.PushTripReport(data)
    if not websiteConfigured() then return end
    WebsiteBridge.PushEvent('trip.report', data)
end

--- Meldet eine einzelne Firmenfinanz-Transaktion (Auftrags-Einnahme, Aus-/
--- Einzahlung, Gehalt) an die Website - siehe Finance.AddTransaction
--- (server/sv_finance.lua), der EINZIGE Schreibpfad für Firmengeld und
--- damit die einzige Stelle, die das aufruft. Läuft dadurch lückenlos für
--- jede Art von Bewegung, nicht nur für Aufträge.
function WebsiteBridge.PushFinanceTransaction(data)
    if not websiteConfigured() then return end
    WebsiteBridge.PushEvent('finance.transaction', data)
end

--- Meldet, dass beim Ressourcenstart alle im Spiel entstandenen Aufträge
--- zurückgesetzt wurden (siehe server/sv_orders.lua) - survivingTabletOrderIds
--- sind die st_orders.id der von der Website selbst angelegten Aufträge, die
--- diesen Reset überlebt haben. Die Website entfernt daraufhin jeden
--- origin:"tablet"-Auftrag, dessen tabletOrderId NICHT in dieser Liste steht -
--- ohne das blieben automatisch generierte/im Spiel abgebrochene Aufträge
--- nach jedem Neustart für immer in der Website-Disposition stehen, obwohl
--- sie im Tablet längst gelöscht sind.
function WebsiteBridge.PushOrdersReset(survivingTabletOrderIds)
    if not websiteConfigured() then return end
    WebsiteBridge.PushEvent('orders.reset', { survivingTabletOrderIds = survivingTabletOrderIds })
end

--- Meldet die gültigen Standortnamen (aus st_locations, siehe
--- server/sv_locations.lua) an die Website - Grundlage für die Auswahl bei
--- "Neuer Auftrag" auf der Website (siehe Orders.CreateFromWebsite:
--- Start-/Zielort müssen exakt einem dieser Namen entsprechen, weil daraus
--- Distanz/Wegpunkt/Bodenmarker berechnet werden). Wird beim
--- Ressourcenstart UND jedes Mal gepusht, wenn im Reiter "Orte" ein Ort
--- angelegt/bearbeitet/gelöscht wird (siehe Locations.Create/Update/Delete).
function WebsiteBridge.PushLocations()
    if not websiteConfigured() then return end
    local locations = {}
    for _, loc in ipairs(Locations.List()) do
        locations[#locations + 1] = { name = loc.name, sourceCargo = loc.sourceCargo, destCargo = loc.destCargo }
    end
    WebsiteBridge.PushEvent('locations.sync', { locations = locations, cargoTypes = Config.CargoTypes })
end

CreateThread(function()
    -- Kurze Verzögerung, damit ein etwaiger Server-Neustart erst durchläuft
    -- (Konfiguration/DB-Verbindung stehen dann sicher bereit).
    Wait(5000)
    WebsiteBridge.PushLocations()
end)


-- =========================================================
-- Periodische Lenkzeiten-Meldung
-- =========================================================

CreateThread(function()
    while true do
        Wait((Config.Website and Config.Website.driverHoursReportIntervalMs) or 60000)
        if websiteConfigured() then
            local onShiftDrivers = MySQL.query.await("SELECT id, employee_id FROM st_drivers WHERE on_shift = 1")
            for _, driver in ipairs(onShiftDrivers) do
                local status = Hours.Status(driver.id)
                WebsiteBridge.PushEvent('driver_hours.report', {
                    tabletEmployeeId = driver.employee_id,
                    dailyMinutes = status.dailyMinutes,
                    resting = status.resting,
                    restingSince = status.restingSince,
                })
            end
        end
    end
end)

-- =========================================================
-- Befehls-Polling (Website -> Tablet)
-- =========================================================

--- `assign_order`: Disponent hat auf der Website einem "tablet"-Auftrag ein
--- Fahrzeug zugewiesen. Die Website kennt nur das Kennzeichen, keine
--- Tablet-interne Fahrer-ID - Orders.DispatchFromWebsite ermittelt den
--- Fahrer selbst über die aktuelle Fahrzeugzuweisung.
local function handleAssignOrder(data)
    local orderId = tonumber(data.tabletOrderId)
    if not orderId then error('invalid_command_payload') end
    if not data.vehiclePlate or data.vehiclePlate == '' then error('no_vehicle_selected') end
    return Orders.DispatchFromWebsite(orderId, data.vehiclePlate)
end

--- `cancel_order`: Disponent hat auf der Website einen "tablet"-Auftrag
--- abgebrochen ("Im Spiel abbrechen").
local function handleCancelOrder(data)
    local orderId = tonumber(data.tabletOrderId)
    if not orderId then error('invalid_command_payload') end
    return Orders.CancelFromWebsite(orderId)
end

--- `create_order`: Disponent hat auf der Website einen neuen (Kunden-/
--- internen) Auftrag angelegt - landet im offenen Tablet-Auftragspool,
--- muss im Spiel noch disponiert werden (siehe Orders.CreateFromWebsite).
local function handleCreateOrder(data)
    local cargo = data.cargo
    if type(cargo) ~= 'string' or cargo == '' then error('invalid_command_payload') end
    return Orders.CreateFromWebsite(cargo, data.startLocation, data.endLocation, data.cargoAmount, data.cargoUnit)
end

--- `update_vehicle`: Disponent hat auf der Website Status/Kilometerstand
--- eines bereits bekannten Fahrzeugs geändert (Kennzeichen als
--- gemeinsamer Schlüssel, siehe Vehicles.UpdateFromWebsite).
local function handleUpdateVehicle(data)
    if type(data.plate) ~= 'string' or data.plate == '' then error('invalid_command_payload') end
    return Vehicles.UpdateFromWebsite(data.plate, data.status, data.mileage)
end

--- `create_employee`: Geschäftsführung hat auf der Website ein neues
--- Mitarbeiterkonto angelegt (inkl. eines dort abgefragten Passworts fürs
--- Tablet-Login, siehe Employees.HireFromWebsite).
local function handleCreateEmployee(data)
    if type(data.username) ~= 'string' or data.username == '' then error('invalid_command_payload') end
    if type(data.password) ~= 'string' or data.password == '' then error('invalid_command_payload') end
    return Employees.HireFromWebsite(data.username, data.password, data.name, data.websiteRoleKey, data.discordId, data.driverPermissions)
end

--- `update_driver_permissions`: Geschäftsführung hat auf der Website die
--- Führerscheinklassen eines bereits Tablet-verknüpften Mitarbeiters
--- geändert (voller Abgleich, siehe Drivers.SetPermissionsFromWebsite).
local function handleUpdateDriverPermissions(data)
    local employeeId = tonumber(data.tabletEmployeeId)
    if not employeeId then error('invalid_command_payload') end
    return Drivers.SetPermissionsFromWebsite(employeeId, data.permissions)
end

--- `deactivate_employee`: Geschäftsführung hat auf der Website ein mit dem
--- Tablet verknüpftes Konto gelöscht - deaktiviert das Tablet-Konto
--- entsprechend (siehe Employees.DeactivateFromWebsite).
local function handleDeactivateEmployee(data)
    local employeeId = tonumber(data.tabletEmployeeId)
    if not employeeId then error('invalid_command_payload') end
    return Employees.DeactivateFromWebsite(employeeId)
end

--- `create_vehicle`: Geschäftsführung hat auf der Website ein neues
--- Fahrzeug mit Häkchen "Auch im Tablet anlegen" erstellt (siehe
--- Vehicles.CreateFromWebsite).
local function handleCreateVehicle(data)
    if type(data.plate) ~= 'string' or data.plate == '' then error('invalid_command_payload') end
    return Vehicles.CreateFromWebsite(data)
end

--- `archive_vehicle`: Geschäftsführung hat auf der Website ein mit dem
--- Tablet verknüpftes Fahrzeug gelöscht - archiviert das Tablet-Fahrzeug
--- entsprechend (siehe Vehicles.ArchiveFromWebsite).
local function handleArchiveVehicle(data)
    if type(data.plate) ~= 'string' or data.plate == '' then error('invalid_command_payload') end
    return Vehicles.ArchiveFromWebsite(data.plate)
end

local commandHandlers = {
    assign_order = handleAssignOrder,
    cancel_order = handleCancelOrder,
    create_order = handleCreateOrder,
    update_vehicle = handleUpdateVehicle,
    create_employee = handleCreateEmployee,
    update_driver_permissions = handleUpdateDriverPermissions,
    deactivate_employee = handleDeactivateEmployee,
    create_vehicle = handleCreateVehicle,
    archive_vehicle = handleArchiveVehicle,
}

local function ackCommand(commandId, ok, errMsg)
    apiRequest('POST', ('/api/tablet/commands/%s/ack'):format(commandId), { ok = ok, error = errMsg })
end

--- `error('order_not_found')` etc. (Standard-Level 1) lässt Lua automatisch
--- "quelle:zeile: " vor die Meldung setzen (z.B.
--- "@speditions-tablet/server/sv_orders.lua:644: order_not_found") - dieses
--- Präfix macht den reinen Fehlercode für den exakten String-Abgleich auf
--- der Website (TABLET_ORDER_ERRORS in use-tablet-command.ts) unbrauchbar.
--- Entfernt es, falls vorhanden, bevor der Code über /ack an die Website geht.
local function stripErrorLocation(err)
    local msg = tostring(err)
    return (msg:gsub('^.-:%d+:%s*', ''))
end

CreateThread(function()
    while true do
        Wait((Config.Website and Config.Website.pollIntervalMs) or 5000)
        if websiteConfigured() then
            apiRequest('GET', '/api/tablet/commands', nil, function(ok, _statusCode, decoded)
                if not ok or not decoded or not decoded.commands then return end
                for _, command in ipairs(decoded.commands) do
                    local handler = commandHandlers[command.type]
                    if handler then
                        local success, result = pcall(handler, command.data or {})
                        ackCommand(command.id, success, (not success) and stripErrorLocation(result) or nil)
                    else
                        ackCommand(command.id, false, 'unknown_command_type')
                    end
                end
            end)
        end
    end
end)
