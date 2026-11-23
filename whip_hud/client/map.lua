-- The ring over WHIP's minimap: a compass that turns with the camera, the heading in degrees, and area and street
-- under it. The map itself is WHIP's (#minimap3d), clipped round under the ring by whip/hud.css.
--   radar ..... shown when WHIP shows the minimap: in a vehicle / on foot as the player set it in WHIP's map options
--               (GetPlayerSetting 'map.inVehicle' / 'map.onFoot'), with the HUD active (logged in, alive, no screen)
--   heading ... the camera's, 20 times a second in half-degree steps (sent only when it moves)
--   location .. area and street, every second

if D11Hud.Radar == false then return end

local LOCATION_MS = 1000
local yes = Hud.yes

local function minimapShown()
    if not Hud.state.active or Hud.state.visible == false or IsPauseMenuActive() then return false end
    if yes(IsPedInAnyVehicle(PlayerPedId(), false)) then return Hud.core('GetPlayerSetting', 'map.inVehicle') ~= false end
    return Hud.core('GetPlayerSetting', 'map.onFoot') == true
end

local lastLocation = {}

local function refreshLocation()
    local pos = GetEntityCoords(PlayerPedId())
    local heading = (360.0 - ((GetGameplayCamRot(0).z + 360.0) % 360.0)) % 360.0
    local loc = {
        show = Hud.state.radar == true,
        direction = Hud.direction(heading),
        heading = heading,
        street = GetStreetNameFromHashKey((GetStreetNameAtCoord(pos.x, pos.y, pos.z))),
        area = GetLabelText(GetNameOfZone(pos.x, pos.y, pos.z)),
    }
    if loc.show ~= lastLocation.show or loc.street ~= lastLocation.street or loc.area ~= lastLocation.area then
        lastLocation = loc
        Hud.set('location', loc)
    end
end

-- radar on/off, area and street
CreateThread(function()
    local nextLocation = 0
    while true do
        local show = minimapShown()
        if show ~= (Hud.state.radar == true) then
            Hud.set('radar', show)
            nextLocation = 0
        end
        if show and GetGameTimer() >= nextLocation then
            refreshLocation()
            nextLocation = GetGameTimer() + LOCATION_MS
        end
        Wait(show and 250 or 500)
    end
end)

-- the heading, light, only with the radar on screen
CreateThread(function()
    while true do
        if Hud.state.radar == true then
            local heading = math.floor(((360.0 - GetGameplayCamRot(0).z) % 360) * 2) / 2
            if Hud.state.heading ~= heading then Hud.set('heading', heading) end
            Wait(50)
        else
            Wait(250)
        end
    end
end)

-- Minimap defaults, once per PC (KVP), through WHIP's own player settings and only where the player is still on
-- WHIP's default; afterwards they change them in WHIP's map options as they like.
--   map.onFoot ............ the minimap on foot too
--   mm.viewSlow/viewFast .. 25% less zoom in a vehicle (metres shown / 0.75, on each slider's step)
if D11Hud.MapDefaults == false then return end

local MAP_DEFAULTS_KVP = 'd12_map_defaults_v1'
local MAP_DEFAULTS = {
    { key = 'map.onFoot', whip = false, d11 = true },
    { key = 'mm.viewSlow', whip = 290, d11 = 390 },   -- 290 / 0.75 = 387 (step 10)
    { key = 'mm.viewFast', whip = 800, d11 = 1050 },  -- 800 / 0.75 = 1067 (step 50)
}

AddEventHandler('whip_core:player:loaded', function()
    if GetResourceKvpString(MAP_DEFAULTS_KVP) == 'done' then return end
    SetTimeout(2000, function()
        for _, d in ipairs(MAP_DEFAULTS) do
            if Hud.core('GetPlayerSetting', d.key) == d.whip then Hud.core('SetPlayerSetting', d.key, d.d11) end
        end
        SetResourceKvp(MAP_DEFAULTS_KVP, 'done')
    end)
end)
