-- =========================================================
-- speditions-tablet :: Upgrade v6 -> v7
-- Nur für bereits bestehende Installationen. Bei einer frischen
-- Installation genügt install.sql - dieses Skript ist dafür nicht nötig.
--
-- Neu: Auftragsstatus-Flow um "anfahrt" (Anfahrt zum Beladepunkt) und
-- "entladen" (wird gerade entladen) erweitert - "beladen" ist ab jetzt der
-- durchgehende Status, während der Fahrer beladen zum Zielort unterwegs ist
-- (ersetzt den alten Status "unterwegs" für NEUE Aufträge). "Fahrerkarte
-- einstecken" (st_drivers.on_shift) muss jetzt vor der Auftragsannahme
-- aktiv sein.
--
-- WICHTIG: Da bestehende Aufträge auf den alten Status-/Standortnamen
-- basieren, die mit dem neuen Standortsystem (Config.Locations,
-- upgrade_v6.sql) nicht mehr übereinstimmen (dadurch spawnt an ihrem
-- Abhol-/Zielort kein NPC und sie lassen sich nicht mehr per Taste E
-- be-/entladen), löscht dieses Skript ALLE bestehenden Aufträge samt
-- Verlauf. Abgeschlossene Aufträge/Statistiken/Auszahlungen bleiben in
-- st_driver_statistics und st_transactions unberührt (die werden nicht
-- gelöscht, nur neu aus den verbleibenden Daten berechnet, sobald der
-- jeweilige Fahrer das nächste Mal einen Auftrag abschließt/ablehnt).
-- =========================================================

ALTER TABLE `st_drivers`
    ADD COLUMN `on_shift` TINYINT(1) NOT NULL DEFAULT 0 AFTER `assigned_vehicle_id`,
    ADD COLUMN `shift_started_at` DATETIME NULL AFTER `on_shift`;

ALTER TABLE `st_orders`
    MODIFY COLUMN `status` ENUM('offen','disponiert','angenommen','anfahrt','beladen','entladen','unterwegs','abgeschlossen','abgebrochen','abgelehnt') NOT NULL DEFAULT 'offen';

DELETE FROM `st_order_history`;
DELETE FROM `st_order_stops`;
DELETE FROM `st_orders`;
ALTER TABLE `st_orders` AUTO_INCREMENT = 1;
ALTER TABLE `st_order_history` AUTO_INCREMENT = 1;
ALTER TABLE `st_order_stops` AUTO_INCREMENT = 1;
