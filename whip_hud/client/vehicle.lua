-- The speedometer, fed from WHIP:
--   fuel/charge .. whip_fuel's 'fuel' vehicle stat (GetVehicleStat), else GTA's
--   electric ..... whip_core IsVehicleElectric
--   rpm/gear ..... natives (GetVehicleCurrentRpm, the same reading as WHIP's own dial)
--   seatbelt ..... client/seatbelt.lua
--   turbo/nitro .. client/power.lua (whip_autos)
-- Only the driver sees it. Aircraft (classes 15/16) get heading, altitude, climb rate and the artificial horizon.

local L = D11Hud.L
local UPDATE_MS = 100
local LOCKED = { [2] = true, [3] = true, [4] = true, [7] = true, [10] = true }
local ROLL_SIGN = -1
local GEAR = { [0] = 'down', [1] = 'moving', [2] = 'moving', [3] = 'up' }
local KMH = D11Hud.SpeedUnit == 'kmh'
local yes = Hud.yes

local letters = {}
for d in L('N NE E SE S SW W NW', 'N NE L SE S SO O NO'):gmatch('%S+') do letters[#letters + 1] = d end

local function clamp01(value) return math.max(0.0, math.min(1.0, tonumber(value) or 0.0)) end

--- The compass letter for a heading in degrees (client/map.lua uses it too).
function Hud.direction(heading) return letters[math.floor(((heading % 360) + 22.5) / 45) % 8 + 1] end

local function readAircraft(vehicle, class)
    local rotation = GetEntityRotation(vehicle, 2)
    local gear
    if class == 16 and yes(DoesVehicleHaveLandingGear(vehicle)) then
        gear = GEAR[GetLandingGearState(vehicle)] or 'broken'
    end
    local heading = (360.0 - GetEntityHeading(vehicle)) % 360.0
    return {
        heli = class == 15,
        knots = GetEntitySpeed(vehicle) * 1.94384,
        altitude = GetEntityCoords(vehicle).z * 3.28084,
        agl = math.max(0, GetEntityHeightAboveGround(vehicle) * 3.28084),
        vs = GetEntityVelocity(vehicle).z * 196.85,
        heading = heading,
        direction = Hud.direction(heading),
        pitch = rotation.x,
        roll = rotation.y * ROLL_SIGN,
        gear = gear,
        rotor = class == 15 and clamp01(GetHeliMainRotorHealth(vehicle) / 1000) or nil,
        airborne = yes(IsEntityInAir(vehicle)),
    }
end

local function getGear(vehicle, electric)
    local gear = GetVehicleCurrentGear(vehicle)
    local text
    if gear > 0 then text = tostring(gear)
    else text = GetEntitySpeedVector(vehicle, true).y < -0.1 and 'R' or 'N' end
    if electric and text ~= 'R' and text ~= 'N' then return 'D' end
    return text
end

local function getFuel(vehicle)
    local fuel = tonumber(Hud.core('GetVehicleStat', { entity = vehicle }, 'fuel')) or GetVehicleFuelLevel(vehicle)
    return clamp01(fuel / 100)
end

local function readVehicle(vehicle)
    local class = GetVehicleClass(vehicle)
    local electric = Hud.core('IsVehicleElectric', vehicle) == true
    local _, lights, highbeams = GetVehicleLightsState(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local running = yes(GetIsVehicleEngineRunning(vehicle))
    local aircraft = (class == 15 or class == 16) and readAircraft(vehicle, class) or nil
    return {
        visible = true,
        aircraft = aircraft,
        speed = GetEntitySpeed(vehicle) * (KMH and 3.6 or 2.237),
        unit = KMH and 'KM/H' or 'MPH',
        -- GetVehicleCurrentRpm: 0.2 at idle to 1.0 at the limiter (GetVehicleDashboardRpm answers 0 in this build)
        rpm = running and clamp01(GetVehicleCurrentRpm(vehicle)) or 0.0,
        gear = getGear(vehicle, electric),
        electric = electric,
        fuel = getFuel(vehicle),
        fuelVisible = class ~= 13,
        lights = yes(lights),
        highbeams = yes(highbeams),
        locked = LOCKED[GetVehicleDoorLockStatus(vehicle)] == true,
        engineVisible = class ~= 13,
        engineHealth = clamp01(engineHealth / 1000),
        engineRunning = running,
        checkEngine = engineHealth <= 300,
        seatbeltVisible = Hud.hasSeatbelt(vehicle),
        seatbelt = Hud.state.seatbelt == true,
    }
end

local function driving()
    if not Hud.state.active then return nil end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped and yes(DoesEntityExist(vehicle)) then return vehicle end
end

CreateThread(function()
    local shown = false
    while true do
        local vehicle = driving()
        if vehicle then
            Hud.set('vehicle', readVehicle(vehicle))
            Hud.power(vehicle)
            shown = true
            Wait(UPDATE_MS)
        else
            if shown then
                Hud.set('vehicle', { visible = false })
                Hud.power(nil)
                shown = false
            end
            Wait(250)
        end
    end
end)
