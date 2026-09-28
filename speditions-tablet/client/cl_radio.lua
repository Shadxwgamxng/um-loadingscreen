-- =========================================================
-- Client: Funk (bindet an pma-voice an, s. server/sv_radio.lua für
-- Präsenz/Teilnehmerliste/Anrufe)
--
-- Kanal/Lautstärke laufen weiterhin primär gegen pma-voice direkt (das
-- validiert Kanäle ohnehin selbst serverseitig) - nur Beitreten/Verlassen,
-- der Kanalabgleich für die Teilnehmerliste und Anrufe gehen über
-- ServerCall zum Server. Sprechen (Push-to-Talk) läuft über pma-voice's
-- eigene Standardtaste, sobald ein Kanal aktiv ist - dafür baut dieses
-- Skript nichts Eigenes.
-- =========================================================

local channel = Config.Radio.defaultChannel
local volume = Config.Radio.defaultVolume
local joined = false
local rxTalkers = {} -- ['local'] oder [serverId] = true, wer gerade auf dem Kanal spricht (nur für die Empfangsanzeige, keine Namen nötig)
local activeCallChannel = nil -- privater pma-voice-Kanal des laufenden Gesprächs, s. radioJoinCall/radioAnswerCall - wird für Halten/Fortsetzen gebraucht

local function pmaVoiceReady()
    return GetResourceState('pma-voice') == 'started'
end

-- Verhindert, dass dieselbe Warnung bei jeder Aktion erneut auftaucht,
-- solange pma-voice nicht läuft - nur einmal, bis applyState() wieder
-- erfolgreich durchläuft.
local warnedPmaVoiceMissing = false

--- Ruft einen pma-voice-Export geschützt auf und loggt einen etwaigen Fehler
--- MIT unserem eigenen Präfix (statt eines generischen "SCRIPT ERROR" ohne
--- erkennbaren Bezug zu dieser Ressource) - macht sonst stillschweigend
--- fehlschlagende Exports (z.B. weil ein pma-voice-Fork eine Funktion anders
--- benannt hat) erstmals sichtbar.
local function safePmaVoiceCall(exportName, ...)
    local ok, err = pcall(function(...) exports['pma-voice'][exportName](exports['pma-voice'], ...) end, ...)
    if not ok then
        print(('^1[speditions-tablet]^7 Funk: pma-voice-Export "%s" ist fehlgeschlagen: %s'):format(exportName, tostring(err)))
    end
    return ok
end

--- Überträgt Kanal + Lautstärke + Ein/Aus-Zustand an pma-voice. Wird bei
--- jeder Änderung über die NUI aufgerufen.
local function applyState()
    if not pmaVoiceReady() then
        if not warnedPmaVoiceMissing then
            warnedPmaVoiceMissing = true
            print(('^1[speditions-tablet]^7 Funk: Ressource "pma-voice" ist nicht gestartet (GetResourceState = "%s") - keine Audioverbindung moeglich. Pruefe server.cfg (ensure pma-voice, Startreihenfolge) bzw. ob pma-voice unter einem anderen Namen laeuft.'):format(GetResourceState('pma-voice')))
        end
        return
    end
    warnedPmaVoiceMissing = false

    -- WICHTIG: pma-voice erfordert zusätzlich zum Kanal, dass "radioEnabled"
    -- per setVoiceProperty gesetzt ist, bevor es einen Sendeversuch
    -- (Push-to-Talk) überhaupt als Funkverkehr erkennt (isRadioEnabled() in
    -- pma-voice selbst) - auf vielen Servern normalerweise an ein
    -- Funkgerät-Item in einem Inventarsystem gekoppelt. Da dieses Tablet
    -- absichtlich ohne Framework/Inventar auskommt, übernimmt "beigetreten"
    -- (joined) diese Rolle.
    safePmaVoiceCall('setVoiceProperty', 'radioEnabled', joined)
    if joined then
        safePmaVoiceCall('setRadioChannel', channel)
        safePmaVoiceCall('setRadioVolume', volume)
    else
        safePmaVoiceCall('setRadioChannel', 0)
    end
end

