-- Fixed nameplate and group-target display sources, with up to sixteen visible
-- rows. Aura slots are built only outside combat. The view is not clickable.
local api = WarlockHudAPI
local rows = {}
local root
local status
local mover
local scrollFrame, scrollContent, scrollBar
local visibilityController
local visibilityDriver = false
local built, pending, auraWarning, failed = false, false, false, false
local builtBrand, buildCount = false, 0
local ROWS = 16
local SOURCE_UNITS = {}
for i = 1, ROWS do SOURCE_UNITS[#SOURCE_UNITS + 1] = "nameplate" .. i end
SOURCE_UNITS[#SOURCE_UNITS + 1] = "target"
for i = 1, 4 do SOURCE_UNITS[#SOURCE_UNITS + 1] = "party" .. i .. "target" end
for i = 1, 40 do SOURCE_UNITS[#SOURCE_UNITS + 1] = "raid" .. i .. "target" end
local ICON_SIZE = 24
local ROW_HEIGHT = 29
local PORTRAIT_SIZE = 26
local BASE_WIDTH, BASE_HEIGHT = 430, 548
local COUNTDOWN_FONT = "WarlockHudMultiDotCountdownFont"
local countdownFontReady = false
local SPELLS = api.Spells
local DOT_KEYS = { unpack(api.MainKeys, 1, 6) }
local DOT_SLOTS = #DOT_KEYS
local ICON_CROP = (1 - 1 / 1.3) / 2
local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local function ClampScale(value)
    return math.max(0.7, math.min(1.6, tonumber(value) or 1))
end

local function ClampWidth(value)
    -- Six fixed DoT slots need enough room for a readable name and HP bar.
    return math.max(390, math.min(700, tonumber(value) or BASE_WIDTH))
end

local function ClampHeight(value)
    return math.max(150, math.min(800, tonumber(value) or BASE_HEIGHT))
end

local function Safe()
    return not InCombatLockdown() and not (C_Secrets
        and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret())
end

local function Plain(value)
    return (not issecretvalue or not issecretvalue(value)) and value ~= nil
end

local function Profile()
    if not api.GetProfile() then api.InitializeProfiles() end
    return api.GetProfile()
end

local function ApplyAppearance()
    if not root then return false end
    local p = Profile()
    if not p then return false end
    root:SetAlpha(math.max(0.3, math.min(1, tonumber(p.multiDotAlpha) or 1)))
    local wantsDriver = p.multiDotEnabled and p.multiDotHideOutOfCombat
        and api.IsAddonEnabled()
    if wantsDriver ~= visibilityDriver then
        if Safe() then
            local ok
            if wantsDriver and RegisterStateDriver then
                ok = pcall(RegisterStateDriver, visibilityController, "mtdvisibility",
                    "[combat] show; hide")
            elseif not wantsDriver and UnregisterStateDriver then
                ok = pcall(UnregisterStateDriver, visibilityController, "mtdvisibility")
            end
            if ok then
                visibilityDriver = wantsDriver
            else
                pending = true
                if WarlockHudTraceHUD then
                    WarlockHudTraceHUD("Multi-Target: combat visibility driver was blocked")
                end
            end
        else
            pending = true
        end
    end
    if visibilityDriver and wantsDriver then return true end
    local shown = p.multiDotEnabled and api.IsAddonEnabled()
        and (not p.multiDotHideOutOfCombat or InCombatLockdown())
    local ok = pcall(root.SetShown, root, shown)
    if not ok then pending = true end
    return ok
end

local function Position()
    if not root then return end
    local p = Profile()
    local width, height = root:GetSize()
    root:ClearAllPoints()
    if type(p.multiDotX) == "number" and type(p.multiDotY) == "number" then
        root:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            p.multiDotX * UIParent:GetWidth() - width / 2,
            p.multiDotY * UIParent:GetHeight() + height / 2)
    else
        root:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            UIParent:GetWidth() / 2 + 320 - width / 2,
            UIParent:GetHeight() / 2 + height / 2)
    end
end

local function ClearIdentity(row)
    row.present = false
    row.eligible = false
    row.relevant = false
    -- Alpha also hides native aura children without changing protected
    -- visibility or anchors during combat.
    row.display:SetAlpha(0)
    row.name:SetText("")
    if row.healthBar then
        pcall(row.healthBar.SetMinMaxValues, row.healthBar, 0, 1)
        pcall(row.healthBar.SetValue, row.healthBar, 0)
    end
    if row.healthText then row.healthText:SetText("") end
    row.name:SetTextColor(0.94, 0.94, 0.92)
    row.portrait:SetTexture(nil)
    row.portraitReady = false
    row.marker:Hide()
    row.markerMode = "none"
    row.target:SetColorTexture(0.86, 0.66, 0.25, 0)
end

local function UpdateHealth(row, name)
    row.name:SetText(name)
    if not UnitHealth or not UnitHealthMax or not UnitHealthPercent
        or not CurveConstants or not CurveConstants.ScaleTo100 then
        row.healthText:SetText("")
        return
    end
    local healthOK, health = pcall(UnitHealth, row.unit, true)
    local maxOK, maximum = pcall(UnitHealthMax, row.unit)
    local percentOK, percent = pcall(UnitHealthPercent, row.unit, true,
        CurveConstants.ScaleTo100)
    if not healthOK or not maxOK or not percentOK then
        row.healthText:SetText("")
        return
    end
    local function Numeric(value)
        return (issecretvalue and issecretvalue(value))
            or type(value) == "number"
    end
    if not Numeric(health) or not Numeric(maximum) or not Numeric(percent) then
        row.healthText:SetText("")
        return
    end
    -- These values may be secret. Native widgets accept them directly; Lua
    -- never compares, divides, concatenates, or formats them.
    pcall(row.healthBar.SetMinMaxValues, row.healthBar, 0, maximum)
    pcall(row.healthBar.SetValue, row.healthBar, health)
    local formatted = pcall(row.healthText.SetFormattedText, row.healthText,
        "%.0f / %.0f  %.0f%%", health, maximum, percent)
    if not formatted then row.healthText:SetText("") end
end

local function GroupThreat(unit)
    if not UnitThreatSituation then return nil end
    local unknown = false
    local members = { "player", "pet" }
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do
            members[#members + 1] = "raid" .. i
            members[#members + 1] = "raidpet" .. i
        end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do
            members[#members + 1] = "party" .. i
            members[#members + 1] = "partypet" .. i
        end
    end
    for _, member in ipairs(members) do
        local existsOK, memberExists = pcall(UnitExists, member)
        if not existsOK or not Plain(memberExists) then
            unknown = true
        elseif memberExists then
            local threatOK, status = pcall(UnitThreatSituation, member, unit)
            if not threatOK or (issecretvalue and issecretvalue(status)) then
                unknown = true
            elseif type(status) == "number" then
                return true
            end
        end
    end
    return unknown and nil or false
end

local function TargetsGroup(unit)
    if not UnitIsUnit or not UnitExists then return false end
    local target = unit .. "target"
    local targetOK, exists = pcall(UnitExists, target)
    if not targetOK or not Plain(exists) or not exists then return false end
    local members = { "player", "pet" }
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do
            members[#members + 1] = "raid" .. i
            members[#members + 1] = "raidpet" .. i
        end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do
            members[#members + 1] = "party" .. i
            members[#members + 1] = "partypet" .. i
        end
    end
    for _, member in ipairs(members) do
        local sameOK, same = pcall(UnitIsUnit, target, member)
        if sameOK and Plain(same) and same then return true end
    end
    return false
end

local function TargetedByGroup(unit)
    if not UnitIsUnit then return false end
    local candidates = { "pettarget" }
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do candidates[#candidates + 1] = "raid" .. i .. "target" end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do candidates[#candidates + 1] = "party" .. i .. "target" end
    end
    local unitGuid
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, unit)
        if ok and Plain(guid) and type(guid) == "string" then unitGuid = guid end
    end
    for _, other in ipairs(candidates) do
        local existsOK, exists = pcall(UnitExists, other)
        if existsOK and Plain(exists) and exists then
            local sameOK, same = pcall(UnitIsUnit, unit, other)
            if sameOK and Plain(same) and same then return true end
            if unitGuid and UnitGUID then
                local guidOK, otherGuid = pcall(UnitGUID, other)
                if guidOK and Plain(otherGuid) and type(otherGuid) == "string"
                    and otherGuid == unitGuid then return true end
            end
        end
    end
    return false
end

local function OwnDot(unit)
    -- Native slots render combat auras. Lua only checks presence while the
    -- aura APIs are unrestricted, never their protected duration fields.
    if InCombatLockdown() or not C_UnitAuras
        or not C_UnitAuras.GetAuraDataBySpellID
        or (C_Secrets and C_Secrets.ShouldAurasBeSecret
            and C_Secrets.ShouldAurasBeSecret()) then return nil end
    for _, spell in ipairs(SPELLS) do
        if spell.group ~= 2 then for _, id in ipairs(spell.ids) do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellID,
                unit, id, "HARMFUL|PLAYER")
            if not ok or (issecretvalue and issecretvalue(aura)) then return nil end
            if aura then return true end
        end end
    end
    return false
end

local function UpdatePortrait(row)
    if row.present and SetPortraitTexture then
        row.portraitReady = pcall(SetPortraitTexture, row.portrait, row.unit)
    end
end

local function ReadRaidMarker(unit)
    if not GetRaidTargetIndex then return nil end
    local ok, index = pcall(GetRaidTargetIndex, unit)
    if ok and Plain(index) and type(index) == "number"
        and index >= 1 and index <= 8 then return index end
end

local function ReadGuidRaidMarker(unit)
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or not Plain(guid) or type(guid) ~= "string" then return nil end
    return ReadRaidMarker(guid)
end

local function MarkerProbeResult(unit)
    if not GetRaidTargetIndex then return "API unavailable" end
    local ok, index = pcall(GetRaidTargetIndex, unit)
    if not ok then return "error" end
    if issecretvalue and issecretvalue(index) then return "restricted" end
    if index == nil then return "nil" end
    return tostring(index)
end

local function ReadableGuid(unit)
    if not UnitGUID then return "unavailable" end
    local ok, guid = pcall(UnitGUID, unit)
    return ok and Plain(guid) and type(guid) == "string"
        and guid or "unavailable"
end

local function RaidMarkerFor(unit)
    local index = ReadRaidMarker(unit)
    if index then return index, unit end
    index = ReadGuidRaidMarker(unit)
    if index then return index, unit .. " GUID" end
    local alternatives = { "target", "focus", "pettarget" }
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do alternatives[#alternatives + 1] = "raid" .. i .. "target" end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do alternatives[#alternatives + 1] = "party" .. i .. "target" end
    end
    for _, other in ipairs(alternatives) do
        local sameOK, same = pcall(UnitIsUnit, unit, other)
        if sameOK and Plain(same) and same then
            index = ReadRaidMarker(other)
            if index then return index, other end
            index = ReadGuidRaidMarker(other)
            if index then return index, other .. " GUID" end
        end
    end
end

local function UpdateIdentity(row)
    local unit = row.unit
    local source = row.source
    if source == "party" and (not IsInGroup or not IsInGroup()
        or (IsInRaid and IsInRaid())) then ClearIdentity(row); return end
    if source == "raid" and (not IsInRaid or not IsInRaid()) then
        ClearIdentity(row); return
    end
    local existsOK, exists = pcall(UnitExists, unit)
    if not existsOK or not Plain(exists) or not exists then
        ClearIdentity(row)
        return
    end
    if UnitIsDeadOrGhost then
        local deadOK, dead = pcall(UnitIsDeadOrGhost, unit)
        if deadOK and Plain(dead) and dead then
            ClearIdentity(row)
            return
        end
    end
    if source ~= "nameplate" then
        local attackOK, attackable = pcall(UnitCanAttack, "player", unit)
        if not attackOK or not Plain(attackable) or not attackable then
            ClearIdentity(row); return
        end
    end
    if source == "nameplate" or source == "target" then
        local threat, dot = GroupThreat(unit), OwnDot(unit)
        local targetingGroup = TargetsGroup(unit)
        local groupTarget = TargetedByGroup(unit)
        -- A row confirmed before combat stays visible while DoT evidence is
        -- restricted. New rows still need confirmation, and safe reads recheck it.
        local retainConfirmed = row.eligible and InCombatLockdown() and dot == nil
        if threat ~= true and dot ~= true and not targetingGroup and not groupTarget
            and not retainConfirmed then
            ClearIdentity(row)
            return
        end
    end
    row.present = true
    row.eligible = true
    row.relevant = true
    row.display:SetAlpha(1)
    row.name:SetTextColor(0.96, 0.96, 0.94)
    row.target:SetColorTexture(0.86, 0.66, 0.25, 0)
    if not row.portraitReady then UpdatePortrait(row) end
    local ok, name = pcall(UnitName, unit)
    if ok then UpdateHealth(row, name) end
    local index = RaidMarkerFor(unit)
    if index then
        local column = (index - 1) % 4
        local line = math.floor((index - 1) / 4)
        row.marker:SetTexCoord(column * 0.25, (column + 1) * 0.25,
            line * 0.25, (line + 1) * 0.25)
        row.marker:Show()
        row.markerMode = "readable"
    else
        -- Blizzard's untainted renderer may accept a restricted marker index
        -- even though addon Lua cannot compare or calculate with it.
        local markerOK, restrictedIndex = pcall(GetRaidTargetIndex, unit)
        local rendered = false
        if markerOK and issecretvalue and issecretvalue(restrictedIndex)
            and SetRaidTargetIconTexture then
            rendered = pcall(SetRaidTargetIconTexture, row.marker, restrictedIndex)
        end
        if rendered then
            row.marker:Show()
            row.markerMode = "native"
        else
            row.marker:Hide()
            row.markerMode = "none"
        end
    end
    local targetOK, selected = pcall(UnitIsUnit, unit, "target")
    if targetOK and Plain(selected) and selected == true then
        row.target:SetColorTexture(0.86, 0.66, 0.25, 0.95)
    end
    -- Match the HUD's full/half icon alpha for an attackable target while
    -- leaving row text and health legible. The parent also carries native aura
    -- buttons, so Blizzard continues to control their visibility and timers.
    row.icons:SetAlpha((row.relevant == true
        or (targetOK and Plain(selected) and selected == true)) and 1 or 0.5)
end

local function NormalizeRows()
    local seen, accepted, count = {}, {}, 0
    for _, row in ipairs(rows) do
        if row.eligible then
            local guid = ReadableGuid(row.unit)
            local duplicate = guid ~= "unavailable" and seen[guid]
            if not duplicate and UnitIsUnit then
                for _, prior in ipairs(accepted) do
                    local ok, same = pcall(UnitIsUnit, row.unit, prior)
                    if ok and Plain(same) and same then
                        duplicate = true
                        break
                    end
                end
            end
            if duplicate or count >= ROWS then
                row.present = false
                row.display:SetAlpha(0)
            else
                row.present = true
                row.display:SetAlpha(1)
                if guid ~= "unavailable" then seen[guid] = true end
                accepted[#accepted + 1] = row.unit
                count = count + 1
            end
        end
    end
end

local function UpdateStatus()
    if not status then return end
    local count = 0
    for _, row in ipairs(rows) do
        if row.present then count = count + 1 end
    end
    if count == 0 then
        status:SetText("No engaged or dotted targets")
    else
        status:SetText(count .. " engaged or dotted target"
            .. (count == 1 and "" or "s"))
    end
end

local function UpdateScrollRange(height, present)
    local viewportHeight = height - 57
    local maxScroll = math.max(0, present * ROW_HEIGHT - viewportHeight)
    scrollBar:SetMinMaxValues(0, maxScroll)
    scrollBar:SetShown(maxScroll > 0)
    if scrollBar:GetValue() > maxScroll then scrollBar:SetValue(maxScroll) end
    if maxScroll == 0 then scrollFrame:SetVerticalScroll(0) end
end

local function CompactRows(width, height, positionsOnly)
    local displayWidth = width - (DOT_SLOTS * (ICON_SIZE + 3) + 38)
    local healthWidth = displayWidth - 48
    local profile = Profile()
    local showExecute = profile and profile.enabled
        and profile.enabled.executeMarker ~= false
    local step = ROW_HEIGHT
    local present = 0
    for _, row in ipairs(rows) do
        if row.present then present = present + 1 end
    end
    local activePosition, emptyPosition = 0, present
    for _, row in ipairs(rows) do
        local position
        if row.present then
            activePosition = activePosition + 1
            position = activePosition
        else
            emptyPosition = emptyPosition + 1
            position = emptyPosition
        end
        if not positionsOnly then row.display:SetWidth(displayWidth) end
        if row.position ~= position or row.step ~= step then
            local y = -(position - 1) * step
            if positionsOnly then
                -- These display frames are created outside combat. Move only
                -- an unprotected existing parent; never rebuild native auras.
                local checked, protected = pcall(row.display.IsProtected, row.display)
                if not checked or (issecretvalue and issecretvalue(protected))
                    or protected then
                    pending = true
                else
                    local moved = pcall(row.display.SetPoint, row.display,
                        "TOPLEFT", scrollContent, "TOPLEFT", 0, y)
                    if moved then row.position, row.step = position, step
                    else pending = true end
                end
            else
                row.display:ClearAllPoints()
                row.display:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, y)
                row.position, row.step = position, step
            end
        end
        if not positionsOnly then
            row.name:SetWidth(math.max(50, displayWidth - 49))
            for _, tick in ipairs({ row.executeOutline, row.executeLine }) do
                tick:ClearAllPoints()
                tick:SetPoint("CENTER", row.healthBar, "LEFT", healthWidth * 0.2, 0)
                tick:SetShown(showExecute)
            end
        end
    end
    UpdateScrollRange(height, present)
end

local function ApplyLayout(width, height)
    root:SetSize(width, height)
    if mover then mover:SetWidth(width - 35) end
    scrollFrame:SetWidth(width - 27)
    scrollFrame:SetHeight(height - 57)
    scrollContent:SetWidth(width - 27)
    scrollBar:SetHeight(height - 57)
    CompactRows(width, height)
end

local function ReflowRows()
    local width, height = root:GetSize()
    CompactRows(width, height, not Safe())
end

local function RefreshSourceAuras(unit)
    for _, row in ipairs(rows) do
        if row.unit == unit and row.auras and row.auras.UpdateAllAuras then
            pcall(row.auras.UpdateAllAuras, row.auras)
            break
        end
    end
end

local function CastTexture(spell)
    if not C_Spell or not C_Spell.GetSpellTexture then return nil end
    local identifiers = { spell.name }
    for _, id in ipairs(spell.ids) do identifiers[#identifiers + 1] = id end
    for _, identifier in ipairs(identifiers) do
        local ok, texture = pcall(C_Spell.GetSpellTexture, identifier)
        if ok and Plain(texture) and texture and texture ~= 134400
            and (type(texture) ~= "string"
                or not texture:lower():find("questionmark", 1, true)) then
            return texture
        end
    end
end

local function DotOrder(profile)
    local ordered, seen = {}, {}
    if type(profile.mainOrder) == "table" then
        for _, key in ipairs(profile.mainOrder) do
            for _, valid in ipairs(DOT_KEYS) do
                if key == valid and not seen[key] then
                    ordered[#ordered + 1], seen[key] = key, true
                    break
                end
            end
        end
    end
    for _, key in ipairs(DOT_KEYS) do
        if not seen[key] then ordered[#ordered + 1] = key end
    end
    local positions = {}
    for index, key in ipairs(ordered) do positions[key] = index end
    return positions
end

local function PlaceDot(icon, display, index, size)
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", display, "RIGHT",
        8 + (index - 1) * (size + 3), 0)
end

local function ApplyDotOrder(profile)
    local positions = DotOrder(profile)
    for _, row in ipairs(rows) do
        for _, entry in ipairs(row.dotVisuals) do
            PlaceDot(entry.icon, row.display, positions[entry.key], ICON_SIZE)
        end
    end
end

local function CreateAuraSlot(row, spell, index, size)
    local idSet = {}
    for _, id in ipairs(spell.ids) do idSet[id] = true end
    row.auras:AddAuraSlot(spell.name, "HARMFUL|PLAYER", {
        candidateFilters = { includeSpellIDs = idSet },
        initializeFrame = function(button)
            button:SetSize(size, size)
            PlaceDot(button, row.display, index, size)
            row.dotVisuals[#row.dotVisuals + 1] = {
                icon = button, key = DOT_KEYS[spell.slot] }
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(button)
            icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
            icon:SetDesaturated(Profile().colorActiveDoTs == false)
            button:SetIcon(icon)
            local texture = CastTexture(spell)
            if texture then
                local castIcon = button:CreateTexture(nil, "OVERLAY")
                castIcon:SetAllPoints(button)
                castIcon:SetTexture(texture)
                castIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP,
                    ICON_CROP, 1 - ICON_CROP)
                castIcon:SetDesaturated(Profile().colorActiveDoTs == false)
            end
            local cooldown = CreateFrame("Cooldown", nil, button,
                "CooldownFrameTemplate")
            cooldown:SetAllPoints(button)
            cooldown:SetDrawBling(false)
            cooldown:SetDrawEdge(false)
            cooldown:SetCountdownMillisecondsThreshold(spell.talentEffect and 10 or 0)
            if cooldown.SetCountdownAbbrevThreshold then
                cooldown:SetCountdownAbbrevThreshold(60)
            end
            if countdownFontReady and cooldown.SetCountdownFont then
                cooldown:SetCountdownFont(COUNTDOWN_FONT)
            end
            if spell.talentEffect and cooldown.GetCountdownFontString then
                local countdownText = cooldown:GetCountdownFontString()
                if countdownText then
                    countdownText:ClearAllPoints()
                    countdownText:SetSize(size, size)
                    countdownText:SetJustifyH("CENTER")
                    countdownText:SetJustifyV("MIDDLE")
                    countdownText:SetPoint("CENTER", button, "CENTER", 3, 0)
                end
            end
            if cooldown.SetSwipeColor then
                cooldown:SetSwipeColor(0, 0, 0, 0.58)
            end
            cooldown:SetReverse(true)
            button:SetDurationCooldown(cooldown)
            if spell.talentEffect and button.SetApplicationCount then
                local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                count:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
                count:SetSize(10, 9)
                count:SetJustifyH("LEFT")
                count:SetPoint("TOPLEFT", button, "TOPLEFT", 1, 0)
                button:SetApplicationCount(count, {})
            end
            -- Blizzard owns the aura button and its cooldown. No script
            -- handlers or insecure combat visibility changes are attached.
        end,
    })
end

local function WantsBrand(p)
    return p.multiDotDemonicBrand ~= false and WarlockHudRowVisibility
        and WarlockHudRowVisibility.KnowsDemonicBrand
        and WarlockHudRowVisibility.KnowsDemonicBrand() == true
end

local function RetireWindow()
    if visibilityDriver and UnregisterStateDriver then
        UnregisterStateDriver(visibilityController, "mtdvisibility")
    end
    visibilityDriver = false
    for _, row in ipairs(rows) do
        row.auras:SetEnabled(false)
        row.auras:Hide()
    end
    root:Hide()
    rows, root, visibilityController = {}, nil, nil
    built = false
end

local function Build()
    if built or not Safe() then pending = true; return false end
    local p = Profile()
    if not p or not api.IsAddonEnabled() then return false end
    builtBrand = WantsBrand(p)
    if builtBrand then
        DOT_KEYS[7] = "demonicbrand"
    else
        DOT_KEYS[7] = nil
    end
    DOT_SLOTS = #DOT_KEYS
    if not C_AddOns or not C_AddOns.LoadAddOn then return false end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        local loaded = C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        if not loaded then return false end
    end
    if CreateFont and not countdownFontReady then
        local font = CreateFont(COUNTDOWN_FONT)
        if font then
            font:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            font:SetShadowColor(0, 0, 0, 1)
            font:SetShadowOffset(1, -1)
            countdownFontReady = true
        end
    end

    local size = ICON_SIZE
    local width = ClampWidth(p.multiDotWidth or BASE_WIDTH * ClampScale(p.multiDotScale))
    local height = ClampHeight(p.multiDotHeight or BASE_HEIGHT * ClampScale(p.multiDotScale))
    buildCount = buildCount + 1
    local function FrameName(name)
        return buildCount == 1 and name or nil
    end
    root = CreateFrame("Frame", FrameName("WarlockHudMultiTargetWindow"), UIParent)
    root:SetSize(width, height)
    root:SetFrameStrata("MEDIUM")
    root:SetMovable(true)
    root:SetClampedToScreen(true)
    visibilityController = CreateFrame("Frame", nil, UIParent,
        "SecureHandlerStateTemplate")
    visibilityController:SetFrameRef("window", root)
    visibilityController:SetAttribute("_onstate-mtdvisibility", [[
        local window = self:GetFrameRef("window")
        if newstate == "show" then window:Show() else window:Hide() end
    ]])
    Position()
    local bg = root:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(root)
    bg:SetColorTexture(0.035, 0.035, 0.045, 0.88)
    local title = root:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", root, "TOPLEFT", 9, -8)
    title:SetText("Multi-Target DoTs (view only)")
    title:SetShadowColor(0, 0, 0, 1)
    title:SetShadowOffset(1, -1)
    status = root:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    status:SetPoint("TOPLEFT", root, "TOPLEFT", 10, -30)
    status:SetText("No engaged or dotted targets")
    status:SetShadowColor(0, 0, 0, 1)
    status:SetShadowOffset(1, -1)
    mover = CreateFrame("Button", FrameName("WarlockHudMultiTargetMove"), root)
    mover:SetSize(width - 35, 28)
    mover:SetPoint("TOPLEFT", root, "TOPLEFT")
    mover:SetFrameLevel(root:GetFrameLevel() + 1)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then root:StartMoving() end
    end)
    mover:SetScript("OnDragStop", function()
        if InCombatLockdown() then return end
        root:StopMovingOrSizing()
        local x, y = root:GetCenter()
        if Plain(x) and Plain(y) then
            local current = Profile()
            current.multiDotX = x / UIParent:GetWidth()
            current.multiDotY = y / UIParent:GetHeight()
            Position()
        end
    end)
    local close = CreateFrame("Button", FrameName("WarlockHudMultiTargetClose"), root)
    close:SetSize(27, 27)
    close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -3, -2)
    close:SetFrameLevel(root:GetFrameLevel() + 5)
    local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeText:SetAllPoints(close)
    closeText:SetText("X")
    close:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        Profile().multiDotEnabled = false
        ApplyAppearance()
    end)
    local resize = CreateFrame("Button", FrameName("WarlockHudMultiTargetResize"), root)
    resize:SetSize(19, 19)
    resize:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -2, 2)
    resize:SetFrameLevel(root:GetFrameLevel() + 5)
    resize:EnableMouse(true)
    resize:RegisterForDrag("LeftButton")
    local grip = resize:CreateTexture(nil, "ARTWORK")
    grip:SetAllPoints(resize)
    grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    local resizing, startX, startY, startWidth, startHeight = false
    resize:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        resizing = true
        startX, startY = GetCursorPosition()
        startWidth, startHeight = root:GetSize()
    end)
    resize:SetScript("OnUpdate", function()
        if not resizing then return end
        if InCombatLockdown() then resizing = false; return end
        local x, y = GetCursorPosition()
        if not Plain(x) or not Plain(y) then return end
        local scale = root:GetEffectiveScale()
        local newWidth = ClampWidth(startWidth + (x - startX) / scale)
        local newHeight = ClampHeight(startHeight - (y - startY) / scale)
        local currentWidth, currentHeight = root:GetSize()
        if newWidth == currentWidth and newHeight == currentHeight then return end
        local applied = pcall(ApplyLayout, newWidth, newHeight)
        if not applied then
            pending = true
            resizing = false
            return
        end
        local current = Profile()
        current.multiDotWidth, current.multiDotHeight = newWidth, newHeight
    end)
    resize:SetScript("OnDragStop", function() resizing = false end)
    scrollFrame = CreateFrame("ScrollFrame", FrameName("WarlockHudMultiTargetScroll"), root)
    scrollFrame:SetPoint("TOPLEFT", root, "TOPLEFT", 7, -50)
    scrollFrame:SetSize(width - 27, height - 57)
    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(width - 27, ROWS * ROW_HEIGHT)
    scrollFrame:SetScrollChild(scrollContent)
    scrollFrame:EnableMouseWheel(true)
    scrollBar = CreateFrame("Slider", FrameName("WarlockHudMultiTargetScrollBar"), root,
        "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -1, -50)
    scrollBar:SetHeight(height - 57)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValueStep(ROW_HEIGHT)
    scrollBar:SetScript("OnValueChanged", function(_, value)
        local ok = pcall(scrollFrame.SetVerticalScroll, scrollFrame, value)
        if not ok then pending = true end
    end)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        scrollBar:SetValue(scrollBar:GetValue() - delta * ROW_HEIGHT)
    end)
    scrollBar:Hide()
    for i, unit in ipairs(SOURCE_UNITS) do
        local display = CreateFrame("Frame", nil, scrollContent)
        display:SetSize(width - (DOT_SLOTS * (size + 3) + 38), size + 5)
        display:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0,
            -(i - 1) * ROW_HEIGHT)
        local background = display:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(display)
        background:SetColorTexture(0.055, 0.055, 0.065, 0.9)
        local portrait = display:CreateTexture(nil, "ARTWORK")
        portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
        portrait:SetPoint("LEFT", display, "LEFT", 8, 0)
        local marker = display:CreateTexture(nil, "OVERLAY")
        marker:SetSize(16, 16)
        marker:SetPoint("TOPRIGHT", portrait, "TOPRIGHT", 2, 2)
        marker:SetTexture(RAID_ICONS)
        marker:Hide()
        local healthBar = CreateFrame("StatusBar", nil, display)
        healthBar:SetPoint("BOTTOMLEFT", display, "BOTTOMLEFT", 44, 3)
        healthBar:SetPoint("BOTTOMRIGHT", display, "BOTTOMRIGHT", -4, 3)
        healthBar:SetHeight(11)
        healthBar:SetFrameLevel(display:GetFrameLevel())
        healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        healthBar:SetStatusBarColor(0.5, 0.15, 0.17, 0.9)
        local healthTrack = healthBar:CreateTexture(nil, "BACKGROUND")
        healthTrack:SetAllPoints(healthBar)
        healthTrack:SetColorTexture(0.025, 0.025, 0.03, 0.95)
        local executeOutline = healthBar:CreateTexture(nil, "OVERLAY", nil, -2)
        executeOutline:SetSize(5, 17)
        executeOutline:SetColorTexture(0, 0, 0, 1)
        local executeLine = healthBar:CreateTexture(nil, "OVERLAY", nil, -1)
        executeLine:SetSize(3, 17)
        executeLine:SetColorTexture(0.78, 0.43, 0.20, 1)
        healthBar:SetMinMaxValues(0, 1)
        healthBar:SetValue(0)
        local healthText = healthBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        healthText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
        healthText:SetTextColor(0.96, 0.96, 0.94)
        healthText:SetShadowColor(0, 0, 0, 1)
        healthText:SetShadowOffset(1, -1)
        healthText:SetText("")
        local name = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", display, "TOPLEFT", 45, -2)
        name:SetWidth(math.max(50, width - (DOT_SLOTS * (size + 3) + 67)))
        name:SetJustifyH("LEFT")
        name:SetTextColor(0.96, 0.96, 0.94)
        name:SetShadowColor(0, 0, 0, 1)
        name:SetShadowOffset(1, -1)
        if name.SetWordWrap then name:SetWordWrap(false) end
        local iconHolder = CreateFrame("Frame", nil, display)
        iconHolder:SetAllPoints(display)
        local selection = display:CreateTexture(nil, "OVERLAY")
        selection:SetSize(4, size + 5)
        selection:SetPoint("LEFT", display, "LEFT", 0, 0)
        selection:SetColorTexture(0.86, 0.66, 0.25, 0)
        local auras = CreateFrame("AuraContainer", nil, iconHolder,
            "CustomAuraContainerTemplate")
        auras:SetSize(DOT_SLOTS * (size + 3), size)
        auras:SetPoint("LEFT", display, "RIGHT", 7, 0)
        local source = i <= ROWS and "nameplate" or
            (i == ROWS + 1 and "target" or (i <= ROWS + 5 and "party" or "raid"))
        local row = { unit = unit, source = source,
            display = display, icons = iconHolder, name = name,
            healthBar = healthBar, healthText = healthText,
            executeOutline = executeOutline, executeLine = executeLine,
            portrait = portrait, marker = marker, target = selection, auras = auras,
            dotVisuals = {} }
        rows[i] = row
        local positions = DotOrder(p)
        for slot, key in ipairs(DOT_KEYS) do
            local preview = api.GetDotDefaultSpell(key)
            if not preview then
                for _, spell in ipairs(SPELLS) do
                    if spell.group ~= 2 and DOT_KEYS[spell.slot] == key
                        and (not p.enabled or p.enabled[spell.name] ~= false) then
                        preview = spell
                        break
                    end
                end
            end
            if preview and (not p.enabled or p.enabled[key] ~= false) then
                local idle = iconHolder:CreateTexture(nil, "ARTWORK")
                idle:SetSize(size, size)
                PlaceDot(idle, display, positions[key], size)
                row.dotVisuals[#row.dotVisuals + 1] = { icon = idle, key = key }
                idle:SetTexture(CastTexture(preview))
                idle:SetTexCoord(ICON_CROP, 1 - ICON_CROP,
                    ICON_CROP, 1 - ICON_CROP)
                idle:SetDesaturated(p.colorActiveDoTs ~= false)
                idle:SetAlpha(0.38)
            end
        end
        for _, spell in ipairs(SPELLS) do
            if spell.group ~= 2 and DOT_KEYS[spell.slot]
                and (not p.enabled or p.enabled[DOT_KEYS[spell.slot]] ~= false)
                and (not p.enabled or p.enabled[spell.name] ~= false) then
                CreateAuraSlot(row, spell, positions[DOT_KEYS[spell.slot]], size)
            end
        end
        auras:SetUnit(unit)
        auras:Show()
        auras:UpdateAllAuras()
        ClearIdentity(row)
        UpdateIdentity(row)
    end
    NormalizeRows()
    UpdateStatus()
    ApplyLayout(width, height)
    built, pending = true, false
    ApplyAppearance()
    return true
end

local function Refresh()
    local p = Profile()
    if not p then return false end
    if not Safe() then pending = true; return false end
    if built and WantsBrand(p) ~= builtBrand then RetireWindow() end
    if not built then return Build() end
    local width = ClampWidth(p.multiDotWidth or BASE_WIDTH * ClampScale(p.multiDotScale))
    local height = ClampHeight(p.multiDotHeight or BASE_HEIGHT * ClampScale(p.multiDotScale))
    ApplyLayout(width, height)
    ApplyDotOrder(p)
    Position()
    ApplyAppearance()
    pending = false
    return true
end

local function GuardedRefresh()
    if failed then return false end
    local ok, result = pcall(Refresh)
    if ok then return result end
    failed = true
    if root and not InCombatLockdown() then root:Hide() end
    print("Warlock HUD: Multi-Target window could not initialize: " .. tostring(result))
    return false
end

-- Temporary discovery probe. It reads unit identities only; it never scans
-- auras or changes the protected multi-target rows.
local probeFrame = CreateFrame("Frame")
local probeRunning, probeElapsed = false, 0
local probePrevious = {}
local function ProbeValue(fn, unit)
    if not fn then return nil end
    local ok, value = pcall(fn, unit)
    if not ok or not Plain(value) then return nil end
    return value
end
local function ProbeTokens()
    local tokens = { "target", "focus", "pettarget" }
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do tokens[#tokens + 1] = "raid" .. i .. "target" end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do tokens[#tokens + 1] = "party" .. i .. "target" end
    end
    for i = 1, 8 do tokens[#tokens + 1] = "boss" .. i end
    for i = 1, ROWS do tokens[#tokens + 1] = "nameplate" .. i end
    return tokens
end
local function ProbeEngagement(unit)
    local threat = GroupThreat(unit)
    local targeting = TargetsGroup(unit)
    local selected = TargetedByGroup(unit)
    local combat
    if UnitAffectingCombat then
        local ok, value = pcall(UnitAffectingCombat, unit)
        if ok and Plain(value) then combat = value end
    end
    local shown = false
    for _, row in ipairs(rows) do
        if row.unit == unit then shown = row.present == true; break end
    end
    local function Flag(value)
        return value == nil and "?" or (value and "1" or "0")
    end
    return "; threat=" .. Flag(threat)
        .. "; targetsGroup=" .. Flag(targeting)
        .. "; groupTargets=" .. Flag(selected)
        .. "; combat=" .. Flag(combat)
        .. "; shown=" .. Flag(shown)
end
local function ProbeSnapshot()
    local output = WarlockHudTraceHUD
    if not output then return end
    local nextState, found = {}, 0
    for _, unit in ipairs(ProbeTokens()) do
        if ProbeValue(UnitExists, unit) then
            local hostile = ProbeValue(UnitCanAttack and function(token)
                return UnitCanAttack("player", token)
            end, unit)
            if hostile then
                local name = ProbeValue(UnitName, unit)
                local guid = ProbeValue(UnitGUID, unit)
                local dead = ProbeValue(UnitIsDeadOrGhost, unit)
                local identity = (type(guid) == "string" and guid)
                    or (type(name) == "string" and name) or "unknown"
                local engagement = unit:match("^nameplate%d+$")
                    and ProbeEngagement(unit) or ""
                local state = identity .. (dead and " [dead]" or "") .. engagement
                nextState[unit] = state
                found = found + 1
                if probePrevious[unit] ~= state then
                    output("Unit probe: " .. unit .. " = "
                        .. (type(name) == "string" and name or "name restricted")
                        .. "; GUID=" .. (type(guid) == "string" and guid or "restricted")
                        .. (dead and "; dead" or "") .. engagement)
                end
            end
        end
    end
    for unit in pairs(probePrevious) do
        if not nextState[unit] then output("Unit probe: " .. unit .. " cleared") end
    end
    probePrevious = nextState
    return found
end
probeFrame:SetScript("OnUpdate", function(_, elapsed)
    if not probeRunning then return end
    probeElapsed = probeElapsed + elapsed
    if probeElapsed < 1 then return end
    probeElapsed = 0
    ProbeSnapshot()
end)

WarlockHudMultiTarget = {
    Refresh = GuardedRefresh,
    UpdateAppearance = ApplyAppearance,
    Toggle = function()
        if InCombatLockdown() then return false end
        local p = Profile()
        if not p then return false end
        p.multiDotEnabled = not p.multiDotEnabled
        if built then return ApplyAppearance() end
        if p.multiDotEnabled then return GuardedRefresh() end
        return true
    end,
    ProbeRunning = function() return probeRunning end,
    Probe = function(command)
        if WarlockHudOpenDebugTrace then WarlockHudOpenDebugTrace() end
        if not WarlockHudTraceHUD then return end
        if command == "toggle" then command = probeRunning and "off" or "on" end
        if command == "off" then
            probeRunning = false
            WarlockHudTraceHUD("Unit probe: stopped")
            return
        end
        probePrevious = {}
        probeElapsed = 0
        probeRunning = true
        WarlockHudTraceHUD("Unit probe: sampling hostile target, focus, pet/group targets, boss1-8, nameplate1-16 once per second; /whud unitprobe off to stop")
        local found = ProbeSnapshot()
        WarlockHudTraceHUD("Unit probe: " .. found .. " hostile tokens currently resolved")
    end,
    PrintTargets = function()
        if WarlockHudOpenDebugTrace then WarlockHudOpenDebugTrace() end
        if not WarlockHudTraceHUD then return end
        local targetOK, targetExists = pcall(UnitExists, "target")
        if targetOK and Plain(targetExists) and targetExists then
            local nameOK, targetName = pcall(UnitName, "target")
            WarlockHudTraceHUD("Multi-Target target: "
                .. (nameOK and Plain(targetName) and type(targetName) == "string"
                    and targetName or "name unavailable")
                .. "; GUID=" .. ReadableGuid("target")
                .. "; marker=" .. MarkerProbeResult("target"))
        end
        local count = 0
        for _, row in ipairs(rows) do
            if row.present then
                local ok, name = pcall(UnitName, row.unit)
                if not ok or not Plain(name) or type(name) ~= "string" then
                    name = "name unavailable"
                end
                local index, source = RaidMarkerFor(row.unit)
                WarlockHudTraceHUD("Multi-Target: " .. row.unit .. " = " .. name
                    .. "; GUID=" .. ReadableGuid(row.unit)
                    .. "; direct marker=" .. MarkerProbeResult(row.unit)
                    .. "; raid marker=" .. (index and tostring(index) or "none/read restricted")
                    .. "; render=" .. tostring(row.markerMode)
                    .. (source and (" via " .. source) or ""))
                count = count + 1
            end
        end
        if count == 0 then
            WarlockHudTraceHUD("Multi-Target: no visible rows")
        end
    end,
    Debug = function()
        local output = WarlockHudTraceHUD
        if not output then return end
        output("Multi-Target: " .. (built and "built" or "not built")
            .. "; read-only; combat: " .. tostring(InCombatLockdown()))
        for _, row in ipairs(rows) do
            if row.present then
                local ok, name = pcall(UnitName, row.unit)
                if not ok or not Plain(name) or type(name) ~= "string" then
                    name = "name unavailable"
                end
                output(row.unit .. " = " .. name
                    .. "; relevant=" .. tostring(row.relevant))
            end
        end
    end,
}

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED",
    "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "UNIT_PORTRAIT_UPDATE", "PORTRAITS_UPDATED",
    "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE", "GROUP_ROSTER_UPDATE",
    "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE",
    "UNIT_AURA", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_FLAGS",
    "UNIT_TARGET" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED"
        or event == "ACTIVE_TALENT_GROUP_CHANGED"
        or event == "PLAYER_TALENT_UPDATE" or event == "SPELLS_CHANGED" then
        if pending or event ~= "PLAYER_REGEN_ENABLED" then GuardedRefresh() end
    end
    if not built then return end
    if event == "PLAYER_REGEN_DISABLED" then
        ApplyAppearance()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        ApplyAppearance()
        for _, row in ipairs(rows) do UpdateIdentity(row) end
        NormalizeRows()
        UpdateStatus()
        ReflowRows()
    elseif event == "UNIT_PORTRAIT_UPDATE" or event == "PORTRAITS_UPDATED" then
        if event == "PORTRAITS_UPDATED" then
            for _, row in ipairs(rows) do UpdatePortrait(row) end
        elseif Plain(unit) and type(unit) == "string" then
            for _, row in ipairs(rows) do
                if row.unit == unit then UpdatePortrait(row); break end
            end
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" or event == "NAME_PLATE_UNIT_ADDED" then
        if not Plain(unit) then return end
        for _, row in ipairs(rows) do
            if row.unit == unit then
                -- A newly assigned token may refer to a different mob.
                ClearIdentity(row)
                if event == "NAME_PLATE_UNIT_ADDED" then UpdateIdentity(row) end
                -- The token may now denote another creature. Ask Blizzard's
                -- container to discard any aura display from its old occupant.
                if row.auras and row.auras.UpdateAllAuras then
                    local refreshed = pcall(row.auras.UpdateAllAuras, row.auras)
                    if not refreshed and not auraWarning then
                        auraWarning = true
                        print("Warlock HUD: Multi-Target native aura refresh was blocked; report this with /whub debug.")
                    end
                end
                break
            end
        end
        NormalizeRows()
        UpdateStatus()
        ReflowRows()
    elseif event == "PLAYER_TARGET_CHANGED" or event == "RAID_TARGET_UPDATE"
        or event == "GROUP_ROSTER_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE"
        or event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_AURA"
        or event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH"
        or event == "UNIT_FLAGS" or event == "UNIT_TARGET" then
        if (event == "UNIT_AURA" or event == "UNIT_HEALTH"
            or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS"
            or event == "UNIT_TARGET")
            and (not Plain(unit) or type(unit) ~= "string"
            or (event ~= "UNIT_TARGET" and not unit:match("^nameplate%d+$")
                and not unit:match("^party%d+target$")
                and not unit:match("^raid%d+target$")
                and unit ~= "target"))
            then return end
        if event == "PLAYER_TARGET_CHANGED" then
            RefreshSourceAuras("target")
        elseif event == "UNIT_TARGET" and Plain(unit) and type(unit) == "string" then
            RefreshSourceAuras(unit .. "target")
        end
        if event ~= "UNIT_TARGET" and Plain(unit) and type(unit) == "string"
            and unit:match("^nameplate%d+$") then
            for _, row in ipairs(rows) do
                if row.unit == unit then UpdateIdentity(row); break end
            end
        else
            for _, row in ipairs(rows) do UpdateIdentity(row) end
        end
        NormalizeRows()
        UpdateStatus()
        ReflowRows()
    end
end)
