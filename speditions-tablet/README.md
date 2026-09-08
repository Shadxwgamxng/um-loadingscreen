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
   bis `sql/upgrade_v10.sql` ausführen, um Lenk-/Ruhezeiten, Gefahrgut,
   Ein-/Auszahlungen, Gehälter/Stempeluhr, den Lieferschein, die
   Fahrerkarten-Pflicht, die Abbruch-Anfragen, das Tablet-eigene Login
   (Name + Passwort) und die frei anlegbaren Rollen nachzurüsten).
   **`sql/upgrade_v7.sql` löscht dabei alle bestehenden Aufträge** - siehe
   Kommentar am Anfang der Datei für den Grund. **Ab sofort werden Aufträge
   ohnehin bei JEDEM Ressourcenstart automatisch geleert** (siehe unten).
   **`sql/upgrade_v9.sql` setzt bei bestehenden Mitarbeiterkonten noch KEIN
   Passwort** - siehe Kommentar am Anfang der Datei und den Abschnitt
   "Mitarbeiter anmelden" unten. `sql/upgrade_v10.sql` legt die drei
   mitgelieferten Basisrollen beim nächsten Ressourcenstart automatisch mit
   ihren bisherigen Berechtigungen an - am Verhalten bestehender
   Installationen ändert sich dadurch zunächst nichts.
3. In `server.cfg`:
   ```
   ensure oxmysql
   ensure speditions-tablet
   ```
4. `config.lua` anpassen (siehe unten) - insbesondere `Config.CompanyName`
   und `Config.Locations` (an die tatsächlichen Firmenstandorte deines
   Servers anpassen).
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
nicht online sein). Ein Passwort vergessen? Geschäftsführung kann es über
den Button "Passwort zurücksetzen" in derselben Übersicht neu setzen.

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
| `live_map_view` | Live-Karte einsehen (Fahrerpositionen, Aufträge, gesetzte Navi-Routen) |
| `fleet_manage` | Fuhrparkverwaltung (Fahrzeuge anlegen/bearbeiten/löschen/zuweisen) |
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
| Disponent | `dispatch`, `live_map_view` |
| Geschäftsführung | alle außer `driver_actions` |

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
- **Automatische Wegpunkte**: Beim Annehmen eines Auftrags wird automatisch
  ein GPS-Wegpunkt zum Beladepunkt gesetzt, beim Losfahren (Statuswechsel auf
  "Unterwegs") automatisch einer zum Zielort. Die Koordinaten kommen aus
  `Config.Locations` - passe sie unbedingt an die tatsächlichen Lade-/
  Entladepunkte deines Servers an.

### Echte Standorte, Be-/Entladen per Bodenmarker, Lieferschein

`Config.Locations` ist eine Liste von 32 Koordinaten (30 reale
Firmenadressen des Servers plus 2 erfundene Möbel-Abholstandorte) statt der
früheren abstrakten Städte-Strecken.
Jeder Standort trägt Frachtarten-Tags (`sourceCargo` = hier abholbare Fracht,
`destCargo` = hier anlieferbare Fracht); die automatische Auftragsgenerierung
wählt nur Frachtarten, für die es mindestens einen passenden Start- **und**
Zielstandort gibt, und berechnet Distanz/Wert aus der echten
Luftlinienentfernung der Koordinaten.

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
- **Fahrerkarte einstecken vor Auftragsannahme**: Ein Fahrer muss im Reiter
  "Fahrerkarte" zuerst seine Fahrt starten ("Fahrerkarte einstecken"), bevor
  er einen Auftrag annehmen kann (`shift_not_started`, serverseitig
  erzwungen in `Orders.AcceptByDriver`) - damit bewusst bestätigt wird, dass
  ab jetzt seine Lenk-/Ruhezeiten laufen. "Fahrerkarte abziehen" beendet die
  Fahrt wieder. Der Zustand wird in `st_drivers.on_shift`/`shift_started_at`
  gespeichert und ist unabhängig vom (automatischen, kennzeichenbasierten)
  Lenkzeit-Tracking selbst - Letzteres läuft weiterhin wie gehabt über
  `client/cl_hours.lua`.
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
- **Wichtig nach diesem Update**: Aufträge, die VOR der Umstellung auf
  `Config.Locations` (echte Standorte) erzeugt wurden, referenzieren
  Standortnamen, die es im neuen System nicht mehr gibt - an ihrem Abhol-/
  Zielort erscheint dann kein Marker und die Taste E funktioniert dort nicht.
  `sql/upgrade_v7.sql` löscht deshalb alle bestehenden Aufträge; danach
  erzeugt entweder der automatische Timer (`Config.OrderGeneration`) oder
  der neue "Auftrag generieren"-Testbutton (s.o.) ausschließlich Aufträge
  mit den neuen, echten Standorten.
