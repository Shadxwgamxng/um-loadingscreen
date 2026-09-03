Config = {}

-- =========================================================
-- ALLGEMEIN
-- =========================================================

-- Firmenname, wird auf dem Sperrbildschirm, im Topbar-Branding und auf der
-- Fahrerkarte angezeigt.
Config.CompanyName = 'Baltic Freight Spedition GmbH'

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
    'license:2368ed9844b18a3bd76048779c665d1f644292d5',
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

-- Frachtarten, die die Fahrerberechtigung "gefahrgut" voraussetzen. Ein
-- Auftrag mit einer dieser Frachtarten kann serverseitig NICHT an einen
-- Fahrer ohne diese Berechtigung disponiert/neu zugewiesen werden.
Config.HazardousCargo = {
    'Chemikalien',
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

-- Koordinaten der Strecken-Orte für den automatischen GPS-Wegpunkt beim
-- Annehmen (-> Beladepunkt) und Losfahren (-> Zielort) eines Auftrags.
-- WICHTIG: Passe diese an die tatsächlichen Be-/Entladepunkte deines
-- Servers an (z.B. Warenhaus-/Lager-Koordinaten) - die Werte hier sind nur
-- grobe Richtwerte in der Nähe der jeweiligen Ortschaft.
Config.Locations = {
    ['Los Santos']   = vector3(215.37, -810.51, 30.72),
    ['Paleto Bay']   = vector3(-448.9, 6008.6, 31.72),
    ['Sandy Shores'] = vector3(1961.48, 3740.75, 32.34),
    ['Grapeseed']    = vector3(1697.62, 4924.32, 42.06),
    ['Harmony']      = vector3(297.05, 3086.5, 42.99),
    ['Grand Senora'] = vector3(2438.0, 3081.0, 48.0),
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
-- LENK- UND RUHEZEITEN
-- =========================================================
-- Angelehnt an die reale EU-Lenkzeitverordnung (vereinfacht). Alle Werte in
-- Minuten. Ein Fahrer "fährt" laut System, solange er auf dem Fahrersitz
-- seines zugewiesenen Firmenfahrzeugs sitzt (Kennzeichen-Abgleich).
Config.DrivingRules = {
    -- Ununterbrochene Lenkzeit, bevor eine Pause zwingend erforderlich ist.
    maxContinuousDrivingMinutes = 270, -- 4,5 Stunden

    -- Wie lange die Pause mindestens dauern muss, um die ununterbrochene
    -- Lenkzeit zurückzusetzen.
    requiredBreakMinutes = 45,

    -- Maximale Lenkzeit pro Tag.
    maxDailyDrivingMinutes = 540, -- 9 Stunden

    -- Wie viele Minuten vor Erreichen eines Limits eine Warnung erfolgen soll.
    warnBeforeMinutes = 15,

    -- Intervall (ms), in dem der Client dem Server aktive Fahrzeit meldet.
    heartbeatIntervalMs = 30 * 1000,
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
