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
2. `sql/install.sql` in die Datenbank importieren.
3. In `server.cfg`:
   ```
   ensure oxmysql
   ensure speditions-tablet
   ```
4. `config.lua` anpassen (siehe unten).
5. Server starten.

## Ersteinrichtung (erste Geschäftsführung anlegen)

Da die Ressource standalone läuft, gibt es zwei Wege, den/die ersten
Geschäftsführer:in anzulegen:

**Variante A - Config:**
Trage die `license:`-Identifier in `Config.InitialOwners` ein. Beim ersten
Öffnen des Tablets (`/tablet`) wird der Account automatisch als
Geschäftsführung angelegt.

**Variante B - Server-Command:**
```
tablet_grant [serverId] [fahrer|disponent|geschaeftsfuehrung]
```
Kann von der Server-Konsole oder von Spielern mit der Ace-Permission
`speditions.admin` (konfigurierbar über `Config.AdminAcePermission`)
ausgeführt werden.

Die Geschäftsführung kann anschließend über den Tab **Mitarbeiter** weitere
Fahrer, Disponenten und Geschäftsführer:innen einstellen.

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
| Geschäftsführung | Mitarbeiter-/Fahrerverwaltung, vollständige Fuhrparkverwaltung, Unternehmensfinanzen, Auszahlungen, Statistiken, Aktivitätsprotokoll |

Alle Aktionen der Geschäftsführung sowie sicherheitsrelevante Systemereignisse
werden in `st_activity_logs` protokolliert und sind nur für die
Geschäftsführung einsehbar (Tab **Protokoll**).

## Wichtiges Prinzip: Fahrer-Einnahmen

Abgeschlossene Aufträge erzeugen **Einnahmen für das Unternehmen**, nicht für
den Fahrer persönlich. Jede Einnahme und jede Auszahlung wird als eigene,
unveränderliche Transaktion in `st_transactions` gespeichert - es wird niemals
nur ein Kontostand überschrieben. Nur die Geschäftsführung kann über den Tab
**Auszahlungen** Unternehmensguthaben auszahlen; der Betrag wird dabei
serverseitig gegen das tatsächliche Guthaben geprüft.

## Datenbankschema

Siehe `sql/install.sql`. Wichtigste Tabellen:

```
st_employees            Mitarbeiterstammdaten (Rolle, Status)
st_drivers              Fahrer-Zusatzdaten (Status, Notizen, Fahrzeugzuweisung)
st_driver_permissions   Führerscheinklassen / Sonderberechtigungen
st_driver_statistics    Aggregierte Fahrerstatistik (aus st_orders berechnet)
st_vehicles             Fuhrpark
st_vehicle_assignments  Historie der Fahrzeug-Fahrer-Zuweisungen
st_vehicle_history      Fahrzeugereignisse (erstellt, Wartung, Status, Aufträge)
st_orders               Aufträge inkl. Fahrer-/Fahrzeugzuordnung
st_order_stops          Zwischenstopps (optional/erweiterbar)
st_order_history        Audit-Trail je Auftragsstatus
st_transactions         Vollständiges Transaktions-Ledger (Einnahmen/Auszahlungen)
st_company_balance      Performance-Cache des aktuellen Guthabens
st_payouts              Auszahlungen (Betrag, Grund, Zielkonto, ausführender Mitarbeiter)
st_notifications        Nachrichten Disponent -> Fahrer
st_activity_logs        Aktivitätsprotokoll
```

## Konfiguration

Alle Stellschrauben befinden sich in `config.lua`:

- `Config.Routes` - Strecken mit Distanz und Wertspanne für die automatische
  Auftragsgenerierung
- `Config.OrderGeneration` - Intervall und maximale Poolgröße
- `Config.VehicleClasses`, `Config.CargoTypes`, `Config.DriverPermissions`
- `Config.AverageSpeedKmh`, `Config.DeadlineBufferMinutes` - Grundlage der
  Pünktlichkeitsberechnung
- `Config.InitialOwners`, `Config.AdminAcePermission` - Ersteinrichtung

## Architektur

- `server/sv_rpc.lua` - zentraler, einziger Einstiegspunkt für alle
  NUI-Aktionen (`speditions-tablet:server:rpc`), inkl. serverseitiger
  Rollenprüfung pro Aktion.
- `server/sv_bootstrap.lua` - Mitarbeiter-Session-Cache & Ersteinrichtung.
- `server/sv_finance.lua` - Transaktions-Ledger, Guthaben, Auszahlungen.
- `server/sv_vehicles.lua` - Fuhrparkverwaltung.
- `server/sv_drivers.lua` - Fahrerkarte, Fahrerakte, Statistik.
- `server/sv_orders.lua` - Auftragsgenerierung & -lebenszyklus.
- `server/sv_employees.lua` - Mitarbeiterverwaltung.
- `server/sv_notifications.lua` - Nachrichten Disponent/Fahrer.
- `client/cl_main.lua` - NUI-Steuerung und RPC-Relay (Client führt keine
  Geschäftslogik aus).
- `html/` - NUI-Frontend (rollenbasierte Ansichten, siehe `js/app.js`).

Das System ist modular aufgebaut: neue Auftragstypen, zusätzliche
Fahrzeugklassen oder weitere Rollen-Berechtigungen lassen sich über
`config.lua` und zusätzliche RPC-Handler erweitern, ohne bestehende Module
anzufassen.
