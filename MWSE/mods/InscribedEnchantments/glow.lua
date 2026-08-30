-- Inscribed Enchantments: the effect itself.
-- Draws Daedric glyph frames as an emissive glow map on every shape of an enchanted item, in the
-- item's own UV space, tinted by the enchantment's first effect colour. Animation is done by the
-- engine: each decorated shape gets a clone of a NiFlipController (loaded from meshes/ie/<colour>.nif)
-- that cycles the glow map through 192 frames. The animation clock is an "animated"
-- NiBSAnimationNode ("IE_anim", also cloned from the template): on its first update the engine
-- registers it with the cell's BSAnimationManager and, because it carries a NiVisController,
-- marks it always-update, so it is skipped by the ordinary animation pass and ticked by the
-- manager with global time. Two layouts, chosen per item:
--   * static (dropped/placed items): the authored NIF layout - the item's geometry is moved under
--     IE_anim and each flip controller sits on its shape's texturing property.
--   * worn (body parts): geometry must stay where the actor's animation and the paperdoll can
--     pose it, so IE_anim is attached as a childless clock that holds the controllers, each
--     still targeting its shape's property.
-- No per-frame Lua anywhere. The clock is never updated from Lua: the engine's first ordinary
-- update of the node registers it and marks it always-update, as it does for any animated NIF.
-- The engine's shared reflective effect is detached from every enchanted item node (its enabled
-- flag is only honoured for lights).
--
-- Assets: meshes/ie/<colour>.nif, textures/ie/<colour>/rune000..191.tga (see tools/generate_rune_sets.py).

local bit = require("bit")
local log = mwse.Logger.new()
local cfg = require("InscribedEnchantments.config").config

local glow = {}

local BASE_FPS = 12                     -- frame rate of the template controllers at frequency 1
local CLAMP_WRAP_WRAP = 3
local FILTER_TRILERP = 2
local CLOCK_NODE_NAME = "IE_anim"        -- the animated node authored in the template mesh
local VANILLA_EFFECT_NAME = "Enchanted Item Effect"   -- name the engine gives its shared texture effect
local AVOBJECT_FLAG_NOT_RANDOM = 0x40    -- NiAVObject flag: keep controller phases as authored
local CAST_ONCE, CAST_ON_STRIKE, CAST_ON_USE, CAST_CONSTANT = 0, 1, 2, 3

-- Baked glyph sets (see tools/generate_rune_sets.py): texture/mesh folder suffix and the mean
-- glyph height as a fraction of one texture repeat. The generator scales 27-34 px source glyphs
-- by 0.55-0.65 (normal, ~18.3 px) or 0.36-0.42 (small, ~11.9 px) in a 128 px tile; the sparse
-- sets keep their parent's glyph size and differ only in count and timing. The cracks set has
-- no glyph to size, so it is exempt from the height gate (fraction 0).
local GLYPH_SETS = {
    normal = { suffix = "", fraction = 18.3 / 128 },
    small = { suffix = "s", fraction = 11.9 / 128 },
    sparse = { suffix = "x", fraction = 18.3 / 128 },
    sparseSmall = { suffix = "xs", fraction = 11.9 / 128 },
    cracks = { suffix = "c", fraction = 0 },
    cracksHD = { suffix = "ch", fraction = 0 },
}

local function glyphSet()
    return GLYPH_SETS[cfg.glyphSize] or GLYPH_SETS.normal
end
-- For the log only: a character is 128 units and about 1.83 m tall.
local CM_PER_UNIT = 1.43

-- Must match the generated texture folders / template meshes. Hues follow the clusters in the
-- vanilla magic effect colours (MGEF lighting RGB).
glow.PALETTE = {
    ember = { 253, 66, 136 },
    blood = { 198, 57, 65 },
    rose = { 244, 185, 223 },
    lilac = { 176, 174, 255 },
    azure = { 0, 124, 217 },
    violet = { 152, 36, 168 },
    mint = { 166, 255, 224 },
    moss = { 128, 192, 128 },
    lime = { 202, 228, 97 },
    ivory = { 255, 255, 223 },
    white = { 255, 255, 255 },
}
local PALETTE = glow.PALETTE

