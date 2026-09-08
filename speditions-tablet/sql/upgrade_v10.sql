-- =========================================================
-- speditions-tablet :: Upgrade v9 -> v10
-- Nur für bereits bestehende Installationen. Bei einer frischen
-- Installation genügt install.sql - dieses Skript ist dafür nicht nötig.
--
-- Neu: Frei anlegbare Rollen mit einzeln bearbeitbaren Berechtigungen
-- (Reiter "Rollen" der Geschäftsführung im Tablet) statt der drei fest
-- verdrahteten Rollen Fahrer/Disponent/Geschäftsführung. Die drei
-- mitgelieferten Basisrollen werden beim nächsten Ressourcenstart
-- automatisch mit ihren bisherigen Berechtigungen in `st_roles` angelegt
-- (server/sv_roles.lua) - für bestehende Installationen ändert sich also
-- zunächst NICHTS am tatsächlichen Verhalten, es kommt nur die
-- Möglichkeit hinzu, weitere Rollen anzulegen bzw. die drei Basisrollen
-- selbst anzupassen.
-- =========================================================

CREATE TABLE IF NOT EXISTS `st_roles` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `role_key` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `permissions` TEXT NOT NULL,
    `is_builtin` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_role_key` (`role_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `st_employees` MODIFY COLUMN `role` VARCHAR(50) NOT NULL DEFAULT 'fahrer';
