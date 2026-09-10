-- =========================================================
-- speditions-tablet :: Upgrade v1 -> v2
-- Nur für bereits bestehende Installationen. Bei einer frischen
-- Installation genügt install.sql - dieses Skript ist dafür nicht nötig.
--
-- Neu: Lenk-/Ruhezeiten-System, Gefahrgut-Zugriffsbeschränkung.
-- =========================================================

ALTER TABLE `st_orders`
    ADD COLUMN `requires_permission` VARCHAR(50) NULL AFTER `source`;

CREATE TABLE IF NOT EXISTS `st_driver_hours` (
    `driver_id` INT UNSIGNED NOT NULL,
    `continuous_driving_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
    `daily_driving_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
    `day_date` DATE NOT NULL,
    `resting_since` DATETIME NULL,
    `warned_continuous` TINYINT(1) NOT NULL DEFAULT 0,
    `warned_daily` TINYINT(1) NOT NULL DEFAULT 0,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`driver_id`),
    CONSTRAINT `fk_hours_driver` FOREIGN KEY (`driver_id`) REFERENCES `st_drivers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
