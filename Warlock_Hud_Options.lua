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
    powerinfusion = "Power Infusion", nightfall = "Nightfall",
}

local function Profile()
    return api.GetProfile()
end

local function RefreshAll()
    for _, refresh in ipairs(refreshers) do refresh() end
end

local function MarkChanged()
    dirty = true
    if api.Rebuild() then dirty = false end
    RefreshAll()
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

local function Check(parent, x, y, label, getValue, setValue)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    Text(parent, label, x + 28, y - 5, "GameFontHighlight")
    check:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
        MarkChanged()
    end)
    refreshers[#refreshers + 1] = function()
        check:SetChecked(getValue())
    end
    return check
end

local function Apply()
    if not dirty then return end
    if not api.Rebuild() then
        print("|cffff7a7aWarlock HUD:|r Apply after combat ends.")
        return
    end
    dirty = false
    RefreshAll()
end

local function ApplyFooter(parent)
    local status = Text(parent, "", 20, -530, "GameFontHighlightSmall")
    Button(parent, "Apply Now", 430, -520, 150, Apply)
    refreshers[#refreshers + 1] = function()
        status:SetText(dirty and "Changes saved. HUD will update after combat."
            or "Changes are saved in the selected profile.")
    end
end

local function Panel(name)
    local frame = CreateFrame("Frame")
    frame:SetSize(720, 560)
    Text(frame, name, 20, -20, "GameFontNormalLarge")
    frame:SetScript("OnShow", RefreshAll)
    panels[#panels + 1] = frame
    ApplyFooter(frame)
    return frame
end

local function SizeInput(parent, label, key, minimum, maximum, x, y)
    Text(parent, label, x, y - 5, "GameFontHighlight")
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetSize(55, 24)
    edit:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 150, y)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(3)
    edit:SetNumeric(true)
    edit:SetText(tostring((Profile() and Profile()[key]) or NUMERIC_DEFAULTS[key]))
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    local function Commit()
        local value = tonumber(edit:GetText())
        if value then
            value = math.max(minimum, math.min(maximum, math.floor(value)))
            if Profile()[key] ~= value then
                Profile()[key] = value
                MarkChanged()
            end
        end
        edit:SetText(tostring(Profile()[key] or NUMERIC_DEFAULTS[key]))
        edit:ClearFocus()
    end
    edit:SetScript("OnEnterPressed", Commit)
    edit:SetScript("OnEditFocusLost", Commit)
    refreshers[#refreshers + 1] = function()
        if not edit:HasFocus() then
            edit:SetText(tostring((Profile() and Profile()[key]) or NUMERIC_DEFAULTS[key]))
        end
    end
    Text(parent, minimum .. "-" .. maximum .. " px", x + 220, y - 5, "GameFontHighlightSmall")
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
        corruption = 6222, bane = 1014, curse = 440982, drain = 1120, immolate = 348,
        fear = 5782, armor = 706, wellfed = 19705, soulsiphon = 17804,
        fort = 1243, motw = 1126, int = 1459,
        spirit = 14752, kings = 20217, salv = 1038,
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
    return C_Spell and C_Spell.GetSpellTexture(spellIDs[key])
end

local function OrderSection(parent, title, orderKey, defaults, y)
    Text(parent, title, 20, y, "GameFontNormal")
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetSize(#defaults * 78, 50)
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
            GameTooltip:AddLine("Drag to change order", 1, 1, 1)
            GameTooltip:Show()
        end)
        tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tile:SetScript("OnDragStart", function(self)
            self:StartMoving()
            self:SetFrameStrata("DIALOG")
            GameTooltip:Hide()
        end)
        tile:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            self:SetFrameStrata("MEDIUM")
            local cursorX, cursorY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            cursorX, cursorY = cursorX / scale, cursorY / scale
            local left, bottom, top = strip:GetLeft(), strip:GetBottom(), strip:GetTop()
            if left and bottom and top and cursorY >= bottom - 20 and cursorY <= top + 20 then
                local destination = math.max(1, math.min(#defaults,
                    math.floor((cursorX - left) / 78) + 1))
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
            tile.frame:SetPoint("TOPLEFT", strip, "TOPLEFT", (index - 1) * 78, 0)
            tile.frame.icon:SetTexture(IconForKey(key) or "Interface\\Icons\\INV_Misc_QuestionMark")
            tile.frame.icon:SetDesaturated(Profile().enabled[key] == false)
            tile.frame:SetAlpha(Profile().enabled[key] == false and 0.5 or 1)
            tile.label:SetText(DisplayName(key))
            tile.check:SetChecked(Profile().enabled[key] ~= false)
        end
    end
end

local layout = Panel("Warlock HUD - Layout")
Text(layout, "Move rows in Edit Mode. Drag icons here to reorder; use the checks to show or hide them.",
    20, -50, "GameFontHighlightSmall")
SizeInput(layout, "Main icon size", "mainSize", 16, 96, 20, -78)
SizeInput(layout, "Second row size", "cooldownSize", 16, 64, 20, -110)
OrderSection(layout, "Main row", "mainOrder", api.MainKeys, -150)
OrderSection(layout, "Second row", "cooldownOrder", api.CooldownKeys, -320)
Check(layout, 20, -475, "20% marker on attackable nameplates",
    function() return Profile().enabled.executeMarker ~= false end,
    function(value)
        if value then
            Profile().enabled.executeMarker = nil
        else
            Profile().enabled.executeMarker = false
        end
    end)

local buffLayout = Panel("Warlock HUD - Buff Row")
Text(buffLayout, "Move the third row in Edit Mode. Drag icons to reorder; use the checks to show or hide them.",
    20, -50, "GameFontHighlightSmall")
SizeInput(buffLayout, "Buff icon size", "buffSize", 16, 64, 20, -85)
OrderSection(buffLayout, "Player buffs", "buffOrder", api.BuffKeys, -145)
Text(buffLayout, "Fortitude, Wild, Intellect, and Spirit include their group versions.",
    20, -285, "GameFontHighlightSmall")
Text(buffLayout, "Kings and Salvation include Greater Blessings.",
    20, -305, "GameFontHighlightSmall")
Text(buffLayout, "Demon Armor / Skin and Well Fed glow when missing.",
    20, -325, "GameFontHighlightSmall")
Text(buffLayout, "Missing group buffs pulse red when your group has the matching class.",
    20, -345, "GameFontHighlightSmall")

local procLayout = Panel("Warlock HUD - Proc Row")
Text(procLayout, "Move the fourth row in Edit Mode. Its icons appear only while a proc is active.",
    20, -50, "GameFontHighlightSmall")
SizeInput(procLayout, "Proc icon size", "procSize", 20, 64, 20, -85)
OrderSection(procLayout, "Procs", "procOrder", api.ProcKeys, -145)
Text(procLayout, "Power Infusion and Nightfall (Shadow Trance) pulse with a countdown.",
    20, -285, "GameFontHighlightSmall")

local spells = Panel("Warlock HUD - Spells")
Text(spells, "Select which auras can appear in their icon slots.",
    20, -50, "GameFontHighlightSmall")
for i, spell in ipairs(api.Spells) do
    local y = -78 - (i - 1) * 31
    Check(spells, 20, y, spell.name,
        function() return Profile().enabled[spell.name] ~= false end,
        function(value)
            if value then
                Profile().enabled[spell.name] = nil
            else
                Profile().enabled[spell.name] = false
            end
        end)
end

local profiles = Panel("Warlock HUD - Profiles")
Text(profiles, "Profiles keep row sizes, order, visibility, and Edit Mode positions together.",
    20, -55, "GameFontHighlightSmall")
Text(profiles, "Current profile", 20, -95, "GameFontHighlight")
local selector = CreateFrame("Frame", "WarlockHudProfileSelector", profiles, "UIDropDownMenuTemplate")
selector:SetPoint("TOPLEFT", profiles, "TOPLEFT", 150, -82)
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

Text(profiles, "Profile name", 20, -145, "GameFontHighlight")
local nameInput = CreateFrame("EditBox", nil, profiles, "InputBoxTemplate")
nameInput:SetSize(180, 24)
nameInput:SetPoint("TOPLEFT", profiles, "TOPLEFT", 150, -137)
nameInput:SetAutoFocus(false)
nameInput:SetMaxLetters(40)
local suggestedName = ((api.GetDB() and api.GetDB().activeProfile) or "Default") .. " Copy"
nameInput:SetText(suggestedName)
nameInput:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
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

Button(profiles, "Create Copy", 20, -185, 120, function()
    local name = EnteredName()
    if name == "" or api.GetDB().profiles[name] then
        print("|cffff7a7aWarlock HUD:|r Enter a new profile name.")
        return
    end
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

Button(profiles, "Rename", 148, -185, 100, function()
    local name = EnteredName()
    local db = api.GetDB()
    if name == "" or db.profiles[name] then
        print("|cffff7a7aWarlock HUD:|r Enter an unused profile name.")
        return
    end
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

Button(profiles, "Delete Current", 256, -185, 125, function()
    local db = api.GetDB()
    local count = 0
    for _ in pairs(db.profiles) do count = count + 1 end
    if count <= 1 then
        print("|cffff7a7aWarlock HUD:|r Keep at least one profile.")
        return
    end
    if type(db.specProfiles) == "table" then
        for group = 1, 2 do
            if db.specProfiles[group] == db.activeProfile then db.specProfiles[group] = nil end
        end
    end
    db.profiles[db.activeProfile] = nil
    db.activeProfile = db.profiles.Default and "Default" or next(db.profiles)
    api.InitializeProfiles()
    MarkChanged()
end)

Check(profiles, 20, -235, "Switch profiles with dual spec",
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

SpecProfileSelector(1, "Primary spec", -280)
SpecProfileSelector(2, "Secondary spec", -325)
Text(profiles, "Create a copy above, then assign it to the other spec.",
    20, -380, "GameFontHighlightSmall")

local notifications = Panel("Warlock HUD - Notifications")
Text(notifications, "Choose which Warlock actions show a chat notification.",
    20, -55, "GameFontHighlightSmall")
local notificationChoices = {
    { "notifySummon", "Ritual of Summoning", -90 },
    { "notifySoulstone", "Soulstone cast on a player", -125 },
    { "notifyHealthstone", "Healthstone trade accepted", -160 },
}
for _, choice in ipairs(notificationChoices) do
    local key = choice[1]
    Check(notifications, 20, choice[3], choice[2],
        function() return Profile().enabled[key] ~= false end,
        function(value)
            if value then Profile().enabled[key] = nil
            else Profile().enabled[key] = false end
        end)
end
Check(notifications, 20, -210, "Send notifications to party or raid chat when grouped",
    function() return Profile().notificationChannel == "GROUP" end,
    function(value) Profile().notificationChannel = value and "GROUP" or "SELF" end)
Text(notifications, "With this off, summon and trade notices appear only in your chat window.",
    48, -245, "GameFontHighlightSmall")
Text(notifications, "Soulstone announcements go to party, raid, or instance chat when grouped.",
    20, -275, "GameFontHighlightSmall")

local shards = Panel("Warlock HUD - Soul Shards")
Text(shards, "Move the shard icon in Edit Mode; it snaps to the grid.",
    20, -55, "GameFontHighlightSmall")
Check(shards, 20, -85, "Show Soul Shards icon",
    function() return Profile().enabled.soulshards ~= false end,
    function(value) Profile().enabled.soulshards = value and nil or false end)
SizeInput(shards, "Shard icon size", "shardSize", 16, 64, 20, -125)
Text(shards, "Minimum shards to keep", 20, -175, "GameFontHighlight")
local shardEdit = CreateFrame("EditBox", nil, shards, "InputBoxTemplate")
shardEdit:SetSize(55, 24)
shardEdit:SetPoint("TOPLEFT", shards, "TOPLEFT", 260, -170)
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
            MarkChanged()
        end
    end
    shardEdit:SetText(tostring(Profile().shardKeepCount or 8))
    shardEdit:ClearFocus()
end
shardEdit:SetScript("OnEnterPressed", CommitShardReserve)
shardEdit:SetScript("OnEditFocusLost", CommitShardReserve)
Button(shards, "Use default 8", 335, -170, 125, function()
    if Profile().shardKeepCount ~= 8 then
        Profile().shardKeepCount = 8
        MarkChanged()
    end
end)
Text(shards, "Each click destroys one shard from your backpack or a regular bag.",
    20, -255, "GameFontHighlight")
Text(shards, "Stops when regular bags are clear or the minimum remains. Unavailable in combat.",
    20, -285, "GameFontHighlightSmall")
refreshers[#refreshers + 1] = function()
    if not shardEdit:HasFocus() then
        shardEdit:SetText(tostring((Profile() and Profile().shardKeepCount) or 8))
    end
end

local about = Panel("Warlock HUD - About")
local version = C_AddOns and C_AddOns.GetAddOnMetadata
    and C_AddOns.GetAddOnMetadata("Warlock_Hud", "Version") or "unknown"
Text(about, "Warlock HUD v" .. version, 20, -65, "GameFontNormalLarge")
Text(about, "A movable, configurable HUD for Warlock spells, buffs, procs, and cooldowns.",
    20, -105, "GameFontHighlight")
Text(about, "Use /whub or /whud to open settings. Drag rows in Edit Mode.",
    20, -145, "GameFontHighlight")
Text(about, "Profiles save each row's size, order, visibility, and position.",
    20, -180, "GameFontHighlight")
Text(about, "The separate Soul Shards icon shows your bag count and clears regular bags.",
    20, -215, "GameFontHighlight")
Text(about, "Soul Siphon is a passive talent indicator in the second row.",
    20, -250, "GameFontHighlight")
Text(about, "Notifications are configured on the Notifications page.",
    20, -285, "GameFontHighlight")

local category
local registration = CreateFrame("Frame")
registration:RegisterEvent("PLAYER_LOGIN")
registration:RegisterEvent("PLAYER_REGEN_ENABLED")
registration:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if dirty and api.Rebuild() then
            dirty = false
            RefreshAll()
        end
        return
    end
    api.InitializeProfiles()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then
        print("|cffff7a7aWarlock HUD:|r AddOn settings are unavailable on this client.")
        return
    end
    category = Settings.RegisterCanvasLayoutCategory(layout, "Warlock HUD")
    Settings.RegisterAddOnCategory(category)
    Settings.RegisterCanvasLayoutSubcategory(category, spells, "Tracked Spells")
    Settings.RegisterCanvasLayoutSubcategory(category, buffLayout, "Buff Row")
    Settings.RegisterCanvasLayoutSubcategory(category, procLayout, "Proc Row")
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
