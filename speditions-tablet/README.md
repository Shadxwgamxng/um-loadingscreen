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
   bestehenden Installation stattdessen der Reihe nach `sql/upgrade_v2.sql`,
   `sql/upgrade_v3.sql`, `sql/upgrade_v4.sql` und `sql/upgrade_v5.sql`
   ausführen, um Lenk-/Ruhezeiten, Gefahrgut, Ein-/Auszahlungen und
   Gehälter/Stempeluhr nachzurüsten und das Login-System zu entfernen).
3. In `server.cfg`:
   ```
   ensure oxmysql
   ensure speditions-tablet
   ```
4. `config.lua` anpassen (siehe unten) - insbesondere `Config.CompanyName`
   und `Config.Locations`.
5. Server starten.

## Mitarbeiter erkennen (kein Login-Bildschirm)

Das Tablet hat **keinen Login-Bildschirm**. Ein Mitarbeiter wird automatisch
anhand seines FiveM-Charakters (license-Identifier) erkannt, sobald er das
Tablet öffnet - hat sein Charakter noch kein Mitarbeiterkonto, zeigt das
Tablet stattdessen einen Hinweis, dass die Geschäftsführung ihm eine Rolle
zuweisen muss.

**Erste Rolle vergeben (Ersteinrichtung):** Über die Server-Konsole, während
die Zielperson online ist (auch nutzbar mit der Ace-Permission
`speditions.admin`):
```
tablet_grant [server-id] [fahrer|disponent|geschaeftsfuehrung] [Anzeigename...]
```
Legt das Mitarbeiterkonto für den Charakter dieses Spielers an oder
aktualisiert dessen Rolle, falls bereits eines existiert.

**Weitere Mitarbeiter einstellen** - über das Tablet: Geschäftsführung →
Tab **Mitarbeiter** → "+ Mitarbeiter einstellen" (die Zielperson muss dafür
online sein, wird per Dropdown aus den aktuell online Spielern ausgewählt).

## Bedienung

- `/tablet` (Standard-Keybind `F6`, in den Keybindings des Spielers
  änderbar) öffnet/schließt das Tablet - **außer** `Config.RequireItem.enabled`
  ist aktiv (siehe unten), dann ist der Command/Keybind deaktiviert.
- Andere Ressourcen können das Tablet auch selbst öffnen, z.B. aus einem
  Inventar-Item-Handler:
  ```lua
  exports['speditions-tablet']:OpenTablet()
  ```

### Tablet nur per Item öffnen

`Config.RequireItem = { enabled = true, itemName = 'essence' }` deaktiviert
den freien Command/Keybind komplett - das Tablet öffnet sich dann nur noch,
wenn das konfigurierte Item benutzt wird:
- Mit **ESX** passiert das automatisch über `ESX.RegisterUsableItem`
  (`server/sv_main.lua`), solange `Config.MoneyBridge` (s.u.) ESX findet.
- Mit einem anderen Inventarsystem (ox_inventory, qb-inventory, ...) lässt du
  dein eigenes Item-Skript beim Gebrauch selbst
  `TriggerEvent('speditions-tablet:server:openFromItem')` (server-seitig,
  `source` = der Spieler) feuern.

### Bargeld bei Aus-/Einzahlung

`Config.MoneyBridge = 'esx' | 'qbcore' | 'custom'` (Standard: `'esx'`):
Führt die Geschäftsführung eine **Auszahlung** durch, bekommt sie den Betrag
als echtes Bargeld in die Hand. Damit das nicht zur Geldvermehrung
missbraucht werden kann, zieht eine **Einzahlung** ihr symmetrisch echtes
Bargeld ab (schlägt fehl, wenn nicht genug Bargeld vorhanden ist -
`insufficient_player_cash`). Bei `'custom'` (oder wenn das gewählte
Framework nicht gefunden wird) werden nur die Events
`speditions-tablet:server:cashPayout` / `-cashDeposit` gefeuert, die du in
deinem eigenen Wirtschaftsskript abfangen kannst - `server/sv_bridge.lua`.

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
zusätzlichen Bedienelemente ergänzt.

