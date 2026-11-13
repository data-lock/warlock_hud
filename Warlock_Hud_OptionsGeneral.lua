-- General addon behavior settings page.
WarlockHudOptionsGeneral = {}

function WarlockHudOptionsGeneral.Build(context)
    local api, general = context.api, context.general
    local Text, Check = context.Text, context.Check
    local Profile, MarkChanged = context.Profile, context.MarkChanged

    Text(general, "Addon", 24, -55, "GameFontNormal")
    Check(general, 24, -82, "Enable Warlock HUD on this character",
        function() return api.IsAddonEnabled() end,
        function(value) api.SetAddonEnabled(value) end,
        "Settings remain available while the HUD is off. The visual rebuild waits until combat and aura protection allow it safely.")

    Text(general, "Display Behavior", 24, -145, "GameFontNormal")
    Text(general, "Hidden rows still appear during combat and Edit Mode.",
        24, -170, "GameFontHighlightSmall")
    for index, option in ipairs({
        { "main", "Target DoTs" }, { "utility", "Utility" },
        { "consumes", "Consumes" }, { "buffs", "Buffs" },
        { "procs", "Procs" }, { "shards", "Soul Shards" },
    }) do
        local key, label = option[1], option[2]
        local x = index % 2 == 1 and 24 or 325
        local row = math.floor((index - 1) / 2)
        Check(general, x, -198 - row * 38, label,
            function() return Profile().showOutOfCombat[key] ~= false end,
            function(value)
                if value then Profile().showOutOfCombat[key] = nil
                else Profile().showOutOfCombat[key] = false end
                if api.RefreshRowVisibility then api.RefreshRowVisibility() end
            end,
            "Show this HUD row outside combat. It remains visible in combat and Edit Mode.",
            false)
    end

    Text(general, "Spell Feedback", 24, -315, "GameFontNormal")
    Check(general, 24, -342, "Show channel tick markers on the castbar",
        function() return Profile().enabled.channelTicks ~= false end,
        function(value)
            if value then Profile().enabled.channelTicks = nil
            else Profile().enabled.channelTicks = false end
            MarkChanged(false)
        end,
        "Shows timing markers for supported channels, including Rain of Fire and Drain spells.",
        false)
    Check(general, 24, -372, "Warn about lower-rank spells",
        function() return Profile().enabled.downrankWarnings ~= false end,
        function(value)
            if value then Profile().enabled.downrankWarnings = nil
            else Profile().enabled.downrankWarnings = false end
            if WarlockHudRefreshDownrankWarnings then
                WarlockHudRefreshDownrankWarnings()
            end
            MarkChanged(false)
        end,
        "Warns when an action-bar spell is below your highest known rank and after casting a lower rank.",
        false)

    Text(general, "HUD Recovery", 24, -420, "GameFontNormal")
    Text(general,
        "If you reload during combat, protected HUD elements may appear after combat ends.",
        24, -446, "GameFontHighlightSmall")
end
