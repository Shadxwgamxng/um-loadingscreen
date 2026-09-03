-- =========================================================
-- Unternehmensfinanzen: Transaktions-Ledger, Guthaben, Auszahlungen
--
-- WICHTIG: Es wird niemals nur ein Kontostand überschrieben.
-- Jede Einnahme und jede Auszahlung wird als eigener, unveränderlicher
-- Eintrag in st_transactions gespeichert. st_company_balance ist
-- lediglich ein Performance-Cache der Summe aller Transaktionen und
-- wird ausschließlich innerhalb von Finance.AddTransaction aktualisiert.
-- =========================================================

Finance = {}

function Finance.GetBalance()
    local row = MySQL.single.await('SELECT balance FROM st_company_balance WHERE id = 1')
    return row and tonumber(row.balance) or 0
end

--- Fügt eine Transaktion hinzu und schreibt den neuen Saldo in den Cache.
--- amount ist VORZEICHENBEHAFTET (Einnahme positiv, Auszahlung negativ).
function Finance.AddTransaction(txType, amount, opts)
    opts = opts or {}
    amount = Utils.Round2(amount)

    local txId = MySQL.insert.await(
        [[INSERT INTO st_transactions
            (type, amount, related_order_id, related_payout_id, related_deposit_id, driver_id, description, created_by)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            txType, amount,
            opts.relatedOrderId, opts.relatedPayoutId, opts.relatedDepositId, opts.driverId,
            opts.description, opts.createdBy,
        }
    )

    MySQL.update.await('UPDATE st_company_balance SET balance = balance + ? WHERE id = 1', { amount })

    RPC.PushToRole(Config.Roles.GESCHAEFTSFUEHRUNG, 'finance:balanceChanged', { balance = Finance.GetBalance() })

    return txId
end

--- Verbucht die Einnahme eines abgeschlossenen Auftrags für das Unternehmen.
function Finance.RecordOrderRevenue(orderId, driverId, amount, description)
    return Finance.AddTransaction('einnahme', amount, {
        relatedOrderId = orderId,
        driverId = driverId,
        description = description,
    })
end

local function sumBetween(sqlDateFilter, extraParams, txType)
    local params = { txType }
    for _, p in ipairs(extraParams or {}) do params[#params + 1] = p end
    local row = MySQL.single.await(
        ('SELECT COALESCE(SUM(amount), 0) AS total FROM st_transactions WHERE type = ? AND %s'):format(sqlDateFilter),
        params
    )
    return row and Utils.Round2(row.total) or 0
end

function Finance.GetOverview()
    local todayRevenue = sumBetween('DATE(created_at) = CURDATE()', {}, 'einnahme')
    local weekRevenue = sumBetween('YEARWEEK(created_at, 1) = YEARWEEK(NOW(), 1)', {}, 'einnahme')
    local monthRevenue = sumBetween('YEAR(created_at) = YEAR(NOW()) AND MONTH(created_at) = MONTH(NOW())', {}, 'einnahme')

    return {
        balance = Finance.GetBalance(),
        revenueToday = todayRevenue,
        revenueWeek = weekRevenue,
        revenueMonth = monthRevenue,
    }
end

function Finance.GetTransactions(limit, offset, typeFilter)
    limit = Utils.SanitizeNumber(limit, 1, 200) or 50
    offset = Utils.SanitizeNumber(offset, 0) or 0

    local where = ''
    local params = {}
    if Utils.InTable({ 'einnahme', 'auszahlung', 'einzahlung' }, typeFilter) then
        where = 'WHERE t.type = ?'
        params[#params + 1] = typeFilter
    end

    params[#params + 1] = limit
    params[#params + 1] = offset

    return MySQL.query.await(([[
        SELECT t.id, t.type, t.amount, t.description, t.created_at,
               d.id AS driver_id, de.name AS driver_name,
               ce.name AS created_by_name
        FROM st_transactions t
        LEFT JOIN st_drivers d ON d.id = t.driver_id
        LEFT JOIN st_employees de ON de.id = d.employee_id
        LEFT JOIN st_employees ce ON ce.id = t.created_by
        %s
        ORDER BY t.created_at DESC, t.id DESC
        LIMIT ? OFFSET ?
    ]]):format(where), params)
end

--- Fahrer-Einnahmenübersicht (Unternehmensgeld, KEINE Auszahlung an den Fahrer).
function Finance.GetDriverEarnings(driverId)
    local weekTotal = MySQL.single.await(
        [[SELECT COALESCE(SUM(amount), 0) AS total FROM st_transactions
          WHERE type = 'einnahme' AND driver_id = ? AND YEARWEEK(created_at, 1) = YEARWEEK(NOW(), 1)]],
        { driverId }
    )
    local monthTotal = MySQL.single.await(
        [[SELECT COALESCE(SUM(amount), 0) AS total FROM st_transactions
          WHERE type = 'einnahme' AND driver_id = ? AND YEAR(created_at) = YEAR(NOW()) AND MONTH(created_at) = MONTH(NOW())]],
        { driverId }
    )
    local allTotal = MySQL.single.await(
        [[SELECT COALESCE(SUM(amount), 0) AS total FROM st_transactions
          WHERE type = 'einnahme' AND driver_id = ?]],
        { driverId }
    )

    return {
        thisWeek = weekTotal and Utils.Round2(weekTotal.total) or 0,
        thisMonth = monthTotal and Utils.Round2(monthTotal.total) or 0,
        total = allTotal and Utils.Round2(allTotal.total) or 0,
    }
end

--- Führt eine Auszahlung durch. NUR Geschäftsführung. Betrag wird serverseitig
--- gegen das tatsächliche Guthaben geprüft - der Client kann hier nichts fälschen.
function Finance.ExecutePayout(src, amount, reason, target)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })

    amount = Utils.SanitizeNumber(amount, 0.01)
    reason = Utils.SanitizeString(reason, 255)
    target = Utils.SanitizeString(target, 100) or Config.DefaultPayoutTarget

    if not amount then error('invalid_amount') end
    if not reason then error('missing_reason') end

    local balance = Finance.GetBalance()
    if amount > balance then error('insufficient_balance') end

    local txId = Finance.AddTransaction('auszahlung', -amount, {
        description = ('Auszahlung: %s'):format(reason),
        createdBy = emp.id,
    })

    local payoutId = MySQL.insert.await(
        'INSERT INTO st_payouts (amount, reason, target, executed_by, transaction_id) VALUES (?, ?, ?, ?, ?)',
        { amount, reason, target, emp.id, txId }
    )

    MySQL.update.await('UPDATE st_transactions SET related_payout_id = ? WHERE id = ?', { payoutId, txId })

    Logs.Write(emp.id, 'payout_executed', ('%s hat eine Auszahlung über %s durchgeführt (Grund: %s).'):format(emp.name, amount, reason))

    return { payoutId = payoutId, newBalance = Finance.GetBalance() }
end

function Finance.GetPayoutHistory(limit)
    limit = Utils.SanitizeNumber(limit, 1, 200) or 50
    return MySQL.query.await([[
        SELECT p.id, p.amount, p.reason, p.target, p.executed_at, e.name AS executed_by_name
        FROM st_payouts p
        LEFT JOIN st_employees e ON e.id = p.executed_by
        ORDER BY p.executed_at DESC, p.id DESC
        LIMIT ?
    ]], { limit })
end

--- Verbucht eine Einzahlung ins Unternehmensguthaben. NUR Geschäftsführung.
--- Genau wie bei der Auszahlung entscheidet ausschließlich der Server über
--- den tatsächlich verbuchten Betrag - der Client liefert nur den Wunschwert.
function Finance.ExecuteDeposit(src, amount, reason, source)
    local emp = Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })

    amount = Utils.SanitizeNumber(amount, 0.01)
    reason = Utils.SanitizeString(reason, 255)
    source = Utils.SanitizeString(source, 100) or 'Bareinzahlung'

    if not amount then error('invalid_amount') end
    if not reason then error('missing_reason') end

    local txId = Finance.AddTransaction('einzahlung', amount, {
        description = ('Einzahlung: %s'):format(reason),
        createdBy = emp.id,
    })

    local depositId = MySQL.insert.await(
        'INSERT INTO st_deposits (amount, reason, source, executed_by, transaction_id) VALUES (?, ?, ?, ?, ?)',
        { amount, reason, source, emp.id, txId }
    )

    MySQL.update.await('UPDATE st_transactions SET related_deposit_id = ? WHERE id = ?', { depositId, txId })

    Logs.Write(emp.id, 'deposit_executed', ('%s hat eine Einzahlung über %s verbucht (Grund: %s).'):format(emp.name, amount, reason))

    return { depositId = depositId, newBalance = Finance.GetBalance() }
end

function Finance.GetDepositHistory(limit)
    limit = Utils.SanitizeNumber(limit, 1, 200) or 50
    return MySQL.query.await([[
        SELECT d.id, d.amount, d.reason, d.source, d.executed_at, e.name AS executed_by_name
        FROM st_deposits d
        LEFT JOIN st_employees e ON e.id = d.executed_by
        ORDER BY d.executed_at DESC, d.id DESC
        LIMIT ?
    ]], { limit })
end

-- =========================================================
-- RPC-Handler
-- =========================================================

RPC.Register('gf:finance:overview', function(src)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    return Finance.GetOverview()
end)

RPC.Register('gf:finance:transactions', function(src, payload)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    return { transactions = Finance.GetTransactions(payload.limit, payload.offset, payload.typeFilter) }
end)

RPC.Register('gf:payout:execute', function(src, payload)
    return Finance.ExecutePayout(src, payload.amount, payload.reason, payload.target)
end)

RPC.Register('gf:payout:history', function(src, payload)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    return { payouts = Finance.GetPayoutHistory(payload.limit) }
end)

RPC.Register('gf:deposit:execute', function(src, payload)
    return Finance.ExecuteDeposit(src, payload.amount, payload.reason, payload.source)
end)

RPC.Register('gf:deposit:history', function(src, payload)
    Employees.RequireRole(src, { Config.Roles.GESCHAEFTSFUEHRUNG })
    return { deposits = Finance.GetDepositHistory(payload.limit) }
end)

-- Read-only Umsatzübersicht für Disponenten (keine Auszahlungsfunktion!)
RPC.Register('dispatch:companyOrdersRevenue', function(src)
    Employees.RequireRole(src, { Config.Roles.DISPONENT, Config.Roles.GESCHAEFTSFUEHRUNG })
    local overview = Finance.GetOverview()
    return {
        revenueToday = overview.revenueToday,
        revenueWeek = overview.revenueWeek,
        revenueMonth = overview.revenueMonth,
    }
end)