## Rollen & Berechtigungen

Alle sicherheitsrelevanten Aktionen (Rollenprüfung, Auftragsstatus,
Auszahlungen, Fahrzeugverwaltung, Guthabenänderungen) werden **ausschließlich
serverseitig** validiert (`server/*.lua`). Die NUI kann keine Werte wie
Auszahlungsbeträge oder "Auftrag abgeschlossen" selbst setzen.

| Rolle | Kernrechte |
|---|---|
| LKW-Fahrer | Fahrerkarte, Statuswechsel, Aufträge annehmen/ablehnen, Frachtstatus, Einnahmenübersicht (nur Ansicht), eigenes Fahrzeug, Nachrichten |
| Disponent | Fahrerübersicht, Auftragspool disponieren/neu zuweisen, aktive Aufträge überwachen, Fahrer kontaktieren, Umsatz einsehen (keine Auszahlung, keine Fahrzeugverwaltung) |
| Geschäftsführung | Mitarbeiter-/Fahrerverwaltung, vollständige Fuhrparkverwaltung, Unternehmensfinanzen, Ein-/Auszahlungen, Statistiken, Aktivitätsprotokoll |

Alle Aktionen der Geschäftsführung sowie sicherheitsrelevante Systemereignisse
werden in `st_activity_logs` protokolliert und sind nur für die
Geschäftsführung einsehbar (Tab **Protokoll**).

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
- **Automatische Wegpunkte**: Beim Annehmen eines Auftrags wird automatisch
  ein GPS-Wegpunkt zum Beladepunkt gesetzt, beim Losfahren (Statuswechsel auf
  "Unterwegs") automatisch einer zum Zielort. Die Koordinaten kommen aus
  `Config.Locations` - passe sie unbedingt an die tatsächlichen Lade-/
  Entladepunkte deines Servers an.
- **Gefahrgut-Zugriffsbeschränkung**: Frachtarten in `Config.HazardousCargo`
  erzeugen Aufträge mit `requires_permission = 'gefahrgut'`. Das Disponieren
  und Neuzuweisen an Fahrer ohne die Fahrerberechtigung "Gefahrgut" wird
  **serverseitig verweigert** (`driver_missing_permission`); die
  Disponenten-Oberfläche blendet ungeeignete Fahrer in der Zuweisungsauswahl
  zusätzlich aus.

## Datenbankschema

Siehe `sql/install.sql`. Wichtigste Tabellen:

