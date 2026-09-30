-- =========================================================
-- Frachtarten
--
-- Ersetzt die frühere feste Aufteilung Config.CargoTypes/CargoUnits/
-- HazardousCargo/CargoTrailerType: Frachtarten liegen jetzt in
-- st_cargo_types und können von der Geschäftsführung im Tablet-Reiter
-- "Frachtarten" selbst angelegt/bearbeitet/gelöscht werden.
-- Config.SeedCargoTypes dient nur der einmaligen Erstbefüllung beim
-- allerersten Ressourcenstart (analog Config.SeedLocations), danach ist
-- ausschließlich die Datenbank die Quelle der Wahrheit.
-- =========================================================

CargoTypes = {}

local cache = nil -- array von { id, name, unit, min, max, hazardous, trailerType }
local byName = nil -- name -> Eintrag aus cache

local function reload()
    local rows = MySQL.query.await('SELECT * FROM st_cargo_types ORDER BY name ASC')
    local fresh, freshByName = {}, {}
    for _, row in ipairs(rows) do
        local entry = {
            id = row.id,
            name = row.name,
            unit = row.unit,
            min = tonumber(row.min_amount) or 1,
            max = tonumber(row.max_amount) or 1,
            hazardous = Utils.ToBool(row.hazardous),
            trailerType = row.trailer_type,
        }
        fresh[#fresh + 1] = entry
        freshByName[row.name] = entry
    end
    cache = fresh
    byName = freshByName
end

--- Erstbefüllung aus Config.SeedCargoTypes, falls noch nicht vorhanden. ON
--- DUPLICATE KEY macht das race-sicher, falls zwei Aufrufer gleichzeitig
--- zum ersten Mal laden.
local function seedCargoTypes()
    for _, c in ipairs(Config.SeedCargoTypes or {}) do
        MySQL.insert.await(
            [[INSERT INTO st_cargo_types (name, unit, min_amount, max_amount, hazardous, trailer_type)
              VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE name = name]],
            { c.name, c.unit, c.min, c.max, c.hazardous and 1 or 0, c.trailerType }
        )
    end
end

local function ensureLoaded()
    if cache then return end
    seedCargoTypes()
    reload()
end

--- Erzwingt ein Neuladen des Caches (nach Create/Update/Delete).
function CargoTypes.Reload()
    reload()
end

--- Liste aller Frachtarten - für die NUI (Reiter "Frachtarten") ebenso wie
--- für server/sv_orders.lua (Auftragsgenerierung) und
--- server/sv_locations.lua (Quelle-/Ziel-Tags der Orte).
function CargoTypes.List()
    ensureLoaded()
    return cache
end

function CargoTypes.GetByName(name)
    ensureLoaded()
    return byName[name]
end

--- Reine Namensliste - für die Session-Nutzdaten (sv_main.lua) und den
--- Website-Sync (sv_website_bridge.lua), die bisher Config.CargoTypes (ein
--- Array aus Strings) erwartet haben.
function CargoTypes.Names()
    ensureLoaded()
    local names = {}
    for _, c in ipairs(cache) do names[#names + 1] = c.name end
    return names
end

local function validateTrailerType(trailerType)
    for _, t in ipairs(Config.TrailerTypes) do
        if t.key == trailerType then return true end
    end
    return false
end

--- Legt eine neue Frachtart an.
function CargoTypes.Create(src, name, unit, min, max, hazardous, trailerType)
    local emp = Employees.RequirePermission(src, 'cargo_types_manage')
    ensureLoaded()

    name = Utils.SanitizeString(name, 100)
    unit = Utils.SanitizeString(unit, 50)
    min = Utils.SanitizeNumber(min, 1)
    max = Utils.SanitizeNumber(max, 1)
    if not name or not unit or not min or not max then error('missing_fields') end
    if max < min then error('invalid_range') end
    if not validateTrailerType(trailerType) then error('invalid_trailer_type') end
    if byName[name] then error('name_taken') end

    local cargoTypeId = MySQL.insert.await(
        [[INSERT INTO st_cargo_types (name, unit, min_amount, max_amount, hazardous, trailer_type)
          VALUES (?, ?, ?, ?, ?, ?)]],
        { name, unit, min, max, hazardous and 1 or 0, trailerType }
    )
    reload()
    RPC.PushBroadcast('cargotypes:changed', {})
    if WebsiteBridge then WebsiteBridge.PushLocations() end
    Logs.Write(emp.id, 'cargo_type_created', ('%s hat die Frachtart "%s" angelegt.'):format(emp.name, name))
    return { cargoTypeId = cargoTypeId }
end

--- Bearbeitet eine bestehende Frachtart.
function CargoTypes.Update(src, cargoTypeId, name, unit, min, max, hazardous, trailerType)
    local emp = Employees.RequirePermission(src, 'cargo_types_manage')
    ensureLoaded()

    local current = MySQL.single.await('SELECT * FROM st_cargo_types WHERE id = ?', { cargoTypeId })
    if not current then error('cargo_type_not_found') end

    name = Utils.SanitizeString(name, 100) or current.name
    unit = Utils.SanitizeString(unit, 50) or current.unit
    min = Utils.SanitizeNumber(min, 1) or current.min_amount
    max = Utils.SanitizeNumber(max, 1) or current.max_amount
    if max < min then error('invalid_range') end
    if trailerType ~= nil and not validateTrailerType(trailerType) then error('invalid_trailer_type') end
    trailerType = trailerType or current.trailer_type
    if hazardous == nil then hazardous = Utils.ToBool(current.hazardous) end

    if name ~= current.name and byName[name] then error('name_taken') end

    MySQL.update.await(
        [[UPDATE st_cargo_types SET name = ?, unit = ?, min_amount = ?, max_amount = ?,
          hazardous = ?, trailer_type = ? WHERE id = ?]],
        { name, unit, min, max, hazardous and 1 or 0, trailerType, cargoTypeId }
    )
    reload()
    RPC.PushBroadcast('cargotypes:changed', {})
    if WebsiteBridge then WebsiteBridge.PushLocations() end
    Logs.Write(emp.id, 'cargo_type_updated', ('%s hat die Frachtart "%s" bearbeitet.'):format(emp.name, name))
    return { ok = true }
end

--- Löscht eine Frachtart. Offene Aufträge, die diese Frachtart noch
--- referenzieren, bleiben bestehen (Frachtarten sind nur per Namens-String
--- verknüpft, kein Fremdschlüssel) - für neue Aufträge steht sie danach
--- einfach nicht mehr zur Auswahl.
function CargoTypes.Delete(src, cargoTypeId)
    local emp = Employees.RequirePermission(src, 'cargo_types_manage')
    ensureLoaded()

    local current = MySQL.single.await('SELECT * FROM st_cargo_types WHERE id = ?', { cargoTypeId })
    if not current then error('cargo_type_not_found') end

    MySQL.update.await('DELETE FROM st_cargo_types WHERE id = ?', { cargoTypeId })
    reload()
    RPC.PushBroadcast('cargotypes:changed', {})
    if WebsiteBridge then WebsiteBridge.PushLocations() end
    Logs.Write(emp.id, 'cargo_type_deleted', ('%s hat die Frachtart "%s" gelöscht.'):format(emp.name, current.name))
    return { ok = true }
end

-- =========================================================
-- RPC-Handler
-- =========================================================

--- Jeder angemeldete Mitarbeiter darf die Frachtartenliste sehen (nicht nur
--- cargo_types_manage) - z.B. für die Quelle-/Ziel-Auswahl im Orte-Formular.
RPC.Register('cargotypes:list', function(src)
    Employees.RequireRole(src)
    return { cargoTypes = CargoTypes.List() }
end)

RPC.Register('gf:cargotypes:create', function(src, payload)
    return CargoTypes.Create(src, payload.name, payload.unit, payload.min, payload.max, payload.hazardous, payload.trailerType)
end)

RPC.Register('gf:cargotypes:update', function(src, payload)
    local cargoTypeId = Utils.SanitizeNumber(payload.cargoTypeId, 1)
    if not cargoTypeId then error('invalid_payload') end
    return CargoTypes.Update(src, cargoTypeId, payload.name, payload.unit, payload.min, payload.max, payload.hazardous, payload.trailerType)
end)

RPC.Register('gf:cargotypes:delete', function(src, payload)
    local cargoTypeId = Utils.SanitizeNumber(payload.cargoTypeId, 1)
    if not cargoTypeId then error('invalid_payload') end
    return CargoTypes.Delete(src, cargoTypeId)
end)
