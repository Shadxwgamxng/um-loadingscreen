-- =========================================================
-- speditions-tablet :: Upgrade v11 -> v12
-- Nur für bereits bestehende Installationen. Bei einer frischen
-- Installation genügt install.sql - dieses Skript ist dafür nicht nötig.
--
-- Erweitert den Website-Sync (Config.Website) um echte Gleichwertigkeit
-- (bidirektional ohne Hierarchie zwischen Tablet und Website):
--   - `st_orders.source`: neuer Wert 'website' - ein auf der Website
--     angelegter Auftrag landet im offenen Auftragspool wie ein
--     automatisch generierter (Orders.CreateFromWebsite), ein Disponent
--     im Spiel muss ihn noch einem Fahrer/Fahrzeug zuweisen.
--   - `st_vehicles`: keine Schemaänderung nötig, nur neue Funktion
--     (Vehicles.UpdateFromWebsite) für Statusänderungen von der Website.
--   - `st_employees`: keine Schemaänderung nötig, nur neue Funktion
--     (Employees.HireFromWebsite) für Website-seitig angelegte Konten.
-- =========================================================

ALTER TABLE `st_orders` MODIFY COLUMN `source` ENUM('auto','disponent','website') NOT NULL DEFAULT 'auto';
