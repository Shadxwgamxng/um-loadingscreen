-- =========================================================
-- speditions-tablet :: Upgrade v3 -> v4
-- Nur für bereits bestehende Installationen. Bei einer frischen
-- Installation genügt install.sql - dieses Skript ist dafür nicht nötig.
--
-- Das Login-System (Benutzername/Passwort) wurde komplett entfernt.
-- Mitarbeiter werden jetzt automatisch anhand ihres FiveM-Charakters
-- erkannt - kein Login-Bildschirm mehr.
--
-- WICHTIG: Dieses Skript LÖSCHT alle bisherigen Mitarbeiterkonten (sie
-- basierten auf dem alten Benutzername/Passwort-System und können nicht
-- automatisch auf einen Charakter übertragen werden). Vergib die Rollen
-- danach über die Server-Konsole neu, während die jeweilige Person online
-- ist:
--   tablet_grant [server-id] [fahrer|disponent|geschaeftsfuehrung] [Anzeigename...]
-- =========================================================

DELETE FROM `st_employees`;

ALTER TABLE `st_employees`
    DROP INDEX `uq_username`;

ALTER TABLE `st_employees`
    DROP COLUMN `username`,
    DROP COLUMN `password_hash`,
    DROP COLUMN `password_salt`,
    MODIFY COLUMN `identifier` VARCHAR(64) NOT NULL,
    ADD UNIQUE KEY `uq_identifier` (`identifier`);
