fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'whip_hud'
description 'D11 HUD for WHIP, GTA VI style: status, speedometer with turbo and nitrous, seatbelt, round radar with GPS card, ammo, action hints.'
author 'District 11 (D11)'
version '1.2.0'
repository 'https://github.com/DLady25/whip-d11-hud'

dependency 'whip_core'

shared_script 'config.lua'

client_scripts {
    'client/state.lua',
    'client/layer.lua',
    'client/status.lua',
    'client/seatbelt.lua',
    'client/power.lua',
    'client/vehicle.lua',
    'client/weapons.lua',
    'client/fuel.lua',
    'client/map.lua',
    'client/route.lua',
    'client/hints.lua',
    'client/menu.lua',
}

server_scripts {
    '@whip_core/lib/satellite.lua',   -- Whip.register (the WHIP layer)
    'server.lua',
}

ui_page 'ui/index.html'

files {
    'theme.css',            -- the WHIP layer, injected into whip_core's page (server.lua)
    'whip/hud.css',
    'whip/status.css',
    'whip/status-layer.css',
    'ui/index.html',
    'ui/*.css',
    'ui/*.js',
    'ui/logo.png',
    'ui/fonts/*',
    'ui/weapons/catalogue.json',
    'ui/weapons/**/*.png',
}

whip_requires '1.0'
