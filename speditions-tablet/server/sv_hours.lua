-- =========================================================
-- Lenk- und Ruhezeiten
--
-- Der Client meldet per Heartbeat aktive Fahrzeit (nur solange er
-- nachweislich auf dem Fahrersitz seines zugewiesenen Firmenfahrzeugs
-- sitzt, siehe client/cl_hours.lua) - alle Grenzwerte und die daraus
-- resultierenden Warnungen/Überschreitungen werden ausschließlich
-- serverseitig anhand von Config.DrivingRules berechnet.
-- =========================================================

Hours = {}

local function todayDate()
    return os.date('%Y-%m-%d')
end

--- Parst ein 'YYYY-MM-DD HH:MM:SS'-Datetime (oxmysql liefert Strings) in einen
--- Unix-Timestamp, um ohne zusätzlichen DB-Roundtrip Zeitdifferenzen zu bilden.
local function parseDateTime(s)
    if not s or s == '' then return nil end
    local y, mo, d, h, mi, se = s:match('(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)')
    if not y then return nil end
    return os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = tonumber(se) })
end

function Hours.EnsureRow(driverId)
    local row = MySQL.single.await('SELECT * FROM st_driver_hours WHERE driver_id = ?', { driverId })
    if not row then
        MySQL.insert.await('INSERT INTO st_driver_hours (driver_id, day_date) VALUES (?, ?)', { driverId, todayDate() })
        row = MySQL.single.await('SELECT * FROM st_driver_hours WHERE driver_id = ?', { driverId })
    end
    return row
end

--- Normalisiert Tageswechsel (tägliche Lenkzeit zurücksetzen) und eine
--- inzwischen ausreichend lange Pause (ununterbrochene Lenkzeit zurücksetzen).
--- Verändert nur das übergebene Lua-Table, NICHT die Datenbank - der Aufrufer
--- ist dafür verantwortlich, über Hours.Save() zu persistieren.
function Hours.Normalize(row)
    local today = todayDate()
    if row.day_date ~= today then
        row.day_date = today
        row.daily_driving_seconds = 0
        row.warned_daily = 0
    end

    if row.resting_since then
        local restStart = parseDateTime(row.resting_since)
        local restSeconds = restStart and (os.time() - restStart) or 0
        if restSeconds >= (Config.DrivingRules.requiredBreakMinutes * 60) then
            row.continuous_driving_seconds = 0
            row.warned_continuous = 0
            row.resting_since = nil
        end
    end

    return row
end

function Hours.Save(row)
    MySQL.update.await(
        [[UPDATE st_driver_hours SET continuous_driving_seconds = ?, daily_driving_seconds = ?,
          day_date = ?, resting_since = ?, warned_continuous = ?, warned_daily = ? WHERE driver_id = ?]],
        { row.continuous_driving_seconds, row.daily_driving_seconds, row.day_date, row.resting_since,
          row.warned_continuous, row.warned_daily, row.driver_id }
    )
end

--- Öffentlicher Status für die Fahrerkarte / Fahrerakte.
function Hours.Status(driverId)
    local row = Hours.EnsureRow(driverId)
    row = Hours.Normalize(row)
    Hours.Save(row)

    local rules = Config.DrivingRules
    return {
        continuousMinutes = math.floor(row.continuous_driving_seconds / 60),
        dailyMinutes = math.floor(row.daily_driving_seconds / 60),
        maxContinuousMinutes = rules.maxContinuousDrivingMinutes,
        maxDailyMinutes = rules.maxDailyDrivingMinutes,
        requiredBreakMinutes = rules.requiredBreakMinutes,
        resting = row.resting_since ~= nil,
        restingSince = row.resting_since,
    }
end

