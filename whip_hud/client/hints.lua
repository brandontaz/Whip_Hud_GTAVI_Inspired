-- Action hints: keys and what they do, in the bottom-right corner (ui/hints.js), up to six rows, highest priority
-- first. Built in, on WHIP's real keys (never an assumed default):
--   seatbelt ....... whip_seatbelt (client/seatbelt.lua), in vehicles that have one
--   engine ......... whip_core's mouse wheel (+whip_ignition_on/off: wheel up starts, wheel down stops)
--   cancel emote ... whip_core's whip_emote_cancel, while IsEmoting
-- Other resources: exports.whip_hud:SetHints(id, rows, priority) / ClearHints(id), kept apart per resource.
-- Hidden with the HUD inactive (dead, screen or inventory open, logged out), the pause menu and NUI focus.
-- Players: /hints on|off|bigger|smaller (/legendas on|off|maior|menor in pt-BR).

local L = D11Hud.L
local cfg = D11Hud.Hints
local yes = Hud.yes
local NO_BELT = { [8] = true, [13] = true, [14] = true, [15] = true, [16] = true }
local contexts = {}
local enabled = cfg.Enabled ~= false and GetResourceKvpString('hints_enabled') ~= 'off'
local scale = tonumber(GetResourceKvpString('hints_scale')) or 1

