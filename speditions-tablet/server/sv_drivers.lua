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
    local emp = Employees.RequirePermission(src, 'driver_actions')
    if not Utils.InTable(DRIVER_STATUS_VALUES, status) then error('invalid_status') end

    local driver = Drivers.EnsureDriverRecord(emp.id)
    MySQL.update.await('UPDATE st_drivers SET current_status = ? WHERE id = ?', { status, driver.id })

    RPC.PushToPermission('dispatch', 'dispatch:driversChanged', {})

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
    local emp = Employees.RequirePermission(src, 'driver_actions')
    local driver = Drivers.EnsureDriverRecord(emp.id)
    local stats = Drivers.GetStatistics(driver.id)
    local vehicle = Drivers.GetVehicle(driver.id)
    local earnings = Finance.GetDriverEarnings(driver.id)

    return {
        employee = { id = emp.id, name = emp.name, hiredAt = emp.hired_at, status = emp.status },
        driver = {
            id = driver.id, rank = driver.rank, currentStatus = driver.current_status, notes = driver.notes,
            onShift = Utils.ToBool(driver.on_shift), shiftStartedAt = driver.shift_started_at,
        },
        statistics = stats,
        permissions = Drivers.GetPermissions(driver.id),
        vehicle = vehicle,
        earnings = earnings,
        hours = Hours.Status(driver.id),
    }
end

--- "Fahrerkarte einstecken" - startet die Schicht. Muss aktiv sein, bevor ein
--- Fahrer einen Auftrag annehmen kann (siehe Orders.AcceptByDriver), damit
--- der Fahrer bewusst bestätigt, dass ab jetzt seine Lenk-/Ruhezeiten laufen.
--- Prüft nach einem Schicht-Update den TATSÄCHLICHEN Wert in der DB (statt
--- der von UPDATE gemeldeten Zeilenanzahl - MySQL zählt dort "geänderte",
--- nicht "getroffene" Zeilen, ein UPDATE auf denselben Wert würde also fälschlich
--- als Fehlschlag durchgehen). So bleibt eine z.B. fehlende Migration
--- (st_drivers.on_shift existiert nicht - siehe sql/upgrade_v7.sql) erkennbar,
--- ohne bei einem harmlosen "nochmal derselbe Wert"-Fall falsch anzuschlagen.
local function verifyShiftState(driverId, expectedOnShift)
    local row = MySQL.single.await('SELECT on_shift FROM st_drivers WHERE id = ?', { driverId })
    if not row or Utils.ToBool(row.on_shift) ~= expectedOnShift then
        error('shift_update_failed')
    end
end

--- Fahrzeuge, die sich ein Fahrer beim Fahrerkarte-Einstecken selbst
--- zuweisen darf: verfügbar, nicht archiviert, und nicht gerade von einem
--- ANDEREN Fahrer beansprucht, der selbst schon im Dienst ist (sonst
--- könnten sich zwei Fahrer gleichzeitig denselben LKW "greifen"). Der
--- eigene, bereits zugewiesene LKW zählt bewusst mit dazu, damit ein Fahrer
--- nach einer Zwischenablage (z.B. Tablet kurz geschlossen) denselben LKW
--- erneut wählen kann.
local function availableVehiclesForShift(driverId)
    return MySQL.query.await([[
        SELECT v.id, v.name, v.plate, v.vehicle_class, v.mileage, v.fuel,
            t.id AS trailer_id, t.name AS trailer_name, t.type AS trailer_type
        FROM st_vehicles v
        LEFT JOIN st_trailers t ON t.assigned_vehicle_id = v.id
        WHERE v.archived = 0 AND v.status = 'verfuegbar'
            AND NOT EXISTS (
                SELECT 1 FROM st_drivers d
                WHERE d.assigned_vehicle_id = v.id AND d.on_shift = 1 AND d.id != ?
            )
        ORDER BY v.name ASC
    ]], { driverId })
end

--- Anhänger, die sich ein Fahrer beim Fahrerkarte-Einstecken selbst ankuppeln
--- darf - analog availableVehiclesForShift: nicht gerade an ein Fahrzeug
--- gekuppelt, das ein ANDERER, bereits im Dienst befindlicher Fahrer fährt.
local function availableTrailersForShift(driverId)
    return MySQL.query.await([[
        SELECT t.id, t.name, t.plate, t.type
        FROM st_trailers t
        WHERE t.archived = 0 AND t.status = 'verfuegbar'
            AND (t.assigned_vehicle_id IS NULL OR NOT EXISTS (
                SELECT 1 FROM st_drivers d
                WHERE d.assigned_vehicle_id = t.assigned_vehicle_id AND d.on_shift = 1 AND d.id != ?
            ))
        ORDER BY t.name ASC
    ]], { driverId })
end

--- Auswahl für das "Fahrerkarte einstecken"-Formular: freie Fahrzeuge +
--- freie Anhänger (inkl. Anhängertyp-Bezeichnungen für die NUI).
function Drivers.ShiftOptions(src)
    local emp = Employees.RequirePermission(src, 'driver_actions')
    local driver = Drivers.EnsureDriverRecord(emp.id)
    return {
        vehicles = availableVehiclesForShift(driver.id),
        trailers = availableTrailersForShift(driver.id),
        trailerTypes = Config.TrailerTypes,
    }
