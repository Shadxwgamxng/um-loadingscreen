-- =========================================================
-- Mitarbeiter-Login (Name + Passwort) & Ersteinrichtung
--
-- Das Tablet hat ein eigenes Login, unabhängig vom FiveM-Charakter: ein
-- Mitarbeiter meldet sich mit Name (`username`) und Passwort an, nicht
-- automatisch über seinen Charakter. `loggedIn[src]` hält fest, als
-- welcher Mitarbeiter der aktuelle Server-Slot gerade angemeldet ist -
-- das ist die einzige Quelle der Wahrheit für Berechtigungsprüfungen.
-- Passwörter werden nie im Klartext gespeichert (SHA2 + Salt über MySQL -
-- es gibt keine Crypto-Bibliothek in reinem Lua/FiveM ohne zusätzliche
-- Abhängigkeit, für den Spielkontext aber ausreichend).
--
-- Die allererste Rolle kommt aus Config.InitialAccounts (einmalig beim
-- ersten Ressourcenstart angelegt). Weitere Konten legt die
-- Geschäftsführung im Tablet an, oder ein Server-Admin über die Konsole:
--   tablet_grant [name] [passwort] [fahrer|disponent|geschaeftsfuehrung] [Anzeigename...]
-- =========================================================

Employees = {}

local loggedIn = {} -- [src] = employee row (nur solange angemeldet)

local function loadEmployeeByUsername(username)
    return MySQL.single.await('SELECT * FROM st_employees WHERE username = ? LIMIT 1', { username })
end

local function loadEmployeeById(id)
    return MySQL.single.await('SELECT * FROM st_employees WHERE id = ? LIMIT 1', { id })
end

function Employees.GenerateSalt()
    local chars = '0123456789abcdef'
    local parts = {}
    for i = 1, 16 do
        local idx = math.random(1, #chars)
        parts[i] = chars:sub(idx, idx)
    end
    return table.concat(parts)
end

function Employees.HashPassword(password, salt)
    local row = MySQL.single.await('SELECT SHA2(CONCAT(?, ?), 256) AS hash', { password, salt })
    return row and row.hash
end

--- Setzt (oder ändert) das Passwort eines Mitarbeiters.
function Employees.SetPassword(employeeId, password)
    local salt = Employees.GenerateSalt()
    local hash = Employees.HashPassword(password, salt)
    MySQL.update.await('UPDATE st_employees SET password_hash = ?, password_salt = ? WHERE id = ?', { hash, salt, employeeId })
end

--- Meldet den aktuellen Server-Slot als den angegebenen Mitarbeiter an.
--- Prüft Name/Passwort ausschließlich serverseitig gegen die DB.
function Employees.Login(src, username, password)
    username = Utils.SanitizeString(username, 50)
    password = Utils.SanitizeString(password, 100)
    if not username or not password then error('invalid_credentials') end

    local emp = loadEmployeeByUsername(username)
    if not emp or not emp.password_hash then error('invalid_credentials') end
    if Employees.HashPassword(password, emp.password_salt) ~= emp.password_hash then
        error('invalid_credentials')
    end
    if emp.status ~= 'aktiv' then
        error('employee_inactive')
    end

    -- Zuletzt bekannten Charakter nur informativ mitschreiben (kein Auth-Faktor,
    -- z.B. für Support-Zwecke nützlich).
    local identifier = Utils.GetIdentifier(src)
    if identifier then
        MySQL.update.await('UPDATE st_employees SET identifier = ? WHERE id = ?', { identifier, emp.id })
        emp.identifier = identifier
    end

    loggedIn[src] = emp
    Logs.Write(emp.id, 'login', ('%s hat sich am Tablet angemeldet.'):format(emp.name))

    return {
        ok = true,
        employee = { id = emp.id, name = emp.name, role = emp.role, hiredAt = emp.hired_at },
        roleLabels = Config.RoleLabels,
        driverPermissions = Config.DriverPermissions,
        vehicleClasses = Config.VehicleClasses,
        vehicleStatuses = Config.VehicleStatus,
    }
end

function Employees.Logout(src)
    local emp = loggedIn[src]
    loggedIn[src] = nil
    if emp then
        Logs.Write(emp.id, 'logout', ('%s hat sich vom Tablet abgemeldet.'):format(emp.name))
    end
end

function Employees.GetLoggedIn(src)
    return loggedIn[src]
end

--- Aktualisiert den Sitzungscache eines Mitarbeiters (z.B. nach Rollen-/
--- Statusänderung durch die Geschäftsführung), falls er gerade angemeldet ist.
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
--- einer der erlaubten Rollen angemeldet ist. Gibt andernfalls den
--- Mitarbeiter-Datensatz zurück.
---@param src number
---@param allowedRoles table|nil Liste erlaubter Rollen. nil = jede angemeldete Rolle reicht.
function Employees.RequireRole(src, allowedRoles)
    local emp = loggedIn[src]
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
    Employees.Logout(source)
end)

