# speditions-tablet

Standalone FiveM-Ressource für ein vollständiges Speditions-Tablet: Fahrer-,
Disponenten- und Fuhrparkmanagement inklusive Unternehmensfinanzen, Auszahlungen
und Aktivitätsprotokoll. Kein Framework (ESX/QBCore) erforderlich - Rollen und
Berechtigungen werden vollständig serverseitig über eine eigene Datenbank
verwaltet.

## Voraussetzungen

- [oxmysql](https://github.com/overextended/oxmysql)
- MySQL/MariaDB-Datenbank
- Optional: [pma-voice](https://github.com/AvarianKnight/pma-voice) für die
  App "Funk" (siehe unten) - ohne pma-voice bleibt die App bedienbar, hat
  aber keine echte Audio-Wirkung.

## Installation

1. Ressource nach `resources/[speditions]/speditions-tablet` kopieren.
2. `sql/install.sql` einmalig in die Datenbank importieren - legt das
   komplette, aktuelle Schema an (alle Tabellen/Spalten dieser Version in
   einem Rutsch, keine schrittweisen Upgrade-Skripte mehr nötig).
3. In `server.cfg`:
   ```
   ensure oxmysql
   ensure speditions-tablet
   ```
4. `config.lua` anpassen (siehe unten) - insbesondere `Config.CompanyName`.
   Standorte werden nicht mehr in `config.lua` gepflegt, sondern im Tablet
   selbst über den Reiter "Orte" (siehe unten) - `Config.SeedLocations`
   dient nur der Erstbefüllung.
5. Server starten.

## Mitarbeiter anmelden (Tablet-eigenes Login)

Das Tablet hat ein **eigenes Login** (Name + Passwort), unabhängig vom
FiveM-Charakter. Öffnet ein Mitarbeiter das Tablet, erscheint nach dem
Sperrbildschirm ein Anmeldeformular - erst nach erfolgreichem Login mit
gültigem Login-Namen und Passwort sieht er die eigentliche Oberfläche.
Anmeldedaten werden ausschließlich serverseitig geprüft
(`server/sv_bootstrap.lua`, `Employees.Login`); das Passwort wird gehasht
(`SHA2` mit individuellem Salt) gespeichert, nie im Klartext. Die Sitzung
gilt nur für den aktuellen Server-Slot und endet automatisch beim
Verlassen des Servers oder über den Konto-Chip oben rechts ("Abmelden").

**Erstkonto:** Beim allerersten Ressourcenstart wird automatisch das erste
Konto aus `Config.InitialAccounts` angelegt (Standard: Login-Name `admin`,
Passwort `ChangeMe123!`, Rolle Geschäftsführung) - **dieses Passwort sofort
nach der ersten Anmeldung über den Konto-Chip ändern!**

**Weitere Mitarbeiter einstellen** - über das Tablet: Geschäftsführung →
Tab **Mitarbeiter** → "+ Mitarbeiter einstellen" (Anzeigename, Login-Name
und Passwort werden dabei direkt vergeben, die Zielperson muss dafür
nicht online sein). Im selben Formular lassen sich direkt die
**Führerscheinklassen** (`Config.DriverPermissions`) ankreuzen - unabhängig
von der gewählten Rolle, harmlos falls diese Rolle gar keine Fahrerakte
anlegt. Nachträglich änderbar bleiben sie wie bisher über die Fahrerakte
(Tab Mitarbeiter → Akte öffnen). Ein Passwort vergessen? Geschäftsführung
kann es über den Button "Passwort zurücksetzen" in derselben Übersicht neu
setzen.

**Alternative über die Server-Konsole** (auch nutzbar mit der
Ace-Permission `speditions.admin`, Zielperson muss NICHT online sein):
```
tablet_grant [name] [passwort] [fahrer|disponent|geschaeftsfuehrung] [Anzeigename...]
```
Legt ein neues Mitarbeiterkonto mit diesem Login-Namen/Passwort/Rolle an
oder aktualisiert Passwort/Rolle, falls der Login-Name bereits existiert.

## Bedienung

- `/tablet` (Standard-Keybind `F6`, in den Keybindings des Spielers
  änderbar) öffnet/schließt das Tablet - **außer** `Config.RequireItem.enabled`
  ist aktiv (siehe unten), dann ist der Command/Keybind deaktiviert.
- Andere Ressourcen können das Tablet auch selbst öffnen, z.B. aus einem
  Inventar-Item-Handler:
  ```lua
  exports['speditions-tablet']:OpenTablet()
  ```
- Solange das Tablet geöffnet ist, hält der Spieler es sichtbar in der Hand
  (`Config.TabletProp`, Standard-Modell `prop_cs_tablet`) - rein optisch,
  ohne Bewegungseinschränkung. Modell/Position/Rotation sind über
  `Config.TabletProp` in `config.lua` anpassbar.
- Die Oberfläche verwendet bewusst **keine Emojis** - App-Icons,
  Warnhinweise (z.B. Gefahrgut) und Statusanzeigen (z.B. Fahrerberechtigungen)
  kommen ausschließlich über Text, Farbe und einfache Liniensymbole (kein
  externer Font/CDN) statt über Symbolzeichen, für ein einheitlicheres,
  seriöseres Erscheinungsbild.

### Navigation: Startbildschirm, Dock + Apps (statt Seitenleiste)

Seit v1.11.0 gibt es keine feste Seitenleiste mit allen Reitern mehr,
sondern ein klassisches, an iPad/iOS angelehntes Tablet-Menü:

1. Nach dem Anmelden landet man immer zuerst auf dem **Startbildschirm** mit
   den Kategorie-Kacheln, für die man mindestens eine Berechtigung hat:
   **Aufträge, Finanzen, Fuhrpark, Mitarbeiterverwaltung, Kommunikation,
   Geschäftsführung** - sowie den beiden eigenständigen Kacheln
   **Disposition** und **Funk** (siehe Punkt 7).
2. Ein Tipp auf eine Kategorie öffnet ein Kachel-Menü mit den einzelnen Apps
   darin. Mehrere eng verwandte frühere Einzel-Apps sind zu jeweils einer App
   mit einer **linken Hover-Leiste** zusammengelegt (unsichtbar bis man mit
   der Maus hinüberfährt, dann klappt sie zur Liste der Abschnitte auf -
   dasselbe `.hover-rail`-Bauteil wie die App-Wechsel-Leiste der Disposition,
   s. u.), statt für jede Kleinigkeit eine eigene Kachel zu brauchen:
   - **Meine Aufträge** (Fahrer): Aktuell / Historie
   - **Finanzcenter** (Geschäftsführung): Übersicht / Umsatz / Finanzen /
     Gehälter / Ein-Auszahlungen
   - **Fuhrpark-Verwaltung**: Fahrzeuge / Anhänger
   - **Mitarbeiter**: Mitarbeiter / Rollen
3. Ein Tipp auf eine App öffnet sie wie gewohnt - Inhalte/Funktionen sind
   unverändert, nur der Weg dorthin hat sich geändert. Der Button
   "‹ Zurück" führt zur Kategorie zurück. Einen "Startbildschirm"-Button gibt
   es nicht mehr oben in der Kopfzeile - stattdessen sitzt unten am
   Bildschirmrand eine dezente, vom iPhone/iPad bekannte Leiste (immer
   sichtbar, nicht erst per Hover), die von überall aus direkt zum
   Startbildschirm führt.
4. Welche Kategorien/Apps/Sektionen sichtbar sind, richtet sich weiterhin
   ausschließlich nach den Berechtigungen der eigenen Rolle (siehe
   "Rollen & Berechtigungen" unten) - jede Sektion einer zusammengelegten App
   behält ihre bisherige Einzel-Berechtigung. Die Kachel **Disposition**
   (Punkt 7) ist die einzige Ausnahme: sie ist für jeden angemeldeten
   Mitarbeiter antippbar, prüft die Berechtigung `dispatch` aber erst beim
   Öffnen und zeigt ohne sie den Hinweis "Keine Berechtigung für diese App."
   statt die Kachel unsichtbar zu machen.
5. Die frühere eigenständige "Fahrerakten"-App ist entfallen - ein
   "Fahrerakte"-Button erscheint jetzt direkt in der Zeile eines Fahrers in
   der App **Mitarbeiter** (Kategorie Mitarbeiterverwaltung).
6. **Dock**: Die Fahrerkarte (Fahrer) liegt als eigenes Icon in einem Dock
   unten auf dem Startbildschirm (analog zum iPad-Dock), statt als
   Kategorie-App - ein "bin ich gerade im Dienst"-Schalter mit Status-Punkt
   (grün = eingesteckt), kein eigentlicher Arbeitsbereich. Der frühere
   Dispositions-Dienst-Dock-Eintrag sitzt jetzt als Toggle direkt in der
   Kopfzeile der App **Disposition** (siehe Punkt 7) statt separat im Dock.
7. **Disposition** (eigene Kachel, kein Kategorie-Untermenü) ist die
   zentrale Arbeitsfläche für Disponenten/Geschäftsführung - siehe eigener
   Abschnitt "Disposition" weiter unten. **Live Karte** und **Nachrichten**
   bleiben eigene Vollbild-Apps in der Kategorie **Kommunikation**, sind aber
   auch direkt aus der Disposition-Kopfzeile per Link erreichbar. Die App
   **"Funk"** (für jeden angemeldeten Mitarbeiter, siehe eigener Abschnitt
   "Funk" weiter unten) liegt ebenfalls als eigene Kachel direkt auf dem
   Startbildschirm - eine eigene Bedienoberfläche mit Kanalwahl,
   Lautstärkeregler, Teilnehmerliste und Anrufen braucht Platz für sich.
8. **Wallpaper + Logo inklusive**: Homescreen, Kategorie-Bildschirm sowie
   Lock- und Login-Screen zeigen ein Hintergrundbild
   (`html/img/wallpaper.jpg`) und das Firmenlogo (`html/img/logo.png`,
   transparenter Hintergrund) - beides bereits mit Baltic-Freight-Branding
   befüllt. Eigenes Motiv/Logo gewünscht? Einfach die jeweilige Datei
   überschreiben (siehe `html/img/WALLPAPER_HIER_ABLEGEN.txt`, empfohlenes
   Wallpaper-Format ca. 2048×1330px/Seitenverhältnis 3:2) - löschst du
   `wallpaper.jpg` komplett, bleibt der dunkle Verlaufshintergrund sichtbar.
   Der Login-Bildschirm (Name + Passwort) ist dazu als transluzente
   Glas-Karte gestaltet.
9. **Widgets**: Fahrer sehen auf dem Startbildschirm drei kompakte Widgets,
   die zur jeweiligen App verlinken - unter der Uhrzeit den "Aktuellen
   Auftrag" (Fracht, Strecke, Status, sofern einer läuft), rechts oben die
   "Fahrerkarte" (eingesteckt/nicht eingesteckt) und direkt darunter "Mein
   Fahrzeug" (Name/Modell, Kennzeichen, Status, Tankstand). Damit sich die
   Kategorie-/App-Kacheln nie mit diesen rechts positionierten Widgets
   überschneiden, stehen sie links in einem festen Raster mit maximal 4
   Kacheln pro Reihe (statt bildschirmfüllend), auch wenn weitere Kategorien
   dazukommen.

Alle folgenden Abschnitte dieses READMEs sprechen aus historischen Gründen
teils weiterhin von "Reitern" - gemeint ist damit jeweils die entsprechende
App (bzw. Sektion einer zusammengelegten App) im Kategorie-Menü.

### Tablet nur per Item öffnen

`Config.RequireItem = { enabled = true, itemName = 'tablet_baltic' }` deaktiviert
den freien Command/Keybind komplett - das Tablet öffnet sich dann nur noch,
wenn das konfigurierte Item benutzt wird:
- Mit **ESX** oder **QBCore** passiert das automatisch (`server/sv_main.lua`
  erkennt beim Ressourcenstart, welches der beiden Frameworks läuft, und
  registriert das Item entsprechend über `ESX.RegisterUsableItem` bzw.
  `QBCore.Functions.CreateUseableItem`) - unabhängig von `Config.MoneyBridge`.
  Das Item muss in deinem Inventarsystem (z.B. `qb-core`/`ox_inventory`
  `items.lua`) natürlich bereits existieren.
- Mit einem reinen Inventarsystem ohne eines der beiden Frameworks
  (z.B. ox_inventory standalone) lässt du dein eigenes Item-Skript beim
  Gebrauch selbst `TriggerEvent('speditions-tablet:server:openFromItem')`
  (server-seitig, `source` = der Spieler) feuern.

### Bargeld bei Aus-/Einzahlung

`Config.MoneyBridge = 'esx' | 'qbcore' | 'custom'` (Standard: `'qbcore'`):
Führt die Geschäftsführung eine **Auszahlung** durch, bekommt sie den Betrag
als echtes Bargeld in die Hand. Damit das nicht zur Geldvermehrung
missbraucht werden kann, zieht eine **Einzahlung** ihr symmetrisch echtes
Bargeld ab (schlägt fehl, wenn nicht genug Bargeld vorhanden ist -
`insufficient_player_cash`). Bei `'custom'` (oder wenn das gewählte
Framework nicht gefunden wird) werden nur die Events
`speditions-tablet:server:cashPayout` / `-cashDeposit` gefeuert, die du in
deinem eigenen Wirtschaftsskript abfangen kannst - `server/sv_bridge.lua`.

**Fehlerdiagnose "Gehalt/Auszahlung kommt nicht an":** `server/sv_bridge.lua`
prüft bei `Config.MoneyBridge = 'qbcore'`/`'esx'` jetzt explizit, ob das
Framework-Objekt bzw. der Spieler-Objekt gefunden wird, und fängt Fehler aus
`AddMoney`/`addMoney` ab - der genaue Grund landet als deutliche `^1`-Zeile
in der Server-Konsole (z.B. "qb-core wurde nicht gefunden - läuft die
Ressource ... auf diesem Server?"). Die Buchung selbst (Guthaben abziehen,
als bezahlt markieren) läuft weiterhin unabhängig davon durch - schlägt die
Bargeldübergabe fehl, erscheint im Tablet jetzt ein deutlicher Fehler-Toast
statt eines leicht übersehbaren Info-Hinweises. Prüfe bei Problemen: läuft
`qb-core` (oder ein Fork wie `qbx_core`) tatsächlich unter genau diesem
Ressourcennamen, und ist der Mitarbeiter beim Auszahlen online/eingeloggt?

### Fahrzeugstand vor der Abmeldung

Hat ein Fahrer beim Abmelden (Button oben im Tablet) ein Fahrzeug
zugewiesen, muss er zuerst Tankstand und ggf. Mängel/Besonderheiten melden
(optional mit Häkchen "Werkstatt erforderlich", setzt den Fahrzeugstatus
automatisch auf "Wartung"). Ohne zugewiesenes Fahrzeug meldet er sich direkt
ab. Siehe `Vehicles.ReportCondition` in `server/sv_vehicles.lua`.

### Disposition (zentrale Arbeitsfläche)

Die Kachel **"Disposition"** (Startbildschirm, kein Kategorie-Untermenü -
siehe "Navigation" oben) ist eine einzige, zusammenhängende Arbeitsfläche mit
drei gleichzeitig sichtbaren Spalten statt der früheren getrennten Apps
"Auftragsverwaltung" (Pool/Aktiv/Abgeschlossen-Tabs) und "Fahrerübersicht":

- **Offene Aufträge** (links): automatisch generierte, noch nicht
  zugewiesene Aufträge mit Strecke, Fracht, Wert und Gefahrgut-Kennzeichnung.
- **Fuhrpark** (Mitte): alle aktiven Fahrer mit Status (verfügbar/im
  Einsatz/Pause/offline), zugewiesenem Fahrzeug samt Fahrzeugstatus und -
  sofern gerade im Einsatz - Fracht/Menge und Strecke des laufenden
  Auftrags.
- **Zugewiesen / Laufend** (rechts): alle disponierten und laufenden
  Aufträge mit Fahrer, Fahrzeug, Status und offenen Abbruch-Anfragen.

**Zuweisen per Ziehen:** eine Auftragskarte aus "Offene Aufträge" (oder zum
Neu-Zuweisen eine Karte aus "Zugewiesen / Laufend", solange ihr Status das
erlaubt) wird auf eine Fuhrpark-Karte gezogen. Während des Ziehens hebt sich
ein gültiges Ziel grün hervor (passende Berechtigung z.B. bei Gefahrgut, bei
einer Neuzuweisung beliebiger Status, sonst nur "verfügbare" Fahrer), ein
ungültiges Ziel wird sichtbar abgeblendet und nimmt die Karte nicht an. Ein
Loslassen auf einem gültigen Ziel öffnet eine kurze Bestätigung ("Auftrag XY
an Fahrer Z zuweisen?") - erst danach wird tatsächlich disponiert, ein
versehentliches Fallenlassen löst also nichts aus. Wer lieber ohne Ziehen
arbeitet, findet an jeder Auftragskarte weiterhin einen "Zuweisen"/"Neu
zuweisen"-Button mit Dropdown-Auswahl.

**Technisch bewusst ohne natives HTML5-Drag&Drop** (`draggable`/`dragstart`/
`dragover`/`drop`): FiveMs NUI ist ein off-screen gerendertes CEF, dessen
Pipeline die native Drag-Interaktion des Betriebssystems nicht abbildet - in
der Praxis bleibt dabei dauerhaft der "Verboten"-Cursor stehen und `drop()`
feuert nicht zuverlässig. Das Ziehen läuft stattdessen über normale
Zeigereignisse (`pointerdown`/`pointermove`/`pointerup`) mit einem von Hand
mitgeführten Ghost-Element - funktioniert wie jede gewöhnliche Mausbewegung
und damit auch zuverlässig im Spiel-NUI.

**Kurz-Wechsel zwischen den Disponenten-Apps:** an der linken Kante des
Inhaltsbereichs sitzt eine schmale Hover-Leiste (kaum sichtbar, bis man mit
der Maus hinüberfährt) - sie klappt dann zu einer Liste mit **Disposition**,
**Live-Karte**, **Nachrichten** und **Funk** auf. Ein Klick darauf wechselt
direkt in die jeweilige App, ohne den Umweg über den Startbildschirm. Die
Leiste erscheint nur, solange eine dieser vier Apps offen ist. Die
Kopfzeile der Disposition selbst enthält daneben den **Dispositions-Dienst-
Toggle** (früher ein eigenes Dock-Icon) sowie einen Link zum Auftrags-
**Verlauf** (abgeschlossene/abgebrochene/abgelehnte Aufträge).

### Dispositions-Dienst & Auftrags-Selbstzuweisung ohne Disponent

Ein bloß am Tablet angemeldeter Disponent/Geschäftsführung reicht **nicht**
aus, um die Selbstzuweisung zu sperren - der Dispositions-Dienst muss dafür
über den **Dienst-Toggle in der Kopfzeile der App "Disposition"** über den
Button "Dienst beginnen" aktiv eingeschaltet sein (analog zur Fahrerkarte
bei Fahrern, die im Dock liegt). Solange niemand im Dienst ist, können Fahrer sich einen
offenen Auftrag im "Offener Auftragspool"-Bereich unter "Aufträge" selbst
zuweisen ("Übernehmen"). Sobald mindestens ein Disponent "Dienst beginnen"
gedrückt hat, wird der Button gesperrt und die normale Disposition greift
wieder - bis "Dienst beenden" gedrückt wird oder der Disponent den Server
verlässt (automatisches Beenden bei Verbindungsabbruch). Siehe
`server/sv_dispatch_shift.lua` (`Dispatch.StartDuty`/`EndDuty`) und
`Orders.SelfAssign`/`isDispatcherAvailable` in `server/sv_orders.lua`.

**Bestandsinstallationen:** die neuen Spalten `dispatch_on_duty`/
`dispatch_shift_started_at` auf `st_employees` werden nur bei einer
komplett frischen Installation automatisch aus `sql/install.sql` angelegt.
Läuft euer Server schon länger, einmalig folgendes SQL gegen eure
Datenbank ausführen, bevor ihr die neue Ressourcenversion startet:
```sql
ALTER TABLE `st_employees`
    ADD COLUMN `dispatch_on_duty` TINYINT(1) NOT NULL DEFAULT 0 AFTER `status`,
    ADD COLUMN `dispatch_shift_started_at` DATETIME NULL AFTER `dispatch_on_duty`;
```

## Rollen & Berechtigungen

Alle sicherheitsrelevanten Aktionen (Rollenprüfung, Auftragsstatus,
Auszahlungen, Fahrzeugverwaltung, Guthabenänderungen) werden **ausschließlich
serverseitig** validiert (`server/*.lua`). Die NUI kann keine Werte wie
Auszahlungsbeträge oder "Auftrag abgeschlossen" selbst setzen.

Rollen sind **frei anlegbar**: die Geschäftsführung kann im Tablet unter dem
Reiter **Rollen** (Berechtigung `roles_manage`) eigene, beliebig benannte
Rollen anlegen und ihnen eine beliebige Auswahl an Einzelberechtigungen aus
folgendem Katalog zuweisen (`Config.Permissions` in `config.lua`,
serverseitig durchgesetzt in `server/sv_roles.lua`):

| Berechtigung | Bedeutung |
|---|---|
| `driver_actions` | Fahrerfunktionen (Aufträge fahren, Fahrerkarte, eigene Statistik, Nachrichten empfangen) |
| `dispatch` | Disposition (zentrale Arbeitsfläche: Auftragspool disponieren, Fuhrpark/Fahrer-Übersicht, Fahrer kontaktieren, Umsatzübersicht) |
| `fleet_manage` | Fuhrparkverwaltung (Fahrzeuge anlegen/bearbeiten/löschen/zuweisen) UND Anhängerverwaltung (Reiter "Anhänger": anlegen/bearbeiten/löschen/an-/umkuppeln) |
| `locations_manage` | Orte verwalten (Reiter "Orte": Be-/Entladepunkte anlegen/bearbeiten/löschen) |
| `employees_manage` | Mitarbeiterverwaltung (einstellen, Rolle/Status ändern, Passwörter zurücksetzen, Fahrerakten) |
| `roles_manage` | Rollen & Berechtigungen verwalten |
| `finance_view` | Finanzen einsehen (Umsatz, Transaktionen, Aus-/Einzahlungshistorie) |
| `finance_payout` | Aus-/Einzahlungen durchführen |
| `wages_manage` | Gehälter/Stundenlöhne verwalten & auszahlen |
| `activity_log_view` | Aktivitätsprotokoll einsehen |
| `stats_view` | Übersicht/Statistik-Dashboard einsehen |
| `console_view` | Fehler-Konsole einsehen (Reiter "Konsole": RPC-/Datenbankfehler, siehe `server/sv_console.lua`) |

Die drei mitgelieferten Basisrollen (LKW-Fahrer, Disponent, Geschäftsführung,
Rollenschlüssel fix - u.a. für die automatische Fahrerakten-Anlage relevant)
starten mit der bisherigen Rechteverteilung als `Config.DefaultRolePermissions`
(nur einmalige Erstbefüllung, danach ist `st_roles` die Quelle der Wahrheit -
die Geschäftsführung kann auch ihre Berechtigungen im Tablet anpassen):

| Basisrolle | Berechtigungen |
|---|---|
| LKW-Fahrer | `driver_actions` |
| Disponent | `dispatch` |
| Geschäftsführung | alle, inkl. `driver_actions` (die GF kann alles, was auch ein Fahrer kann) |

**Bestandsinstallationen:** `Config.DefaultRolePermissions` wirkt nur bei der
allerersten Anlage einer Rolle - existiert die Rolle "Geschäftsführung" in
deiner Datenbank schon, bekommt sie weder `driver_actions` noch (seit
v1.10.6) `console_view` automatisch nachgetragen. Öffne dafür einmalig den
Reiter "Rollen", wähle Geschäftsführung und hake die fehlende(n)
Berechtigung(en) mit an - sonst taucht z.B. der neue Reiter "Konsole" trotz
aktualisiertem Code nicht auf.

Welche Reiter im Tablet sichtbar sind, richtet sich ausschließlich nach den
Berechtigungen der eigenen Rolle (`html/js/app.js`, `NAV_ITEMS`) - eine
eigene Rolle mit z.B. `dispatch` UND `driver_actions` sieht entsprechend
sowohl die Fahrer- als auch die Disponenten-Reiter. Serverseitig wird bei
**jeder** Aktion unabhängig von der NUI erneut geprüft
(`Employees.RequirePermission`) - die Anzeige der Reiter ist reine
Bequemlichkeit, kein Sicherheitsmechanismus.

**Schutz vor Selbstaussperrung:** Die letzte aktive Person mit der
Berechtigung `employees_manage` kann nicht in eine Rolle ohne diese
Berechtigung verschoben oder deaktiviert werden; ebenso kann `roles_manage`
nicht aus der letzten Rolle entfernt werden, der noch aktive Mitarbeiter
zugeordnet sind. Als Notfall-Zugang bleibt immer `tablet_grant` über die
Server-Konsole (s.o.).

Alle Aktionen der Geschäftsführung sowie sicherheitsrelevante Systemereignisse
werden in `st_activity_logs` protokolliert und sind nur mit der Berechtigung
`activity_log_view` einsehbar (Tab **Protokoll**).

## Wichtiges Prinzip: Fahrer-Einnahmen & Ein-/Auszahlungen

Abgeschlossene Aufträge erzeugen **Einnahmen für das Unternehmen**, nicht für
den Fahrer persönlich. Jede Einnahme, jede Auszahlung und jede Einzahlung
wird als eigene, unveränderliche Transaktion in `st_transactions` gespeichert
- es wird niemals nur ein Kontostand überschrieben. Nur die Geschäftsführung
kann über den Tab **Ein-/Auszahlungen**:
- **Einzahlen**: Guthaben von außen ins Unternehmenskonto verbuchen (Betrag,
  Herkunft, Grund) - z.B. eine Kapitaleinlage. Erhöht das Guthaben sofort und
  wird protokolliert (`st_deposits`).
- **Auszahlen**: Unternehmensguthaben auszahlen. Der Betrag wird dabei
  serverseitig gegen das tatsächliche Guthaben geprüft (`st_payouts`).

Beide Aktionen sind reine Buchungsvorgänge im internen Ledger - es findet
keine automatische Übertragung von echtem Spielergeld statt (keine
Framework-Anbindung in diesem Standalone-Setup).

## Lenk- und Ruhezeiten, Wegpunkte, Gefahrgut

- **Lenk-/Ruhezeiten**: Ein Fahrer "fährt" im Sinne des Systems, sobald er auf
  dem Fahrersitz eines Fahrzeugs sitzt, dessen **Kennzeichen mit dem in der
  Fuhrparkverwaltung hinterlegten Kennzeichen seines zugewiesenen Fahrzeugs
  übereinstimmt** (`client/cl_hours.lua`, Abgleich per
  `GetVehicleNumberPlateText`). Das bedeutet: Das Fahrzeug-Spawn-/Garagen-Skript
  deines Servers muss beim Ausgeben des LKWs `SetVehicleNumberPlateText` auf
  genau den Wert setzen, der im Fuhrpark als Kennzeichen hinterlegt ist.
  GTA-Kennzeichen sind auf **8 Zeichen** begrenzt - nutze für reale Fahrzeuge
  entsprechend kurze Kennzeichen (die Beispielwerte wie "HH-TR 420" in diesem
  README sind reine Anzeigebeispiele und müssten für ein echtes Fahrzeug
  gekürzt werden, z.B. "HHTR420").
  Grenzwerte (ununterbrochene Lenkzeit, Pausendauer, Tageslenkzeit,
  Warnvorlauf) stehen in `Config.DrivingRules`. Bei Überschreitung erhält der
  Fahrer eine native In-Game-Benachrichtigung (funktioniert auch bei
  geschlossenem Tablet); der Disponent kann Fahrer zusätzlich aktiv über den
  Button **"Lenkzeit erinnern"** an einer Fuhrpark-Karte in der Disposition erinnern.
  **Zwei Voraussetzungen, ohne die sich die Lenkzeit NICHT ändert:** (1) die
  Fahrerkarte muss im Reiter "Fahrerkarte" eingesteckt sein (`on_shift` in
  `st_drivers`) - nur das Sitzen im richtigen Fahrzeug reicht seit diesem
  Update nicht mehr aus; (2) dem Fahrer muss ein Fahrzeug zugewiesen sein -
  das passiert seit dem Selbstauswahl-Feature (siehe unten) automatisch beim
  Einstecken der Fahrerkarte. Fehlt (2) trotzdem (z.B. weil die
  Geschäftsführung die Zuweisung nachträglich im Fuhrpark aufgehoben hat),
  erscheint ein In-Game-Warnhinweis ("Dir ist noch kein Fahrzeug zugewiesen
  ..."), statt
  dass die Zähler kommentarlos bei 0 bleiben (`client/cl_hours.lua`).
- **Bugfix: manueller Status "Pause" setzte Lenkzeit nicht zurück**: Der
  Status-Dropdown in der Fahrerkarte (`current_status` - "Verfügbar/Im
  Einsatz/Pause") war bisher komplett unabhängig von der Lenk-/Ruhezeiten-
  Erfassung. Wer manuell auf "Pause" wechselte, ohne dabei tatsächlich aus
  dem zugewiesenen Fahrzeug auszusteigen, hatte also nie einen `resting_since`-
  Zeitstempel gesetzt - die ununterbrochene Lenkzeit lief dadurch nie ab und
  wurde nie zurückgesetzt, egal wie lange "Pause" aktiv war. `Drivers.SetStatus`
  (`server/sv_drivers.lua`) ruft beim Wechsel auf "Pause" jetzt zusätzlich
  `Hours.RestStart()` auf (idempotent, wie beim automatischen Aussteigen aus
  dem Fahrzeug) - die Lenkzeit setzt sich damit nach der konfigurierten
  Mindestpause (`Config.DrivingRules.requiredBreakMinutes`, aktuell **10
  Minuten**) auch bei manuell gesetzter Pause zuverlässig zurück.
- **Automatische Wegpunkte**: Beim Annehmen eines Auftrags wird automatisch
  ein GPS-Wegpunkt zum Beladepunkt gesetzt, beim Losfahren (Statuswechsel auf
  "Unterwegs") automatisch einer zum Zielort. Die Koordinaten kommen aus den
  im Tablet gepflegten Orten (siehe "Orte" unten).

### Orte (Reiter "Orte")

Standorte liegen nicht mehr fest in `config.lua`, sondern in der Datenbank
(`st_locations`) und werden von der Geschäftsführung (Berechtigung
`locations_manage`) direkt im Tablet über den Reiter **"Orte"** gepflegt:
anlegen, bearbeiten, löschen. Beim Anlegen/Bearbeiten füllt der Button
**"Aktuelle Position übernehmen"** die Koordinaten- und Blickrichtungsfelder
automatisch mit der aktuellen Spielerposition (serverseitig ermittelt, kein
Hinlaufen zu exakten Zahlen nötig).

`Config.SeedLocations` in `config.lua` enthält die mitgelieferten 59
Standardstandorte (echte Firmenadressen des Servers) und dient **nur** der
einmaligen Erstbefüllung beim allerersten Ressourcenstart - danach ist
ausschließlich die Datenbank die Quelle der Wahrheit; Änderungen an
`Config.SeedLocations` nach der Erstbefüllung haben keine Wirkung mehr,
Orte müssen dann über den Reiter "Orte" gepflegt werden.

**Alte/veraltete Orte auf der Website:** Wurde `st_locations` schon VOR der
finalen 59-Orte-Liste befüllt (z.B. mit Platzhalternamen während der
Entwicklung), bleiben diese alten Einträge zusätzlich zu den neuen echten
Orten stehen - die Erstbefüllung überschreibt nur Namensgleiche, entfernt
aber nie andere Namen. Einmalig folgendes SQL ausführen (leert
`st_locations` komplett - eigene, im Tablet nachträglich angelegte Orte
gehen dabei mit verloren)
```sql
DELETE FROM `st_locations`;
ALTER TABLE `st_locations` AUTO_INCREMENT = 1;
```
und die Ressource neu starten, danach wird automatisch sauber aus
`Config.SeedLocations` neu befüllt und über `locations.sync` an die
Website gemeldet.

Jeder Ort trägt Frachtarten-Tags (Quelle = hier abholbare Fracht, Ziel = hier
anlieferbare Fracht); die automatische Auftragsgenerierung wählt nur
Frachtarten, für die es mindestens einen passenden Start- **und**
Zielstandort gibt, und berechnet Distanz/Wert aus der echten
Luftlinienentfernung der Koordinaten. Wird ein Ort gelöscht, der noch als
Start-/Zielpunkt eines offenen Auftrags referenziert ist, bleibt der Auftrag
bestehen - nur Wegpunkt/Bodenmarker lassen sich für ihn dann nicht mehr
auflösen (kein Fehler, der Auftrag lässt sich weiterhin normal abschließen).

### Frachtarten (Reiter "Frachtarten")

Frachtarten liegen ebenfalls nicht mehr fest in `config.lua`, sondern in der
Datenbank (`st_cargo_types`) und werden von der Geschäftsführung
(Berechtigung `cargo_types_manage`) direkt im Tablet über den Reiter
**"Frachtarten"** gepflegt: anlegen, bearbeiten, löschen. Je Frachtart wird
festgelegt:

- **Name** - wie die Fracht in Auftragspool/Lieferschein/Ortsverwaltung heißt.
- **Einheit** und **Menge min./max.** - bestimmt die zufällige Stückzahl/
  Menge, die beim Generieren eines Auftrags auf dem Lieferschein steht
  (z.B. "1.200 Liter").
- **Gefahrgut** - ist das Häkchen gesetzt, erzeugt die Frachtart Aufträge mit
  `requires_permission = 'gefahrgut'` (siehe Gefahrgut-Zugriffsbeschränkung
  unten).
- **Benötigter Anhängertyp** - legt fest, welcher Anhängertyp (siehe Reiter
  "Anhänger" unten) am Fahrzeug angekuppelt sein muss, damit ein Auftrag
  dieser Frachtart disponiert/selbst angenommen werden kann.

`Config.SeedCargoTypes` in `config.lua` enthält die mitgelieferten 14
Standard-Frachtarten und dient **nur** der einmaligen Erstbefüllung beim
allerersten Ressourcenstart - danach ist ausschließlich die Datenbank die
Quelle der Wahrheit; Änderungen an `Config.SeedCargoTypes` nach der
Erstbefüllung haben keine Wirkung mehr, Frachtarten müssen dann über den
Reiter "Frachtarten" gepflegt werden.

**Bestandsinstallationen (Server, die schon vor diesem Update liefen):** Die
neue Tabelle `st_cargo_types` wird nur bei einer komplett frischen
Installation automatisch aus `sql/install.sql` angelegt. Läuft euer Server
schon länger, einmalig folgendes SQL gegen eure Datenbank ausführen, bevor
ihr die neue Ressourcenversion startet:
```sql
CREATE TABLE IF NOT EXISTS `st_cargo_types` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `unit` VARCHAR(50) NOT NULL,
    `min_amount` INT UNSIGNED NOT NULL DEFAULT 1,
    `max_amount` INT UNSIGNED NOT NULL DEFAULT 1,
    `hazardous` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `trailer_type` ENUM('curtainsider','curtainsider_gefahrgut','kipper','kuehlanhaenger','tankanhaenger') NOT NULL DEFAULT 'curtainsider',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_cargo_type_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
Danach die Ressource neu starten - `st_cargo_types` wird beim ersten Start
automatisch aus `Config.SeedCargoTypes` mit den bisherigen 14 Frachtarten
befüllt (exakt dieselben Werte, die vorher in `Config.CargoTypes`/
`CargoUnits`/`HazardousCargo`/`CargoTrailerType` standen), danach steht euch
der Reiter "Frachtarten" zur Pflege zur Verfügung.

Wird eine Frachtart gelöscht, die noch von einem offenen Auftrag referenziert
wird, bleibt der Auftrag bestehen - für neue, automatisch generierte
Aufträge steht die gelöschte Frachtart danach einfach nicht mehr zur Auswahl.

### Anhänger (Reiter "Anhänger")

Fünf Anhängertypen (`Config.TrailerTypes`): Curtainsider, Curtainsider mit
Gefahrgutzulassung, Kipper, Kühlanhänger, Tankanhänger. Im Reiter
**"Anhänger"** (Berechtigung `fleet_manage`, wie der Fuhrpark) legt die
Geschäftsführung Anhänger an und kuppelt sie über "Ankuppeln"/"Umkuppeln" an
ein Fahrzeug - ein Anhänger kann nur an einem Fahrzeug gleichzeitig hängen,
das Ankuppeln an ein neues Fahrzeug kuppelt automatisch vom vorherigen ab.
Die Fuhrpark-Tabelle zeigt in der Spalte "Anhänger" den aktuell angekuppelten
Anhänger pro LKW. Fahrer können sich beim Fahrerkarte-Einstecken auch selbst
einen freien Anhänger ankuppeln (siehe "Fahrerkarte einstecken vor
Auftragsannahme" unten) - die GF-Verwaltung hier bleibt parallel als
manuelle Vorab-/Korrekturmöglichkeit bestehen.

Jede Frachtart verlangt (je nach im Reiter "Frachtarten" hinterlegtem
Anhängertyp) einen bestimmten Anhängertyp (Gefahrgut → Curtainsider mit Gefahrgutzulassung,
Lebensmittel/Kühlware → Kühlanhänger, Schüttgut wie Baustoffe/Schrott →
Kipper, Flüssigfracht wie Öl/Kraftstoff → Tankanhänger, alles andere →
normaler Curtainsider). Disponieren/Selbstzuweisen/Neuzuweisen wird
**serverseitig verweigert**, wenn am zugewiesenen Fahrzeug kein Anhänger vom
geforderten Typ hängt (`vehicle_missing_trailer`) - exakt wie die
bestehende Gefahrgut-Berechtigungsprüfung bei Fahrern. Seit v1.10.11 hängt
der Fehlercode das benötigte Anhänger-Label direkt an
(`vehicle_missing_trailer:<Label>`, z.B. `vehicle_missing_trailer:Tankanhänger`)
- sowohl `html/js/app.js` als auch die Website (`translateOrderCommandError`
in `spedition-webseite/src/lib/use-tablet-command.ts`) zeigen daraus eine
konkrete Meldung an, statt nur des rohen Fehlercodes.

- **Bodenmarker statt NPC**: An einem Standort, der gerade zu einem aktiven
  Auftrag gehört (Beladepunkt eines "in Anfahrt"-Auftrags, oder Zielort
  eines "beladen"-Auftrags), zeichnet das Spiel bei Nähe
  (`Config.LocationMarkerRadius`, Standard 60m) einen blauen Kreis auf dem
  Boden als Interaktionsstelle. Bewusst **kein NPC** (die
  Pedestrian-KI/Interaktion war zu unzuverlässig) - der Marker ist rein
  visuell, keine Entity, kein Kollisionsverhalten. Der Client-Thread, der
  das prüft, baut sich pro Tick eine kleine Nachschlagetabelle aus den
  eigenen Aufträgen (statt bei jedem einzelnen Ort erneut die komplette
  Auftragsliste zu durchsuchen) - macht sich vor allem bemerkbar, sobald im
  Reiter "Orte" sehr viele Orte angelegt wurden.
- **Auftragsstatus-Flow**: `disponiert` (bzw. Selbstzuweisung) → `angenommen`
  (Annehmen-Button im Tablet, siehe unten die Fahrerkarten-Pflicht) → sofort
  automatisch `anfahrt` (Anfahrt zum Beladepunkt) → per Taste E am
  Beladepunkt-Marker `beladen` (= beladen, zum Zielort unterwegs - bleibt
  während der ganzen Fahrt bestehen) → per Taste E am Zielort-Marker
  `entladen` → automatisch `abgeschlossen`. Nur `angenommen`/`Ablehnen`
  laufen noch über Tablet-Buttons - der Rest passt sich automatisch der
  Spielwelt an.
- **Beladen/Entladen per Taste E**: Ist ein Auftrag gerade "in Anfahrt" mit
  Beladepunkt hier, oder "beladen" mit Zielort hier, zeigt das Spiel bei Nähe
  zum Marker (`Config.LocationInteractRadius`, Standard 2,5m) einen Hinweis
  ("E - Fracht abholen/abliefern"). Taste E startet eine Animation mit
  Fortschrittsbalken über `Config.LoadUnloadSeconds` (Standard 150s = 2:30
  min); der Auftragsstatus wechselt danach automatisch weiter (s.o.).
  Entfernt sich der Fahrer während des Vorgangs mehr als 5m vom Marker,
  bricht der Vorgang ab.
- **Fahrerkarte einstecken vor Auftragsannahme, inkl. Fahrzeug-/Anhänger-
  Selbstauswahl**: Ein Fahrer muss im Reiter "Fahrerkarte" zuerst seine Fahrt
  starten ("Fahrerkarte einstecken"), bevor er einen Auftrag annehmen kann
  (`shift_not_started`, serverseitig erzwungen in `Orders.AcceptByDriver`) -
  damit bewusst bestätigt wird, dass ab jetzt seine Lenk-/Ruhezeiten laufen.
  Dabei öffnet sich ein Formular, in dem der Fahrer sich **selbst** ein
  freies Fahrzeug aussucht (`driver:shiftOptions`/`driver:startShift`,
  `server/sv_drivers.lua`) - eine gesonderte Zuweisung durch die
  Geschäftsführung im Fuhrpark ist dafür nicht mehr nötig, bleibt als
  manuelle Vorab-Zuweisung aber weiterhin möglich. Passend dazu muss der
  Fahrer entweder einen freien Anhänger auswählen (wird automatisch an das
  gewählte Fahrzeug angekuppelt) oder explizit **"Werkstattfahrt"** wählen
  (kein Anhänger) - erst dann lässt sich "Fahrerkarte einstecken" bestätigen.
  Ohne Anhänger kann der Fahrer keine Frachtaufträge annehmen (siehe
  Anhänger-Pflicht oben), Lenkzeit wird aber unabhängig davon erfasst, sobald
  er im zugewiesenen Fahrzeug sitzt - eine Werkstattfahrt ist also bewusst
  auch ohne Fracht möglich. Ein Fahrzeug/Anhänger, das sich gerade ein
  ANDERER, bereits im Dienst befindlicher Fahrer genommen hat, taucht in der
  Auswahl nicht auf. "Fahrerkarte abziehen" beendet die Fahrt wieder UND gibt
  das Fahrzeug automatisch für andere Fahrer frei (der Anhänger bleibt am
  Fahrzeug hängen). Der Schicht-Zustand wird in
  `st_drivers.on_shift`/`shift_started_at` gespeichert und ist unabhängig
  vom (automatischen, kennzeichenbasierten) Lenkzeit-Tracking selbst -
  Letzteres läuft weiterhin wie gehabt über `client/cl_hours.lua`.
- **Lieferschein im Tablet**: Solange ein Auftrag angenommen, in Anfahrt,
  beladen oder in Entladung ist, zeigt das Tablet unter "Meine Aufträge"
  einen ausführlichen Lieferschein: Ware, Menge/Einheit (Reiter
  "Frachtarten"), Gefahrgut-Kennzeichnung, Entfernung, Abhol-/Zielort
  samt GPS-Koordinaten, zugewiesenes Fahrzeug, Ausstellungsdatum,
  disponierender Mitarbeiter und Lieferfrist.
- **Eigene Markierung**: Unter jedem gerade aktiven Auftrag (angenommen,
  Anfahrt, beladen, Entladung) kann der Fahrer über "Neue Markierung setzen"
  einen eigenen Wegpunkt/Blip an seiner aktuellen Position setzen - z.B. um
  sich einen Treffpunkt oder eine Zwischenstation zu merken, unabhängig von
  den festen Be-/Entladepunkten. Die Position wird ausschließlich
  serverseitig ermittelt (`GetEntityCoords`, kein Client-Trust, exakt wie
  bei "Aktuelle Position übernehmen" im Reiter "Orte") - anders als dort
  werden die Koordinaten dem Fahrer aber **nie** angezeigt, es gibt nur eine
  Bestätigung. Erneutes Setzen ersetzt die vorherige Markierung. Siehe
  `Orders.SetCustomMarker` in `server/sv_orders.lua`.

  **Bestandsinstallationen:** die drei neuen Spalten `custom_marker_x/y/z`
  auf `st_orders` werden nur bei einer komplett frischen Installation
  automatisch aus `sql/install.sql` angelegt. Läuft euer Server schon
  länger, einmalig folgendes SQL gegen eure Datenbank ausführen:
  ```sql
  ALTER TABLE `st_orders`
      ADD COLUMN `custom_marker_x` FLOAT NULL,
      ADD COLUMN `custom_marker_y` FLOAT NULL,
      ADD COLUMN `custom_marker_z` FLOAT NULL;
  ```
- **Bekannte Einschränkungen**: Die Zeit- und Nähe-Prüfung für das Be-/
  Entladen läuft ausschließlich clientseitig (kein serverseitiger Schutz vor
  Manipulation der lokalen Wartezeit) - für ein PvE-Logistikfeature wie
  dieses als ausreichend eingeschätzt, bei Bedarf aber erweiterbar. Für jede
  der (standardmäßig 14) Frachtarten aus dem Reiter "Frachtarten" ist unter
  den mitgelieferten 59 Standardstandorten mindestens eine Quelle **und**
  ein Ziel hinterlegt - löschst du im Reiter "Orte" den einzigen Quell- oder
  Zielort einer Frachtart, wird diese Frachtart bis zum Anlegen eines
  Ersatzorts nicht mehr für automatisch generierte Aufträge ausgewählt.
- **Gefahrgut-Zugriffsbeschränkung**: Frachtarten, deren "Gefahrgut"-Häkchen
  im Reiter "Frachtarten" gesetzt ist, erzeugen Aufträge mit
  `requires_permission = 'gefahrgut'`. Das Disponieren
  und Neuzuweisen an Fahrer ohne die Fahrerberechtigung "Gefahrgut" wird
  **serverseitig verweigert** (`driver_missing_permission`); die
  Disponenten-Oberfläche blendet ungeeignete Fahrer in der Zuweisungsauswahl
  zusätzlich aus.

### Auftrags-Reset bei jedem Neustart

Bei jedem Ressourcenstart (Server-Neustart, `/refresh` + `ensure`, oder ein
manueller Neustart der Ressource) werden **alle im Spiel entstandenen, noch
nicht abgeschlossenen Aufträge** (automatisch generiert oder von einem
Disponenten manuell angelegt - offen im Pool, mitten in der Fahrt,
abgebrochen/abgelehnt, inkl. Verlauf und Abbruch-Anfragen) automatisch
gelöscht - so startet jede Session ohne hängengebliebene Aufträge von vor
dem Neustart. Zwei Ausnahmen überleben bewusst: **von der Website aus
angelegte Aufträge (`source = 'website'`)**, damit ein Website-Auftrag nicht
verloren geht, bevor ihn im Spiel überhaupt jemand gesehen/disponiert hat,
und **bereits abgeschlossene Aufträge (`status = 'abgeschlossen'`)**, damit
ein erledigter Auftrag als Nachweis erhalten bleibt statt bei jedem Neustart
zu verschwinden - beide inkl. ihres vollständigen Verlaufs. Fahrerstatistik
und Transaktions-Ledger bleiben davon ohnehin unberührt. Bei aktivem
Website-Sync wird direkt danach ein `orders.reset`-Event an die Website
gemeldet (siehe „Website-Sync" unten) - die entfernt daraufhin jeden dort
gespiegelten `origin: "tablet"`-Auftrag, der den Neustart im Tablet nicht
überlebt hat, statt für immer als Karteileiche in der Website-Disposition
stehen zu bleiben.

### Fahrer bricht Auftrag ab (mit Genehmigung/Vertragsstrafe)

Im Reiter "Aufträge" hat ein Fahrer bei jedem laufenden Auftrag
(`angenommen`/`anfahrt`/`beladen`/`entladen`) einen Button **"Abbrechen"**:

- **Ist ein Disponent/GF online**: Es wird nur eine Genehmigungsanfrage
  erzeugt (`st_order_cancel_requests`) - der Auftrag bleibt bis zur
  Entscheidung unverändert. Der Disponent sieht die Anfrage in "Aktive
  Aufträge" mit den Buttons "✅ Abbruch genehmigen"/"❌ Ablehnen".
  Genehmigung führt den normalen Abbruch aus (keine Strafe); Ablehnung
  benachrichtigt den Fahrer.
- **Ist niemand online**: Der Auftrag wird sofort abgebrochen, und dem
  Unternehmensguthaben wird eine **Vertragsstrafe** (`Config.OrderCancelPenalty`,
  Standard 500$) als eigene Transaktion (`vertragsstrafe`) belastet.

## Live-Karte

Die App **"Live Karte"** (Kategorie Kommunikation, Berechtigung `live_map_view`)
zeigt ausschließlich gerade eingestempelte Fahrer (`st_drivers.on_shift = 1`)
als Marker über einem selbst hinterlegten Kartenbild - alle 3 Sekunden
(`Config.LiveMap.trackingIntervalMs`) aktualisiert.

- **Standard-Kartenbild inklusive**: `html/img/map.jpg` liegt mit einer
  GTA-V-Satellitenkarte bereits bei. Willst du ein anderes Kartenbild,
  überschreibe einfach diese Datei (siehe
  `html/img/KARTENBILD_HIER_ABLEGEN.txt`) - löschst du sie komplett, zeigt
  die Karte stattdessen einen Hinweistext statt eines kaputten Bildes.
- **Kein Kalibrierungswerkzeug**: Die Fahrerposition kommt immer direkt und
  serverseitig von GTA (`GetEntityCoords`) - es gibt bewusst kein
  In-App-Werkzeug mehr, das das erst umständlich ermitteln muss. Passt dein
  eigenes Kartenbild nicht exakt zu den mitgelieferten Standard-
  Kartengrenzen `Config.LiveMap.bounds` (die Marker sitzen dann leicht
  daneben), passe die vier Zahlen (`minX`/`maxX`/`minY`/`maxY`) direkt in
  `config.lua` an: besuche im Spiel zwei dir bekannte, auf deinem Kartenbild
  gut identifizierbare Orte, notiere ihre Weltkoordinaten (z.B. über den
  Reiter "Orte") sowie die jeweilige Bildposition in Prozent, und löse damit
  die vier Werte linear auf (siehe `worldToMapPercent` in `html/js/app.js`
  für die exakte Formel). Nach dem Eintragen die Ressource neu starten (und
  - sofern Website-Sync aktiv - die Website erhält die neuen Grenzen
  automatisch mit, siehe unten).
- **Serverseitig ermittelt**: Position, Fahrzeug und laufender Auftrag jedes
  getrackten Fahrers werden ausschließlich serverseitig ermittelt
  (`GetEntityCoords`/`GetVehiclePedIsIn`), nie vom Client gemeldet. Rein
  transient im Arbeitsspeicher (`server/sv_tracking.lua`) - keine
  Datenbank-Tabelle, keine Historie.
- **Website-Sync**: Ist `Config.Website.enabled` aktiv, werden Positionen
  live an die Speditions-Website gepusht (`driver_position.update`/
  `.remove`) und die konfigurierten Kartengrenzen beim Ressourcenstart als
  `live_map.bounds` mitgeschickt, damit die Website dieselbe
  Weltkoordinaten→Kartenbild-Umrechnung verwendet wie das Tablet.

**Bestandsinstallationen:** `live_map_view` ist eine neue Berechtigung -
bestehende Rollen bekommen sie NICHT automatisch (`Config.DefaultRolePermissions`
wirkt nur bei der Erstbefüllung einer Rolle, siehe "Rollen & Berechtigungen"
oben). Öffne den Reiter "Rollen", wähle Disponent/Geschäftsführung und hake
"Live-Karte einsehen" manuell an.

## Funk

Die App **"Funk"** ist eine eigenständige Kachel direkt auf dem
Startbildschirm (nicht in einer Kategorie - für jeden angemeldeten
Mitarbeiter sichtbar, kein eigenes Berechtigungs-Häkchen nötig) und bindet
an [pma-voice](https://github.com/AvarianKnight/pma-voice) an. Sie ist
bewusst als digitale Funkkonsole/Leitstellen-Cockpit gestaltet statt als
Liste von zehn Kanal-Buttons, mit Teilnehmerliste und Anrufen zwischen
Funk-Teilnehmern.

- **Großes LCD-Kanaldisplay** in der Mitte zeigt den aktuell eingestellten
  Kanal jederzeit eindeutig. Links/rechts daneben je ein antippbarer
  Nachbarkanal sowie ein Schrittpfeil (◂/▸) - Kanalwechsel bleibt so immer
  ein einzelner, gezielter Tap statt einer Kachelwand. Im Tablet angezeigte
  Kanäle 1-10 (`Config.Radio.minChannel`/`maxChannel`), Standardkanal beim
  Ressourcenstart `Config.Radio.defaultChannel` - alle drei in `config.lua`
  frei anpassbar. Intern läuft das über pma-voice-Kanäle 4100-4109
  (`Config.Radio.pmaChannelBase`, s. Kommentar in `config.lua`) - eigener,
  hoher Kanalbereich, damit es keine Überschneidung mit Funkkanälen anderer
  Ressourcen/Gruppen auf eurem Server gibt.
- **Lautstärke-Regler**: echter Slider (kein +/- Tastenpaar) mit
  Prozentanzeige, direkt an `pma-voice`s `setRadioVolume` gekoppelt.
  Standardlautstärke beim Ressourcenstart `Config.Radio.defaultVolume`.
- **Funk beitreten/verlassen**: eigener Schalter oben in der Konsole. Erst
  nach dem Beitreten wird man für andere hörbar/sichtbar (Teilnehmerliste,
  Anrufe) - `setVoiceProperty('radioEnabled', ...)` steht dabei auf `true`,
  ohne Beitritt bleibt der Funk stumm. Kanal/Lautstärke lassen sich auch
  vorher schon einstellen.
- **Teilnehmerliste** (rechts neben der Konsole): zeigt live, wer gerade
  auf demselben Kanal ist (Polling alle 3s, solange die App offen ist,
  `server/sv_radio.lua`, RPC `radio:channelMembers`) - rein transient im
  Arbeitsspeicher, keine Datenbank-Tabelle.
- **Anrufe**: jeder Funk-Teilnehmer kann jeden anderen (der ebenfalls
  beigetreten ist) direkt aus der Teilnehmerliste heraus anrufen - egal ob
  Disponent→Fahrer oder Fahrer→Disponent, keine feste Rollen-Einschränkung.
  Der Anruf läuft über einen von den normalen Funkkanälen komplett
  getrennten, privaten pma-voice-Call-Kanal (`setCallChannel`) - das
  normale Mithören auf dem eingestellten Kanal wird dadurch nicht gestört.
  Klingelt `Config.Radio.callRingSeconds` (Standard 20s) lang niemand ran,
  gilt der Anruf als verpasst. **Ein Anruf kommt nur an, solange die
  Funk-App auf dem Tablet des Angerufenen tatsächlich geöffnet ist** - bei
  geschlossenem Tablet oder auf einer anderen App/Kategorie verpufft ein
  eingehender Anruf momentan wirkungslos.
- **Anruf halten**: während eines laufenden Gesprächs lässt sich über
  "Halten" die Verbindung pausieren - beide Seiten trennen währenddessen
  ihren privaten Call-Kanal (niemand spricht ins Leere), "Fortsetzen"
  (von beiden Seiten auslösbar) verbindet wieder. RPCs `radio:holdCall`/
  `radio:resumeCall`.
- **Eigener Name im Funk**: im Einstellungsbereich unter der Konsole lässt
  sich ein eigener Anzeigename für die Teilnehmerliste hinterlegen (Standard:
  Mitarbeitername) - rein transient, RPC `radio:setDisplayName`.
- **Sounds**: liegen fertig bei (`html/sounds/`) - über den Schalter
  "Sounds abspielen" im Einstellungsbereich jederzeit stummschaltbar,
  eigene Dateien lassen sich einfach überschreiben (siehe
  `html/sounds/SOUNDS_HIER_ABLEGEN.txt`).
  | Datei | Wann |
  |---|---|
  | `channel_switch.mp3` | Kanal gewechselt |
  | `ptt_end.mp3` | eigenes Senden (PTT) losgelassen |
  | `call_number.mp3` (Schleife) | während man selbst jemanden anruft - bricht ab, sobald angenommen wird |
  | `incoming_call.mp3` (Schleife) | eingehender Anruf - bricht ab bei Annehmen/Ablehnen |
  | `holding_line.mp3` (Schleife) | Gespräch wird gehalten - bricht ab, sobald fortgesetzt (oder aufgelegt) wird |
- **Funkstatus auf einen Blick**: ein Chip zeigt, ob die Verbindung zu
  pma-voice aktiv ist ("Verbunden"/"Nicht verbunden", wird alle paar
  Sekunden nachgeprüft), zwei weitere blenden sich farbig ein, sobald man
  selbst sendet ("Senden", pulsierend rot) bzw. jemand auf dem Kanal zu
  hören ist ("Empfang", blau) - beides live über die pma-voice-eigenen
  Events `pma-voice:radioActive`/`pma-voice:setTalkingOnRadio`.
- **Architektur**: Kanal-/Lautstärkewechsel bei pma-voice selbst laufen
  weiterhin primär clientseitig (`client/cl_radio.lua`, Exports
  `setVoiceProperty`, `setRadioChannel`, `setRadioVolume`) - pma-voice
  validiert Kanäle ohnehin selbst serverseitig. Beitreten/Verlassen, der
  Kanalabgleich für die Teilnehmerliste sowie Anrufe laufen dagegen über
  `server/sv_radio.lua`, da der Server wissen muss, wer gerade wo ist.
- **Fehlerdiagnose "Funk geht nicht/kein Ton":** Ist `pma-voice` nicht
  gestartet (falscher Ressourcenname, Absturz, o.ä.), meldet
  `client/cl_radio.lua` das einmalig deutlich in der Client-Konsole (F8) mit
  dem tatsächlichen `GetResourceState('pma-voice')`-Wert - im Tablet zeigt
  der Verbunden-Chip in diesem Fall "Nicht verbunden". Wird die Kanalwahl
  von pma-voice aktiv abgelehnt (Event `pma-voice:radioChangeRejected`,
  z.B. weil die Konsolenvariable `voice_enableRadios` auf `0` steht),
  erscheint zusätzlich ein In-Game-Warnhinweis. Prüfe in dem Fall
  `ensure pma-voice` in `server.cfg` und die genannte Convar.
- **Fehlerdiagnose "Beitreten-Button springt sofort wieder zurück":** `config.lua`
  wird bei einem Update bewusst NICHT automatisch überschrieben (s.
  `escrow_ignore_files` in `fxmanifest.lua`) - stammt eure `config.lua` noch
  von vor der Einführung des Funk-Features, fehlt ihr der komplette
  `Config.Radio`-Block. `client/cl_radio.lua` und `server/sv_radio.lua`
  laufen in dem Fall zwar dank eingebauter Standardwerte (Kanäle 1-10)
  weiter, statt abzustürzen, melden das aber deutlich als rote Zeile
  `[speditions-tablet] Funk: Config.Radio fehlt in config.lua ...` in der
  Server- bzw. Client-Konsole (F8). Ergänzt in dem Fall den folgenden Block
  aus der aktuellen `config.lua` in eure eigene (Werte nach Bedarf anpassen):
  ```lua
  Config.Radio = {
      minChannel = 1,
      maxChannel = 10,
      defaultChannel = 1,
      defaultVolume = 100,
      callRingSeconds = 20,
      pmaChannelBase = 4100,
  }
  ```
- **Fehlerdiagnose "Anrufpartner hören sich nicht":** Anrufe laufen über
  pma-voice's eigenen, von den normalen Funkkanälen komplett getrennten
  Call-Mechanismus (`setCallChannel`) - dafür muss die Konsolenvariable
  `voice_enableCalls` (in älteren pma-voice-Versionen `voice_enablePhones`)
  auf `1` stehen (Standardwert von pma-voice selbst, kann aber in `server.cfg`
  explizit auf `0` gesetzt worden sein, z.B. durch ein Telefon-Script, das
  diesen Kanal exklusiv für sich beansprucht). Prüft `server.cfg` auf diese
  Convar. Prüft außerdem die Server-/Client-Konsole (F8) auf rote
  `[speditions-tablet] Funk: pma-voice-Export "setCallChannel" ist
  fehlgeschlagen ...`-Zeilen unmittelbar nach dem Annehmen eines Anrufs -
  die tauchen auf, falls euer pma-voice-Fork diesen Export unter einem
  anderen Namen bereitstellt. Erscheint stattdessen in der Server-Konsole
  wiederholt `[mumble] MUMBLE_ADD_VOICE_CHANNEL_LISTEN: Tried to call native
  on a channel that didn't exist`: das ist ein bekannter, von den
  pma-voice-Maintainern nicht behobener Bug (Race Condition zwischen dem
  Anlegen eines neuen Mumble-Kanals und dem ersten Zuhören darauf, s.
  [pma-voice#555](https://github.com/AvarianKnight/pma-voice/issues/555)) -
  betrifft praktisch nur BRANDNEUE Kanalnummern. Anruf-Kanäle laufen daher
  über einen festen, wiederverwendeten Pool (`server/sv_radio.lua`,
  `CALL_CHANNEL_POOL_START`/`CALL_CHANNEL_POOL_SIZE`, Standard 90001-90020,
  bis zu 20 gleichzeitige Gespräche) statt ständig neuer Nummern - jeder
  Pool-Kanal wird dadurch nur beim jeweils ersten Gespräch nach einem
  Serverneustart neu angelegt, danach bereits vorhanden. Tritt die Meldung
  trotzdem dauerhaft auf, testet zur Kontrolle den normalen Funkkanal
  (nicht Anrufe) - bleibt der ebenfalls stumm, liegt es nicht an den
  Anruf-Kanälen, sondern an pma-voice/Mumble selbst (Serverneustart, ggf.
  pma-voice-Update prüfen).

## Datenbankschema

Siehe `sql/install.sql`. Wichtigste Tabellen:

```
st_roles                Frei anlegbare Rollen (Rollenschlüssel, Bezeichnung, Berechtigungen als JSON, Basisrolle ja/nein)
st_employees            Mitarbeiterstammdaten (Login-Name, Passwort-Hash/Salt, Rolle, Status, zuletzt bekannter FiveM-Charakter nur informativ, Dispositions-Dienst-Status)
st_drivers              Fahrer-Zusatzdaten (Status, Notizen, Fahrzeugzuweisung, Fahrerkarte eingesteckt/seit)
st_driver_permissions   Führerscheinklassen / Sonderberechtigungen
st_driver_statistics    Aggregierte Fahrerstatistik (aus st_orders berechnet)
st_locations            Be-/Entladepunkte (Reiter "Orte"), Erstbefüllung aus Config.SeedLocations
st_cargo_types          Frachtarten (Reiter "Frachtarten"), Erstbefüllung aus Config.SeedCargoTypes
st_vehicles             Fuhrpark
st_vehicle_assignments  Historie der Fahrzeug-Fahrer-Zuweisungen
st_vehicle_history      Fahrzeugereignisse (erstellt, Wartung, Status, Aufträge)
st_trailers             Anhänger (Reiter "Anhänger"), inkl. Ankupplung an st_vehicles
st_orders               Aufträge inkl. Fahrer-/Fahrzeugzuordnung, geforderter Anhängertyp, Menge/Einheit (Lieferschein)
st_order_stops          Zwischenstopps (optional/erweiterbar)
st_order_history        Audit-Trail je Auftragsstatus
st_order_cancel_requests Abbruch-Anfragen von Fahrern (offen/genehmigt/abgelehnt)
st_transactions         Vollständiges Transaktions-Ledger (Einnahmen/Auszahlungen/Einzahlungen/Vertragsstrafen)
st_company_balance      Performance-Cache des aktuellen Guthabens
st_payouts              Auszahlungen (Betrag, Grund, Zielkonto, ausführender Mitarbeiter)
st_deposits             Einzahlungen (Betrag, Grund, Herkunft, ausführender Mitarbeiter)
st_notifications        Nachrichten Disponent -> Fahrer
st_activity_logs        Aktivitätsprotokoll
st_driver_hours         Lenk-/Ruhezeiten je Fahrer (ununterbrochen/täglich, Pausenstatus)
st_wage_rates           Stundenlohn je Rolle (von der Geschäftsführung anpassbar)
st_timeclock_sessions   Stempeluhr-Sessions je Mitarbeiter (ein-/ausgestempelt, bezahlt/offen)
st_payroll_payouts      Historie der Gehaltsauszahlungen
```

## Gehälter / Stempeluhr

Jeder Mitarbeiter stempelt sich über das Topbar-Widget im Tablet selbst
ein/aus - unabhängig von der Rolle. Die Geschäftsführung legt über den
Reiter **Gehälter** den Stundenlohn je Rolle fest (Erstbefüllung aus
`Config.DefaultHourlyWage`, danach ist die Datenbank die Quelle der
Wahrheit) und sieht dort für jeden aktiven Mitarbeiter die offenen,
noch nicht ausgezahlten Stunden samt daraus berechnetem Betrag. Ein Klick
auf "Auszahlen" berechnet das Gehalt serverseitig neu (der Client kann
den Betrag nicht vorgeben), zieht ihn vom Unternehmensguthaben ab und
übergibt ihn - genau wie bei einer normalen Auszahlung - als echtes
Bargeld an den **Mitarbeiter selbst** (nicht an die ausführende
Geschäftsführung). **Voraussetzung: der Mitarbeiter muss gerade online
und am Tablet eingeloggt sein** - ist das nicht der Fall, ist der
"Auszahlen"-Button in der Übersicht deaktiviert (Badge "Nicht online")
und ein Klickversuch (z.B. per API) wird serverseitig mit
`employee_not_online` abgelehnt, statt das Gehalt zu verbuchen und das
Bargeld verfallen zu lassen.

Verlässt ein eingestempelter Mitarbeiter den Server (Disconnect, egal ob
gewollt oder durch Verbindungsabbruch), wird er automatisch ausgestempelt
(`playerDropped` in `server/sv_bootstrap.lua` ruft `Payroll.ForceClockOut`
auf, **bevor** die Session gelöscht wird) - ohne das würde die Stempeluhr
offline einfach weiterlaufen und beim nächsten Gehaltslauf mitbezahlt
werden, obwohl niemand mehr am Server ist.

## Konfiguration

Alle Stellschrauben befinden sich in `config.lua`:

- `Config.CompanyName` - Firmenname auf Sperrbildschirm, Topbar und Fahrerkarte
- `Config.SeedLocations` - Liste der echten Firmenstandorte (Koordinaten,
  Frachtarten-Tags `sourceCargo`/`destCargo`) für die **einmalige
  Erstbefüllung** von `st_locations`; danach ausschließlich über den Reiter
  "Orte" pflegbar (siehe oben). Genutzt für Auftragsgenerierung,
  Bodenmarker, Be-/Entladen und Wegpunkte; `Config.OrderValuePerKm`,
  `Config.LoadUnloadSeconds`, `Config.LocationMarkerRadius`,
  `Config.LocationInteractRadius` - Wertspanne pro km sowie Timing/Radien
  für den Be-/Entladevorgang
- `Config.SeedCargoTypes` - Liste der Frachtarten (Name, Einheit,
  Mengenspanne, Gefahrgut-Flag, benötigter Anhängertyp) für die **einmalige
  Erstbefüllung** von `st_cargo_types`; danach ausschließlich über den
  Reiter "Frachtarten" pflegbar (siehe oben)
- `Config.TrailerTypes` - Katalog der fünf Anhängertypen (Reiter "Anhänger")
- `Config.OrderGeneration` - maximale Poolgröße sowie der Takt neuer
  Aufträge nach Anzahl online + am Tablet angemeldeter Fahrer
  (`intervalMsByDriverCount`, Standard: 1-2 Fahrer alle 12-15 Min., ab 3
  Fahrern alle 10-12 Min.; 0 Fahrer online = keine Generierung)
- `Config.OrderCancelPenalty` - Vertragsstrafe (Standard 500$), wenn ein Fahrer einen Auftrag ohne Disponenten-Freigabe selbst abbricht
- `Config.VehicleClasses`, `Config.DriverPermissions`
- `Config.AverageSpeedKmh`, `Config.DeadlineBufferMinutes` - Grundlage der
  Pünktlichkeitsberechnung
- `Config.DrivingRules` - Lenk-/Ruhezeiten-Grenzwerte und Heartbeat-Intervall
- `Config.InitialAccounts` - Erstkonto(s), die beim allerersten
  Ressourcenstart automatisch angelegt werden (Login-Name, Passwort,
  Rolle, Anzeigename) - Passwort danach unbedingt ändern!
- `Config.AdminAcePermission` - berechtigt zusätzlich zur Server-Konsole zum Vergeben/Zurücksetzen von Mitarbeiterkonten (`tablet_grant`)
- `Config.Permissions` - Katalog aller Einzelberechtigungen, aus denen die
  Geschäftsführung im Tablet (Reiter "Rollen") eigene Rollen zusammenstellt;
  `Config.DefaultRolePermissions` - nur einmalige Erstbefüllung der drei
  mitgelieferten Basisrollen, danach ist `st_roles` die Quelle der Wahrheit
- `Config.RequireItem` - Tablet nur per Item öffnen
- `Config.MoneyBridge` - Framework-Anbindung für Bargeld bei Aus-/Einzahlung
- `Config.NotificationSound` - Klingelton bei nativen In-Game-Hinweisen
- `Config.DefaultHourlyWage` - Stundenlohn je Rolle, nur einmalige Erstbefüllung von `st_wage_rates`

## Architektur

- `server/sv_rpc.lua` - zentraler, einziger Einstiegspunkt für alle
  NUI-Aktionen (`speditions-tablet:server:rpc`), inkl. serverseitiger
  Berechtigungsprüfung pro Aktion; `RPC.PushToPermission` für
  Echtzeit-Updates an alle angemeldeten Mitarbeiter mit einer bestimmten
  Berechtigung (statt einer fest verdrahteten Rolle).
- `server/sv_bridge.lua` - Optionale Framework-Anbindung (ESX/QBCore) für
  Bargeld bei Aus-/Einzahlung, inkl. ESX-/QBCore-Objekt für die
  Item-Registrierung (`ESX.RegisterUsableItem`/`QBCore.Functions.CreateUseableItem`)
  in `sv_main.lua`.
- `server/sv_bootstrap.lua` - Tablet-eigenes Login (Name + Passwort,
  Session je Server-Slot in `loggedIn[src]`), Passwort-Hashing,
  `tablet_grant`-Command, Erstkonto-Seeding aus `Config.InitialAccounts`,
  `Employees.RequirePermission` (Berechtigungsprüfung pro Aktion).
- `server/sv_roles.lua` - Rollen & Berechtigungen: frei anlegbare Rollen
  (Erstellen/Bearbeiten/Löschen), Berechtigungsprüfung (`Roles.HasPermission`),
  Erstbefüllung der drei Basisrollen aus `Config.DefaultRolePermissions`.
- `server/sv_locations.lua` - Orte (Reiter "Orte"): CRUD auf `st_locations`,
  Erstbefüllung aus `Config.SeedLocations`, "Aktuelle Position übernehmen"
  (ermittelt serverseitig per `GetEntityCoords`/`GetEntityHeading`),
  `locations:changed`-Broadcast an alle angemeldeten Mitarbeiter.
- `server/sv_finance.lua` - Transaktions-Ledger, Guthaben, Ein-/Auszahlungen.
- `server/sv_payroll.lua` - Stundenlöhne, Stempeluhr, Gehaltsauszahlung.
- `server/sv_vehicles.lua` - Fuhrparkverwaltung.
- `server/sv_trailers.lua` - Anhängerverwaltung (Reiter "Anhänger"): CRUD auf
  `st_trailers`, An-/Umkuppeln an Fahrzeuge.
- `server/sv_drivers.lua` - Fahrerkarte, Fahrerakte, Statistik, Fahrerkarte einstecken/abziehen (Schicht).
- `server/sv_hours.lua` - Lenk-/Ruhezeiten-Tracking, Warnungen, Erinnerungen.
  `warned_continuous`/`warned_daily` sind ein 3-Zustands-Zähler (0/1/2) und
  werden nach jedem DB-Read explizit normalisiert (`toWarnState`), weil
  oxmysql `TINYINT(1)`-Spalten sonst zu Lua-Booleans castet - Neuinstallationen
  legen die Spalten seit v1.10.3 direkt als `TINYINT UNSIGNED` an
  (`sql/install.sql`), was den Cast von vornherein verhindert; bei
  bestehenden Datenbanken reicht die Lua-seitige Normalisierung. Zusätzlich
  (v1.10.7, verschärft gegenüber dem ursprünglichen v1.10.5-Versuch):
  `Hours.Save()` bindet `resting_since` (DATETIME, nullable) NIE mehr als
  `?`-Parameter, weder mit noch ohne Wert - das hat die UPDATE-Abfrage auf
  manchen oxmysql-Versionen mit "Unknown column 'NaN' in field list"
  korrumpiert (oxmysql scheint DATETIME-Parameter über `?` generell falsch
  zu casten, nicht nur bei fehlendem Wert - v1.10.5 deckte nur den
  NULL-Fall ab und reichte nicht). `resting_since` wird jetzt in jedem Fall
  direkt als SQL-Literal in die Query geschrieben (`NULL` oder der
  quotierte Wert) - sicher, weil er ausschließlich aus `Utils.Now()`
  (server-generiertes `os.date`-Format) oder `nil` stammt, nie aus einer
  Nutzereingabe. Tatsächliche Ursache gefunden (v1.10.10): oxmysql lieferte
  für eine leere `resting_since`-Spalte auf dem Zielserver nicht Lua-`nil`
  zurück, sondern eine echte Lua-Zahl mit dem Wert NaN (0/0) - jede Zahl
  (auch NaN) ist in Lua truthy, also griff `if row.resting_since then`
  trotzdem, und `tostring(NaN)` ergab buchstäblich den String `"nan"`,
  sichtbar am MySQL-Fehler "Incorrect datetime value: 'nan'" (v1.10.7-9
  hatten das Symptom nur verschoben, nicht behoben). `Hours.EnsureRow()`
  normalisiert `resting_since` deshalb jetzt zusätzlich hart auf
  "echter, nicht-leerer String, sonst nil" - alles andere (Zahlen
  inklusive NaN, `false`, leere Strings) wird zu `nil`.
- `server/sv_console.lua` - Reiter "Konsole" (Berechtigung `console_view`,
  seit v1.10.13 zeigt sie zusätzlich (`kind = 'info'`) die Zusammenfassung
  des Auftrags-Resets bei jedem Ressourcenstart ("X Aufträge bleiben
  erhalten...", siehe `server/sv_orders.lua`) - vorher nur in der
  Server-Konsole sichtbar, damit ohne Server-Zugriff nachprüfbar ist, ob
  abgeschlossene Aufträge tatsächlich als "erhalten" erkannt wurden.
  standardmäßig nur Geschäftsführung): Ringpuffer im Arbeitsspeicher (max.
  300 Einträge, überlebt keinen Ressourcen-Neustart) mit allen RPC-Fehlern
  (außer dem erwarteten `not_logged_in`, siehe `server/sv_rpc.lua`),
  tatsächlich als Lua-Fehler geworfenen DB-Fehlern (`MySQL.*.await` wird
  dafür zentral gewrappt) und client-seitig gemeldeten Fehlern
  (`console:clientError`). WICHTIG: kann NICHT die Konsolen-Ausgabe anderer
  Ressourcen (z.B. oxmysql selbst) mitlesen - FiveM isoliert jede Ressource
  in einer eigenen Lua-Umgebung, das ist technisch nicht möglich. Deckt nur
  ab, was der eigene Code selbst als Fehler erkennt. Zeigt seit v1.10.8
  zusätzlich die aktuell laufende Skript-Version
  (`GetResourceMetadata(..., 'version', 0)` aus `fxmanifest.lua`) direkt in
  der NUI an - damit ohne Server-/Konsolenzugriff nachprüfbar ist, ob ein
  zugesendetes Update tatsächlich aktiv ist, statt es nur zu vermuten.
- `server/sv_orders.lua` - Auftragsgenerierung & -lebenszyklus
  (disponiert → angenommen → anfahrt → beladen → entladen → abgeschlossen),
  Gefahrgut-Prüfung, Anhängertyp-Prüfung (`vehicle_missing_trailer`),
  Auto-Wegpunkte, Standort-/Frachtart-Zuordnung + GPS-Koordinaten für Lieferschein,
  Abbruch-Anfragen mit Disponenten-Genehmigung/Vertragsstrafe, Auftrags-Reset bei Ressourcenstart.
  `Orders.Complete()` prüft Pünktlichkeit über `SELECT (NOW() <= ?) AS ok` -
  dieses Ausdrucksergebnis ist bei MySQL vom Typ TINYINT(1) und wurde daher
  (v1.10.9) auf `Utils.ToBool` statt einem `tonumber(...) == 1`-Vergleich
  umgestellt (derselbe oxmysql-Boolean-Cast wie bei `warned_continuous`/
  `warned_daily` in `sv_hours.lua`) - ohne den Fix wäre `punctual` durch den
  Cast praktisch immer als 0 (verspätet) gespeichert worden, auch bei
  pünktlicher Lieferung.
- `server/sv_employees.lua` - Mitarbeiterverwaltung (Einstellen, Rolle/Status
  ändern, beliebige im Tablet angelegte Rollen zuweisbar).
- `server/sv_notifications.lua` - Nachrichten Disponent/Fahrer.
- `server/sv_radio.lua` - App "Funk": Präsenz (wer ist auf welchem Kanal),
  Teilnehmerliste, Anrufe zwischen zwei Funk-Teilnehmern - siehe eigener
  Abschnitt "Funk" oben. Rein transient im Arbeitsspeicher wie
  `sv_tracking.lua`, keine Datenbank-Tabelle.
- `server/sv_website_bridge.lua` - Optionaler Website-Sync (siehe eigener
  Abschnitt unten), komplett inaktiv solange `Config.Website.enabled = false`.
  Sowohl Erfolg als auch Fehlschlag werden seit v1.10.12 nur noch mit
  `Config.Debug = true` geloggt (`Utils.DebugPrint`), nicht mehr unbedingt -
  vorher hat jedes einzelne Sync-Ereignis (bei jeder Statusänderung, alle 60s
  Lenkzeit-Meldungen, ...) sowie jeder einzelne Fehlschlag (Website kurz nicht
  erreichbar, Timeout) einen Log-Eintrag erzeugt und die Konsole im
  Dauerbetrieb geflutet. Website-Sync ist ohnehin "best effort" (ein Ausfall
  blockiert nie das Spiel) - zum Debuggen `Config.Debug = true` setzen.
- `client/cl_main.lua` - NUI-Steuerung, RPC-Relay (`ServerCall` auch für
  andere Client-Skripte nutzbar) sowie native In-Game-Hinweise/Wegpunkte sind hier verdrahtet.
- `client/cl_hours.lua` - Erkennt per Kennzeichen-Abgleich, ob der Fahrer
  gerade sein zugewiesenes Firmenfahrzeug fährt, und meldet Fahrzeit an den Server.
- `client/cl_orders.lua` - Bodenmarker an relevanten Standorten aus dem
  Reiter "Orte" (kein NPC), Be-/Entladen per Taste E mit Fortschrittsbalken.
- `client/cl_radio.lua` - App "Funk", bindet an pma-voice an (Kanalwahl
  1000-1009 + Lautstärke, `Config.Radio`, Anrufe) - siehe eigener Abschnitt
  "Funk" oben.
- `html/` - NUI-Frontend (Sperrbildschirm, berechtigungsbasierte Reiter -
  `NAV_ITEMS`/`buildSidebar` in `js/app.js` -, Rollenverwaltung). Der Client
  führt dabei keine Geschäftslogik aus - jede Aktion wird serverseitig neu
  geprüft, die Reiter-Sichtbarkeit ist reine Bequemlichkeit.

**Wichtig bei eigenen NUI-Erweiterungen:** niemals `confirm()`/`alert()`/
`prompt()` im NUI-JavaScript verwenden - CEF (der Browser-Unterbau der
FiveM-NUI) unterstützt diese synchronen JS-Dialoge nicht richtig, das
Spiel friert dabei **komplett** ein (kein Fehler, keine Wiederherstellung
außer per Ressourcen-/Server-Neustart). Bestätigungen laufen in diesem
Projekt stattdessen ausschließlich über `openConfirmModal()`
(`html/js/app.js`) - ein normales, asynchrones NUI-Modal.

Das System ist modular aufgebaut: neue Auftragstypen, zusätzliche
Fahrzeugklassen oder weitere Rollen-Berechtigungen lassen sich über
`config.lua` und zusätzliche RPC-Handler erweitern, ohne bestehende Module
anzufassen.

## Website-Sync (optional)

Das Tablet kann optional mit einer separaten, extern gehosteten
Speditions-Website synchronisiert werden - **gleichwertig in beide
Richtungen**: weder das Tablet noch die Website ist die alleinige Quelle
der Wahrheit, beide Seiten können Aufträge/Fahrzeuge/Mitarbeiter anlegen
bzw. bearbeiten, die jeweils andere Seite zieht nach. Das Feature ist
standardmäßig **deaktiviert** und greift nicht in irgendetwas ein, solange
es nicht aktiv eingeschaltet wird.

**Architektur**: Beide Richtungen laufen über ausgehende HTTP-Requests vom
FiveM-Server - der Spielserver muss dafür keinen eingehenden Port öffnen:

- **Push** (Tablet → Website): bei jeder relevanten Änderung (Auftrag **neu
  im offenen Pool generiert** (`Orders.GenerateOne`)/disponiert/selbst
  zugewiesen (kein Disponent online)/neu disponiert/angenommen/
  abgeschlossen/neu angelegt, Fahrzeug angelegt/geändert/**Fahrer
  zu-/abgewiesen** (Fahrerkarte einstecken/abziehen, Fuhrpark-Zuweisung),
  Mitarbeiter eingestellt/Rolle geändert, periodische Lenkzeiten-Meldung)
  schickt `server/sv_website_bridge.lua` sofort einen Webhook an
  `.../api/tablet/webhook` — ein neu generierter Pool-Auftrag ist dadurch
  ab sofort auch auf der Website sichtbar und von dort aus disponierbar
  (Reiter "Auftragspool"), statt erst beim Disponieren im Spiel bekannt zu
  werden. Einmalig beim Ressourcenstart UND bei
  jeder Änderung im Reiter "Orte" (angelegt/bearbeitet/gelöscht) wird
  zusätzlich `locations.sync` gepusht - meldet die gültigen Standortnamen/
  Frachtarten (`Locations.List()`/`CargoTypes.Names()`), Grundlage für die
  Standort-Auswahl beim Anlegen neuer Aufträge auf der Website. Ebenfalls
  beim Ressourcenstart wird `orders.reset` gepusht (siehe "Auftrags-Reset
  bei jedem Neustart" oben) - meldet, welche `st_orders.id` den Neustart
  überlebt haben (von der Website selbst angelegte UND bereits
  abgeschlossene Aufträge); die Website entfernt daraufhin jeden dort
  gespiegelten `origin: "tablet"`-Auftrag, der NICHT in dieser Liste steht.
  Zusätzlich für Stempeluhr/Fahrerkarte/Fahrtenbuch (siehe README der
  Website für die dortige Verarbeitung):
  - `timeclock.update` - bei jedem Ein-/Ausstempeln (`Payroll.ClockIn`/
    `ClockOut`, auch beim automatischen Schließen+Neustart einer Session
    während einer Gehaltsauszahlung). Die Website übernimmt den Status 1:1 -
    das eigene Ein-/Ausstempeln auf der Website ist für Tablet-verknüpfte
    Mitarbeiter deaktiviert, um zwei unabhängige Zeiterfassungen zu vermeiden.
  - `driver_shift.update` - bei jedem "Fahrerkarte einstecken/abziehen"
    (`Drivers.StartShift`/`EndShift`) - setzt den Aktiv-Status der Fahrerkarte
    auf der Website, ebenfalls ohne eigenen Website-Button für Tablet-
    verknüpfte Fahrer.
  - `driver_hours.report` (periodisch, wie zuvor) meldet inzwischen
    zusätzlich `restingSince`, damit die Website den genauen Pausenbeginn
    übernehmen kann statt nur "in Pause: ja/nein".
  - `trip.report` - bei jedem abgeschlossenen Frachtauftrag
    (`Orders.Complete`) wird automatisch ein Fahrtenbuch-Eintrag auf der
    Website angelegt (Start-/Zielort, Kilometerstand vor/nach der Fahrt,
    Fahrer, Kennzeichen). `tabletOrderId` ist der Abgleichsschlüssel, ein
    erneuter Push (z.B. nach Ressourcen-Neustart) erzeugt dort nie einen
    doppelten Eintrag. Private/sonstige Fahrten trägt die Geschäftsführung
    weiterhin manuell im Website-Fahrtenbuch ein.
  - `finance.transaction` - bei JEDER Firmenkonto-Bewegung
    (`Finance.AddTransaction` in `server/sv_finance.lua` ist der einzige
    Schreibpfad für `st_transactions`/`st_company_balance` - Auftrags-
    Einnahme, Aus-/Einzahlung, Gehaltsauszahlung laufen alle hier durch,
    daher lückenlos). Meldet Typ, Betrag, Beschreibung, Fahrer-/Ausführer-
    Name und den neuen Saldo; die Website zeigt das unter "Finanzen" im
    Abschnitt "Ingame-Umsatz" an - unabhängig von den dort separat
    geführten Rechnungen. `tabletTransactionId` ist wieder der
    Abgleichsschlüssel gegen doppelte Einträge.
- **Pull** (Website → Tablet): alle `Config.Website.pollIntervalMs` fragt
  das Tablet `.../api/tablet/commands` ab und führt dort hinterlegte
  Befehle aus; das Ergebnis wird per `.../api/tablet/commands/{id}/ack`
  zurückgemeldet - bei einem Fehler als reiner Fehlercode (z.B.
  `order_not_found`), damit die Website ihn übersetzen bzw. gezielt darauf
  reagieren kann (`stripErrorLocation` in `sv_website_bridge.lua` entfernt
  dafür das von Luas `error()` automatisch vorangestellte "datei:zeile: ").
  Befehlstypen:
  - `assign_order`/`cancel_order` - Fahrzeug zuweisen/Auftrag abbrechen bei
    einem bereits im Tablet existierenden Auftrag.
  - `create_order` - ein auf der Website neu angelegter Auftrag landet im
    offenen Tablet-Auftragspool (`Orders.CreateFromWebsite`), genau wie ein
    automatisch generierter - ein Disponent im Spiel muss ihn noch
    disponieren. Start-/Zielort müssen exakt einem im Reiter "Orte"
    hinterlegten Namen entsprechen (siehe `locations.sync` oben).
  - `update_vehicle` - Statusänderung an einem von der Website aus
    bearbeiteten, bereits Tablet-verknüpften Fahrzeug
    (`Vehicles.UpdateFromWebsite`, Kennzeichen als gemeinsamer Schlüssel).
  - `create_employee` - ein auf der Website neu angelegtes Konto bekommt
    auch ein Tablet-Login (`Employees.HireFromWebsite`). Erfordert, dass
    im Rollen-Editor **genau eine** Tablet-Rolle der gewählten Website-
    Rolle zugeordnet ist (`Roles.FindTabletRoleForWebsiteKey`) - sonst
    schlägt der Befehl fehl (nur in der Server-Konsole sichtbar, siehe
    Fehlerausgabe von `server/sv_website_bridge.lua`). Optional können dabei
    auch Führerscheinklassen mitgegeben werden.
  - `update_driver_permissions` - ersetzt die Führerscheinklassen eines
    bereits Tablet-verknüpften Mitarbeiters vollständig durch die von der
    Website übergebene Auswahl (`Drivers.SetPermissionsFromWebsite`,
    Payload `{tabletEmployeeId, permissions}`).
  - `deactivate_employee` - wird gelöscht ein mit dem Tablet verknüpftes
    Konto auf der Website, deaktiviert das Tablet-Konto entsprechend
    (`Employees.DeactivateFromWebsite`, Payload `{tabletEmployeeId}`). Kein
    hartes SQL-Löschen im Tablet - würde Auftrags-/Transaktions-/Log-
    Historie verwaisen lassen; Deaktivieren ist die im Tablet ohnehin
    etablierte "Entfernen"-Variante für Mitarbeiter (siehe Reiter
    "Mitarbeiter", Status "inaktiv"). Greift die eingebaute Sperre "letztes
    aktives Konto mit Mitarbeiterverwaltung", bleibt der Mitarbeiter auf
    dem Tablet aktiv, obwohl er auf der Website gelöscht wurde - siehe
    Server-Konsole (`last_management_account`).
  - `create_vehicle` - auf der Website mit Häkchen "Auch im Tablet
    anlegen" erstelltes Fahrzeug wird auch im Tablet angelegt
    (`Vehicles.CreateFromWebsite`, Payload
    `{plate, name, model, vehicleClass, mileage}`) - `plate` ist dabei der
    gemeinsame Schlüssel, über den sich beide Seiten automatisch
    zurückverknüpfen (kein Konflikt möglich, da die Website Fahrzeuge
    grundsätzlich über das Kennzeichen statt einer erst später bekannten
    Tablet-ID sucht).
  - `archive_vehicle` - wird ein mit dem Tablet verknüpftes Fahrzeug auf
    der Website gelöscht, archiviert das Tablet-Fahrzeug entsprechend
    (`Vehicles.ArchiveFromWebsite`, Payload `{plate}`) - kein hartes
    SQL-Löschen, aus demselben Grund wie bei `deactivate_employee`.

**Einrichtung**:

1. Auf der Website die Umgebungsvariable `TABLET_API_KEY` auf einen langen
   Zufallsstring setzen.
2. In `config.lua` den `Config.Website`-Block ausfüllen:
   ```lua
   Config.Website = {
       enabled = true,
       baseUrl = 'https://deine-domain.de', -- Basis-URL der Website, ohne trailing slash
       apiKey = '<derselbe Wert wie TABLET_API_KEY>',
       pollIntervalMs = 5000,
       driverHoursReportIntervalMs = 60000,
   }
   ```
4. Im Reiter "Rollen" jeder Tablet-Rolle, deren Mitarbeiter auf der Website
   erscheinen sollen, über das neue Dropdown "Website-Rolle" eine der 9
   festen Website-Rollen zuordnen. **Ohne diese Zuordnung wird kein
   Mitarbeiter dieser Rolle synchronisiert** - es gibt keine Rätselraten-
   Automatik, welche Website-Rolle gemeint sein könnte.
5. Optional: im Mitarbeiter-Bereich je Konto eine Discord-ID hinterlegen, um
   das Tablet-Konto mit dem zugehörigen Discord-OAuth-Login auf der Website
   zu verknüpfen.

**Bekannte Einschränkungen**: das Tablet führt für die Lenkzeit nur eine
Tageshistorie (keine Wochenhistorie) - die Wochensumme auf der Fahrerkarte
der Website wird daher von der Website selbst aus den täglichen Meldungen
hochgerechnet (Tageswechsel erkannt an ihrer eigenen Systemuhr, Reset jeweils
Montag), nicht 1:1 vom Tablet übernommen; bei stark unterschiedlichen
Zeitzonen zwischen Tablet-Server und Website-Server kann das um wenige
Stunden abweichen. Der grobe, 6-stufige Auftragsstatus der Website ist eine
vereinfachte Abbildung des 10-stufigen Tablet-Status. Ein komplett **neues**
Fahrzeug von der Website aus im Spiel
erscheinen zu lassen ist bewusst nicht umgesetzt (kein echtes FiveM-Spawn-
Modell von der Website aus wählbar) - nur Statusänderungen an bereits
existierenden, Tablet-verknüpften Fahrzeugen laufen in beide Richtungen.
Ein Website-Ausfall blockiert niemals das Tablet - fehlgeschlagene
Requests werden nur geloggt (inkl. der eigentlichen Fehlermeldung der
Website, nicht nur des HTTP-Status).
