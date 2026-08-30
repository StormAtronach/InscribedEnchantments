-- Persisted settings for Inscribed Enchantments. Loaded from Data Files\MWSE\config\InscribedEnchantments.json,
-- missing keys are filled from the defaults below.

local defaults = {
    enabled = true,
    suppressVanilla = true,     -- switch off the engine's reflective "Enchanted Item Effect" sheen
    fps = 12,                   -- frames per second of the 192-frame loop (12 = 16 s per loop)
    keepExistingGlow = true,    -- leave shapes that already carry their own glow map alone
    skipDistorted = true,       -- skip shapes whose UV layout would stretch or mis-size the glyphs
    maxStretch = 3.5,           -- UV stretch ratio above which a surface counts as distorted
    minGlyphSize = 0,           -- glyph height on the surface, in game units (1 unit ~ 1.4 cm); smaller is skipped (0 = never)
    maxGlyphSize = 6.5,         -- glyph height on the surface, in game units; larger is skipped
    desync = true,              -- give every item its own loop offset so items don't flash together
    glyphSize = "small",        -- "normal" or "small" glyph set (separate baked textures)
    colourMode = "school",      -- "school" = enchantment's first effect colour, "fixed" = fixedColour
    fixedColour = "white",
    playerOnly = false,         -- only the player's equipment (and first-person view)
    equippedOnly = false,       -- skip dropped / placed items
    castOnce = true,            -- enchantment cast types that glow
    castOnStrike = true,
    castOnUse = true,
    castConstant = true,
    weapons = true,             -- item types that glow
    armor = true,
    clothing = true,
    meshBlacklist = "",         -- comma-separated substrings of mesh paths to skip
    blocked = {},               -- item ids / plugin names blocked via the exclusions page
    logLevel = mwse.logLevel.info,
}

local fileName = "InscribedEnchantments"

return {
    config = mwse.loadConfig(fileName, defaults),
    defaults = defaults,
    fileName = fileName,
}
