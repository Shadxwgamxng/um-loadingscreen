-- =========================================================
-- Client: CB-Funk (bindet an pma-voice an)
--
-- Ein-/Ausschalten läuft ausschließlich über das Tablet. Danach bleibt das
-- Bedienfeld auch bei geschlossenem Tablet auf dem Bildschirm sichtbar.
-- Damit man es (ziehen, Kanal/Lautstärke/Stumm) auch bedienen kann, ohne
-- extra das ganze Tablet zu öffnen (z.B. während der Fahrt), gibt
-- Config.CbRadio.interactKey kurz den Mauszeiger dafür frei - ist das
-- Tablet ohnehin schon offen, ist das Funkgerät automatisch mitbedienbar.
-- =========================================================

local radioOn = false
local channel = Config.CbRadio.defaultChannel
local volume = Config.CbRadio.defaultVolume
local muted = false
local interacting = false

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

RegisterCommand('cbRadioToggle', function()
    if not radioOn then return end
    if exports['speditions-tablet']:IsTabletOpen() then return end -- Tablet hat ohnehin schon Fokus
    setInteracting(not interacting)
end, false)

RegisterKeyMapping('cbRadioToggle', 'CB-Funk bedienen (Fokus an/aus)', 'keyboard', Config.CbRadio.interactKey or 'F7')

-- ---------------------------------------------------------
-- NUI-Callbacks (rein clientseitig - pma-voice validiert Kanäle selbst
-- serverseitig, ein zusätzlicher RPC-Umweg für jeden Lautstärke-Tick wäre
-- nur unnötige Latenz)
-- ---------------------------------------------------------

RegisterNUICallback('radioPower', function(data, cb)
    radioOn = data.on and true or false
    if not radioOn and interacting then
        setInteracting(false)
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

-- Schaltet den Funk beim Ressourcen-/Verbindungsende sauber ab.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and radioOn and pmaVoiceReady() then
        exports['pma-voice']:setRadioChannel(0)
    end
end)
