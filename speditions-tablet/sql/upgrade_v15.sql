-- =========================================================
-- speditions-tablet :: Upgrade v14 -> v15
-- Nur für bereits bestehende Installationen. Bei einer frischen
-- Installation genügt install.sql - dieses Skript ist dafür nicht nötig.
--
-- Bereinigung: st_locations wurde auf manchen Installationen schon VOR der
-- finalen Config.SeedLocations-Liste (59 echte Standorte) mit vorläufigen/
-- Platzhalter-Orten befüllt. Die Erstbefüllung (server/sv_locations.lua,
-- seedLocations()) nutzt ON DUPLICATE KEY UPDATE nur auf den Namen - alte
-- Orte mit ANDEREM Namen werden dadurch nie entfernt, sondern bleiben
-- zusätzlich zu den neuen, echten Orten stehen ("auf der Website sind noch
-- die alten Orte hinterlegt").
--
-- WICHTIG: Dieses Skript leert st_locations KOMPLETT, auch eigene, über den
-- Tablet-Reiter "Orte" nachträglich angelegte Orte gehen dabei verloren.
-- Nur ausführen, wenn wirklich nur die aus Config.SeedLocations bekannten
-- Orte gewünscht sind - Config.SeedLocations füllt die Tabelle beim
-- nächsten Ressourcenstart automatisch wieder aus config.lua.
-- =========================================================

DELETE FROM `st_locations`;
ALTER TABLE `st_locations` AUTO_INCREMENT = 1;
