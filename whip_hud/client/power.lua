-- Turbo and nitrous from whip_autos. Both are whip_core vehicle stats:
--   boost .. 1..100, the gauge's scale for -3..30 psi (whip_autos shared/power.lua: PSI_LOW, PSI_HIGH). A car carries
--            it once a turbo stage is fitted; the stage is the car's 'turbo' vehicle data ({ psi }).
--   nitro .. 0..100, a full bottle. A car carries it once a bottle is fitted.
--
-- The driver's live numbers are whip_autos' own gauge readings, which whip_core keeps to itself. With the optional
-- patch (whip_core-vehicle-stat-reading-d11.patch: exports.whip_core:GetVehicleStatReading) whip_hud reads them
-- exactly. Without it, nitro is the stat as whip_core holds it (whip_autos bills the bottle as it burns, so it moves a
-- step behind), and boost, which whip_autos only shares while someone else is in the car, comes from GTA's own turbo
-- part (whip_autos fits it with every stage) scaled to the stage's psi: the same spool, not the same number.

local PSI_LOW, PSI_HIGH, LEVEL_MAX = -3, 30, 100
local IDLE_LEVEL = 1.0
local INFO_MS = 2000        -- a car's fitted parts are read again this often (a stage bought while sitting in it)
local BURST_HOLD_MS = 400   -- nitro counts as burning this long after the bottle last went down

-- nil: not tried since whip_core started; false: whip_core has no GetVehicleStatReading (patch not applied)
local exact = nil
AddEventHandler('onClientResourceStart', function(name) if name == 'whip_core' then exact = nil end end)

local function liveReading(veh, name)
    if exact == false or GetResourceState('whip_core') ~= 'started' then return nil end
    local ok, value = pcall(function() return exports.whip_core:GetVehicleStatReading(name, { entity = veh }) end)
    exact = ok
    return ok and tonumber(value) or nil
end

local function stat(veh, name)
    return tonumber(Hud.core('GetVehicleStat', { entity = veh }, name))
end

local info = { vehicle = nil, at = 0 }
local function fitted(veh)
    local now = GetGameTimer()
    if info.vehicle == veh and now - info.at < INFO_MS then return info end
    local ref = { entity = veh }
    local turbo = D11Hud.Turbo ~= false and Hud.core('HasVehicleStat', ref, 'boost') == true
    local data = turbo and Hud.core('GetVehicleData', ref, 'turbo') or nil
    info = {
        vehicle = veh,
        at = now,
        turbo = turbo,
        psi = type(data) == 'table' and tonumber(data.psi) or PSI_HIGH,
        nitro = D11Hud.Nitro ~= false and Hud.core('HasVehicleStat', ref, 'nitro') == true,
    }
    return info
end

local function levelToPsi(level)
    return PSI_LOW + math.max(0, math.min(LEVEL_MAX, level)) / LEVEL_MAX * (PSI_HIGH - PSI_LOW)
end

local function boostPsi(veh, stagePsi)
    local level = liveReading(veh, 'boost')
    if level then return levelToPsi(level) end
    level = stat(veh, 'boost')
    if level and level > IDLE_LEVEL + 0.5 then return levelToPsi(level) end   -- someone else is in: the live number
    if not Hud.yes(GetIsVehicleEngineRunning(veh)) then return levelToPsi(IDLE_LEVEL) end
    local pressure = GetVehicleTurboPressure and tonumber(GetVehicleTurboPressure(veh)) or 0.0
    if pressure >= 0 then return math.min(1.0, pressure) * stagePsi end
    return math.max(PSI_LOW, pressure * -PSI_LOW)   -- off the throttle: vacuum
end

local lastNitro, burstUntil = nil, 0
local function nitroLevel(veh)
    local level = liveReading(veh, 'nitro') or stat(veh, 'nitro') or 0
    local now = GetGameTimer()
    if lastNitro and level < lastNitro - 0.01 then burstUntil = now + BURST_HOLD_MS end
    lastNitro = level
    return math.max(0, math.min(1, level / LEVEL_MAX)), now < burstUntil
end

local function round(value, step) return math.floor(value / step + 0.5) * step end

local function push(key, value)
    local last = Hud.state[key]
    for k, v in pairs(value) do
        if last[k] ~= v then return Hud.set(key, value) end
    end
end

--- Called by the speedometer loop (client/vehicle.lua) for the car being driven; nil when out of it.
function Hud.power(veh)
    local car = veh and fitted(veh)
    if car and car.turbo then
        push('turbo', { visible = true, psi = round(boostPsi(veh, car.psi), 0.1), max = car.psi })
    else
        push('turbo', { visible = false, psi = 0.0, max = 0.0 })
    end
    if car and car.nitro then
        local level, burst = nitroLevel(veh)
        push('nitro', { visible = true, level = round(level, 0.005), burst = burst })
    else
        lastNitro = nil
        push('nitro', { visible = false, level = 0.0, burst = false })
    end
end
