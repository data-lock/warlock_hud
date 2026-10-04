local api = WarlockHudAPI
local panels = {}
local refreshers = {}
local dirty = false
local NUMERIC_DEFAULTS = {
    mainSize = 48, cooldownSize = 24, buffSize = 24,
    procSize = 32, shardSize = 32,
}

local LABELS = {
    corruption = "Corruption", bane = "Banes", curse = "Curses", drain = "Drains",
    immolate = "Immolate",
    healthstone = "Healthstone", soulstone = "Soulstone", fear = "Fear",
    soulsiphon = "Soul Siphon", soulshards = "Soul Shards",
    armor = "Armor / Skin", wellfed = "Well Fed",
    racial1 = "Racial ability 1", racial2 = "Racial ability 2",
    fort = "Fortitude", motw = "Mark of the Wild", int = "Intellect",
    spirit = "Spirit", kings = "Kings", salv = "Salvation",
    thorns = "Thorns", breath = "Unending Breath",
    powerinfusion = "Power Infusion", nightfall = "Nightfall",
}
local TILE_LABELS = { motw = "Wild", breath = "Breath" }

local ICON_HELP = {
    corruption = "Target DoT. Shows its active aura countdown.",
    immolate = "Target DoT. Shows its active aura countdown.",
    bane = "Banes share one Target DoTs icon slot. Choose eligible Banes on Tracked Auras.",
    curse = "Curses share one Target DoTs icon slot. Preview icon: Curse of Weakness.",
    drain = "Drains share one Target DoTs icon slot. Choose eligible Drains on Tracked Auras.",
    healthstone = "Shows your Healthstone and its item cooldown.",
    soulstone = "Shows your Soulstone and its item cooldown.",
    fear = "Shows Fear in the Utility row when available.",
    racial1 = "Shows an available racial ability and its cooldown.",
    racial2 = "Shows a second racial ability when available.",
    soulsiphon = "Passive Soul Siphon talent indicator; it has no cooldown.",
    armor = "Demon Armor or Demon Skin. Glows when missing.",
    wellfed = "Well Fed. Glows when missing.",
    fort = "Includes Power Word: Fortitude and Prayer of Fortitude.",
    motw = "Includes Mark of the Wild and Gift of the Wild.",
    int = "Includes Arcane Intellect and Arcane Brilliance.",
    spirit = "Includes Divine Spirit and Prayer of Spirit.",
    kings = "Includes Blessing of Kings and Greater Blessing of Kings.",
    salv = "Includes Blessing of Salvation and Greater Blessing of Salvation.",
    thorns = "Shows Thorns while active and warns when a Druid in your group can provide it.",
    breath = "Unending Breath appears at the right end only while active, with a native countdown.",
    powerinfusion = "Appears only while Power Infusion is active, with a pulsing countdown.",
    nightfall = "Shows Shadow Trance while active, with a pulsing countdown.",
}

local function Profile()
    return api.GetProfile()
end

local function RefreshAll()
    for _, refresh in ipairs(refreshers) do refresh() end
end

local function MarkChanged(needsRebuild)
    if needsRebuild ~= false then
        dirty = true
        if api.Rebuild() then dirty = false end
    end
    RefreshAll()
end

local function CanRebuild()
    return not InCombatLockdown()
        and not (C_Secrets and C_Secrets.ShouldAurasBeSecret
            and C_Secrets.ShouldAurasBeSecret())
end

local function Text(parent, value, x, y, font)
    local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(value)
    return label
end

