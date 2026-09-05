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
    'Farben', 'Öle',
}

-- Frachtarten, die die Fahrerberechtigung "gefahrgut" voraussetzen. Ein
-- Auftrag mit einer dieser Frachtarten kann serverseitig NICHT an einen
-- Fahrer ohne diese Berechtigung disponiert/neu zugewiesen werden.
Config.HazardousCargo = {
    'Chemikalien',
}

-- Menge/Einheit je Frachtart für den Lieferschein (zufällig innerhalb der
-- Spanne je generiertem Auftrag).
Config.CargoUnits = {
    Holz            = { unit = 'Festmeter', min = 5,   max = 40   },
    Lebensmittel    = { unit = 'kg',        min = 200, max = 2000 },
    Farben          = { unit = 'Liter',     min = 100, max = 1500 },
    Fahrzeugteile   = { unit = 'Stück',     min = 5,   max = 80   },
    Chemikalien     = { unit = 'Liter',     min = 100, max = 1000 },
    Baustoffe       = { unit = 'Tonnen',    min = 2,   max = 25   },
    Maschinenteile  = { unit = 'Stück',     min = 1,   max = 20   },
    ['Öle']         = { unit = 'Liter',     min = 100, max = 2000 },
    ['Möbel']       = { unit = 'Stück',     min = 1,   max = 30   },
    Elektronik      = { unit = 'Stück',     min = 1,   max = 50   },
}

