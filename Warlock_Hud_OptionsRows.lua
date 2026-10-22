-- Row settings pages. Each page is built by Warlock_Hud_Options.lua after shared controls exist.
WarlockHudOptionsRows = {}

function WarlockHudOptionsRows.BuildLayout(context)
    local api, layout = context.api, context.layout
    local Text, Check = context.Text, context.Check
    local SizeSlider, LinkedTargetUtilityRows = context.SizeSlider, context.LinkedTargetUtilityRows
    local ResetRowValues, ResetPageButton = context.ResetRowValues, context.ResetPageButton
    local DefaultProfile, Profile, MarkChanged = context.DefaultProfile, context.Profile, context.MarkChanged

    Text(layout, "Drag gold grips to reorder or move icons. Use checks to show or hide them; move rows in Edit Mode.",
        20, -50, "GameFontHighlightSmall")
    Text(layout, "Icon sizes", 20, -72, "GameFontNormal")
    SizeSlider(layout, "Target DoT icon size", "mainSize", 16, 96, 20, -95)
    SizeSlider(layout, "Utility icon size", "cooldownSize", 16, 64, 20, -125)
    local nameplatesY = LinkedTargetUtilityRows(layout)
    Text(layout, "Nameplates", 20, nameplatesY, "GameFontNormal")
    Check(layout, 20, nameplatesY - 20, "20% marker on attackable nameplates",
        function() return Profile().enabled.executeMarker ~= false end,
        function(value)
            if value then
                Profile().enabled.executeMarker = nil
            else
                Profile().enabled.executeMarker = false
            end
        end)
    ResetPageButton(layout, "Rows & Layout", function()
        local defaults = DefaultProfile()
        ResetRowValues("mainSize", "mainOrder", api.MainKeys, defaults)
        ResetRowValues("cooldownSize", "cooldownOrder", api.CooldownKeys, defaults)
        Profile().enabled.executeMarker = nil
        MarkChanged()
    end, 470, nameplatesY - 48)
