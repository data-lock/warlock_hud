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

local sharingPanel = WarlockHudOptionsSharing.Build({
    api = api,
    Panel = Panel,
    Text = Text,
    Button = Button,
    MarkChanged = MarkChanged,
})

local notifications = WarlockHudOptionsNotifications.Build({
    Panel = Panel,
    Text = Text,
    Check = Check,
    ResetPageButton = ResetPageButton,
    Profile = Profile,
    MarkChanged = MarkChanged,
})

local summons = WarlockHudOptionsSummons.Build({
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

local stones = WarlockHudOptionsStones.Build({
    Panel = Panel,
    Text = Text,
    Check = Check,
    Button = Button,
    Profile = Profile,
    RefreshAll = RefreshAll,
    refreshers = refreshers,
})

local shards = WarlockHudOptionsShards.Build({
    api = api,
    Panel = Panel,
    Text = Text,
    Check = Check,
    Button = Button,
    SizeSlider = SizeSlider,
    ResetPageButton = ResetPageButton,
    Profile = Profile,
    DefaultProfile = DefaultProfile,
    MarkChanged = MarkChanged,
    refreshers = refreshers,
})

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
