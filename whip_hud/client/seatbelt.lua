-- A small seatbelt (WHIP has none). The key toggles it; a crash above D11Hud.Seatbelt.EjectKmh without it
-- (EjectBuckledKmh with it) throws you through the windscreen; buckled, F (leave the vehicle) is blocked; getting out
-- unbuckles. Motorbikes, bicycles, boats and aircraft have no belt.
-- The driver sees it on the speedometer (client/vehicle.lua reads Hud.state.seatbelt), a passenger on a small icon.
-- LocalPlayer.state.seatbelt (local only) is there for other resources to read.

local L = D11Hud.L
local cfg = D11Hud.Seatbelt
local NO_BELT = { [8] = true, [13] = true, [14] = true, [15] = true, [16] = true }
local yes = Hud.yes

Hud.state.seatbelt = false
Hud.state.passengerBelt = { visible = false, buckled = false }

function Hud.hasSeatbelt(vehicle)
    return cfg.Enabled ~= false and vehicle ~= 0 and not NO_BELT[GetVehicleClass(vehicle)]
end

if cfg.Enabled == false then return end

local KMH = 3.6
local EJECT_UNBUCKLED = (tonumber(cfg.EjectKmh) or 20) / KMH
local EJECT_BUCKLED = (tonumber(cfg.EjectBuckledKmh) or 160) / KMH

local function currentVehicle()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle ~= 0 and yes(DoesEntityExist(vehicle)) then return vehicle end
    return 0
end

local function setBelt(buckled)
    if Hud.state.seatbelt == buckled then return end
    Hud.set('seatbelt', buckled)
    LocalPlayer.state:set('seatbelt', buckled, false)
    SetFlyThroughWindscreenParams(buckled and EJECT_BUCKLED or EJECT_UNBUCKLED, 1.0, 17.0, 10.0)
    PlaySoundFrontend(-1, buckled and 'NAV_UP_DOWN' or 'NAV_LEFT_RIGHT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

RegisterCommand('whip_seatbelt', function()
    if IsPauseMenuActive() or not Hud.state.active then return end
    if not Hud.hasSeatbelt(currentVehicle()) then return end
    setBelt(not Hud.state.seatbelt)
end, false)
RegisterKeyMapping('whip_seatbelt', L('Vehicle: seatbelt', 'Veículo: cinto de segurança'), 'keyboard', cfg.Key or 'B')

local function passengerSeat(vehicle, ped)
    for seat = 0, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if GetPedInVehicleSeat(vehicle, seat) == ped then return true end
    end
    return false
end

local function pushPassenger(vehicle)
    local ped = PlayerPedId()
    local visible = Hud.state.active and Hud.hasSeatbelt(vehicle) and passengerSeat(vehicle, ped)
    local belt = Hud.state.passengerBelt
    if belt.visible == visible and belt.buckled == Hud.state.seatbelt then return end
    Hud.set('passengerBelt', { visible = visible, buckled = Hud.state.seatbelt })
end

CreateThread(function()
    SetFlyThroughWindscreenParams(EJECT_UNBUCKLED, 1.0, 17.0, 10.0)
    while true do
        local vehicle = currentVehicle()
        if vehicle == 0 then
            setBelt(false)
            pushPassenger(0)
            Wait(500)
        elseif Hud.state.seatbelt then
            DisableControlAction(0, 75, true) -- F: leave the vehicle
            DisableControlAction(27, 75, true)
            pushPassenger(vehicle)
            Wait(0)
        else
            pushPassenger(vehicle)
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    LocalPlayer.state:set('seatbelt', false, false)
    SetFlyThroughWindscreenParams(EJECT_UNBUCKLED, 1.0, 17.0, 10.0)
end)
