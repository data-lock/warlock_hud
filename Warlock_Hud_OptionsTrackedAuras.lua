-- Tracked Auras settings page. Built by Warlock_Hud_Options.lua after its shared controls exist.
WarlockHudOptionsTrackedAuras = {}

function WarlockHudOptionsTrackedAuras.Build(context)
    local api = context.api
    local Panel, Text, Check = context.Panel, context.Text, context.Check
    local Button, ResetPageButton = context.Button, context.ResetPageButton
    local Profile, MarkChanged = context.Profile, context.MarkChanged
    local refreshers = context.refreshers

    local spells = Panel("Warlock HUD - Tracked Auras")
    Text(spells, "Choose which auras can appear. Banes, Curses, and Drains each share one icon slot.",
        20, -50, "GameFontHighlightSmall")
    Text(spells, "Default image changes the idle icon only.",
        20, -69, "GameFontHighlightSmall")
    local spellGroups = {
        { title = "Core DoTs and effects", x = 20, y = -90,
            contains = function(spell)
                return spell.slot == 1 or spell.slot == 5 or spell.slot == 6 or spell.slot == 7
            end },
        { title = "Banes", x = 20, y = -245, defaultKey = "bane", menuX = 115,
            contains = function(spell) return spell.slot == 2 end },
        { title = "Drains", x = 20, y = -370, defaultKey = "drain", menuX = 115,
            contains = function(spell) return spell.slot == 4 end },
        { title = "Curses", x = 345, y = -90, defaultKey = "curse", menuX = 440,
            contains = function(spell) return spell.slot == 3 and spell.group ~= 2 end },
        { title = "Control", x = 345, y = -300,
            contains = function(spell) return spell.group == 2 end },
    }
    local function SpellHelp(spell)
        if spell.group == 2 then
            return "Fear appears in Utility when enabled."
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
        if group.defaultKey then
            local key = group.defaultKey
            local menu = CreateFrame("Frame", nil, spells, "UIDropDownMenuTemplate")
            menu:SetPoint("TOPLEFT", spells, "TOPLEFT", group.menuX, group.y + 13)
            UIDropDownMenu_SetWidth(menu, 165)
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
        local index = 0
        for _, spell in ipairs(api.Spells) do
            if group.contains(spell) then
                Check(spells, group.x, group.y - 30 - index * 31, spell.name,
                    function() return Profile().enabled[spell.name] ~= false end,
                    function(value)
                        if value then
                            Profile().enabled[spell.name] = nil
                        else
                            Profile().enabled[spell.name] = false
                        end
                    end, SpellHelp(spell))
                index = index + 1
            end
        end
    end
    Text(spells, "Target DoT colors", 345, -385, "GameFontNormal")
    Check(spells, 345, -415, "Color when active; grey when missing",
        function() return Profile().colorActiveDoTs ~= false end,
        function(value)
            if value then Profile().colorActiveDoTs = nil
            else Profile().colorActiveDoTs = false end
        end,
        "On (default): color when active, grey when missing. This affects the Target DoTs row only.")
    Text(spells, "Saves now; visual update waits until safe.",
        373, -455, "GameFontHighlightSmall")
    Button(spells, "Group Assignments", 345, -478, 165, function()
        if WarlockHudOpenAssignments then WarlockHudOpenAssignments() end
    end)
    ResetPageButton(spells, "Tracked Auras", function()
        for _, spell in ipairs(api.Spells) do Profile().enabled[spell.name] = nil end
        Profile().defaultDotIcons = {}
        Profile().colorActiveDoTs = nil
        MarkChanged()
    end)
    return spells
end
