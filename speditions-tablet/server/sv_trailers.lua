-- =========================================================
-- Anhängerverwaltung
--
-- Anhänger (Curtainsider, Curtainsider mit Gefahrgutzulassung, Kipper,
-- Kühlanhänger, Tankanhänger) werden Fahrzeugen zugewiesen/angekuppelt und
-- bestimmen, welche Aufträge damit disponiert werden können (siehe
-- st_cargo_types.trailer_type, server/sv_cargo_types.lua, server/sv_orders.lua).
-- Erstellen/Bearbeiten/
-- Löschen/Ankuppeln ist wie beim Fuhrpark ausschließlich der
-- Geschäftsführung vorbehalten (serverseitig erzwungen, 'fleet_manage').
-- =========================================================

Trailers = {}

local STATUS_VALUES = { 'verfuegbar', 'im_einsatz', 'wartung', 'defekt', 'ausser_betrieb' }

local function isValidTrailerType(typeKey)
    for _, t in ipairs(Config.TrailerTypes) do
        if t.key == typeKey then return true end
    end
    return false
end

--- Lesbares Label zu einem Anhängertyp-Schlüssel (z.B. 'tankanhaenger' ->
--- 'Tankanhänger') - für Fehlermeldungen, die dem Fahrer/Disponenten sagen
--- sollen, WELCHER Anhänger konkret gebraucht wird, statt nur den rohen
--- Schlüssel/Fehlercode zu zeigen. Fällt auf den Schlüssel selbst zurück,
--- falls er (z.B. durch eine inkonsistente Config) nicht im Katalog steht.
function Trailers.LabelFor(typeKey)
    for _, t in ipairs(Config.TrailerTypes) do
        if t.key == typeKey then return t.label end
    end
    return typeKey
end

function Trailers.GetById(trailerId)
    return MySQL.single.await('SELECT * FROM st_trailers WHERE id = ? LIMIT 1', { trailerId })
end

function Trailers.List(includeArchived)
    local where = includeArchived and '' or 'WHERE t.archived = 0'
    return MySQL.query.await(([[
        SELECT t.*, v.name AS vehicle_name, v.plate AS vehicle_plate
        FROM st_trailers t
        LEFT JOIN st_vehicles v ON v.id = t.assigned_vehicle_id
        %s
        ORDER BY t.archived ASC, t.name ASC
    ]]):format(where))
end

--- Anhänger, der aktuell an das übergebene Fahrzeug angekuppelt ist (oder
--- nil) - für die Dispositions-Prüfung in server/sv_orders.lua.
function Trailers.GetByVehicleId(vehicleId)
    if not vehicleId then return nil end
    return MySQL.single.await('SELECT * FROM st_trailers WHERE assigned_vehicle_id = ? LIMIT 1', { vehicleId })
end

function Trailers.Create(src, data)
    local emp = Employees.RequirePermission(src, 'fleet_manage')

    local name = Utils.SanitizeString(data.name, 100)
    local plate = Utils.SanitizeString(data.plate, 20)
    local trailerType = data.type

    if not (name and plate and trailerType) then error('missing_fields') end
    if not isValidTrailerType(trailerType) then error('invalid_trailer_type') end

    local existing = MySQL.single.await('SELECT id FROM st_trailers WHERE plate = ? LIMIT 1', { plate })
    if existing then error('plate_taken') end

    local trailerId = MySQL.insert.await(
        [[INSERT INTO st_trailers (name, type, plate, status) VALUES (?, ?, ?, 'verfuegbar')]],
        { name, trailerType, plate }
    )

    Logs.Write(emp.id, 'trailer_create', ('%s hat Anhänger %s (%s) erstellt.'):format(emp.name, name, plate))
    RPC.PushToPermission('dispatch', 'fleet:changed', {})

    return { trailerId = trailerId }
end

function Trailers.Update(src, trailerId, data)
    local emp = Employees.RequirePermission(src, 'fleet_manage')
    local trailer = Trailers.GetById(trailerId)
    if not trailer then error('trailer_not_found') end

    local name = Utils.SanitizeString(data.name, 100) or trailer.name
    local plate = Utils.SanitizeString(data.plate, 20) or trailer.plate
    local trailerType = data.type or trailer.type
    if not isValidTrailerType(trailerType) then error('invalid_trailer_type') end
    local status = data.status
    if status ~= nil and not Utils.InTable(STATUS_VALUES, status) then error('invalid_status') end
    status = status or trailer.status

    if plate ~= trailer.plate then
        local existing = MySQL.single.await('SELECT id FROM st_trailers WHERE plate = ? AND id != ? LIMIT 1', { plate, trailerId })
        if existing then error('plate_taken') end
    end

    MySQL.update.await(
        'UPDATE st_trailers SET name = ?, type = ?, plate = ?, status = ? WHERE id = ?',
        { name, trailerType, plate, status, trailerId }
    )
    Logs.Write(emp.id, 'trailer_update', ('%s hat Anhänger %s (%s) bearbeitet.'):format(emp.name, name, plate))
    RPC.PushToPermission('dispatch', 'fleet:changed', {})

    return { ok = true }