end

--- "Fahrerkarte einstecken" - startet die Schicht. Der Fahrer wählt dabei
--- selbst ein freies Fahrzeug (ersetzt die frühere reine GF-Zuweisung, die
--- als eigener Vorgang im Fuhrpark aber weiterhin möglich bleibt) UND
--- entweder einen Anhänger (wird automatisch an das gewählte Fahrzeug
--- angekuppelt, siehe Trailers.AssignInternal) oder markiert die Fahrt
--- explizit als "Werkstattfahrt" (workshopMode = true, kein Anhänger nötig -
--- die bestehende Anhängertyp-Prüfung bei der Disposition, s.
--- server/sv_orders.lua, sorgt dann von selbst dafür, dass ein Fahrer ohne
--- Anhänger keine Frachtaufträge annehmen kann). Genau eine der beiden
--- Optionen ist Pflicht, damit der Fahrer bewusst eine Wahl trifft.
function Drivers.StartShift(src, vehicleId, trailerId, workshopMode)
    local emp = Employees.RequirePermission(src, 'driver_actions')
    local driver = Drivers.EnsureDriverRecord(emp.id)

    vehicleId = Utils.SanitizeNumber(vehicleId, 1)
    trailerId = trailerId and Utils.SanitizeNumber(trailerId, 1) or nil
    workshopMode = workshopMode == true

    if not vehicleId then error('missing_fields') end
    if not trailerId and not workshopMode then error('missing_trailer_or_workshop') end
    if trailerId and workshopMode then error('missing_fields') end

    local vehicle = Vehicles.GetById(vehicleId)
    if not vehicle then error('vehicle_not_found') end
    if Utils.ToBool(vehicle.archived) then error('vehicle_archived') end
    if vehicle.status ~= 'verfuegbar' then error('vehicle_unavailable') end

    local claimedBy = MySQL.single.await(
        'SELECT id FROM st_drivers WHERE assigned_vehicle_id = ? AND on_shift = 1 AND id != ?',
        { vehicleId, driver.id }
    )
    if claimedBy then error('vehicle_unavailable') end

    Vehicles.AssignInternal(emp, vehicleId, driver.id)

    if trailerId then
        local trailer = Trailers.GetById(trailerId)
        if not trailer then error('trailer_not_found') end
        if Utils.ToBool(trailer.archived) then error('trailer_unavailable') end
        if trailer.status ~= 'verfuegbar' then error('trailer_unavailable') end
        Trailers.AssignInternal(emp, trailerId, vehicleId)
    end

    MySQL.update.await('UPDATE st_drivers SET on_shift = 1, shift_started_at = NOW() WHERE id = ?', { driver.id })
    verifyShiftState(driver.id, true)
    Logs.Write(emp.id, 'shift_started', ('%s hat die Fahrerkarte eingesteckt (Fahrt gestartet, Fahrzeug %s%s).'):format(
        emp.name, vehicle.plate, workshopMode and ', Werkstattfahrt ohne Anhänger' or ''
    ))
    if WebsiteBridge then WebsiteBridge.PushDriverShiftUpdate(emp.id, true) end
    return { ok = true }
end

--- "Fahrerkarte abziehen" - beendet die Schicht UND gibt das Fahrzeug wieder
--- für andere Fahrer frei (der Anhänger bleibt am Fahrzeug hängen, nicht am
--- Fahrer - wer als nächstes dieses Fahrzeug wählt, sieht/übernimmt ihn
--- automatisch mit).
function Drivers.EndShift(src)
    local emp = Employees.RequirePermission(src, 'driver_actions')
    local driver = Drivers.EnsureDriverRecord(emp.id)
    MySQL.update.await('UPDATE st_drivers SET on_shift = 0, shift_started_at = NULL WHERE id = ?', { driver.id })
    verifyShiftState(driver.id, false)
    if driver.assigned_vehicle_id then
        Vehicles.AssignInternal(emp, driver.assigned_vehicle_id, nil)
    end
    Logs.Write(emp.id, 'shift_ended', ('%s hat die Fahrerkarte abgezogen (Fahrt beendet).'):format(emp.name))
    if WebsiteBridge then WebsiteBridge.PushDriverShiftUpdate(emp.id, false) end
    return { ok = true }
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
        hours = Hours.Status(driverId),
    }
end

function Drivers.SetNote(src, driverId, note)
    local emp = Employees.RequirePermission(src, 'employees_manage')
    local driver = Drivers.GetById(driverId)
    if not driver then error('driver_not_found') end

    note = note ~= nil and Utils.SanitizeString(note, 2000) or nil
    MySQL.update.await('UPDATE st_drivers SET notes = ? WHERE id = ?', { note, driverId })
    Logs.Write(emp.id, 'driver_note', ('%s hat eine Notiz für Fahrer #%s hinterlegt.'):format(emp.name, driverId))
    return { ok = true }
end

