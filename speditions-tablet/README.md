# speditions-tablet

Standalone FiveM-Ressource für ein vollständiges Speditions-Tablet: Fahrer-,
Disponenten- und Fuhrparkmanagement inklusive Unternehmensfinanzen, Auszahlungen
und Aktivitätsprotokoll. Kein Framework (ESX/QBCore) erforderlich - Rollen und
Berechtigungen werden vollständig serverseitig über eine eigene Datenbank
verwaltet.

## Voraussetzungen

- [oxmysql](https://github.com/overextended/oxmysql)
- MySQL/MariaDB-Datenbank

## Installation

1. Ressource nach `resources/[speditions]/speditions-tablet` kopieren.
2. `sql/install.sql` in die Datenbank importieren (bei einer bereits
   bestehenden Installation stattdessen der Reihe nach `sql/upgrade_v2.sql`
   dann `sql/upgrade_v3.sql` ausführen, um Lenk-/Ruhezeiten, Gefahrgut,
   das Login-System und Ein-/Auszahlungen nachzurüsten).
3. In `server.cfg`:
   ```
   ensure oxmysql
   ensure speditions-tablet
   ```
4. `config.lua` anpassen (siehe unten) - insbesondere `Config.CompanyName`,
   `Config.Locations` und `Config.InitialAccounts`.
5. Server starten.

## Anmeldung (Login-System)

Das Tablet hat ein **eigenes Benutzername/Passwort-Login**, unabhängig vom
FiveM-Charakter - ein Mitarbeiter meldet sich aktiv am Tablet an (wie bei
echter Unternehmenssoftware), statt automatisch über seine Spieler-ID/seinen
Charakter erkannt zu werden. Das hat zwei praktische Vorteile: Mehrere
Personen können sich am selben Terminal mit unterschiedlichen Konten
anmelden, und die Geschäftsführung kann Konten für Personen anlegen, die
gerade gar nicht online sind (Zugangsdaten werden z.B. per Discord
weitergegeben).

**Erstes Konto (Ersteinrichtung):**
`Config.InitialAccounts` in `config.lua` wird beim ersten Ressourcenstart
automatisch angelegt, falls der Benutzername noch nicht existiert:
```lua
Config.InitialAccounts = {
    { username = 'admin', password = 'ChangeMe123!', role = 'geschaeftsfuehrung', name = 'Administrator' },
}
```
**Wichtig:** Nach dem ersten Login unbedingt über den Schlüssel-Button oben
im Tablet das Passwort ändern!

**Weitere Konten anlegen** - zwei Wege:
- Über das Tablet: Geschäftsführung → Tab **Mitarbeiter** → "+ Mitarbeiter
  einstellen" (Name, Benutzername, Passwort, Rolle - die Zielperson muss
  dafür nicht online sein).
- Über die Server-Konsole (auch nutzbar, um sich selbst auszusperren zu
  vermeiden, oder mit der Ace-Permission `speditions.admin`):
  ```
  tablet_grant [benutzername] [passwort] [fahrer|disponent|geschaeftsfuehrung] [Anzeigename...]
  ```
  Legt das Konto an oder aktualisiert Rolle + Passwort, falls der
  Benutzername schon existiert.

**Sicherheitshinweis:** Passwörter werden serverseitig per `SHA2(passwort || salt, 256)`
über MySQL gehasht (`server/sv_bootstrap.lua`) - es gibt keine
Crypto-Bibliothek in reinem Lua/FiveM ohne Zusatzabhängigkeit. Das ist für
den Spielkontext ausreichend, aber kein Enterprise-Auth-Standard (kein
bcrypt/Argon2, keine Rate-Limits gegen Brute-Force). Vergib keine echten,
wiederverwendeten Passwörter.

## Bedienung

- `/tablet` (Standard-Keybind `F6`, in den Keybindings des Spielers
  änderbar) öffnet/schließt das Tablet.
- Andere Ressourcen können das Tablet auch selbst öffnen, z.B. aus einem
  Inventar-Item-Handler:
  ```lua
  exports['speditions-tablet']:OpenTablet()
  ```

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
st_employees            Mitarbeiterstammdaten (Rolle, Status, username/password_hash fürs Login)
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
```

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
- `Config.InitialAccounts`, `Config.AdminAcePermission` - Login-Ersteinrichtung

## Architektur

- `server/sv_rpc.lua` - zentraler, einziger Einstiegspunkt für alle
  NUI-Aktionen (`speditions-tablet:server:rpc`), inkl. serverseitiger
  Rollenprüfung pro Aktion.
- `server/sv_bootstrap.lua` - Benutzername/Passwort-Login (Hashing, Session
  je Server-Slot), Ersteinrichtung, `tablet_grant`-Command.
- `server/sv_finance.lua` - Transaktions-Ledger, Guthaben, Ein-/Auszahlungen.
- `server/sv_vehicles.lua` - Fuhrparkverwaltung.
- `server/sv_drivers.lua` - Fahrerkarte, Fahrerakte, Statistik.
- `server/sv_hours.lua` - Lenk-/Ruhezeiten-Tracking, Warnungen, Erinnerungen.
- `server/sv_orders.lua` - Auftragsgenerierung & -lebenszyklus, Gefahrgut-Prüfung,
  Auto-Wegpunkte.
- `server/sv_employees.lua` - Mitarbeiterverwaltung, Passwort setzen/ändern.
- `server/sv_notifications.lua` - Nachrichten Disponent/Fahrer.
- `client/cl_main.lua` - NUI-Steuerung, RPC-Relay (`ServerCall` auch für
  andere Client-Skripte nutzbar) sowie native In-Game-Hinweise/Wegpunkte sind hier verdrahtet.
- `client/cl_hours.lua` - Erkennt per Kennzeichen-Abgleich, ob der Fahrer
  gerade sein zugewiesenes Firmenfahrzeug fährt, und meldet Fahrzeit an den Server.
- `html/` - NUI-Frontend (Sperrbildschirm, rollenbasierte Ansichten, siehe
  `js/app.js`). Der Client führt dabei keine Geschäftslogik aus - jede Aktion
  wird serverseitig neu geprüft.

Das System ist modular aufgebaut: neue Auftragstypen, zusätzliche
Fahrzeugklassen oder weitere Rollen-Berechtigungen lassen sich über
`config.lua` und zusätzliche RPC-Handler erweitern, ohne bestehende Module
anzufassen.
