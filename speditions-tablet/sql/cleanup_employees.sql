-- =========================================================
-- speditions-tablet :: Mitarbeiter-Bereinigung (optional)
--
-- Löscht ALLE aktuellen Mitarbeiterkonten (inkl. Fahrer-Zusatzdaten,
-- Berechtigungen, Statistik und Lenkzeiten - per ON DELETE CASCADE),
-- OHNE Fahrzeuge, Aufträge oder die Finanzhistorie anzufassen.
--
-- Nützlich, um verwirrende Test-/Doppelkonten (z.B. aus der alten
-- Charakter-basierten Anmeldung) loszuwerden. Beim nächsten
-- Ressourcenstart wird automatisch wieder ein frisches Konto aus
-- Config.InitialAccounts angelegt.
--
-- NUR ausführen, wenn du wirklich ALLE Mitarbeiterkonten neu anlegen
-- willst! Es gibt danach keine Fahrer/Disponenten/Geschäftsführung
-- mehr, bis neue Konten angelegt werden.
-- =========================================================

DELETE FROM `st_employees`;