function Drivers.SetPermission(src, driverId, permKey, granted)
    local emp = Employees.RequirePermission(src, 'employees_manage')
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

--- System-Variante ohne src/Berechtigungsprüfung: gewährt einem frisch
--- angelegten Fahrer-Datensatz direkt beim Einstellen die im
--- "Mitarbeiter einstellen"-Formular ausgewählten Führerscheinklassen
--- (Employees.Hire/HireFromWebsite), statt sie erst nachträglich über die
--- Fahrerakte einzeln vergeben zu müssen. Ungültige Schlüssel werden
--- stillschweigend ignoriert statt einen Fehler zu werfen - das Anlegen des
--- Mitarbeiters selbst soll dadurch nie fehlschlagen.
function Drivers.GrantPermissionsRaw(driverId, permKeys)
    if type(permKeys) ~= 'table' then return end
    local valid = {}
    for _, perm in ipairs(Config.DriverPermissions) do valid[perm.key] = true end
    for _, key in ipairs(permKeys) do
        if valid[key] then
            MySQL.insert.await(
                'INSERT INTO st_driver_permissions (driver_id, permission_key) VALUES (?, ?) ON DUPLICATE KEY UPDATE granted_at = granted_at',
                { driverId, key }
            )
        end
    end
end

--- System-Variante für den Website-Sync (kein src - wird ausschließlich aus
--- einem bereits API-Key-geprüften Website-Befehl heraus aufgerufen, siehe
--- server/sv_website_bridge.lua): gleicht die Führerscheinklassen eines
--- Fahrers VOLLSTÄNDIG mit der von der Website übergebenen Liste ab (setzt
--- alle enthaltenen, entfernt alle fehlenden) - anders als
--- Drivers.SetPermission (einzelne An-/Abwahl) bildet das den kompletten
--- Checkbox-Zustand des Website-Formulars in einem Rutsch ab.
function Drivers.SetPermissionsFromWebsite(employeeId, permKeys)
    local driver = Drivers.GetByEmployeeId(employeeId)
    if not driver then error('driver_not_found') end
    if type(permKeys) ~= 'table' then permKeys = {} end

    local valid = {}
    for _, perm in ipairs(Config.DriverPermissions) do valid[perm.key] = true end
    local wanted = {}
    for _, key in ipairs(permKeys) do
        if valid[key] then wanted[key] = true end
    end

    for key in pairs(valid) do
        if wanted[key] then
            MySQL.insert.await(
                'INSERT INTO st_driver_permissions (driver_id, permission_key) VALUES (?, ?) ON DUPLICATE KEY UPDATE granted_at = granted_at',
                { driver.id, key }
            )
        else
            MySQL.update.await('DELETE FROM st_driver_permissions WHERE driver_id = ? AND permission_key = ?', { driver.id, key })
        end
    end

    Logs.Write(nil, 'driver_permission_website', ('Führerscheinklassen von Fahrer #%s wurden von der Website aus aktualisiert.'):format(driver.id))
    return { ok = true }
end

--- Fahrerübersicht für den Disponenten (und die Geschäftsführung): wer ist
--- eingeloggt, welchen Status hat er, welches Fahrzeug fährt er gerade.
function Drivers.ListForDispatch()
    return MySQL.query.await([[
        SELECT d.id AS driver_id, e.name, e.status AS employment_status, d.current_status,
               v.id AS vehicle_id, v.name AS vehicle_name, v.plate AS vehicle_plate, v.status AS vehicle_status,
               (SELECT GROUP_CONCAT(dp.permission_key) FROM st_driver_permissions dp WHERE dp.driver_id = d.id) AS permissions
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

RPC.Register('driver:shiftOptions', function(src)
    return Drivers.ShiftOptions(src)
end)

RPC.Register('driver:startShift', function(src, payload)
    payload = payload or {}
    return Drivers.StartShift(src, payload.vehicleId, payload.trailerId, payload.workshopMode)
end)

RPC.Register('driver:endShift', function(src)
    return Drivers.EndShift(src)
end)

RPC.Register('driver:history', function(src, payload)
    local emp = Employees.RequirePermission(src, 'driver_actions')
    local driver = Drivers.EnsureDriverRecord(emp.id)
    return { history = Drivers.GetHistory(driver.id, payload.limit) }
end)

RPC.Register('driver:earnings', function(src)
    local emp = Employees.RequirePermission(src, 'driver_actions')
    local driver = Drivers.EnsureDriverRecord(emp.id)
    return Finance.GetDriverEarnings(driver.id)
end)

RPC.Register('driver:vehicle', function(src)
    local emp = Employees.RequirePermission(src, 'driver_actions')
    local driver = Drivers.EnsureDriverRecord(emp.id)
    return { vehicle = Drivers.GetVehicle(driver.id), onShift = Utils.ToBool(driver.on_shift) }
end)

RPC.Register('dispatch:drivers', function(src)
    Employees.RequirePermission(src, 'dispatch')
    return { drivers = Drivers.ListForDispatch() }
end)

RPC.Register('gf:drivers:file', function(src, payload)
    Employees.RequirePermission(src, 'employees_manage')
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
