-- =========================================================
-- Gehälter: Stempeluhr, Stundenlöhne je Rolle, Gehaltsauszahlung
--
-- Jeder Mitarbeiter stempelt sich selbst ein/aus. Die Geschäftsführung legt
-- den Stundenlohn je Rolle fest (in st_wage_rates, mit Config.DefaultHourlyWage
-- als einmaliger Erstbefüllung) und zahlt das automatisch aus offenen
-- Stempeluhr-Sekunden * Stundenlohn berechnete Gehalt aus - der Client kann
-- den Betrag NICHT selbst vorgeben.
-- =========================================================

Payroll = {}

local VALID_ROLES = { 'fahrer', 'disponent', 'geschaeftsfuehrung' }

CreateThread(function()
    for role, rate in pairs(Config.DefaultHourlyWage or {}) do
        local existing = MySQL.single.await('SELECT role FROM st_wage_rates WHERE role = ?', { role })
        if not existing then
            MySQL.insert.await('INSERT INTO st_wage_rates (role, hourly_rate) VALUES (?, ?)', { role, rate })
        end
    end
end)

function Payroll.GetWageRates()
    local rows = MySQL.query.await('SELECT role, hourly_rate FROM st_wage_rates')
    local rates = {}
    for _, row in ipairs(rows) do
        rates[row.role] = tonumber(row.hourly_rate)
    end
    return rates
end

function Payroll.GetWageRate(role)
    local row = MySQL.single.await('SELECT hourly_rate FROM st_wage_rates WHERE role = ?', { role })
    return row and tonumber(row.hourly_rate) or 0
end

function Payroll.SetWageRate(src, role, hourlyRate)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })

    if not Utils.InTable(VALID_ROLES, role) then error('invalid_role') end
    hourlyRate = Utils.SanitizeNumber(hourlyRate, 0, 100000)
    if not hourlyRate then error('invalid_amount') end

    local existing = MySQL.single.await('SELECT role FROM st_wage_rates WHERE role = ?', { role })
    if existing then
        MySQL.update.await('UPDATE st_wage_rates SET hourly_rate = ? WHERE role = ?', { hourlyRate, role })
    else
        MySQL.insert.await('INSERT INTO st_wage_rates (role, hourly_rate) VALUES (?, ?)', { role, hourlyRate })
    end

    Logs.Write(emp.id, 'wage_rate_changed', ('%s hat den Stundenlohn für "%s" auf %s gesetzt.'):format(emp.name, Config.RoleLabels[role] or role, hourlyRate))
    return { ok = true }
end

-- ---------------------------------------------------------
-- Stempeluhr
-- ---------------------------------------------------------

function Payroll.GetActiveSession(employeeId)
    return MySQL.single.await('SELECT * FROM st_timeclock_sessions WHERE employee_id = ? AND clock_out_at IS NULL LIMIT 1', { employeeId })
end

--- Offene (noch nicht ausgezahlte) Sekunden eines Mitarbeiters - abgeschlossene
--- Sessions plus die laufende Session bis jetzt (falls gerade eingestempelt).
function Payroll.GetUnpaidSeconds(employeeId)
    local row = MySQL.single.await([[
        SELECT COALESCE(SUM(TIMESTAMPDIFF(SECOND, clock_in_at, IFNULL(clock_out_at, NOW()))), 0) AS total
        FROM st_timeclock_sessions
        WHERE employee_id = ? AND paid_at IS NULL
    ]], { employeeId })
    return row and tonumber(row.total) or 0
end

function Payroll.ClockIn(src)
    local emp = Employees.RequireRole(src)
    if Payroll.GetActiveSession(emp.id) then error('already_clocked_in') end

    MySQL.insert.await('INSERT INTO st_timeclock_sessions (employee_id, clock_in_at) VALUES (?, NOW())', { emp.id })
    Logs.Write(emp.id, 'clock_in', ('%s hat sich eingestempelt.'):format(emp.name))
    return { ok = true }
end

function Payroll.ClockOut(src)
    local emp = Employees.RequireRole(src)
    local active = Payroll.GetActiveSession(emp.id)
    if not active then error('not_clocked_in') end

    MySQL.update.await('UPDATE st_timeclock_sessions SET clock_out_at = NOW() WHERE id = ?', { active.id })
    Logs.Write(emp.id, 'clock_out', ('%s hat sich ausgestempelt.'):format(emp.name))
    return { ok = true }
end

function Payroll.GetMyStatus(src)
    local emp = Employees.RequireRole(src)
    local active = Payroll.GetActiveSession(emp.id)
    local unpaidSeconds = Payroll.GetUnpaidSeconds(emp.id)
    local rate = Payroll.GetWageRate(emp.role)
    return {
        clockedIn = active ~= nil,
        clockInAt = active and active.clock_in_at or nil,
        unpaidSeconds = unpaidSeconds,
        hourlyRate = rate,
        estimatedAmount = Utils.Round2((unpaidSeconds / 3600) * rate),
    }
end

-- ---------------------------------------------------------
-- Gehaltsübersicht + Auszahlung (nur Geschäftsführung)
-- ---------------------------------------------------------

