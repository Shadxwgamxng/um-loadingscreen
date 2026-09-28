-- =========================================================
-- Client: Funk (bindet an pma-voice an)
--
-- Bewusst schlank gehalten - kein eigenes Ein-/Ausschalten, keine Anrufe
-- (das gab es hier früher schon einmal als "CB-Funk", lief aber unzuverlässig
-- und wurde komplett entfernt). Diese neue "Funk"-App im Tablet kann nur
-- EINS: zwischen den zehn Kanälen aus Config.Radio umschalten - dafür reicht
-- pma-voice's eigener Kanal-Export vollständig aus, ein Server-Umweg über
-- die normale RPC-Bridge (rpc()/call() in app.js) wäre hier nur unnötige
-- Latenz bei jedem Tastendruck, denn pma-voice validiert Kanäle ohnehin
-- schon selbst serverseitig. Sprechen (Push-to-Talk) läuft über pma-voice's
-- eigene Standardtaste, sobald ein Kanal aktiv ist - dafür baut dieses
-- Skript nichts Eigenes.
-- =========================================================

local channel = Config.Radio.defaultChannel

local function pmaVoiceReady()
    return GetResourceState('pma-voice') == 'started'
end

-- Verhindert, dass dieselbe Warnung bei jedem Kanalwechsel erneut auftaucht,
-- solange pma-voice nicht läuft - nur einmal, bis applyChannel() wieder
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

--- Überträgt den aktuell eingestellten Kanal an pma-voice. Wird beim
--- Ressourcenstart (Standardkanal) und bei jedem Kanalwechsel über die NUI
--- aufgerufen.
local function applyChannel()
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

--- Rein clientseitiger NUI-Callback (kein Server-RPC) - Kanalwahl kommt aus
--- der Funk-App (html/js/app.js, VIEWS['funk']).
RegisterNUICallback('radioSetChannel', function(data, cb)
    local ch = tonumber(data.channel)
    if ch then
        ch = math.max(Config.Radio.minChannel, math.min(Config.Radio.maxChannel, math.floor(ch)))
        channel = ch
        applyChannel()
    end
    cb({ ok = true, channel = channel })
end)

-- Direkt beim Ressourcenstart auf den Standardkanal einstellen, damit der
-- Funk auch dann schon aktiv ist, wenn das Tablet noch gar nicht geöffnet
-- wurde (z.B. während der Fahrt). Kurze Verzögerung, damit pma-voice beim
-- gemeinsamen Ressourcenstart Zeit hat, selbst hochzufahren.
CreateThread(function()
    Wait(2000)
    applyChannel()
end)
