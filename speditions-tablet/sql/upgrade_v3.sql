-- =========================================================
-- speditions-tablet :: Upgrade v2 -> v3
-- Nur für bereits bestehende Installationen. Bei einer frischen
-- Installation genügt install.sql - dieses Skript ist dafür nicht nötig.
--
-- Neu: Eigenes Benutzername/Passwort-Login (ersetzt die automatische
-- Anmeldung über den FiveM-Charakter), Ein-/Auszahlungen.
--
-- WICHTIG: Mitarbeiter, die vor diesem Upgrade automatisch über
-- Config.InitialOwners/Charakter-Identifier angelegt wurden, haben noch
-- KEIN Passwort und können sich nicht einloggen, bis ein Admin ihnen über
-- die Server-Konsole eines zuweist:
--   tablet_grant [benutzername] [passwort] [fahrer|disponent|geschaeftsfuehrung] [Anzeigename]
-- =========================================================

ALTER TABLE `st_employees`
    MODIFY COLUMN `identifier` VARCHAR(64) NULL,
    ADD COLUMN `username` VARCHAR(50) NULL AFTER `identifier`,
    ADD COLUMN `password_hash` VARCHAR(64) NULL AFTER `username`,
    ADD COLUMN `password_salt` VARCHAR(32) NULL AFTER `password_hash`,
    ADD UNIQUE KEY `uq_username` (`username`);

ALTER TABLE `st_transactions`
    MODIFY COLUMN `type` ENUM('einnahme','auszahlung','einzahlung') NOT NULL,
    ADD COLUMN `related_deposit_id` INT UNSIGNED NULL AFTER `related_payout_id`;

CREATE TABLE IF NOT EXISTS `st_deposits` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `amount` DECIMAL(14,2) NOT NULL,
    `reason` VARCHAR(255) NOT NULL,
    `source` VARCHAR(100) NOT NULL DEFAULT 'Bareinzahlung',
    `executed_by` INT UNSIGNED NOT NULL,
    `executed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `transaction_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_deposit_tx` FOREIGN KEY (`transaction_id`) REFERENCES `st_transactions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