local function Button(parent, label, x, y, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

local function Check(parent, x, y, label, getValue, setValue, tooltip, needsRebuild)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    Text(parent, label, x + 28, y - 5, "GameFontHighlight")
    check:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
        MarkChanged(needsRebuild)
    end)
    if tooltip then
        check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    refreshers[#refreshers + 1] = function()
        check:SetChecked(getValue())
    end
    return check
end

local function RetryHudUpdate()
    if not dirty then return end
    if not CanRebuild() then return end
    if not api.Rebuild() then
        print("|cffff7a7aWarlock HUD:|r HUD update is still pending.")
        return
    end
    dirty = false
    RefreshAll()
end

local function ApplyFooter(parent)
    local status = Text(parent, "", 20, -530, "GameFontHighlightSmall")
    local button = Button(parent, "Retry HUD Update", 430, -520, 150, RetryHudUpdate)
    local function RefreshFooter()
        button:SetEnabled(dirty and CanRebuild())
        if not dirty then
            status:SetText("Saved automatically.")
        elseif InCombatLockdown() then
            status:SetText("Saved; HUD updates after combat.")
        elseif not CanRebuild() then
            status:SetText("Saved; waiting for aura access.")
        else
            status:SetText("Saved; HUD update pending.")
        end
    end
    parent:SetScript("OnUpdate", function(self, elapsed)
        if not dirty then return end
        self.refreshElapsed = (self.refreshElapsed or 0) + elapsed
        if self.refreshElapsed >= 0.5 then
            self.refreshElapsed = 0
            RefreshFooter()
        end
    end)
    refreshers[#refreshers + 1] = RefreshFooter
end

local function Panel(name, hasFooter)
    local frame = CreateFrame("Frame")
    frame:SetSize(720, 560)
    Text(frame, name, 20, -20, "GameFontNormalLarge")
    frame:SetScript("OnShow", RefreshAll)
    panels[#panels + 1] = frame
    if hasFooter ~= false then ApplyFooter(frame) end
    return frame
end

local function SizeSlider(parent, label, key, minimum, maximum, x, y)
    Text(parent, label, x, y - 5, "GameFontHighlight")
    local valueText = Text(parent, "", x + 395, y - 5, "GameFontHighlight")
    Text(parent, minimum .. "-" .. maximum .. " px", x + 460, y - 5, "GameFontHighlightSmall")
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetSize(165, 17)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 183, y - 3)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(1)
    local function Clamp(value)
        return math.max(minimum, math.min(maximum, math.floor(value + 0.5)))
    end
    local function Commit(value)
        value = Clamp(value)
        slider:SetValue(value)
        if Profile()[key] ~= value then
            Profile()[key] = value
            MarkChanged()
        end
    end
    slider:SetScript("OnValueChanged", function(_, value)
        valueText:SetText(Clamp(value) .. " px")
    end)
    slider:SetScript("OnMouseUp", function(self)
        Commit(self:GetValue())
    end)
    local minus = Button(parent, "-", x + 150, y, 24, function()
        Commit(Profile()[key] - 1)
    end)
    local plus = Button(parent, "+", x + 355, y, 24, function()
        Commit(Profile()[key] + 1)
    end)
    refreshers[#refreshers + 1] = function()
        local value = (Profile() and Profile()[key]) or NUMERIC_DEFAULTS[key]
        slider:SetValue(value)
        valueText:SetText(value .. " px")
        minus:SetEnabled(value > minimum)
        plus:SetEnabled(value < maximum)
    end
end

local function DisplayName(key)
    if key == "racial1" or key == "racial2" then
        local _, _, raceID = UnitRace("player")
        local racial = api.Racials[raceID]
            and api.Racials[raceID][key == "racial1" and 1 or 2]
        if racial then return racial[1] end
    end
    return LABELS[key] or key
end

local function IconForKey(key)
    local spellIDs = {
        corruption = 6222, bane = 1014, drain = 1120, immolate = 348,
        fear = 5782, armor = 706, wellfed = 19705, soulsiphon = 17804,
        fort = 1243, motw = 1126, int = 1459,
        spirit = 14752, kings = 20217, salv = 1038,
        thorns = 467, breath = 5697,
        powerinfusion = 10060, nightfall = 17941,
    }
    if key == "healthstone" or key == "soulstone" or key == "soulshards" then
        return C_Item and C_Item.GetItemIconByID
            and C_Item.GetItemIconByID(key == "healthstone" and 5512
                or key == "soulstone" and 5232 or 6265)
    end
    if key == "racial1" or key == "racial2" then
        local _, _, raceID = UnitRace("player")
        local racial = api.Racials[raceID]
            and api.Racials[raceID][key == "racial1" and 1 or 2]
        return racial and C_Spell and C_Spell.GetSpellTexture(racial[2])
    end
    if key == "curse" then
        return "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth"
    end
    return C_Spell and C_Spell.GetSpellTexture(spellIDs[key])
end

local function OrderSection(parent, title, orderKey, defaults, y, columns, onReset)
    Text(parent, title, 20, y, "GameFontNormal")
    if onReset then
        local reset = Button(parent, "Reset Row", 480, y + 8, 100, onReset)
        reset:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title)
            GameTooltip:AddLine("Restores icon size, order, and visibility. Edit Mode position stays.",
                1, 1, 1, true)
            GameTooltip:Show()
        end)
        reset:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    columns = columns or #defaults
    local rows = math.ceil(#defaults / columns)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetSize(columns * 78, rows > 1 and rows * 95 or 50)
    strip:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y - 29)
    local tiles = {}
    for index = 1, #defaults do
        local tile = CreateFrame("Button", nil, strip)
        tile:SetSize(42, 42)
        tile:SetMovable(true)
        tile:EnableMouse(true)
        tile:RegisterForDrag("LeftButton")
        local background = tile:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(tile)
        background:SetColorTexture(0, 0, 0, 1)
        local icon = tile:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", tile, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.115, 0.885, 0.115, 0.885)
        tile.icon = icon
        tile:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(DisplayName(self.key))
            if ICON_HELP[self.key] then
                GameTooltip:AddLine(ICON_HELP[self.key], 1, 1, 1, true)
            end
            if orderKey == "buffOrder" and self.key == "breath" then
                GameTooltip:AddLine("Fixed at the right end of the buff row", 1, 1, 1)
            else
                GameTooltip:AddLine("Drag to change order", 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tile:SetScript("OnDragStart", function(self)
            if orderKey == "buffOrder" and self.key == "breath" then return end
            self:StartMoving()
            self:SetFrameStrata("DIALOG")
            GameTooltip:Hide()
        end)
        tile:SetScript("OnDragStop", function(self)
            if orderKey == "buffOrder" and self.key == "breath" then
                RefreshAll()
                return
            end
            self:StopMovingOrSizing()
            self:SetFrameStrata("MEDIUM")
            local cursorX, cursorY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            cursorX, cursorY = cursorX / scale, cursorY / scale
            local left, bottom, top = strip:GetLeft(), strip:GetBottom(), strip:GetTop()
            if left and bottom and top and cursorY >= bottom - 20 and cursorY <= top + 20 then
                local column = math.max(1, math.min(columns,
                    math.floor((cursorX - left) / 78) + 1))
                local row = rows > 1 and math.max(1, math.min(rows,
                    math.floor((top - cursorY) / 95) + 1)) or 1
                local lastMovable = orderKey == "buffOrder" and #defaults - 1 or #defaults
                local destination = math.min(lastMovable, (row - 1) * columns + column)
                if destination ~= index then
                    local order = Profile()[orderKey]
                    local moved = table.remove(order, index)
                    table.insert(order, destination, moved)
                    MarkChanged()
                    return
                end
            end
            RefreshAll()
        end)
        local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        check:SetPoint("TOP", tile, "BOTTOM", 0, -19)
        check:SetScript("OnClick", function(self)
            local key = Profile()[orderKey][index]
            if self:GetChecked() then
                Profile().enabled[key] = nil
            else
                Profile().enabled[key] = false
            end
            MarkChanged()
        end)
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetSize(70, 16)
        label:SetPoint("TOP", tile, "BOTTOM", 0, -2)
        label:SetJustifyH("CENTER")
        tiles[index] = { frame = tile, check = check, label = label }
    end
    refreshers[#refreshers + 1] = function()
        for index, tile in ipairs(tiles) do
            local key = Profile()[orderKey][index]
            tile.frame.key = key
            tile.frame:ClearAllPoints()
            tile.frame:SetPoint("TOPLEFT", strip, "TOPLEFT",
                ((index - 1) % columns) * 78,
                -math.floor((index - 1) / columns) * 95)
            tile.frame.icon:SetTexture(IconForKey(key) or "Interface\\Icons\\INV_Misc_QuestionMark")
            tile.frame.icon:SetDesaturated(Profile().enabled[key] == false)
            tile.frame:SetAlpha(Profile().enabled[key] == false and 0.5 or 1)
            tile.label:SetText(TILE_LABELS[key] or DisplayName(key))
            tile.check:SetChecked(Profile().enabled[key] ~= false)
        end
    end
end

local function DefaultProfile()
    return api.NormalizeProfile({})
end

local function ResetRowValues(sizeKey, orderKey, keys, defaults)
    local profile = Profile()
    profile[sizeKey] = defaults[sizeKey]
    profile[orderKey] = {}
    for index, key in ipairs(defaults[orderKey]) do
        profile[orderKey][index] = key
    end
    for _, key in ipairs(keys) do profile.enabled[key] = nil end
end

StaticPopupDialogs.WARLOCKHUD_RESET_PAGE = {
    text = "Reset %s settings in the current profile?\nEdit Mode positions are kept.",
    button1 = "Reset Page",
    button2 = CANCEL,
    OnAccept = function(_, reset) if reset then reset() end end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function ResetPageButton(parent, pageName, reset)
    Button(parent, "Reset Page", 300, -520, 110, function()
        StaticPopup_Show("WARLOCKHUD_RESET_PAGE", pageName, nil, reset)
    end)
end

local layout = Panel("Warlock HUD - Rows & Layout")
Text(layout, "Move rows in Edit Mode. Drag icons to reorder them; use the checks to show or hide them.",
    20, -50, "GameFontHighlightSmall")
Text(layout, "Icon sizes", 20, -82, "GameFontNormal")
SizeSlider(layout, "Target DoT icon size", "mainSize", 16, 96, 20, -105)
SizeSlider(layout, "Utility icon size", "cooldownSize", 16, 64, 20, -135)
OrderSection(layout, "Target DoTs", "mainOrder", api.MainKeys, -180, nil, function()
    ResetRowValues("mainSize", "mainOrder", api.MainKeys, DefaultProfile())
    MarkChanged()
end)
OrderSection(layout, "Utility", "cooldownOrder", api.CooldownKeys, -315, nil, function()
    ResetRowValues("cooldownSize", "cooldownOrder", api.CooldownKeys, DefaultProfile())
    MarkChanged()
end)
Text(layout, "Nameplates", 20, -455, "GameFontNormal")
Check(layout, 20, -475, "20% marker on attackable nameplates",
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
end)

local buffLayout = Panel("Warlock HUD - Buffs")
Text(buffLayout, "Move this row in Edit Mode. Drag icons to reorder them; use the checks to show or hide them.",
    20, -50, "GameFontHighlightSmall")
Text(buffLayout, "Icon size", 20, -85, "GameFontNormal")
SizeSlider(buffLayout, "Buff icon size", "buffSize", 16, 64, 20, -110)
OrderSection(buffLayout, "Player buffs", "buffOrder", api.BuffKeys, -165, 5, function()
    ResetRowValues("buffSize", "buffOrder", api.BuffKeys, DefaultProfile())
    MarkChanged()
end)
Text(buffLayout, "Buff reminders", 20, -400, "GameFontNormal")
Text(buffLayout, "Fortitude, Wild, Intellect, Spirit, Kings, and Salvation include group versions.",
    20, -427, "GameFontHighlightSmall")
Text(buffLayout, "Demon Armor / Skin and Well Fed glow when missing.",
    20, -449, "GameFontHighlightSmall")
Text(buffLayout, "Missing group buffs pulse red when your group has the matching class.",
    20, -471, "GameFontHighlightSmall")

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

local spells = Panel("Warlock HUD - Tracked Auras")
Text(spells, "Choose which auras can appear. Banes, Curses, and Drains each share one icon slot.",
    20, -50, "GameFontHighlightSmall")
local spellGroups = {
    { title = "Corruption & Immolate", x = 20, y = -90,
        contains = function(spell) return spell.slot == 1 or spell.slot == 5 end },
    { title = "Banes", x = 20, y = -205,
        contains = function(spell) return spell.slot == 2 end },
    { title = "Drains", x = 20, y = -360,
        contains = function(spell) return spell.slot == 4 end },
    { title = "Curses", x = 345, y = -90,
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
    end
    return "Shows this aura on Target DoTs when active."
end
for _, group in ipairs(spellGroups) do
    Text(spells, group.title, group.x, group.y, "GameFontNormal")
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
ResetPageButton(spells, "Tracked Auras", function()
    for _, spell in ipairs(api.Spells) do Profile().enabled[spell.name] = nil end
    MarkChanged()
end)

local profiles = Panel("Warlock HUD - Profiles")
Text(profiles, "Profiles keep row sizes, order, visibility, and Edit Mode positions together.",
    20, -50, "GameFontHighlightSmall")
Text(profiles, "Active profile", 20, -85, "GameFontNormal")
Text(profiles, "Profile summary", 350, -85, "GameFontNormal")
local profileSummary = Text(profiles, "", 350, -115, "GameFontHighlightSmall")
profileSummary:SetWidth(230)
profileSummary:SetJustifyH("LEFT")
Text(profiles, "Current profile", 20, -115, "GameFontHighlight")
local selector = CreateFrame("Frame", "WarlockHudProfileSelector", profiles, "UIDropDownMenuTemplate")
selector:SetPoint("TOPLEFT", profiles, "TOPLEFT", 150, -102)
UIDropDownMenu_SetWidth(selector, 180)
UIDropDownMenu_Initialize(selector, function(_, level)
    if (level or 1) ~= 1 then return end
    local db = api.GetDB()
    if not db or not db.profiles then return end
    local names = {}
    for name in pairs(db.profiles) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = name
        info.checked = name == api.GetDB().activeProfile
        info.func = function()
            local db = api.GetDB()
            local changed = db.activeProfile ~= name
            db.activeProfile = name
            if db.autoSpecProfiles then
                local group = api.ActiveTalentGroup()
                if group then
                    db.specProfiles = db.specProfiles or {}
                    if db.specProfiles[group] ~= name then changed = true end
                    db.specProfiles[group] = name
                end
            end
            if changed then
                api.InitializeProfiles()
                MarkChanged()
            end
            UIDropDownMenu_SetText(selector, name)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)
refreshers[#refreshers + 1] = function()
    UIDropDownMenu_SetText(selector, api.GetDB().activeProfile)
end

Text(profiles, "Manage profiles", 20, -160, "GameFontNormal")
Text(profiles, "Profile name", 20, -190, "GameFontHighlight")
local nameInput = CreateFrame("EditBox", nil, profiles, "InputBoxTemplate")
nameInput:SetSize(180, 24)
nameInput:SetPoint("TOPLEFT", profiles, "TOPLEFT", 150, -182)
nameInput:SetAutoFocus(false)
nameInput:SetMaxLetters(40)
local suggestedName = ((api.GetDB() and api.GetDB().activeProfile) or "Default") .. " Copy"
nameInput:SetText(suggestedName)
nameInput:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
local nameStatus = Text(profiles, "", 400, -190, "GameFontHighlightSmall")
refreshers[#refreshers + 1] = function()
    if not nameInput:HasFocus()
        and (nameInput:GetText() == "" or nameInput:GetText() == suggestedName) then
        local db = api.GetDB()
        suggestedName = (db and db.activeProfile or "Default") .. " Copy"
        nameInput:SetText(suggestedName)
    end
end

local function EnteredName()
    return (nameInput:GetText() or ""):match("^%s*(.-)%s*$")
end

local function ValidProfileName()
    local name = EnteredName()
    if name == "" then return nil, "Enter a profile name." end
    if name:find("%c") or name:lower() == "none" then
        return nil, "Choose another name."
    end
    local db = api.GetDB()
    for existing in pairs(db and db.profiles or {}) do
        if existing:lower() == name:lower() then
            return nil, "That name already exists."
        end
    end
    return name
end

local createButton, renameButton, deleteButton
local function UpdateNameActions()
    local name, reason = ValidProfileName()
    if createButton then createButton:SetEnabled(name ~= nil) end
    if renameButton then renameButton:SetEnabled(name ~= nil) end
    nameStatus:SetText(name and "Name is available." or reason)
    nameStatus:SetTextColor(name and 0.4 or 1, name and 1 or 0.55, 0.4)
end

local function CopyProfile(source)
    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = {}
            for childKey, childValue in pairs(value) do copy[key][childKey] = childValue end
        else
            copy[key] = value
        end
    end
    return copy
end

createButton = Button(profiles, "Create Copy", 20, -225, 120, function()
    local name = ValidProfileName()
    if not name then return end
    api.GetDB().profiles[name] = api.NormalizeProfile(CopyProfile(Profile()))
    api.GetDB().activeProfile = name
    local db = api.GetDB()
    if db.autoSpecProfiles then
        local group = api.ActiveTalentGroup()
        if group then
            db.specProfiles = db.specProfiles or {}
            db.specProfiles[group] = name
        end
    end
    api.InitializeProfiles()
    nameInput:SetText("")
    MarkChanged()
end)

renameButton = Button(profiles, "Rename", 148, -225, 100, function()
    local name = ValidProfileName()
    if not name then return end
    local db = api.GetDB()
    if type(db.specProfiles) == "table" then
        for group = 1, 2 do
            if db.specProfiles[group] == db.activeProfile then db.specProfiles[group] = name end
        end
    end
    db.profiles[name] = db.profiles[db.activeProfile]
    db.profiles[db.activeProfile] = nil
    db.activeProfile = name
    api.InitializeProfiles()
    nameInput:SetText("")
    MarkChanged()
end)

local function DeleteProfile(name)
    local db = api.GetDB()
    if db.activeProfile ~= name then return end
    local count = 0
    for _ in pairs(db.profiles) do count = count + 1 end
    if count <= 1 then return end
    if type(db.specProfiles) == "table" then
        for group = 1, 2 do
            if db.specProfiles[group] == db.activeProfile then db.specProfiles[group] = nil end
        end
    end
    db.profiles[db.activeProfile] = nil
    db.activeProfile = db.profiles.Default and "Default" or next(db.profiles)
    api.InitializeProfiles()
    MarkChanged()
end

StaticPopupDialogs.WARLOCKHUD_DELETE_PROFILE = {
    text = "Delete profile %s? This cannot be undone.",
    button1 = "Delete Profile",
    button2 = CANCEL,
    OnAccept = function(_, name) DeleteProfile(name) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

deleteButton = Button(profiles, "Delete Current", 256, -225, 125, function()
    local db = api.GetDB()
    if db and db.activeProfile then
        StaticPopup_Show("WARLOCKHUD_DELETE_PROFILE", db.activeProfile, nil, db.activeProfile)
    end
end)

nameInput:SetScript("OnTextChanged", UpdateNameActions)

Text(profiles, "Dual spec", 20, -275, "GameFontNormal")
local specStatus = Text(profiles, "", 350, -305, "GameFontHighlightSmall")
specStatus:SetWidth(230)
specStatus:SetJustifyH("LEFT")
Check(profiles, 20, -300, "Switch profiles with dual spec",
    function() return api.GetDB().autoSpecProfiles == true end,
    function(value)
        local db = api.GetDB()
        db.autoSpecProfiles = value
        if value then
            local group = api.ActiveTalentGroup()
            if group then
                db.specProfiles = db.specProfiles or {}
                db.specProfiles[group] = db.specProfiles[group] or db.activeProfile
            end
        end
        api.InitializeProfiles()
    end)

local function SpecProfileSelector(group, label, y)
    Text(profiles, label, 20, y - 7, "GameFontHighlight")
    local menu = CreateFrame("Frame", nil, profiles, "UIDropDownMenuTemplate")
    menu:SetPoint("TOPLEFT", profiles, "TOPLEFT", 150, y)
    UIDropDownMenu_SetWidth(menu, 180)
    UIDropDownMenu_Initialize(menu, function(_, level)
        if (level or 1) ~= 1 then return end
        local db = api.GetDB()
        if not db or not db.profiles then return end
        local names = {}
        for name in pairs(db.profiles) do names[#names + 1] = name end
        table.sort(names)
        local options = { "None" }
        for _, name in ipairs(names) do options[#options + 1] = name end
        for _, name in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.checked = (db.specProfiles and db.specProfiles[group] or "None") == name
            info.func = function()
                db.specProfiles = db.specProfiles or {}
                db.specProfiles[group] = name ~= "None" and name or nil
                api.InitializeProfiles()
                MarkChanged()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    refreshers[#refreshers + 1] = function()
        local db = api.GetDB()
        UIDropDownMenu_SetText(menu, db.specProfiles and db.specProfiles[group] or "None")
    end
end

SpecProfileSelector(1, "Primary spec", -345)
SpecProfileSelector(2, "Secondary spec", -390)
Text(profiles, "Create a copy above, then assign it to the other spec.",
    20, -445, "GameFontHighlightSmall")
Text(profiles, "Selecting a profile assigns it to the current spec when automatic switching is on.",
    20, -468, "GameFontHighlightSmall")

refreshers[#refreshers + 1] = function()
    local db = api.GetDB()
    local profile = Profile()
    if not db or not profile then return end
    local count = 0
    for _ in pairs(db.profiles) do count = count + 1 end
    deleteButton:SetEnabled(count > 1)
    UpdateNameActions()

    local function EnabledCount(keys)
        local enabled = 0
        for _, key in ipairs(keys) do
            if profile.enabled[key] ~= false then enabled = enabled + 1 end
        end
        return enabled
    end
    profileSummary:SetText("Selected: " .. db.activeProfile
        .. "\nEnabled slots: " .. EnabledCount(api.MainKeys)
        .. " / " .. EnabledCount(api.CooldownKeys)
        .. " / " .. EnabledCount(api.BuffKeys) .. " / " .. EnabledCount(api.ProcKeys)
        .. "\nSizes: " .. profile.mainSize .. " / " .. profile.cooldownSize
        .. " / " .. profile.buffSize .. " / " .. profile.procSize .. " px"
        .. "\n(DoTs / Utility / Buffs / Procs)")

    if not db.autoSpecProfiles then
        specStatus:SetText("Automatic switching is off.")
    else
        local group = api.ActiveTalentGroup()
        local groupName = group == 1 and "Primary" or group == 2 and "Secondary"
            or "Unavailable"
        local assigned = group and db.specProfiles and db.specProfiles[group] or "None"
        specStatus:SetText("Current spec: " .. groupName
            .. "\nAssigned profile: " .. (assigned or "None"))
    end
end

local notifications = Panel("Warlock HUD - Notifications")
Text(notifications, "Choose which Warlock actions show a chat notification.",
    20, -50, "GameFontHighlightSmall")
Text(notifications, "Announcements", 20, -85, "GameFontNormal")
local notificationChoices = {
    { "notifySummon", "Ritual of Summoning", -115 },
    { "notifySoulstone", "Soulstone cast on a player", -180 },
    { "notifyHealthstone", "Healthstone trade accepted", -245 },
}
for _, choice in ipairs(notificationChoices) do
    local key = choice[1]
    Check(notifications, 20, choice[3], choice[2],
        function() return Profile().enabled[key] ~= false end,
        function(value)
            if value then Profile().enabled[key] = nil
            else Profile().enabled[key] = false end
        end, nil, false)
end
Text(notifications, "Example: Summoning Player. Please click the portal.",
    48, -148, "GameFontHighlightSmall")
Text(notifications, "Example: Soulstone cast on Player.",
    48, -213, "GameFontHighlightSmall")
Text(notifications, "Example: Healthstone trade accepted with Player.",
    48, -278, "GameFontHighlightSmall")
Text(notifications, "Delivery", 20, -325, "GameFontNormal")
Check(notifications, 20, -355, "Send summon and Healthstone trade notices to group chat",
    function() return Profile().notificationChannel == "GROUP" end,
    function(value) Profile().notificationChannel = value and "GROUP" or "SELF" end,
    nil, false)
Text(notifications, "When off, summon and trade notices appear only in your chat window.",
    48, -390, "GameFontHighlightSmall")
Text(notifications, "Soulstone goes to party, raid, or instance chat when grouped regardless of this setting.",
    20, -420, "GameFontHighlightSmall")
ResetPageButton(notifications, "Notifications", function()
    for _, choice in ipairs(notificationChoices) do
        Profile().enabled[choice[1]] = nil
    end
    Profile().notificationChannel = "SELF"
    MarkChanged(false)
end)

local shards = Panel("Warlock HUD - Soul Shards")
Text(shards, "Move the shard icon in Edit Mode; it snaps to the grid.",
    20, -50, "GameFontHighlightSmall")
Text(shards, "Shard icon", 20, -85, "GameFontNormal")
Check(shards, 20, -110, "Show Soul Shards icon",
    function() return Profile().enabled.soulshards ~= false end,
    function(value) Profile().enabled.soulshards = value and nil or false end)
SizeSlider(shards, "Shard icon size", "shardSize", 16, 64, 20, -150)
Text(shards, "Shard reserve", 20, -205, "GameFontNormal")
Text(shards, "Minimum shards to keep", 20, -235, "GameFontHighlight")
local shardEdit = CreateFrame("EditBox", nil, shards, "InputBoxTemplate")
shardEdit:SetSize(55, 24)
shardEdit:SetPoint("TOPLEFT", shards, "TOPLEFT", 260, -230)
shardEdit:SetAutoFocus(false)
shardEdit:SetMaxLetters(2)
shardEdit:SetNumeric(true)
shardEdit:SetText(tostring((Profile() and Profile().shardKeepCount) or 8))
shardEdit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
local function CommitShardReserve()
    local value = tonumber(shardEdit:GetText())
    if value then
        value = math.max(0, math.min(64, math.floor(value)))
        if Profile().shardKeepCount ~= value then
            Profile().shardKeepCount = value
            MarkChanged(false)
        end
    end
    shardEdit:SetText(tostring(Profile().shardKeepCount or 8))
    shardEdit:ClearFocus()
end
shardEdit:SetScript("OnEnterPressed", CommitShardReserve)
shardEdit:SetScript("OnEditFocusLost", CommitShardReserve)
Button(shards, "Use default 8", 335, -230, 125, function()
    if Profile().shardKeepCount ~= 8 then
        Profile().shardKeepCount = 8
        MarkChanged(false)
    end
end)
Text(shards, "Shard deletion", 20, -295, "GameFontNormal")
local shardWarning = Text(shards, "Each click permanently destroys one Soul Shard.",
    20, -325, "GameFontHighlight")
shardWarning:SetTextColor(1, 0.65, 0.25)
Text(shards, "Only your backpack and regular bags are affected.",
    20, -355, "GameFontHighlightSmall")
Text(shards, "Deletion stops at your minimum and is unavailable in combat.",
    20, -380, "GameFontHighlightSmall")
refreshers[#refreshers + 1] = function()
    if not shardEdit:HasFocus() then
        shardEdit:SetText(tostring((Profile() and Profile().shardKeepCount) or 8))
    end
end
ResetPageButton(shards, "Soul Shards", function()
    local defaults = DefaultProfile()
    Profile().enabled.soulshards = nil
    Profile().shardSize = defaults.shardSize
    Profile().shardKeepCount = defaults.shardKeepCount
    MarkChanged()
end)

local about = Panel("Warlock HUD - About", false)
local function AddonMetadata(key)
    return C_AddOns and C_AddOns.GetAddOnMetadata
        and C_AddOns.GetAddOnMetadata("Warlock_Hud", key) or "unknown"
end
Text(about, "A movable Warlock HUD for World of Warcraft: Forever beta.",
    20, -50, "GameFontHighlightSmall")
Text(about, "Build", 20, -88, "GameFontNormal")
Text(about, "Version " .. AddonMetadata("Version") .. "  |  Interface "
    .. AddonMetadata("Interface"), 20, -115, "GameFontHighlight")
Text(about, "What it shows", 20, -155, "GameFontNormal")
Text(about, "Target DoTs, utility cooldowns, buffs, procs, and Soul Shards.",
    20, -182, "GameFontHighlight")
Text(about, "Controls", 20, -222, "GameFontNormal")
Text(about, "/whub or /whud opens settings. Move rows and the shard icon in Edit Mode.",
    20, -249, "GameFontHighlight")
Text(about, "Settings save automatically to the current profile.",
    20, -279, "GameFontHighlight")
Text(about, "GitHub", 20, -319, "GameFontNormal")
Text(about, "https://github.com/data-lock/warlock_hud", 20, -346, "GameFontHighlight")

local category
local registration = CreateFrame("Frame")
registration:RegisterEvent("PLAYER_LOGIN")
registration:RegisterEvent("PLAYER_REGEN_ENABLED")
registration:RegisterEvent("PLAYER_REGEN_DISABLED")
registration:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
registration:SetScript("OnEvent", function(_, event)
    if event == "ACTIVE_TALENT_GROUP_CHANGED" then
        RefreshAll()
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        RefreshAll()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if dirty and api.Rebuild() then
            dirty = false
        end
        RefreshAll()
        return
    end
    api.InitializeProfiles()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then
        print("|cffff7a7aWarlock HUD:|r AddOn settings are unavailable on this client.")
        return
    end
    category = Settings.RegisterCanvasLayoutCategory(layout, "Warlock HUD")
    Settings.RegisterAddOnCategory(category)
    Settings.RegisterCanvasLayoutSubcategory(category, spells, "Tracked Auras")
    Settings.RegisterCanvasLayoutSubcategory(category, buffLayout, "Buffs")
    Settings.RegisterCanvasLayoutSubcategory(category, procLayout, "Procs")
    Settings.RegisterCanvasLayoutSubcategory(category, profiles, "Profiles")
    Settings.RegisterCanvasLayoutSubcategory(category, notifications, "Notifications")
    Settings.RegisterCanvasLayoutSubcategory(category, shards, "Soul Shards")
    Settings.RegisterCanvasLayoutSubcategory(category, about, "About")
    RefreshAll()
end)

function WarlockHudOpenSettings()
    if category then
        Settings.OpenToCategory(category:GetID())
        return true
    end
end
