-- =========================================================
-- speditions-tablet :: Upgrade v13 -> v14
-- Nur für bereits bestehende Installationen. Bei einer frischen
-- Installation genügt install.sql - dieses Skript ist dafür nicht nötig.
--
-- Bugfix: st_wage_rates.role war noch ein festes ENUM aus den Anfängen des
-- Gehaltssystems ('fahrer','disponent','geschaeftsfuehrung'), obwohl die
-- Geschäftsführung seit Längerem beliebige eigene Rollen im Rollen-Editor
-- anlegen kann (st_employees.role wurde dafür bereits auf VARCHAR
-- umgestellt - st_wage_rates wurde dabei übersehen). Für jede neu
-- angelegte Rolle, deren Schlüssel nicht in diesem alten ENUM steht (z.B.
-- "prokurist"), schlug das Setzen eines Stundenlohns bisher mit
-- "Data truncated for column 'role'" fehl.
-- =========================================================

ALTER TABLE `st_wage_rates`
    MODIFY COLUMN `role` VARCHAR(50) NOT NULL;
