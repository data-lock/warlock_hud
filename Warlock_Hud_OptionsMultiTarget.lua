-- Multi-Target DoTs settings page. The panel is created by Warlock_Hud_Options.lua.
WarlockHudOptionsMultiTarget = {}

function WarlockHudOptionsMultiTarget.Build(context)
    local multiDotPanel = context.multiDotPanel
    local Text, Check, Button = context.Text, context.Check, context.Button
    local Profile, refreshers = context.Profile, context.refreshers

    Text(multiDotPanel, "Up to 16 mobs from nameplates and group targets. Target through world nameplates or Tab.",
        20, -54, "GameFontHighlight")
    Text(multiDotPanel, "Off by default. Use /whud mtd to open or close it outside combat.",
        20, -81, "GameFontHighlightSmall")
    Text(multiDotPanel, "This view is read-only; target enemies through world nameplates or Tab.",
        20, -106, "GameFontHighlightSmall")
    Check(multiDotPanel, 20, -145, "Enable multi-target DoT window",
        function() return Profile().multiDotEnabled == true end,
        function(value)
            if InCombatLockdown() then return end
            Profile().multiDotEnabled = value
        end,
        "Enable or disable the window outside combat. Saved immediately.", false)
    Check(multiDotPanel, 20, -181, "Hide outside combat",
        function() return Profile().multiDotHideOutOfCombat == true end,
        function(value)
            if InCombatLockdown() then return end
            Profile().multiDotHideOutOfCombat = value
            if WarlockHudMultiTarget then WarlockHudMultiTarget.UpdateAppearance() end
        end,
        "Show the window only during combat while it is enabled. Saved immediately.", false)
    Button(multiDotPanel, "Reset position", 20, -229, 130, function()
        if InCombatLockdown() then return end
        Profile().multiDotX, Profile().multiDotY = nil, nil
        if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
    end)
    Button(multiDotPanel, "Reset size", 163, -229, 110, function()
        if InCombatLockdown() then return end
        Profile().multiDotScale = 1
        Profile().multiDotWidth, Profile().multiDotHeight = 430, 548
        if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
    end)
    Text(multiDotPanel, "Transparency", 20, -275, "GameFontHighlight")
    local alphaValue = Text(multiDotPanel, "100%", 400, -275, "GameFontHighlight")
    local alphaSlider = CreateFrame("Slider", nil, multiDotPanel, "OptionsSliderTemplate")
    alphaSlider:SetSize(165, 17)
    alphaSlider:SetPoint("TOPLEFT", multiDotPanel, "TOPLEFT", 203, -272)
    alphaSlider:SetMinMaxValues(30, 100)
    alphaSlider:SetValueStep(5)
    alphaSlider:SetScript("OnValueChanged", function(_, value)
        if InCombatLockdown() then
            local current = math.floor(((Profile().multiDotAlpha or 1) * 100) / 5 + 0.5) * 5
            if value ~= current then alphaSlider:SetValue(current) end
            return
        end
        local percent = math.max(30, math.min(100, math.floor(value / 5 + 0.5) * 5))
        alphaValue:SetText(percent .. "%")
        local p = Profile()
        if p and p.multiDotAlpha ~= percent / 100 then
            p.multiDotAlpha = percent / 100
            if WarlockHudMultiTarget then WarlockHudMultiTarget.UpdateAppearance() end
        end
    end)
    refreshers[#refreshers + 1] = function()
        alphaSlider:SetValue(math.floor(((Profile().multiDotAlpha or 1) * 100) / 5 + 0.5) * 5)
    end
    Text(multiDotPanel, "Toggle and adjust outside combat. Drag the title to move or the lower-right grip to resize; scroll when needed.",
        20, -318, "GameFontHighlightSmall")
    Text(multiDotPanel, "A nameplate token can be reused; its old label is cleared on removal.",
        20, -349, "GameFontHighlightSmall")
    Text(multiDotPanel, "Native aura slots show tracked effects. Brand follows Target DoTs settings.",
        20, -374, "GameFontHighlightSmall")
    Text(multiDotPanel, "Each row shows a portrait, name, health bar, and 20% health mark.",
        20, -399, "GameFontHighlightSmall")
    Text(multiDotPanel, "Timer decimals follow the setting on Tracked Auras.",
        20, -424, "GameFontHighlightSmall")
end