-- =========================================================
-- Ersteinrichtung: Konten aus Config.InitialAccounts anlegen, falls der
-- Name noch nicht existiert. Läuft einmalig bei jedem Ressourcenstart.
-- =========================================================

CreateThread(function()
    for _, account in ipairs(Config.InitialAccounts or {}) do
        local existing = loadEmployeeByUsername(account.username)
        if not existing then
            local employeeId = MySQL.insert.await(
                'INSERT INTO st_employees (username, name, role, status) VALUES (?, ?, ?, ?)',
                { account.username, account.name or account.username, account.role or Config.Roles.GESCHAEFTSFUEHRUNG, 'aktiv' }
            )
            Employees.SetPassword(employeeId, account.password)
            if account.role == Config.Roles.FAHRER then
                Drivers.EnsureDriverRecord(employeeId)
            end
            print(('^2[speditions-tablet]^7 Erstkonto angelegt: "%s" (Rolle: %s). Bitte Passwort nach dem ersten Login ändern!'):format(account.username, account.role or Config.Roles.GESCHAEFTSFUEHRUNG))
        end
    end
end)

-- =========================================================
-- Admin-Bootstrap-Command
-- Erlaubt es Server-Admins (Konsole oder Ace-Permission), ohne Zugriff
-- auf das Tablet selbst ein Mitarbeiterkonto anzulegen oder dessen
-- Rolle/Passwort zurückzusetzen - unabhängig davon, ob die Zielperson
-- gerade online ist.
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

    local username = args[1]
    local password = args[2]
    local role = args[3]
    local name = table.concat(args, ' ', 4)
    if name == '' then name = username end

    if not username or not password or not role or not Utils.InTable({ 'fahrer', 'disponent', 'geschaeftsfuehrung' }, role) then
        reply('Nutzung: tablet_grant [name] [passwort] [fahrer|disponent|geschaeftsfuehrung] [Anzeigename...]')
        return
    end

    local existing = loadEmployeeByUsername(username)
    local employeeId

    if existing then
        MySQL.update.await('UPDATE st_employees SET role = ?, status = ?, name = ? WHERE id = ?', { role, 'aktiv', name, existing.id })
        employeeId = existing.id
    else
        employeeId = MySQL.insert.await('INSERT INTO st_employees (username, name, role, status) VALUES (?, ?, ?, ?)', { username, name, role, 'aktiv' })
    end

    Employees.SetPassword(employeeId, password)
    Employees.RefreshLoginById(employeeId)

    if role == Config.Roles.FAHRER then
        Drivers.EnsureDriverRecord(employeeId)
    end

    Logs.Write(nil, 'admin_grant', ('Admin hat Konto "%s" mit Rolle "%s" angelegt/aktualisiert.'):format(username, role))
    reply(('Konto "%s" wurde mit Rolle "%s" angelegt/aktualisiert und das Passwort gesetzt.'):format(username, role))
end, true)
