-- Row settings pages. Each page is built by Warlock_Hud_Options.lua after shared controls exist.
WarlockHudOptionsRows = {}

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