function Payroll.GetOverview()
    local employees = MySQL.query.await(
        "SELECT id, name, role FROM st_employees WHERE status = 'aktiv' ORDER BY FIELD(role, 'geschaeftsfuehrung', 'disponent', 'fahrer'), name ASC"
    )
    local rates = Payroll.GetWageRates()

    local list = {}
    for _, e in ipairs(employees) do
        local seconds = Payroll.GetUnpaidSeconds(e.id)
        local rate = rates[e.role] or 0
        list[#list + 1] = {
            id = e.id,
            name = e.name,
            role = e.role,
            unpaidSeconds = seconds,
            hourlyRate = rate,
            amount = Utils.Round2((seconds / 3600) * rate),
            clockedIn = Payroll.GetActiveSession(e.id) ~= nil,
        }
    end
    return list
end

--- Zahlt einem Mitarbeiter das aktuell errechnete Gehalt aus (offene
--- Stempeluhr-Sekunden * Stundenlohn seiner Rolle). Betrag wird
--- ausschließlich serverseitig berechnet.
function Payroll.PayEmployee(src, employeeId)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })

    employeeId = Utils.SanitizeNumber(employeeId, 1)
    if not employeeId then error('invalid_payload') end

    local target = MySQL.single.await('SELECT * FROM st_employees WHERE id = ?', { employeeId })
    if not target then error('employee_not_found') end

    local seconds = Payroll.GetUnpaidSeconds(employeeId)
    local rate = Payroll.GetWageRate(target.role)
    local hours = Utils.Round2(seconds / 3600)
    local amount = Utils.Round2(hours * rate)
    if amount <= 0 then error('nothing_to_pay') end

    local balance = Finance.GetBalance()
    if amount > balance then error('insufficient_balance') end

    -- Läuft die Stempeluhr gerade, wird die aktuelle Session jetzt
    -- geschlossen, ALLE noch unbezahlten Sessions als bezahlt markiert und
    -- - falls der Mitarbeiter noch eingestempelt war - nahtlos eine neue
    -- Session begonnen, damit die Zeiterfassung einfach weiterläuft.
    local active = Payroll.GetActiveSession(employeeId)
    if active then
        MySQL.update.await('UPDATE st_timeclock_sessions SET clock_out_at = NOW() WHERE id = ?', { active.id })
    end
    MySQL.update.await('UPDATE st_timeclock_sessions SET paid_at = NOW() WHERE employee_id = ? AND paid_at IS NULL', { employeeId })
    if active then
        MySQL.insert.await('INSERT INTO st_timeclock_sessions (employee_id, clock_in_at) VALUES (?, NOW())', { employeeId })
    end

    local txId = Finance.AddTransaction('gehalt', -amount, {
        description = ('Gehalt: %s (%.2f Std. x %s)'):format(target.name, hours, rate),
        createdBy = emp.id,
    })

    -- Das Gehalt bekommt der MITARBEITER als Bargeld, nicht die
    -- ausführende Geschäftsführung - nur möglich, wenn dieser Mitarbeiter
    -- gerade online UND am Tablet erkannt ist.
    local targetSrc = Utils.FindSrcByEmployeeId(employeeId)
    local cashGiven = false
    if targetSrc then
        cashGiven = Bridge.AddCash(targetSrc, amount)
    end

    MySQL.insert.await(
        'INSERT INTO st_payroll_payouts (employee_id, hours, hourly_rate, amount, executed_by, transaction_id, cash_given) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { employeeId, hours, rate, amount, emp.id, txId, cashGiven }
    )

    Logs.Write(emp.id, 'payroll_paid', ('%s hat %s das Gehalt ausgezahlt (%.2f Std. x %s = %s).%s'):format(
        emp.name, target.name, hours, rate, amount,
        cashGiven and ' Bargeld ausgehändigt.' or (targetSrc and ' Bargeld-Anbindung fehlgeschlagen.' or ' Mitarbeiter nicht online, kein Bargeld übergeben.')
    ))

    if targetSrc then
        Utils.NotifyClient(targetSrc, ('Dir wurde ein Gehalt von %s ausgezahlt.'):format(amount), 'success')
    end

    return { amount = amount, hours = hours, cashGiven = cashGiven, newBalance = Finance.GetBalance() }
end

-- =========================================================
-- RPC-Handler
-- =========================================================

RPC.Register('me:payrollStatus', function(src)
    return Payroll.GetMyStatus(src)
end)

RPC.Register('me:clockIn', function(src)
    return Payroll.ClockIn(src)
end)

RPC.Register('me:clockOut', function(src)
    return Payroll.ClockOut(src)
end)

RPC.Register('gf:payroll:rates', function(src)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    return { rates = Payroll.GetWageRates(), roleLabels = Config.RoleLabels }
end)

RPC.Register('gf:payroll:setRate', function(src, payload)
    return Payroll.SetWageRate(src, payload.role, payload.hourlyRate)
end)

RPC.Register('gf:payroll:overview', function(src)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    return { employees = Payroll.GetOverview() }
end)

RPC.Register('gf:payroll:pay', function(src, payload)
    return Payroll.PayEmployee(src, payload.employeeId)
end)
