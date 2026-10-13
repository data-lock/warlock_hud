-- Eight fixed nameplate-token display rows. Aura slots are built only outside
-- combat. Nameplate unit tokens cannot be used as secure click targets.
local api = WarlockHudAPI
local rows = {}
local root
local status
local mover
local built, pending, auraWarning, failed = false, false, false, false
local ROWS = 8
local ICON_SIZE = 24
local BASE_WIDTH, BASE_HEIGHT = 430, 316
local SPELLS = api.Spells
local DOT_KEYS = api.MainKeys
local DOT_SLOTS = #DOT_KEYS
local ICON_CROP = (1 - 1 / 1.3) / 2
local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local function ClampScale(value)
    return math.max(0.7, math.min(1.6, tonumber(value) or 1))
end

local function ClampWidth(value)
    return math.max(260, math.min(700, tonumber(value) or BASE_WIDTH))
end

local function ClampHeight(value)
    return math.max(287, math.min(640, tonumber(value) or BASE_HEIGHT))
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

local function Position()
    if not root then return end
    local p = Profile()
    root:ClearAllPoints()
    if type(p.multiDotX) == "number" and type(p.multiDotY) == "number" then
        root:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            p.multiDotX * UIParent:GetWidth(), p.multiDotY * UIParent:GetHeight())
    else
        root:SetPoint("CENTER", UIParent, "CENTER", 320, 0)
    end
end

local function ClearIdentity(row)
    row.present = false
    row.relevant = false
    row.name:SetText("")
    if row.healthBar then
        pcall(row.healthBar.SetMinMaxValues, row.healthBar, 0, 1)
        pcall(row.healthBar.SetValue, row.healthBar, 0)
    end
    row.name:SetTextColor(0.45, 0.45, 0.45)
    row.marker:Hide()
    row.target:SetColorTexture(0.08, 0.08, 0.08, 0)
end

local function UpdateHealth(row, name)
    if not UnitHealth or not UnitHealthMax or not UnitHealthPercent
        or not CurveConstants or not CurveConstants.ScaleTo100 then
        row.name:SetText(name)
        return
    end
    local healthOK, health = pcall(UnitHealth, row.unit, true)
    local maxOK, maximum = pcall(UnitHealthMax, row.unit)
    local percentOK, percent = pcall(UnitHealthPercent, row.unit, true,
        CurveConstants.ScaleTo100)
    if not healthOK or not maxOK or not percentOK then
        row.name:SetText(name)
        return
    end
    local function Numeric(value)
        return (issecretvalue and issecretvalue(value))
            or type(value) == "number"
    end
    if not Numeric(health) or not Numeric(maximum) or not Numeric(percent) then
        row.name:SetText(name)
        return
    end
    -- These values may be secret. Native widgets accept them directly; Lua
    -- never compares, divides, concatenates, or formats them.
    pcall(row.healthBar.SetMinMaxValues, row.healthBar, 0, maximum)
    pcall(row.healthBar.SetValue, row.healthBar, health)
    local formatted = pcall(row.name.SetFormattedText, row.name,
        "%s (%.0f/%.0f) %.0f%%", name, health, maximum, percent)
    if not formatted then row.name:SetText(name) end
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

local function UpdateIdentity(row)
    -- Do not leave the prior occupant's name or marker when a token is reused.
    ClearIdentity(row)
    local unit = row.unit
    local existsOK, exists = pcall(UnitExists, unit)
    if not existsOK or not Plain(exists) or not exists then return end
    if UnitIsDeadOrGhost then
        local deadOK, dead = pcall(UnitIsDeadOrGhost, unit)
        if deadOK and Plain(dead) and dead then return end
    end
    row.present = true
    local threat, dot = GroupThreat(unit), OwnDot(unit)
    if threat == true or dot == true then
        row.relevant = true
    elseif threat == false and dot == false then
        row.relevant = false
    else
        row.relevant = nil
    end
    if row.relevant == true then
        row.name:SetTextColor(1, 1, 1)
        row.target:SetColorTexture(0.25, 0.25, 0.25, 0.8)
    elseif row.relevant == nil then
        row.name:SetTextColor(0.5, 0.5, 0.5)
        row.target:SetColorTexture(0.1, 0.1, 0.1, 0.55)
    end
    local ok, name = pcall(UnitName, unit)
    if ok then UpdateHealth(row, name) end
    if GetRaidTargetIndex then
        local markerOK, index = pcall(GetRaidTargetIndex, unit)
        if markerOK and Plain(index) and type(index) == "number"
            and index >= 1 and index <= 8 then
            local column = (index - 1) % 4
            local line = math.floor((index - 1) / 4)
            row.marker:SetTexCoord(column * 0.25, (column + 1) * 0.25,
                line * 0.25, (line + 1) * 0.25)
            row.marker:Show()
        end
    end
    local targetOK, selected = pcall(UnitIsUnit, unit, "target")
    if targetOK and Plain(selected) and selected == true then
        row.target:SetColorTexture(1, 0.7, 0.1, 1)
    end
