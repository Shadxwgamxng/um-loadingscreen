-- =========================================================
-- Warnmeldungen: Annäherungswarnung + lokaler Cache
--
-- Läuft komplett unabhängig davon, ob das Tablet gerade geöffnet ist -
-- die Ansage muss während der Fahrt funktionieren, auch bei
-- geschlossenem Tablet (NUI/JS läuft dann nicht sichtbar im Vordergrund,
-- und kann ohnehin keine GTA-Natives wie GetEntityCoords abfragen).
-- Hält sich über denselben bereits vorhandenen Push-Kanal synchron, den
-- auch die NUI nutzt (speditions-tablet:client:push) - cl_orders.lua
-- registriert für locations:changed genau denselben Event-Namen ein
-- zweites Mal, unabhängig vom NUI-Weiterleitungs-Handler in cl_main.lua
-- (der ist an tabletOpen gebunden, dieser hier bewusst nicht).
-- =========================================================

local activeWarningsById = {}
local announcedTiers = {} -- warningId -> { [schwellenwert]=true, ... }

local announcementsEnabled = GetResourceKvpString('warnings_announcements_enabled') ~= '0'
local maxThresholdMeters = tonumber(GetResourceKvpString('warnings_max_threshold_meters')) or Config.Warnings.proximity.thresholdsMeters[1]

-- Unterkategorie-Schlüssel -> Klartext-Label, aus derselben Config.Warnings-
-- Kategorienliste gebaut, die auch der Server als Whitelist nutzt und die
-- NUI über session:whoami bekommt - keine dritte, separat gepflegte Kopie.
local subcategoryLabels = {}
for _, cat in ipairs(Config.Warnings.categories) do
    for _, sub in ipairs(cat.subcategories) do
        subcategoryLabels[sub.key] = sub.label
    end
end

local function unwrap(res)
    if res and res.ok then return res.result end
    return nil
end

local function upsertWarning(w)
    if not w then return end
    activeWarningsById[w.id] = w
end

local function removeWarning(warningId)
    activeWarningsById[warningId] = nil
    announcedTiers[warningId] = nil
end

local function refreshAll()
    ServerCall('warnings:list', nil, function(res)
        local result = unwrap(res)
        if not result then return end
        local fresh = {}
        for _, w in ipairs(result.warnings or {}) do
            fresh[w.id] = w
        end
        activeWarningsById = fresh
        -- Meldungen, die nicht mehr aktiv sind, brauchen auch keinen
        -- gemerkten Ansage-Fortschritt mehr.
        for id in pairs(announcedTiers) do
            if not fresh[id] then announcedTiers[id] = nil end
        end
    end)
end

CreateThread(function()
    Wait(2000) -- kurze Verzögerung, damit ServerCall sicher registriert ist
    refreshAll()
end)

RegisterNetEvent('speditions-tablet:client:push', function(event, data)
    if event ~= 'warnings:changed' then return end
    if data.type == 'created' or data.type == 'confirmed' then
        upsertWarning(data.warning)
    elseif data.type == 'removed' then
        removeWarning(data.warningId)
    elseif data.type == 'expired_batch' then
        refreshAll()
    end
end)

-- ---------------------------------------------------------
-- Persönliche Einstellungen (rein clientseitiges Gerätesetting, keine
-- Firmendaten - überlebt per KVP einen Relog, landet nie in der DB).
-- ---------------------------------------------------------

RegisterNUICallback('warningsGetSettings', function(_, cb)
    cb({ announcementsEnabled = announcementsEnabled, maxThresholdMeters = maxThresholdMeters })
end)

RegisterNUICallback('warningsSetSettings', function(data, cb)
    if data.announcementsEnabled ~= nil then
        announcementsEnabled = data.announcementsEnabled and true or false
        SetResourceKvp('warnings_announcements_enabled', announcementsEnabled and '1' or '0')
    end
    if data.maxThresholdMeters then
        maxThresholdMeters = tonumber(data.maxThresholdMeters) or maxThresholdMeters
        SetResourceKvp('warnings_max_threshold_meters', tostring(maxThresholdMeters))
    end
    cb('ok')
end)

