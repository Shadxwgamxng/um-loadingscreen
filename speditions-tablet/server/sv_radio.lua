-- =========================================================
-- CB-Funk: Ein-/Ausschalten, Anrufe von der Disposition an Fahrer
--
-- Kanal/Lautstärke/Stumm passieren rein clientseitig über pma-voice (siehe
-- client/cl_radio.lua) - das validiert Funkkanäle bereits selbst
-- serverseitig. Hier wird nur verwaltet, WER gerade ein Funkgerät
-- eingeschaltet hat (nötig, um zu wissen, ob ein Anruf überhaupt ankommen
-- kann) und der Anruf-Lebenszyklus selbst: Anrufe laufen über einen von
-- pma-voice's normalen Funkkanälen komplett getrennten, privaten
-- Call-Kanal (exports.setCallChannel) - das normale Mithören auf dem
-- eingestellten Funkkanal wird durch einen Anruf nicht gestört.
-- =========================================================

local radioOnSrc = {} -- [src] = true, wer gerade das Funkgerät eingeschaltet hat
local calls = {}      -- [callId] = { callerSrc, targetSrc, channel, state = 'ringing'|'active' }
local srcToCall = {}  -- [src] = callId
local nextCallId = 1
local nextCallChannel = 90001 -- eigener Wertebereich, getrennt von den normalen Funkkanälen 1-9

local function endCall(callId, reason)
    local call = calls[callId]
    if not call then return end

    calls[callId] = nil
    srcToCall[call.callerSrc] = nil
    srcToCall[call.targetSrc] = nil

    -- Direkte Client-Events statt RPC.Push, damit das auch bei
    -- geschlossenem Tablet ankommt (siehe cl_radio.lua) - dort wird sowohl
    -- die pma-voice-Anbindung beendet als auch die NUI benachrichtigt.
    TriggerClientEvent('speditions-tablet:client:radioLeaveCall', call.callerSrc, reason)
    TriggerClientEvent('speditions-tablet:client:radioLeaveCall', call.targetSrc, reason)
end

RPC.Register('me:radio:powerOn', function(src)
    local emp = Employees.RequireRole(src)
    radioOnSrc[src] = true
    Logs.Write(emp.id, 'radio_on', ('%s hat den CB-Funk eingeschaltet.'):format(emp.name))
    return { ok = true }
end)

RPC.Register('me:radio:powerOff', function(src)
    local emp = Employees.RequireRole(src)
    radioOnSrc[src] = nil
    local callId = srcToCall[src]
    if callId then endCall(callId, 'radio_off') end
    Logs.Write(emp.id, 'radio_off', ('%s hat den CB-Funk ausgeschaltet.'):format(emp.name))
    return { ok = true }
end)

--- Disponent/GF ruft einen Fahrer über dessen CB-Funk an. Nur möglich,
--- wenn der Fahrer online, am Tablet erkannt UND sein Funkgerät
--- eingeschaltet ist.
RPC.Register('dispatch:callDriver', function(src, payload)
    local emp = Employees.RequireRole(src, { Config.Roles.DISPONENT, Config.Roles.GESCHAEFTSFUEHRUNG })

    local driverId = Utils.SanitizeNumber(payload.driverId, 1)
    if not driverId then error('invalid_payload') end

    local driver = Drivers.GetById(driverId)
    if not driver then error('driver_not_found') end

    local targetSrc = Utils.FindSrcByEmployeeId(driver.employee_id)
    if not targetSrc then error('driver_not_online') end
    if not radioOnSrc[targetSrc] then error('driver_radio_off') end
    if srcToCall[targetSrc] or srcToCall[src] then error('driver_busy') end

    local callId = nextCallId
    nextCallId = nextCallId + 1
    local callChannel = nextCallChannel
    nextCallChannel = nextCallChannel + 1

    calls[callId] = { callerSrc = src, targetSrc = targetSrc, channel = callChannel, state = 'ringing' }
    srcToCall[src] = callId
    srcToCall[targetSrc] = callId

    TriggerClientEvent('speditions-tablet:client:radioIncomingCall', targetSrc, emp.name, callChannel)
    Logs.Write(emp.id, 'radio_call_started', ('%s hat den Fahrer über CB-Funk angerufen.'):format(emp.name))

    CreateThread(function()
        Wait((Config.CbRadio.callRingSeconds or 20) * 1000)
        local call = calls[callId]
        if call and call.state == 'ringing' then
            endCall(callId, 'missed')
        end
    end)

    return { ok = true }
end)

--- Fahrer nimmt einen eingehenden Anruf am CB-Funk an. Gibt den privaten
--- Call-Kanal zurück, dem der Client (siehe cl_radio.lua) dann selbst
--- beitritt.
RPC.Register('radio:answerCall', function(src)
    local callId = srcToCall[src]
    local call = callId and calls[callId]
    if not call or call.targetSrc ~= src or call.state ~= 'ringing' then error('no_incoming_call') end

    call.state = 'active'
    -- Direktes Client-Event statt RPC.Push, damit das auch ankommt, wenn
    -- die anrufende Seite ihr Tablet inzwischen geschlossen hat.
    TriggerClientEvent('speditions-tablet:client:radioJoinCall', call.callerSrc, call.channel)

    return { ok = true, channel = call.channel }
end)

RPC.Register('radio:declineCall', function(src)
    local callId = srcToCall[src]
    local call = callId and calls[callId]
    if not call or call.targetSrc ~= src then error('no_incoming_call') end
    endCall(callId, 'declined')
    return { ok = true }
end)

--- Legt ein laufendes Gespräch auf - kann von beiden Seiten aufgerufen werden.
RPC.Register('radio:hangup', function(src)
    local callId = srcToCall[src]
    if not callId then error('no_active_call') end
    endCall(callId, 'hangup')
    return { ok = true }
end)

AddEventHandler('playerDropped', function()
    local src = source
    radioOnSrc[src] = nil
    local callId = srcToCall[src]
    if callId then endCall(callId, 'disconnected') end
end)
