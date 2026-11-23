-- The GPS card next to the radar ring: the next turn's arrow, the distance to it and the distance left. Only with the
-- radar on screen (Hud.state.radar, client/map.lua).
-- The waypoint: GetGpsBlipRouteLength does not see it, so its distance comes from a path calculation, or a straight
-- line when there is no path. A script route uses the native length.

if D11Hud.Radar == false or D11Hud.Route == false then return end

local ROUTE_MS = 150        -- arrow and distance to the turn
local DISTANCE_MS = 1000    -- distance left (path calculation, dearer)
local ARRIVED_METERS = 15
local WAYPOINT_SPRITE = 8
local NO_PATH_METERS = 100000.0
local yes = Hud.yes

-- The turn is read off the GPS line itself (the one WHIP's minimap draws: GetPosAlongGpsTypeRoute), not from
-- GenerateDirectionsToCoord, whose codes pointed the wrong way here. The route is sampled every STEP metres from the
-- player; the first change of heading above TURN_DEG against the current stretch is the turn: its side from the sign
-- of the angle, sharp above SHARP_DEG, and the distance to it.
local STEP, LOOK_AHEAD = 10.0, 400.0
local TURN_DEG, SHARP_DEG = 35.0, 115.0

local posAlongRoute = GetPosAlongGpsTypeRoute or function(fromPlayer, dist, slot)
    return Citizen.InvokeNative(0xF3162836C28F9DA5, Citizen.PointerValueVector(), fromPlayer, dist, slot,
        Citizen.ReturnResultAnyway())
end

--- The route's points in a slot (0 = waypoint, 1 = script route), from the player up to LOOK_AHEAD, or nil.
local function routePoints(slot)
    local pts = {}
    for d = 0.0, LOOK_AHEAD, STEP do
        local ok, p = posAlongRoute(true, d, slot)
        if ok == 0 or not ok or (type(p) ~= 'vector3' and type(p) ~= 'table') then break end
        if p.x == 0.0 and p.y == 0.0 then break end
        local last = pts[#pts]
        if last and math.abs(p.x - last.x) < 0.5 and math.abs(p.y - last.y) < 0.5 then break end   -- end of the route
        pts[#pts + 1] = p
    end
    return #pts >= 3 and pts or nil
end

--- Signed angle (degrees) from a to b: positive = left (x east, y north: anticlockwise).
local function turnAngle(ax, ay, bx, by)
    return math.deg(math.atan(ax * by - ay * bx, ax * bx + ay * by))
end

--- The line's next turn: its name and the metres to it, or 'straight' with no turn in range.
local function maneuverFromLine(pts)
    local ax, ay = pts[3].x - pts[1].x, pts[3].y - pts[1].y   -- the current stretch (20 m)
    for i = 3, #pts - 2 do
        local bx, by = pts[i + 2].x - pts[i].x, pts[i + 2].y - pts[i].y
        local angle = turnAngle(ax, ay, bx, by)
        if math.abs(angle) >= TURN_DEG then
            -- side and strength from the stretch after the turn, a little further on when there is one
            local j = math.min(#pts - 1, i + 3)
            local after = turnAngle(ax, ay, pts[j + 1].x - pts[j].x, pts[j + 1].y - pts[j].y)
            if math.abs(after) < math.abs(angle) then after = angle end
            local left = after > 0
            local name = math.abs(after) >= SHARP_DEG and (left and 'sharpLeft' or 'sharpRight') or (left and 'left' or 'right')
            return name, i * STEP   -- the stretch i..i+2 has the corner in the middle, at pts[i+1]
        end
    end
    return 'straight', nil
end

local total = { meters = 0, at = -DISTANCE_MS }

local function waypointMeters(pos, target)
    local now = GetGameTimer()
    if now - total.at < DISTANCE_MS then return total.meters end
    local meters = CalculateTravelDistanceBetweenPoints(pos.x, pos.y, pos.z, target.x, target.y, target.z)
    if meters <= 0 or meters >= NO_PATH_METERS then
        meters = math.sqrt((target.x - pos.x) ^ 2 + (target.y - pos.y) ^ 2)
    end
    total.meters, total.at = meters, now
    return meters
end

local function readRoute()
    if Hud.state.radar ~= true then return false end
    local waypoint = yes(IsWaypointActive())
    local meters
    if waypoint then
        local target = GetBlipInfoIdCoord(GetFirstBlipInfoId(WAYPOINT_SPRITE))
        meters = math.floor(waypointMeters(GetEntityCoords(PlayerPedId()), target))
    else
        total.at = -DISTANCE_MS
        meters = math.floor(GetGpsBlipRouteLength())
    end
    if meters < ARRIVED_METERS then return false end

    local route = { meters = meters - meters % 10, maneuver = 'straight' }
    local pts = routePoints(waypoint and 0 or 1)
    if pts then
        local name, ahead = maneuverFromLine(pts)
        route.maneuver = name
        if ahead and ahead >= 10 then route.ahead = math.floor(ahead - ahead % 10) end
    end
    return route
end

local function refreshRoute()
    local route = readRoute()
    local last = Hud.state.route
    if not route and not last then return end
    if route and last and route.meters == last.meters and route.maneuver == last.maneuver
        and route.ahead == last.ahead then return end
    Hud.set('route', route)
end

CreateThread(function()
    while true do
        if not yes(IsPauseMenuActive()) then refreshRoute() end
        Wait(ROUTE_MS)
    end
end)