-- ---------------------------------------------------------
-- Annäherungsprüfung
-- ---------------------------------------------------------

--- Vereinfachte Richtungsprüfung ohne Routing-Engine: Winkel zwischen der
--- Blickrichtung des Fahrzeugs (GetEntityForwardVector - unabhängig von
--- der Heading-Gradzahlkonvention, daher robuster als eine manuelle
--- Peilungsberechnung über GetEntityHeading) und der Peilung zur Meldung.
--- Einziger Austauschpunkt für eine spätere echte Routing-API.
local function isApproaching(ped, dx, dy, dist)
    if dist < 5 then return true end -- direkt an der Meldung dran, Richtung irrelevant
    local fwd = GetEntityForwardVector(ped)
    local fMag = math.sqrt(fwd.x * fwd.x + fwd.y * fwd.y)
    if fMag < 0.001 then return true end
    local dot = (fwd.x * dx + fwd.y * dy) / (fMag * dist)
    dot = math.max(-1.0, math.min(1.0, dot))
    local angleDeg = math.deg(math.acos(dot))
    return angleDeg <= Config.Warnings.proximity.approachAngleDegrees
end

--- Prüft die Entfernungs-Schwellen (absteigend, z.B. 1000/500/250m) gegen
--- den bisherigen Ansage-Fortschritt dieser Meldung. Markiert JEDE gerade
--- unterschrittene Schwelle als erledigt (verhindert Wiederholungs-Spam,
--- auch wenn mehrere Schwellen in einem Tick übersprungen werden), gibt
--- aber nur die knappste (kleinste) neu unterschrittene Schwelle zurück -
--- so gibt es pro Tick höchstens eine Ansage pro Meldung.
local function crossedTier(warningId, dist)
    local tiers = Config.Warnings.proximity.thresholdsMeters
    announcedTiers[warningId] = announcedTiers[warningId] or {}
    local progress = announcedTiers[warningId]
    local newTier = nil
    for _, t in ipairs(tiers) do
        if t <= maxThresholdMeters and dist <= t then
            if not progress[t] then newTier = t end
            progress[t] = true
        end
    end
    return newTier
end

local function announceWarning(w, tier)
    local label = subcategoryLabels[w.subcategory] or 'Warnmeldung'
    local message = ('%s in %d Metern.'):format(label, tier)
    -- Lokal ausgelöst (kein Server-Umweg nötig, der Text ist rein
    -- clientseitig gebaut) - landet im bestehenden Hinweis-Handler
    -- (client/cl_main.lua), der automatisch Thefeed-Text + den
    -- konfigurierten Benachrichtigungston auslöst.
    TriggerEvent('speditions-tablet:client:notify', message, 'warning')
    -- Zusätzlich eine tatsächlich GESPROCHENE Ansage über die Web-Speech-
    -- API der NUI (app.js, Handler 'speak') - läuft unabhängig davon, ob
    -- das Tablet gerade sichtbar geöffnet ist (die NUI-Seite bleibt im
    -- Hintergrund aktiv). Rein bestes Bemühen: bietet das eingebettete
    -- FiveM-CEF keine Stimmen an, bleibt der Text-/Ton-Hinweis oben als
    -- einziges, aber weiterhin funktionierendes Signal bestehen.
    SendNUIMessage({ type = 'speak', text = message })
end

CreateThread(function()
    while true do
        Wait(Config.Warnings.proximity.checkIntervalMs)

        if announcementsEnabled and next(activeWarningsById) then
            local ped = PlayerPedId()
            local veh = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or 0
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local coords = GetEntityCoords(ped)
                for id, w in pairs(activeWarningsById) do
                    local dx, dy = w.x - coords.x, w.y - coords.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    local tier = crossedTier(id, dist)
                    if tier and isApproaching(ped, dx, dy, dist) then
                        announceWarning(w, tier)
                    end
                end
            end
        end
    end
end)