- **Bekannte Einschränkungen**: Die Zeit- und Nähe-Prüfung für das Be-/
  Entladen läuft ausschließlich clientseitig (kein serverseitiger Schutz vor
  Manipulation der lokalen Wartezeit) - für ein PvE-Logistikfeature wie
  dieses als ausreichend eingeschätzt, bei Bedarf aber erweiterbar. Für die
  Frachtart `Elektronik` ist unter den 32 vorgegebenen Standorten keine
  Quelle (`sourceCargo`) hinterlegt - sie wird aktuell also nie für
  automatisch generierte Aufträge ausgewählt, bis du in `Config.Locations`
  einen Standort mit `sourceCargo = {'Elektronik'}` ergänzt. (`Möbel` hat
  inzwischen zwei erfundene Abholstandorte: "Möbeltischlerei Hirschweiler"
  und "Zentrallager Box 5 (Möbel)".)
- **Gefahrgut-Zugriffsbeschränkung**: Frachtarten in `Config.HazardousCargo`
  erzeugen Aufträge mit `requires_permission = 'gefahrgut'`. Das Disponieren
  und Neuzuweisen an Fahrer ohne die Fahrerberechtigung "Gefahrgut" wird
  **serverseitig verweigert** (`driver_missing_permission`); die
  Disponenten-Oberfläche blendet ungeeignete Fahrer in der Zuweisungsauswahl
  zusätzlich aus.

### Auftrags-Reset bei jedem Neustart

Bei jedem Ressourcenstart (Server-Neustart, `/refresh` + `ensure`, oder ein
manueller Neustart der Ressource) werden **alle bestehenden Aufträge**
(inkl. Verlauf und Abbruch-Anfragen) automatisch gelöscht - so startet
jede Session mit einem sauberen Auftragspool. Fahrerstatistik und
Transaktions-Ledger bleiben davon unberührt.

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

### Live-Karte (Disposition)

Mit der Berechtigung `live_map_view` (Basisrollen: Disponent und
Geschäftsführung) zeigt der Reiter **Live-Karte** ein live aktualisiertes
Positionsraster (Polling alle 5 Sekunden, `dispatch:liveMap` in
`server/sv_tracking.lua`) aller gerade am Tablet angemeldeten Fahrer:

- **Position**: Wird rein **serverseitig** alle 5 Sekunden per
  `GetEntityCoords` für jeden angemeldeten Mitarbeiter mit der Berechtigung
  `driver_actions` ermittelt - dafür ist **keinerlei Mitwirkung des
  Client-Skripts nötig** (kein eigener Heartbeat-Call, dadurch auch kein
  Risiko von RPC-Fehler-Spam für Mitarbeiter ohne diese Berechtigung).
  Positionen werden nicht in der Datenbank gespeichert, sondern nur
  transient im Arbeitsspeicher gehalten und bei jedem Intervall komplett
  neu aufgebaut - meldet sich ein Fahrer ab oder verlässt den Server,
  verschwindet er beim nächsten Intervall automatisch von der Karte statt
  als veraltete "Geisterposition" stehen zu bleiben.
- **Aufträge**: Zu jedem Fahrer mit einem laufenden Auftrag
  (`angenommen`/`anfahrt`/`beladen`/`entladen`) zeigt die Karte Frachtart
  sowie Abhol-/Zielort.
- **Navi-Route**: Der aktuell gesetzte GPS-Wegpunkt (derselbe, den der
  Fahrer auch tatsächlich in GTA angezeigt bekommt, s.o.) wird als gelber
  Punkt mit gestrichelter Linie zur aktuellen Fahrerposition eingezeichnet.
- **Wichtige Einschränkung**: Es handelt sich bewusst um ein **schematisches
  Positionsraster, kein echtes Kartenbild** - die Ressource bringt keine
  GTA-V-Kartengrafik mit (Lizenz-/Copyright-Gründe). Fahrer UND
  Firmenstandorte (`Config.Locations`, als graue Orientierungspunkte) werden
  auf denselben ungefähren Weltkoordinaten-Bereich der GTA-V-Karte
  (`MAP_BOUNDS` in `html/js/app.js`) abgebildet, sodass die relative Lage
  zueinander stimmt - für ein echtes Kartenbild müsste `drawLiveMap()` in
  `html/js/app.js` um eine selbst eingebundene Kartengrafik erweitert
  werden.

## Datenbankschema

Siehe `sql/install.sql`. Wichtigste Tabellen:

