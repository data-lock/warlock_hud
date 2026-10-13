-- Eight fixed nameplate-token rows. Protected frames and aura slots are built
-- only outside combat. A row is never rebound to a different token.
local api = WarlockHudAPI
local rows = {}
local root
local built, pending, auraWarning, failed = false, false, false, false
local ROWS = 8
local ICON_SIZE = 24
local SPELLS = {
    { "Corruption", { 172, 6222, 6223, 7648, 11671, 11672, 25311 } },
    { "Immolate", { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 } },
    { "Siphon Life", { 18265, 18879, 18880, 18881 } },
    { "Banes", { 980, 1014, 6217, 11711, 11712, 11713, 603,
        1225228, 1243339 } },
}
local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local function ClampScale(value)
    return math.max(0.7, math.min(1.6, tonumber(value) or 1))
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
    row.name:SetText("")
    row.marker:Hide()
    row.engaged:SetText("")
    row.target:SetColorTexture(0.25, 0.25, 0.25, 0.8)
end

local function UpdateIdentity(row)
    -- Do not leave the prior occupant's name or marker when a token is reused.
    ClearIdentity(row)
    local unit = row.unit
    local existsOK, exists = pcall(UnitExists, unit)
    if not existsOK or not Plain(exists) or not exists then return end
    local ok, name = pcall(UnitName, unit)
    if ok then
        -- FontString:SetText accepts secret strings; never inspect the name.
        row.name:SetText(name)
    end
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
    if UnitThreatSituation then
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
            if existsOK and Plain(memberExists) and memberExists then
                local threatOK, status = pcall(UnitThreatSituation, member, unit)
                if threatOK and Plain(status) and type(status) == "number" then
                    row.engaged:SetText("Group")
                    break
                end
            end
        end
    end
end

