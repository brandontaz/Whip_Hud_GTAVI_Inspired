-- The HUD's single state. Every change goes through Hud.set; when the page (re)loads it asks for the whole snapshot.

Hud = {
    state = {
        active = false,        -- logged in, alive and no WHIP screen open (client/status.lua)
        visible = true,
        inventoryOpen = false, -- WHIP's inventory already counts as an open screen
        locale = D11Hud.Locale,
        logo = D11Hud.Logo == true,
        showStatus = D11Hud.Status ~= false,
        dynamic = D11Hud.Dynamic ~= false,
        nitro = { visible = false, level = 0.0, burst = false },
        turbo = { visible = false, psi = 0.0, max = 0.0 },
    },
}

-- Natives in this build can answer 1/0 instead of a boolean (0 is true in Lua): every check goes through yes().
function Hud.yes(value) return value == true or value == 1 end

function Hud.set(key, value)
    Hud.state[key] = value
    SendNUIMessage({ action = key, payload = value })
end

function Hud.snapshot()
    SendNUIMessage({ action = 'snapshot', payload = Hud.state })
end

--- exports.whip_core:<name>(...) without breaking while whip_core starts or restarts.
function Hud.core(name, ...)
    if GetResourceState('whip_core') ~= 'started' then return nil end
    local args = { ... }
    local ok, value = pcall(function() return exports.whip_core[name](exports.whip_core, table.unpack(args)) end)
    if ok then return value end
end

RegisterNUICallback('ready', function(_, cb)
    Hud.snapshot()
    cb({ ok = true })
end)

-- the speedometer reports its own edge (the action hints move left of it); nothing to answer
RegisterNUICallback('gaugeBounds', function(_, cb) cb({ ok = true }) end)
