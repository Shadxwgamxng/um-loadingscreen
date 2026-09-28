-- =========================================================
-- Warnmeldungen: Verkehrswarn-App ("Warnmeldungen")
--
-- Jede Meldung wird EINMALIG mit der zum Erstellzeitpunkt tatsächlichen
-- Serverposition (GetEntityCoords) gespeichert - der Client kann seine
-- eigene Position nie selbst setzen. Gültigkeitsdauer/Ablauf laufen
-- serverseitig über expires_at, nie über einen Client-/Browser-Timer;
-- Bestätigen verlängert nur expires_at + zählt hoch (kein eigener
-- 'confirmed'-Status nötig), die aktive Abfrage filtert IMMER zusätzlich
-- expires_at > NOW(), damit "aktiv" nie vom periodischen Ablauf-Tick
-- abhängt.
-- =========================================================

Warnings = {}

local lastCreateAt = {} -- employeeId -> os.time(), Spam-Schutz (createCooldownSeconds)

local function categoryCatalogEntry(categoryKey, subcategoryKey)
    for _, cat in ipairs(Config.Warnings.categories) do
        if cat.key == categoryKey then
            for _, sub in ipairs(cat.subcategories) do
                if sub.key == subcategoryKey then
                    return cat, sub
                end
            end
        end
    end
    return nil, nil
end