end

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
    local trackedFrame = CreateFrame("Frame", nil, consumeLayout)
    trackedFrame:SetSize(504, 68)
    trackedFrame:SetPoint("TOPLEFT", consumeLayout, "TOPLEFT", 50, -221)
    local trackedBackground = trackedFrame:CreateTexture(nil, "BACKGROUND")
    trackedBackground:SetAllPoints(trackedFrame)
    trackedBackground:SetColorTexture(0.025, 0.035, 0.05, 0.55)
    for _, edgeInfo in ipairs({
        { "TOP", trackedFrame:GetWidth(), 1 },
        { "BOTTOM", trackedFrame:GetWidth(), 1 },
        { "LEFT", 1, trackedFrame:GetHeight() },
        { "RIGHT", 1, trackedFrame:GetHeight() },
    }) do
        local edge = trackedFrame:CreateTexture(nil, "BORDER")
        edge:SetSize(edgeInfo[2], edgeInfo[3])
        edge:SetPoint(edgeInfo[1], trackedFrame, edgeInfo[1])
        edge:SetColorTexture(0.7, 0.54, 0.2, 0.75)
    end
    OrderSection(consumeLayout, "Tracked consumables", "consumeOrder", api.ConsumeKeys,
        -185, 7, function()
            local defaults = DefaultProfile()
            ResetRowValues("consumeSize", "consumeOrder", api.ConsumeKeys, defaults)
            for _, key in ipairs(api.ConsumeKeys) do
                Profile().enabled[key] = defaults.enabled[key]
            end
            Profile().consumeReminders = defaults.consumeReminders
            Profile().colorActiveConsumes = nil
            MarkChanged()
        end, 127, 68, true, true, 50, 50)
    Text(consumeLayout, "Reminder settings", 20, -300, "GameFontNormal")
    Text(consumeLayout, "Only enabled trackers can show a missing reminder.",
        20, -320, "GameFontHighlightSmall")
    for index, option in ipairs({
        { "wellfed", "Well Fed" }, { "flask", "Flask" },
        { "spelldamage", "Spell Damage" }, { "shadow", "Shadow Damage" },
        { "fire", "Fire Damage" }, { "wizardoil", "Weapon Buff" },
        { "manaregen", "Mana Regeneration" },
    }) do
        local key, label = option[1], option[2]
        Check(consumeLayout, 20 + ((index - 1) % 3) * 225,
            -343 - math.floor((index - 1) / 3) * 26, "Remind: " .. label,
            function() return Profile().consumeReminders[key] == true end,
            function(value)
                Profile().consumeReminders[key] = value
                if api.RefreshConsumableGlows then api.RefreshConsumableGlows() end
            end, "Only flashes when this tracker is enabled and the effect is confirmed missing.",
            false)
    end
    Text(consumeLayout, "Appearance", 20, -431, "GameFontNormal")
    Check(consumeLayout, 125, -427, "Color when active; grey when missing",
        function() return Profile().colorActiveConsumes ~= false end,
        function(value)
            if value then Profile().colorActiveConsumes = nil
            else Profile().colorActiveConsumes = false end
        end, "On (default): color when active, grey when missing. Off reverses the colors.")
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
    end, 450, -425)
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
    local trackedFrame = CreateFrame("Frame", nil, buffLayout)
    trackedFrame:SetSize(504, 136)
    trackedFrame:SetPoint("TOPLEFT", buffLayout, "TOPLEFT", 50, -201)
    local trackedBackground = trackedFrame:CreateTexture(nil, "BACKGROUND")
    trackedBackground:SetAllPoints(trackedFrame)
    trackedBackground:SetColorTexture(0.025, 0.035, 0.05, 0.55)
    for _, edgeInfo in ipairs({
        { "TOP", trackedFrame:GetWidth(), 1 },
        { "BOTTOM", trackedFrame:GetWidth(), 1 },
        { "LEFT", 1, trackedFrame:GetHeight() },
        { "RIGHT", 1, trackedFrame:GetHeight() },
    }) do
        local edge = trackedFrame:CreateTexture(nil, "BORDER")
        edge:SetSize(edgeInfo[2], edgeInfo[3])
        edge:SetPoint(edgeInfo[1], trackedFrame, edgeInfo[1])
        edge:SetColorTexture(0.7, 0.54, 0.2, 0.75)
    end
    OrderSection(buffLayout, "Player buffs", "buffOrder", api.BuffKeys, -165, 8, function()
        ResetRowValues("buffSize", "buffOrder", api.BuffKeys, DefaultProfile())
        Profile().colorActiveBuffs = nil
        MarkChanged()
    end, 102, 68, true, true, 50, 50)
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
    local trackedFrame = CreateFrame("Frame", nil, procLayout)
    trackedFrame:SetSize(504, 68)
    trackedFrame:SetPoint("TOPLEFT", procLayout, "TOPLEFT", 50, -201)
    local trackedBackground = trackedFrame:CreateTexture(nil, "BACKGROUND")
    trackedBackground:SetAllPoints(trackedFrame)
    trackedBackground:SetColorTexture(0.025, 0.035, 0.05, 0.55)
    for _, edgeInfo in ipairs({
        { "TOP", trackedFrame:GetWidth(), 1 },
        { "BOTTOM", trackedFrame:GetWidth(), 1 },
        { "LEFT", 1, trackedFrame:GetHeight() },
        { "RIGHT", 1, trackedFrame:GetHeight() },
    }) do
        local edge = trackedFrame:CreateTexture(nil, "BORDER")
        edge:SetSize(edgeInfo[2], edgeInfo[3])
        edge:SetPoint(edgeInfo[1], trackedFrame, edgeInfo[1])
        edge:SetColorTexture(0.7, 0.54, 0.2, 0.75)
    end
    OrderSection(procLayout, "Active procs", "procOrder", api.ProcKeys, -165, 7, function()
        ResetRowValues("procSize", "procOrder", api.ProcKeys, DefaultProfile())
        MarkChanged()
    end, 127, 68, true, true, 50, 50)
    Text(procLayout, "Power Infusion and Nightfall (Shadow Trance) pulse with a countdown.",
        20, -310, "GameFontHighlightSmall")
    return procLayout
end
