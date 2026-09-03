-- =========================================================
-- Allgemeine Server-Hilfsfunktionen
-- =========================================================

Utils = {}

--- Liefert den (stabilen) Spieler-Identifier (license) für einen Server-Slot.
---@param src number
---@return string|nil
function Utils.GetIdentifier(src)
    if type(src) ~= 'number' or src <= 0 then return nil end
    local numIds = GetNumPlayerIdentifiers(src)
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:find('license:') == 1 then
            return id
        end
    end
    return nil
end

function Utils.GetPlayerName(src)
    return GetPlayerName(src) or ('Unbekannt#' .. tostring(src))
end

function Utils.Now()
    return os.date('%Y-%m-%d %H:%M:%S')
end

--- Runde auf 2 Nachkommastellen (Geldbeträge / km)
function Utils.Round2(n)
    n = tonumber(n) or 0
    return math.floor(n * 100 + 0.5) / 100
end

function Utils.Trim(s)
    if type(s) ~= 'string' then return s end
    return s:match('^%s*(.-)%s*$')
end

--- Sehr defensive Eingabeprüfung für Freitext-Felder aus der NUI.
--- Verhindert überlange / leere Strings, kein SQL-Escaping nötig
--- (oxmysql arbeitet ausschließlich mit parametrisierten Queries).
function Utils.SanitizeString(s, maxLen)
    if type(s) ~= 'string' then return nil end
    s = Utils.Trim(s)
    if s == '' then return nil end
    maxLen = maxLen or 255
    if #s > maxLen then
        s = s:sub(1, maxLen)
    end
    return s
end

function Utils.SanitizeNumber(n, min, max)
    n = tonumber(n)
    if not n then return nil end
    if min and n < min then return nil end
    if max and n > max then return nil end
    return n
end

function Utils.InTable(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

function Utils.DebugPrint(...)
    if Config.Debug then
        print('^3[speditions-tablet]^7', ...)
    end
end

--- Sucht den Server-Slot eines Mitarbeiters unter den aktuell verbundenen
--- Spielern (nur die, die das Tablet bereits mindestens einmal geöffnet
--- und damit einen Session-Cache-Eintrag haben).
function Utils.FindSrcByEmployeeId(employeeId)
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local cached = Employees.GetCached(src)
        if cached and cached.id == employeeId then
            return src
        end
    end
    return nil
end

--- Löst einen nativen In-Game-Hinweis beim Client aus (funktioniert auch,
--- wenn das Tablet gerade nicht geöffnet ist - z.B. für Lenkzeit-Warnungen
--- oder "neuer Auftrag zugewiesen").
function Utils.NotifyClient(src, message, notifyType)
    if not src then return end
    TriggerClientEvent('speditions-tablet:client:notify', src, message, notifyType or 'info')
end

--- Setzt beim Client einen GPS-Wegpunkt (z.B. Beladepunkt/Zielort eines Auftrags).
function Utils.SetClientWaypoint(src, locationName, label)
    if not src then return end
    local coords = Config.Locations[locationName]
    if not coords then return end
    TriggerClientEvent('speditions-tablet:client:waypoint', src, coords.x, coords.y, label or locationName)
end
