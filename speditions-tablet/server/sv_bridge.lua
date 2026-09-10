-- =========================================================
-- Wirtschafts-Anbindung (Bargeld bei Aus-/Einzahlung)
--
-- Bei einer Auszahlung soll die ausführende Geschäftsführung das Geld als
-- echtes Bargeld "in die Hand" bekommen. Damit das keine Geldvermehrung
-- ermöglicht (Einzahlung ohne echten Bargeldabzug + Auszahlung mit echtem
-- Bargeldzugang wäre ein Dupe), zieht eine Einzahlung dem Ausführenden
-- symmetrisch echtes Bargeld ab. Unterstützt ESX und QBCore; für alles
-- andere ('custom') werden nur generische Events gefeuert, die ein eigenes
-- Wirtschaftsskript abfangen kann.
-- =========================================================

Bridge = {}

local ESX = nil
local QBCore = nil

local function getEsx()
    if ESX then return ESX end
    local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok and obj then ESX = obj end
    return ESX
end

--- Öffentlicher Zugriff auf das ESX-Objekt (z.B. für RegisterUsableItem in
--- sv_main.lua), damit die Erkennungslogik nicht doppelt existiert.
Bridge.GetEsx = getEsx

local function getQbCore()
    if QBCore then return QBCore end
    local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok and obj then QBCore = obj end
    return QBCore
end

CreateThread(function()
    if Config.MoneyBridge == 'esx' and not getEsx() then
        print('^1[speditions-tablet]^7 Config.MoneyBridge ist "esx", aber es_extended wurde nicht gefunden. Bargeld-Aus-/Einzahlung ist deaktiviert (nur generische Events).')
    elseif Config.MoneyBridge == 'qbcore' and not getQbCore() then
        print('^1[speditions-tablet]^7 Config.MoneyBridge ist "qbcore", aber qb-core wurde nicht gefunden. Bargeld-Aus-/Einzahlung ist deaktiviert (nur generische Events).')
    end
end)

--- Gibt dem Spieler Bargeld (z.B. bei einer Auszahlung). Best-effort: schlägt
--- die Framework-Anbindung fehl, wird trotzdem das generische Event gefeuert,
--- damit ein eigenes Wirtschaftsskript einhaken kann. Gibt zurück, ob die
--- Framework-Anbindung selbst erfolgreich war.
function Bridge.AddCash(src, amount)
    amount = math.floor((tonumber(amount) or 0) + 0.5)
    if amount <= 0 then return true end

    local applied = false

    if Config.MoneyBridge == 'esx' then
        local esx = getEsx()
        local xPlayer = esx and esx.GetPlayerFromId(src)
        if xPlayer then
            if xPlayer.addMoney then
                xPlayer.addMoney(amount)
                applied = true
            elseif xPlayer.addAccountMoney then
                xPlayer.addAccountMoney('money', amount)
                applied = true
            end
        end
    elseif Config.MoneyBridge == 'qbcore' then
        local qb = getQbCore()
        local player = qb and qb.Functions.GetPlayer(src)
        if player then
            player.Functions.AddMoney('cash', amount)
            applied = true
        end
    end

    TriggerEvent('speditions-tablet:server:cashPayout', src, amount)
    return applied
end

--- Zieht dem Spieler Bargeld ab (z.B. bei einer Einzahlung). Gibt false
--- zurück, wenn nicht genug Bargeld vorhanden ist oder keine unterstützte
--- Framework-Anbindung gefunden wurde - der Aufrufer MUSS das prüfen und
--- die Einzahlung in diesem Fall verweigern, sonst könnte über Ein-/
--- Auszahlung Geld vervielfacht werden.
function Bridge.RemoveCash(src, amount)
    amount = math.floor((tonumber(amount) or 0) + 0.5)
    if amount <= 0 then return true end

    if Config.MoneyBridge == 'esx' then
        local esx = getEsx()
        local xPlayer = esx and esx.GetPlayerFromId(src)
        if not xPlayer then return false end

        local current = xPlayer.getMoney and xPlayer.getMoney() or nil
        if not current and xPlayer.getAccount then
            local account = xPlayer.getAccount('money')
            current = account and account.money
        end
        if not current or current < amount then return false end

        if xPlayer.removeMoney then
            xPlayer.removeMoney(amount)
        elseif xPlayer.removeAccountMoney then
            xPlayer.removeAccountMoney('money', amount)
        else
            return false
        end

        TriggerEvent('speditions-tablet:server:cashDeposit', src, amount)
        return true
    elseif Config.MoneyBridge == 'qbcore' then
        local qb = getQbCore()
        local player = qb and qb.Functions.GetPlayer(src)
        if not player then return false end

        local current = player.Functions.GetMoney('cash')
        if not current or current < amount then return false end

        player.Functions.RemoveMoney('cash', amount)
        TriggerEvent('speditions-tablet:server:cashDeposit', src, amount)
        return true
    end

    -- 'custom': keine Guthabenprüfung durch dieses Skript möglich - das
    -- eigene Wirtschaftsskript ist selbst dafür verantwortlich, dieses
    -- Event zu prüfen und ggf. abzulehnen.
    TriggerEvent('speditions-tablet:server:cashDeposit', src, amount)
    return true
end
