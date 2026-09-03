-- =========================================================
-- speditions-tablet :: Datenbankschema
-- =========================================================

CREATE TABLE IF NOT EXISTS `st_employees` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `role` ENUM('fahrer','disponent','geschaeftsfuehrung') NOT NULL DEFAULT 'fahrer',
    `status` ENUM('aktiv','inaktiv') NOT NULL DEFAULT 'aktiv',
    `hired_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_drivers` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `employee_id` INT UNSIGNED NOT NULL,
    `rank` VARCHAR(50) NOT NULL DEFAULT 'Fahrer',
    `notes` TEXT NULL,
    `current_status` ENUM('offline','verfuegbar','im_einsatz','pause') NOT NULL DEFAULT 'offline',
    `assigned_vehicle_id` INT UNSIGNED NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_employee` (`employee_id`),
    CONSTRAINT `fk_drivers_employee` FOREIGN KEY (`employee_id`) REFERENCES `st_employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_driver_permissions` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `driver_id` INT UNSIGNED NOT NULL,
    `permission_key` VARCHAR(50) NOT NULL,
    `granted_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `granted_by` INT UNSIGNED NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_driver_perm` (`driver_id`, `permission_key`),
    CONSTRAINT `fk_permissions_driver` FOREIGN KEY (`driver_id`) REFERENCES `st_drivers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_driver_statistics` (
    `driver_id` INT UNSIGNED NOT NULL,
    `total_orders` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_km` DECIMAL(12,2) NOT NULL DEFAULT 0,
    `successful_deliveries` INT UNSIGNED NOT NULL DEFAULT 0,
    `cancelled_orders` INT UNSIGNED NOT NULL DEFAULT 0,
    `on_time_deliveries` INT UNSIGNED NOT NULL DEFAULT 0,
    `punctuality_rate` DECIMAL(5,2) NOT NULL DEFAULT 0,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`driver_id`),
    CONSTRAINT `fk_stats_driver` FOREIGN KEY (`driver_id`) REFERENCES `st_drivers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_vehicles` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `model` VARCHAR(100) NOT NULL,
    `plate` VARCHAR(20) NOT NULL,
    `vehicle_class` VARCHAR(50) NOT NULL,
    `mileage` INT UNSIGNED NOT NULL DEFAULT 0,
    `fuel` TINYINT UNSIGNED NOT NULL DEFAULT 100,
    `status` ENUM('verfuegbar','im_einsatz','wartung','defekt','ausser_betrieb') NOT NULL DEFAULT 'verfuegbar',
    `vehicle_identifier` VARCHAR(50) NULL,
    `notes` TEXT NULL,
    `archived` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_vehicle_assignments` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `vehicle_id` INT UNSIGNED NOT NULL,
    `driver_id` INT UNSIGNED NULL,
    `assigned_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `unassigned_at` DATETIME NULL,
    `assigned_by` INT UNSIGNED NULL,
    PRIMARY KEY (`id`),
    KEY `idx_va_vehicle` (`vehicle_id`),
    KEY `idx_va_driver` (`driver_id`),
    CONSTRAINT `fk_va_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `st_vehicles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_vehicle_history` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `vehicle_id` INT UNSIGNED NOT NULL,
    `event_type` VARCHAR(50) NOT NULL,
    `description` TEXT NULL,
    `related_order_id` INT UNSIGNED NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_vh_vehicle` (`vehicle_id`),
    CONSTRAINT `fk_vh_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `st_vehicles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_orders` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `cargo` VARCHAR(150) NOT NULL,
    `start_location` VARCHAR(100) NOT NULL,
    `end_location` VARCHAR(100) NOT NULL,
    `distance_km` DECIMAL(10,2) NOT NULL DEFAULT 0,
    `value` DECIMAL(12,2) NOT NULL DEFAULT 0,
    `status` ENUM('offen','disponiert','angenommen','beladen','unterwegs','abgeschlossen','abgebrochen','abgelehnt') NOT NULL DEFAULT 'offen',
    `driver_id` INT UNSIGNED NULL,
    `vehicle_id` INT UNSIGNED NULL,
    `dispatcher_id` INT UNSIGNED NULL,
    `source` ENUM('auto','disponent') NOT NULL DEFAULT 'auto',
    `deadline` DATETIME NULL,
    `punctual` TINYINT(1) NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `accepted_at` DATETIME NULL,
    `completed_at` DATETIME NULL,
    PRIMARY KEY (`id`),
    KEY `idx_orders_status` (`status`),
    KEY `idx_orders_driver` (`driver_id`),
    KEY `idx_orders_vehicle` (`vehicle_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_order_stops` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `order_id` INT UNSIGNED NOT NULL,
    `sequence` INT UNSIGNED NOT NULL DEFAULT 1,
    `location` VARCHAR(100) NOT NULL,
    `stop_type` ENUM('pickup','delivery') NOT NULL DEFAULT 'delivery',
    `reached_at` DATETIME NULL,
    PRIMARY KEY (`id`),
    KEY `idx_stops_order` (`order_id`),
    CONSTRAINT `fk_stops_order` FOREIGN KEY (`order_id`) REFERENCES `st_orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_order_history` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `order_id` INT UNSIGNED NOT NULL,
    `status` VARCHAR(30) NOT NULL,
    `changed_by` INT UNSIGNED NULL,
    `changed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `note` TEXT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_oh_order` (`order_id`),
    CONSTRAINT `fk_oh_order` FOREIGN KEY (`order_id`) REFERENCES `st_orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_transactions` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `type` ENUM('einnahme','auszahlung') NOT NULL,
    `amount` DECIMAL(14,2) NOT NULL,
    `related_order_id` INT UNSIGNED NULL,
    `related_payout_id` INT UNSIGNED NULL,
    `driver_id` INT UNSIGNED NULL,
    `description` VARCHAR(255) NULL,
    `created_by` INT UNSIGNED NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_tx_type` (`type`),
    KEY `idx_tx_created` (`created_at`),
    KEY `idx_tx_driver` (`driver_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_company_balance` (
    `id` TINYINT UNSIGNED NOT NULL,
    `balance` DECIMAL(14,2) NOT NULL DEFAULT 0,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `st_company_balance` (`id`, `balance`) VALUES (1, 0)
    ON DUPLICATE KEY UPDATE `id` = `id`;

CREATE TABLE IF NOT EXISTS `st_payouts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `amount` DECIMAL(14,2) NOT NULL,
    `reason` VARCHAR(255) NOT NULL,
    `target` VARCHAR(100) NOT NULL DEFAULT 'Unternehmensbankkonto',
    `executed_by` INT UNSIGNED NOT NULL,
    `executed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `transaction_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_payout_tx` FOREIGN KEY (`transaction_id`) REFERENCES `st_transactions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_notifications` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `recipient_employee_id` INT UNSIGNED NULL,
    `recipient_role` VARCHAR(30) NULL,
    `title` VARCHAR(100) NOT NULL,
    `message` TEXT NOT NULL,
    `read_state` TINYINT(1) NOT NULL DEFAULT 0,
    `sender_employee_id` INT UNSIGNED NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_notif_recipient` (`recipient_employee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `st_activity_logs` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `employee_id` INT UNSIGNED NULL,
    `action` VARCHAR(100) NOT NULL,
    `details` TEXT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_log_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
