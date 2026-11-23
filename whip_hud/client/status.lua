-- Player status, 0-100 whole numbers, read from WHIP:
--   health ...... native: GTA kills at 100, so 200 = 100% and 100 = 0%
--   armour ...... native
--   hunger/thirst whip_core stats (GetStat); stress if some resource registers a 'stress' stat
--   energy ...... GTA's sprint stamina, or D11Hud.Stamina's export
--   oxygen ...... whip_core 'oxygen' stat, else GTA's time left under water
-- Shown like WHIP's own status HUD: logged in, alive and no screen open.

local POLL_MS = 200
local SHOW = D11Hud.Status ~= false   -- false: WHIP's own gauges stay, whip_hud draws none

local function pct(value)
    value = tonumber(value) or 0
    return math.floor(math.max(0, math.min(100, value)) + 0.5)
end

local function health(ped)
    local raw, max = GetEntityHealth(ped), GetEntityMaxHealth(ped)
    local floor = max > 100 and 100 or 0
    return pct((raw - floor) / math.max(1, max - floor) * 100)
end

local function customStamina()
    local source = D11Hud.Stamina
    if type(source) ~= 'table' or GetResourceState(source.resource or '') ~= 'started' then return nil end
    local ok, value = pcall(function() return exports[source.resource][source.export]() end)
    return ok and tonumber(value) or nil
end

local function readStatus()
    local ped, player = PlayerPedId(), PlayerId()
    return {
        health = health(ped),
        armor = pct(GetPedArmour(ped)),
        hunger = pct(Hud.core('GetStat', 'hunger') or 100),
        thirst = pct(Hud.core('GetStat', 'thirst') or 100),
        stress = pct(Hud.core('GetStat', 'stress') or 0),
        energy = pct(customStamina() or 100 - GetPlayerSprintStaminaRemaining(player)),
        oxygen = pct(Hud.core('GetStat', 'oxygen') or GetPlayerUnderwaterTimeRemaining(player) * 10),
    }
end

local function isActive()
    if Hud.core('IsPlayerLoaded') ~= true then return false end
    if Hud.core('IsPlayerDead') == true then return false end
    return Hud.core('IsAnyScreenOpen', true) ~= true
end

local function changed(a, b)
    if not b then return true end
    for key, value in pairs(a) do
        if b[key] ~= value then return true end
    end
    return false
end

CreateThread(function()
    local last
    while true do
        local active = isActive()
        if Hud.state.active ~= active then
            Hud.set('active', active)
            if not active then last = nil end
        end
        if active and SHOW then
            local status = readStatus()
            if changed(status, last) then
                last = status
                Hud.set('status', status)
            end
        end
        Wait(POLL_MS)
    end
end)
