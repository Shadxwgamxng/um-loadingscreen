-- =========================================================
-- Client: CB-Funk (bindet an pma-voice an)
--
-- Ein-/Ausschalten läuft ausschließlich über das Tablet. Danach bleibt das
-- Bedienfeld auch bei geschlossenem Tablet auf dem Bildschirm sichtbar.
-- Damit man es (ziehen, Größe ändern, Kanal/Lautstärke/Stumm) auch bedienen
-- kann, ohne extra das ganze Tablet zu öffnen (z.B. während der Fahrt),
-- schaltet Config.CbRadio.interactKey den Mauszeiger dafür EIN/AUS (Toggle -
-- kein Gedrückthalten, damit man nie "hängen" bleiben kann). Zusätzlich
-- gibt Escape den Mauszeiger IMMER wieder frei, als garantierter Notausstieg.
-- Bei einem eingehenden Anruf der Disposition wird der Mauszeiger automatisch
-- kurz freigegeben (wie bei einem klingelnden Telefon) und direkt nach der
-- Reaktion (Annehmen/Ablehnen) wieder freigegeben, falls er nur dafür an war.
-- =========================================================

local radioOn = false
local channel = Config.CbRadio.defaultChannel
local volume = Config.CbRadio.defaultVolume
local muted = false
local interacting = false
local interactingForCall = false -- true, wenn der Fokus nur wegen eines Anrufs automatisch aktiviert wurde
local pendingCallChannel = nil
local talkers = {} -- ['local'] oder [serverId] = Anzeigename, wer gerade auf dem Kanal spricht

local function pmaVoiceReady()
    return GetResourceState('pma-voice') == 'started'
end

--- Überträgt den aktuellen Zustand an pma-voice. Wird bei jeder Änderung
--- (an/aus, Kanal, Lautstärke, Stumm) neu aufgerufen.
local function applyVoiceState()
    if not pmaVoiceReady() then return end

    if radioOn then
        exports['pma-voice']:setRadioChannel(channel)
        exports['pma-voice']:setRadioVolume(muted and 0 or volume)
    else
        exports['pma-voice']:setRadioChannel(0)
    end
end

local function setInteracting(on)
    interacting = on
    SetNuiFocus(on, on)
    SendNUIMessage({ type = 'radioInteract', on = on })
end

--- Gibt den Mauszeiger wieder frei, falls er nur automatisch wegen eines
--- Anrufs aktiviert wurde (nicht, wenn der Spieler ihn selbst per Taste an
--- hatte, oder wenn das Tablet ohnehin offen ist).
local function releaseCallFocusIfNeeded()
    if interactingForCall and interacting and not exports['speditions-tablet']:IsTabletOpen() then
        setInteracting(false)
    end
    interactingForCall = false
end

-- ---------------------------------------------------------
-- Mauszeiger-Toggle für das Funkgerät
-- ---------------------------------------------------------

RegisterCommand('cbRadioToggle', function()
    if not radioOn then return end
    if exports['speditions-tablet']:IsTabletOpen() then return end -- Tablet hat ohnehin schon Fokus
    interactingForCall = false
    setInteracting(not interacting)
end, false)

RegisterKeyMapping('cbRadioToggle', 'CB-Funk bedienen (an/aus)', 'keyboard', Config.CbRadio.interactKey or 'F7')

-- ---------------------------------------------------------
-- NUI-Callbacks (rein clientseitig - pma-voice validiert Kanäle selbst
-- serverseitig, ein zusätzlicher RPC-Umweg für jeden Lautstärke-Tick wäre
-- nur unnötige Latenz)
-- ---------------------------------------------------------

