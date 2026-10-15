local api = WarlockHudAPI
local panels = {}
local refreshers = {}
local dirty = false
local NUMERIC_DEFAULTS = {
    mainSize = 48, cooldownSize = 24, buffSize = 24,
    procSize = 32, consumeSize = 24, shardSize = 32,
}

local LABELS = {
    corruption = "Corruption", bane = "Banes", curse = "Curses", drain = "Drains",
    immolate = "Immolate", siphonlife = "Siphon Life", demonicbrand = "Demonic Brand",
    healthstone = "Healthstone", soulstone = "Soulstone", fear = "Fear",
    conflagrate = "Conflagrate",
    demon = "Missing Demon Reminder", sacrifice = "Demonic Sacrifice",
    soullink = "Soul Link",
    soulshards = "Soul Shards",
    armor = "Armor / Skin", wellfed = "Well Fed",
    flask = "Flask", spelldamage = "Spell Damage Elixir",
    shadow = "Shadow Damage Elixir", fire = "Fire Damage Elixir",
    wizardoil = "Wizard Oil", manaregen = "Mana Regeneration",
    racial1 = "Racial ability 1", racial2 = "Racial ability 2",
    fort = "Fortitude", motw = "Mark of the Wild", int = "Intellect",
    spirit = "Spirit", kings = "Kings", salv = "Salvation",
    thorns = "Thorns", breath = "Unending Breath",
    powerinfusion = "Power Infusion", nightfall = "Nightfall",
}
local TILE_LABELS = { motw = "Wild", breath = "Breath",
    spelldamage = "Spell Dmg", shadow = "Shadow", fire = "Fire",
    wizardoil = "Oil", manaregen = "Mana" }

