Config = {}

-- =========================================================
-- ALLGEMEIN
-- =========================================================

-- Command zum Öffnen des Tablets. Zusätzlich kann per Export
-- exports['speditions-tablet']:OpenTablet() geöffnet werden
-- (z.B. aus einem Inventar-Item-Use-Handler eines anderen Skripts).
Config.OpenCommand = 'tablet'
Config.OpenKey = 'F6' -- Keybind wird clientseitig via RegisterCommand + Keymapping gesetzt

-- =========================================================
-- BOOTSTRAP / ERSTEINRICHTUNG
-- =========================================================
-- Lizenzen (identifier:license:xxxx) die beim ersten Connect automatisch
-- als Geschäftsführung angelegt werden, falls noch kein Mitarbeiter-Eintrag
-- existiert. Damit ist ohne Framework-Integration eine Ersteinrichtung möglich.
Config.InitialOwners = {
    -- 'license:1234567890abcdef1234567890abcdef12345678',
}

-- Ace-Permission die zusätzlich zu Config.InitialOwners berechtigt,
-- per Command Mitarbeiter zu bootstrappen (/tablet_grant).
Config.AdminAcePermission = 'speditions.admin'

-- =========================================================
-- ROLLEN
-- =========================================================
Config.Roles = {
    FAHRER = 'fahrer',
    DISPONENT = 'disponent',
    GESCHAEFTSFUEHRUNG = 'geschaeftsfuehrung',
}

Config.RoleLabels = {
    fahrer = 'LKW-Fahrer',
    disponent = 'Disponent',
    geschaeftsfuehrung = 'Geschäftsführung',
}

-- =========================================================
-- FAHRERBERECHTIGUNGEN (Führerscheinklassen etc.)
-- =========================================================
Config.DriverPermissions = {
    { key = 'klasse_c', label = 'Klasse C' },
    { key = 'klasse_ce', label = 'Klasse CE' },
    { key = 'gefahrgut', label = 'Gefahrgut' },
    { key = 'schwertransport', label = 'Schwertransport' },
}

-- =========================================================
-- FAHRZEUGE
-- =========================================================
Config.VehicleClasses = {
    'Sattelzugmaschine',
    'Verteiler-LKW',
    'Schwerlast',
    'Kühltransporter',
    'Tanklastzug',
}

Config.VehicleStatus = {
    VERFUEGBAR = 'verfuegbar',
    IM_EINSATZ = 'im_einsatz',
    WARTUNG = 'wartung',
    DEFEKT = 'defekt',
    AUSSER_BETRIEB = 'ausser_betrieb',
}

-- Status, in denen ein Fahrzeug NICHT für neue Aufträge disponiert werden darf
Config.VehicleBlockedForDispatch = {
    wartung = true,
    defekt = true,
    ausser_betrieb = true,
}

-- =========================================================
-- AUFTRÄGE / STRECKEN
-- =========================================================
Config.CargoTypes = {
    'Baustoffe', 'Lebensmittel', 'Elektronik', 'Möbel',
    'Fahrzeugteile', 'Chemikalien', 'Holz', 'Maschinenteile',
}

-- Vordefinierte Strecken mit Distanz (km) und Basis-Auftragswert-Spanne ($)
Config.Routes = {
    { from = 'Los Santos',    to = 'Paleto Bay',    distance = 45.2, minValue = 8000,  maxValue = 14000 },
    { from = 'Los Santos',    to = 'Sandy Shores',  distance = 38.6, minValue = 6500,  maxValue = 12000 },
    { from = 'Sandy Shores',  to = 'Paleto Bay',    distance = 22.1, minValue = 4000,  maxValue = 8000  },
    { from = 'Los Santos',    to = 'Grapeseed',     distance = 41.0, minValue = 7000,  maxValue = 13000 },
    { from = 'Paleto Bay',    to = 'Grapeseed',     distance = 12.4, minValue = 2500,  maxValue = 5000  },
    { from = 'Los Santos',    to = 'Harmony',       distance = 15.8, minValue = 3000,  maxValue = 6000  },
    { from = 'Sandy Shores',  to = 'Grand Senora',  distance = 18.3, minValue = 3200,  maxValue = 6500  },
}

-- Durchschnittsgeschwindigkeit (km/h) zur Berechnung der Lieferfrist (Pünktlichkeit)
Config.AverageSpeedKmh = 65

-- Zusätzlicher Puffer in Minuten auf die berechnete Fahrzeit
Config.DeadlineBufferMinutes = 8

-- Automatische Auftragsgenerierung
Config.OrderGeneration = {
    enabled = true,
    intervalMs = 6 * 60 * 1000, -- alle 6 Minuten ein neuer Pool-Auftrag
    maxOpenOrders = 12,          -- maximale Anzahl unbearbeiteter (offener) Aufträge im Pool
}

-- =========================================================
-- FINANZEN
-- =========================================================
Config.Currency = {
    prefix = '$',
    suffix = '',
    thousandsSeparator = '.',
}

Config.DefaultPayoutTarget = 'Unternehmensbankkonto'

-- =========================================================
-- LOGGING
-- =========================================================
Config.Debug = false