-- Icon codes from GetControlInstructionalButton (the keyboard's main block).
local iconKeys = {
    b_1000 = 'Shift', b_1001 = L('Right Shift', 'Shift D'), b_1002 = 'Tab', b_1003 = 'Enter', b_1004 = 'Backspace',
    b_1012 = 'Caps Lock', b_1013 = 'Ctrl', b_1014 = L('Right Ctrl', 'Ctrl D'), b_1015 = 'Alt', b_1016 = 'Alt Gr',
    b_2000 = L('Space', 'Espaço'),
}

-- The same command hash RegisterKeyMapping uses: the key the player set.
local function resolveKey(row)
    if row.key then return row.key end
    if row.controls then
        local keys = {}
        for _, control in ipairs(row.controls) do keys[#keys + 1] = resolveKey({ control = control }) end
        return table.concat(keys, ' / ')
    end
    local control = row.control or (joaat(row.command) | 0x80000000)
    local button = GetControlInstructionalButton(0, control, true)
    if button and button:sub(1, 2) == 't_' then return button:sub(3) end
    if iconKeys[button] then return iconKeys[button] end
    return row.fallback or L('See keys', 'Ver teclas')
end

--- rows: up to six { label = text, key = 'E' | command = 'my_command' | control = 38 }; priority 0-100 (default 50).
exports('SetHints', function(id, rows, priority)
    local owner = GetInvokingResource()
    if not owner or type(id) ~= 'string' or #id > 80 or type(rows) ~= 'table' then return false end
    local copy = {}
    for i = 1, math.min(#rows, 6) do
        local row = rows[i]
        if type(row) ~= 'table' or type(row.label) ~= 'string' or #row.label > 160 then return false end
        local key = type(row.key) == 'string' and #row.key <= 40 and row.key or nil
        local command = type(row.command) == 'string' and #row.command <= 80 and row.command or nil
        local control = type(row.control) == 'number' and math.tointeger(row.control) or nil
        if not key and not command and not control then return false end
        copy[#copy + 1] = { key = key, command = command, control = control, label = row.label }
    end
    contexts[owner] = contexts[owner] or {}
    contexts[owner][id] = { rows = copy, priority = math.max(0, math.min(100, tonumber(priority) or 50)) }
    return true
end)

exports('ClearHints', function(id)
    local owner = GetInvokingResource()
    if owner and contexts[owner] then contexts[owner][id] = nil end
end)

AddEventHandler('onClientResourceStop', function(resource) contexts[resource] = nil end)

local function vehicleRows(ped, vehicle)
    local rows = {}
    local class = GetVehicleClass(vehicle)
    if Hud.hasSeatbelt(vehicle) and not NO_BELT[class] then
        rows[#rows + 1] = { command = 'whip_seatbelt', label = Hud.state.seatbelt and L('Unbuckle', 'Retirar cinto') or L('Buckle up', 'Colocar cinto') }
    end
    if GetPedInVehicleSeat(vehicle, -1) == ped and class ~= 13 then
        -- Engine: whip_core's default is the mouse wheel (+whip_ignition_on/off). Asking for the key of a command
        -- with no key (+whip_ignition_toggle) answers a key that is not its own, and the wheel does not come back as
        -- text: hence the fixed wheel text.
        local running = yes(GetIsVehicleEngineRunning(vehicle))
        rows[#rows + 1] = {
            key = running and L('Wheel ↓', 'Roda ↓') or L('Wheel ↑', 'Roda ↑'),
            label = running and L('Stop engine', 'Desligar motor') or L('Start engine', 'Ligar motor'),
        }
    end
    return rows
end

local function buildRows()
    if not enabled or not Hud.state.active or Hud.state.visible == false or IsPauseMenuActive() or IsNuiFocused() then
        return {}
    end
    local ped = PlayerPedId()
    local groups = {}
    for owner, entries in pairs(contexts) do
        if GetResourceState(owner) == 'started' then
            for id, entry in pairs(entries) do
                groups[#groups + 1] = { id = owner .. ':' .. id, rows = entry.rows, priority = entry.priority }
            end
        end
    end
    if Hud.core('IsEmoting') then
        groups[#groups + 1] = { id = 'emote', priority = 90, rows = { { command = 'whip_emote_cancel', label = L('Cancel animation', 'Cancelar animação') } } }
    end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and yes(DoesEntityExist(vehicle)) then
        groups[#groups + 1] = { id = 'vehicle', priority = 20, rows = vehicleRows(ped, vehicle) }
    end
    table.sort(groups, function(a, b)
        if a.priority == b.priority then return a.id < b.id end
        return a.priority > b.priority
    end)
    local rows, seen = {}, {}
    for _, group in ipairs(groups) do
        for _, row in ipairs(group.rows) do
            local key = resolveKey(row)
            local identity = key .. '\0' .. row.label
            if not seen[identity] and #rows < 6 then
                seen[identity] = true
                rows[#rows + 1] = { key = key, label = row.label }
            end
        end
    end
    return rows
end

if cfg.Enabled ~= false then
    local command = cfg.Command or 'hints'
    RegisterCommand(command, function(_, args)
        local option = args[1]
        if option == 'bigger' or option == 'maior' then scale = math.min(1.5, scale + 0.25)
        elseif option == 'smaller' or option == 'menor' then scale = math.max(1, scale - 0.25)
        elseif option == 'on' then enabled = true
        elseif option == 'off' then enabled = false
        else enabled = not enabled end
        SetResourceKvp('hints_enabled', enabled and 'on' or 'off')
        SetResourceKvp('hints_scale', tostring(scale))
        Hud.core('Notify', L('Hints %s · size %d%%', 'Legendas %s · tamanho %d%%'):format(
            enabled and L('on', 'ativadas') or L('off', 'desativadas'), scale * 100), 'info')
    end, false)

    AddEventHandler('whip_core:player:loaded', function()
        TriggerEvent('chat:addSuggestion', '/' .. command, L('Action hints on screen', 'Atalhos contextuais na tela'), {
            { name = L('on|off|bigger|smaller', 'on|off|maior|menor'), help = L('Show, hide or resize them', 'Mostrar, ocultar ou ajustar o tamanho') },
        })
    end)
end

CreateThread(function()
    local last
    while true do
        local message = { rows = buildRows(), scale = scale }
        local encoded = json.encode(message)
        if encoded ~= last then
            last = encoded
            Hud.set('hints', message)
        end
        Wait(250)
    end
end)
