-- Row settings pages. Each page is built by Warlock_Hud_Options.lua after shared controls exist.
WarlockHudOptionsRows = {}

function WarlockHudOptionsRows.BuildConsumes(context)
    local api = context.api
    local Panel, Text, Check = context.Panel, context.Text, context.Check
    local SizeSlider, OrderSection = context.SizeSlider, context.OrderSection
    local ResetRowValues, ResetPageButton = context.ResetRowValues, context.ResetPageButton
    local DefaultProfile, Profile, MarkChanged = context.DefaultProfile, context.Profile, context.MarkChanged

    local consumeLayout = Panel("Warlock HUD - Consumes")
    Text(consumeLayout, "Move this row in Edit Mode. Drag icons to reorder them; use the checks to show or hide them.",
        20, -50, "GameFontHighlightSmall")
    Check(consumeLayout, 20, -80, "Enable Consumes row",
        function() return Profile().consumesEnabled ~= false end,
        function(value)
            Profile().consumesEnabled = value
            if api.RefreshRowVisibility then api.RefreshRowVisibility() end
        end, "The row stays movable in Edit Mode when disabled.", false)
    Text(consumeLayout, "Icon size", 20, -125, "GameFontNormal")
    SizeSlider(consumeLayout, "Consume icon size", "consumeSize", 16, 64, 20, -150)
    OrderSection(consumeLayout, "Tracked consumables", "consumeOrder", api.ConsumeKeys,
        -205, nil, function()
            local defaults = DefaultProfile()
            ResetRowValues("consumeSize", "consumeOrder", api.ConsumeKeys, defaults)
            for _, key in ipairs(api.ConsumeKeys) do
                Profile().enabled[key] = defaults.enabled[key]
            end
            Profile().consumeReminders = defaults.consumeReminders
            Profile().colorActiveConsumes = nil
            MarkChanged()
        end)
    Text(consumeLayout, "Checked icons are tracked. Only checked reminders flash when confirmed missing.",
        20, -325, "GameFontHighlightSmall")
    Check(consumeLayout, 20, -345, "Color when active; grey when missing",
        function() return Profile().colorActiveConsumes ~= false end,
        function(value)
            if value then Profile().colorActiveConsumes = nil
            else Profile().colorActiveConsumes = false end
        end, "On (default): color when active, grey when missing. Off reverses the colors.")
    Text(consumeLayout, "Remind when missing", 20, -380, "GameFontNormal")
    for index, option in ipairs({
        { "wellfed", "Well Fed" }, { "flask", "Flask" },
        { "spelldamage", "Spell Damage" }, { "shadow", "Shadow Damage" },
        { "fire", "Fire Damage" }, { "wizardoil", "Wizard Oil" },
        { "manaregen", "Mana Regeneration" },
    }) do
        local key, label = option[1], option[2]
        Check(consumeLayout, 20 + ((index - 1) % 2) * 340,
            -399 - math.floor((index - 1) / 2) * 27, label,
            function() return Profile().consumeReminders[key] == true end,
            function(value)
                Profile().consumeReminders[key] = value
                if api.RefreshConsumableGlows then api.RefreshConsumableGlows() end
            end, "Only flashes when this tracker is enabled and the effect is confirmed missing.",
            false)
    end
    ResetPageButton(consumeLayout, "Consumes", function()
        local defaults = DefaultProfile()
        ResetRowValues("consumeSize", "consumeOrder", api.ConsumeKeys, defaults)
        for _, key in ipairs(api.ConsumeKeys) do
            Profile().enabled[key] = defaults.enabled[key]
        end
        Profile().consumeReminders = defaults.consumeReminders
        Profile().consumesEnabled = nil
        Profile().showOutOfCombat.consumes = nil
        Profile().colorActiveConsumes = nil
        MarkChanged()
    end)
    return consumeLayout
end

function WarlockHudOptionsRows.BuildBuffs(context)
    local api = context.api
    local Panel, Text, Check = context.Panel, context.Text, context.Check
    local SizeSlider, OrderSection = context.SizeSlider, context.OrderSection
    local ResetRowValues, DefaultProfile = context.ResetRowValues, context.DefaultProfile
    local Profile, MarkChanged = context.Profile, context.MarkChanged

    local buffLayout = Panel("Warlock HUD - Buffs")
    Text(buffLayout, "Move this row in Edit Mode. Drag icons to reorder them; use the checks to show or hide them.",
        20, -50, "GameFontHighlightSmall")
    Text(buffLayout, "Icon size", 20, -85, "GameFontNormal")
    SizeSlider(buffLayout, "Buff icon size", "buffSize", 16, 64, 20, -110)
    OrderSection(buffLayout, "Player buffs", "buffOrder", api.BuffKeys, -165, 7, function()
        ResetRowValues("buffSize", "buffOrder", api.BuffKeys, DefaultProfile())
        Profile().colorActiveBuffs = nil
        MarkChanged()
    end)
    Text(buffLayout, "Buff reminders", 20, -400, "GameFontNormal")
    Text(buffLayout, "Fortitude, Wild, Intellect, Spirit, Kings, and Salvation include group versions.",
        20, -427, "GameFontHighlightSmall")
    Text(buffLayout, "Demon Armor / Skin glows when missing.",
        20, -449, "GameFontHighlightSmall")
    Text(buffLayout, "Missing group buffs pulse red when your group has the matching class.",
        20, -471, "GameFontHighlightSmall")
    Check(buffLayout, 20, -490, "Color when active; grey when missing",
        function() return Profile().colorActiveBuffs ~= false end,
        function(value)
            if value then Profile().colorActiveBuffs = nil
            else Profile().colorActiveBuffs = false end
        end,
        "On (default): color when active, grey when missing. Off reverses the colors. Missing-buff pulses stay red.")
    return buffLayout
end

function WarlockHudOptionsRows.BuildProcs(context)
    local api = context.api
    local Panel, Text = context.Panel, context.Text
    local SizeSlider, OrderSection = context.SizeSlider, context.OrderSection
    local ResetRowValues, DefaultProfile = context.ResetRowValues, context.DefaultProfile
    local MarkChanged = context.MarkChanged

    local procLayout = Panel("Warlock HUD - Procs")
    Text(procLayout, "Move this row in Edit Mode. Its icons appear only while a proc is active.",
        20, -50, "GameFontHighlightSmall")
    Text(procLayout, "Icon size", 20, -85, "GameFontNormal")
    SizeSlider(procLayout, "Proc icon size", "procSize", 20, 64, 20, -110)
    OrderSection(procLayout, "Active procs", "procOrder", api.ProcKeys, -165, nil, function()
        ResetRowValues("procSize", "procOrder", api.ProcKeys, DefaultProfile())
        MarkChanged()
    end)
    Text(procLayout, "Power Infusion and Nightfall (Shadow Trance) pulse with a countdown.",
        20, -310, "GameFontHighlightSmall")
    return procLayout
end