--- Baut aus der talkers-Tabelle die Namensliste und schickt sie ans LCD.
local function sendTalkersUpdate()
    local names = {}
    for _, name in pairs(talkers) do
        names[#names + 1] = name
    end
    SendNUIMessage({ type = 'radioTalkers', names = names })
end

RegisterNUICallback('radioPower', function(data, cb)
    radioOn = data.on and true or false
    if not radioOn then
        talkers = {}
        sendTalkersUpdate()
        if interacting then
            interactingForCall = false
            setInteracting(false)
        end
    end
    applyVoiceState()
    cb('ok')
end)

RegisterNUICallback('radioSetChannel', function(data, cb)
    local ch = tonumber(data.channel)
    if ch then
        ch = math.max(Config.CbRadio.minChannel, math.min(Config.CbRadio.maxChannel, math.floor(ch)))
        channel = ch
        applyVoiceState()
    end
    cb('ok')
end)

RegisterNUICallback('radioSetVolume', function(data, cb)
    local vol = tonumber(data.volume)
    if vol then
        volume = math.max(0, math.min(100, math.floor(vol)))
        applyVoiceState()
    end
    cb('ok')
end)

RegisterNUICallback('radioToggleMute', function(_, cb)
    muted = not muted
    applyVoiceState()
    cb('ok')
end)

RegisterNUICallback('radioAnswerCall', function(_, cb)
    local channelToJoin = pendingCallChannel
    pendingCallChannel = nil
    releaseCallFocusIfNeeded()
    if channelToJoin then
        ServerCall('radio:answerCall', {}, function(res)
            if res and res.ok and pmaVoiceReady() then
                exports['pma-voice']:setCallChannel(channelToJoin)
            end
        end)
    end
    cb('ok')
end)

RegisterNUICallback('radioDeclineCall', function(_, cb)
    pendingCallChannel = nil
    releaseCallFocusIfNeeded()
    ServerCall('radio:declineCall', {}, function() end)
    cb('ok')
end)

RegisterNUICallback('radioHangup', function(_, cb)
    ServerCall('radio:hangup', {}, function() end)
    cb('ok')
end)

--- Notausstieg: wird von der NUI bei Escape aufgerufen (siehe app.js) -
--- gibt den Mauszeiger frei, falls er gerade nur wegen des Funkgeräts aktiv
--- ist. Kann nur überhaupt ankommen, wenn die NUI ohnehin schon Fokus hat,
--- also genau dann, wenn es etwas freizugeben gibt.
RegisterNUICallback('radioForceRelease', function(_, cb)
    if interacting and not exports['speditions-tablet']:IsTabletOpen() then
        interactingForCall = false
        setInteracting(false)
    end
    cb('ok')
end)

-- ---------------------------------------------------------
-- Anruf-Netevents (unabhängig vom Tablet/NUI-Fokus, damit ein Anruf auch
-- bei geschlossenem Tablet ankommt und die pma-voice-Anbindung IMMER
-- korrekt läuft, unabhängig davon, ob die NUI gerade zuschaut)
-- ---------------------------------------------------------

RegisterNetEvent('speditions-tablet:client:radioIncomingCall', function(callerName, callChannel)
    if not radioOn then return end
    pendingCallChannel = callChannel
    if not interacting then
        interactingForCall = true
        setInteracting(true)
    end
    SendNUIMessage({ type = 'radioIncomingCall', callerName = callerName })
end)

--- Wird an BEIDE Gesprächsseiten geschickt, sobald der Anruf angenommen
--- wurde - die anrufende Seite tritt dem privaten Call-Kanal erst jetzt bei.
RegisterNetEvent('speditions-tablet:client:radioJoinCall', function(callChannel)
    if pmaVoiceReady() then exports['pma-voice']:setCallChannel(callChannel) end
    SendNUIMessage({ type = 'radioCallAnswered' })
end)

RegisterNetEvent('speditions-tablet:client:radioLeaveCall', function(reason)
    if pmaVoiceReady() then exports['pma-voice']:setCallChannel(0) end
    pendingCallChannel = nil
    releaseCallFocusIfNeeded()
    SendNUIMessage({ type = 'radioCallEnded', reason = reason })
end)

-- ---------------------------------------------------------
-- Sprech-Sound + "wer spricht"-Anzeige: pma-voice meldet lokal, wenn der
-- Spieler selbst auf dem Funkkanal zu sprechen beginnt/aufhört
-- (Push-to-Talk). Für ANDERE Spieler auf dem Kanal bietet pma-voice selbst
-- kein eigenes Export/Event an - wir hören daher zusätzlich das intern von
-- pma-voice gefeuerte Event 'pma-voice:setTalkingOnRadio' mit (verifiziert
-- gegen den pma-voice-Quellcode, client/module/radio.lua: wird dort per
-- RegisterNetEvent('pma-voice:setTalkingOnRadio', setTalkingOnRadio)
-- registriert - FiveM-Events sind nicht ressourcen-exklusiv, mehrere
-- Ressourcen können denselben Eventnamen unabhängig voneinander abonnieren).
-- ---------------------------------------------------------

RegisterNetEvent('pma-voice:radioActive', function(radioTalking)
    if not radioOn then return end
    SendNUIMessage({ type = 'radioPtt', talking = radioTalking })
    talkers['local'] = radioTalking and 'Du' or nil
    sendTalkersUpdate()
end)

RegisterNetEvent('pma-voice:setTalkingOnRadio', function(plySource, enabled)
    if not radioOn then return end
    if type(plySource) ~= 'number' then return end

    if enabled then
        local playerIndex = GetPlayerFromServerId(plySource)
        talkers[plySource] = (playerIndex ~= -1 and GetPlayerName(playerIndex)) or ('Spieler #' .. plySource)
    else
        talkers[plySource] = nil
    end
    sendTalkersUpdate()
end)

-- Schaltet den Funk beim Ressourcen-/Verbindungsende sauber ab.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and pmaVoiceReady() then
        if radioOn then exports['pma-voice']:setRadioChannel(0) end
        exports['pma-voice']:setCallChannel(0)
    end
end)