end

local function UpdateStatus()
    if not status then return end
    local count, relevant = 0, 0
    for _, row in ipairs(rows) do
        if row.present then
            count = count + 1
            if row.relevant == true then relevant = relevant + 1 end
        end
    end
    if count == 0 then
        status:SetText("No visible live targets")
    else
        status:SetText("Relevant: " .. relevant .. " / " .. count
            .. " visible (other rows dimmed)")
    end
end

local function CompactRows(width, height)
    local displayWidth = width - (DOT_SLOTS * (ICON_SIZE + 3) + 18)
    local step = (height - 84) / (ROWS - 1)
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
        row.display:SetWidth(displayWidth)
        row.display:ClearAllPoints()
        row.display:SetPoint("TOPLEFT", root, "TOPLEFT", 7,
            -50 - (position - 1) * step)
        row.name:SetWidth(math.max(65, displayWidth - 28))
    end
end

local function ApplyLayout(width, height)
    root:SetSize(width, height)
    if mover then mover:SetWidth(width - 35) end
    CompactRows(width, height)
end

local function ReflowRows()
    if not Safe() then pending = true; return end
    local width, height = root:GetSize()
    CompactRows(width, height)
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

local function CreateAuraSlot(row, spell, index, size)
    local idSet = {}
    for _, id in ipairs(spell.ids) do idSet[id] = true end
    row.auras:AddAuraSlot(spell.name, "HARMFUL|PLAYER", {
        candidateFilters = { includeSpellIDs = idSet },
        initializeFrame = function(button)
            button:SetSize(size, size)
            button:ClearAllPoints()
            button:SetPoint("LEFT", row.display, "RIGHT", 8 + (index - 1) * (size + 3), 0)
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
            cooldown:SetCountdownMillisecondsThreshold(10)
            cooldown:SetReverse(true)
            button:SetDurationCooldown(cooldown)
            -- Blizzard owns the aura button and its cooldown. No script
            -- handlers or insecure combat visibility changes are attached.
        end,
    })
end

local function Build()
    if built or not Safe() then pending = true; return false end
    local p = Profile()
    if not p or not api.IsAddonEnabled() then return false end
    if not C_AddOns or not C_AddOns.LoadAddOn then return false end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        local loaded = C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        if not loaded then return false end
    end

    local size = ICON_SIZE
    local width = ClampWidth(p.multiDotWidth or BASE_WIDTH * ClampScale(p.multiDotScale))
    local height = ClampHeight(p.multiDotHeight or BASE_HEIGHT * ClampScale(p.multiDotScale))
    root = CreateFrame("Frame", "WarlockHudMultiTargetWindow", UIParent)
    root:SetSize(width, height)
    root:SetFrameStrata("MEDIUM")
    root:SetMovable(true)
    root:SetClampedToScreen(true)
    Position()
    local bg = root:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(root)
    bg:SetColorTexture(0.05, 0.04, 0.07, 0.78)
    local title = root:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", root, "TOPLEFT", 9, -8)
    title:SetText("Multi-Target DoTs (view only)")
    status = root:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    status:SetPoint("TOPLEFT", root, "TOPLEFT", 10, -30)
    status:SetText("No visible live targets")
    mover = CreateFrame("Button", "WarlockHudMultiTargetMove", root)
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
        end
    end)
    local close = CreateFrame("Button", "WarlockHudMultiTargetClose", root,
        "SecureHandlerClickTemplate")
    close:SetSize(27, 27)
    close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -3, -2)
    close:SetFrameLevel(root:GetFrameLevel() + 5)
    close:RegisterForClicks("AnyUp")
    close:SetFrameRef("window", root)
    close:SetAttribute("_onclick", 'self:GetFrameRef("window"):Hide()')
    local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeText:SetAllPoints(close)
    closeText:SetText("X")
    close:HookScript("OnClick", function()
        Profile().multiDotEnabled = false
    end)
    local resize = CreateFrame("Button", "WarlockHudMultiTargetResize", root)
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
        ApplyLayout(newWidth, newHeight)
        local current = Profile()
        current.multiDotWidth, current.multiDotHeight = newWidth, newHeight
    end)
    resize:SetScript("OnDragStop", function() resizing = false end)
    for i = 1, ROWS do
        local unit = "nameplate" .. i
        local display = CreateFrame("Frame", nil, root)
        display:SetSize(width - (DOT_SLOTS * (size + 3) + 18), size + 5)
        display:SetPoint("TOPLEFT", root, "TOPLEFT", 7,
            -50 - (i - 1) * ((height - 84) / (ROWS - 1)))
        local highlight = display:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints(display)
        highlight:SetColorTexture(0.25, 0.25, 0.25, 0.8)
        local marker = display:CreateTexture(nil, "ARTWORK")
        marker:SetSize(17, 17)
        marker:SetPoint("LEFT", display, "LEFT", 3, 0)
        marker:SetTexture(RAID_ICONS)
        marker:Hide()
        local healthBar = CreateFrame("StatusBar", nil, display)
        healthBar:SetPoint("LEFT", display, "LEFT", 22, 0)
        healthBar:SetPoint("RIGHT", display, "RIGHT", -3, 0)
        healthBar:SetHeight(19)
        healthBar:SetFrameLevel(display:GetFrameLevel())
        healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        healthBar:SetStatusBarColor(0.35, 0.07, 0.07, 0.75)
        healthBar:SetMinMaxValues(0, 1)
        healthBar:SetValue(0)
        local name = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("LEFT", display, "LEFT", 24, 0)
        name:SetWidth(math.max(65, width - (DOT_SLOTS * (size + 3) + 46)))
        name:SetJustifyH("LEFT")
        local auras = CreateFrame("AuraContainer", nil, display,
            "CustomAuraContainerTemplate")
        auras:SetSize(DOT_SLOTS * (size + 3), size)
        auras:SetPoint("LEFT", display, "RIGHT", 7, 0)
        local row = { unit = unit, display = display, name = name,
            healthBar = healthBar,
            marker = marker, target = highlight, auras = auras }
        rows[i] = row
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
                local idle = display:CreateTexture(nil, "ARTWORK")
                idle:SetSize(size, size)
                idle:SetPoint("LEFT", display, "RIGHT",
                    8 + (slot - 1) * (size + 3), 0)
                idle:SetTexture(CastTexture(preview))
                idle:SetTexCoord(ICON_CROP, 1 - ICON_CROP,
                    ICON_CROP, 1 - ICON_CROP)
                idle:SetDesaturated(p.colorActiveDoTs ~= false)
            end
        end
        for _, spell in ipairs(SPELLS) do
            if spell.group ~= 2
                and (not p.enabled or p.enabled[DOT_KEYS[spell.slot]] ~= false)
                and (not p.enabled or p.enabled[spell.name] ~= false) then
                CreateAuraSlot(row, spell, spell.slot, size)
            end
        end
        auras:SetUnit(unit)
        auras:Show()
        auras:UpdateAllAuras()
        ClearIdentity(row)
        UpdateIdentity(row)
    end
    UpdateStatus()
    ApplyLayout(width, height)
    built, pending = true, false
    root:SetShown(p.multiDotEnabled)
    return true