local function CreateAuraSlot(row, spell, index, size)
    local idSet = {}
    for _, id in ipairs(spell[2]) do idSet[id] = true end
    row.auras:AddAuraSlot(spell[1], "HARMFUL|PLAYER", {
        candidateFilters = { includeSpellIDs = idSet },
        initializeFrame = function(button)
            button:SetSize(size, size)
            button:ClearAllPoints()
            button:SetPoint("LEFT", row.button, "RIGHT", 8 + (index - 1) * (size + 3), 0)
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(button)
            button:SetIcon(icon)
            if index < 4 and C_Spell and C_Spell.GetSpellTexture then
                local ok, texture = pcall(C_Spell.GetSpellTexture, spell[2][1])
                if ok and Plain(texture) and texture and texture ~= 134400 then
                    local castIcon = button:CreateTexture(nil, "OVERLAY")
                    castIcon:SetAllPoints(button)
                    castIcon:SetTexture(texture)
                end
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
    local width = 190 + 4 * (size + 3)
    local height = ROWS * (size + 9) + 32
    root = CreateFrame("Frame", "WarlockHudMultiTargetWindow", UIParent)
    root:SetSize(width, height)
    root:SetFrameStrata("MEDIUM")
    root:SetMovable(true)
    root:SetClampedToScreen(true)
    root:SetScale(ClampScale(p.multiDotScale))
    Position()
    local bg = root:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(root)
    bg:SetColorTexture(0.05, 0.04, 0.07, 0.78)
    local title = root:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", root, "TOPLEFT", 9, -8)
    title:SetText("Multi-Target DoTs")
    local mover = CreateFrame("Button", "WarlockHudMultiTargetMove", root)
    mover:SetSize(width - 35, 28)
    mover:SetPoint("TOPLEFT", root, "TOPLEFT")
    mover:SetFrameLevel(root:GetFrameLevel() + 1)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function()
        if Safe() then root:StartMoving() end
    end)
    mover:SetScript("OnDragStop", function()
        if not Safe() then return end
        root:StopMovingOrSizing()
        local x, y = root:GetCenter()
        if Plain(x) and Plain(y) then
            local current = Profile()
            current.multiDotX = x / UIParent:GetWidth()
            current.multiDotY = y / UIParent:GetHeight()
        end
    end)
    local close = CreateFrame("Button", "WarlockHudMultiTargetClose", root,
        "UIPanelCloseButton")
    close:SetSize(27, 27)
    close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -3, -2)
    close:SetFrameLevel(root:GetFrameLevel() + 5)
    close:SetScript("OnClick", function()
        Profile().multiDotEnabled = false
        if Safe() then
            WarlockHudMultiTarget.Refresh()
        else
            pending = true
            print("Warlock HUD: Multi-Target window will close after combat.")
        end
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
    local resizing, startCursor, startScale = false, nil, nil
    resize:SetScript("OnDragStart", function()
        if not Safe() then return end
        resizing = true
        startCursor = GetCursorPosition()
        startScale = ClampScale(Profile().multiDotScale)
    end)
    resize:SetScript("OnUpdate", function()
        if not resizing then return end
        if not Safe() then resizing = false; return end
        local cursor = GetCursorPosition()
        if not Plain(cursor) then return end
        local parentScale = UIParent:GetEffectiveScale()
        local scale = ClampScale(startScale
            + (cursor - startCursor) / (width * parentScale))
        root:SetScale(scale)
        Profile().multiDotScale = scale
    end)
    resize:SetScript("OnDragStop", function() resizing = false end)
    for i = 1, ROWS do
        local unit = "nameplate" .. i
        local button = CreateFrame("Button", "WarlockHudMultiTarget" .. i,
            root, "SecureActionButtonTemplate")
        button:SetSize(184, size + 5)
        button:SetPoint("TOPLEFT", root, "TOPLEFT", 7, -30 - (i - 1) * (size + 9))
        button:RegisterForClicks("AnyUp")
        button:SetAttribute("type1", "target")
        button:SetAttribute("unit", unit)
        -- Secure macro conditions handle combat visibility; addon Lua never
        -- calls Show/Hide on a protected row for a nameplate event.
        RegisterStateDriver(button, "visibility",
            "[@" .. unit .. ",exists,harm,nodead] show; hide")
        local highlight = button:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints(button)
        highlight:SetColorTexture(0.25, 0.25, 0.25, 0.8)
        local marker = button:CreateTexture(nil, "ARTWORK")
        marker:SetSize(17, 17)
        marker:SetPoint("LEFT", button, "LEFT", 3, 0)
        marker:SetTexture(RAID_ICONS)
        marker:Hide()
        local name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("LEFT", button, "LEFT", 24, 0)
        name:SetWidth(120)
        name:SetJustifyH("LEFT")
        local engaged = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        engaged:SetPoint("RIGHT", button, "RIGHT", -3, 0)
        local auras = CreateFrame("AuraContainer", nil, button,
            "CustomAuraContainerTemplate")
        auras:SetSize(4 * (size + 3), size)
        auras:SetPoint("LEFT", button, "RIGHT", 7, 0)
        local row = { unit = unit, button = button, name = name,
            marker = marker, engaged = engaged, target = highlight, auras = auras }
        rows[i] = row
        for slot, spell in ipairs(SPELLS) do CreateAuraSlot(row, spell, slot, size) end
        auras:SetUnit(unit)
        auras:Show()
        auras:UpdateAllAuras()
        ClearIdentity(row)
        UpdateIdentity(row)
    end
    built, pending = true, false
    root:SetShown(p.multiDotEnabled)
    return true
end

local function Refresh()
    local p = Profile()
    if not p then return false end
    if not built then return Build() end
    if not Safe() then pending = true; return false end
    root:SetScale(ClampScale(p.multiDotScale))
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
}

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED",
    "ACTIVE_TALENT_GROUP_CHANGED",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE", "GROUP_ROSTER_UPDATE",
    "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE" }) do
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
    elseif event == "PLAYER_TARGET_CHANGED" or event == "RAID_TARGET_UPDATE"
        or event == "GROUP_ROSTER_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE"
        or event == "UNIT_THREAT_SITUATION_UPDATE" then
        if Plain(unit) and type(unit) == "string"
            and unit:match("^nameplate%d+$") then
            for _, row in ipairs(rows) do
                if row.unit == unit then UpdateIdentity(row); break end
            end
        else
            for _, row in ipairs(rows) do UpdateIdentity(row) end
        end
    end
end)
