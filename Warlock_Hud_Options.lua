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
    banish = "Banish",
    conflagrate = "Conflagrate",
    demon = "Missing Demon Reminder", sacrifice = "Demonic Sacrifice",
    soullink = "Soul Link",
    soulshards = "Soul Shards",
    armor = "Armor / Skin", wellfed = "Well Fed",
    flask = "Flask", spelldamage = "Spell Damage Elixir",
    shadow = "Shadow Damage Elixir", fire = "Fire Damage Elixir",
    wizardoil = "Wizard Oil / Firestone", manaregen = "Mana Regeneration",
    racial1 = "Racial ability 1", racial2 = "Racial ability 2",
    fort = "Fortitude", motw = "Mark of the Wild", int = "Intellect",
    spirit = "Spirit", kings = "Kings", salv = "Salvation",
    thorns = "Thorns", breath = "Unending Breath",
    powerinfusion = "Power Infusion", nightfall = "Nightfall",
}
local TILE_LABELS = { motw = "Wild", breath = "Breath",
    spelldamage = "Spell Dmg", shadow = "Shadow", fire = "Fire",
    wizardoil = "Oil", manaregen = "Mana",
    demonicbrand = "Brand", demon = "Missing Demon" }

local ICON_HELP = {
    corruption = "Target DoT. Shows its active aura countdown.",
    immolate = "Target DoT. Shows its active aura countdown.",
    bane = "Banes share one Target DoTs icon slot. Choose its idle image on Tracked Auras.",
    curse = "Curses share one Target DoTs icon slot. Choose its idle image on Tracked Auras.",
    drain = "Drains share one Target DoTs icon slot. Choose its idle image on Tracked Auras.",
    siphonlife = "Siphon Life appears when talented and tracks its target DoT.",
    demonicbrand = "Tracks the Demonic Brand target effect when talented. Blizzard renders its duration; remaining attack counts need in-game verification.",
    healthstone = "Hidden until Create Healthstone is learned by default. Enable it early to arrange the icon; shows its item cooldown.",
    soulstone = "Hidden until Create Soulstone is learned by default. Enable it early to arrange the icon; shows its item cooldown.",
    soulshards = "Hidden until Drain Soul is learned by default. Enable it early to arrange the icon.",
    fear = "Shows Fear on the current target when available.",
    banish = "Shows Banish on the current target when available.",
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
    wizardoil = "Wizard Oil or Firestone on your weapon. Firestone shows its remaining time when readable; Wizard Oil has no HUD timer. Protected states may delay updates.",
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

local function IsFeatureEnabled(key)
    local enabled = Profile().enabled[key]
    if enabled ~= nil then return enabled == true end
    if key == "healthstone" or key == "soulstone" or key == "soulshards" then
        return api.FeatureSpellLearned and api.FeatureSpellLearned(key) == true
    end
    return true
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

local function Check(parent, x, y, label, getValue, setValue, tooltip, needsRebuild,
    checkSize, labelGap)
    checkSize = checkSize or 22
    labelGap = labelGap or 5
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    check:SetSize(checkSize, checkSize)
    local textOffset = checkSize + labelGap
    Text(parent, label, x + textOffset, y - 5, "GameFontHighlight")
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
        button:SetShown(dirty)
        button:SetEnabled(dirty and CanRebuild())
        if not dirty then
            status:SetText("")
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
        fear = 5782, banish = 710, conflagrate = 1293817,
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

        local demoIcons = {}
        local function DemoRow(title, keys, orderKey, sizeKey, anchor)
            local profile = Profile()
            local order = orderKey and profile[orderKey] or keys
            local size = profile[sizeKey]
            local iconSpacing = 1
            local iconCrop = (1 - 1 / 1.3) / 2
            local width = math.max(1, #order * size
                + math.max(0, #order - 1) * iconSpacing)
            local row = CreateFrame("Frame", nil, demo)
            row:SetSize(width, size)
            if orderKey == "buffOrder" or orderKey == "consumeOrder" then
                row:SetPoint("LEFT", anchor, "LEFT")
            else
                row:SetPoint("CENTER", anchor, "CENTER")
            end
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
                    (index - (#order + 1) / 2) * (size + iconSpacing), 0)
                local icon = button:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints(button)
                local texture = api.GetDemoIconTexture
                    and api.GetDemoIconTexture(key)
                icon:SetTexture(texture or IconForKey(key)
                    or "Interface\\Icons\\INV_Misc_QuestionMark")
                demoIcons[#demoIcons + 1] = { icon = icon, key = key }
                icon:SetTexCoord(iconCrop, 1 - iconCrop, iconCrop, 1 - iconCrop)
                if (orderKey == "mainOrder" or orderKey == "cooldownOrder")
                    and key ~= "fear" then
                    icon:SetDesaturated(profile.colorActiveDoTs ~= false)
                elseif orderKey == "buffOrder" then
                    icon:SetDesaturated(profile.colorActiveBuffs ~= false)
                elseif orderKey == "consumeOrder" then
                    icon:SetDesaturated(profile.colorActiveConsumes ~= false)
                end

                local border = CreateFrame("Frame", nil, button)
                border:SetSize(size + 2, size + 2)
                border:SetPoint("CENTER", button, "CENTER")
                local edges = {
                    { "TOP", size + 2, 1 }, { "BOTTOM", size + 2, 1 },
                    { "LEFT", 1, size + 2 }, { "RIGHT", 1, size + 2 },
                }
                for _, edgeInfo in ipairs(edges) do
                    local edge = border:CreateTexture(nil, "OVERLAY")
                    edge:SetSize(edgeInfo[2], edgeInfo[3])
                    edge:SetPoint(edgeInfo[1], border, edgeInfo[1])
                    edge:SetColorTexture(0, 0, 0, 1)
                end
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
        local textureRefresh = 0
        demo:SetScript("OnUpdate", function(self, elapsed)
            textureRefresh = textureRefresh + elapsed
            if textureRefresh < 0.5 then return end
            textureRefresh = 0
            for _, entry in ipairs(demoIcons) do
                local current = api.GetDemoIconTexture
                    and api.GetDemoIconTexture(entry.key)
                if current then entry.icon:SetTexture(current) end
            end
        end)
        demo:Hide()
        iconDemo = demo
    end
    iconDemo:Show()
    RefreshAll()
end

local function OrderSection(parent, title, orderKey, defaults, y, columns, onReset,
    stripX, rowPitch, centerRows, cornerControls, cellWidth, labelWidth)
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
    rowPitch = rowPitch or 95
    cellWidth = cellWidth or 78
    local rows = math.ceil(#defaults / columns)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetSize(columns * cellWidth, rows * rowPitch)
    strip:SetPoint("TOPLEFT", parent, "TOPLEFT", stripX or 24, y - 29)
    local tiles = {}
    for index = 1, #defaults do
        local tile = CreateFrame("Button", nil, strip)
        local tileSize = cornerControls and 34 or 42
        tile:SetSize(tileSize, tileSize)
        tile:SetMovable(true)
        tile:EnableMouse(true)
        tile:RegisterForDrag("LeftButton")
        local background = tile:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(tile)
        background:SetColorTexture(0, 0, 0, 1)
        local icon = tile:CreateTexture(nil, "ARTWORK")
        local iconInset = cornerControls and 1 or 2
        icon:SetPoint("TOPLEFT", tile, "TOPLEFT", iconInset, -iconInset)
        icon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -iconInset, iconInset)
        icon:SetTexCoord(0.115, 0.885, 0.115, 0.885)
        tile.icon = icon
        if cornerControls then
            local grip = tile:CreateTexture(nil, "OVERLAY")
            grip:SetPoint("TOPLEFT", tile, "TOPLEFT", 3, -3)
            grip:SetSize(10, 13)
            grip:SetColorTexture(0.04, 0.035, 0.025, 0.85)
            for dot = 1, 6 do
                local mark = tile:CreateTexture(nil, "OVERLAY")
                mark:SetSize(2, 2)
                mark:SetPoint("TOPLEFT", grip, "TOPLEFT",
                    2 + ((dot - 1) % 2) * 4, -2 - math.floor((dot - 1) / 2) * 4)
                mark:SetColorTexture(1, 0.82, 0.25, 1)
            end
        end
        tile:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(DisplayName(self.key))
            if ICON_HELP[self.key] then
                GameTooltip:AddLine(ICON_HELP[self.key], 1, 1, 1, true)
            end
            if cornerControls then
                GameTooltip:AddLine("Drag this icon tile by its gold grip to reorder it.",
                    1, 1, 1, true)
                GameTooltip:AddLine("Use the checkmark to show or hide it.", 1, 1, 1, true)
            elseif orderKey == "buffOrder" and self.key == "breath" then
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
                local row = rows > 1 and math.max(1, math.min(rows,
                    math.floor((top - cursorY) / rowPitch) + 1)) or 1
                local rowCount = math.min(columns, #defaults - (row - 1) * columns)
                local rowOffset = centerRows
                    and (columns - rowCount) * cellWidth / 2 or 0
                local column = math.max(1, math.min(columns,
                    math.floor((cursorX - left - rowOffset) / cellWidth) + 1))
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
        local check = CreateFrame("CheckButton", nil,
            cornerControls and tile or parent, "UICheckButtonTemplate")
        if cornerControls then
            check:SetSize(16, 16)
            check:SetPoint("TOPRIGHT", tile, "TOPRIGHT", 0, 0)
        else
            check:SetPoint("TOP", tile, "BOTTOM", 0, -19)
        end
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
        label:SetSize(labelWidth or 70, 16)
        label:SetPoint("TOP", tile, "BOTTOM", 0, -2)
        label:SetJustifyH("CENTER")
        tiles[index] = { frame = tile, check = check, label = label }
    end
    refreshers[#refreshers + 1] = function()
        for index, tile in ipairs(tiles) do
            local key = Profile()[orderKey][index]
            tile.frame.key = key
            tile.frame:ClearAllPoints()
            local rowIndex = math.floor((index - 1) / columns)
            local rowCount = math.min(columns, #defaults - rowIndex * columns)
            local rowOffset = centerRows
                and (columns - rowCount) * cellWidth / 2 or 0
            local tileOffset = cornerControls
                and (cellWidth - tile.frame:GetWidth()) / 2 or 0
            tile.frame:SetPoint("TOPLEFT", strip, "TOPLEFT",
                rowOffset + tileOffset + ((index - 1) % columns) * cellWidth,
                -rowIndex * rowPitch - (cornerControls and 20 or 0))
            tile.frame.icon:SetTexture(IconForKey(key) or "Interface\\Icons\\INV_Misc_QuestionMark")
            tile.frame.icon:SetDesaturated(Profile().enabled[key] == false)
            tile.frame:SetAlpha(Profile().enabled[key] == false and 0.5 or 1)
            tile.label:SetText(TILE_LABELS[key] or DisplayName(key))
            tile.check:SetChecked(Profile().enabled[key] ~= false)
        end
    end
end

local DefaultProfile, ResetRowValues

local function LinkedTargetUtilityRows(parent)
    local keys = { "mainOrder", "cooldownOrder" }
    local titles = { "Target DoTs", "Utility" }
    local strips = {}
    local allKeys = #api.MainKeys + #api.CooldownKeys
    local columns, boxColumns, cellWidth, cellHeight = 11, 12, 50, 53
    local gridRows = math.max(1, math.ceil(allKeys / columns))
    local firstTitleY = -155
    local gridHeight = gridRows * cellHeight + 30
    local secondTitleY = firstTitleY - 20 - gridHeight - 15
    local nameplatesY = secondTitleY - 20 - gridHeight - 10
    local resetY = nameplatesY - 44

    local function ResetBoth()
        local defaults = DefaultProfile()
        ResetRowValues("mainSize", "mainOrder", api.MainKeys, defaults)
        ResetRowValues("cooldownSize", "cooldownOrder", api.CooldownKeys, defaults)
        MarkChanged()
    end

    for rowIndex, orderKey in ipairs(keys) do
        local y = rowIndex == 1 and firstTitleY or secondTitleY
        Text(parent, titles[rowIndex], 20, y, "GameFontNormal")
        local strip = CreateFrame("Frame", nil, parent)
        local rowKeys = orderKey == "mainOrder" and api.MainKeys or api.CooldownKeys
        local visibleRows = gridRows
        strip:SetSize(boxColumns * cellWidth, visibleRows * cellHeight + 30)
        strip:SetPoint("TOP", parent, "TOP", 0, y - 20)
        local back = strip:CreateTexture(nil, "BACKGROUND")
        back:SetAllPoints(strip)
        back:SetColorTexture(0.025, 0.035, 0.05, 0.55)
        local border = CreateFrame("Frame", nil, strip)
        border:SetAllPoints(strip)
        for _, edgeInfo in ipairs({
            { "TOP", strip:GetWidth(), 1 }, { "BOTTOM", strip:GetWidth(), 1 },
            { "LEFT", 1, strip:GetHeight() }, { "RIGHT", 1, strip:GetHeight() },
        }) do
            local edge = border:CreateTexture(nil, "BORDER")
            edge:SetSize(edgeInfo[2], edgeInfo[3])
            edge:SetPoint(edgeInfo[1], border, edgeInfo[1])
            edge:SetColorTexture(0.7, 0.54, 0.2, 0.75)
        end
        strips[rowIndex] = strip
        local tiles = {}
        for index = 1, allKeys do
            local tile = CreateFrame("Button", nil, strip)
            tile:SetSize(34, 34)
            tile:SetMovable(true)
            tile:EnableMouse(true)
            tile:RegisterForDrag("LeftButton")
            local border = tile:CreateTexture(nil, "BACKGROUND")
            border:SetAllPoints(tile)
            border:SetColorTexture(0, 0, 0, 1)
            local icon = tile:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("TOPLEFT", tile, "TOPLEFT", 1, -1)
            icon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -1, 1)
            icon:SetTexCoord(0.115, 0.885, 0.115, 0.885)
            tile.icon = icon
            local grip = tile:CreateTexture(nil, "OVERLAY")
            grip:SetPoint("TOPLEFT", tile, "TOPLEFT", 3, -3)
            grip:SetSize(10, 13)
            grip:SetColorTexture(0.04, 0.035, 0.025, 0.85)
            for dot = 1, 6 do
                local mark = tile:CreateTexture(nil, "OVERLAY")
                mark:SetSize(2, 2)
                mark:SetPoint("TOPLEFT", grip, "TOPLEFT",
                    2 + ((dot - 1) % 2) * 4, -2 - math.floor((dot - 1) / 2) * 4)
                mark:SetColorTexture(1, 0.82, 0.25, 1)
            end
            local check = CreateFrame("CheckButton", nil, tile, "UICheckButtonTemplate")
            check:SetSize(16, 16)
            check:SetPoint("TOPRIGHT", tile, "TOPRIGHT", 0, 0)
            check:SetScript("OnClick", function(self)
                if not tile.key then return end
                local key = tile.key
                if self:GetChecked() then
                    Profile().enabled[key] = (key == "healthstone"
                        or key == "soulstone") and true or nil
                else
                    Profile().enabled[key] = false
                end
                MarkChanged()
            end)
            tile:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(DisplayName(self.key))
                if ICON_HELP[self.key] then
                    GameTooltip:AddLine(ICON_HELP[self.key], 1, 1, 1, true)
                end
                GameTooltip:AddLine("Drag this icon tile by its gold grip. Drop in either grid to reorder or move it.",
                    1, 1, 1, true)
                GameTooltip:AddLine("Use the checkmark to show or hide it.", 1, 1, 1, true)
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
                for destinationRow, target in ipairs(strips) do
                    local stripLeft, stripTop = target:GetLeft(), target:GetTop()
                    if stripLeft and stripTop then
                        local left, right = stripLeft, stripLeft + boxColumns * cellWidth
                        local top = stripTop - 17
                        local visibleRows = gridRows
                        local bottom = top - visibleRows * cellHeight
                        if cursorX >= left - 8 and cursorX <= right + 8
                            and cursorY >= bottom - 8 and cursorY <= top + 8 then
                            local source = Profile()[orderKey]
                            local sourceIndex
                            for i, key in ipairs(source) do
                                if key == self.key then sourceIndex = i; break end
                            end
                            if sourceIndex then
                                local destination = Profile()[keys[destinationRow]]
                                local destinationCount = #destination
                                local rowCount = math.max(0, math.min(columns,
                                    destinationCount - (row - 1) * columns))
                                local rowOffset = (strip:GetWidth() - rowCount * cellWidth) / 2
                                local column = math.max(1, math.min(columns,
                                    math.floor((cursorX - stripLeft - rowOffset) / cellWidth) + 1))
                                local row = math.max(1, math.min(visibleRows,
                                    math.floor((top - cursorY) / cellHeight) + 1))
                                local slot = (row - 1) * columns + column
                                table.remove(source, sourceIndex)
                                if source == destination and slot > sourceIndex then
                                    slot = slot - 1
                                end
                                table.insert(destination, math.min(slot, #destination + 1), self.key)
                                MarkChanged()
                                return
                            end
                        end
                    end
                end
                RefreshAll()
            end)
            local label = strip:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            label:SetSize(cellWidth, 14)
            label:SetPoint("TOP", tile, "BOTTOM", 0, -2)
            label:SetJustifyH("CENTER")
            tiles[index] = { frame = tile, check = check, label = label }
        end
        refreshers[#refreshers + 1] = function()
            local order = Profile()[orderKey]
            for index, entry in ipairs(tiles) do
                local key = order[index]
                local tile = entry.frame
                tile:SetShown(key ~= nil)
                entry.label:SetShown(key ~= nil)
                if key then
                    tile.key = key
                    tile:ClearAllPoints()
                    local rowIndex = math.floor((index - 1) / columns)
                    local rowCount = math.min(columns, #order - rowIndex * columns)
                    local firstX = (strip:GetWidth() - rowCount * cellWidth) / 2
                    tile:SetPoint("TOPLEFT", strip, "TOPLEFT",
                        firstX + ((index - 1) % columns) * cellWidth,
                        -17 - rowIndex * cellHeight)
                    tile.icon:SetTexture(IconForKey(key)
                        or "Interface\\Icons\\INV_Misc_QuestionMark")
                    local enabled = IsFeatureEnabled(key)
                    tile.icon:SetDesaturated(not enabled)
                    tile:SetAlpha(enabled and 1 or 0.5)
                    entry.check:SetChecked(enabled)
                    entry.label:SetText(TILE_LABELS[key] or DisplayName(key))
                end
            end
        end
    end
    local reset = Button(parent, "Reset Both Rows", 300, resetY, 140, ResetBoth)
    reset:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reset Target DoTs and Utility")
        GameTooltip:AddLine(
            "Restores both rows' icon sizes, order, and visibility. Edit Mode positions stay.",
            1, 1, 1, true)
        GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return nameplatesY
end

DefaultProfile = function()
    return api.NormalizeProfile({})
end

ResetRowValues = function(sizeKey, orderKey, keys, defaults)
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

local function ResetPageButton(parent, pageName, reset, x, y)
    Button(parent, "Reset Page", x or 300, y or -520, 110, function()
        StaticPopup_Show("WARLOCKHUD_RESET_PAGE", pageName, nil, reset)
    end)
end

local layout = Panel("Warlock HUD - Rows & Layout")
local general = Panel("Warlock HUD - General", false)
local fonts = Panel("Warlock HUD - Fonts")
Text(fonts, "Choose a built-in font and set sizes for HUD text.",
    20, -50, "GameFontHighlightSmall")
local function FontSelector(label, key, y, sizeKey)
    Text(fonts, label, 20, y, "GameFontNormal")
    local menu = CreateFrame("Frame", nil, fonts, "UIDropDownMenuTemplate")
    menu:SetPoint("TOPLEFT", fonts, "TOPLEFT", 190, y + 16)
    UIDropDownMenu_SetWidth(menu, 175)
    UIDropDownMenu_Initialize(menu, function(_, level)
        for _, choice in ipairs(WarlockHudFonts.Choices) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = choice.label
            local current = Profile()
            info.checked = ((current and current[key]) or "default") == choice.key
            info.func = function()
                Profile()[key] = choice.key ~= "default" and choice.key or nil
                MarkChanged()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    local preview = Text(fonts, "", 445, y, "GameFontHighlight")
    refreshers[#refreshers + 1] = function()
        local selected = Profile()[key] or "default"
        for _, choice in ipairs(WarlockHudFonts.Choices) do
            if choice.key == selected then
                UIDropDownMenu_SetText(menu, choice.label)
                preview:SetText(choice.label)
                break
            end
        end
        local path, size, flags = GameFontHighlight:GetFont()
        preview:SetFont(path, size, flags)
        WarlockHudFonts.Apply(preview, Profile(), sizeKey, 16, key)
    end
end
FontSelector("Main HUD font", "fontFace", -85, "fontIconSize")
FontSelector("Multi-Target font", "multiTargetFontFace", -145, "fontMultiTargetSize")
local function FontSizeControl(label, key, y, minimum, maximum, suggested)
    Text(fonts, label, 20, y, "GameFontNormal")
    local slider = CreateFrame("Slider", nil, fonts, "OptionsSliderTemplate")
    slider:SetSize(165, 17)
    slider:SetPoint("TOPLEFT", fonts, "TOPLEFT", 220, y + 2)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(1)
    local valueText = Text(fonts, "", 440, y, "GameFontHighlight")
    local function Commit(value)
        value = math.max(minimum, math.min(maximum, math.floor(value + 0.5)))
        if Profile()[key] ~= value then
            Profile()[key] = value
            MarkChanged()
        end
    end
    slider:SetScript("OnValueChanged", function(_, value)
        valueText:SetText(math.floor(value + 0.5) .. " px")
    end)
    slider:SetScript("OnMouseUp", function(self) Commit(self:GetValue()) end)
    Button(fonts, "-", 185, y + 4, 24, function()
        Commit((Profile()[key] or suggested) - 1)
    end)
    Button(fonts, "+", 395, y + 4, 24, function()
        Commit((Profile()[key] or suggested) + 1)
    end)
    Button(fonts, "Default", 535, y + 4, 90, function()
        if Profile()[key] ~= nil then
            Profile()[key] = nil
            MarkChanged()
        end
    end)
    refreshers[#refreshers + 1] = function()
        slider:SetValue(Profile()[key] or suggested)
        valueText:SetText(Profile()[key] and (Profile()[key] .. " px") or "Default")
    end
end
FontSizeControl("Icon counts and Soulstone", "fontIconSize", -220, 8, 24, 12)
FontSizeControl("Target aura countdowns", "fontTimerSize", -285, 8, 30, 14)
FontSizeControl("Multi-Target labels", "fontMultiTargetSize", -350, 8, 18, 10)
FontSizeControl("Multi-Target countdowns", "fontMultiTargetTimerSize", -415, 8, 24, 10)
Text(fonts, "Changes save immediately. HUD visuals update when combat and aura state allow it.",
    20, -470, "GameFontHighlightSmall")
ResetPageButton(fonts, "Fonts", function()
    local p = Profile()
    p.fontFace, p.fontIconSize, p.fontTimerSize = nil, nil, nil
    p.multiTargetFontFace = nil
    p.fontMultiTargetSize, p.fontMultiTargetTimerSize = nil, nil
    MarkChanged()
end)
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
    LinkedTargetUtilityRows = LinkedTargetUtilityRows,
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

local shareCategory
local about = WarlockHudOptionsAbout.Build({
    api = api,
    Panel = Panel,
    Text = Text,
    Button = Button,
    refreshers = refreshers,
    ShowIconDemo = ShowIconDemo,
    IsDemoShown = function() return iconDemo and iconDemo:IsShown() end,
    OpenSharingSettings = function()
        if shareCategory then Settings.OpenToCategory(shareCategory:GetID()) end
    end,
})

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
    category = Settings.RegisterCanvasLayoutCategory(about, "Warlock HUD")
    Settings.RegisterAddOnCategory(category)
    Settings.RegisterCanvasLayoutSubcategory(category, general, "General")
    Settings.RegisterCanvasLayoutSubcategory(category, layout, "Rows & Layout")
    Settings.RegisterCanvasLayoutSubcategory(category, spells, "Tracked Auras")
    Settings.RegisterCanvasLayoutSubcategory(category, multiDotPanel, "Multi-Target DoTs")
    Settings.RegisterCanvasLayoutSubcategory(category, consumeLayout, "Consumes")
    Settings.RegisterCanvasLayoutSubcategory(category, buffLayout, "Buffs")
    Settings.RegisterCanvasLayoutSubcategory(category, procLayout, "Procs")
    Settings.RegisterCanvasLayoutSubcategory(category, shards, "Soul Shards")
    Settings.RegisterCanvasLayoutSubcategory(category, stones, "Stones")
    Settings.RegisterCanvasLayoutSubcategory(category, summons, "Summons")
    Settings.RegisterCanvasLayoutSubcategory(category, notifications, "Notifications")
    Settings.RegisterCanvasLayoutSubcategory(category, fonts, "Fonts")
    Settings.RegisterCanvasLayoutSubcategory(category, profiles, "Profiles")
    shareCategory = Settings.RegisterCanvasLayoutSubcategory(category, sharingPanel,
        "Share Settings")
    RefreshAll()
end)

function WarlockHudOpenSettings()
    if category then
        Settings.OpenToCategory(category:GetID())
        return true
    end
end
