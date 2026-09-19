-- =========================================================
-- Orte (Be-/Entladepunkte)
--
-- Ersetzt die frühere feste Config.Locations-Liste: Orte liegen jetzt in
-- st_locations und können von der Geschäftsführung im Tablet-Reiter "Orte"
-- selbst angelegt/bearbeitet/gelöscht werden (inkl. "Aktuelle Position
-- übernehmen"). Config.SeedLocations dient nur der einmaligen Erstbefüllung
-- beim allerersten Ressourcenstart (analog Config.DefaultRolePermissions),
-- danach ist ausschließlich die Datenbank die Quelle der Wahrheit.
-- =========================================================

Locations = {}

local cache = nil -- array von { id, name, coords=vector4(x,y,z,heading), sourceCargo={...}, destCargo={...} }
local byName = nil -- name -> Eintrag aus cache

local function decodeCargoList(jsonText)
    if not jsonText or jsonText == '' then return {} end
    local ok, decoded = pcall(json.decode, jsonText)
    if ok and type(decoded) == 'table' then return decoded end
    return {}
end

local function reload()
    local rows = MySQL.query.await('SELECT * FROM st_locations ORDER BY name ASC')
    local fresh, freshByName = {}, {}
    for _, row in ipairs(rows) do
        local entry = {
            id = row.id,
            name = row.name,
            -- Bewusst eine reine Lua-Tabelle statt vector4(...): dieser Cache
            -- geht per JSON-RPC auch zum Client raus (client/cl_orders.lua,
            -- Bodenmarker) - vector4-Userdata lässt sich über json.encode
            -- nicht zuverlässig serialisieren, eine Tabelle mit x/y/z/w
            -- schon, und für die reine Feldzugriffs-Arithmetik in
            -- server/sv_orders.lua macht es keinen Unterschied.
            coords = { x = tonumber(row.pos_x), y = tonumber(row.pos_y), z = tonumber(row.pos_z), w = tonumber(row.heading) or 0.0 },
            sourceCargo = decodeCargoList(row.source_cargo),
            destCargo = decodeCargoList(row.dest_cargo),
        }
        fresh[#fresh + 1] = entry
        freshByName[row.name] = entry
    end
    cache = fresh
    byName = freshByName
end

--- Erstbefüllung aus Config.SeedLocations, falls noch nicht vorhanden. ON
--- DUPLICATE KEY macht das race-sicher, falls zwei Aufrufer gleichzeitig
--- zum ersten Mal laden.
local function seedLocations()
    for _, loc in ipairs(Config.SeedLocations or {}) do
        MySQL.insert.await(
            [[INSERT INTO st_locations (name, pos_x, pos_y, pos_z, heading, source_cargo, dest_cargo)
              VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE name = name]],
            {
                loc.name, loc.coords.x, loc.coords.y, loc.coords.z, loc.coords.w,
                json.encode(loc.sourceCargo or {}), json.encode(loc.destCargo or {}),
            }
        )
    end
end

local function ensureLoaded()
    if cache then return end
    seedLocations()
    reload()
end

--- Erzwingt ein Neuladen des Caches (nach Create/Update/Delete).
function Locations.Reload()
    reload()
end

--- Liste aller Orte - für die NUI (Reiter "Orte") ebenso wie für
--- server/sv_orders.lua (Auftragsgenerierung) und client/cl_orders.lua
--- (Bodenmarker, über die 'locations:list'-RPC unten).
function Locations.List()
    ensureLoaded()
    return cache
end

function Locations.GetByName(name)
    ensureLoaded()
    return byName[name]
end

local function sanitizeCargoList(list)
    if type(list) ~= 'table' then return {} end
    local valid = {}
    for _, c in ipairs(Config.CargoTypes) do valid[c] = true end
    local out, seen = {}, {}
    for _, key in ipairs(list) do
        if type(key) == 'string' and valid[key] and not seen[key] then
            seen[key] = true
            out[#out + 1] = key
        end
    end
    return out
end

--- Legt einen neuen Ort an.
function Locations.Create(src, name, x, y, z, heading, sourceCargo, destCargo)
    local emp = Employees.RequirePermission(src, 'locations_manage')
    ensureLoaded()

    name = Utils.SanitizeString(name, 100)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    heading = tonumber(heading) or 0.0
    if not name or not x or not y or not z then error('missing_fields') end
    if byName[name] then error('name_taken') end

    local sanitizedSource = sanitizeCargoList(sourceCargo)
    local sanitizedDest = sanitizeCargoList(destCargo)

    local locationId = MySQL.insert.await(
        [[INSERT INTO st_locations (name, pos_x, pos_y, pos_z, heading, source_cargo, dest_cargo)
          VALUES (?, ?, ?, ?, ?, ?, ?)]],
        { name, x, y, z, heading, json.encode(sanitizedSource), json.encode(sanitizedDest) }
    )
    reload()
    RPC.PushBroadcast('locations:changed', {})
    if WebsiteBridge then WebsiteBridge.PushLocations() end
    Logs.Write(emp.id, 'location_created', ('%s hat den Ort "%s" angelegt.'):format(emp.name, name))
    return { locationId = locationId }
end

--- Bearbeitet einen bestehenden Ort.
function Locations.Update(src, locationId, name, x, y, z, heading, sourceCargo, destCargo)
    local emp = Employees.RequirePermission(src, 'locations_manage')
    ensureLoaded()

    local current = MySQL.single.await('SELECT * FROM st_locations WHERE id = ?', { locationId })
    if not current then error('location_not_found') end

    name = Utils.SanitizeString(name, 100) or current.name
    x = tonumber(x) or current.pos_x
    y = tonumber(y) or current.pos_y
    z = tonumber(z) or current.pos_z
    heading = tonumber(heading) or current.heading

    if name ~= current.name and byName[name] then error('name_taken') end

    local sanitizedSource = sanitizeCargoList(sourceCargo)
    local sanitizedDest = sanitizeCargoList(destCargo)

    MySQL.update.await(
        [[UPDATE st_locations SET name = ?, pos_x = ?, pos_y = ?, pos_z = ?, heading = ?,
          source_cargo = ?, dest_cargo = ? WHERE id = ?]],
        { name, x, y, z, heading, json.encode(sanitizedSource), json.encode(sanitizedDest), locationId }
    )
    reload()
    RPC.PushBroadcast('locations:changed', {})
    if WebsiteBridge then WebsiteBridge.PushLocations() end
    Logs.Write(emp.id, 'location_updated', ('%s hat den Ort "%s" bearbeitet.'):format(emp.name, name))
    return { ok = true }
end

--- Löscht einen Ort. Offene Aufträge, die diesen Ort noch als Start-/
--- Zielpunkt referenzieren, bleiben bestehen (Orte sind nur per Namens-
--- String verknüpft, kein Fremdschlüssel) - deren Wegpunkt/Bodenmarker lässt
--- sich dann nur nicht mehr auflösen (siehe Utils.GetLocationByName), das
--- führt zu keinem Fehler.
function Locations.Delete(src, locationId)
    local emp = Employees.RequirePermission(src, 'locations_manage')
    ensureLoaded()

    local current = MySQL.single.await('SELECT * FROM st_locations WHERE id = ?', { locationId })
    if not current then error('location_not_found') end

    MySQL.update.await('DELETE FROM st_locations WHERE id = ?', { locationId })
    reload()
    RPC.PushBroadcast('locations:changed', {})
    if WebsiteBridge then WebsiteBridge.PushLocations() end
    Logs.Write(emp.id, 'location_deleted', ('%s hat den Ort "%s" gelöscht.'):format(emp.name, current.name))
    return { ok = true }
end

--- Liefert die aktuelle Position des aufrufenden Spielers serverseitig
--- (kein zusätzliches Client->Server-Event nötig, GetPlayerPed funktioniert
--- direkt mit der Server-ID) - Grundlage für den "Aktuelle Position
--- übernehmen"-Button im Anlegen/Bearbeiten-Formular.
function Locations.GetCurrentPosition(src)
    Employees.RequirePermission(src, 'locations_manage')
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then error('player_not_found') end
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    return { x = coords.x, y = coords.y, z = coords.z, heading = heading }
end

-- =========================================================
-- RPC-Handler
-- =========================================================

--- Jeder angemeldete Mitarbeiter darf die Ortsliste sehen (nicht nur
--- locations_manage) - Fahrer brauchen sie für die Bodenmarker an Be-/
--- Entladepunkten (client/cl_orders.lua).
RPC.Register('locations:list', function(src)
    Employees.RequireRole(src)
    return { locations = Locations.List() }
end)

RPC.Register('gf:locations:create', function(src, payload)
    return Locations.Create(src, payload.name, payload.x, payload.y, payload.z, payload.heading, payload.sourceCargo, payload.destCargo)
end)

RPC.Register('gf:locations:update', function(src, payload)
    local locationId = Utils.SanitizeNumber(payload.locationId, 1)
    if not locationId then error('invalid_payload') end
    return Locations.Update(src, locationId, payload.name, payload.x, payload.y, payload.z, payload.heading, payload.sourceCargo, payload.destCargo)
end)

RPC.Register('gf:locations:delete', function(src, payload)
    local locationId = Utils.SanitizeNumber(payload.locationId, 1)
    if not locationId then error('invalid_payload') end
    return Locations.Delete(src, locationId)
end)

RPC.Register('gf:locations:currentPosition', function(src)
    return Locations.GetCurrentPosition(src)
end)