local templates = {}      -- set folder -> { controller = niTimeController, texture = niSourceTexture, clock = niBSAnimationNode }
local uvStatsCache = {}   -- geometry uniqueID .. ":" .. maxStretch -> stats table, or false when unusable
local live = {}           -- list of { node, mode, clock, controllers = {}, shapes = { { shape, original } } }
                          -- Entries hold their nodes alive; pruneDead drops the ones the engine has discarded.

local sqrt, abs, log_, exp, max = math.sqrt, math.abs, math.log, math.exp, math.max

-- Templates --------------------------------------------------------------------------------------

-- Texture/mesh set for a colour: "<colour>" for the normal glyph size, "<colour>s" for small.
local function setFolder(colour)
    return colour .. glyphSet().suffix
end

-- Loads meshes/ie/<set>.nif once and returns its flip controller, first frame and animated node.
local function templateFor(colour)
    local folder = setFolder(colour)
    local t = templates[folder]
    if t then
        return t
    end
    local path = "ie\\" .. folder .. ".nif"
    local root = tes3.loadMesh(path)
    local shape = root and root:getObjectByName("glyphs")
    local prop = shape and shape.texturingProperty
    local controller = prop and prop.controller
    local map = prop and prop.glowMap
    local clock = root and root:getObjectByName(CLOCK_NODE_NAME)
    if not controller or not map or not map.texture or not clock then
        log:error("Template mesh %s is missing its glow map, flip controller or %s node.", path, CLOCK_NODE_NAME)
        return nil
    end
    t = { controller = controller, texture = map.texture, clock = clock }
    templates[folder] = t
    return t
end

-- Colour -----------------------------------------------------------------------------------------

-- Hue (degrees) and saturation of an RGB triple.
local function hueSat(r, g, b)
    local hi, lo = max(r, g, b), math.min(r, g, b)
    if hi <= 0 then
        return 0, 0
    end
    local sat = (hi - lo) / hi
    if hi == lo then
        return 0, sat
    end
    local d = hi - lo
    local h
    if hi == r then
        h = (g - b) / d % 6
    elseif hi == g then
        h = (b - r) / d + 2
    else
        h = (r - g) / d + 4
    end
    return h * 60, sat
end

local paletteHS = {}
for name, c in pairs(PALETTE) do
    local h, s = hueSat(c[1], c[2], c[3])
    paletteHS[name] = { h = h, s = s }
end

-- Vanilla effect colours are mostly pastels, so match on hue (weighted) and saturation rather
-- than on RGB distance, which would send every pale colour to white.
local function nearestColour(r, g, b)
    local h, s = hueSat(r, g, b)
    if s < 0.05 then
        return "white"
    end
    local best, bestDist = "white", math.huge
    for name, p in pairs(paletteHS) do
        if name ~= "white" then
            local dh = abs(h - p.h)
            if dh > 180 then
                dh = 360 - dh
            end
            local d = dh / 180 + 0.6 * abs(s - p.s)
            if d < bestDist then
                best, bestDist = name, d
            end
        end
    end
    return best
end

local function colourForEnchantment(ench)
    if cfg.colourMode == "fixed" then
        return PALETTE[cfg.fixedColour] and cfg.fixedColour or "white"
    end
    local first = ench.effects and ench.effects[1]
    local data = first and first.id >= 0 and tes3.getMagicEffect(first.id)
    if not data then
        return "white"
    end
    return nearestColour(data.lightingRed, data.lightingGreen, data.lightingBlue)
end

-- Filters ----------------------------------------------------------------------------------------

local function castTypeAllowed(castType)
    if castType == CAST_ONCE then return cfg.castOnce end
    if castType == CAST_ON_STRIKE then return cfg.castOnStrike end
    if castType == CAST_ON_USE then return cfg.castOnUse end
    if castType == CAST_CONSTANT then return cfg.castConstant end
    return false
end

