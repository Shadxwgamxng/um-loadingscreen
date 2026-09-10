-- =========================================================
-- speditions-tablet :: Upgrade v8 -> v9
-- Nur für bereits bestehende Installationen. Bei einer frischen
-- Installation genügt install.sql - dieses Skript ist dafür nicht nötig.
--
-- Neu: Tablet-eigenes Login (Name + Passwort) statt automatischer
-- Erkennung anhand des FiveM-Charakters. WICHTIG: Bestehende
-- Mitarbeiterkonten haben noch KEIN Passwort - sie können sich erst
-- wieder anmelden, nachdem die Geschäftsführung (oder per
-- `tablet_grant [name] [passwort] [rolle] [Anzeigename]` über die
-- Server-Konsole) ihnen einen Login-Namen samt Passwort vergeben hat.
-- Das erste Konto aus Config.InitialAccounts wird automatisch beim
-- nächsten Ressourcenstart angelegt, falls der Name noch nicht existiert.
-- =========================================================

ALTER TABLE `st_employees`
    ADD COLUMN `username` VARCHAR(50) NULL AFTER `id`,
    ADD COLUMN `password_hash` VARCHAR(255) NULL AFTER `username`,
    ADD COLUMN `password_salt` VARCHAR(32) NULL AFTER `password_hash`,
    MODIFY COLUMN `identifier` VARCHAR(64) NULL;

ALTER TABLE `st_employees` DROP INDEX `uq_identifier`;
ALTER TABLE `st_employees` ADD UNIQUE KEY `uq_username` (`username`);
