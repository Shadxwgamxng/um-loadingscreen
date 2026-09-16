-- =========================================================
-- speditions-tablet :: Upgrade v12 -> v13
-- Nur für bereits bestehende Installationen. Bei einer frischen
-- Installation genügt install.sql - dieses Skript ist dafür nicht nötig.
--
-- Orte (Reiter "Orte") und Anhänger (Reiter "Anhänger"):
--   - `st_locations`: ersetzt die frühere feste Config.Locations-Liste.
--     Die Erstbefüllung mit den Standardstandorten übernimmt das
--     Tablet selbst beim nächsten Ressourcenstart aus Config.SeedLocations
--     (analog Config.DefaultRolePermissions) - hier sind bewusst keine
--     INSERTs nötig.
--   - `st_trailers`: Anhänger, die einem Fahrzeug zugeordnet werden
--     können (assigned_vehicle_id).
--   - `st_orders.requires_trailer_type`: geforderter Anhängertyp für
--     einen Auftrag (analog requires_permission für Gefahrgut).
-- =========================================================

CREATE TABLE IF NOT EXISTS `st_locations` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `pos_x` DOUBLE NOT NULL,
    `pos_y` DOUBLE NOT NULL,
    `pos_z` DOUBLE NOT NULL,
    `heading` DOUBLE NOT NULL DEFAULT 0,
    `source_cargo` TEXT NULL,
    `dest_cargo` TEXT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_location_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_trailers` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `type` ENUM('curtainsider','curtainsider_gefahrgut','kipper','kuehlanhaenger','tankanhaenger') NOT NULL,
    `plate` VARCHAR(20) NOT NULL,
    `assigned_vehicle_id` INT UNSIGNED NULL,
    `status` ENUM('verfuegbar','im_einsatz','wartung','defekt','ausser_betrieb') NOT NULL DEFAULT 'verfuegbar',
    `archived` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_trailer_plate` (`plate`),
    KEY `idx_trailer_vehicle` (`assigned_vehicle_id`),
    CONSTRAINT `fk_trailer_vehicle` FOREIGN KEY (`assigned_vehicle_id`) REFERENCES `st_vehicles` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `st_orders`
    ADD COLUMN `requires_trailer_type` ENUM('curtainsider','curtainsider_gefahrgut','kipper','kuehlanhaenger','tankanhaenger') NULL AFTER `requires_permission`;
