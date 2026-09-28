-- =========================================================
-- Server: Funk - Präsenz (wer ist auf welchem Kanal), Teilnehmerliste,
-- Anrufe zwischen zwei Funk-Teilnehmern.
--
-- Rein transient im Arbeitsspeicher (wie server/sv_tracking.lua) - keine
-- Datenbank-Tabelle, keine Historie. Kanal-/Lautstärkewechsel selbst laufen
-- weiterhin primär clientseitig gegen pma-voice (client/cl_radio.lua);
-- hier wird nur mitgeführt, WER gerade auf WELCHEM Kanal ist (für die
-- Teilnehmerliste) und der Anruf-Lebenszyklus - Anrufe laufen über einen
-- von pma-voice's normalen Funkkanälen komplett getrennten, privaten
-- Call-Kanal (exports.setCallChannel), das normale Mithören auf dem
-- eingestellten Kanal wird durch einen Anruf nicht gestört.
-- =========================================================

-- Absicherung gegen eine ältere/unvollständige config.lua (config.lua ist
-- die einzige Datei, die bei einem Update bewusst NICHT überschrieben wird,
-- s. escrow_ignore_files in fxmanifest.lua) - fehlt Config.Radio komplett,
-- würde z.B. radio:join sonst bei jedem Beitreten-Versuch mit einem
-- Lua-Laufzeitfehler abbrechen (RPC-Antwort {ok=false, error=<Lua-Fehler>}),
-- was sich als "Beitreten-Button springt sofort wieder zurück" zeigt, ohne
-- dass der eigentliche Grund (fehlende Config.Radio) irgendwo sichtbar wäre
-- außer als serverseitige RPC-Fehlermeldung in der Konsole.
local RadioConfig = Config.Radio
if not RadioConfig then
    RadioConfig = { minChannel = 1000, maxChannel = 1009, defaultChannel = 1000, defaultVolume = 100, callRingSeconds = 20 }
    print('^1[speditions-tablet]^7 Funk: Config.Radio fehlt in config.lua (alte/unvollständige Datei?) - Funk läuft vorerst mit Standardwerten (Kanäle 1000-1009). Bitte config.lua aus dem aktuellen Ressourcen-Paket übernehmen, um Config.Radio zu ergänzen.')
end

local presence = {} -- [src] = { channel = number, displayName = string }
local calls = {}      -- [callId] = { callerSrc, targetSrc, channel, state = 'ringing'|'active' }
local srcToCall = {}  -- [src] = callId
local nextCallId = 1
local nextCallChannel = 90001 -- eigener Wertebereich, getrennt von den normalen Funkkanälen 1000-1009

local function endCall(callId, reason)
    local call = calls[callId]
    if not call then return end

    calls[callId] = nil
    srcToCall[call.callerSrc] = nil
    srcToCall[call.targetSrc] = nil

    -- Direkte Client-Events statt RPC.Push, damit das auch ankommt, wenn
    -- die NUI gerade nicht auf eine Antwort wartet.
    TriggerClientEvent('speditions-tablet:client:radioLeaveCall', call.callerSrc, reason)
    TriggerClientEvent('speditions-tablet:client:radioLeaveCall', call.targetSrc, reason)
end

-- TEMPORÄRE DIAGNOSE-AUSGABEN (radio:join) - bewusst auffällig mit
-- [FUNK-DEBUG]-Präfix, damit sich der genaue Punkt, an dem "Funk
-- beitreten" hängen bleibt, live in der Server-Konsole nachvollziehen
-- lässt. Nach erfolgreicher Diagnose wieder entfernen.
RPC.Register('radio:join', function(src)
    print(('[FUNK-DEBUG] radio:join gestartet (source %s)'):format(src))
    local emp = Employees.RequireRole(src)
    print(('[FUNK-DEBUG] radio:join: RequireRole ok, emp.id=%s emp.name=%s'):format(tostring(emp.id), tostring(emp.name)))
    presence[src] = presence[src] or {}
    presence[src].channel = RadioConfig.defaultChannel
    presence[src].displayName = presence[src].displayName or emp.name
    print('[FUNK-DEBUG] radio:join: presence gesetzt, rufe Logs.Write auf')
    Logs.Write(emp.id, 'radio_join', ('%s hat den Funk betreten.'):format(emp.name))
    print('[FUNK-DEBUG] radio:join: Logs.Write aufgerufen (non-blocking), gebe Ergebnis zurück')
    return { ok = true, displayName = presence[src].displayName }
end)

RPC.Register('radio:leave', function(src)
    local emp = Employees.RequireRole(src)
    presence[src] = nil
    local callId = srcToCall[src]
    if callId then endCall(callId, 'radio_off') end
    Logs.Write(emp.id, 'radio_leave', ('%s hat den Funk verlassen.'):format(emp.name))
    return { ok = true }
end)

--- Rein für die Teilnehmerliste - der eigentliche Kanalwechsel bei
--- pma-voice passiert unabhängig davon direkt im Client (cl_radio.lua).
RPC.Register('radio:setChannel', function(src, payload)
    Employees.RequireRole(src)
    local ch = Utils.SanitizeNumber(payload.channel, RadioConfig.minChannel, RadioConfig.maxChannel)
    if not ch then error('invalid_payload') end
    if not presence[src] then error('radio_not_joined') end
    presence[src].channel = math.floor(ch)
    return { ok = true }
end)