local function itemTypeAllowed(item)
    local t = item.objectType
    if t == tes3.objectType.weapon then return cfg.weapons end
    if t == tes3.objectType.armor then return cfg.armor end
    if t == tes3.objectType.clothing then return cfg.clothing end
    return false
end

local meshBlacklistCache = { source = nil, list = {} }

local function meshBlacklist()
    if meshBlacklistCache.source ~= cfg.meshBlacklist then
        local list = {}
        for token in string.gmatch(cfg.meshBlacklist or "", "[^,]+") do
            token = token:lower():gsub("^%s+", ""):gsub("%s+$", "")
            if token ~= "" then
                list[#list + 1] = token
            end
        end
        meshBlacklistCache.source = cfg.meshBlacklist
        meshBlacklistCache.list = list
    end
    return meshBlacklistCache.list
end

-- Returns the enchantment to use for an item, or nil when the item should not glow.
local function enchantmentFor(item)
    local ench = item and item.enchantment
    if not ench then
        return nil
    end
    if not itemTypeAllowed(item) or not castTypeAllowed(ench.castType) then
        return nil
    end
    local blocked = cfg.blocked
    if blocked and next(blocked) then
        if blocked[item.id:lower()] then
            return nil
        end
        local sourceMod = item.sourceMod
        if sourceMod and blocked[sourceMod:lower()] then
            return nil
        end
    end
    local tokens = meshBlacklist()
    if #tokens > 0 then
        local mesh = item.mesh and item.mesh:lower() or ""
        for _, token in ipairs(tokens) do
            if mesh:find(token, 1, true) then
                return nil
            end
        end
    end
    return ench
end

-- UV quality --------------------------------------------------------------------------------------

-- Measures how the mesh's UV layout maps onto its surface. For each triangle the UV->world map is a
-- 3x2 matrix M; its singular values s1 >= s2 give the stretch ratio s1/s2 (1 = uniform) and the scale
-- sqrt(s1*s2) in model units per UV unit. Results are area-weighted over the shape and cached per
-- geometry data, so each model is measured once. Returns nil when there is no usable triangle data.
local function uvStats(shape)
    local data = shape.data
    if not data then
        return nil
    end
    local maxStretch = cfg.maxStretch or 2.2
    local key = data.uniqueID .. ":" .. maxStretch
    local cached = uvStatsCache[key]
    if cached ~= nil then
        return cached or nil
    end

    local verts, uvs, tris = data.vertices, data.texCoords, data.triangles
    local n = verts and #verts or 0
    if n == 0 or not uvs or #uvs < n or not tris or #tris == 0 then
        uvStatsCache[key] = false
        return nil
    end
    -- Copy positions and UVs into plain arrays once; the triangle loop then allocates nothing.
    local px, py, pz, tu, tv = {}, {}, {}, {}, {}
    for i = 1, n do
        local p, t = verts[i], uvs[i]
        px[i], py[i], pz[i], tu[i], tv[i] = p.x, p.y, p.z, t.x, t.y
    end
    local totalArea, stretchedArea, logScaleSum = 0, 0, 0
    for _, tri in pairs(tris) do
        local iv = tri.vertices
        local a, b, c = iv[1] + 1, iv[2] + 1, iv[3] + 1
        local e1x, e1y, e1z = px[b] - px[a], py[b] - py[a], pz[b] - pz[a]
        local e2x, e2y, e2z = px[c] - px[a], py[c] - py[a], pz[c] - pz[a]
        local du1, dv1 = tu[b] - tu[a], tv[b] - tv[a]
        local du2, dv2 = tu[c] - tu[a], tv[c] - tv[a]
        local uvDet = du1 * dv2 - du2 * dv1
        local cx, cy, cz = e1y * e2z - e1z * e2y, e1z * e2x - e1x * e2z, e1x * e2y - e1y * e2x
        local worldArea = 0.5 * sqrt(cx * cx + cy * cy + cz * cz)
        if abs(uvDet) > 1e-10 and worldArea > 1e-6 then
            -- Columns of M: world-space derivatives with respect to u and v.
            local inv = 1 / uvDet
            local mux, muy, muz = (e1x * dv2 - e2x * dv1) * inv, (e1y * dv2 - e2y * dv1) * inv, (e1z * dv2 - e2z * dv1) * inv
            local mvx, mvy, mvz = (e2x * du1 - e1x * du2) * inv, (e2y * du1 - e1y * du2) * inv, (e2z * du1 - e1z * du2) * inv
            -- Eigenvalues of M^T M.
            local g11 = mux * mux + muy * muy + muz * muz
            local g22 = mvx * mvx + mvy * mvy + mvz * mvz
            local g12 = mux * mvx + muy * mvy + muz * mvz
            local tr, det = g11 + g22, g11 * g22 - g12 * g12
            local disc = sqrt(max(0, tr * tr * 0.25 - det))
            local l1, l2 = tr * 0.5 + disc, max(1e-12, tr * 0.5 - disc)
            totalArea = totalArea + worldArea
            logScaleSum = logScaleSum + worldArea * 0.25 * log_(max(det, 1e-12))   -- log of (det)^(1/4)
            if sqrt(l1 / l2) > maxStretch then
                stretchedArea = stretchedArea + worldArea
            end
        end
    end
    if totalArea <= 0 then
        uvStatsCache[key] = false
        return nil
    end
    local stats = {
        stretchedFraction = stretchedArea / totalArea,
        scale = exp(logScaleSum / totalArea),   -- model units per UV unit
    }
    uvStatsCache[key] = stats
    return stats
end

-- Decides whether a shape's UV layout is good enough to carry glyphs.
local function uvAcceptable(shape)
    if not cfg.skipDistorted then
        return true
    end
    local stats = uvStats(shape)
    if not stats then
        return true
    end
    -- Height one glyph would have on this surface: its share of a texture repeat, times the
    -- surface's model units per repeat, times the object's scale in the world.
    local worldScale = shape.worldTransform and shape.worldTransform.scale or 1
    local fraction = glyphSet().fraction
    local ok = stats.stretchedFraction <= 0.5
    if fraction == 0 then
        log:debug("  %s: stretched %.0f%%, no glyph to size -> %s", shape.name or "?",
            stats.stretchedFraction * 100, ok and "ok" or "skipped")
        return ok
    end
    local glyphUnits = fraction * stats.scale * worldScale
    ok = ok and glyphUnits >= (cfg.minGlyphSize or 0) and glyphUnits <= (cfg.maxGlyphSize or math.huge)
    log:debug("  %s: stretched %.0f%%, glyph ~%.1f units (~%.0f cm) -> %s", shape.name or "?",
        stats.stretchedFraction * 100, glyphUnits, glyphUnits * CM_PER_UNIT, ok and "ok" or "skipped")
    return ok
end

-- Vanilla effect ---------------------------------------------------------------------------------

-- True when Assetless No Glow is active: it patches the engine so the vanilla sheen is never attached.
function glow.vanillaPatchedByOtherMod()
    return tes3.isLuaModActive("NoGlow")
end

-- The engine attaches one shared NiTextureEffect (a view-dependent environment map) to the root
-- node of every enchanted item: the reference's scene node, or the body part / weapon / shield
-- node. Its enabled flag is read only by the light manager, so the effect is detached from (or,
-- when the setting is off again, re-attached to) each such node instead.
local function vanillaEffect()
    local wc = tes3.worldController
    if wc and wc.enchantedItemEffectCreated then
        return wc.enchantedItemEffect
    end
    return nil
end

local function syncVanillaEffect(node)
    local effect = vanillaEffect()
    if not effect then
        return
    end
    local present = node:getEffect(ni.dynamicEffectType.textureEffect)
    local isVanilla = present ~= nil and present.name == VANILLA_EFFECT_NAME
    if cfg.suppressVanilla then
        if isVanilla then
            node:detachEffect(present)
            node:updateEffects()
        end
    elseif not present then
        node:attachEffect(effect)
        node:updateEffects()
    end
end

-- Animation drive -------------------------------------------------------------------------------

local function frequency()
    return (cfg.fps or BASE_FPS) / BASE_FPS
end

local function childrenOf(node)
    local list = {}
    for _, child in pairs(node.children) do
        if child then
            list[#list + 1] = child
        end
    end
    return list
end

-- Clones the template's animated node. Cloned BSAnimationNodes start in their "first time"
-- state, so the engine performs registration and phase setup on the next update.
local function cloneClock(template)
    local clock = template.clock:clone()
    if not cfg.desync then
        clock.flags = bit.bor(clock.flags, AVOBJECT_FLAG_NOT_RANDOM)   -- keep the authored phase (0)
    end
    return clock
end

-- Static layout: the clock becomes the parent of node's geometry (authored animated-NIF layout).
local function insertClock(node, template)
    local clock = cloneClock(template)
    for _, child in ipairs(childrenOf(node)) do
        node:detachChild(child)
        clock:attachChild(child, true)
    end
    node:attachChild(clock, true)
    return clock
end

-- Worn layout: the clock is a childless sibling of the geometry and only holds the controllers.
local function attachClock(node, template)
    local clock = cloneClock(template)
    node:attachChild(clock, true)
    return clock
end

-- Restores the original structure: geometry back under the node (static layout), clock detached.
local function removeClock(entry)
    local node, clock = entry.node, entry.clock
    if entry.mode == "static" then
        for _, child in ipairs(childrenOf(clock)) do
            clock:detachChild(child)
            node:attachChild(child, true)
        end
    else
        clock:removeAllControllers()
    end
    node:detachChild(clock)
    node:update()
end

-- Apply / strip ----------------------------------------------------------------------------------

local function applyToShape(shape, template, entry)
    local prop = shape.texturingProperty
    if not prop or (cfg.keepExistingGlow and prop.glowMap) or not uvAcceptable(shape) then
        return false
    end
    local clone = prop:clone()
    clone.glowMap = niTexturingPropertyMap.new({
        texture = template.texture,
        clampMode = CLAMP_WRAP_WRAP,
        filterMode = FILTER_TRILERP,
        textCoords = 0,
    })
    shape.texturingProperty = clone
    shape:updateProperties()
    -- setTarget also lists the controller on the property (the authored NIF placement), which is
    -- what the static layout wants. In the worn layout the property's owner is posed by the
    -- actor's animation pass, which would tick the controller with clip-local time; there the
    -- controller is moved to the clock node, which only the manager ticks.
    local controller = template.controller:clone()
    controller:setTarget(clone)
    if entry.mode == "worn" then
        clone:removeController(controller)
        entry.clock:prependController(controller)
    end
    controller.frequency = frequency()
    entry.controllers[#entry.controllers + 1] = controller
    entry.shapes[#entry.shapes + 1] = { shape = shape, original = prop }
    return true
end

local function decorateLeaves(node, template, entry)
    local children = node.children
    if not children then
        return (node.texturingProperty ~= nil and applyToShape(node, template, entry)) and 1 or 0
    end
    local n = 0
    for _, child in pairs(children) do
        if child then
            n = n + decorateLeaves(child, template, entry)
        end
    end
    return n
end

-- Decorates every leaf geometry under node and gives it a clock in the requested layout
-- ("static" or "worn"). The clock is left for the engine's next ordinary update, which registers
-- it with the cell's manager and marks it always-update (the node may not be in a cell yet when
-- the scene-node events fire). Returns the number of shapes decorated.
local function applyToNode(node, template, mode)
    if node:getObjectByName(CLOCK_NODE_NAME) then
        return 0
    end
    local entry = { node = node, mode = mode, controllers = {}, shapes = {} }
    if mode == "worn" then
        entry.clock = attachClock(node, template)   -- needed before the shapes are wired
    end
    local n = decorateLeaves(node, template, entry)
    if n == 0 then
        if entry.clock then
            node:detachChild(entry.clock)
        end
        return 0
    end
    if mode == "static" then
        entry.clock = insertClock(node, template)
    end
    live[#live + 1] = entry
    return n
end

-- Drops entries whose node the engine has detached (unequipped parts, sheathed weapons, unloaded
-- cells). The entry kept the node alive, so the check is safe; dropping it releases the subtree.
local function pruneDead()
    local kept = 0
    for i = 1, #live do
        local entry = live[i]
        live[i] = nil
        if entry.node.parent then
            kept = kept + 1
            live[kept] = entry
        end
    end
end

local function isPlayerReference(ref)
    return ref == tes3.player or ref == tes3.player1stPerson
end

-- Decorates node for item, or only handles the vanilla sheen when glyphs are off or filtered out.
local function handleNode(node, item, mode, allowed)
    syncVanillaEffect(node)
    if not cfg.enabled or not allowed then
        return 0, nil
    end
    local ench = enchantmentFor(item)
    if not ench then
        return 0, nil
    end
    local colour = colourForEnchantment(ench)
    local template = templateFor(colour)
    if not template then
        return 0, nil
    end
    return applyToNode(node, template, mode), colour
end

function glow.applyItemReference(ref)
    local node, item = ref.sceneNode, ref.object
    if not node or not item or not item.enchantment then
        return 0
    end
    pruneDead()
    local n, colour = handleNode(node, item, "static", not cfg.equippedOnly)
    if n > 0 then
        log:debug("%s: %d shape(s) -> %s", ref.id, n, colour)
    end
    return n
end

-- Item types that can carry an enchantment; used to sweep a cell without touching its other
-- references.
local ENCHANTABLE_TYPES = { tes3.objectType.weapon, tes3.objectType.armor, tes3.objectType.clothing }

-- Every enabled dropped or placed enchanted item in a cell.
function glow.applyCellItems(cell)
    local total = 0
    for ref in cell:iterateReferences(ENCHANTABLE_TYPES, false) do
        if ref.object.enchantment then
            total = total + glow.applyItemReference(ref)
        end
    end
    return total
end

function glow.applyBodyParts(ref)
    local bpm = ref.bodyPartManager
    if not bpm then
        return 0
    end
    pruneDead()
    local allowed = not cfg.playerOnly or isPlayerReference(ref)
    local total = 0
    for _, layer in pairs(tes3.activeBodyPartLayer) do
        for _, part in pairs(tes3.activeBodyPart) do
            local active = bpm:getActiveBodyPart(layer, part)
            local item = active and active.node and active.item
            if item and item.enchantment then
                total = total + handleNode(active.node, item, "worn", allowed)
            end
        end
    end
    if total > 0 then
        log:debug("%s: %d body-part shape(s)", ref.id, total)
    end
    return total
end

local function stripAll()
    for _, entry in ipairs(live) do
        if entry.node.parent then
            removeClock(entry)
            for _, s in ipairs(entry.shapes) do
                s.shape.texturingProperty = s.original   -- the clone, its glow map and controller go with it
                s.shape:updateProperties()
            end
        end
    end
    live = {}
end

-- Re-evaluate everything currently loaded against the current settings: strip all glyphs, then
-- visit every enchanted item in the loaded world (sheen setting applied, glyphs if enabled).
function glow.refresh()
    stripAll()
    uvStatsCache = {}
    if not tes3.player then
        return
    end
    local total = glow.applyBodyParts(tes3.player)
    if tes3.player1stPerson then
        total = total + glow.applyBodyParts(tes3.player1stPerson)
    end
    for _, cell in pairs(tes3.getActiveCells()) do
        total = total + glow.applyCellItems(cell)
        for ref in cell:iterateReferences(tes3.objectType.npc, false) do
            if not isPlayerReference(ref) then
                total = total + glow.applyBodyParts(ref)
            end
        end
    end
    log:debug("Refresh: %d shape(s) live", total)
end

-- Apply a changed animation rate to everything live without re-decorating.
function glow.applyRate()
    local f = frequency()
    for _, entry in ipairs(live) do
        for _, controller in ipairs(entry.controllers) do
            controller.frequency = f
        end
    end
end

return glow
