-- =========================================================
-- speditions-tablet :: Upgrade v10 -> v11
-- Nur für bereits bestehende Installationen. Bei einer frischen
-- Installation genügt install.sql - dieses Skript ist dafür nicht nötig.
--
-- Neu: Website-Sync (Config.Website, server/sv_website_bridge.lua). Beide
-- neuen Spalten sind rein optional und wirken sich ohne aktivierten
-- Website-Sync (Config.Website.enabled = false, Standard) auf nichts aus:
--   - `st_employees.discord_id`: verknüpft ein Mitarbeiterkonto optional mit
--     einem Discord-Nutzer, damit das zugehörige Website-Konto sich per
--     Discord-OAuth anmelden kann (rein informativ, KEIN Auth-Faktor im
--     Tablet selbst - genau wie `identifier`).
--   - `st_roles.website_role_key`: ordnet einer Tablet-Rolle eine der 9
--     festen Website-Rollen zu (im Rollen-Editor unter "Rollen" pflegbar) -
--     ohne diese Zuordnung schlägt die Synchronisation eines Mitarbeiters
--     mit dieser Rolle fehl (siehe server/sv_website_bridge.lua).
-- =========================================================

ALTER TABLE `st_employees` ADD COLUMN `discord_id` VARCHAR(32) NULL AFTER `identifier`;
ALTER TABLE `st_roles` ADD COLUMN `website_role_key` VARCHAR(30) NULL AFTER `permissions`;