-- =========================================================
-- BELADE-/ENTLADEPUNKTE
-- =========================================================
-- Jeder Ort ist ein echter Firmenstandort in der Welt: dort markiert ein
-- Bodenkreis die Be-/Entladestelle, an der per Tasteninteraktion (E) die
-- Fracht ab-/angenommen wird (siehe client/cl_orders.lua - bewusst kein
-- NPC, um Probleme mit der Pedestrian-KI zu vermeiden). `sourceCargo` =
-- Frachtarten, die hier ABGEHOLT werden können (Auftrags-Startpunkt),
-- `destCargo` = Frachtarten, die hier ANGENOMMEN werden
-- (Auftrags-Zielpunkt). Ein Auftrag wird nur zwischen zwei
-- UNTERSCHIEDLICHEN Orten generiert, die dieselbe Frachtart als Quelle
-- bzw. Ziel führen. `coords` ist x, y, z, Blickrichtung (Heading, aktuell
-- ungenutzt ohne NPC).
Config.Locations = {
    { name = 'Holzhandel Hirschweiler',                coords = vector4(46.5653, 6301.5454, 31.2295, 139.2673),   sourceCargo = { 'Holz' } },
    { name = 'Schlachterei Hirschweiler',               coords = vector4(-74.7670, 6265.5103, 31.2581, 59.6800),   sourceCargo = { 'Lebensmittel' } },
    { name = 'Bauer Siggi Hirschweiler',                coords = vector4(417.5191, 6472.0654, 28.8115, 58.1537),  sourceCargo = { 'Lebensmittel' } },
    { name = 'Holzverarbeitung Hirschweiler',           coords = vector4(-600.0895, 5292.8071, 70.2152, 260.2553), sourceCargo = { 'Holz' } },
    { name = 'Farbhandel Friederichsen',                coords = vector4(1646.7103, 4837.1064, 42.0292, 95.3194), sourceCargo = { 'Farben' } },
    { name = 'KfZ Werkstatt Meier',                     coords = vector4(1963.2445, 5177.4312, 47.9211, 290.3256), destCargo = { 'Fahrzeugteile', 'Öle' } },
    { name = 'Gefahrenstoffzentrum Galileo Park',       coords = vector4(2902.0540, 4369.3184, 50.3478, 294.0421), sourceCargo = { 'Chemikalien' } },
    { name = 'Garten- & Landschaftsbau Machere',        coords = vector4(2908.5291, 4466.8555, 48.1954, 153.3615), destCargo = { 'Holz', 'Farben', 'Baustoffe' } },
    { name = 'Baumarkt Thomsen Nord',                   coords = vector4(2680.3562, 3504.5762, 53.3038, 68.0863), destCargo = { 'Baustoffe', 'Farben', 'Holz' } },
    { name = 'Kiesgrube Nord',                          coords = vector4(2682.2056, 2796.8303, 40.4611, 6.2855),  sourceCargo = { 'Baustoffe' } },
    { name = 'Kiesgrube Nord - Abbau',                  coords = vector4(2943.4368, 2744.2578, 43.3081, 286.8217), sourceCargo = { 'Baustoffe' } },
    { name = 'Kohlekraftwerk',                          coords = vector4(2710.9817, 1514.1188, 24.5007, 76.9679), destCargo = { 'Maschinenteile', 'Öle' } },
    { name = 'Zentrallager Box 9 (Holz)',                coords = vector4(1709.7573, -1503.2196, 113.9467, 70.8459), destCargo = { 'Holz' } },
    { name = 'Zentrallager Box 2 (Sonstiges)',           coords = vector4(1727.7478, -1535.5013, 113.9467, 249.7921), destCargo = { 'Möbel', 'Elektronik' } },
    { name = 'Zentrallager Anlieferung Schüttgut',       coords = vector4(1742.9828, -1632.9983, 112.4680, 99.0393), destCargo = { 'Baustoffe' } },
    { name = 'Zentrallager Anlieferung Gefahrenstoffe',  coords = vector4(1490.6962, -1910.1671, 71.5243, 211.0637), destCargo = { 'Chemikalien' } },
    { name = 'Zentrallager Anlieferung Altmetalle',      coords = vector4(1568.3628, -2165.1841, 77.5721, 84.1045), destCargo = { 'Maschinenteile' } },
    { name = 'Zentrallager Abholung Öle',                coords = vector4(1258.2878, -1907.9558, 38.5011, 16.5664), sourceCargo = { 'Öle' } },
    { name = 'Metallschmelze',                          coords = vector4(1098.6482, -1984.2262, 31.0147, 325.9687), sourceCargo = { 'Maschinenteile' } },
    { name = 'Zwischenlager Baumarkt',                   coords = vector4(998.3950, -1855.2062, 31.0398, 182.0329), sourceCargo = { 'Baustoffe' } },
    { name = 'Grosshandel Holzwaren',                    coords = vector4(500.7615, -1965.1077, 24.9851, 125.8696), sourceCargo = { 'Holz' } },
    { name = 'Anlieferung Shopping Center',               coords = vector4(96.4740, -1808.7917, 27.0821, 229.9650), destCargo = { 'Möbel', 'Elektronik', 'Lebensmittel' } },
    { name = 'Anlieferung KfZ Werkstatt (Stadt)',        coords = vector4(-195.5794, -1376.9260, 31.2584, 208.8103), destCargo = { 'Fahrzeugteile', 'Öle' } },
    { name = 'Baustelle Stadt/West',                     coords = vector4(-502.1097, -941.4283, 23.9640, 152.0452), destCargo = { 'Baustoffe' } },
    { name = 'Baustelle Stadtmitte',                     coords = vector4(-121.6090, -1056.7939, 27.2595, 293.2224), destCargo = { 'Baustoffe' } },
    { name = 'Baustelle Stadt/Nord',                     coords = vector4(93.9297, -375.4476, 41.9395, 200.3073),  destCargo = { 'Baustoffe' } },
    { name = 'Baustelle Stadt/ost',                      coords = vector4(1393.6664, -738.7650, 67.1901, 101.5932), destCargo = { 'Baustoffe' } },
    { name = 'Anlieferung Einkaufszentrum Weststadt',    coords = vector4(-1543.6205, -590.0679, 34.8675, 354.0047), destCargo = { 'Möbel', 'Elektronik', 'Lebensmittel' } },
    { name = 'Anlieferung 24/7 Supermarkt',               coords = vector4(-2955.2710, 396.4877, 15.0217, 61.8753), destCargo = { 'Lebensmittel' } },
    { name = 'Abholung KfZ-Teilehandel',                  coords = vector4(963.3997, -1017.6773, 40.8475, 265.3992), sourceCargo = { 'Fahrzeugteile' } },
    { name = 'Möbeltischlerei Hirschweiler',              coords = vector4(179.6482, 6162.3105, 31.6971, 320.5), sourceCargo = { 'Möbel' } },
    { name = 'Zentrallager Box 5 (Möbel)',                coords = vector4(1718.9204, -1519.7361, 113.9467, 159.8), sourceCargo = { 'Möbel' } },
}

-- Wertspanne ($ pro km), aus der zufällig der Auftragswert berechnet wird
-- (Distanz wird automatisch aus den echten Koordinaten der Be-/Entladepunkte
-- berechnet, keine manuelle Streckenpflege mehr nötig).
Config.OrderValuePerKm = { min = 180, max = 320 }

-- Wie lange das Be-/Entladen per Tasteninteraktion (E) am Markierungskreis
-- dauert (Sekunden).
Config.LoadUnloadSeconds = 150 -- 2,5 Minuten

-- Ab welcher Entfernung (Meter) der Bodenmarker eines Be-/Entladepunkts
-- überhaupt erst gezeichnet wird (Performance).
Config.LocationMarkerRadius = 60.0
-- Ab welcher Entfernung (Meter) die "Drücke E"-Interaktion angezeigt wird.
Config.LocationInteractRadius = 2.5

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

-- Blendet im Tablet (Reiter "Aufträge", Offener Auftragspool) für Fahrer
-- einen Button "Auftrag generieren" ein, der sofort - unabhängig vom oben
-- konfigurierten Intervall - einen neuen Testauftrag erzeugt. Nur zum
-- Testen gedacht: für den Live-Betrieb wieder auf false stellen.
Config.AllowManualOrderGeneration = true

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
