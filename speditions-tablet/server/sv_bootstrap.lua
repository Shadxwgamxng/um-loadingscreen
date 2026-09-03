-- =========================================================
-- Mitarbeiter-Login (Benutzername/Passwort) & Ersteinrichtung
--
-- Das Tablet hat ein eigenes Login, unabhängig vom FiveM-Charakter:
-- ein Mitarbeiter meldet sich mit Benutzername + Passwort an, nicht
-- über seine Spieler-ID/seinen Charakter. `loggedIn[src]` hält fest,
-- als welcher Mitarbeiter der aktuelle Server-Slot gerade angemeldet
-- ist - das ist die einzige Quelle der Wahrheit für Berechtigungsprüfungen.
-- =========================================================

Employees = {}

local loggedIn = {} -- [src] = employee row (nur solange eingeloggt)

local function loadEmployeeByUsername(username)
    return MySQL.single.await('SELECT * FROM st_employees WHERE username = ? LIMIT 1', { username })
end

local function loadEmployeeById(id)
    return MySQL.single.await('SELECT * FROM st_employees WHERE id = ? LIMIT 1', { id })
end

--- Berechnet den Passwort-Hash über MySQL (SHA2 + Salt). Es gibt keine
--- Crypto-Bibliothek in reinem Lua/FiveM ohne zusätzliche Abhängigkeit -
--- das ist für den Spielkontext ausreichend, aber kein Enterprise-Standard.
function Employees.HashPassword(password, salt)
    local row = MySQL.single.await('SELECT SHA2(CONCAT(?, ?), 256) AS hash', { password, salt })
    return row and row.hash
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

--- Setzt (oder ändert) das Passwort eines Mitarbeiters.
function Employees.SetPassword(employeeId, password)
    local salt = Employees.GenerateSalt()
    local hash = Employees.HashPassword(password, salt)
    MySQL.update.await('UPDATE st_employees SET password_hash = ?, password_salt = ? WHERE id = ?', { hash, salt, employeeId })
end

function Employees.VerifyPassword(employeeId, password)
    local row = MySQL.single.await('SELECT password_hash, password_salt FROM st_employees WHERE id = ?', { employeeId })
    if not row or not row.password_hash then return false end
    return Employees.HashPassword(password, row.password_salt) == row.password_hash
end

--- Meldet den aktuellen Server-Slot als den angegebenen Mitarbeiter an.
--- Prüft Benutzername/Passwort ausschließlich serverseitig gegen die DB.
function Employees.Login(src, username, password)
    username = Utils.SanitizeString(username, 50)
    password = Utils.SanitizeString(password, 100)
    if not username or not password then error('invalid_credentials') end

    local emp = loadEmployeeByUsername(username)

    if Config.Debug then
        Utils.DebugPrint(('LOGIN-DEBUG username=%q password_len=%d gefunden=%s hash_vorhanden=%s'):format(
            username, #password, tostring(emp ~= nil), tostring(emp and emp.password_hash ~= nil)
        ))
    end

    if not emp or not emp.password_hash then error('invalid_credentials') end

    local computedHash = Employees.HashPassword(password, emp.password_salt)
    if Config.Debug then
        Utils.DebugPrint(('LOGIN-DEBUG salt=%s berechneter_hash=%s gespeicherter_hash=%s stimmt_ueberein=%s'):format(
            tostring(emp.password_salt), tostring(computedHash), tostring(emp.password_hash), tostring(computedHash == emp.password_hash)
        ))
    end
    if computedHash ~= emp.password_hash then
        error('invalid_credentials')
    end
    if emp.status ~= 'aktiv' then
        error('employee_inactive')
    end

    -- Zuletzt bekannten Charakter nur informativ mitschreiben (kein Auth-Faktor).
    -- In einem pcall, damit ein Problem mit diesem rein informativen Feld
    -- (z.B. eine noch nicht bereinigte alte Unique-Sperre) niemals den
    -- eigentlichen Login blockiert.
    local identifier = Utils.GetIdentifier(src)
    if identifier then
        local ok = pcall(function()
            MySQL.update.await('UPDATE st_employees SET identifier = ? WHERE id = ?', { identifier, emp.id })
        end)
        if not ok then
            Utils.DebugPrint(('Konnte identifier fuer Mitarbeiter #%s nicht aktualisieren (nicht kritisch).'):format(emp.id))
        end
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

--- Aktualisiert den Login-Cache eines Mitarbeiters (z.B. nach Rollen-/
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
-- Benutzername noch nicht existiert. Läuft einmalig beim Ressourcenstart.
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
            print(('^2[speditions-tablet]^7 Initial-Konto angelegt: "%s" (Rolle: %s). Bitte Passwort nach dem ersten Login ändern!'):format(account.username, account.role or Config.Roles.GESCHAEFTSFUEHRUNG))
        end
    end
end)

-- =========================================================
-- Admin-Bootstrap-Command
-- Erlaubt es Server-Admins (Konsole oder Ace-Permission), ohne
-- direkten Datenbankzugriff ein Mitarbeiterkonto anzulegen oder dessen
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

    local username = args[1]
    local password = args[2]
    local role = args[3]
    local name = table.concat(args, ' ', 4)
    if name == '' then name = username end

    local function reply(msg)
        if isConsole then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { 'Speditions-Tablet', msg } }) end
    end

    if not username or not password or not role or not Utils.InTable({ 'fahrer', 'disponent', 'geschaeftsfuehrung' }, role) then
        reply('Nutzung: tablet_grant [benutzername] [passwort] [fahrer|disponent|geschaeftsfuehrung] [Anzeigename...]')
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
