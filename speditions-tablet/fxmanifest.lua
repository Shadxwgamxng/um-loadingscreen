fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'speditions-tablet'
author 'shadxwgamxng'
description 'Standalone FiveM Speditions-Tablet - Fahrer-, Disponenten- und Fuhrparkmanagement'
version '1.10.14'

dependency 'oxmysql'

shared_scripts {
    'config.lua'
}

-- Escrow (Keymaster "Build for Escrow"/Asset-Escrow) verschlüsselt beim
-- Bauen automatisch ALLE unten deklarierten shared_scripts/server_scripts/
-- client_scripts/ui_page/files - inklusive config.lua. escrow_ignore_files
-- nimmt config.lua davon aus, damit ihr (bzw. der Zielserver) es nach dem
-- Lock weiterhin normal im Texteditor bearbeiten könnt (Config.Website,
-- Standorte, Firmenname, ...), ohne für jede Änderung neu escrowen zu
-- müssen. sql/*.sql und README.md sind ohnehin nie betroffen - Escrow
-- erfasst ausschließlich die oben deklarierten Skript-/UI-Dateien.
escrow_ignore_files {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_utils.lua',
    'server/sv_rpc.lua',
    'server/sv_bridge.lua',
    'server/sv_bootstrap.lua',
    'server/sv_roles.lua',
    'server/sv_console.lua',
    'server/sv_logs.lua',
    'server/sv_finance.lua',
    'server/sv_payroll.lua',
    'server/sv_cargo_types.lua',
    'server/sv_locations.lua',
    'server/sv_vehicles.lua',
    'server/sv_trailers.lua',
    'server/sv_drivers.lua',
    'server/sv_hours.lua',
    'server/sv_orders.lua',
    'server/sv_website_bridge.lua',
    'server/sv_employees.lua',
    'server/sv_notifications.lua',
    'server/sv_main.lua'
}

client_scripts {
    'client/cl_main.lua',
    'client/cl_hours.lua',
    'client/cl_orders.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}