```
st_employees            Mitarbeiterstammdaten (Rolle, Status, FiveM-Charakter-Identifier)
st_drivers              Fahrer-Zusatzdaten (Status, Notizen, Fahrzeugzuweisung)
st_driver_permissions   Führerscheinklassen / Sonderberechtigungen
st_driver_statistics    Aggregierte Fahrerstatistik (aus st_orders berechnet)
st_vehicles             Fuhrpark
st_vehicle_assignments  Historie der Fahrzeug-Fahrer-Zuweisungen
st_vehicle_history      Fahrzeugereignisse (erstellt, Wartung, Status, Aufträge)
st_orders               Aufträge inkl. Fahrer-/Fahrzeugzuordnung
st_order_stops          Zwischenstopps (optional/erweiterbar)
st_order_history        Audit-Trail je Auftragsstatus
st_transactions         Vollständiges Transaktions-Ledger (Einnahmen/Auszahlungen/Einzahlungen)
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
Bargeld, hier allerdings an den **Mitarbeiter selbst** (nicht an die
ausführende Geschäftsführung), sofern dieser gerade online und am
Tablet erkannt ist.

## Konfiguration

Alle Stellschrauben befinden sich in `config.lua`:

- `Config.CompanyName` - Firmenname auf Sperrbildschirm, Topbar und Fahrerkarte
- `Config.Routes`, `Config.Locations` - Strecken (Distanz/Wertspanne) und die
  dazugehörigen Wegpunkt-Koordinaten für Beladepunkt/Zielort
- `Config.OrderGeneration` - Intervall und maximale Poolgröße
- `Config.VehicleClasses`, `Config.CargoTypes`, `Config.HazardousCargo`,
  `Config.DriverPermissions`
- `Config.AverageSpeedKmh`, `Config.DeadlineBufferMinutes` - Grundlage der
  Pünktlichkeitsberechnung
- `Config.DrivingRules` - Lenk-/Ruhezeiten-Grenzwerte und Heartbeat-Intervall
- `Config.AdminAcePermission` - berechtigt zusätzlich zur Server-Konsole zum Vergeben von Mitarbeiterrollen (`tablet_grant`)
- `Config.RequireItem` - Tablet nur per Item öffnen
- `Config.MoneyBridge` - Framework-Anbindung für Bargeld bei Aus-/Einzahlung
- `Config.NotificationSound` - Klingelton bei nativen In-Game-Hinweisen
- `Config.DefaultHourlyWage` - Stundenlohn je Rolle, nur einmalige Erstbefüllung von `st_wage_rates`

## Architektur

- `server/sv_rpc.lua` - zentraler, einziger Einstiegspunkt für alle
  NUI-Aktionen (`speditions-tablet:server:rpc`), inkl. serverseitiger
  Rollenprüfung pro Aktion.
- `server/sv_bridge.lua` - Optionale Framework-Anbindung (ESX/QBCore) für
  Bargeld bei Aus-/Einzahlung, inkl. ESX-Objekt für `ESX.RegisterUsableItem`.
- `server/sv_bootstrap.lua` - automatische Mitarbeitererkennung anhand des
  FiveM-Charakters (Session je Server-Slot), `tablet_grant`-Command.
- `server/sv_finance.lua` - Transaktions-Ledger, Guthaben, Ein-/Auszahlungen.
- `server/sv_radio.lua` - CB-Funk ein-/ausschalten, Anrufe (privater pma-voice-Call-Kanal).
- `server/sv_payroll.lua` - Stundenlöhne, Stempeluhr, Gehaltsauszahlung.
- `server/sv_vehicles.lua` - Fuhrparkverwaltung.
- `server/sv_drivers.lua` - Fahrerkarte, Fahrerakte, Statistik.
- `server/sv_hours.lua` - Lenk-/Ruhezeiten-Tracking, Warnungen, Erinnerungen.
- `server/sv_orders.lua` - Auftragsgenerierung & -lebenszyklus, Gefahrgut-Prüfung,
  Auto-Wegpunkte.
- `server/sv_employees.lua` - Mitarbeiterverwaltung (Einstellen, Rolle/Status ändern).
- `server/sv_notifications.lua` - Nachrichten Disponent/Fahrer.
- `client/cl_main.lua` - NUI-Steuerung, RPC-Relay (`ServerCall` auch für
  andere Client-Skripte nutzbar) sowie native In-Game-Hinweise/Wegpunkte sind hier verdrahtet.
- `client/cl_hours.lua` - Erkennt per Kennzeichen-Abgleich, ob der Fahrer
  gerade sein zugewiesenes Firmenfahrzeug fährt, und meldet Fahrzeit an den Server.
- `client/cl_radio.lua` - CB-Funk, bindet an pma-voice an (Kanal/Lautstärke/Stumm).
- `html/` - NUI-Frontend (Sperrbildschirm, rollenbasierte Ansichten, siehe
  `js/app.js`). Der Client führt dabei keine Geschäftslogik aus - jede Aktion
  wird serverseitig neu geprüft.

Das System ist modular aufgebaut: neue Auftragstypen, zusätzliche
Fahrzeugklassen oder weitere Rollen-Berechtigungen lassen sich über
`config.lua` und zusätzliche RPC-Handler erweitern, ohne bestehende Module
anzufassen.