local ICON_HELP = {
    corruption = "Target DoT. Shows its active aura countdown.",
    immolate = "Target DoT. Shows its active aura countdown.",
    bane = "Banes share one Target DoTs icon slot. Choose its idle image on Tracked Auras.",
    curse = "Curses share one Target DoTs icon slot. Choose its idle image on Tracked Auras.",
    drain = "Drains share one Target DoTs icon slot. Choose its idle image on Tracked Auras.",
    siphonlife = "Siphon Life appears when talented and tracks its target DoT.",
    demonicbrand = "Tracks the Demonic Brand target effect when talented. Blizzard renders its duration; remaining attack counts need in-game verification.",
    healthstone = "Shows your Healthstone and its item cooldown.",
    soulstone = "Shows your Soulstone and its item cooldown.",
    fear = "Shows Fear in the Utility row when available.",
    conflagrate = "Shows Conflagrate and its cooldown when learned. The icon pulses when your Immolate is active on the current target.",
    demon = "Flash a warning when no demon is summoned and no active Demonic Sacrifice is detected.",
    sacrifice = "Shows an active Demonic Sacrifice effect with its native duration.",
    soullink = "Remind you when Soul Link is known, a demon is summoned, and the buff is confirmed missing.",
    racial1 = "Shows an available racial ability and its cooldown.",
    racial2 = "Shows a second racial ability when available.",
    armor = "Demon Armor or Demon Skin. Glows when missing.",
    wellfed = "Well Fed. Glows when missing.",
    flask = "Flask of Supreme Power effect. Native aura countdown.",
    spelldamage = "Lesser, regular, or Greater Arcane Elixir effect. Native aura countdown.",
    shadow = "Shadow Power elixir effect. Native aura countdown.",
    fire = "Fire Power or Greater Firepower elixir effect. Native aura countdown.",
    wizardoil = "Wizard Oil family on your main-hand weapon. No HUD timer; status is unknown during protected aura states.",
    manaregen = "Mageblood family effects, including Mana Regeneration. Native aura countdown.",
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
    if not Profile() then api.InitializeProfiles() end
    if not Profile() then return end
    for _, refresh in ipairs(refreshers) do refresh() end
end

local function MarkChanged(needsRebuild)
    if needsRebuild ~= false then
        dirty = true
        if api.Rebuild() then dirty = false end
    end
    if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
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
    if api.GetDotDefaultSpell then
        local selected = api.GetDotDefaultSpell(key)
        if selected and C_Spell and C_Spell.GetSpellTexture then
            local texture = C_Spell.GetSpellTexture(selected.ids[1])
            if texture then return texture end
        end
    end
    local spellIDs = {
        fear = 5782, conflagrate = 1293817,
        armor = 706, wellfed = 19705, flask = 17628,
        spelldamage = 16889, shadow = 11474, fire = 26276,
        manaregen = 24363,
        demon = 5500, sacrifice = 18788, soullink = 19028,
        fort = 1243, motw = 1126, int = 1459,
        spirit = 14752, kings = 20217, salv = 1038,
        thorns = 467, breath = 5697,
        powerinfusion = 10060, nightfall = 17941,
    }
    if key == "wizardoil" then
        return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(20749)
    end
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
    local spellID = WarlockHudEffects.PreviewSpellIDs[key] or spellIDs[key]
    return spellID and C_Spell and C_Spell.GetSpellTexture(spellID)
end

local iconDemo
local function ShowIconDemo()
    if iconDemo and iconDemo:IsShown() then
        iconDemo:Hide()
        RefreshAll()
        return
    end
    if not CanRebuild() then
        print("|cffff7a7aWarlock HUD:|r Start the HUD demo after combat.")
        return
    end
    local anchors = api.GetDemoAnchors and api.GetDemoAnchors()
    if not anchors then
        print("|cffff7a7aWarlock HUD:|r Enable Warlock HUD to preview its bars on screen.")
        return
    end
    if iconDemo and iconDemo:GetParent() ~= anchors.root then iconDemo = nil end
    if not iconDemo then
        local demo = CreateFrame("Frame", nil, anchors.root)
        demo:SetAllPoints(UIParent)
        demo:SetFrameStrata("DIALOG")
        local close = Button(demo, "End HUD demo", 0, 0, 140, function()
            demo:Hide()
            RefreshAll()
        end)
        close:ClearAllPoints()
        close:SetPoint("TOP", UIParent, "TOP", 0, -45)

        local function DemoRow(title, keys, orderKey, sizeKey, anchor)
            local order = orderKey and Profile()[orderKey] or keys
            local size = Profile()[sizeKey]
            local width = #order * size + math.max(0, #order - 1) * 4 + 8
            local row = CreateFrame("Frame", nil, demo)
            row:SetSize(width, size + 8)
            if orderKey == "buffOrder" or orderKey == "consumeOrder" then
                row:SetPoint("LEFT", anchor, "LEFT", -4, 0)
            else
                row:SetPoint("CENTER", anchor, "CENTER")
            end
            local background = row:CreateTexture(nil, "BACKGROUND")
            background:SetAllPoints(row)
            background:SetColorTexture(0, 0, 0, 0.9)
            local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            rowLabel:SetSize(95, 18)
            local rowLeft = (orderKey == "buffOrder" or orderKey == "consumeOrder")
                and anchor:GetLeft()
                or (anchor:GetCenter() or 0) - width / 2
            if rowLeft < 110 then
                rowLabel:SetPoint("LEFT", row, "RIGHT", 6, 0)
                rowLabel:SetJustifyH("LEFT")
            else
                rowLabel:SetPoint("RIGHT", row, "LEFT", -6, 0)
                rowLabel:SetJustifyH("RIGHT")
            end
            rowLabel:SetText(title)
            for index = 1, #order do
                local key = order[index]
                local button = CreateFrame("Button", nil, row)
                button:SetSize(size, size)
                button:SetPoint("CENTER", row, "CENTER",
                    (index - (#order + 1) / 2) * (size + 4), 0)
                local icon = button:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints(button)
                icon:SetTexture(IconForKey(key) or "Interface\\Icons\\INV_Misc_QuestionMark")
                icon:SetTexCoord(0.115, 0.885, 0.115, 0.885)
                button:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(DisplayName(key))
                    if ICON_HELP[key] then
                        GameTooltip:AddLine(ICON_HELP[key], 1, 1, 1, true)
                    end
                    GameTooltip:Show()
                end)
                button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
        end

        DemoRow("Target DoTs", api.MainKeys, "mainOrder", "mainSize", anchors.main)
        DemoRow("Utility", api.CooldownKeys, "cooldownOrder", "cooldownSize", anchors.utility)
        DemoRow("Consumes", api.ConsumeKeys, "consumeOrder", "consumeSize", anchors.consumes)
        DemoRow("Buffs", api.BuffKeys, "buffOrder", "buffSize", anchors.buffs)
        DemoRow("Procs", api.ProcKeys, "procOrder", "procSize", anchors.procs)
        local shardAnchor = anchors.shards
        if not shardAnchor then
            shardAnchor = CreateFrame("Frame", nil, demo)
            shardAnchor:SetSize(Profile().shardSize, Profile().shardSize)
            if type(Profile().shardX) == "number" and type(Profile().shardY) == "number" then
                shardAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
                    Profile().shardX * UIParent:GetWidth(),
                    Profile().shardY * UIParent:GetHeight())
            elseif PlayerFrame then
                shardAnchor:SetPoint("RIGHT", PlayerFrame, "TOPLEFT", -8, -44)
            else
                shardAnchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 100, 210)
            end
        end
        DemoRow("Soul Shards", { "soulshards" }, nil, "shardSize", shardAnchor)
        demo:Hide()
        iconDemo = demo
    end
    iconDemo:Show()
    RefreshAll()
end

local function OrderSection(parent, title, orderKey, defaults, y, columns, onReset)
    Text(parent, title, 20, y, "GameFontNormal")
    if onReset then
        local reset = Button(parent, "Reset Row", 480, y + 8, 100, onReset)
        reset:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title)
            GameTooltip:AddLine(orderKey == "consumeOrder"
                and "Restores size, order, tracked icons, colors, and reminders. Edit Mode position stays."
                or "Restores icon size, order, and visibility. Edit Mode position stays.",
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
                Profile().enabled[key] = orderKey == "consumeOrder"
                    and key ~= "wellfed" and true or nil
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
local general = Panel("Warlock HUD - General", false)
local multiDotPanel = Panel("Warlock HUD - Multi-Target DoTs", false)
WarlockHudOptionsMultiTarget.Build({
    multiDotPanel = multiDotPanel,
    Text = Text,
    Check = Check,
    Button = Button,
    Profile = Profile,
    refreshers = refreshers,
})
WarlockHudOptionsGeneral.Build({
    api = api,
    general = general,
    Text = Text,
    Check = Check,
    Button = Button,
    Profile = Profile,
    ShowIconDemo = ShowIconDemo,
    IsDemoShown = function() return iconDemo and iconDemo:IsShown() end,
    refreshers = refreshers,
})
WarlockHudOptionsRows.BuildLayout({
    api = api,
    layout = layout,
    Text = Text,
    Check = Check,
    SizeSlider = SizeSlider,
    OrderSection = OrderSection,
    ResetRowValues = ResetRowValues,
    ResetPageButton = ResetPageButton,
    DefaultProfile = DefaultProfile,
    Profile = Profile,
    MarkChanged = MarkChanged,
})

local consumeLayout = WarlockHudOptionsRows.BuildConsumes({
    api = api,
    Panel = Panel,
    Text = Text,
    Check = Check,
    SizeSlider = SizeSlider,
    OrderSection = OrderSection,
    ResetRowValues = ResetRowValues,
    ResetPageButton = ResetPageButton,
    DefaultProfile = DefaultProfile,
    Profile = Profile,
    MarkChanged = MarkChanged,
})

local buffLayout = WarlockHudOptionsRows.BuildBuffs({
    api = api,
    Panel = Panel,
    Text = Text,
    Check = Check,
    SizeSlider = SizeSlider,
    OrderSection = OrderSection,
    ResetRowValues = ResetRowValues,
    DefaultProfile = DefaultProfile,
    Profile = Profile,
    MarkChanged = MarkChanged,
})

local procLayout = WarlockHudOptionsRows.BuildProcs({
    api = api,
    Panel = Panel,
    Text = Text,
    SizeSlider = SizeSlider,
    OrderSection = OrderSection,
    ResetRowValues = ResetRowValues,
    DefaultProfile = DefaultProfile,
    MarkChanged = MarkChanged,
})

local spells = WarlockHudOptionsTrackedAuras.Build({
    api = api,
    Panel = Panel,
    Text = Text,
    Check = Check,
    Button = Button,
    ResetPageButton = ResetPageButton,
    Profile = Profile,
    MarkChanged = MarkChanged,
    refreshers = refreshers,
})

local profiles = WarlockHudOptionsProfiles.Build({
    api = api,
    Panel = Panel,
    Text = Text,
    Check = Check,
    Button = Button,
    Profile = Profile,
    MarkChanged = MarkChanged,
    refreshers = refreshers,
})

local sharingPanel = Panel("Warlock HUD - Share Settings")
Text(sharingPanel, "Choose sections, then export. Paste a code to preview it before importing.",
    20, -50, "GameFontHighlightSmall")
local share = WarlockHudSharing
local labels = {
    bars = "Bars and tracked icons", positions = "Edit Mode locations",
    notifications = "Notifications", summons = "Summons",
    stones = "Stone options", shards = "Soul Shards",
}
local selected = {}
for index, section in ipairs(share.Sections) do
    selected[section] = true
    local x = index <= 3 and 20 or 335
    local y = -80 - ((index - 1) % 3) * 31
    local check = CreateFrame("CheckButton", nil, sharingPanel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", sharingPanel, "TOPLEFT", x, y)
    check:SetChecked(true)
    Text(sharingPanel, labels[section], x + 28, y - 5, "GameFontHighlight")
    check:SetScript("OnClick", function(self) selected[section] = self:GetChecked() and true or false end)
end
local allProfiles = false
local allCheck = CreateFrame("CheckButton", nil, sharingPanel, "UICheckButtonTemplate")
allCheck:SetPoint("TOPLEFT", sharingPanel, "TOPLEFT", 20, -182)
Text(sharingPanel, "All profiles (import creates new profiles)", 48, -187, "GameFontHighlight")
allCheck:SetScript("OnClick", function(self) allProfiles = self:GetChecked() and true or false end)
Text(sharingPanel, "Import current merges selected sections into the active profile.",
    20, -213, "GameFontHighlightSmall")
Text(sharingPanel, "Import all creates new profiles; existing profiles are never overwritten.",
    20, -230, "GameFontHighlightSmall")
Text(sharingPanel, "Share code", 20, -257, "GameFontNormal")
local shareArea = CreateFrame("Frame", nil, sharingPanel)
shareArea:SetPoint("TOPLEFT", sharingPanel, "TOPLEFT", 20, -278)
shareArea:SetSize(575, 158)
local shareBackground = shareArea:CreateTexture(nil, "BACKGROUND")
shareBackground:SetAllPoints()
shareBackground:SetColorTexture(0.04, 0.04, 0.06, 0.85)
for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local border = shareArea:CreateTexture(nil, "BORDER")
    border:SetColorTexture(0.45, 0.45, 0.45, 0.7)
    if edge == "TOP" or edge == "BOTTOM" then
        border:SetHeight(1)
        border:SetPoint(edge .. "LEFT", shareArea, edge .. "LEFT")
        border:SetPoint(edge .. "RIGHT", shareArea, edge .. "RIGHT")
    else
        border:SetWidth(1)
        border:SetPoint("TOP" .. edge, shareArea, "TOP" .. edge)
        border:SetPoint("BOTTOM" .. edge, shareArea, "BOTTOM" .. edge)
    end
end
local shareScroll = CreateFrame("ScrollFrame", nil, shareArea, "UIPanelScrollFrameTemplate")
shareScroll:SetPoint("TOPLEFT", shareArea, "TOPLEFT", 8, -7)
shareScroll:SetSize(540, 144)
local shareInput = CreateFrame("EditBox", nil, shareScroll)
shareInput:SetMultiLine(true)
shareInput:SetAutoFocus(false)
shareInput:SetMaxLetters(60000)
shareInput:SetSize(530, 144)
shareInput:SetFontObject("ChatFontNormal")
shareInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
local shareMeasure = shareInput:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
shareMeasure:SetWidth(530)
shareInput:SetScript("OnTextChanged", function(self)
    shareMeasure:SetText(self:GetText())
    self:SetHeight(math.max(144, shareMeasure:GetStringHeight() + 20))
end)
shareScroll:SetScrollChild(shareInput)
local shareStatus = Text(sharingPanel, "", 20, -485, "GameFontHighlightSmall")
shareStatus:SetWidth(570)
shareStatus:SetJustifyH("LEFT")
local function SetShareStatus(message, good)
    shareStatus:SetText(message)
    shareStatus:SetTextColor(good and 0.4 or 1, good and 1 or 0.5, 0.4)
end
Button(sharingPanel, "Export", 20, -448, 105, function()
    local any
    for _, section in ipairs(share.Sections) do
        if selected[section] then any = true; break end
    end
    if not any then SetShareStatus("Select at least one section to export.", false); return end
    local code = share.Export(selected, allProfiles)
    shareInput:SetText(code)
    shareInput:SetFocus()
    shareInput:HighlightText()
    SetShareStatus("Export ready. Press Ctrl+C to copy the selected code.", true)
end)
Button(sharingPanel, "Preview Import", 135, -448, 125, function()
    local parsed, reason = share.Decode(shareInput:GetText())
    if not parsed then SetShareStatus(reason, false); return end
    local count, included = 0, {}
    for _ in pairs(parsed.profiles) do count = count + 1 end
    for _, section in ipairs(share.Sections) do
        if parsed.available[section] then included[#included + 1] = labels[section] end
    end
    SetShareStatus("Code v" .. parsed.version .. "; " .. count .. " profile(s). Available: "
        .. table.concat(included, ", ") .. ".", true)
end)
StaticPopupDialogs.WARLOCKHUD_CONFIRM_IMPORT = {
    text = "Import from addon version %s?\n%s\nSelected settings save immediately. The HUD refreshes when safe.",
    button1 = "Import Settings",
    button2 = CANCEL,
    OnAccept = function(_, request)
        if not request then return end
        if not request.allProfiles and api.GetDB().activeProfile ~= request.profileName then
            SetShareStatus("Active profile changed. Review the import again.", false)
            return
        end
        local imported, result = share.Import(request.parsed, request.selected, request.allProfiles)
        if not imported then SetShareStatus(result, false); return end
        MarkChanged()
        SetShareStatus(result .. " Saved now; HUD refreshes when safe.", true)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
Button(sharingPanel, "Import Selected", 270, -448, 125, function()
    local parsed, reason = share.Decode(shareInput:GetText())
    if not parsed then SetShareStatus(reason, false); return end
    local chosen, snapshot = {}, {}
    for _, section in ipairs(share.Sections) do
        snapshot[section] = selected[section]
        if selected[section] and parsed.available[section] then
            chosen[#chosen + 1] = labels[section]
        end
    end
    if #chosen == 0 then
        SetShareStatus("Select at least one section available in the code.", false)
        return
    end
    local profileName = api.GetDB().activeProfile
    local destination = allProfiles and "Create new profiles" or
        ("Merge into current profile: " .. profileName)
    StaticPopup_Show("WARLOCKHUD_CONFIRM_IMPORT", parsed.version,
        destination .. "\nSections: " .. table.concat(chosen, ", "),
        { parsed = parsed, selected = snapshot, allProfiles = allProfiles,
            profileName = profileName })
end)
Button(sharingPanel, "Clear", 405, -448, 90, function()
    shareInput:SetText("")
    shareInput:ClearFocus()
    shareScroll:SetVerticalScroll(0)
    SetShareStatus("Share code cleared.", true)
end)
local notifications = Panel("Warlock HUD - Notifications")
Text(notifications, "Choose which Warlock actions show a chat notification.",
    20, -50, "GameFontHighlightSmall")
Text(notifications, "Announcements", 20, -85, "GameFontNormal")
local notificationChoices = {
    { "notifySummon", "Ritual of Summoning", -115 },
    { "notifySoulstone", "Soulstone cast on a player", -180 },
    { "notifyHealthstone", "Healthstone trade completed", -245 },
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
Text(notifications, "Example: Healthstone trade completed with Player.",
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

local summons = Panel("Warlock HUD - Summons", false)
Text(summons, "Summon Request Queue", 20, -55, "GameFontNormal")
Text(summons, "Request keywords", 20, -92, "GameFontHighlight")
local summonKeywordInput = CreateFrame("EditBox", nil, summons, "InputBoxTemplate")
summonKeywordInput:SetSize(300, 24)
summonKeywordInput:SetPoint("TOPLEFT", summons, "TOPLEFT", 175, -82)
summonKeywordInput:SetAutoFocus(false)
summonKeywordInput:SetMaxLetters(142)
summonKeywordInput:SetFontObject(ChatFontNormal)
local summonKeywordDisplay = summonKeywordInput:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
summonKeywordDisplay:SetPoint("LEFT", summonKeywordInput, "LEFT", 6, 0)
summonKeywordDisplay:SetWidth(286)
summonKeywordDisplay:SetJustifyH("LEFT")
summonKeywordDisplay:SetText(api.DefaultSummonKeywords)
Text(summons, "Default: 123, sum, summ", 175, -116,
    "GameFontHighlightSmall")
local summonKeywordHint = Text(summons,
    "Separate with commas. Up to 8 words, 1-16 letters or digits each. Exact message match.",
    20, -140, "GameFontHighlightSmall")
summonKeywordHint:SetWidth(650)
summonKeywordHint:SetJustifyH("LEFT")
local function SaveSummonKeyword(self)
    local value = api.NormalizeSummonKeywords(self:GetText())
    if value then
        if Profile().summonKeywords ~= value then
            Profile().summonKeywords = value
            MarkChanged(false)
        end
    else
        print("|cffff7a7aWarlock HUD:|r Enter 1-8 comma-separated words, each 1-16 letters or digits.")
    end
end
local function RefreshSummonKeywordInput()
    local profile = Profile()
    local keyword = profile and profile.summonKeywords
    if type(keyword) ~= "string" or keyword == "" then
        keyword = api.DefaultSummonKeywords
        if profile then profile.summonKeywords = keyword end
    end
    if not summonKeywordInput:HasFocus() then
        summonKeywordInput:SetText("")
        summonKeywordDisplay:SetText(keyword)
        summonKeywordDisplay:Show()
    end
end
local editingSummonKeyword = false
summonKeywordInput:SetScript("OnEditFocusGained", function(self)
    editingSummonKeyword = true
    summonKeywordDisplay:Hide()
    self:SetText(Profile() and Profile().summonKeywords
        or api.DefaultSummonKeywords)
    self:HighlightText()
end)
summonKeywordInput:SetScript("OnEnterPressed", function(self)
    SaveSummonKeyword(self)
    editingSummonKeyword = false
    self:ClearFocus()
    RefreshSummonKeywordInput()
end)
summonKeywordInput:SetScript("OnEscapePressed", function(self)
    editingSummonKeyword = false
    self:ClearFocus()
    RefreshSummonKeywordInput()
end)
summonKeywordInput:SetScript("OnEditFocusLost", function(self)
    if editingSummonKeyword then SaveSummonKeyword(self) end
    editingSummonKeyword = false
    RefreshSummonKeywordInput()
end)
refreshers[#refreshers + 1] = function()
    RefreshSummonKeywordInput()
end
summons:HookScript("OnShow", function()
    RefreshSummonKeywordInput()
end)
Text(summons, "Open the queue with /whub summonqueue. Announce lists these words.",
    20, -163, "GameFontHighlightSmall")
Button(summons, "Open Summon Queue", 20, -199, 180, function()
    if WarlockHudOpenSummonQueue then WarlockHudOpenSummonQueue() end
end)
Button(summons, "Preview 15 requests", 215, -199, 180, function()
    if WarlockHudOpenSummonQueueDemo then WarlockHudOpenSummonQueueDemo() end
end)
Text(summons, "Demo uses sample names; its buttons do not cast or announce.",
    20, -229, "GameFontHighlightSmall")
Check(summons, 20, -250, "Enable summon request queue",
    function() return Profile().summonQueueEnabled ~= false end,
    function(value)
        Profile().summonQueueEnabled = value
        if not value and WarlockHudClearSummonQueue then
            WarlockHudClearSummonQueue("DISABLED")
        end
    end,
    "When off, new requests are ignored and pending requests are cleared.", false)
Check(summons, 20, -285, "Automatically remove players when nearby",
    function() return Profile().summonAutoRemoveNearby ~= false end,
    function(value) Profile().summonAutoRemoveNearby = value end,
    "Uses a readable group-distance check, or interaction range when permitted. Unavailable results leave requests queued.", false)
Text(summons, "Accepted request sources", 20, -328, "GameFontNormal")
local summonSources = {
    { "PARTY", "Party", -355 },
    { "RAID", "Raid", -390 },
    { "INSTANCE_CHAT", "Instance", -425 },
    { "WHISPER", "Whisper from group members", -460 },
}
for _, source in ipairs(summonSources) do
    local key = source[1]
    Check(summons, 20, source[3], source[2],
        function()
            local sources = Profile().summonSources
            return not sources or sources[key] ~= false
        end,
        function(value)
            Profile().summonSources = Profile().summonSources or {}
            Profile().summonSources[key] = value and nil or false
        end,
        nil, false)
end
ResetPageButton(summons, "Summons", function()
    Profile().summonKeywords = api.DefaultSummonKeywords
    Profile().summonQueueEnabled = true
    Profile().summonAutoRemoveNearby = true
    Profile().summonSources = {}
    MarkChanged(false)
end)

local stones = Panel("Warlock HUD - Stones", false)
Text(stones, "Soulstone", 20, -55, "GameFontNormal")
local soulstoneStatus = Text(stones, "", 330, -55, "GameFontHighlightSmall")
refreshers[#refreshers + 1] = function()
    local status = WarlockHudSoulstoneText and WarlockHudSoulstoneText()
    soulstoneStatus:SetText(status and ("Applied: " .. status) or "")
end
local function Stones()
    local profile = Profile()
    profile.stones = profile.stones or {}
    return profile.stones
end
local function StoneCheck(y, label, key, defaultOn, tooltip)
    Check(stones, 20, y, label,
        function()
            local value = Stones()[key]
            return value == nil and defaultOn or value == true
        end,
        function(value) Stones()[key] = value end,
        tooltip, false)
end
StoneCheck(-80, "Enable Soulstone tracker", "soulstoneTracker", true)
StoneCheck(-115, "Show recipient name", "showSoulstoneName", true)
StoneCheck(-150, "Show estimated countdown", "showSoulstoneCountdown", true,
    "Uses a safe out-of-combat aura observation. It may be stale during combat.")
StoneCheck(-185, "Notify on expiry or uncertain loss", "notifySoulstoneLoss", false)
Text(stones, "Details appear only while the Soulstone aura is confirmed active.",
    48, -223, "GameFontHighlightSmall")
Text(stones, "Healthstones", 20, -260, "GameFontNormal")
StoneCheck(-285, "Track completed Healthstone trades", "distributionTracker", true)
StoneCheck(-320, "Auto-place one Healthstone for group members", "autoPlaceHealthstone", false,
    "Only in an empty trade with a matched group member. You must press Accept yourself.")
StoneCheck(-355, "Notify me after a recorded distribution", "notifyDistribution", false)
Text(stones, "Supplied means a completed trade was recorded; current possession is unknown.",
    48, -395, "GameFontHighlightSmall")
local distributionText = Text(stones, "", 20, -425, "GameFontHighlightSmall")
distributionText:SetWidth(610)
distributionText:SetJustifyH("LEFT")
refreshers[#refreshers + 1] = function()
    distributionText:SetText(WarlockHudDistributionSummary and WarlockHudDistributionSummary()
        or "Distribution list unavailable")
end
Button(stones, "Reset supplied list", 20, -500, 155, function()
    if WarlockHudResetDistribution then WarlockHudResetDistribution() end
    RefreshAll()
end)

local shards = Panel("Warlock HUD - Soul Shards")
Text(shards, "Move the shard icon in Edit Mode; it snaps to the grid.",
    20, -50, "GameFontHighlightSmall")
Text(shards, "Shard icon", 20, -80, "GameFontNormal")
Check(shards, 20, -105, "Show Soul Shards icon",
    function() return Profile().enabled.soulshards ~= false end,
    function(value)
        if value then
            Profile().enabled.soulshards = nil
        else
            Profile().enabled.soulshards = false
        end
    end)
SizeSlider(shards, "Shard icon size", "shardSize", 16, 64, 20, -140)
local function ShardNumberSlider(label, key, y, limits, onChange)
    Text(shards, label, 20, y - 5, "GameFontHighlight")
    local slider = CreateFrame("Slider", nil, shards, "OptionsSliderTemplate")
    slider:SetSize(165, 17)
    slider:SetPoint("TOPLEFT", shards, "TOPLEFT", 245, y - 3)
    slider:SetValueStep(1)
    local valueText = Text(shards, "", 470, y - 5, "GameFontHighlight")
    local function Clamp(value)
        local minimum, maximum = limits()
        return math.max(minimum, math.min(maximum, math.floor(value + 0.5)))
    end
    local function Commit(value)
        value = Clamp(value)
        slider:SetValue(value)
        if Profile()[key] ~= value then
            Profile()[key] = value
            if onChange then onChange() end
            MarkChanged(false)
        end
    end
    slider:SetScript("OnValueChanged", function(_, value)
        valueText:SetText(tostring(Clamp(value)))
    end)
    slider:SetScript("OnMouseUp", function(self) Commit(self:GetValue()) end)
    local minus = Button(shards, "-", 210, y, 24, function()
        Commit(Profile()[key] - 1)
    end)
    local plus = Button(shards, "+", 420, y, 24, function()
        Commit(Profile()[key] + 1)
    end)
    refreshers[#refreshers + 1] = function()
        local minimum, maximum = limits()
        slider:SetMinMaxValues(minimum, maximum)
        local value = Profile()[key]
        slider:SetValue(value)
        valueText:SetText(tostring(value))
        minus:SetEnabled(value > minimum)
        plus:SetEnabled(value < maximum)
    end
end
Text(shards, "Shard reserve", 20, -185, "GameFontNormal")
ShardNumberSlider("Minimum shards to keep", "shardKeepCount", -210,
    function() return 0, 64 end)
Button(shards, "Use default 8", 520, -210, 125, function()
    if Profile().shardKeepCount ~= 8 then
        Profile().shardKeepCount = 8
        MarkChanged(false)
    end
end)
local shardWarning = Text(shards,
    "Clicking the icon permanently destroys one shard from a regular bag.",
    20, -480, "GameFontHighlightSmall")
shardWarning:SetTextColor(1, 0.65, 0.25)
Text(shards, "Deletion stops at your reserve and is unavailable in combat.",
    20, -500, "GameFontHighlightSmall")
Text(shards, "Shard warnings", 20, -265, "GameFontNormal")
local function RefreshShardWarning()
    if api.RefreshShardWarning then api.RefreshShardWarning() end
end
Check(shards, 20, -290, "Enable shard warnings",
    function() return Profile().shardWarningsEnabled end,
    function(value)
        Profile().shardWarningsEnabled = value
        RefreshShardWarning()
    end, nil, false)
ShardNumberSlider("Red at or below", "shardLowThreshold", -330,
    function() return 0, Profile().shardHighThreshold - 1 end, RefreshShardWarning)
ShardNumberSlider("Yellow at or above", "shardHighThreshold", -370,
    function() return Profile().shardLowThreshold + 1, 64 end, RefreshShardWarning)
Check(shards, 20, -410, "Warn when shards overflow the Soul Bag",
    function() return Profile().shardWarnOverflow end,
    function(value)
        Profile().shardWarnOverflow = value
        RefreshShardWarning()
    end,
    "Detects shards in regular bags while a Soul Bag is equipped.", false)
Button(shards, "Use warning defaults", 20, -445, 165, function()
    local defaults = DefaultProfile()
    Profile().shardLowThreshold = defaults.shardLowThreshold
    Profile().shardHighThreshold = defaults.shardHighThreshold
    RefreshShardWarning()
    MarkChanged(false)
end)
ResetPageButton(shards, "Soul Shards", function()
    local defaults = DefaultProfile()
    Profile().enabled.soulshards = nil
    Profile().shardSize = defaults.shardSize
    Profile().shardKeepCount = defaults.shardKeepCount
    Profile().shardWarningsEnabled = defaults.shardWarningsEnabled
    Profile().shardLowThreshold = defaults.shardLowThreshold
    Profile().shardHighThreshold = defaults.shardHighThreshold
    Profile().shardWarnOverflow = defaults.shardWarnOverflow
    RefreshShardWarning()
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
Text(about, "Reset addon", 20, -390, "GameFontNormal")
Text(about, "Deletes all Warlock HUD profiles, settings, and saved character data.",
    20, -415, "GameFontHighlightSmall")
local resetStatus = Text(about, "", 20, -485, "GameFontHighlightSmall")
local resetReload = CreateFrame("Frame")
resetReload:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    ReloadUI()
end)
StaticPopupDialogs.WARLOCKHUD_RESET_ALL = {
    text = "Reset all Warlock HUD data to defaults?\nThis deletes every profile, setting, and saved character record. Export a share code first if you want a backup. The UI will reload.",
    button1 = "Reset Everything",
    button2 = CANCEL,
    OnAccept = function()
        WarlockHudDB = {}
        api.InitializeProfiles()
        if InCombatLockdown() then
            resetStatus:SetText("Reset saved. UI will reload after combat.")
            resetReload:RegisterEvent("PLAYER_REGEN_ENABLED")
        else
            ReloadUI()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
Button(about, "Reset All Data", 20, -445, 140, function()
    StaticPopup_Show("WARLOCKHUD_RESET_ALL")
end)

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
    Settings.RegisterCanvasLayoutSubcategory(category, general, "General")
    Settings.RegisterCanvasLayoutSubcategory(category, multiDotPanel, "Multi-Target DoTs")
    Settings.RegisterCanvasLayoutSubcategory(category, spells, "Tracked Auras")
    Settings.RegisterCanvasLayoutSubcategory(category, consumeLayout, "Consumes")
    Settings.RegisterCanvasLayoutSubcategory(category, buffLayout, "Buffs")
    Settings.RegisterCanvasLayoutSubcategory(category, procLayout, "Procs")
    Settings.RegisterCanvasLayoutSubcategory(category, profiles, "Profiles")
    Settings.RegisterCanvasLayoutSubcategory(category, sharingPanel, "Share Settings")
    Settings.RegisterCanvasLayoutSubcategory(category, notifications, "Notifications")
    Settings.RegisterCanvasLayoutSubcategory(category, summons, "Summons")
    Settings.RegisterCanvasLayoutSubcategory(category, stones, "Stones")
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
