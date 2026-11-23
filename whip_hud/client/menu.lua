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
local PARTS = { 'status', 'radar', 'route', 'gauge', 'ammo', 'hints', 'belt' }

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
    setOpen(false)
    cb({ ok = true })
end)

RegisterNUICallback('editorClose', function(_, cb)
    setOpen(false)
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
