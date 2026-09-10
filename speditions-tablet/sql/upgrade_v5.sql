-- =========================================================
-- speditions-tablet :: Upgrade v4 -> v5
-- Nur für bereits bestehende Installationen. Bei einer frischen
-- Installation genügt install.sql - dieses Skript ist dafür nicht nötig.
--
-- Neu: Gehälter. Mitarbeiter stempeln über eine Stempeluhr Arbeitszeit,
-- die Geschäftsführung legt Stundenlöhne je Rolle fest und zahlt das
-- automatisch berechnete Gehalt aus.
-- =========================================================

ALTER TABLE `st_transactions`
    MODIFY COLUMN `type` ENUM('einnahme','auszahlung','einzahlung','gehalt') NOT NULL;

-- Die 3 temporären Test-Konten ("test-account:...") aus der Ausprobier-Phase
-- werden nicht mehr gebraucht, jetzt wo wieder die echte Charaktererkennung
-- läuft.
DELETE FROM `st_employees` WHERE `identifier` LIKE 'test-account:%';

CREATE TABLE IF NOT EXISTS `st_wage_rates` (
    `role` ENUM('fahrer','disponent','geschaeftsfuehrung') NOT NULL,
    `hourly_rate` DECIMAL(10,2) NOT NULL DEFAULT 0,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_timeclock_sessions` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `employee_id` INT UNSIGNED NOT NULL,
    `clock_in_at` DATETIME NOT NULL,
    `clock_out_at` DATETIME NULL,
    `paid_at` DATETIME NULL,
    PRIMARY KEY (`id`),
    KEY `idx_tc_employee` (`employee_id`),
    CONSTRAINT `fk_tc_employee` FOREIGN KEY (`employee_id`) REFERENCES `st_employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_payroll_payouts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `employee_id` INT UNSIGNED NOT NULL,
    `hours` DECIMAL(10,2) NOT NULL,
    `hourly_rate` DECIMAL(10,2) NOT NULL,
    `amount` DECIMAL(14,2) NOT NULL,
    `executed_by` INT UNSIGNED NOT NULL,
    `executed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `transaction_id` INT UNSIGNED NOT NULL,
    `cash_given` TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_payroll_employee` FOREIGN KEY (`employee_id`) REFERENCES `st_employees` (`id`),
    CONSTRAINT `fk_payroll_tx` FOREIGN KEY (`transaction_id`) REFERENCES `st_transactions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
