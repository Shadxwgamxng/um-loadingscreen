# speditions-tablet

Standalone FiveM-Ressource für ein vollständiges Speditions-Tablet: Fahrer-,
Disponenten- und Fuhrparkmanagement inklusive Unternehmensfinanzen, Auszahlungen
und Aktivitätsprotokoll. Kein Framework (ESX/QBCore) erforderlich - Rollen und
Berechtigungen werden vollständig serverseitig über eine eigene Datenbank
verwaltet.

## Voraussetzungen

- [oxmysql](https://github.com/overextended/oxmysql)
- MySQL/MariaDB-Datenbank
- Optional: [pma-voice](https://github.com/AvarianKnight/pma-voice) für den CB-Funk (siehe unten) - ohne pma-voice wird das Bedienfeld weiterhin angezeigt und lässt sich bedienen, hat aber keine echte Audio-Wirkung.

## Installation

1. Ressource nach `resources/[speditions]/speditions-tablet` kopieren.
2. `sql/install.sql` in die Datenbank importieren (bei einer bereits
   bestehenden Installation stattdessen der Reihe nach `sql/upgrade_v2.sql`
   bis `sql/upgrade_v14.sql` ausführen, um Lenk-/Ruhezeiten, Gefahrgut,
   Ein-/Auszahlungen, Gehälter/Stempeluhr, den Lieferschein, die
   Fahrerkarten-Pflicht, die Abbruch-Anfragen, das Tablet-eigene Login
   (Name + Passwort), die frei anlegbaren Rollen, den optionalen
   Website-Sync (siehe unten), Orte und Anhänger (siehe unten) sowie den
   Gehälter-Bugfix für frei angelegte Rollen nachzurüsten).
   **`sql/upgrade_v7.sql` löscht dabei alle bestehenden Aufträge** - siehe
   Kommentar am Anfang der Datei für den Grund. **Ab sofort werden Aufträge
   ohnehin bei JEDEM Ressourcenstart automatisch geleert** (siehe unten).
   **`sql/upgrade_v9.sql` setzt bei bestehenden Mitarbeiterkonten noch KEIN
   Passwort** - siehe Kommentar am Anfang der Datei und den Abschnitt
   "Mitarbeiter anmelden" unten. `sql/upgrade_v10.sql` legt die drei
   mitgelieferten Basisrollen beim nächsten Ressourcenstart automatisch mit
   ihren bisherigen Berechtigungen an - am Verhalten bestehender
   Installationen ändert sich dadurch zunächst nichts. `sql/upgrade_v13.sql`
   legt nur die neuen Tabellen/Spalten an - die mitgelieferten Standardorte
   (`Config.SeedLocations`) werden beim nächsten Ressourcenstart automatisch
   eingetragen, siehe Abschnitt "Orte" unten. **`sql/upgrade_v14.sql` ist
   Pflicht, sobald du im Rollen-Editor mindestens eine eigene Rolle über die
   drei mitgelieferten Basisrollen hinaus angelegt hast** - ohne dieses
   Upgrade schlägt das Setzen eines Stundenlohns für so eine Rolle im Reiter
   "Gehälter" mit einem Datenbankfehler fehl (`st_wage_rates.role` war noch
   ein festes ENUM aus den Anfängen des Gehaltssystems). `sql/upgrade_v15.sql`
   ist nur relevant, falls auf der Website noch veraltete/doppelte Orte
   auftauchen (siehe Abschnitt "Orte" unten) - leert `st_locations` einmalig,
   damit die 59 echten Standardorte danach sauber neu eingetragen werden.
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

### Tablet nur per Item öffnen

`Config.RequireItem = { enabled = true, itemName = 'essence' }` deaktiviert
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

### Auftrags-Selbstzuweisung ohne Disponent

Ist gerade weder ein Disponent noch die Geschäftsführung online (bzw. hat
das Tablet in der aktuellen Verbindung noch nicht geöffnet), können Fahrer
sich einen offenen Auftrag im "Offener Auftragspool"-Bereich unter "Meine
Aufträge" selbst zuweisen ("Übernehmen"). Sobald wieder jemand mit
Dispositionsrecht online ist, wird der Button gesperrt und die normale
Disposition greift wieder. Siehe `Orders.SelfAssign` in `server/sv_orders.lua`.

### CB-Funk

Bindet an [pma-voice](https://github.com/AvarianKnight/pma-voice) an (Exports
`setRadioChannel`/`setRadioVolume`/`setCallChannel`). Ein-/Ausschalten läuft
ausschließlich über den Knopf oben im Tablet - danach bleibt das Bedienfeld
auch bei geschlossenem Tablet sichtbar, verschiebbar (Ziehpunkt in der
Bezel-Fläche) und über den Ziehpunkt unten rechts in der Größe änderbar. Um
es zu bedienen (ziehen, Größe ändern, Kanal 01-09, Lautstärke, Stumm),
während das Tablet geschlossen ist (z.B. während der Fahrt),
`Config.CbRadio.interactKey` (Standard `F7`) EINMAL DRÜCKEN schaltet den
Mauszeiger dafür an, nochmal drücken wieder aus - kein Gedrückthalten, damit
man nie "hängen" bleiben kann. Reagiert die Taste nicht: in den
FiveM-Einstellungen unter "Tastenbelegung" nach "CB-Funk" suchen, ein
anderes Skript könnte dieselbe Taste bereits belegt haben. Ist das Tablet
ohnehin offen, ist das Funkgerät automatisch mitbedienbar. Sprechen
(Push-to-Talk) läuft über pma-voice's eigene Standard-Taste, sobald ein
Kanal eingestellt ist - dafür baut dieses Skript nichts Eigenes.

**Fehlerdiagnose "CB-Funk geht nicht/kein Ton":** Ist `pma-voice` nicht
gestartet (falscher Ressourcenname, Absturz, o.ä.), meldet `client/cl_radio.lua`
das jetzt einmalig deutlich statt komplett stillzuschweigen: eine `^1`-Zeile
in der Client-Konsole (F8) mit dem tatsächlichen `GetResourceState('pma-voice')`-Wert,
zusätzlich ein In-Game-Warnhinweis beim Einschalten des Funkgeräts. Das
behebt nicht die eigentliche Ursache (meist läuft `pma-voice` gar nicht oder
unter anderem Namen) - prüfe in dem Fall `ensure pma-voice` in `server.cfg`
und ob die Ressource beim Start tatsächlich fehlerfrei durchläuft.

**Fehlerdiagnose "pma-voice lehnt die Kanalwahl ab"** (Serverkonsole zeigt
`pma-voice:radioChangeRejected`): **zuerst** in `server.cfg` prüfen, ob dort
irgendwo `setr voice_enableRadios 0` (oder `0` ohne `setr`) gesetzt ist - der
pma-voice-Standardwert ist `1` (aktiviert), auf manchen server.cfg-Vorlagen
wird er aber explizit auf `0` überschrieben, was **jeden** Kanalwechsel jedes
Skripts ablehnt, unabhängig von Fremd-Skripten. Fehlt der Eintrag oder steht
er auf `0`, `setr voice_enableRadios 1` ergänzen/ändern und Server neu
starten. Bleibt der Fehler danach bestehen, lehnt pma-voice einen Kanal
ausschließlich dann ab, wenn ein ANDERES, zusätzlich installiertes Skript
über den pma-voice-Export `addChannelCheck(channel, cb)` einen eigenen
Zugriffs-Check für diesen Kanal registriert hat und dessen Callback für den
Charakter `false` zurückgibt (z.B. ein separates Funkgerät-Item-System) -
dieses Tablet registriert selbst keinen solchen Check. pma-voice loggt jede
`addChannelCheck`-Registrierung mit dem Namen der verantwortlichen Ressource,
aber **nur wenn `voice_debugMode` auf mindestens `1` steht** (Standard `0` =
unsichtbar). In `server.cfg`:
```
setr voice_debugMode 1
```
setzen, Server neu starten und im **kompletten** Startkonsolen-Log (nicht
erst beim Fehler selbst) nach `added a check to channel` suchen - die dort
genannte Ressource ist die tatsächliche Ursache und muss auf deren eigener
Seite konfiguriert/deaktiviert werden, das kann dieses Tablet nicht
beeinflussen. Taucht dort trotz aktiviertem `voice_debugMode` gar keine
Zeile auf, läuft vermutlich ein abweichender pma-voice-Fork/eine alte
Version mit anderer Ablehnungslogik - in dem Fall die pma-voice-Version
selbst prüfen/aktualisieren.

**Sounds:** `html/sounds/ptt.m4a` beim Beginn/Ende des eigenen Sprechens
(pma-voice-Event `radioActive`), `channel_switch.m4a` beim Kanalwechsel,
`incoming_call.m4a` als Dauerschleife, solange ein Anruf klingelt - stoppt
sofort bei Annahme/Ablehnung/Auflegen. Eigene Dateien austauschbar, gleicher
Dateiname genügt.

**Anrufe:** Die Geschäftsführung/Disponenten können Fahrer über den
"📞 Anrufen"-Button in der Fahrerübersicht direkt anrufen - nur möglich,
wenn der Fahrer online, am Tablet erkannt und sein CB-Funk eingeschaltet
ist. Der Anruf läuft über einen eigenen, privaten pma-voice-Call-Kanal
(komplett getrennt vom normalen Funkkanal - das gewohnte Mithören auf dem
eingestellten Kanal wird dadurch nicht gestört). Beim Fahrer klingelt es am
CB-Funk: die zwei rechten Knöpfe werden zu **Ablehnen (rot)** und
**Annehmen (grün)**; nach Annahme wird der rote Knopf zum Auflegen. Klingelt
`Config.CbRadio.callRingSeconds` (Standard 20s) lang niemand ran, wird
automatisch aufgelegt.

**Hinweis zum Design:** Auf Wunsch orientiert sich das Bedienfeld an einem
mitgeschickten Foto eines physischen CB-Funkgeräts (Lautstärke-Knopf links,
Display mit Kanalanzeige, "MUTE CTCSS"-Taste, die zwei rechten Knöpfe,
CH-Wippe unten rechts) - da das Originalfoto selbst nicht als Bilddatei in
die Ressource übernommen werden konnte, ist es als CSS/HTML-Nachbau
umgesetzt, keine Bilddatei. Die übrigen im Foto vorhandenen, aber nicht
benötigten Tasten (AM/FM MENU, EMG/VOX, SCAN/MSCAN, MEM/MSAVE) sind rein
dekorativ nachgebaut und ohne Funktion - es wurden bewusst keine
zusätzlichen Bedienelemente ergänzt. Das Bedienfeld ist immer voll deckend
(nicht durchsichtig), unabhängig davon, ob es gerade bedient wird.

**Anzeige "wer spricht":** Auf dem LCD erscheint der **Tablet-Name** (nicht
der Steam-/Rockstar-Name) des/der gerade auf dem Kanal sprechenden Spieler -
also genau der Name, mit dem sich der jeweilige Mitarbeiter am Tablet
angemeldet hat (`server/sv_radio.lua`, RPC `radio:employeeName`, liest
`Employees.GetLoggedIn`). Ist ein Sprecher am Tablet gerade nicht
angemeldet, erscheint ersatzweise "Spieler #<server-id>". Für den eigenen
Spieler nutzt `client/cl_radio.lua` das offizielle pma-voice-Event
`pma-voice:radioActive`. Für ANDERE Spieler bietet pma-voice selbst kein
eigenes Export/Event an - `cl_radio.lua` hört daher zusätzlich das intern
von pma-voice gefeuerte Event `pma-voice:setTalkingOnRadio` mit
(FiveM-Events sind nicht ressourcen-exklusiv, das ist technisch
unproblematisch), verifiziert direkt im pma-voice-Quellcode
(`client/module/radio.lua`), und löst den Server pro Sprecher (mit
Client-Cache) zum jeweiligen Tablet-Namen auf. Da es sich bei
`setTalkingOnRadio` um ein **internes, nicht offiziell dokumentiertes**
Event von pma-voice handelt, könnte ein zukünftiges pma-voice-Update dessen
Name/Parameter ändern - die Anzeige würde dann stillschweigend leer
bleiben (kein Fehler, aber auch keine automatische Warnung).

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
| `dispatch` | Disposition (Fahrerübersicht, Auftragspool disponieren, Fahrer kontaktieren, Umsatzübersicht) |
| `fleet_manage` | Fuhrparkverwaltung (Fahrzeuge anlegen/bearbeiten/löschen/zuweisen) UND Anhängerverwaltung (Reiter "Anhänger": anlegen/bearbeiten/löschen/an-/umkuppeln) |
| `locations_manage` | Orte verwalten (Reiter "Orte": Be-/Entladepunkte anlegen/bearbeiten/löschen) |
| `employees_manage` | Mitarbeiterverwaltung (einstellen, Rolle/Status ändern, Passwörter zurücksetzen, Fahrerakten) |
| `roles_manage` | Rollen & Berechtigungen verwalten |
| `finance_view` | Finanzen einsehen (Umsatz, Transaktionen, Aus-/Einzahlungshistorie) |
| `finance_payout` | Aus-/Einzahlungen durchführen |
| `wages_manage` | Gehälter/Stundenlöhne verwalten & auszahlen |
| `activity_log_view` | Aktivitätsprotokoll einsehen |
| `stats_view` | Übersicht/Statistik-Dashboard einsehen |

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
deiner Datenbank schon, bekommt sie `driver_actions` NICHT automatisch
nachgetragen. Öffne dafür einmalig den Reiter "Rollen", wähle
Geschäftsführung und hake "Fahrerfunktionen" mit an.

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
  Button **"Lenkzeit erinnern"** in der Fahrerübersicht erinnern.
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
aber nie andere Namen. Einmalig `sql/upgrade_v15.sql` ausführen (leert
`st_locations` komplett - eigene, im Tablet nachträglich angelegte Orte
gehen dabei mit verloren) und die Ressource neu starten, danach wird
automatisch sauber aus `Config.SeedLocations` neu befüllt und über
`locations.sync` an die Website gemeldet.

Jeder Ort trägt Frachtarten-Tags (Quelle = hier abholbare Fracht, Ziel = hier
anlieferbare Fracht); die automatische Auftragsgenerierung wählt nur
Frachtarten, für die es mindestens einen passenden Start- **und**
Zielstandort gibt, und berechnet Distanz/Wert aus der echten
Luftlinienentfernung der Koordinaten. Wird ein Ort gelöscht, der noch als
Start-/Zielpunkt eines offenen Auftrags referenziert ist, bleibt der Auftrag
bestehen - nur Wegpunkt/Bodenmarker lassen sich für ihn dann nicht mehr
auflösen (kein Fehler, der Auftrag lässt sich weiterhin normal abschließen).

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

Jede Frachtart verlangt anhand von `Config.CargoTrailerType` einen
bestimmten Anhängertyp (Gefahrgut → Curtainsider mit Gefahrgutzulassung,
Lebensmittel/Kühlware → Kühlanhänger, Schüttgut wie Baustoffe/Schrott →
Kipper, Flüssigfracht wie Öl/Kraftstoff → Tankanhänger, alles andere →
normaler Curtainsider). Disponieren/Selbstzuweisen/Neuzuweisen wird
**serverseitig verweigert**, wenn am zugewiesenen Fahrzeug kein Anhänger vom
geforderten Typ hängt (`vehicle_missing_trailer`) - exakt wie die
bestehende Gefahrgut-Berechtigungsprüfung bei Fahrern.

- **Bodenmarker statt NPC**: An einem Standort, der gerade zu einem aktiven
  Auftrag gehört (Beladepunkt eines "in Anfahrt"-Auftrags, oder Zielort
  eines "beladen"-Auftrags), zeichnet das Spiel bei Nähe
  (`Config.LocationMarkerRadius`, Standard 60m) einen blauen Kreis auf dem
  Boden als Interaktionsstelle. Bewusst **kein NPC** (die
  Pedestrian-KI/Interaktion war zu unzuverlässig) - der Marker ist rein
  visuell, keine Entity, kein Kollisionsverhalten.
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
  einen ausführlichen Lieferschein: Ware, Menge/Einheit
  (`Config.CargoUnits`), Gefahrgut-Kennzeichnung, Entfernung, Abhol-/Zielort
  samt GPS-Koordinaten, zugewiesenes Fahrzeug, Ausstellungsdatum,
  disponierender Mitarbeiter und Lieferfrist.
- **"Auftrag generieren"-Testbutton**: Im Reiter "Aufträge" (offener
  Auftragspool) erzeugt ein Fahrer per Klick sofort einen neuen Testauftrag,
  unabhängig vom automatischen Intervall - gesteuert über
  `Config.AllowManualOrderGeneration` (Standard `true`; für den Live-Betrieb
  auf `false` stellen, dann verschwindet der Button).
- **Bekannte Einschränkungen**: Die Zeit- und Nähe-Prüfung für das Be-/
  Entladen läuft ausschließlich clientseitig (kein serverseitiger Schutz vor
  Manipulation der lokalen Wartezeit) - für ein PvE-Logistikfeature wie
  dieses als ausreichend eingeschätzt, bei Bedarf aber erweiterbar. Für jede
  der 14 Frachtarten aus `Config.CargoTypes` ist unter den mitgelieferten 59
  Standardstandorten mindestens eine Quelle **und** ein Ziel hinterlegt -
  löschst du im Reiter "Orte" den einzigen Quell- oder Zielort einer
  Frachtart, wird diese Frachtart bis zum Anlegen eines Ersatzorts nicht
  mehr für automatisch generierte Aufträge ausgewählt.
- **Gefahrgut-Zugriffsbeschränkung**: Frachtarten in `Config.HazardousCargo`
  erzeugen Aufträge mit `requires_permission = 'gefahrgut'`. Das Disponieren
  und Neuzuweisen an Fahrer ohne die Fahrerberechtigung "Gefahrgut" wird
  **serverseitig verweigert** (`driver_missing_permission`); die
  Disponenten-Oberfläche blendet ungeeignete Fahrer in der Zuweisungsauswahl
  zusätzlich aus.

### Auftrags-Reset bei jedem Neustart

Bei jedem Ressourcenstart (Server-Neustart, `/refresh` + `ensure`, oder ein
manueller Neustart der Ressource) werden **alle im Spiel entstandenen
Aufträge** (automatisch generiert oder von einem Disponenten manuell
angelegt, inkl. Verlauf und Abbruch-Anfragen) automatisch gelöscht - so
startet jede Session mit einem sauberen Auftragspool. **Von der Website aus
angelegte Aufträge (`source = 'website'`) überleben einen Neustart** und
bleiben inkl. ihres aktuellen Status/Verlaufs erhalten, damit ein
Website-Auftrag nicht verloren geht, bevor ihn im Spiel überhaupt jemand
gesehen/disponiert hat. Fahrerstatistik und Transaktions-Ledger bleiben
davon unberührt.

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

## Datenbankschema

Siehe `sql/install.sql`. Wichtigste Tabellen:

```
st_roles                Frei anlegbare Rollen (Rollenschlüssel, Bezeichnung, Berechtigungen als JSON, Basisrolle ja/nein)
st_employees            Mitarbeiterstammdaten (Login-Name, Passwort-Hash/Salt, Rolle, Status, zuletzt bekannter FiveM-Charakter nur informativ)
st_drivers              Fahrer-Zusatzdaten (Status, Notizen, Fahrzeugzuweisung, Fahrerkarte eingesteckt/seit)
st_driver_permissions   Führerscheinklassen / Sonderberechtigungen
st_driver_statistics    Aggregierte Fahrerstatistik (aus st_orders berechnet)
st_locations            Be-/Entladepunkte (Reiter "Orte"), Erstbefüllung aus Config.SeedLocations
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
  für den Be-/Entladevorgang; `Config.CargoUnits` - Mengeneinheit je
  Frachtart für den Lieferschein
- `Config.TrailerTypes` - Katalog der fünf Anhängertypen (Reiter "Anhänger");
  `Config.CargoTrailerType` - welche Frachtart welchen Anhängertyp verlangt
- `Config.OrderGeneration` - Intervall und maximale Poolgröße
- `Config.AllowManualOrderGeneration` - blendet den "Auftrag generieren"-Testbutton für Fahrer ein (Standard `true`, für Live-Betrieb auf `false` stellen)
- `Config.OrderCancelPenalty` - Vertragsstrafe (Standard 500$), wenn ein Fahrer einen Auftrag ohne Disponenten-Freigabe selbst abbricht
- `Config.VehicleClasses`, `Config.CargoTypes`, `Config.HazardousCargo`,
  `Config.DriverPermissions`
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
- `server/sv_radio.lua` - CB-Funk ein-/ausschalten, Anrufe (privater pma-voice-Call-Kanal).
- `server/sv_payroll.lua` - Stundenlöhne, Stempeluhr, Gehaltsauszahlung.
- `server/sv_vehicles.lua` - Fuhrparkverwaltung.
- `server/sv_trailers.lua` - Anhängerverwaltung (Reiter "Anhänger"): CRUD auf
  `st_trailers`, An-/Umkuppeln an Fahrzeuge.
- `server/sv_drivers.lua` - Fahrerkarte, Fahrerakte, Statistik, Fahrerkarte einstecken/abziehen (Schicht).
- `server/sv_hours.lua` - Lenk-/Ruhezeiten-Tracking, Warnungen, Erinnerungen.
- `server/sv_orders.lua` - Auftragsgenerierung & -lebenszyklus
  (disponiert → angenommen → anfahrt → beladen → entladen → abgeschlossen),
  Gefahrgut-Prüfung, Anhängertyp-Prüfung (`vehicle_missing_trailer`),
  Auto-Wegpunkte, Standort-/Frachtart-Zuordnung + GPS-Koordinaten für Lieferschein,
  Abbruch-Anfragen mit Disponenten-Genehmigung/Vertragsstrafe, Auftrags-Reset bei Ressourcenstart.
- `server/sv_employees.lua` - Mitarbeiterverwaltung (Einstellen, Rolle/Status
  ändern, beliebige im Tablet angelegte Rollen zuweisbar).
- `server/sv_notifications.lua` - Nachrichten Disponent/Fahrer.
- `server/sv_website_bridge.lua` - Optionaler Website-Sync (siehe eigener
  Abschnitt unten), komplett inaktiv solange `Config.Website.enabled = false`.
- `client/cl_main.lua` - NUI-Steuerung, RPC-Relay (`ServerCall` auch für
  andere Client-Skripte nutzbar) sowie native In-Game-Hinweise/Wegpunkte sind hier verdrahtet.
- `client/cl_hours.lua` - Erkennt per Kennzeichen-Abgleich, ob der Fahrer
  gerade sein zugewiesenes Firmenfahrzeug fährt, und meldet Fahrzeit an den Server.
- `client/cl_radio.lua` - CB-Funk, bindet an pma-voice an (Kanal/Lautstärke/Stumm, Anzeige "wer spricht").
- `client/cl_orders.lua` - Bodenmarker an relevanten Standorten aus dem
  Reiter "Orte" (kein NPC), Be-/Entladen per Taste E mit Fortschrittsbalken.
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

- **Push** (Tablet → Website): bei jeder relevanten Änderung (Auftrag
  disponiert/angenommen/abgeschlossen/**neu angelegt**, Fahrzeug
  angelegt/geändert, Mitarbeiter eingestellt/Rolle geändert, periodische
  Lenkzeiten-Meldung) schickt `server/sv_website_bridge.lua` sofort einen
  Webhook an `.../api/tablet/webhook`. Einmalig beim Ressourcenstart UND bei
  jeder Änderung im Reiter "Orte" (angelegt/bearbeitet/gelöscht) wird
  zusätzlich `locations.sync` gepusht - meldet die gültigen Standortnamen/
  Frachtarten (`Locations.List()`/`Config.CargoTypes`), Grundlage für die
  Standort-Auswahl beim Anlegen neuer Aufträge auf der Website.
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
  zurückgemeldet. Befehlstypen:
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

**Einrichtung**:

1. `sql/upgrade_v11.sql` und `sql/upgrade_v12.sql` importieren (ergänzt
   `st_employees.discord_id`, `st_roles.website_role_key` sowie den Wert
   `'website'` für `st_orders.source`) - bei einer Neuinstallation ist das
   bereits in `sql/install.sql` enthalten.
2. Auf der Website die Umgebungsvariable `TABLET_API_KEY` auf einen langen
   Zufallsstring setzen.
3. In `config.lua` den `Config.Website`-Block ausfüllen:
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
