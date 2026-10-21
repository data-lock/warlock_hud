-- Multi-Target DoTs settings page. The panel is created by Warlock_Hud_Options.lua.
WarlockHudOptionsMultiTarget = {}

function WarlockHudOptionsMultiTarget.Build(context)
    local multiDotPanel = context.multiDotPanel
    local Text, Check, Button = context.Text, context.Check, context.Button
    local Profile, refreshers = context.Profile, context.refreshers

    Text(multiDotPanel, "Up to 16 mobs from nameplates and group targets. Target through world nameplates or Tab.",
        20, -54, "GameFontHighlight")
    Text(multiDotPanel, "On by default for new profiles. Use /whud mtd to open or close it outside combat.",
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
    Check(multiDotPanel, 20, -211, "Show Threat Indicator",
        function() return Profile().multiDotThreatIndicator ~= false end,
        function(value)
            if InCombatLockdown() then return end
            Profile().multiDotThreatIndicator = value
            if WarlockHudMultiTarget then WarlockHudMultiTarget.UpdateAppearance() end
        end,
        "Personal LOW / MED / HIGH threat; a grey dash means unavailable. Saved immediately; the view updates when combat and aura protection allow.", false)
    Check(multiDotPanel, 300, -211, "Show predicted DoT damage",
        function() return Profile().multiDotDamageEnabled ~= false end,
        function(value)
            Profile().multiDotDamageEnabled = value
            if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
        end,
        "Show approximate remaining DoT damage on Multi-Target rows.", false)
    Button(multiDotPanel, "Reset position", 20, -249, 130, function()
        if InCombatLockdown() then return end
        Profile().multiDotX, Profile().multiDotY = nil, nil
        if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
    end)
    Button(multiDotPanel, "Reset size", 163, -249, 110, function()
        if InCombatLockdown() then return end
        Profile().multiDotScale = 1
        Profile().multiDotWidth, Profile().multiDotHeight = 430, 548
        if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
    end)
    Text(multiDotPanel, "Transparency", 20, -295, "GameFontHighlight")
    local alphaValue = Text(multiDotPanel, "100%", 400, -295, "GameFontHighlight")
    local alphaSlider = CreateFrame("Slider", nil, multiDotPanel, "OptionsSliderTemplate")
    alphaSlider:SetSize(165, 17)
    alphaSlider:SetPoint("TOPLEFT", multiDotPanel, "TOPLEFT", 203, -292)
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
        20, -338, "GameFontHighlightSmall")
    Text(multiDotPanel, "A nameplate token can be reused; its old label is cleared on removal.",
        20, -369, "GameFontHighlightSmall")
    Text(multiDotPanel, "Native aura slots show tracked effects. Brand follows Target DoTs settings.",
        20, -394, "GameFontHighlightSmall")
    Text(multiDotPanel, "Each row shows a portrait, name, health bar, and 20% health mark.",
        20, -419, "GameFontHighlightSmall")
    Text(multiDotPanel, "Damage: amber Corruption, violet Bane, teal Siphon, red Immolate.",
        20, -469, "GameFontHighlightSmall")
    Text(multiDotPanel, "Timer decimals follow the setting on Tracked Auras.",
        20, -444, "GameFontHighlightSmall")
end