--- Verarbeitet einen Fahrzeit-Heartbeat vom Client (nur während er
--- nachweislich am Steuer des zugewiesenen Firmenfahrzeugs sitzt).
--- warned_continuous/warned_daily sind Zustände 0=keine Warnung,
--- 1=Warnung gesendet, 2=Überschreitung gemeldet (damit nicht bei jedem
--- Heartbeat erneut benachrichtigt wird).
function Hours.Tick(src, seconds)
    local emp = Employees.RequireRole(src, { Config.Roles.FAHRER })
    seconds = Utils.SanitizeNumber(seconds, 1, 300)
    if not seconds then error('invalid_payload') end

    local driver = Drivers.EnsureDriverRecord(emp.id)
    local row = Hours.Normalize(Hours.EnsureRow(driver.id))

    row.resting_since = nil
    row.continuous_driving_seconds = row.continuous_driving_seconds + seconds
    row.daily_driving_seconds = row.daily_driving_seconds + seconds

    local rules = Config.DrivingRules
    local contLimit = rules.maxContinuousDrivingMinutes * 60
    local dailyLimit = rules.maxDailyDrivingMinutes * 60
    local warnAt = rules.warnBeforeMinutes * 60

    if row.continuous_driving_seconds >= contLimit then
        if row.warned_continuous ~= 2 then
            Utils.NotifyClient(src, ('Lenkzeitueberschreitung! Bitte sofort eine Pause von mindestens %d Minuten einlegen.'):format(rules.requiredBreakMinutes), 'error')
            Logs.Write(emp.id, 'driving_violation', ('%s hat die maximale ununterbrochene Lenkzeit ueberschritten.'):format(emp.name))
            row.warned_continuous = 2
        end
    elseif row.continuous_driving_seconds >= (contLimit - warnAt) then
        if row.warned_continuous == 0 then
            Utils.NotifyClient(src, ('Du faehrst seit %d Minuten ununterbrochen. Plane bald eine Pause ein.'):format(math.floor(row.continuous_driving_seconds / 60)), 'warning')
            row.warned_continuous = 1
        end
    end

    if row.daily_driving_seconds >= dailyLimit then
        if row.warned_daily ~= 2 then
            Utils.NotifyClient(src, 'Du hast deine maximale taegliche Lenkzeit erreicht.', 'error')
            Logs.Write(emp.id, 'driving_violation_daily', ('%s hat die maximale taegliche Lenkzeit ueberschritten.'):format(emp.name))
            row.warned_daily = 2
        end
    elseif row.daily_driving_seconds >= (dailyLimit - warnAt) then
        if row.warned_daily == 0 then
            Utils.NotifyClient(src, 'Du naeherst dich deiner taeglichen Lenkzeitgrenze.', 'warning')
            row.warned_daily = 1
        end
    end

    Hours.Save(row)
    return { ok = true }
end

--- Der Client meldet, dass der Fahrer den Fahrersitz verlassen hat - die
--- Ruhezeit beginnt zu laufen (wird bei Hours.Normalize() nach Ablauf der
--- erforderlichen Pausendauer automatisch verrechnet).
function Hours.RestStart(src)
    local emp = Employees.RequireRole(src, { Config.Roles.FAHRER })
    local driver = Drivers.EnsureDriverRecord(emp.id)
    local row = Hours.Normalize(Hours.EnsureRow(driver.id))

    if not row.resting_since then
        row.resting_since = Utils.Now()
        Hours.Save(row)
    end

    return { ok = true }
end

-- =========================================================
-- RPC-Handler
-- =========================================================

RPC.Register('driver:drivingTick', function(src, payload)
    return Hours.Tick(src, payload.seconds)
end)

RPC.Register('driver:drivingStopped', function(src)
    return Hours.RestStart(src)
end)

RPC.Register('dispatch:remindDriver', function(src, payload)
    local emp = Employees.RequireRole(src, { Config.Roles.DISPONENT, Config.Roles.GESCHAEFTSFUEHRUNG })
    local driverId = Utils.SanitizeNumber(payload.driverId, 1)
    if not driverId then error('invalid_payload') end

    local driver = Drivers.GetById(driverId)
    if not driver then error('driver_not_found') end

    local targetSrc = Utils.FindSrcByEmployeeId(driver.employee_id)
    if targetSrc then
        Utils.NotifyClient(targetSrc, ('Erinnerung von %s: Denk an deine Lenk-/Ruhezeiten!'):format(emp.name), 'warning')
    end
    Notifications.Send(nil, driver.employee_id, 'Lenk-/Ruhezeiten-Erinnerung', ('%s erinnert dich an deine Lenk-/Ruhezeiten.'):format(emp.name), emp.id)
    Logs.Write(emp.id, 'hours_reminder', ('%s hat Fahrer #%s an die Lenk-/Ruhezeiten erinnert.'):format(emp.name, driverId))

    return { ok = true }
end)
