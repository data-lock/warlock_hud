-- General settings page. The panel is created by Warlock_Hud_Options.lua.
WarlockHudOptionsGeneral = {}

function WarlockHudOptionsGeneral.Build(context)
    local api, general = context.api, context.general
    local Text, Check, Button = context.Text, context.Check, context.Button
    local Profile, ShowIconDemo = context.Profile, context.ShowIconDemo
    local IsDemoShown, refreshers = context.IsDemoShown, context.refreshers

    Text(general, "Enabled by default for Warlocks. Other classes can turn it on here.",
        20, -50, "GameFontHighlightSmall")
    Check(general, 20, -85, "Enable Warlock HUD on this character",
        function() return api.IsAddonEnabled() end,
        function(value) api.SetAddonEnabled(value) end,
        "Saves immediately. The HUD appears or disappears when a safe visual update is possible.")
    Text(general, "Settings remain available while the HUD is off.",
        48, -125, "GameFontHighlightSmall")
    local demoButton = Button(general, "Demo all HUD bars", 20, -175, 190, ShowIconDemo)
    refreshers[#refreshers + 1] = function()
        demoButton:SetText(IsDemoShown()
            and "End HUD demo" or "Demo all HUD bars")
    end
    Text(general, "Shows every icon slot on screen, including inactive buffs and procs.",
        20, -210, "GameFontHighlightSmall")
    Text(general, "Show out of combat", 20, -250, "GameFontNormal")
    Text(general, "Hidden rows appear in combat and Edit Mode.",
        20, -274, "GameFontHighlightSmall")
    for index, option in ipairs({
        { "main", "Target DoTs" }, { "utility", "Utility" },
        { "consumes", "Consumes" }, { "buffs", "Buffs" }, { "procs", "Procs" },
        { "shards", "Soul Shards" },
    }) do
        local key, label = option[1], option[2]
        Check(general, 20, -290 - (index - 1) * 36, label,
            function() return Profile().showOutOfCombat[key] ~= false end,
            function(value)
                if value then Profile().showOutOfCombat[key] = nil
                else Profile().showOutOfCombat[key] = false end
                if api.RefreshRowVisibility then api.RefreshRowVisibility() end
            end,
            "Show this HUD row outside combat. The row is always visible in combat and Edit Mode.",
            false)
    end
    Text(general, "If you /reload during combat, the HUD loads after combat ends.",
        20, -520, "GameFontHighlightSmall")
end
