-- =========================================================
-- Nachrichten Disponent <-> Fahrer
-- =========================================================

Notifications = {}

--- Speichert eine Nachricht und pusht sie in Echtzeit, falls der Empfänger
--- gerade online ist und das Tablet bereits geöffnet hat.
function Notifications.Send(recipientRole, recipientEmployeeId, title, message, senderEmployeeId)
    local id = MySQL.insert.await(
        'INSERT INTO st_notifications (recipient_employee_id, recipient_role, title, message, sender_employee_id) VALUES (?, ?, ?, ?, ?)',
        { recipientEmployeeId, recipientRole, title, message, senderEmployeeId }
    )

    if recipientEmployeeId then
        for _, playerId in ipairs(GetPlayers()) do
            local target = tonumber(playerId)
            local cached = Employees.GetCached(target)
            if cached and cached.id == recipientEmployeeId then
                RPC.Push(target, 'notifications:new', { id = id, title = title, message = message })
            end
        end
    elseif recipientRole then
        RPC.PushToRole(recipientRole, 'notifications:new', { id = id, title = title, message = message })
    end

    return id
end

function Notifications.List(employeeId, limit)
    limit = Utils.SanitizeNumber(limit, 1, 200) or 50
    return MySQL.query.await([[
        SELECT n.id, n.title, n.message, n.read_state, n.created_at, s.name AS sender_name
        FROM st_notifications n
        LEFT JOIN st_employees s ON s.id = n.sender_employee_id
        WHERE n.recipient_employee_id = ?
        ORDER BY n.created_at DESC
        LIMIT ?
    ]], { employeeId, limit })
end

function Notifications.MarkRead(employeeId, notificationId)
    if notificationId then
        MySQL.update.await('UPDATE st_notifications SET read_state = 1 WHERE id = ? AND recipient_employee_id = ?', { notificationId, employeeId })
    else
        MySQL.update.await('UPDATE st_notifications SET read_state = 1 WHERE recipient_employee_id = ? AND read_state = 0', { employeeId })
    end
end

-- =========================================================
-- RPC-Handler
-- =========================================================

RPC.Register('driver:messages', function(src, payload)
    local emp = Employees.RequireRole(src, { Config.Roles.FAHRER })
    return { messages = Notifications.List(emp.id, payload.limit) }
end)

RPC.Register('driver:markMessageRead', function(src, payload)
    local emp = Employees.RequireRole(src, { Config.Roles.FAHRER })
    Notifications.MarkRead(emp.id, Utils.SanitizeNumber(payload.notificationId, 1))
    return { ok = true }
end)

RPC.Register('dispatch:messageDriver', function(src, payload)
    local emp = Employees.RequireRole(src, { Config.Roles.DISPONENT, Config.Roles.GESCHAEFTSFUEHRUNG })
    local driverId = Utils.SanitizeNumber(payload.driverId, 1)
    local message = Utils.SanitizeString(payload.message, 500)
    if not driverId or not message then error('invalid_payload') end

    local driver = Drivers.GetById(driverId)
    if not driver then error('driver_not_found') end

    Notifications.Send(nil, driver.employee_id, ('Nachricht von %s'):format(emp.name), message, emp.id)
    Logs.Write(emp.id, 'message_sent', ('%s hat einer Nachricht an Fahrer #%s gesendet.'):format(emp.name, driverId))

    return { ok = true }
end)
