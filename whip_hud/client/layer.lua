-- The WHIP layer, client side (server.lua decides it). Says in F8 what the server decided and what whip_core's page
-- was last told, once the player is in; and if the server holds the layer but this page never got it (a broadcast
-- missed while loading), hands whip_core its own applyTheme event again, locally.

local SELF = GetCurrentResourceName()
local function dbg(...) if D11Hud.Debug then print(...) end end
local pageTheme = nil   -- the last theme whip_core's page was told to load (its applyTheme event), if any

RegisterNetEvent('whip_core:client:applyTheme')
AddEventHandler('whip_core:client:applyTheme', function(resource) pageTheme = resource or false end)

local function check()
    local layer = GlobalState.whip_hud_layer
    if type(layer) ~= 'table' then
        dbg('^3[whip_hud] WHIP layer: no word from whip_hud\'s server side (is server.lua running? check the server console)^0')
        return
    end
    dbg(('%s[whip_hud] %s^0'):format(layer.on and '^2' or '^3', tostring(layer.text)))
    -- The theme that carries the layer: whip_hud itself, or whip_theme (1.0.4 sent whip_hud over whip_theme here).
    local theme = layer.theme or SELF
    if layer.on and pageTheme ~= theme then
        dbg(('^3[whip_hud] whip_core\'s page had not been sent the theme %s: sending it again^0'):format(theme))
        TriggerEvent('whip_core:client:applyTheme', theme)
    end
end

-- looked at a few times: a page that was still loading, or a cached stylesheet, can miss the first one
AddEventHandler('whip_core:player:loaded', function()
    for _, ms in ipairs({ 5000, 15000, 40000 }) do SetTimeout(ms, check) end
end)
-- whip_hud (re)started with the player already in
CreateThread(function()
    Wait(5000)
    if Hud.core('IsPlayerLoaded') == true then check() Wait(10000) check() end
end)
