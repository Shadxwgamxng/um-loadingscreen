-- =========================================================
-- Dispositions-Dienst
--
-- Analog zur Fahrerkarte (st_drivers.on_shift, siehe Drivers.StartShift/
-- EndShift in server/sv_drivers.lua): ein Disponent/die Geschäftsführung
-- muss den Dispositions-Dienst hier explizit beginnen, bevor eine
-- Disposition im Sinne von isDispatcherAvailable() (server/sv_orders.lua)
-- als "aktiv" gilt. Vorher zählt ein bloß am Tablet angemeldeter Disponent
-- NICHT als verfügbar - Fahrer können sich offene Aufträge dann weiterhin
-- selbst zuweisen, selbst wenn der Disponent gerade z.B. im Fuhrpark
-- unterwegs ist statt aktiv zu disponieren.
-- =========================================================

Dispatch = {}

function Dispatch.StartDuty(src)
    local emp = Employees.RequirePermission(src, 'dispatch')
    MySQL.update.await('UPDATE st_employees SET dispatch_on_duty = 1, dispatch_shift_started_at = NOW() WHERE id = ?', { emp.id })
    Employees.RefreshLoginById(emp.id)
    Logs.Write(emp.id, 'dispatch_duty_started', ('%s hat den Dispositions-Dienst begonnen.'):format(emp.name))
    RPC.PushToPermission('dispatch', 'dispatch:dutyChanged', {})
    return { ok = true }
end

function Dispatch.EndDuty(src)
    local emp = Employees.RequirePermission(src, 'dispatch')
    MySQL.update.await('UPDATE st_employees SET dispatch_on_duty = 0, dispatch_shift_started_at = NULL WHERE id = ?', { emp.id })
    Employees.RefreshLoginById(emp.id)
    Logs.Write(emp.id, 'dispatch_duty_ended', ('%s hat den Dispositions-Dienst beendet.'):format(emp.name))
    RPC.PushToPermission('dispatch', 'dispatch:dutyChanged', {})
    return { ok = true }
end

--- Eigener Status für die Dienst-Toggle-Anzeige im Disponenten-Cockpit
--- (dispatch-board). Liest aus dem bereits geladenen Sitzungscache
--- (Employees.GetLoggedIn), kein zusätzlicher DB-Roundtrip nötig.
function Dispatch.OwnStatus(src)
    local emp = Employees.RequirePermission(src, 'dispatch')
    return { onDuty = Utils.ToBool(emp.dispatch_on_duty), shiftStartedAt = emp.dispatch_shift_started_at }
end

--- Räumt beim Verbindungsabbruch einen evtl. "hängengebliebenen"
--- Dienst-Status auf (server/sv_bootstrap.lua, playerDropped) - falls ein
--- Disponent crasht/disconnectet, ohne sich vorher regulär abzumelden,
--- bleibt dispatch_on_duty sonst dauerhaft auf 1 stehen.
function Dispatch.ForceEndDuty(employeeId)
    MySQL.update.await(
        'UPDATE st_employees SET dispatch_on_duty = 0, dispatch_shift_started_at = NULL WHERE id = ? AND dispatch_on_duty = 1',
        { employeeId }
    )
end

RPC.Register('dispatch:startDuty', function(src) return Dispatch.StartDuty(src) end)
RPC.Register('dispatch:endDuty', function(src) return Dispatch.EndDuty(src) end)
RPC.Register('dispatch:dutyStatus', function(src) return Dispatch.OwnStatus(src) end)
