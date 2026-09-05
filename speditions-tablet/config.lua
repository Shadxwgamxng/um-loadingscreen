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

-- Wenn aktiviert, öffnet sich das Tablet NICHT mehr per Command/Keybind,
-- sondern ausschließlich, wenn das konfigurierte Item benutzt wird
-- (per ESX.RegisterUsableItem). Für andere Inventarsysteme (ox_inventory,
-- qb-inventory, ...) lässt du dein eigenes Item-Skript beim Gebrauch selbst
-- das Event 'speditions-tablet:server:openFromItem' (Ziel-Spieler als src)
-- feuern.
Config.RequireItem = {
    enabled = true,
    itemName = 'essence', -- Testwert - auf den echten Tablet-Item-Namen anpassen
}

-- Klingelton, der bei jedem nativen In-Game-Hinweis abgespielt wird (neue
-- Nachricht, neuer Auftrag, Lenkzeit-Warnung, Disponenten-Erinnerung, ...).
-- Name/Soundset müssen ein gültiges GTA-Frontend-Sound-Paar sein.
Config.NotificationSound = {
    name = 'Remote_Text_Tone',
    set = 'Phone_SoundSet_Default',
}

-- =========================================================
-- BOOTSTRAP / ERSTEINRICHTUNG
-- =========================================================
-- Kein Login-Bildschirm: ein Mitarbeiter wird automatisch anhand seines
-- FiveM-Charakters (license) erkannt, sobald er das Tablet öffnet. Die
-- allererste Rolle (z.B. Geschäftsführung) vergibt ein Server-Admin über
-- die Konsole, während die Zielperson online ist:
--   tablet_grant [server-id] [fahrer|disponent|geschaeftsfuehrung] [Anzeigename...]

-- Ace-Permission, die zusätzlich zur Server-Konsole berechtigt, per Command
-- Mitarbeiterrollen zu vergeben (/tablet_grant).
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

-- Bei einer Auszahlung erhält die ausführende Geschäftsführung den Betrag
-- als echtes Bargeld, bei einer Einzahlung wird ihr der Betrag symmetrisch
-- als Bargeld abgezogen (verhindert Geldvermehrung). 'esx' und 'qbcore'
-- binden automatisch an das jeweilige Framework an, 'custom' feuert nur
-- die Events speditions-tablet:server:cashPayout/-cashDeposit, die du
-- selbst in deinem eigenen Wirtschaftssystem abfangen kannst.
Config.MoneyBridge = 'esx' -- 'esx' | 'qbcore' | 'custom'

-- =========================================================
-- CB-FUNK
-- =========================================================
-- Bindet an pma-voice an (exports 'setRadioChannel'/'setRadioVolume'/
-- 'setCallChannel'). Das Funkgerät wird über das Tablet ein-/ausgeschaltet;
-- danach bleibt das Bedienfeld auch bei geschlossenem Tablet sichtbar. Um
-- es zu bedienen (ziehen, Größe ändern, Kanal/Lautstärke/Stumm), während
-- das Tablet geschlossen ist (z.B. während der Fahrt), `interactKey`
-- EINMAL DRÜCKEN schaltet den Mauszeiger dafür an, nochmal drücken wieder
-- aus (kein Gedrückthalten). Ist das Tablet bereits offen, ist das
-- Funkgerät automatisch mitbedienbar. Reagiert die Taste bei dir nicht:
-- in den FiveM-Einstellungen unter "Tastenbelegung" nach "CB-Funk" suchen -
-- ein anderes Skript könnte dieselbe Taste bereits belegt haben, dann hilft
-- nur eine manuelle Neubelegung dort. Gültige Tastennamen: siehe
-- FiveM-Keymapping-Referenz
-- (https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard).
Config.CbRadio = {
    minChannel = 1,
    maxChannel = 9,
    defaultChannel = 1,
    defaultVolume = 80, -- 0-100
    interactKey = 'F7',
    callRingSeconds = 20, -- wie lange ein Anruf klingelt, bevor automatisch aufgelegt wird
}

-- =========================================================
-- GEHÄLTER / STEMPELUHR
-- =========================================================
-- Stundenlohn je Rolle. Wird nur EINMALIG beim ersten Ressourcenstart in die
-- Datenbank (st_wage_rates) übernommen - danach ist die Datenbank die Quelle
-- der Wahrheit, die Geschäftsführung kann die Sätze am Tablet anpassen
-- (Reiter "Gehälter"). Änderungen hier in der Config wirken sich NICHT mehr
-- aus, sobald die Sätze einmal in der Datenbank stehen.
Config.DefaultHourlyWage = {
    fahrer = 25,
    disponent = 30,
    geschaeftsfuehrung = 35,
}

-- =========================================================
-- LOGGING
-- =========================================================
Config.Debug = false
