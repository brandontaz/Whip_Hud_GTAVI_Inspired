fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'whip_theme'
description 'Your WHIP theme. Carries whip_hud: hides WHIP\'s own status gauges and rev dial and rounds its minimap, so the whip_hud HUD replaces the old one.'
version '1.1.0'

dependency 'whip_core'

server_script 'server.lua'

files {
    'theme.css',
    'css/*.css',
}
