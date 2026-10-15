-- Row settings pages. Each page is built by Warlock_Hud_Options.lua after shared controls exist.
WarlockHudOptionsRows = {}

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
