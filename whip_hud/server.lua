-- The WHIP layer (whip/hud.css: rev dial hidden, round minimap; whip/status.css: WHIP's gauges hidden, voice as a
-- circle) goes into whip_core's page as a WHIP theme, but only when no other theme is active. With your own theme,
-- @import the files from it (README) and set D11Hud.WhipLayer = false. Stopping whip_hud puts WHIP's look back.
--
-- What happened is always said: one line in this console, and the same line in each player's F8 (client/layer.lua
-- reads GlobalState.whip_hud_layer), since that is where people look first.

local SELF = GetCurrentResourceName()
local function dbg(...) if D11Hud.Debug then print(...) end end
local IMPORT = ("@import url('https://cfx-nui-%s/whip/hud.css'); @import url('https://cfx-nui-%s/whip/status.css');")
    :format(SELF, SELF)

--- theme: the WHIP theme that carries the layer (whip_hud itself or whip_theme); the client hands whip_core's page that
--- one again if it missed it, never whip_hud over another theme.
local function report(on, text, theme)
    -- every public whip_core (1.0.0 on) draws its minimap in its own page (#minimap3d), which whip/hud.css rounds
    text = ('%s (whip_core %s)'):format(text, GetResourceMetadata('whip_core', 'version', 0) or '?')
    GlobalState.whip_hud_layer = { on = on, text = text, resource = SELF, theme = on and (theme or SELF) or nil }
    dbg(('%s[whip_hud] %s^0'):format(on and '^2' or '^3', text))
end

-- The layer itself: hud.css, and status.css unless D11Hud.Status = false (WHIP's own gauges stay then).
local function layerCss()
    local out = { "/* whip_hud's layer inside WHIP's page. Written by whip_hud when it starts, emptied when it stops: do not edit. */" }
    out[#out + 1] = LoadResourceFile(SELF, 'whip/hud.css') or ''
    if D11Hud.Status ~= false then out[#out + 1] = LoadResourceFile(SELF, 'whip/status.css') or '' end
    return table.concat(out, '\n')
end
exports('WhipLayerCss', layerCss)   -- whip_theme 1.1.0+ asks for it and keeps it in its own css/whip_hud.css

-- whip_hud as its own WHIP theme (theme.css): whip/status-layer.css follows D11Hud.Status, no line to delete.
SaveResourceFile(SELF, 'whip/status-layer.css', D11Hud.Status ~= false and (LoadResourceFile(SELF, 'whip/status.css') or '')
    or '/* D11Hud.Status = false: WHIP\'s own status gauges stay. */\n', -1)

-- whip_theme 1.1.0+ imports its own css/whip_hud.css, written from WhipLayerCss as it starts (FiveM hands players a
-- resource's files as they were when it started). When what it serves is not our layer (it started before us, or
-- Status changed), or when we stop, it is restarted so it writes the right one: nobody edits theme.css.
local THEME_RES, THEME_LAYER = 'whip_theme', 'css/whip_hud.css'
local function themeTakesLayer()
    return GetResourceState(THEME_RES) == 'started'
        and (LoadResourceFile(THEME_RES, 'theme.css') or ''):find(THEME_LAYER, 1, true) ~= nil
end
local function restartTheme(why)
    dbg(('^3[whip_hud] restarting whip_theme: %s^0'):format(why))
    StopResource(THEME_RES)
    StartResource(THEME_RES)
end

-- A chosen WHIP theme resource (D11Hud.Theme, whip_theme_d12 by default) carries the layer: its theme.css gets two
-- @import lines for our files, between markers so they can be found again and removed. They go right after the
-- theme's own @import lines (CSS ignores an @import after any rule), and the theme is restarted once so FiveM serves
-- the new theme.css. Stopping whip_hud takes them out again: an @import of a stopped resource fails and drops the
-- whole theme.
local MARK_A, MARK_B = '/* whip_hud layer begin */', '/* whip_hud layer end */'
local function carrierBlock()
    return MARK_A .. "\n@import url('https://cfx-nui-" .. SELF .. "/whip/hud.css?v=5');\n"
        .. "@import url('https://cfx-nui-" .. SELF .. "/whip/status-layer.css?v=4');\n" .. MARK_B
end
local function stripBlock(css)
    local a = css:find(MARK_A, 1, true)
    local _, b = css:find(MARK_B, 1, true)
    if not a or not b then return css, false end
    return (css:sub(1, a - 1):gsub('%s+$', '') .. '\n' .. css:sub(b + 1):gsub('^%s+', '')), true
end
local function insertBlock(css)
    local firstRule = css:find('{', 1, true) or (#css + 1)
    local pos = select(2, css:find('^%s*@charset[^;]*;')) or 0
    local init = 1
    while true do
        local s, e = css:find('@import[^;]-;', init)
        if not s or s > firstRule then break end
        local lineStart = (css:sub(1, s - 1):match('.*()\n') or 0)
        if not css:sub(lineStart + 1, s - 1):find('/*', 1, true) then pos = e end   -- skip commented-out imports
        init = e + 1
    end
    return css:sub(1, pos) .. '\n' .. carrierBlock() .. '\n' .. css:sub(pos + 1)
end
--- The stylesheet a theme resource loads: theme.css, else a common name, else the one .css file (or the one with
--- "theme" in its name) in its fxmanifest `files`. Returns the path, or nil and the .css files it could see.
local GUESSES = { 'theme.css', 'css/theme.css', 'ui/theme.css', 'style.css', 'styles.css', 'main.css', 'css/main.css', 'css/style.css', 'index.css' }
local carrierFiles = {}
local function carrierFile(res)
    local known = carrierFiles[res]
    if known and LoadResourceFile(res, known) then return known end
    local seen = {}
    for i = 0, (GetNumResourceMetadata(res, 'file') or 0) - 1 do
        local f = GetResourceMetadata(res, 'file', i)
        if f and f:lower():match('%.css$') and not f:find('*', 1, true) then seen[#seen + 1] = f end
    end
    local order = {}
    for _, f in ipairs(GUESSES) do order[#order + 1] = f end
    for _, f in ipairs(seen) do if f:lower():find('theme', 1, true) then order[#order + 1] = f end end
    if #seen == 1 then order[#order + 1] = seen[1] end
    for _, f in ipairs(order) do
        if LoadResourceFile(res, f) then carrierFiles[res] = f return f end
    end
    return nil, seen
end
--- Puts the layer into the carrier's stylesheet. Returns true when it is ready, 'changed' when it had to be rewritten,
--- or false and a reason.
local function installInCarrier(res)
    local file, seen = carrierFile(res)
    if not file then
        return false, ('no theme.css found in %s (.css files in its fxmanifest: %s)'):format(res, #seen > 0 and table.concat(seen, ', ') or 'none listed')
    end
    local css = LoadResourceFile(res, file)
    local cur = css:find(MARK_A, 1, true) and css:match(MARK_A:gsub('%p', '%%%0') .. '.-' .. MARK_B:gsub('%p', '%%%0'))
    if cur == carrierBlock() then return true end
    local clean = stripBlock(css)
    if not SaveResourceFile(res, file, insertBlock(clean), -1) then
        return false, ('FiveM would not let whip_hud write %s/%s'):format(res, file)
    end
    return 'changed'
end
local function restartCarrier(res, why)
    dbg(('^3[whip_hud] restarting %s: %s^0'):format(res, why))
    StopResource(res)
    StartResource(res)
end

-- Stopping: the theme goes back to an empty layer, or WHIP's gauges would stay hidden with no HUD of ours.
AddEventHandler('onResourceStop', function(res)
    if res ~= SELF then return end
    local carrier = D11Hud.Theme
    if carrier and carrier ~= '' and GetResourceState(carrier) == 'started' then
        local file = carrierFile(carrier)
        local css = file and LoadResourceFile(carrier, file)
        local clean, had
        if css then clean, had = stripBlock(css) end
        if had and SaveResourceFile(carrier, file, clean, -1) then restartCarrier(carrier, 'whip_hud stopped') end
    end
    if not themeTakesLayer() then return end
    if (LoadResourceFile(THEME_RES, THEME_LAYER) or ''):find('#minimap3d', 1, true) then restartTheme('whip_hud stopped') end
end)

if D11Hud.WhipLayer == false then
    report(false, ('WHIP layer off: WhipLayer = false in config.lua. Your WHIP theme must carry %s'):format(IMPORT))
    return
end

-- Inside Whip.register so it is set again after a whip_core restart.
Whip.register(function()
    local theme, owner = exports.whip_core:GetActiveTheme()
    -- The chosen theme (D11Hud.Theme = 'whip_theme_d12'): it carries the layer and is the active WHIP theme.
    local carrier = D11Hud.Theme
    if carrier and carrier ~= '' and GetResourceState(carrier) == 'started' then
        local stale = (theme == 'd11_hud' or theme == 'd11_theme') and GetResourceState(theme) == 'missing'
        local free = theme == nil or theme == '' or theme == false or theme == SELF or stale
        if theme ~= carrier and not free then
            report(false, ('WHIP layer off: you chose "%s" (D11Hud.Theme) but the WHIP theme "%s" is active (%s). Set Config.Theme = "%s" in whip_core, or set D11Hud.Theme = false.')
                :format(carrier, tostring(theme), owner and ('set by ' .. tostring(owner)) or 'Config.Theme', carrier))
            return
        end
        local done, why = installInCarrier(carrier)
        if not done then
            report(false, ('WHIP layer off: could not add the layer to %s: %s. Add %s to its stylesheet by hand, after its own @import lines.'):format(carrier, why, IMPORT))
            return
        end
        if theme ~= carrier then
            local ok, err = exports.whip_core:SetActiveTheme(carrier)
            if not ok then
                report(false, ('WHIP layer off: whip_core refused the theme %s (%s).'):format(carrier, tostring(err)))
                return
            end
        end
        if done == 'changed' then
            restartCarrier(carrier, 'its theme.css now imports the whip_hud layer')
            SetTimeout(3000, function() TriggerClientEvent('whip_core:client:applyTheme', -1, carrier) end)
        end
        report(true, ('WHIP layer on: carried by %s (its stylesheet imports whip/hud.css and whip/status-layer.css).'):format(carrier), carrier)
        return
    end
    -- whip_core remembers the active theme by resource name. If it was saved under the old d11_ names, that resource no
    -- longer exists after the rename, so the layer would never load: take the theme over (or hand it to whip_theme).
    if (theme == 'd11_hud' or theme == 'd11_theme') and GetResourceState(theme) == 'missing' then
        dbg(('^3[whip_hud] the saved WHIP theme "%s" was renamed: switching it over^0'):format(theme))
        theme = (theme == 'd11_theme' and GetResourceState(THEME_RES) == 'started') and THEME_RES or nil
        if theme then
            local ok = exports.whip_core:SetActiveTheme(theme)
            if not ok then theme = nil end
        end
    end
    if theme == SELF then
        report(true, 'WHIP layer on: whip_hud is already WHIP\'s active theme.')
        return
    end
    if themeTakesLayer() then
        -- whip_theme is ours: it becomes WHIP's active theme over nothing, an old whip_hud / d11_ name, or the old whip_theme_d12
        local free = theme == nil or theme == '' or theme == false or theme == SELF or theme == 'whip_theme_d12'
            or ((theme == 'd11_hud' or theme == 'd11_theme') and GetResourceState(theme) == 'missing')
        if theme ~= THEME_RES and free then
            local ok, err = exports.whip_core:SetActiveTheme(THEME_RES)
            if not ok then
                report(false, ('WHIP layer off: whip_core refused the theme %s (%s).'):format(THEME_RES, tostring(err)))
                return
            end
            SetTimeout(3000, function() TriggerClientEvent('whip_core:client:applyTheme', -1, THEME_RES) end)
        end
        if (LoadResourceFile(THEME_RES, THEME_LAYER) or '') ~= layerCss() then
            restartTheme('it started before whip_hud (or Status changed), so it serves an old layer')
        end
        report(true, 'WHIP layer on: carried by whip_theme (its css/whip_hud.css).', THEME_RES)
        return
    end
    if theme == 'whip_theme' then
        -- whip_theme 1.0.x: the two @import lines ship commented out (a failed import drops the whole theme)
        local css = LoadResourceFile('whip_theme', 'theme.css') or ''
        if ("\n" .. css):find("\n@import url%('https://cfx%-nui%-" .. SELF .. "/whip/hud%.css") then
            report(true, 'WHIP layer on: through whip_theme, which imports whip/hud.css and whip/status.css.', 'whip_theme')
        else
            report(false, ('WHIP layer off: whip_theme 1.0.x is the active WHIP theme. Update it to 1.1.0 (github.com/DLady25/whip-d11-theme), which takes the layer by itself, or add %s to its theme.css.')
                :format(IMPORT))
        end
        return
    end
    if theme ~= nil and theme ~= '' and theme ~= false then
        report(false, ('WHIP layer off: the WHIP theme "%s" is active (%s), so whip_hud cannot load its own. Add %s to that theme\'s theme.css, or WHIP\'s gauges and square minimap stay on screen.')
            :format(tostring(theme), owner and ('set by ' .. tostring(owner)) or 'Config.Theme', IMPORT))
        return
    end
    local ok, err = exports.whip_core:SetActiveTheme(SELF)
    if not ok then
        report(false, ('WHIP layer off: whip_core refused it (%s).'):format(tostring(err)))
        return
    end
    report(true, 'WHIP layer on: whip_hud set itself as WHIP\'s active theme (whip/hud.css, whip/status.css).')
end)

-- Sent again after login: whip_core sends the theme at login, but FiveM's NUI can serve the theme.css cached from the
-- last session; sending it again swaps the <link> and the page fetches it anew.
AddEventHandler('whip_core:player:loaded', function(data)
    local src = type(data) == 'table' and tonumber(data.source)
    if not src then return end
    SetTimeout(2000, function()
        local layer = GlobalState.whip_hud_layer
        local carrying = type(layer) == 'table' and layer.on and layer.theme or SELF
        if GetPlayerName(src) and exports.whip_core:GetActiveTheme() == carrying then
            TriggerClientEvent('whip_core:client:applyTheme', src, carrying)
        end
    end)
end)
