-- =========================================================
-- speditions-tablet :: Upgrade v5 -> v6
-- Nur für bereits bestehende Installationen. Bei einer frischen
-- Installation genügt install.sql - dieses Skript ist dafür nicht nötig.
--
-- Neu: Echte Firmenstandorte mit NPCs zum Be-/Entladen per Tasteninteraktion
-- (E), Lieferschein mit Menge/Einheit je Auftrag. Config.Routes/Config.Locations
-- (altes Name->Koordinaten-Dictionary) wurden durch die neue Standortliste
-- in config.lua ersetzt.
-- =========================================================

ALTER TABLE `st_orders`
    ADD COLUMN `cargo_amount` INT UNSIGNED NULL AFTER `requires_permission`,
    ADD COLUMN `cargo_unit` VARCHAR(30) NULL AFTER `cargo_amount`;
