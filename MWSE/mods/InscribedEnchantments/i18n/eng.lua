return {
    -- Pages
    ["settings.label"] = "Settings",
    ["settings.description"] = "Enchanted items show faint Daedric glyphs that slowly come and go on their surface, "
        .. "in place of the vanilla reflective sheen.\n\n"
        .. "Hover over a setting for details. Changes apply immediately to everything that is loaded.",
    ["filters.label"] = "Filters",
    ["filters.description"] = "Choose which items receive glyphs: whose equipment, which item types, which "
        .. "kinds of enchantment, and which meshes to leave alone.\n\n"
        .. "Individual items and whole plugins can be excluded on the Blocked items page.",

    -- Categories
    ["category.general.label"] = "General",
    ["category.appearance.label"] = "Appearance",
    ["category.surfaces.label"] = "Surfaces",
    ["category.diagnostics.label"] = "Diagnostics",
    ["category.who.label"] = "Whose items",
    ["category.itemTypes.label"] = "Item types",
    ["category.castTypes.label"] = "Enchantment types",
    ["category.meshes.label"] = "Meshes",

    -- General
    ["enabled.label"] = "Show glyphs",
    ["enabled.description"] = "Draws the glyphs on enchanted items. Turning this off removes them from loaded items "
        .. "right away. Independent of the vanilla sheen setting below.",
    ["suppressVanilla.label"] = "Hide vanilla sheen",
    ["suppressVanilla.description"] = "Removes the game's own reflective enchantment effect (the sliding, "
        .. "view-dependent sheen) from every enchanted item. Independent of the glyphs: you can hide the sheen without showing glyphs, "
        .. "or show glyphs on top of the sheen. Makes a separate no-glow patch unnecessary.",
    ["suppressVanilla.alreadyPatched"] = "Note: another mod (such as Assetless No Glow) has already removed the vanilla "
        .. "sheen from this game, so this setting currently has no visible effect either way.",

    -- Appearance
    ["colourMode.label"] = "Colour",
    ["colourMode.option.school"] = "Enchantment colour",
    ["colourMode.option.fixed"] = "Fixed colour",
    ["colourMode.description"] = "Enchantment colour tints the glyphs with the game's own colour for the enchantment's "
        .. "first magic effect (fire damage red, restoration mint, conjuration pink, illusion blue, and so on). "
        .. "Fixed colour uses the colour chosen below for every item.",
    ["fixedColour.label"] = "Fixed colour",
    ["fixedColour.description"] = "Colour used for all glyphs when Colour is set to Fixed colour.",
    ["fixedColour.option.ember"] = "Ember (fire)",
    ["fixedColour.option.blood"] = "Blood (damage)",
    ["fixedColour.option.rose"] = "Rose (conjuration)",
    ["fixedColour.option.lilac"] = "Lilac (illusion)",
    ["fixedColour.option.azure"] = "Azure (invisibility)",
    ["fixedColour.option.violet"] = "Violet (corprus)",
    ["fixedColour.option.mint"] = "Mint (restoration)",
    ["fixedColour.option.moss"] = "Moss (resistance)",
    ["fixedColour.option.lime"] = "Lime (alteration)",
    ["fixedColour.option.ivory"] = "Ivory (mysticism)",
    ["fixedColour.option.white"] = "White",
    ["glyphSize.label"] = "Glyph set",
    ["glyphSize.option.normal"] = "Normal",
    ["glyphSize.option.small"] = "Small",
    ["glyphSize.option.sparse"] = "Sparse",
    ["glyphSize.option.sparseSmall"] = "Sparse, small",
    ["glyphSize.option.cracks"] = "Cracks",
    ["glyphSize.option.cracksHD"] = "Cracks, high resolution",
    ["glyphSize.description"] = "Normal draws 14 glyphs per texture tile at about 16-22 pixels; Small draws 20 at "
        .. "about 10-14 pixels. The Sparse sets keep those sizes but place fewer glyphs (8 and 10), keep them "
        .. "invisible when not lit, and light each one for a shorter moment, so only two or three show at a "
        .. "time. Cracks replaces the glyphs with a network of hairline cracks that light up from one end to "
        .. "the other, as if the enchantment were inside the metal; the glyph height limits below do not apply "
        .. "to it. The high resolution version draws the same style of cracks at twice the texture size, with "
        .. "smoother lines. How big any of this is on the item depends on each mesh's texture mapping.",

    ["fps.label"] = "Animation speed (frames per second)",
    ["fps.description"] = "Speed of the 192-frame glyph loop. 12 means one loop every 16 seconds; lower is slower "
        .. "and calmer, higher makes glyphs come and go faster.",
    ["desync.label"] = "Desynchronise items",
    ["desync.description"] = "Gives every item its own point in the loop so several enchanted items in view do not "
        .. "light up in unison.",

    -- Surfaces
    ["keepExistingGlow.label"] = "Respect existing glow maps",
    ["keepExistingGlow.description"] = "Leave meshes that already carry their own glow map (for example Daedric or "
        .. "glass gear with _g textures) untouched instead of replacing that glow with glyphs.",
    ["skipDistorted.label"] = "Skip distorted surfaces",
    ["skipDistorted.description"] = "Measures each surface's UV layout and leaves out surfaces where the glyphs would "
        .. "come out stretched, tiny or huge. Fewer surfaces glow, but none look smeared.",
    ["maxStretch.label"] = "Maximum stretch",
    ["maxStretch.description"] = "How unevenly a surface's texture mapping may be scaled before it counts as "
        .. "distorted (1.0 = perfectly even). A surface is skipped when more than half of its area exceeds this.",
    ["minGlyphSize.label"] = "Minimum glyph height (units)",
    ["minGlyphSize.description"] = "How tall a glyph would be on the item, in game units (a character is 128 units "
        .. "tall; 1 unit is about 1.4 cm). The glyph textures repeat with the item's own texture, so a surface whose "
        .. "texture covers a large area gets large glyphs. Surfaces below this height are skipped; 0 never skips on size.",
    ["maxGlyphSize.label"] = "Maximum glyph height (units)",
    ["maxGlyphSize.description"] = "Surfaces whose glyphs would come out taller than this are skipped. Trousers and "
        .. "gauntlets typically land at 2-5 units, cuirasses at 4-10, so 6.5 keeps the finer inscriptions and "
        .. "drops the billboard-sized ones.",

    -- Filters
    ["playerOnly.label"] = "Player's equipment only",
    ["playerOnly.description"] = "Only the player's worn and wielded items glow (including the first-person view). "
        .. "NPC equipment is left alone.",
    ["equippedOnly.label"] = "Equipped items only",
    ["equippedOnly.description"] = "Skip enchanted items lying in the world (dropped or placed). Only worn and "
        .. "wielded items glow.",
    ["weapons.label"] = "Weapons",
    ["weapons.description"] = "Enchanted weapons glow.",
    ["armor.label"] = "Armor",
    ["armor.description"] = "Enchanted armor glows.",
    ["clothing.label"] = "Clothing",
    ["clothing.description"] = "Enchanted clothing (rings, amulets, robes, and so on) glows.",
    ["castConstant.label"] = "Constant effect",
    ["castConstant.description"] = "Items with a constant effect enchantment glow.",
    ["castOnStrike.label"] = "Cast on strike",
    ["castOnStrike.description"] = "Weapons that cast their enchantment when they hit glow.",
    ["castOnUse.label"] = "Cast on use",
    ["castOnUse.description"] = "Items whose enchantment is cast from the magic menu glow.",
    ["castOnce.label"] = "Cast once",
    ["castOnce.description"] = "Single-use enchanted items (scroll-like items) glow.",
    ["meshBlacklist.label"] = "Skip meshes containing",
    ["meshBlacklist.description"] = "Comma-separated text. Any item whose model path contains one of these "
        .. "fragments never glows, for example: w_art_, a_daedric_. Case does not matter.",

    -- Blocked items
    ["blocked.label"] = "Blocked items",
    ["blocked.description"] = "Items in the left list never glow. Blocking a plugin blocks every enchanted item it "
        .. "adds. Changes apply when the menu closes.",
    ["blocked.leftList"] = "Blocked",
    ["blocked.rightList"] = "Glowing",
    ["blocked.filter.plugins"] = "Plugins",
    ["blocked.filter.weapons"] = "Enchanted weapons",
    ["blocked.filter.armor"] = "Enchanted armor",
    ["blocked.filter.clothing"] = "Enchanted clothing",
}
