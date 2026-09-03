fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'speditions-tablet'
author 'shadxwgamxng'
description 'Standalone FiveM Speditions-Tablet - Fahrer-, Disponenten- und Fuhrparkmanagement'
version '1.2.0'

dependency 'oxmysql'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_utils.lua',
    'server/sv_rpc.lua',
    'server/sv_bridge.lua',
    'server/sv_bootstrap.lua',
    'server/sv_logs.lua',
    'server/sv_finance.lua',
    'server/sv_vehicles.lua',
    'server/sv_drivers.lua',
    'server/sv_hours.lua',
    'server/sv_orders.lua',
    'server/sv_employees.lua',
    'server/sv_notifications.lua',
    'server/sv_main.lua'
}

client_scripts {
    'client/cl_main.lua',
    'client/cl_hours.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}