```
st_roles                Frei anlegbare Rollen (Rollenschlüssel, Bezeichnung, Berechtigungen als JSON, Basisrolle ja/nein)
st_employees            Mitarbeiterstammdaten (Login-Name, Passwort-Hash/Salt, Rolle, Status, zuletzt bekannter FiveM-Charakter nur informativ)
st_drivers              Fahrer-Zusatzdaten (Status, Notizen, Fahrzeugzuweisung, Fahrerkarte eingesteckt/seit)
st_driver_permissions   Führerscheinklassen / Sonderberechtigungen
st_driver_statistics    Aggregierte Fahrerstatistik (aus st_orders berechnet)
st_vehicles             Fuhrpark
st_vehicle_assignments  Historie der Fahrzeug-Fahrer-Zuweisungen
st_vehicle_history      Fahrzeugereignisse (erstellt, Wartung, Status, Aufträge)
st_orders               Aufträge inkl. Fahrer-/Fahrzeugzuordnung, Menge/Einheit (Lieferschein)
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
Bargeld, hier allerdings an den **Mitarbeiter selbst** (nicht an die
ausführende Geschäftsführung), sofern dieser gerade online und am
Tablet erkannt ist.

## Konfiguration

Alle Stellschrauben befinden sich in `config.lua`:

- `Config.CompanyName` - Firmenname auf Sperrbildschirm, Topbar und Fahrerkarte
- `Config.Locations` - Liste der echten Firmenstandorte (Koordinaten,
  Frachtarten-Tags `sourceCargo`/`destCargo`) für Auftragsgenerierung,
  Bodenmarker, Be-/Entladen und Wegpunkte; `Config.OrderValuePerKm`,
  `Config.LoadUnloadSeconds`, `Config.LocationMarkerRadius`,
  `Config.LocationInteractRadius` - Wertspanne pro km sowie Timing/Radien
  für den Be-/Entladevorgang; `Config.CargoUnits` - Mengeneinheit je
  Frachtart für den Lieferschein
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
  Bargeld bei Aus-/Einzahlung, inkl. ESX-Objekt für `ESX.RegisterUsableItem`.
- `server/sv_bootstrap.lua` - Tablet-eigenes Login (Name + Passwort,
  Session je Server-Slot in `loggedIn[src]`), Passwort-Hashing,
  `tablet_grant`-Command, Erstkonto-Seeding aus `Config.InitialAccounts`,
  `Employees.RequirePermission` (Berechtigungsprüfung pro Aktion).
- `server/sv_roles.lua` - Rollen & Berechtigungen: frei anlegbare Rollen
  (Erstellen/Bearbeiten/Löschen), Berechtigungsprüfung (`Roles.HasPermission`),
  Erstbefüllung der drei Basisrollen aus `Config.DefaultRolePermissions`.
- `server/sv_tracking.lua` - Live-Karte: liest serverseitig per
  `GetEntityCoords` die Position jedes angemeldeten Fahrers, verknüpft sie
  mit dessen laufendem Auftrag/Wegpunkt für den Reiter "Live-Karte".
- `server/sv_finance.lua` - Transaktions-Ledger, Guthaben, Ein-/Auszahlungen.
- `server/sv_radio.lua` - CB-Funk ein-/ausschalten, Anrufe (privater pma-voice-Call-Kanal).
- `server/sv_payroll.lua` - Stundenlöhne, Stempeluhr, Gehaltsauszahlung.
- `server/sv_vehicles.lua` - Fuhrparkverwaltung.
- `server/sv_drivers.lua` - Fahrerkarte, Fahrerakte, Statistik, Fahrerkarte einstecken/abziehen (Schicht).
- `server/sv_hours.lua` - Lenk-/Ruhezeiten-Tracking, Warnungen, Erinnerungen.
- `server/sv_orders.lua` - Auftragsgenerierung & -lebenszyklus
  (disponiert → angenommen → anfahrt → beladen → entladen → abgeschlossen),
  Gefahrgut-Prüfung, Auto-Wegpunkte, Standort-/Frachtart-Zuordnung + GPS-Koordinaten für Lieferschein,
  Abbruch-Anfragen mit Disponenten-Genehmigung/Vertragsstrafe, Auftrags-Reset bei Ressourcenstart.
- `server/sv_employees.lua` - Mitarbeiterverwaltung (Einstellen, Rolle/Status
  ändern, beliebige im Tablet angelegte Rollen zuweisbar).
- `server/sv_notifications.lua` - Nachrichten Disponent/Fahrer.
- `client/cl_main.lua` - NUI-Steuerung, RPC-Relay (`ServerCall` auch für
  andere Client-Skripte nutzbar) sowie native In-Game-Hinweise/Wegpunkte sind hier verdrahtet.
- `client/cl_hours.lua` - Erkennt per Kennzeichen-Abgleich, ob der Fahrer
  gerade sein zugewiesenes Firmenfahrzeug fährt, und meldet Fahrzeit an den Server.
- `client/cl_radio.lua` - CB-Funk, bindet an pma-voice an (Kanal/Lautstärke/Stumm, Anzeige "wer spricht").
- `client/cl_orders.lua` - Bodenmarker an relevanten Standorten aus
  `Config.Locations` (kein NPC), Be-/Entladen per Taste E mit Fortschrittsbalken.
- `html/` - NUI-Frontend (Sperrbildschirm, berechtigungsbasierte Reiter -
  `NAV_ITEMS`/`buildSidebar` in `js/app.js` -, Rollenverwaltung, Live-Karte
  per `<canvas>`). Der Client führt dabei keine Geschäftslogik aus - jede
  Aktion wird serverseitig neu geprüft, die Reiter-Sichtbarkeit ist reine
  Bequemlichkeit.

Das System ist modular aufgebaut: neue Auftragstypen, zusätzliche
Fahrzeugklassen oder weitere Rollen-Berechtigungen lassen sich über
`config.lua` und zusätzliche RPC-Handler erweitern, ohne bestehende Module
anzufassen.
