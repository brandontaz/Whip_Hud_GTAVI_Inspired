-- Keeps css/whip_hud.css equal to whip_hud's layer (exports.whip_hud:WhipLayerCss). FiveM hands players a resource's
-- files as they were when it started, so when whip_hud starts after this theme (or its Status option changes) it
-- restarts this resource once and the new file is written here; when whip_hud stops it restarts it again and the layer
-- is emptied, so WHIP's own HUD comes back.

local SELF = GetCurrentResourceName()
local FILE = 'css/whip_hud.css'
local EMPTY = "/* whip_hud's layer. Written by whip_theme/server.lua when whip_hud is running; empty until then. */\n"

local function layer()
    if GetResourceState('whip_hud') ~= 'started' then return EMPTY end
    local ok, css = pcall(function() return exports.whip_hud:WhipLayerCss() end)
    if ok and type(css) == 'string' and css ~= '' then return css end
    return EMPTY
end

local function write()
    local css = layer()
    if LoadResourceFile(SELF, FILE) ~= css then SaveResourceFile(SELF, FILE, css, -1) end
end

write()
print(('^2[whip_theme] ready: whip_hud layer %s^0'):format(GetResourceState('whip_hud') == 'started' and 'on' or 'off (starts with whip_hud)'))