RPC.Register('radio:setDisplayName', function(src, payload)
    Employees.RequireRole(src)
    local name = Utils.SanitizeString(payload.name, 24)
    if not name then error('missing_fields') end
    presence[src] = presence[src] or {}
    presence[src].displayName = name
    return { ok = true, displayName = name }
end)

--- Alle Mitarbeiter, die aktuell auf demselben Kanal wie `src` sind
--- (inkl. `src` selbst, markiert über `isSelf`) - Grundlage für die
--- Teilnehmerliste und die Anrufauswahl in der NUI.
RPC.Register('radio:channelMembers', function(src)
    Employees.RequireRole(src)
    local me = presence[src]
    if not me then return { ok = true, joined = false, members = {} } end

    local members = {}
    for s, p in pairs(presence) do
        if p.channel == me.channel then
            members[#members + 1] = { src = s, name = p.displayName, isSelf = (s == src), inCall = srcToCall[s] ~= nil }
        end
    end
    table.sort(members, function(a, b) return a.name < b.name end)

    return { ok = true, joined = true, channel = me.channel, members = members }
end)

--- Ruft einen anderen, gerade im Funk befindlichen Mitarbeiter an - egal ob
--- Disponent->Fahrer oder Fahrer->Disponent, jeder Funk-Teilnehmer kann
--- jeden anderen anrufen (kein eigener Rollen-Check nötig, Config.Radio
--- selbst ist bereits für jeden angemeldeten Mitarbeiter zugänglich).
RPC.Register('radio:callUser', function(src, payload)
    local emp = Employees.RequireRole(src)

    local targetSrc = Utils.SanitizeNumber(payload.targetSrc, 1)
    if not targetSrc then error('invalid_payload') end
    if targetSrc == src then error('invalid_payload') end
    if not presence[src] then error('radio_not_joined') end
    if not presence[targetSrc] then error('radio_target_not_joined') end
    if srcToCall[targetSrc] or srcToCall[src] then error('radio_busy') end

    local targetEmp = Employees.GetLoggedIn(targetSrc)
    if not targetEmp then error('radio_target_not_joined') end

    local callId = nextCallId
    nextCallId = nextCallId + 1
    local callChannel = nextCallChannel
    nextCallChannel = nextCallChannel + 1

    calls[callId] = { callerSrc = src, targetSrc = targetSrc, channel = callChannel, state = 'ringing' }
    srcToCall[src] = callId
    srcToCall[targetSrc] = callId

    TriggerClientEvent('speditions-tablet:client:radioIncomingCall', targetSrc, presence[src].displayName or emp.name, callChannel)

    CreateThread(function()
        Wait((RadioConfig.callRingSeconds or 20) * 1000)
        local call = calls[callId]
        if call and call.state == 'ringing' then
            endCall(callId, 'missed')
        end
    end)

    return { ok = true }
end)

RPC.Register('radio:answerCall', function(src)
    local callId = srcToCall[src]
    local call = callId and calls[callId]
    if not call or call.targetSrc ~= src or call.state ~= 'ringing' then error('radio_no_incoming_call') end

    call.state = 'active'
    -- Direktes Client-Event statt RPC.Push, damit das auch ankommt, wenn
    -- die anrufende Seite die Funk-App inzwischen verlassen hat.
    TriggerClientEvent('speditions-tablet:client:radioJoinCall', call.callerSrc, call.channel)

    return { ok = true, channel = call.channel }
end)

RPC.Register('radio:declineCall', function(src)
    local callId = srcToCall[src]
    local call = callId and calls[callId]
    if not call or call.targetSrc ~= src then error('radio_no_incoming_call') end
    endCall(callId, 'declined')
    return { ok = true }
end)

--- Legt ein laufendes Gespräch auf - kann von beiden Seiten aufgerufen werden.
RPC.Register('radio:hangup', function(src)
    local callId = srcToCall[src]
    if not callId then error('radio_no_active_call') end
    endCall(callId, 'hangup')
    return { ok = true }
end)

--- Hält ein laufendes Gespräch - beide Seiten trennen währenddessen ihre
--- pma-voice-Verbindung zum privaten Call-Kanal (s. cl_radio.lua), damit
--- niemand ins Leere spricht/hört. Kann von beiden Seiten ausgelöst und
--- von beiden Seiten wieder fortgesetzt werden.
RPC.Register('radio:holdCall', function(src)
    local callId = srcToCall[src]
    local call = callId and calls[callId]
    if not call or call.state ~= 'active' then error('radio_no_active_call') end
    call.state = 'hold'
    local otherSrc = call.callerSrc == src and call.targetSrc or call.callerSrc
    TriggerClientEvent('speditions-tablet:client:radioCallHold', otherSrc)
    return { ok = true }
end)

RPC.Register('radio:resumeCall', function(src)
    local callId = srcToCall[src]
    local call = callId and calls[callId]
    if not call or call.state ~= 'hold' then error('radio_call_not_on_hold') end
    call.state = 'active'
    local otherSrc = call.callerSrc == src and call.targetSrc or call.callerSrc
    TriggerClientEvent('speditions-tablet:client:radioCallResumed', otherSrc)
    return { ok = true }
end)

AddEventHandler('playerDropped', function()
    local src = source
    presence[src] = nil
    local callId = srcToCall[src]
    if callId then endCall(callId, 'disconnected') end
end)
