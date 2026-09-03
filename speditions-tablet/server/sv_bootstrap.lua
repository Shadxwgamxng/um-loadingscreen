-- =========================================================
-- Mitarbeiter-Cache, Session-Auflösung & Ersteinrichtung
-- =========================================================

Employees = {}

local cache = {} -- [src] = employee row

local function loadEmployeeByIdentifier(identifier)
    return MySQL.single.await(
        'SELECT * FROM st_employees WHERE identifier = ? LIMIT 1',
        { identifier }
    )
end

--- Lädt (oder erstellt bei InitialOwners) den Mitarbeiter-Datensatz für einen
--- verbundenen Spieler und legt ihn im Server-Cache ab. Wird beim Öffnen des
--- Tablets aufgerufen (session:init).
function Employees.Resolve(src)
    local identifier = Utils.GetIdentifier(src)
    if not identifier then return nil end

    local emp = loadEmployeeByIdentifier(identifier)

    if not emp and Utils.InTable(Config.InitialOwners, identifier) then
        local name = Utils.GetPlayerName(src)
        local insertId = MySQL.insert.await(
            'INSERT INTO st_employees (identifier, name, role, status) VALUES (?, ?, ?, ?)',
            { identifier, name, Config.Roles.GESCHAEFTSFUEHRUNG, 'aktiv' }
        )
        if insertId then
            emp = loadEmployeeByIdentifier(identifier)
            Logs.Write(nil, 'bootstrap_owner', ('%s wurde automatisch als Geschäftsführung angelegt (InitialOwners).'):format(name))
        end
    end

    if emp then
        cache[src] = emp
    else
        cache[src] = nil
    end

    return emp
end

function Employees.GetCached(src)
    return cache[src]
end

--- Erzwingt einen frischen DB-Read und aktualisiert den Cache (z.B. nach Rollenwechsel).
function Employees.Refresh(src)
    local emp = cache[src]
    if not emp then return Employees.Resolve(src) end
    local fresh = MySQL.single.await('SELECT * FROM st_employees WHERE id = ? LIMIT 1', { emp.id })
    cache[src] = fresh
    return fresh
end

function Employees.ClearCache(src)
    cache[src] = nil
end

--- Wirft einen Fehler, falls der Spieler kein aktiver Mitarbeiter mit einer der
--- erlaubten Rollen ist. Gibt andernfalls den Mitarbeiter-Datensatz zurück.
---@param src number
---@param allowedRoles table|nil Liste erlaubter Rollen. nil = jede aktive Rolle reicht.
function Employees.RequireRole(src, allowedRoles)
    local emp = cache[src]
    if not emp then
        emp = Employees.Resolve(src)
    end
    if not emp then
        error('not_employee')
    end
    if emp.status ~= 'aktiv' then
        error('employee_inactive')
    end
    if allowedRoles and not Utils.InTable(allowedRoles, emp.role) then
        error('forbidden_role')
    end
    return emp
end

AddEventHandler('playerDropped', function()
    local src = source
    Employees.ClearCache(src)
end)

-- =========================================================
-- Admin-Bootstrap-Command
-- Erlaubt es Server-Admins (Konsole oder Ace-Permission), ohne
-- direkten Datenbankzugriff die erste Geschäftsführung anzulegen
-- bzw. weitere Mitarbeiter zu bootstrappen.
-- =========================================================

RegisterCommand('tablet_grant', function(src, args)
    local isConsole = src == 0
    if not isConsole and not IsPlayerAceAllowed(src, Config.AdminAcePermission) then
        if src ~= 0 then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Speditions-Tablet', 'Keine Berechtigung.' } })
        end
        return
    end

    local targetId = tonumber(args[1])
    local role = args[2]

    if not targetId or not role or not Utils.InTable({ 'fahrer', 'disponent', 'geschaeftsfuehrung' }, role) then
        local msg = 'Nutzung: tablet_grant [serverId] [fahrer|disponent|geschaeftsfuehrung]'
        if isConsole then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { 'Speditions-Tablet', msg } }) end
        return
    end

    local identifier = Utils.GetIdentifier(targetId)
    if not identifier then
        local msg = 'Zielspieler nicht gefunden oder offline.'
        if isConsole then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { 'Speditions-Tablet', msg } }) end
        return
    end

    local name = Utils.GetPlayerName(targetId)
    local existing = loadEmployeeByIdentifier(identifier)

    if existing then
        MySQL.update.await('UPDATE st_employees SET role = ?, status = ? WHERE id = ?', { role, 'aktiv', existing.id })
    else
        MySQL.insert.await('INSERT INTO st_employees (identifier, name, role, status) VALUES (?, ?, ?, ?)', { identifier, name, role, 'aktiv' })
    end

    Employees.Refresh(targetId)
    Logs.Write(nil, 'admin_grant', ('Admin hat %s (%s) die Rolle "%s" zugewiesen.'):format(name, identifier, role))

    local msg = ('%s wurde die Rolle "%s" zugewiesen.'):format(name, role)
    if isConsole then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { 'Speditions-Tablet', msg } }) end
end, true)
