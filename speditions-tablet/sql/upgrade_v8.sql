-- =========================================================
-- speditions-tablet :: Upgrade v7 -> v8
-- Nur für bereits bestehende Installationen. Bei einer frischen
-- Installation genügt install.sql - dieses Skript ist dafür nicht nötig.
--
-- Neu: Fahrer können einen aktiven Auftrag über das Tablet abbrechen
-- wollen - ist ein Disponent/GF online, muss der/die den Abbruch erst
-- genehmigen (st_order_cancel_requests); ist niemand online, wird sofort
-- abgebrochen und dem Unternehmen eine Vertragsstrafe (neuer
-- Transaktionstyp) belastet.
-- =========================================================

CREATE TABLE IF NOT EXISTS `st_order_cancel_requests` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `order_id` INT UNSIGNED NOT NULL,
    `driver_id` INT UNSIGNED NOT NULL,
    `reason` VARCHAR(255) NULL,
    `status` ENUM('offen','genehmigt','abgelehnt') NOT NULL DEFAULT 'offen',
    `requested_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `resolved_at` DATETIME NULL,
    `resolved_by` INT UNSIGNED NULL,
    PRIMARY KEY (`id`),
    KEY `idx_ocr_order` (`order_id`),
    CONSTRAINT `fk_ocr_order` FOREIGN KEY (`order_id`) REFERENCES `st_orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `st_transactions`
    MODIFY COLUMN `type` ENUM('einnahme','auszahlung','einzahlung','gehalt','vertragsstrafe') NOT NULL;
