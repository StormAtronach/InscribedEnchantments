local i18n = mwse.loadTranslations("InscribedEnchantments")
local configModule = require("InscribedEnchantments.config")
local glow = require("InscribedEnchantments.glow")

local config = configModule.config
local defaults = configModule.defaults

local function refresh()
    glow.refresh()
end

local function enchantedIds(objectType)
    return function()
        local ids = {}
        for obj in tes3.iterateObjects(objectType) do
            ---@cast obj tes3weapon|tes3armor|tes3clothing
            if obj.enchantment then
                ids[#ids + 1] = obj.id:lower()
            end
        end
        table.sort(ids)
        return ids
    end
end

local function colourOptions()
    local options = {}
    for _, name in ipairs(table.keys(glow.PALETTE, true)) do
        options[#options + 1] = { label = i18n("fixedColour.option." .. name), value = name }
    end
    return options
end

-- Yes/no button bound to a config key; refreshes live items unless `live` is false.
local function toggle(parent, key, live)
    parent:createYesNoButton({
        label = i18n(key .. ".label"),
        description = i18n(key .. ".description"),
        configKey = key,
        callback = live ~= false and refresh or nil,
    })
end

local function registerModConfig()
    local template = mwse.mcm.createTemplate({
        name = "Inscribed Enchantments",
        config = config,
        defaultConfig = defaults,
        showDefaultSetting = true,
    })
    template.onClose = function()
        mwse.saveConfig(configModule.fileName, config)
        refresh()
    end
    template:register()

    -- Settings ---------------------------------------------------------------------------------
    do
        local page = template:createSideBarPage({
            label = i18n("settings.label"),
            description = i18n("settings.description"),
        })

        local general = page:createCategory({ label = i18n("category.general.label") })
        toggle(general, "enabled")
        local suppressDescription = i18n("suppressVanilla.description")
        if glow.vanillaPatchedByOtherMod() then
            suppressDescription = suppressDescription .. "\n\n" .. i18n("suppressVanilla.alreadyPatched")
        end
        general:createYesNoButton({
            label = i18n("suppressVanilla.label"),
            description = suppressDescription,
            configKey = "suppressVanilla",
            callback = refresh,
        })

        local appearance = page:createCategory({ label = i18n("category.appearance.label") })
        appearance:createDropdown({
            label = i18n("colourMode.label"),
            description = i18n("colourMode.description"),
            configKey = "colourMode",
            options = {
                { label = i18n("colourMode.option.school"), value = "school" },
                { label = i18n("colourMode.option.fixed"), value = "fixed" },
            },
            callback = refresh,
        })
        appearance:createDropdown({
            label = i18n("fixedColour.label"),
            description = i18n("fixedColour.description"),
            configKey = "fixedColour",
            options = colourOptions(),
            callback = refresh,
        })
        appearance:createDropdown({
            label = i18n("glyphSize.label"),
            description = i18n("glyphSize.description"),
            configKey = "glyphSize",
            options = {
                { label = i18n("glyphSize.option.normal"), value = "normal" },
                { label = i18n("glyphSize.option.small"), value = "small" },
                { label = i18n("glyphSize.option.sparse"), value = "sparse" },
                { label = i18n("glyphSize.option.sparseSmall"), value = "sparseSmall" },
                { label = i18n("glyphSize.option.cracks"), value = "cracks" },
                { label = i18n("glyphSize.option.cracksHD"), value = "cracksHD" },
            },
            callback = refresh,
        })
        appearance:createSlider({
            label = i18n("fps.label"),
            description = i18n("fps.description"),
            configKey = "fps",
            min = 2,
            max = 20,
            step = 1,
            jump = 2,
            callback = function()
                glow.applyRate()
            end,
        })
        toggle(appearance, "desync")

        local surfaces = page:createCategory({ label = i18n("category.surfaces.label") })
        toggle(surfaces, "keepExistingGlow")
        toggle(surfaces, "skipDistorted")
        surfaces:createSlider({
            label = i18n("maxStretch.label"),
            description = i18n("maxStretch.description"),
            configKey = "maxStretch",
            min = 1.2,
            max = 4.0,
            step = 0.1,
            jump = 0.5,
            decimalPlaces = 1,
            callback = refresh,
        })
        surfaces:createSlider({
            label = i18n("minGlyphSize.label"),
            description = i18n("minGlyphSize.description"),
            configKey = "minGlyphSize",
            min = 0,
            max = 8,
            step = 0.5,
            jump = 1,
            decimalPlaces = 1,
            callback = refresh,
        })
        surfaces:createSlider({
            label = i18n("maxGlyphSize.label"),
            description = i18n("maxGlyphSize.description"),
            configKey = "maxGlyphSize",
            min = 1,
            max = 20,
            step = 0.5,
            jump = 1,
            decimalPlaces = 1,
            callback = refresh,
        })

        local diagnostics = page:createCategory({ label = i18n("category.diagnostics.label") })
        diagnostics:createLogLevelOptions({ configKey = "logLevel" })
    end

    -- Filters ----------------------------------------------------------------------------------
    do
        local page = template:createSideBarPage({
            label = i18n("filters.label"),
            description = i18n("filters.description"),
        })

        local who = page:createCategory({ label = i18n("category.who.label") })
        toggle(who, "playerOnly")
        toggle(who, "equippedOnly")

        local itemTypes = page:createCategory({ label = i18n("category.itemTypes.label") })
        for _, key in ipairs({ "weapons", "armor", "clothing" }) do
            toggle(itemTypes, key)
        end

        local castTypes = page:createCategory({ label = i18n("category.castTypes.label") })
        for _, key in ipairs({ "castConstant", "castOnStrike", "castOnUse", "castOnce" }) do
            toggle(castTypes, key)
        end

        local meshes = page:createCategory({ label = i18n("category.meshes.label") })
        meshes:createTextField({
            label = i18n("meshBlacklist.label"),
            description = i18n("meshBlacklist.description"),
            configKey = "meshBlacklist",
            callback = refresh,
        })
    end

    -- Blocked items ----------------------------------------------------------------------------
    template:createExclusionsPage({
        label = i18n("blocked.label"),
        description = i18n("blocked.description"),
        leftListLabel = i18n("blocked.leftList"),
        rightListLabel = i18n("blocked.rightList"),
        variable = mwse.mcm.createTableVariable({ id = "blocked", table = config }),
        filters = {
            { label = i18n("blocked.filter.plugins"), type = "Plugin" },
            { label = i18n("blocked.filter.weapons"), callback = enchantedIds(tes3.objectType.weapon) },
            { label = i18n("blocked.filter.armor"), callback = enchantedIds(tes3.objectType.armor) },
            { label = i18n("blocked.filter.clothing"), callback = enchantedIds(tes3.objectType.clothing) },
        },
    })
end

return registerModConfig
