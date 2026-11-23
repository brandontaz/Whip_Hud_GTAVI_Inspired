-- The weapon in hand and its ammo, read from whip_gunny:
--   rounds / capacity .. whip_gunny GetDrawnWeapon (ammo = rounds in the weapon, capacity = the magazine in it); with
--                        no magazine in, the first compatible magazine's size (0/12: an empty weapon)
--   spare (next to the
--   magazine icon) ..... magazine weapons: COMPATIBLE magazines with rounds in your pockets (metadata.ammo, the way
--                        gunny's reload picks one); weapons without one (revolver, shotgun): loose rounds of the calibre
--   without whip_gunny . GTA's own ammo
--   silhouette ......... ui/weapons/catalogue.json: the weapon plus the attachments really mounted on it; tools
--                        (camera, metal detector, shovel) while the prop is attached to the player
-- Read only: it never changes the weapon.

if D11Hud.Ammo == false then return end

local yes = Hud.yes
local UNARMED_HASH = `WEAPON_UNARMED`
local MELEE_GROUP = `GROUP_MELEE`

-- ---------- silhouettes ----------
local weapons, props = {}, {}
local catalogue = json.decode(LoadResourceFile(GetCurrentResourceName(), 'ui/weapons/catalogue.json') or '{}') or {}
for name, entry in pairs(catalogue) do
    entry.folder = 'weapons/' .. name:lower() .. '/'
    entry.componentHashes = {}
    for variantName, variant in pairs(entry.variants) do
        if variantName ~= 'base' then entry.componentHashes[variantName] = joaat(variantName) end
        for _, group in ipairs(variant.groups) do
            for _, component in ipairs(group) do
                entry.componentHashes[component.component] = joaat(component.component)
            end
        end
    end
    if entry.propModel then props[joaat(entry.propModel)] = entry
    else weapons[joaat(name)] = entry end
end

local lastPed, lastHash, lastCheck, cachedKey, cachedLayers = nil, nil, 0, '', {}

local function weaponVisual(ped, hash)
    local now = GetGameTimer()
    if ped == lastPed and hash == lastHash and now >= lastCheck and now - lastCheck < 150 then
        return cachedKey, cachedLayers
    end
    lastPed, lastHash, lastCheck = ped, hash, now
    local entry = weapons[hash]
    local layers = {}
    if entry then
        local function equipped(name)
            return yes(HasPedGotWeaponComponent(ped, hash, entry.componentHashes[name]))
        end
        local variant = entry.variants.base
        for name, candidate in pairs(entry.variants) do
            if name ~= 'base' and equipped(name) then variant = candidate; break end
        end
        layers[1] = entry.folder .. variant.image
        for _, group in ipairs(variant.groups) do
            local selected, default
            for _, component in ipairs(group) do
                if component.default then
                    default = component
                elseif equipped(component.component) then
                    selected = component
                    break
                end
            end
            selected = selected or default
            if selected then layers[#layers + 1] = entry.folder .. selected.image end
        end
    end
    cachedLayers, cachedKey = layers, table.concat(layers, '|')
    return cachedKey, cachedLayers
end

local toolPed, toolCheck, toolEntity, toolEntry = nil, 0, nil, nil
local function heldToolVisual(ped)
    local now = GetGameTimer()
    if ped ~= toolPed or now < toolCheck or now - toolCheck >= 500 then
        toolPed, toolCheck, toolEntity, toolEntry = ped, now, nil, nil
        for _, entity in ipairs(GetGamePool('CObject')) do
            local entry = props[GetEntityModel(entity)]
            if entry and yes(IsEntityAttachedToEntity(entity, ped)) then
                if not toolEntry or entry.folder > toolEntry.folder then
                    toolEntity, toolEntry = entity, entry
                end
            end
        end
    end
    if toolEntity and yes(DoesEntityExist(toolEntity)) and yes(IsEntityAttachedToEntity(toolEntity, ped))
        and props[GetEntityModel(toolEntity)] == toolEntry then
        local path = toolEntry.folder .. toolEntry.variants.base.image
        return path, { path }
    end
    return '', {}
end

-- ---------- ammo ----------
-- whip_gunny's catalogue, read from its own files (Config.Weapons/Magazines/Calibers in items/*.lua): which magazines
-- each weapon takes, their size and each calibre's round item. gunny's exports only say what is in your hand.
local gunny = { weapons = {}, magazines = {}, calibers = {} }
local function loadGunnyCatalogue()
    if GetResourceState('whip_gunny') ~= 'started' then return end
    local env = setmetatable({ Config = {} }, { __index = _G })
    for _, file in ipairs({ 'items/calibers.lua', 'items/magazines.lua', 'items/weapons.lua' }) do
        local code = LoadResourceFile('whip_gunny', file)
        local chunk = code and load(code, '@whip_gunny/' .. file, 't', env)
        if chunk then pcall(chunk) end
    end
    gunny.weapons = env.Config.Weapons or {}
    gunny.magazines = env.Config.Magazines or {}
    gunny.calibers = env.Config.Calibers or {}
end
loadGunnyCatalogue()
AddEventHandler('onClientResourceStart', function(name) if name == 'whip_gunny' then loadGunnyCatalogue() end end)

local function gunnyWeapon()
    if GetResourceState('whip_gunny') ~= 'started' then return nil end
    local ok, w = pcall(function() return exports.whip_gunny:GetDrawnWeapon() end)
    return ok and type(w) == 'table' and w or nil
end

--- What you carry (pockets and the accessory strip), a list of { item, amount, metadata }.
local function carried()
    local inv = Hud.core('GetInventory')
    local list = {}
    for _, container in ipairs({ 'player', 'accessory' }) do
        for _, data in pairs(type(inv) == 'table' and inv[container] or {}) do list[#list + 1] = data end
    end
    return list
end

--- Spare: compatible magazines with rounds (magazine weapons) or loose rounds of the calibre (weapons without one).
--- Read at most every 500 ms (the loop runs at 50 ms and GetInventory copies the whole inventory).
local reserveCache = { item = nil, at = 0, value = 0 }
local function gunnyReserve(cfg, item)
    if not cfg then return 0 end
    local now = GetGameTimer()
    if reserveCache.item == item and now - reserveCache.at < 500 then return reserveCache.value end
    reserveCache.item, reserveCache.at = item, now
    reserveCache.value = 0
    if cfg.magless then
        local caliber = gunny.calibers[cfg.caliber]
        reserveCache.value = caliber and tonumber(Hud.core('GetItemCount', caliber.ammoItem)) or 0
        return reserveCache.value
    end
    local takes = {}
    for _, mag in ipairs(cfg.compatibleMags or {}) do takes[mag] = true end
    local mags = 0
    for _, data in ipairs(carried()) do
        local ammo = type(data.metadata) == 'table' and tonumber(data.metadata.ammo) or 0
        if takes[data.item] and ammo > 0 then mags = mags + (tonumber(data.amount) or 1) end
    end
    reserveCache.value = mags
    return mags
end

local function readAmmo(ped, hash)
    local w = gunnyWeapon()
    if w and w.kind == 'gun' and (tonumber(w.capacity) or gunny.weapons[w.item]) then
        local cfg = gunny.weapons[w.item]
        local max = tonumber(w.capacity)
        if not max and cfg then   -- a magazine weapon with no magazine in: the first compatible one's size
            max = cfg.magless and tonumber(cfg.internalCapacity)
                or (cfg.compatibleMags and gunny.magazines[cfg.compatibleMags[1]] and tonumber(gunny.magazines[cfg.compatibleMags[1]].capacity))
        end
        max = math.floor(max or 0)
        local clip = math.max(0, math.floor(tonumber(w.ammo) or 0))
        if max > 0 then clip = math.min(clip, max) end
        return clip, max, gunnyReserve(cfg, w.item)
    end
    local hasClip, nativeClip = GetAmmoInClip(ped, hash)
    local clip = yes(hasClip) and nativeClip or 0
    local max = GetMaxAmmoInClip(ped, hash, true) or 0
    local reserve = math.max(0, (GetAmmoInPedWeapon(ped, hash) or 0) - clip)
    local spare = max > 0 and math.floor(reserve / max) or 0
    return math.floor(clip), math.floor(math.max(0, max)), spare
end

CreateThread(function()
    local visible, lastWeapon, lastClip, lastMax, lastSpare, lastKey, lastInVehicle = false, nil, -1, -1, -1, nil, nil
    while true do
        local ped = PlayerPedId()
        local inVehicle = yes(IsPedInAnyVehicle(ped, false))
        local gotWeapon, hash = GetCurrentPedWeapon(ped, true)
        local hasWeapon = yes(gotWeapon)
        local armed = hasWeapon and hash ~= UNARMED_HASH
        local melee = armed and GetWeapontypeGroup(hash) == MELEE_GROUP

        local show, clip, max, spare = false, 0, 0, 0
        if armed and not melee then
            clip, max, spare = readAmmo(ped, hash)
            show = true
        end

        local key, layers = weaponVisual(ped, armed and hash or UNARMED_HASH)
        if not armed and not yes(IsEntityDead(ped)) then
            key, layers = heldToolVisual(ped)
            melee = key ~= ''
        end
        if melee then show = key ~= '' end
        if not Hud.state.active then show = false end

        if show ~= visible or hash ~= lastWeapon or clip ~= lastClip or max ~= lastMax or spare ~= lastSpare
            or key ~= lastKey or inVehicle ~= lastInVehicle then
            visible, lastWeapon, lastClip, lastMax, lastSpare, lastKey, lastInVehicle = show, hash, clip, max, spare, key, inVehicle
            Hud.set('ammo', {
                visible = show,
                inVehicle = inVehicle,
                showAmmo = not melee,
                clip = clip,
                max = max,
                spare = spare,
                visualKey = key,
                layers = layers,   -- always: the snapshot (page reloaded) needs the layers
            })
        end
        Wait(show and 50 or 150)
    end
end)