local function distanceMeters(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local WARNING_SELECT = [[
    SELECT w.*, e.name AS created_by_name
    FROM st_warnings w
    JOIN st_employees e ON e.id = w.created_by
]]

--- Nur aktive UND noch gültige Meldungen - die Ablauf-Bedingung steht
--- direkt in JEDER Abfrage, nicht nur im periodischen Aufräum-Thread
--- unten, damit "aktiv" nie hinter dem tatsächlichen Ablaufzeitpunkt
--- zurückbleibt.
local function listActiveWarnings()
    return MySQL.query.await(WARNING_SELECT .. " WHERE w.status = 'active' AND w.expires_at > NOW() ORDER BY w.created_at DESC")
end

local function getActiveWarning(warningId)
    return MySQL.single.await(WARNING_SELECT .. ' WHERE w.id = ? AND w.status = ? AND w.expires_at > NOW()', { warningId, 'active' })
end

--- Wirft, wenn der Aufrufer weder warnings_manage hat noch nah genug an
--- der Meldung dran ist (verhindert Bestätigen/Verwerfen quer über die
--- ganze Karte ohne jeden Bezug zur Meldung).
local function requireNearOrModerator(src, emp, warning)
    if Roles.HasPermission(emp.role, 'warnings_manage') then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then error('player_not_found') end
    local coords = GetEntityCoords(ped)
    if distanceMeters(coords.x, coords.y, warning.x, warning.y) > Config.Warnings.moderationRadiusMeters then
        error('too_far_away')
    end
end

RPC.Register('warnings:list', function(src)
    Employees.RequireRole(src)
    return { warnings = listActiveWarnings() }
end)

--- Aktuelle Position des Aufrufers - für die "Wo bin ich"-Markierung auf
--- der Warnmeldungen-Karte und die Entfernungsanzeige im Detail-Modal.
--- Getrennt von der beim Erstellen tatsächlich verwendeten Position (die
--- wird in warnings:create IMMER frisch gelesen, nie hier zwischengespeichert).
RPC.Register('warnings:currentPosition', function(src)
    Employees.RequireRole(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then error('player_not_found') end
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z }
end)

RPC.Register('warnings:create', function(src, payload)
    local emp = Employees.RequireRole(src)

    local cat, sub = categoryCatalogEntry(payload.category, payload.subcategory)
    if not cat or not sub then error('invalid_category') end

    local now = os.time()
    if lastCreateAt[emp.id] and (now - lastCreateAt[emp.id]) < Config.Warnings.createCooldownSeconds then
        error('rate_limited')
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then error('player_not_found') end
    local coords = GetEntityCoords(ped)

    local warningId = MySQL.insert.await([[
        INSERT INTO st_warnings (category, subcategory, x, y, z, created_by, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], {
        cat.key, sub.key,
        Utils.Round2(coords.x), Utils.Round2(coords.y), Utils.Round2(coords.z),
        emp.id, Config.Warnings.lifetimeMinutes,
    })

    lastCreateAt[emp.id] = now

    local row = MySQL.single.await(WARNING_SELECT .. ' WHERE w.id = ?', { warningId })
    RPC.PushBroadcast('warnings:changed', { type = 'created', warning = row })
    return { warning = row }
end)

RPC.Register('warnings:confirm', function(src, payload)
    local emp = Employees.RequireRole(src)
    local warningId = Utils.SanitizeNumber(payload.warningId, 1, 999999999)
    if not warningId then error('invalid_payload') end

    local warning = getActiveWarning(warningId)
    if not warning then error('warning_not_found') end

    requireNearOrModerator(src, emp, warning)

    local existing = MySQL.single.await('SELECT id FROM st_warning_confirmations WHERE warning_id = ? AND employee_id = ?', { warningId, emp.id })
    if existing then error('already_confirmed') end

    MySQL.insert.await('INSERT INTO st_warning_confirmations (warning_id, employee_id) VALUES (?, ?)', { warningId, emp.id })
    MySQL.update.await([[
        UPDATE st_warnings SET expires_at = DATE_ADD(NOW(), INTERVAL ? MINUTE), confirm_count = confirm_count + 1
        WHERE id = ?
    ]], { Config.Warnings.lifetimeMinutes, warningId })

    local row = MySQL.single.await(WARNING_SELECT .. ' WHERE w.id = ?', { warningId })
    RPC.PushBroadcast('warnings:changed', { type = 'confirmed', warning = row })
    return { warning = row }
end)

local function removeWarning(warningId, removedBy)
    MySQL.update.await('UPDATE st_warnings SET status = ?, removed_by = ?, removed_at = NOW() WHERE id = ?', { 'removed', removedBy, warningId })
    RPC.PushBroadcast('warnings:changed', { type = 'removed', warningId = warningId })
end

RPC.Register('warnings:reject', function(src, payload)
    local emp = Employees.RequireRole(src)
    local warningId = Utils.SanitizeNumber(payload.warningId, 1, 999999999)
    if not warningId then error('invalid_payload') end

    local warning = getActiveWarning(warningId)
    if not warning then error('warning_not_found') end

    requireNearOrModerator(src, emp, warning)
    removeWarning(warningId, emp.id)
    return { ok = true }
end)

--- Moderation: warnings_manage darf jede eigene wie fremde Meldung von
--- überall löschen, ohne die Nähe-Vorgabe aus requireNearOrModerator.
RPC.Register('warnings:remove', function(src, payload)
    local emp = Employees.RequirePermission(src, 'warnings_manage')
    local warningId = Utils.SanitizeNumber(payload.warningId, 1, 999999999)
    if not warningId then error('invalid_payload') end

    local warning = MySQL.single.await('SELECT id FROM st_warnings WHERE id = ? AND status = ?', { warningId, 'active' })
    if not warning then error('warning_not_found') end

    removeWarning(warningId, emp.id)
    return { ok = true }
end)

RPC.Register('warnings:mine', function(src)
    local emp = Employees.RequireRole(src)
    local rows = MySQL.query.await(WARNING_SELECT .. ' WHERE w.created_by = ? ORDER BY w.created_at DESC LIMIT 50', { emp.id })
    return { warnings = rows }
end)

-- ---------------------------------------------------------
-- Aufräumen (Restart-Verhalten + periodischer Ablauf)
-- ---------------------------------------------------------

CreateThread(function()
    if Config.Warnings.clearOnRestart then
        MySQL.query.await('DELETE FROM st_warnings')
        print('^3[speditions-tablet]^7 Warnmeldungen beim Ressourcenstart geleert (Config.Warnings.clearOnRestart = true).')
    else
        -- Deckt die Zeit ab, in der die Ressource nicht lief: alles, was
        -- inzwischen abgelaufen ist, sofort als 'expired' markieren, statt
        -- bis zum ersten periodischen Tick zu warten.
        MySQL.query.await("UPDATE st_warnings SET status = 'expired' WHERE status = 'active' AND expires_at <= NOW()")
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        local ok, err = pcall(function()
            local result = MySQL.update.await("UPDATE st_warnings SET status = 'expired' WHERE status = 'active' AND expires_at <= NOW()")
            if result and result > 0 then
                RPC.PushBroadcast('warnings:changed', { type = 'expired_batch' })
            end
        end)
        if not ok then
            print(('^1[speditions-tablet]^7 Fehler beim Warnmeldungen-Ablauf-Tick: %s'):format(err))
        end
    end
end)
