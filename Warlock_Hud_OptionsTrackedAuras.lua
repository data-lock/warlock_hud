-- Tracked Auras settings page. Built by Warlock_Hud_Options.lua after its shared controls exist.
WarlockHudOptionsTrackedAuras = {}

function WarlockHudOptionsTrackedAuras.Build(context)
    local api = context.api
    local Panel, Text, Check = context.Panel, context.Text, context.Check
    local Button, ResetPageButton = context.Button, context.ResetPageButton
    local Profile, MarkChanged = context.Profile, context.MarkChanged
    local refreshers = context.refreshers

    local spells = Panel("Warlock HUD - Tracked Auras")
    Text(spells, "Check effects to track. Banes, Curses, and Drains share one HUD slot.",
        20, -50, "GameFontHighlightSmall")
    Text(spells, "Default menus choose the idle icon shown for each shared slot.",
        20, -69, "GameFontHighlightSmall")
    local spellGroups = {
        { title = "Core Effects", x = 20, y = -90,
            contains = function(spell)
                return spell.slot == 1 or spell.slot == 5 or spell.slot == 6 or spell.slot == 7
            end },
        { title = "Banes", x = 20, y = -265, spacing = 28,
            contains = function(spell) return spell.slot == 2 end },
        { title = "Drains", x = 20, y = -395, spacing = 28,
            contains = function(spell) return spell.slot == 4 end },
        { title = "Curses", x = 285, y = -255, spacing = 28,
            contains = function(spell) return spell.slot == 3 and spell.group ~= 2 end },
        { title = "Control", x = 285, y = -455,
            contains = function(spell) return spell.group == 2 end },
    }
    Text(spells, "Default shared-slot icons", 285, -90, "GameFontNormal")
    local defaultsBox = CreateFrame("Frame", nil, spells)
    defaultsBox:SetSize(360, 126)
    defaultsBox:SetPoint("TOPLEFT", spells, "TOPLEFT", 275, -111)
    local defaultsBack = defaultsBox:CreateTexture(nil, "BACKGROUND")
    defaultsBack:SetAllPoints(defaultsBox)
    defaultsBack:SetColorTexture(0.025, 0.035, 0.05, 0.5)
    local defaultsBorder = CreateFrame("Frame", nil, defaultsBox)
    defaultsBorder:SetAllPoints(defaultsBox)
    for _, edgeInfo in ipairs({
        { "TOP", defaultsBox:GetWidth(), 1 }, { "BOTTOM", defaultsBox:GetWidth(), 1 },
        { "LEFT", 1, defaultsBox:GetHeight() }, { "RIGHT", 1, defaultsBox:GetHeight() },
    }) do
        local edge = defaultsBorder:CreateTexture(nil, "BORDER")
        edge:SetSize(edgeInfo[2], edgeInfo[3])
        edge:SetPoint(edgeInfo[1], defaultsBorder, edgeInfo[1])
        edge:SetColorTexture(0.7, 0.54, 0.2, 0.75)
    end
    local function DefaultMenu(key, label, y)
        Text(defaultsBox, label, 12, y, "GameFontHighlight")
        local menu = CreateFrame("Frame", nil, defaultsBox, "UIDropDownMenuTemplate")
        menu:SetPoint("TOPLEFT", defaultsBox, "TOPLEFT", 105, y)
        UIDropDownMenu_SetWidth(menu, 155)
        UIDropDownMenu_Initialize(menu, function(_, level)
            if (level or 1) ~= 1 then return end
            local profile = Profile()
            local selected = profile and profile.defaultDotIcons
                and profile.defaultDotIcons[key]
            local options = { { name = "Automatic" } }
            for _, spell in ipairs(api.Spells) do
                if spell.slot == api.DotDefaultSlots[key] and spell.group ~= 2 then
                    options[#options + 1] = { name = spell.name, value = spell.name }
                end
            end
            for _, option in ipairs(options) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = option.name
                info.checked = selected == option.value
                info.func = function()
                    Profile().defaultDotIcons[key] = option.value
                    MarkChanged()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        refreshers[#refreshers + 1] = function()
            local profile = Profile()
            UIDropDownMenu_SetText(menu,
                profile and profile.defaultDotIcons
                    and profile.defaultDotIcons[key] or "Automatic")
        end
    end
    DefaultMenu("bane", "Default Bane", -9)
    DefaultMenu("curse", "Default Curse", -47)
    DefaultMenu("drain", "Default Drain", -85)
    local function SpellHelp(spell)
        if spell.group == 2 then
            return "Fear and Banish appear in Utility when enabled."
        elseif spell.slot == 2 then
            return "Banes share one Target DoTs icon slot. Enable this aura to make it eligible."
        elseif spell.slot == 3 then
            return "Curses share one Target DoTs icon slot. Enable this aura to make it eligible."
        elseif spell.slot == 4 then
            return "Drains share one Target DoTs icon slot. Enable this aura to make it eligible."
        elseif spell.talentEffect then
            return "Tracks Demonic Brand when talented. Blizzard renders its duration; remaining attack counts need in-game verification."
        end
        return "Shows this aura on Target DoTs when active."
    end
    for _, group in ipairs(spellGroups) do
        Text(spells, group.title, group.x, group.y, "GameFontNormal")
        local index = 0
        for _, spell in ipairs(api.Spells) do
            if group.contains(spell) then
                Check(spells, group.x, group.y - 30 - index * (group.spacing or 31), spell.name,
                    function() return Profile().enabled[spell.name] ~= false end,
                    function(value)
                        if value then
                            Profile().enabled[spell.name] = nil
                        else
                            Profile().enabled[spell.name] = false
                        end
                    end, SpellHelp(spell), nil, 22, 5)
                index = index + 1
            end
        end
    end
    Text(spells, "Appearance", 400, -455, "GameFontNormal")
    Check(spells, 400, -485, "Color active DoTs",
        function() return Profile().colorActiveDoTs ~= false end,
        function(value)
            if value then Profile().colorActiveDoTs = nil
            else Profile().colorActiveDoTs = false end
        end,
        "On (default): color when active, grey when missing. This affects the Target DoTs row only.",
        nil, 22, 5)
    Check(spells, 400, -510, "Timer ms",
        function() return Profile().dotTimerMilliseconds ~= false end,
        function(value) Profile().dotTimerMilliseconds = value end,
        "Applies to Target DoTs and Multi-Target DoTs. Saves now; native timers update when combat and aura protection allow a rebuild.",
        nil, 22, 5)
    Button(spells, "Group Assignments", 165, -540, 165, function()
        if WarlockHudOpenAssignments then WarlockHudOpenAssignments() end
    end)
    ResetPageButton(spells, "Tracked Auras", function()
        for _, spell in ipairs(api.Spells) do Profile().enabled[spell.name] = nil end
        Profile().defaultDotIcons = {}
        Profile().colorActiveDoTs = nil
        Profile().dotTimerMilliseconds = true
        MarkChanged()
    end, 350, -540)
    return spells
end
