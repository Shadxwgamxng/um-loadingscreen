-- =========================================================
-- Client: Funk (bindet an pma-voice an)
--
-- Bewusst schlank gehalten - kein eigenes Ein-/Ausschalten, keine Anrufe
-- (das gab es hier früher schon einmal als "CB-Funk", lief aber unzuverlässig
-- und wurde komplett entfernt). Diese "Funk"-App im Tablet kann: zwischen
-- den zehn Kanälen aus Config.Radio umschalten, die Funklautstärke regeln,
-- und zeigt den echten pma-voice-Verbindungsstatus sowie ein Sende-/
-- Empfangsfeedback an - dafür reichen pma-voice's eigene Exports/Events
-- vollständig aus, ein Server-Umweg über die normale RPC-Bridge
-- (rpc()/call() in app.js) wäre hier nur unnötige Latenz bei jedem
-- Tastendruck, denn pma-voice validiert Kanäle ohnehin schon selbst
-- serverseitig. Sprechen (Push-to-Talk) läuft über pma-voice's eigene
-- Standardtaste, sobald ein Kanal aktiv ist - dafür baut dieses Skript
-- nichts Eigenes.
-- =========================================================

local channel = Config.Radio.defaultChannel
local volume = Config.Radio.defaultVolume
local rxTalkers = {} -- ['local'] oder [serverId] = true, wer gerade auf dem Kanal spricht (nur für die Empfangsanzeige, keine Namen nötig)

local function pmaVoiceReady()
    return GetResourceState('pma-voice') == 'started'
end

-- Verhindert, dass dieselbe Warnung bei jedem Kanalwechsel erneut auftaucht,
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

--- Überträgt Kanal + Lautstärke an pma-voice. Wird beim Ressourcenstart
--- (Standardwerte) und bei jeder Änderung über die NUI aufgerufen.
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
    -- absichtlich ohne Framework/Inventar auskommt, ist der Funk hier immer
    -- aktiv, sobald ein Kanal eingestellt ist - ohne das würde pma-voice
    -- jeden Sendeversuch stillschweigend ignorieren, obwohl der Kanal
    -- korrekt gesetzt ist.
    safePmaVoiceCall('setVoiceProperty', 'radioEnabled', true)
    safePmaVoiceCall('setRadioChannel', channel)
    safePmaVoiceCall('setRadioVolume', volume)
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
-- 'pma-voice:setTalkingOnRadio' mit (FiveM-Events sind nicht
-- ressourcen-exklusiv, mehrere Ressourcen können denselben Eventnamen
-- unabhängig voneinander abonnieren). Bewusst OHNE Namensauflösung -
-- reine Sende-/Empfangsanzeige reicht für den Funk-Bildschirm, ein Server-
-- RPC pro Sprecher wäre hier unnötiger Aufwand.
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
-- NUI-Callbacks (rein clientseitig, kein Server-RPC)
-- ---------------------------------------------------------

RegisterNUICallback('radioSetChannel', function(data, cb)
    local ch = tonumber(data.channel)
    if ch then
        ch = math.max(Config.Radio.minChannel, math.min(Config.Radio.maxChannel, math.floor(ch)))
        channel = ch
        applyState()
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

--- Liefert den aktuellen Zustand auf Anfrage der NUI (z.B. beim Öffnen der
--- Funk-App oder alle paar Sekunden, solange sie offen ist) - vor allem für
--- "connected", das sich zur Laufzeit ändern kann (pma-voice startet/stoppt
--- neu), während Kanal/Lautstärke von der NUI ohnehin schon optimistisch
--- mitgeführt werden.
RegisterNUICallback('radioGetStatus', function(_, cb)
    cb({ ok = true, connected = pmaVoiceReady(), channel = channel, volume = volume })
end)

-- Direkt beim Ressourcenstart auf die Standardwerte einstellen, damit der
-- Funk auch dann schon aktiv ist, wenn das Tablet noch gar nicht geöffnet
-- wurde (z.B. während der Fahrt). Kurze Verzögerung, damit pma-voice beim
-- gemeinsamen Ressourcenstart Zeit hat, selbst hochzufahren.
CreateThread(function()
    Wait(2000)
    applyState()
end)
