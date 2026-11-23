-- /hud: the layout editor. Drag every part of the HUD where you want it, resize it, and choose whether the status bars
-- (health, armour, energy, food, water, stress) stay on screen. ui/editor.js draws it; this opens it and keeps what the
-- player chose, per PC (KVP), so it is back after a restart.
--   layout .... { status = { x, y, s }, ... }: x, y in vh from the default spot, s the scale; only parts that moved
--   pinStatus . true: the status bars never fade out and show every bar and chip

local cfg = D11Hud.Menu
if type(cfg) ~= 'table' or cfg.Enabled == false then return end

local L = D11Hud.L
local KVP = 'whip_hud_layout_v1'
local COMMAND = cfg.Command or 'hud'
local PARTS = { 'status', 'radar', 'route', 'gauge', 'ammo', 'hints', 'belt', 'map' }

local function number(v, lo, hi, default)
    v = tonumber(v)
    if not v or v ~= v then return default end
    return math.max(lo, math.min(hi, v))
end

--- Only the known parts, only numbers, only sane ones: the page is told what to draw, never trusted for it.
local function clean(layout)
    local out = {}
    if type(layout) ~= 'table' then return out end
    for _, id in ipairs(PARTS) do
        local v = layout[id]
        if type(v) == 'table' then
            out[id] = { x = number(v.x, -200, 200, 0), y = number(v.y, -200, 200, 0), s = number(v.s, 0.5, 1.6, 1) }
        end
    end
    return out
end

-- what the player saved (or the config's defaults), before the page asks for its snapshot
do
    local saved = {}
    local raw = GetResourceKvpString(KVP)
    if raw then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then saved = decoded end
    end
    Hud.state.layout = clean(saved.layout)
    if saved.pinStatus ~= nil then Hud.state.pinStatus = saved.pinStatus == true
    else Hud.state.pinStatus = D11Hud.PinStatus == true end
end

local open = false

-- The minimap is drawn in whip_core's page, which whip_hud's page cannot reach: whip_core's own client moves it, through
-- the SetMinimapOffset export of whip_core-patches/ (x, y in vh from the default spot, scale). Without the patch the map
-- stays put (and F8 says so once).
local warned = false
local function pushMap(v)
    v = type(v) == 'table' and v or {}
    local ok = pcall(function() return exports.whip_core:SetMinimapOffset(number(v.x, -200, 200, 0), number(v.y, -200, 200, 0), number(v.s, 0.5, 1.6, 1)) end)
    if not ok and not warned and GetResourceState('whip_core') == 'started' then
        warned = true
        print('^3[whip_hud] the minimap cannot be moved: whip_core has no SetMinimapOffset export (apply whip_core-patches/whip_core-minimap-offset-d11.patch)^0')
    end
    return ok
end

-- the saved spot, once whip_core is up (and again if it restarts)
CreateThread(function()
    local was = false
    while true do
        local up = GetResourceState('whip_core') == 'started'
        if up and not was then
            Wait(2500)
            local l = Hud.state.layout
            if l and l.map then pushMap(l.map) end
        end
        was = up
        Wait(2000)
    end
end)

local function setOpen(value)
    if open == value then return end
    open = value
    SetNuiFocus(value, value)
    Hud.set('editor', value)
    if not value then return end
    CreateThread(function()
        while open do
            -- the pause menu would open under the editor on Esc (the page closes it itself)
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            if not Hud.state.active then setOpen(false) break end
            Wait(0)
        end
    end)
end

RegisterCommand(COMMAND, function()
    if open then return setOpen(false) end
    if not Hud.state.active or IsPauseMenuActive() then return end
    setOpen(true)
end, false)

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. COMMAND, L('Edit the HUD: move it, resize it, keep status on screen', 'Editar o HUD: mover, redimensionar, manter o status na tela'))
end)

RegisterNUICallback('editorSave', function(data, cb)
    data = type(data) == 'table' and data or {}
    local layout, pin = clean(data.layout), data.pinStatus == true
    SetResourceKvp(KVP, json.encode({ layout = layout, pinStatus = pin }))
    Hud.set('layout', layout)
    Hud.set('pinStatus', pin)
    pushMap(layout.map)
    setOpen(false)
    cb({ ok = true })
end)

-- while dragging in /hud: the real map follows
RegisterNUICallback('mapMove', function(data, cb)
    if open or type(data) == 'table' then pushMap(data) end
    cb({ ok = true })
end)

RegisterNUICallback('editorClose', function(_, cb)
    setOpen(false)
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
