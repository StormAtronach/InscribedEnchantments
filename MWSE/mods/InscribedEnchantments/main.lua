-- Inscribed Enchantments: entry point. Wires the effect module to game events and registers the MCM.

local log = mwse.Logger.new()
local configModule = require("InscribedEnchantments.config")
local cfg = configModule.config
log:setLevel(cfg.logLevel)

local glow = require("InscribedEnchantments.glow")
local registerModConfig = require("InscribedEnchantments.mcm")

-- Placed items: one sweep of the weapon / armor / clothing references when a cell becomes
-- active. Listening to referenceSceneNodeCreated instead would make MWSE build and dispatch an
-- event for every one of the thousands of references a cell change creates.
--- @param e cellActivatedEventData
local function onCellActivated(e)
    if e.cell then
        glow.applyCellItems(e.cell)
    end
end

-- Items the player drops after the cell is already active.
--- @param e itemDroppedEventData
local function onItemDropped(e)
    if e.reference then
        glow.applyItemReference(e.reference)
    end
end

-- An NPC entered the simulation: its body was built with its scene node, but bodyPartsUpdated
-- is not delivered for an actor that has no mobile yet, so this is the first usable notice.
--- @param e mobileActivatedEventData
local function onMobileActivated(e)
    if e.mobile and e.mobile.objectType == tes3.objectType.mobileNPC and e.reference then
        glow.applyBodyParts(e.reference)
    end
end

-- Equipment changes on a live actor: worn armor, clothing, shields, and a weapon that was
-- already drawn when the body was rebuilt.
--- @param e bodyPartsUpdatedEventData
local function onBodyPartsUpdated(e)
    if e.reference then
        glow.applyBodyParts(e.reference)
    end
end

-- Drawing a weapon attaches its model outside the body-part rebuild; the event fires after the
-- attach, for the third-person body and (for the player) the first-person one too.
--- @param e weaponReadiedEventData
local function onWeaponReadied(e)
    if e.reference then
        glow.applyBodyParts(e.reference)
        if e.reference == tes3.player and tes3.player1stPerson then
            glow.applyBodyParts(tes3.player1stPerson)
        end
    end
end

-- After a load the previous scene graph is gone; re-evaluate whatever the load created.
local function onLoaded()
    glow.refresh()
end

local function initialized()
    event.register(tes3.event.cellActivated, onCellActivated)
    event.register(tes3.event.itemDropped, onItemDropped)
    event.register(tes3.event.mobileActivated, onMobileActivated)
    event.register(tes3.event.bodyPartsUpdated, onBodyPartsUpdated)
    event.register(tes3.event.weaponReadied, onWeaponReadied)
    event.register(tes3.event.loaded, onLoaded)
    if glow.vanillaPatchedByOtherMod() then
        log:info("Vanilla enchantment sheen is already removed by another mod (e.g. Assetless No Glow); compatible.")
    end
    log:info("Initialized (fps=%d, colourMode=%s, suppressVanilla=%s).", cfg.fps, cfg.colourMode, cfg.suppressVanilla)
end

event.register(tes3.event.initialized, initialized)
event.register(tes3.event.modConfigReady, registerModConfig)