--- Meldet sich der Server über pma-voice ab, hat der zuletzt gewählte Kanal
--- NICHT gegriffen (z.B. weil voice_enableRadios=0 gesetzt ist oder ein
--- anderes, hier installiertes Skript den Kanalwechsel blockiert) - ohne
--- diesen Listener würde man das nie erfahren, die Kanalwahl wirkt dann
--- einfach nur wirkungslos.
RegisterNetEvent('pma-voice:radioChangeRejected', function()
    print('^1[speditions-tablet]^7 Funk: pma-voice hat die Kanalwahl ABGELEHNT (Event pma-voice:radioChangeRejected) - moegliche Ursachen: Convar voice_enableRadios steht auf 0, oder ein weiteres, hier installiertes Skript blockiert den Kanalwechsel.')
    TriggerEvent('speditions-tablet:client:notify', 'Funk: pma-voice hat die Kanalwahl abgelehnt - siehe Serverkonsole.', 'error')
end)

-- ---------------------------------------------------------
-- Sende-/Empfangsanzeige: pma-voice meldet lokal, wenn der Spieler selbst
-- auf dem Funkkanal zu sprechen beginnt/aufhört (Push-to-Talk). Für ANDERE
-- Spieler auf dem Kanal bietet pma-voice kein eigenes Export/Event an - wir
-- hören daher zusätzlich das intern von pma-voice gefeuerte Event
-- 'pma-voice:setTalkingOnRadio' mit. Bewusst OHNE Namensauflösung hier -
-- die Teilnehmerliste selbst kommt über radio:channelMembers vom Server.
-- ---------------------------------------------------------

RegisterNetEvent('pma-voice:radioActive', function(radioTalking)
    SendNUIMessage({ type = 'radioTx', talking = radioTalking and true or false })
end)

RegisterNetEvent('pma-voice:setTalkingOnRadio', function(src, enabled)
    if enabled then
        rxTalkers[src] = true
    else
        rxTalkers[src] = nil
    end
    local anyoneTalking = next(rxTalkers) ~= nil
    SendNUIMessage({ type = 'radioRx', talking = anyoneTalking })
end)

-- ---------------------------------------------------------
-- NUI-Callbacks: Beitreten/Verlassen/Kanal/Lautstärke laufen komplett
-- clientseitig gegen pma-voice, melden den Kanal aber zusätzlich (best
-- effort, per ServerCall) an den Server, damit die Teilnehmerliste stimmt.
-- ---------------------------------------------------------

RegisterNUICallback('radioJoin', function(_, cb)
    ServerCall('radio:join', {}, function(res)
        if res and res.ok then
            joined = true
            applyState()
        end
        cb(res or { ok = false })
    end)
end)

RegisterNUICallback('radioLeave', function(_, cb)
    ServerCall('radio:leave', {}, function(res)
        joined = false
        applyState()
        cb(res or { ok = false })
    end)
end)

RegisterNUICallback('radioSetChannel', function(data, cb)
    local ch = tonumber(data.channel)
    if ch then
        ch = math.max(Config.Radio.minChannel, math.min(Config.Radio.maxChannel, math.floor(ch)))
        channel = ch
        applyState()
        if joined then ServerCall('radio:setChannel', { channel = ch }, function() end) end
    end
    cb({ ok = true, channel = channel })
end)

RegisterNUICallback('radioSetVolume', function(data, cb)
    local vol = tonumber(data.volume)
    if vol then
        volume = math.max(0, math.min(100, math.floor(vol)))
        applyState()
    end
    cb({ ok = true, volume = volume })
end)

RegisterNUICallback('radioSetDisplayName', function(data, cb)
    ServerCall('radio:setDisplayName', { name = data.name }, function(res) cb(res or { ok = false }) end)
end)

RegisterNUICallback('radioGetChannelMembers', function(_, cb)
    ServerCall('radio:channelMembers', {}, function(res) cb(res or { ok = false }) end)
end)

RegisterNUICallback('radioCallUser', function(data, cb)
    ServerCall('radio:callUser', { targetSrc = data.targetSrc }, function(res) cb(res or { ok = false }) end)
end)