end

--- Kuppelt einen Anhänger an ein Fahrzeug an (oder ab, wenn vehicleId = nil).
--- Ein Fahrzeug kann immer nur EINEN Anhänger gleichzeitig haben - ein
--- bereits an dieses Fahrzeug gekuppelter Anhänger wird zuerst abgekuppelt.
--- Kern-Logik ohne Berechtigungsprüfung, damit Drivers.StartShift (Fahrer
--- kuppelt sich beim Fahrerkarte-Einstecken selbst einen Anhänger an, siehe
--- server/sv_drivers.lua) sie mit dem eigenen Mitarbeiter-Datensatz
--- wiederverwenden kann, statt 'fleet_manage' zu benötigen.
local function assignTrailerInternal(emp, trailerId, vehicleId)
    local trailer = Trailers.GetById(trailerId)
    if not trailer then error('trailer_not_found') end

    if vehicleId ~= nil and vehicleId ~= 0 then
        local vehicle = MySQL.single.await('SELECT * FROM st_vehicles WHERE id = ?', { vehicleId })
        if not vehicle then error('vehicle_not_found') end
        if Utils.ToBool(vehicle.archived) then error('vehicle_archived') end

        -- Bereits an dieses Fahrzeug gekuppelten Anhänger abkuppeln
        MySQL.update.await('UPDATE st_trailers SET assigned_vehicle_id = NULL WHERE assigned_vehicle_id = ?', { vehicleId })
        MySQL.update.await('UPDATE st_trailers SET assigned_vehicle_id = ? WHERE id = ?', { vehicleId, trailerId })
        Logs.Write(emp.id, 'trailer_assign', ('%s hat Anhänger %s an %s (%s) angekuppelt.'):format(emp.name, trailer.name, vehicle.name, vehicle.plate))
    else
        MySQL.update.await('UPDATE st_trailers SET assigned_vehicle_id = NULL WHERE id = ?', { trailerId })
        Logs.Write(emp.id, 'trailer_unassign', ('%s hat Anhänger %s abgekuppelt.'):format(emp.name, trailer.name))
    end

    RPC.PushToPermission('dispatch', 'fleet:changed', {})
    return { ok = true }
end
Trailers.AssignInternal = assignTrailerInternal

function Trailers.Assign(src, trailerId, vehicleId)
    local emp = Employees.RequirePermission(src, 'fleet_manage')
    return assignTrailerInternal(emp, trailerId, vehicleId)
end

--- Löscht (archiviert) einen Anhänger. mode = 'archive' (Standard) oder 'hard'.
function Trailers.Delete(src, trailerId, mode)
    local emp = Employees.RequirePermission(src, 'fleet_manage')
    local trailer = Trailers.GetById(trailerId)
    if not trailer then error('trailer_not_found') end

    if mode == 'hard' then
        MySQL.update.await('DELETE FROM st_trailers WHERE id = ?', { trailerId })
        Logs.Write(emp.id, 'trailer_delete_hard', ('%s hat Anhänger %s (%s) endgültig gelöscht.'):format(emp.name, trailer.name, trailer.plate))
        RPC.PushToPermission('dispatch', 'fleet:changed', {})
        return { ok = true, mode = 'hard' }
    end

    MySQL.update.await("UPDATE st_trailers SET archived = 1, status = 'ausser_betrieb', assigned_vehicle_id = NULL WHERE id = ?", { trailerId })
    Logs.Write(emp.id, 'trailer_archive', ('%s hat Anhänger %s (%s) archiviert.'):format(emp.name, trailer.name, trailer.plate))
    RPC.PushToPermission('dispatch', 'fleet:changed', {})
    return { ok = true, mode = 'archive' }
end

-- =========================================================
-- RPC-Handler
-- =========================================================

RPC.Register('gf:trailers:list', function(src)
    Employees.RequirePermission(src, 'fleet_manage')
    return { trailers = Trailers.List(), trailerTypes = Config.TrailerTypes }
end)

RPC.Register('gf:trailers:create', function(src, payload)
    return Trailers.Create(src, payload)
end)

RPC.Register('gf:trailers:update', function(src, payload)
    local trailerId = Utils.SanitizeNumber(payload.trailerId, 1)
    if not trailerId then error('invalid_payload') end
    return Trailers.Update(src, trailerId, payload)
end)

RPC.Register('gf:trailers:assign', function(src, payload)
    local trailerId = Utils.SanitizeNumber(payload.trailerId, 1)
    if not trailerId then error('invalid_payload') end
    local vehicleId = payload.vehicleId and Utils.SanitizeNumber(payload.vehicleId, 1) or nil
    return Trailers.Assign(src, trailerId, vehicleId)
end)

RPC.Register('gf:trailers:delete', function(src, payload)
    local trailerId = Utils.SanitizeNumber(payload.trailerId, 1)
    if not trailerId then error('invalid_payload') end
    return Trailers.Delete(src, trailerId, payload.mode)
end)
