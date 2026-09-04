-- =========================================================
-- Mitarbeiter-Sitzungen & Ersteinrichtung
--
-- Kein Login-Bildschirm: ein Server-Slot wird automatisch anhand seines
-- FiveM-Charakter-Identifiers (license) seinem Mitarbeiter-Datensatz in
-- st_employees zugeordnet. `loggedIn[src]` ist dabei nur ein Zwischenspeicher
-- für die aktuelle Verbindung - keine echte "Anmeldung", sondern die einzige
-- Quelle der Wahrheit für Berechtigungsprüfungen.
--
-- Die allererste Rolle (z.B. Geschäftsführung) wird von einem Server-Admin
-- über die Konsole vergeben, während die Zielperson online ist:
--   tablet_grant [server-id] [fahrer|disponent|geschaeftsfuehrung] [Anzeigename...]
-- =========================================================

Employees = {}

local loggedIn = {} -- [src] = employee row (Sitzungscache für die aktuelle Verbindung)

local function loadEmployeeByIdentifier(identifier)
    return MySQL.single.await('SELECT * FROM st_employees WHERE identifier = ? LIMIT 1', { identifier })
end

local function loadEmployeeById(id)
    return MySQL.single.await('SELECT * FROM st_employees WHERE id = ? LIMIT 1', { id })
end

--- Ordnet den aktuellen Server-Slot automatisch seinem Mitarbeiter-Datensatz
--- zu (anhand des FiveM-Charakters) - ganz ohne Login-Bildschirm. Wird u.a.
--- beim Entsperren des Tablets über session:whoami aufgerufen.
--- Gibt nil zurück, wenn dieser Charakter (noch) kein Mitarbeiterkonto hat.
function Employees.EnsureSession(src)
    local cached = loggedIn[src]
    if cached then return cached end

    local identifier = Utils.GetIdentifier(src)
    if not identifier then return nil end

    local emp = loadEmployeeByIdentifier(identifier)
    if not emp then return nil end

    loggedIn[src] = emp
    return emp
end

function Employees.GetLoggedIn(src)
    return loggedIn[src]
end

--- Aktualisiert den Sitzungscache eines Mitarbeiters (z.B. nach Rollen-/
--- Statusänderung durch die Geschäftsführung), falls er gerade online ist.
function Employees.RefreshLoginById(employeeId)
    for src, emp in pairs(loggedIn) do
        if emp.id == employeeId then
            loggedIn[src] = loadEmployeeById(employeeId)
            return src
        end
    end
    return nil
end

--- Wirft einen Fehler, falls der Spieler nicht als aktiver Mitarbeiter mit
--- einer der erlaubten Rollen erkannt wird. Gibt andernfalls den
--- Mitarbeiter-Datensatz zurück.
---@param src number
---@param allowedRoles table|nil Liste erlaubter Rollen. nil = jede erkannte Rolle reicht.
function Employees.RequireRole(src, allowedRoles)
    local emp = Employees.EnsureSession(src)
    if not emp then
        error('not_logged_in')
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
    loggedIn[source] = nil
end)

-- =========================================================
-- Admin-Bootstrap-Command
-- Erlaubt es Server-Admins (Konsole oder Ace-Permission), einem gerade
-- ONLINEN Spieler ein Mitarbeiterkonto anzulegen oder dessen Rolle zu
-- ändern - so kommt die allererste Geschäftsführung ins System, ganz ohne
-- Benutzername/Passwort.
-- =========================================================

RegisterCommand('tablet_grant', function(src, args)
    local isConsole = src == 0
    if not isConsole and not IsPlayerAceAllowed(src, Config.AdminAcePermission) then
        if src ~= 0 then
            TriggerClientEvent('chat:addMessage', src, { args = { 'Speditions-Tablet', 'Keine Berechtigung.' } })
        end
        return
    end

    local function reply(msg)
        if isConsole then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { 'Speditions-Tablet', msg } }) end
    end

    local targetId = tonumber(args[1])
    local role = args[2]
    local name = table.concat(args, ' ', 3)

    if not targetId or not role or not Utils.InTable({ 'fahrer', 'disponent', 'geschaeftsfuehrung' }, role) then
        reply('Nutzung: tablet_grant [server-id] [fahrer|disponent|geschaeftsfuehrung] [Anzeigename...]')
        return
    end

    if not GetPlayerName(targetId) then
        reply(('Kein Spieler mit Server-ID %s online.'):format(tostring(targetId)))
        return
    end

    local identifier = Utils.GetIdentifier(targetId)
    if not identifier then
        reply('Konnte den Charakter-Identifier des Zielspielers nicht ermitteln.')
        return
    end

    if name == '' then name = GetPlayerName(targetId) end

    local existing = loadEmployeeByIdentifier(identifier)
    local employeeId

    if existing then
        MySQL.update.await('UPDATE st_employees SET role = ?, status = ?, name = ? WHERE id = ?', { role, 'aktiv', name, existing.id })
        employeeId = existing.id
    else
        employeeId = MySQL.insert.await('INSERT INTO st_employees (identifier, name, role, status) VALUES (?, ?, ?, ?)', { identifier, name, role, 'aktiv' })
    end

    Employees.RefreshLoginById(employeeId)

    if role == Config.Roles.FAHRER then
        Drivers.EnsureDriverRecord(employeeId)
    end

    Logs.Write(nil, 'admin_grant', ('Admin hat "%s" (Server-ID %s) die Rolle "%s" zugewiesen.'):format(name, targetId, role))
    reply(('"%s" (Server-ID %s) wurde die Rolle "%s" zugewiesen.'):format(name, targetId, role))
end, true)