RegisterNUICallback('radioAnswerCall', function(_, cb)
    ServerCall('radio:answerCall', {}, function(res)
        if res and res.ok then
            activeCallChannel = res.channel
            if pmaVoiceReady() then exports['pma-voice']:setCallChannel(res.channel) end
        end
        cb(res or { ok = false })
    end)
end)

RegisterNUICallback('radioDeclineCall', function(_, cb)
    ServerCall('radio:declineCall', {}, function(res) cb(res or { ok = false }) end)
end)

RegisterNUICallback('radioHangup', function(_, cb)
    activeCallChannel = nil
    if pmaVoiceReady() then exports['pma-voice']:setCallChannel(0) end
    ServerCall('radio:hangup', {}, function(res) cb(res or { ok = false }) end)
end)

--- Hält das laufende Gespräch - trennt die eigene pma-voice-Verbindung zum
--- privaten Call-Kanal (der Server benachrichtigt die Gegenseite, die das
--- bei sich ebenso tut, s. radioCallHold-Netevent unten), OHNE den Kanal
--- selbst zu vergessen (activeCallChannel bleibt gesetzt, für radioResumeCall).
RegisterNUICallback('radioHoldCall', function(_, cb)
    ServerCall('radio:holdCall', {}, function(res)
        if res and res.ok and pmaVoiceReady() then
            exports['pma-voice']:setCallChannel(0)
        end
        cb(res or { ok = false })
    end)
end)

RegisterNUICallback('radioResumeCall', function(_, cb)
    ServerCall('radio:resumeCall', {}, function(res)
        if res and res.ok and pmaVoiceReady() and activeCallChannel then
            exports['pma-voice']:setCallChannel(activeCallChannel)
        end
        cb(res or { ok = false })
    end)
end)

RegisterNUICallback('radioGetStatus', function(_, cb)
    cb({ ok = true, connected = pmaVoiceReady(), joined = joined, channel = channel, volume = volume })
end)

-- ---------------------------------------------------------
-- Anruf-Netevents (unabhängig vom NUI-Fokus, aber nur sichtbar, solange
-- die Funk-App tatsächlich offen ist - ohne offene Funk-App verpufft ein
-- eingehender Anruf momentan wirkungslos, s. README).
-- ---------------------------------------------------------

RegisterNetEvent('speditions-tablet:client:radioIncomingCall', function(callerName)
    SendNUIMessage({ type = 'radioIncomingCall', callerName = callerName })
end)

--- Wird an BEIDE Gesprächsseiten geschickt, sobald der Anruf angenommen
--- wurde - die anrufende Seite tritt dem privaten Call-Kanal erst jetzt bei.
RegisterNetEvent('speditions-tablet:client:radioJoinCall', function(callChannel)
    activeCallChannel = callChannel
    if pmaVoiceReady() then exports['pma-voice']:setCallChannel(callChannel) end
    SendNUIMessage({ type = 'radioCallAnswered' })
end)

RegisterNetEvent('speditions-tablet:client:radioLeaveCall', function(reason)
    activeCallChannel = nil
    if pmaVoiceReady() then exports['pma-voice']:setCallChannel(0) end
    SendNUIMessage({ type = 'radioCallEnded', reason = reason })
end)

--- Push-Events der Gegenseite, wenn DORT Halten/Fortsetzen gedrückt wurde -
--- die eigene pma-voice-Verbindung zum Call-Kanal wird spiegelbildlich
--- getrennt/wiederhergestellt, damit während des Haltens niemand ins Leere
--- spricht.
RegisterNetEvent('speditions-tablet:client:radioCallHold', function()
    if pmaVoiceReady() then exports['pma-voice']:setCallChannel(0) end
    SendNUIMessage({ type = 'radioCallHold' })
end)

RegisterNetEvent('speditions-tablet:client:radioCallResumed', function()
    if pmaVoiceReady() and activeCallChannel then exports['pma-voice']:setCallChannel(activeCallChannel) end
    SendNUIMessage({ type = 'radioCallResumed' })
end)

-- Ressource endet -> pma-voice sauber zurücksetzen, unabhängig vom
-- zuletzt bekannten joined-Zustand.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and pmaVoiceReady() then
        exports['pma-voice']:setRadioChannel(0)
        exports['pma-voice']:setCallChannel(0)
    end
end)
