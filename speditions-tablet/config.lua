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

-- Prop, das dem Spieler in die Hand gelegt wird, solange das Tablet
-- geöffnet ist (client/cl_main.lua) - rein optisch, ohne Bewegungs-
-- einschränkung. offset/rotation ggf. nachjustieren (X = seitlich,
-- Y = vor/zurück, Z = hoch/runter, rotation in Grad); bone ist der
-- Ped-Knochen, an den angehängt wird (28422 = SKEL_L_Hand).
Config.TabletProp = {
    enabled = true,
    model = 'prop_cs_tablet',
    bone = 28422,
    offset = { x = 0.03, y = 0.02, z = -0.02 },
    rotation = { x = 0.0, y = 0.0, z = 0.0 },
}

-- Wenn aktiviert, öffnet sich das Tablet NICHT mehr per Command/Keybind,
-- sondern ausschließlich, wenn das konfigurierte Item benutzt wird
-- (automatisch per ESX.RegisterUsableItem bzw.
-- QBCore.Functions.CreateUseableItem, je nachdem welches Framework läuft).
-- Für ein reines Inventarsystem ohne diese Funktion (z.B. ox_inventory ohne
-- QBCore) lässt du dein eigenes Item-Skript beim Gebrauch selbst das Event
-- 'speditions-tablet:server:openFromItem' (Ziel-Spieler als src) feuern.
Config.RequireItem = {
    enabled = true,
    itemName = 'tablet_baltic',
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
-- Das Tablet hat einen eigenen Login (Name + Passwort), unabhängig vom
-- FiveM-Charakter - ein Mitarbeiter meldet sich beim Öffnen des Tablets mit
-- seinen Zugangsdaten an (server/sv_bootstrap.lua, Employees.Login).
-- Erstkonten werden beim allerersten Ressourcenstart aus Config.InitialAccounts
-- angelegt - Passwort danach unbedingt ändern! Weitere Konten legt die
-- Geschäftsführung im Tablet an, oder ein Server-Admin über die Konsole:
--   tablet_grant [name] [passwort] [fahrer|disponent|geschaeftsfuehrung] [Anzeigename...]
Config.InitialAccounts = {
    { username = 'admin', password = 'LECKARSCH123!', role = 'geschaeftsfuehrung', name = 'Administrator' },
}

-- Ace-Permission, die zusätzlich zur Server-Konsole berechtigt, per Command
-- Mitarbeiterkonten anzulegen/zurückzusetzen (/tablet_grant).
Config.AdminAcePermission = 'speditions.admin'

-- =========================================================
-- ROLLEN & BERECHTIGUNGEN
-- =========================================================
-- Fahrer/Disponent/Geschäftsführung sind die drei mitgelieferten
-- Basisrollen (Rollenschlüssel fix, u.a. für die automatische
-- Fahrerakten-Anlage und Config.InitialAccounts/tablet_grant relevant).
-- Zusätzlich kann die Geschäftsführung im Tablet (Reiter "Rollen")
-- beliebig weitere, frei benannte Rollen mit einer eigenen Auswahl an
-- Berechtigungen anlegen - siehe server/sv_roles.lua. Welche
-- Berechtigungen eine Rolle tatsächlich hat, steht ausschließlich in der
-- Datenbank (st_roles); Config.DefaultRolePermissions unten wirkt nur
-- EINMALIG als Erstbefüllung der drei Basisrollen (wie bei
-- Config.DefaultHourlyWage), danach ist die Datenbank die Quelle der
-- Wahrheit.
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

-- Katalog aller im Tablet verfügbaren Einzelberechtigungen - das ist die
-- vollständige Auswahl, aus der die Geschäftsführung beim Anlegen/
-- Bearbeiten einer Rolle wählen kann (Reiter "Rollen").
Config.Permissions = {
    { key = 'driver_actions',    label = 'Fahrerfunktionen (Aufträge fahren, Fahrerkarte, eigene Statistik, Nachrichten empfangen)', group = 'Fahrer' },
    { key = 'dispatch',          label = 'Disposition (Fahrerübersicht, Auftragspool disponieren, Fahrer kontaktieren)', group = 'Disposition' },
    { key = 'fleet_manage',      label = 'Fuhrparkverwaltung (Fahrzeuge anlegen/bearbeiten/löschen/zuweisen)', group = 'Fuhrpark' },
    { key = 'locations_manage',  label = 'Orte verwalten (Be-/Entladepunkte anlegen/bearbeiten/löschen)', group = 'Fuhrpark' },
    { key = 'cargo_types_manage', label = 'Frachtarten verwalten (anlegen/bearbeiten/löschen)', group = 'Fuhrpark' },
    { key = 'employees_manage',  label = 'Mitarbeiterverwaltung (einstellen, Rolle/Status ändern, Passwörter zurücksetzen)', group = 'Personal' },
    { key = 'roles_manage',      label = 'Rollen & Berechtigungen verwalten', group = 'Personal' },
    { key = 'finance_view',      label = 'Finanzen einsehen (Umsatz, Transaktionen, Aus-/Einzahlungshistorie)', group = 'Finanzen' },
    { key = 'finance_payout',    label = 'Aus-/Einzahlungen durchführen', group = 'Finanzen' },
    { key = 'wages_manage',      label = 'Gehälter/Stundenlöhne verwalten & auszahlen', group = 'Finanzen' },
    { key = 'activity_log_view', label = 'Aktivitätsprotokoll einsehen', group = 'Sonstiges' },
    { key = 'stats_view',        label = 'Übersicht/Statistik-Dashboard einsehen', group = 'Sonstiges' },
    { key = 'console_view',      label = 'Fehler-Konsole einsehen (RPC-/Datenbankfehler)', group = 'Sonstiges' },
}

-- Erstbefüllung der drei mitgelieferten Basisrollen (nur beim allerersten
-- Anlegen der jeweiligen Rolle in st_roles relevant, siehe oben).
Config.DefaultRolePermissions = {
    fahrer = { 'driver_actions' },
    disponent = { 'dispatch' },
    -- driver_actions dabei: die Geschäftsführung soll alles können, was ein
    -- LKW-Fahrer auch kann (Fahrerkarte, Aufträge fahren, eigene Statistik,
    -- Nachrichten empfangen) - zusätzlich zu den GF-eigenen Funktionen.
    geschaeftsfuehrung = {
        'driver_actions', 'dispatch', 'fleet_manage', 'locations_manage', 'cargo_types_manage', 'employees_manage', 'roles_manage',
        'finance_view', 'finance_payout', 'wages_manage', 'activity_log_view', 'stats_view', 'console_view',
    },
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
-- Frachtarten werden NICHT mehr live aus der Config gelesen, sondern in der
-- Datenbank (st_cargo_types) gepflegt - die Geschäftsführung kann sie im
-- Tablet-Reiter "Frachtarten" selbst anlegen/bearbeiten/löschen (Name,
-- Einheit + Mengenspanne fürs Lieferschein, ob Gefahrgut-Berechtigung nötig
-- ist, welcher Anhängertyp gebraucht wird), siehe server/sv_cargo_types.lua.
-- `Config.SeedCargoTypes` wirkt genau wie `Config.SeedLocations` nur EINMALIG
-- als Erstbefüllung beim allerersten Ressourcenstart (per Namen,
-- `ON DUPLICATE KEY` - bereits vorhandene Frachtarten werden nicht
-- überschrieben) - danach ist ausschließlich die Datenbank die Quelle der
-- Wahrheit, Änderungen hier haben dann keine Wirkung mehr. `trailerType` ohne
-- Eintrag/leer fällt auf den Standard-Anhänger 'curtainsider' zurück.
Config.SeedCargoTypes = {
    { name = 'Baustoffe',      unit = 'Tonnen',    min = 2,    max = 25,    hazardous = false, trailerType = 'kipper' },
    { name = 'Lebensmittel',   unit = 'kg',        min = 200,  max = 2000,  hazardous = false, trailerType = 'kuehlanhaenger' },
    { name = 'Elektronik',     unit = 'Stück',     min = 1,    max = 50,    hazardous = false, trailerType = 'curtainsider' },
    { name = 'Möbel',          unit = 'Stück',     min = 1,    max = 30,    hazardous = false, trailerType = 'curtainsider' },
    { name = 'Fahrzeugteile',  unit = 'Stück',     min = 5,    max = 80,    hazardous = false, trailerType = 'curtainsider' },
    { name = 'Chemikalien',    unit = 'Liter',     min = 100,  max = 1000,  hazardous = true,  trailerType = 'curtainsider_gefahrgut' },
    { name = 'Holz',           unit = 'Festmeter', min = 5,    max = 40,    hazardous = false, trailerType = 'curtainsider' },
    { name = 'Maschinenteile', unit = 'Stück',     min = 1,    max = 20,    hazardous = false, trailerType = 'curtainsider' },
    { name = 'Farben',         unit = 'Liter',     min = 100,  max = 1500,  hazardous = false, trailerType = 'curtainsider' },
    { name = 'Öle',            unit = 'Liter',     min = 100,  max = 2000,  hazardous = false, trailerType = 'tankanhaenger' },
    { name = 'Kraftstoff',     unit = 'Liter',     min = 2000, max = 15000, hazardous = false, trailerType = 'tankanhaenger' },
    { name = 'Schmuck',        unit = 'Stück',     min = 5,    max = 50,    hazardous = false, trailerType = 'curtainsider' },
    { name = 'Kleidung',       unit = 'Stück',     min = 100,  max = 800,   hazardous = false, trailerType = 'curtainsider' },
    { name = 'Schrott',        unit = 'kg',        min = 500,  max = 5000,  hazardous = false, trailerType = 'kipper' },
}

-- Katalog der verfügbaren Anhängertypen (Reiter "Anhänger") - `key` steht in
-- st_trailers.type, `label` ist die Anzeige im Tablet.
Config.TrailerTypes = {
    { key = 'curtainsider',          label = 'Curtainsider' },
    { key = 'curtainsider_gefahrgut', label = 'Curtainsider (Gefahrgutzulassung)' },
    { key = 'kipper',                label = 'Kipper' },
    { key = 'kuehlanhaenger',        label = 'Kühlanhänger' },
    { key = 'tankanhaenger',         label = 'Tankanhänger' },
}

-- =========================================================
-- BELADE-/ENTLADEPUNKTE (ORTE)
-- =========================================================
-- Orte werden NICHT mehr live aus der Config gelesen, sondern in der
-- Datenbank (st_locations) gepflegt - die Geschäftsführung kann sie im
-- Tablet-Reiter "Orte" selbst anlegen/bearbeiten/löschen (inkl. "Aktuelle
-- Position übernehmen"), siehe server/sv_locations.lua. `Config.SeedLocations`
-- wirkt genau wie `Config.DefaultRolePermissions`/`Config.DefaultHourlyWage`
-- nur EINMALIG als Erstbefüllung beim allerersten Ressourcenstart (per
-- Namen, `ON DUPLICATE KEY` - bereits vorhandene Orte werden nicht
-- überschrieben) - danach ist ausschließlich die Datenbank die Quelle der
-- Wahrheit, Änderungen hier haben dann keine Wirkung mehr. `sourceCargo` =
-- Frachtarten, die an einem Ort ABGEHOLT werden können (Auftrags-
-- Startpunkt), `destCargo` = Frachtarten, die dort ANGENOMMEN werden
-- (Auftrags-Zielpunkt) - ein Auftrag wird nur zwischen zwei
-- UNTERSCHIEDLICHEN Orten generiert, die dieselbe Frachtart als Quelle bzw.
-- Ziel führen (siehe server/sv_orders.lua, Orders.GenerateOne). `coords` ist
-- x, y, z, Blickrichtung (Heading).
Config.SeedLocations = {
    { name = 'Tankstelle Südstadt',                   coords = vector4(-1413.0906, -276.3613, 46.3573, 122.9841),  destCargo = { 'Kraftstoff' } },
    { name = 'Einkaufsstraße Südstadt',                coords = vector4(-1322.3031, -756.9341, 20.3754, 132.1405),  destCargo = { 'Elektronik', 'Möbel' } },
    { name = 'Vangelico Juwelier',                     coords = vector4(-632.0485, -239.9601, 38.1142, 113.6025),   sourceCargo = { 'Schmuck' } },
    { name = 'Lichtkick Filmtheater',                  coords = vector4(-486.6024, -447.9075, 34.2013, 165.1228),   destCargo = { 'Elektronik' } },
    { name = 'Klamottenladen Nordstadt',               coords = vector4(-58.4882, -176.9483, 54.2738, 159.8721),    destCargo = { 'Kleidung' } },
    { name = 'Tattoozentrum Nordstadt',                coords = vector4(-52.4797, -179.4368, 54.2742, 147.3091),    destCargo = { 'Farben' } },
    { name = 'Apotheke Nordstadt',                     coords = vector4(-45.8573, -182.2130, 54.2699, 156.1175),    destCargo = { 'Chemikalien' } },
    { name = 'Euroshop Nordstadt',                     coords = vector4(45.4441, -106.2116, 56.0044, 337.8018),     destCargo = { 'Elektronik' } },
    { name = 'Paketzentrum Nordstadt',                 coords = vector4(65.1030, 129.8393, 80.5308, 162.2396),      destCargo = { 'Elektronik', 'Möbel' } },
    { name = 'Fast-Food Laden Nordstadt',              coords = vector4(90.7449, 298.1360, 110.2102, 338.5446),     destCargo = { 'Lebensmittel' } },
    { name = 'Juwelier Nordstadt',                     coords = vector4(236.8944, 380.8580, 106.1918, 341.7407),    destCargo = { 'Schmuck' } },
    { name = 'Second Hand Klamottenladen Nordstadt',   coords = vector4(331.1173, 362.7849, 106.6535, 355.3933),    sourceCargo = { 'Kleidung' } },
    { name = '24/7 Supermarkt Nordstadt',              coords = vector4(382.3276, 356.3886, 102.5808, 350.3206),    destCargo = { 'Lebensmittel' } },
    { name = 'Casino',                                 coords = vector4(971.8890, 7.4844, 81.0410, 224.8293),       destCargo = { 'Möbel' } },
    { name = 'Friseursalon Nordstadt',                 coords = vector4(1224.7721, -481.9726, 66.4220, 254.5712),   destCargo = { 'Farben' } },
    { name = 'KFZ Werkstatt Rudi',                     coords = vector4(1064.5686, -784.7833, 58.2627, 352.5960),   destCargo = { 'Fahrzeugteile', 'Öle' } },
    { name = 'Solarzentrum',                           coords = vector4(750.6551, 1301.9348, 360.2965, 131.8380),   sourceCargo = { 'Elektronik', 'Maschinenteile' } },
    { name = 'Movie Park',                             coords = vector4(188.0015, 1243.4708, 225.5953, 275.1788),   destCargo = { 'Elektronik' } },
    { name = 'Bauernhof Meier',                        coords = vector4(-87.4153, 1877.5320, 197.3252, 270.5265),   sourceCargo = { 'Lebensmittel' } },
    { name = 'KFZ Werkstatt Ranjid',                   coords = vector4(262.1628, 2582.1777, 44.9263, 124.4768),    destCargo = { 'Fahrzeugteile', 'Öle' } },
    { name = 'Kieswerk Falkenwalde',                   coords = vector4(283.9247, 2847.5205, 43.6424, 111.1951),    sourceCargo = { 'Baustoffe' } },
    { name = 'Kieswerk Hügeldorf',                     coords = vector4(2677.0366, 2791.0420, 40.5186, 12.6945),    sourceCargo = { 'Baustoffe' } },
    { name = 'Baumarkt Hügeldorf Autobahn',             coords = vector4(2681.4785, 3508.3516, 53.3037, 65.9424),    destCargo = { 'Baustoffe', 'Holz', 'Farben' } },
    { name = 'Tankstelle Hügeldorf Landstraße',         coords = vector4(1359.5720, 3615.3787, 34.8913, 293.8185),   destCargo = { 'Kraftstoff' } },
    { name = 'Holzverarbeitung Hirschweiler',           coords = vector4(-574.4285, 5270.5923, 70.2689, 67.8386),    sourceCargo = { 'Holz' } },
    { name = 'Fahrradvermietung Hirschweiler',          coords = vector4(-769.1369, 5596.4321, 33.6058, 185.0724),   destCargo = { 'Fahrzeugteile' } },
    { name = 'Metzgerei Hirschweiler',                  coords = vector4(-69.7692, 6269.4512, 31.2621, 35.2860),     destCargo = { 'Lebensmittel' } },
    { name = 'Zentrallager Hirschweiler (Tor 1)',       coords = vector4(42.1257, 6299.3848, 31.2294, 189.4753),     sourceCargo = { 'Möbel', 'Elektronik' } },
    { name = 'Tiernahrungszentrum Hirschweiler',        coords = vector4(-55.6003, 6394.8511, 31.4904, 40.4435),     destCargo = { 'Lebensmittel' } },
    { name = 'Zentrallager Hirschweiler (Tor 2)',       coords = vector4(58.0157, 6471.7808, 31.4253, 219.9842),     sourceCargo = { 'Möbel', 'Elektronik', 'Farben' } },
    { name = 'Bauer Manfred Hirschweiler',              coords = vector4(421.6891, 6477.3452, 28.8147, 24.6141),     sourceCargo = { 'Lebensmittel' } },
    { name = 'Bauer Günni Hirschweiler Autobahn',       coords = vector4(2200.6777, 5613.5015, 53.6332, 191.3689),   sourceCargo = { 'Lebensmittel' } },
    { name = 'Bootsanleger Land',                       coords = vector4(3802.1641, 4475.4995, 5.9927, 170.4438),    destCargo = { 'Maschinenteile' } },
    { name = 'Humane Labs Forschungslabor',             coords = vector4(3609.2017, 3731.3088, 29.6894, 326.4201),   destCargo = { 'Chemikalien' } },
    { name = 'Schrottplatz Hügeldorf',                  coords = vector4(2364.2654, 3129.1616, 48.2104, 265.5793),   sourceCargo = { 'Schrott', 'Maschinenteile', 'Fahrzeugteile' } },
    { name = 'Strandpromenade Café',                    coords = vector4(-1793.5090, -1198.1898, 13.0174, 329.9821), destCargo = { 'Lebensmittel' } },
    { name = 'Anlieferung Hafen Walker',                 coords = vector4(-52.2539, -2653.1208, 6.0007, 162.0387),    destCargo = { 'Maschinenteile' } },
    { name = 'Anlieferung Hafen Schiff',                 coords = vector4(-143.1830, -2388.8242, 6.0000, 71.0642),    sourceCargo = { 'Maschinenteile' } },
    { name = 'Anlieferung Hafen Bugstars',               coords = vector4(129.3919, -3084.8677, 5.9009, 76.0289),     destCargo = { 'Elektronik' } },
    { name = 'Anlieferung Hafen U-Boot Halle',           coords = vector4(494.6169, -3167.8530, 6.0696, 194.4470),    destCargo = { 'Maschinenteile' } },
    { name = 'Anlieferung Hafen Containerlager',         coords = vector4(1133.5258, -3069.2036, 5.9010, 167.8817),   destCargo = { 'Möbel' } },
    { name = 'Industriegebäude',                        coords = vector4(820.1056, -2364.1206, 30.2318, 138.0473),   destCargo = { 'Maschinenteile' } },
    { name = 'Schmelze',                                coords = vector4(1084.2832, -1973.7777, 31.0146, 144.1909),  sourceCargo = { 'Maschinenteile' }, destCargo = { 'Schrott' } },
    { name = 'Schlachthof',                             coords = vector4(961.1883, -2106.4451, 31.8275, 254.5108),   sourceCargo = { 'Lebensmittel' } },
    { name = 'Öl Lager',                                coords = vector4(699.9645, -2312.4636, 26.6375, 143.2132),   sourceCargo = { 'Öle' } },
    { name = 'Kraftstofflager',                         coords = vector4(557.3855, -2328.2297, 5.8236, 88.7202),     sourceCargo = { 'Kraftstoff' } },
    { name = 'Gas Lager',                               coords = vector4(-224.5158, -2251.1614, 7.8117, 63.8850),    sourceCargo = { 'Kraftstoff', 'Chemikalien' } },
    { name = 'Flughafen',                               coords = vector4(-946.4362, -2826.4675, 13.9672, 250.9027),  destCargo = { 'Elektronik', 'Maschinenteile' } },
    { name = 'Logistikhandel Platz 12',                 coords = vector4(-1124.8440, -2221.0049, 13.1958, 326.1807), destCargo = { 'Möbel' } },
    { name = 'Logistikhandel Platz 25',                 coords = vector4(-1183.0769, -2147.0903, 13.2526, 320.6503), destCargo = { 'Elektronik' } },
    { name = 'Industriebetrieb',                        coords = vector4(-580.4362, -1589.4342, 26.7511, 254.5801),  destCargo = { 'Maschinenteile' } },
    { name = 'Schrotthof',                              coords = vector4(-498.9285, -1713.7181, 19.8991, 346.7195),  sourceCargo = { 'Schrott' } },
    { name = 'Güterbahnhof',                            coords = vector4(503.7385, -629.3307, 24.7511, 43.7673),     destCargo = { 'Baustoffe', 'Möbel' } },
    { name = 'Umspannwerk',                             coords = vector4(735.7593, 131.9819, 80.7205, 72.7470),      destCargo = { 'Maschinenteile' } },
    { name = 'Tankstelle Neumann',                      coords = vector4(642.4342, 260.3834, 103.2956, 260.9001),    destCargo = { 'Kraftstoff' } },
    { name = 'Tankstelle Klausen',                      coords = vector4(-2059.8032, -304.9529, 13.1621, 282.9346),  destCargo = { 'Kraftstoff' } },
    { name = 'Tankstelle Meier',                        coords = vector4(-341.0958, -1475.3755, 30.7519, 60.6348),   destCargo = { 'Kraftstoff' } },
    { name = 'Tankstelle Schneider',                    coords = vector4(293.8644, -1251.6951, 29.4058, 203.0127),   destCargo = { 'Kraftstoff' } },
    { name = 'Tankstelle Müller',                       coords = vector4(-79.4204, -1756.5078, 29.6349, 236.3690),   destCargo = { 'Kraftstoff' } },
}

-- Wertspanne ($ pro km), aus der zufällig der Auftragswert berechnet wird
-- (Distanz wird automatisch aus den echten Koordinaten der Be-/Entladepunkte
-- berechnet, keine manuelle Streckenpflege mehr nötig).
Config.OrderValuePerKm = { min = 125, max = 200 }

-- Vertragsstrafe (Unternehmensguthaben), wenn ein Fahrer einen Auftrag OHNE
-- Freigabe eines Disponenten selbst abbricht (nur möglich, wenn gerade kein
-- Disponent/Geschäftsführung online ist - sonst muss der Abbruch erst
-- genehmigt werden, siehe Orders.RequestCancelByDriver).
Config.OrderCancelPenalty = 250

-- Wie lange das Be-/Entladen per Tasteninteraktion (E) am Markierungskreis
-- dauert (Sekunden).
Config.LoadUnloadSeconds = 150 -- 2,5 Minuten

-- Ab welcher Entfernung (Meter) der Bodenmarker eines Be-/Entladepunkts
-- überhaupt erst gezeichnet wird (Performance).
Config.LocationMarkerRadius = 60.0
-- Ab welcher Entfernung (Meter) die "Drücke E"-Interaktion angezeigt wird.
Config.LocationInteractRadius = 2.5

-- Durchschnittsgeschwindigkeit (km/h) zur Berechnung der Lieferfrist (Pünktlichkeit)
Config.AverageSpeedKmh = 50

-- Zusätzlicher Puffer in Minuten auf die berechnete Fahrzeit
Config.DeadlineBufferMinutes = 15

-- Automatische Auftragsgenerierung - der Takt hängt von der Anzahl aktuell
-- online UND am Tablet angemeldeten Mitarbeiter mit Fahrerberechtigung
-- ('driver_actions') ab: je mehr Fahrer da sind, um so öfter kommt Nachschub.
-- 'maxDrivers' ist die jeweils OBERE Grenze der Stufe (die erste Stufe, in
-- die die aktuelle Fahreranzahl noch passt, gewinnt) - die letzte Stufe
-- sollte immer 'math.huge' als Obergrenze haben, damit auch bei sehr vielen
-- Fahrern noch ein Takt greift. Sind 0 Fahrer online, wird nichts generiert
-- (niemand könnte den Auftrag ohnehin annehmen).
Config.OrderGeneration = {
    enabled = true,
    maxOpenOrders = 12, -- maximale Anzahl unbearbeiteter (offener) Aufträge im Pool
    intervalMsByDriverCount = {
        { maxDrivers = 2, minMs = 12 * 60 * 1000, maxMs = 15 * 60 * 1000 }, -- 1-2 Fahrer: alle 12-15 Min.
        { maxDrivers = math.huge, minMs = 10 * 60 * 1000, maxMs = 12 * 60 * 1000 }, -- ab 3 Fahrern: alle 10-12 Min.
    },
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
    requiredBreakMinutes = 20,

    -- Maximale Lenkzeit pro Tag.
    maxDailyDrivingMinutes = 660, -- 9 Stunden

    -- Wie viele Minuten vor Erreichen eines Limits eine Warnung erfolgen soll.
    warnBeforeMinutes = 30,

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
Config.MoneyBridge = 'qbcore' -- 'esx' | 'qbcore' | 'custom'

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
-- WEBSITE-SYNC
-- =========================================================
-- Synchronisiert Aufträge/Disposition, Fuhrpark, Fahrerkarte/Lenkzeiten und
-- Mitarbeiterkonten mit der separaten Speditions-Website (Next.js-Repo
-- "spedition-webseite"). Standardmäßig AUS - erst aktivieren, wenn baseUrl
-- und apiKey gesetzt sind (apiKey muss exakt der Website-Umgebungsvariable
-- TABLET_API_KEY entsprechen). Läuft ausschließlich über ausgehende
-- HTTP-Requests (Push per Webhook, Befehle per Polling abgeholt) - der
-- Spielserver muss dafür keinen eingehenden Port öffnen. Siehe
-- server/sv_website_bridge.lua und den README-Abschnitt "Website-Sync".
Config.Website = {
    enabled = true,
    baseUrl = 'https://baltic-freight.de', -- ohne abschließenden Slash
    apiKey = '65edea5d20f5c976fd943d2860dd059f2dd280dde321af18cb2e7056ba7b4334',
    pollIntervalMs = 5000, -- wie oft auf offene Befehle von der Website geprüft wird
    driverHoursReportIntervalMs = 60000, -- wie oft Lenkzeiten an die Website gemeldet werden
}

-- =========================================================
-- LOGGING
-- =========================================================
Config.Debug = false
