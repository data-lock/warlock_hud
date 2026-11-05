-- Multi-Target DoTs settings page. The panel is created by Warlock_Hud_Options.lua.
WarlockHudOptionsMultiTarget = {}

function WarlockHudOptionsMultiTarget.Build(context)
    local multiDotPanel = context.multiDotPanel
    local Text, Check, Button = context.Text, context.Check, context.Button
    local Profile, refreshers = context.Profile, context.refreshers

    Text(multiDotPanel, "Multi-Target Window", 20, -53, "GameFontNormal")
    Text(multiDotPanel,
        "Track up to 16 engaged enemies from available nameplates and group targets.",
        20, -76, "GameFontHighlightSmall")
    Check(multiDotPanel, 20, -104, "Enable Multi-Target DoT window",
        function() return Profile().multiDotEnabled == true end,
        function(value)
            if InCombatLockdown() then return end
            Profile().multiDotEnabled = value
        end,
        "Enable or disable the window outside combat. Saved immediately.", false)
    Check(multiDotPanel, 20, -139, "Hide outside combat",
        function() return Profile().multiDotHideOutOfCombat == true end,
        function(value)
            if InCombatLockdown() then return end
            Profile().multiDotHideOutOfCombat = value
            if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
        end,
        "Show the window only during combat while it is enabled. Saved immediately.", false)

    Text(multiDotPanel, "Combat Information", 20, -184, "GameFontNormal")
    Text(multiDotPanel, "Damage is estimated. Threat shows LOW, MED, HIGH or unknown.",
        20, -207, "GameFontHighlightSmall")
    Check(multiDotPanel, 20, -235, "Show Threat Indicator",
        function() return Profile().multiDotThreatIndicator ~= false end,
        function(value)
            if InCombatLockdown() then return end
            Profile().multiDotThreatIndicator = value
            if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
        end,
        "Personal threat: LOW / MED / HIGH. A grey dash means unavailable. Saved immediately.", false)
    Check(multiDotPanel, 300, -235, "Show predicted DoT damage",
        function() return Profile().multiDotDamageEnabled ~= false end,
        function(value)
            Profile().multiDotDamageEnabled = value
            if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
        end,
        "Show approximate remaining DoT damage on Multi-Target rows.", false)
    Check(multiDotPanel, 20, -263, "Show DoT icons",
        function() return Profile().multiDotShowIcons ~= false end,
        function(value)
            Profile().multiDotShowIcons = value
            if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
        end,
        "Hide or show the native DoT icons in each row. Saved immediately; visual changes wait until safe.", false)

    Text(multiDotPanel, "Appearance", 20, -300, "GameFontNormal")
    Button(multiDotPanel, "Reset position", 20, -325, 130, function()
        if InCombatLockdown() then return end
        Profile().multiDotX, Profile().multiDotY = nil, nil
        if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
    end)
    Button(multiDotPanel, "Reset size", 163, -325, 110, function()
        if InCombatLockdown() then return end
        Profile().multiDotScale = 1
        Profile().multiDotWindowScale = 1
        Profile().multiDotWidth, Profile().multiDotHeight = 420, 420
        if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
    end)
    Text(multiDotPanel, "Window scale", 20, -359, "GameFontHighlight")
    local scaleValue = Text(multiDotPanel, "100%", 400, -359, "GameFontHighlight")
    local scaleSlider = CreateFrame("Slider", nil, multiDotPanel, "OptionsSliderTemplate")
    scaleSlider:SetSize(165, 17)
    scaleSlider:SetPoint("TOPLEFT", multiDotPanel, "TOPLEFT", 203, -356)
    scaleSlider:SetMinMaxValues(50, 100)
    scaleSlider:SetValueStep(5)
    scaleSlider:SetScript("OnValueChanged", function(_, value)
        local percent = math.max(50, math.min(100, math.floor(value / 5 + 0.5) * 5))
        scaleValue:SetText(percent .. "%")
        local p = Profile()
        if p and p.multiDotWindowScale ~= percent / 100 then
            p.multiDotWindowScale = percent / 100
            if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
        end
    end)
    refreshers[#refreshers + 1] = function()
        scaleSlider:SetValue(math.floor(((Profile().multiDotWindowScale or 1)
            * 100) / 5 + 0.5) * 5)
    end

    Text(multiDotPanel, "Transparency", 20, -388, "GameFontHighlight")
    local alphaValue = Text(multiDotPanel, "100%", 400, -388, "GameFontHighlight")
    local alphaSlider = CreateFrame("Slider", nil, multiDotPanel, "OptionsSliderTemplate")
    alphaSlider:SetSize(165, 17)
    alphaSlider:SetPoint("TOPLEFT", multiDotPanel, "TOPLEFT", 203, -385)
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

    Text(multiDotPanel, "Controls & Limitations", 20, -427, "GameFontNormal")
    Text(multiDotPanel,
        "Move or resize outside combat. In combat, target through the world or standard controls.",
        20, -450, "GameFontHighlightSmall")
    Text(multiDotPanel,
        "Available DoT timers are native. Last-seen rows may remain briefly; aura data can be protected.",
        20, -473, "GameFontHighlightSmall")
    Text(multiDotPanel,
        "Brand follows Target DoTs. Rows show health and a 20% marker.",
        20, -496, "GameFontHighlightSmall")
    Text(multiDotPanel,
        "Damage colors: Corruption amber, Bane violet, Siphon teal, Immolate red.",
        20, -519, "GameFontHighlightSmall")
    Text(multiDotPanel, "Timer decimals follow Tracked Auras.",
        20, -542, "GameFontHighlightSmall")
end
