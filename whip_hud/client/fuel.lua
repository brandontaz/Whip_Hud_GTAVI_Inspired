-- Low fuel warning: every 10 s, driving with D11Hud.LowFuel.Threshold % or less in the tank, a WHIP notification;
-- again every RepeatSeconds until refuelled. Reads whip_fuel's 'fuel' vehicle stat, else GTA's. Electric: battery.

local L = D11Hud.L
local cfg = D11Hud.LowFuel
if cfg.Enabled == false then return end

local yes = Hud.yes
local threshold = tonumber(cfg.Threshold) or 20
local repeatMs = (tonumber(cfg.RepeatSeconds) or 60) * 1000

local function fuelLevel(vehicle)
    local fuel = tonumber(Hud.core('GetVehicleStat', { entity = vehicle }, 'fuel')) or tonumber(GetVehicleFuelLevel(vehicle)) or 100
    return math.floor(math.max(0, math.min(100, fuel)))
end

local function drivenVehicle()
    if not Hud.state.active then return nil end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped or not yes(DoesEntityExist(vehicle)) then return nil end
    if GetVehicleClass(vehicle) == 13 or yes(IsThisModelABicycle(GetEntityModel(vehicle))) then return nil end
    return vehicle
end

CreateThread(function()
    while true do
        Wait(10000)
        local vehicle = drivenVehicle()
        if vehicle and fuelLevel(vehicle) <= threshold then
            local electric = Hud.core('IsVehicleElectric', vehicle) == true
            Hud.core('Notify', electric and L('Battery low!', 'Nível de bateria baixo!')
                or L('Fuel low!', 'Nível de combustível baixo!'), 'error', 5000)
            Wait(repeatMs)
        end
    end
end)