end

local function Refresh()
    local p = Profile()
    if not p then return false end
    if not built then return Build() end
    if not Safe() then pending = true; return false end
    local width = ClampWidth(p.multiDotWidth or BASE_WIDTH * ClampScale(p.multiDotScale))
    local height = ClampHeight(p.multiDotHeight or BASE_HEIGHT * ClampScale(p.multiDotScale))
    ApplyLayout(width, height)
    Position()
    root:SetShown(p.multiDotEnabled and api.IsAddonEnabled())
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

WarlockHudMultiTarget = {
    Refresh = GuardedRefresh,
    Debug = function()
        local output = WarlockHudTraceHUD or print
        output("Multi-Target: " .. (built and "built" or "not built")
            .. "; read-only; combat: " .. tostring(InCombatLockdown()))
        for _, row in ipairs(rows) do
            if row.present then
                output(row.unit .. ": relevant=" .. tostring(row.relevant))
            end
        end
    end,
}

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED",
    "ACTIVE_TALENT_GROUP_CHANGED",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE", "GROUP_ROSTER_UPDATE",
    "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE",
    "UNIT_AURA", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_FLAGS" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED"
        or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if pending or event ~= "PLAYER_REGEN_ENABLED" then GuardedRefresh() end
    end
    if not built then return end
    if event == "NAME_PLATE_UNIT_REMOVED" or event == "NAME_PLATE_UNIT_ADDED" then
        if not Plain(unit) then return end
        for _, row in ipairs(rows) do
            if row.unit == unit then
                if event == "NAME_PLATE_UNIT_REMOVED" then ClearIdentity(row)
                else UpdateIdentity(row) end
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
        UpdateStatus()
        ReflowRows()
    elseif event == "PLAYER_TARGET_CHANGED" or event == "RAID_TARGET_UPDATE"
        or event == "GROUP_ROSTER_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE"
        or event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_AURA"
        or event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH"
        or event == "UNIT_FLAGS" then
        if (event == "UNIT_AURA" or event == "UNIT_HEALTH"
            or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS")
            and (not Plain(unit) or type(unit) ~= "string"
            or not unit:match("^nameplate%d+$")) then return end
        if Plain(unit) and type(unit) == "string"
            and unit:match("^nameplate%d+$") then
            for _, row in ipairs(rows) do
                if row.unit == unit then UpdateIdentity(row); break end
            end
        else
            for _, row in ipairs(rows) do UpdateIdentity(row) end
        end
        UpdateStatus()
        if event == "UNIT_FLAGS" or event == "UNIT_HEALTH" then
            ReflowRows()
        end
    end
end)
