-- Fixed nameplate and group-target display sources, with up to sixteen visible
-- rows. Aura slots are built only outside combat. The view is not clickable.
local api = WarlockHudAPI
local rows = {}
local root
local status
local damageDebug = true
local mover
local scrollFrame, scrollContent, scrollBar
local visibilityController
local visibilityDriver = false
local built, pending, auraWarning, failed = false, false, false, false
local builtTimerMilliseconds
local builtFontFace, builtFontSize, builtTimerFontSize
local buildCount = 0
local ROWS = 16
local SOURCE_UNITS = {}
for i = 1, ROWS do SOURCE_UNITS[#SOURCE_UNITS + 1] = "nameplate" .. i end
SOURCE_UNITS[#SOURCE_UNITS + 1] = "target"
for i = 1, 4 do SOURCE_UNITS[#SOURCE_UNITS + 1] = "party" .. i .. "target" end
for i = 1, 40 do SOURCE_UNITS[#SOURCE_UNITS + 1] = "raid" .. i .. "target" end
local LIVE_UNITS = #SOURCE_UNITS
for i = 1, ROWS do SOURCE_UNITS[#SOURCE_UNITS + 1] = "ghost" .. i end
local ICON_SIZE = 24
local ROW_HEIGHT = 29
local PORTRAIT_SIZE = 26
local BASE_WIDTH, BASE_HEIGHT = 430, 548
local COUNTDOWN_FONT = "WarlockHudMultiDotCountdownFont"
local countdownFontReady = false
local SPELLS = api.Spells
local DOT_KEYS = {}
local DOT_SLOTS = 0
local SLOT_KEYS = api.MainKeys
local ICON_CROP = (1 - 1 / 1.3) / 2
local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local function ClampScale(value)
    return math.max(0.7, math.min(1.6, tonumber(value) or 1))
end

local function ClampWidth(value)
    local minimum = math.max(390, DOT_SLOTS * (ICON_SIZE + 3) + 305)
    return math.max(minimum, math.min(700, tonumber(value) or BASE_WIDTH))
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
    if Safe() then
        local showThreat = p.multiDotThreatIndicator ~= false
        for _, row in ipairs(rows) do
            row.threatLabel:SetShown(showThreat)
            row.threatDot:SetShown(showThreat)
            row.name:SetWidth(math.max(42, row.display:GetWidth()
                - (showThreat and 223 or 168)))
        end
    end
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

local lastSeen = {}
local damage
local identity = WarlockHudMultiTargetIdentity.New(function() return rows end,
    SPELLS, ROWS, Plain, function(guid, name, row)
        lastSeen[guid] = { name = name, seen = GetTime(),
            health = row.snapshotHealth, maximum = row.snapshotMaximum,
            percent = row.snapshotPercent, portrait = row.snapshotPortrait }
    end, function(guid)
        return damage and damage.RemainingForGuid(guid) > 0
    end, function(unit)
        if not UnitGUID then return end
        local ok, guid = pcall(UnitGUID, unit)
        if not ok or not Plain(guid) or type(guid) ~= "string" then return end
        lastSeen[guid] = nil
        if damage then damage.ForgetGuid(guid) end
    end)
local ClearIdentity = identity.ClearIdentity
local GroupThreat = identity.GroupThreat
local TargetsGroup = identity.TargetsGroup
local TargetedByGroup = identity.TargetedByGroup
local UpdatePortrait = identity.UpdatePortrait
local MarkerProbeResult = identity.MarkerProbeResult
local ReadableGuid = identity.ReadableGuid
local RaidMarkerFor = identity.RaidMarkerFor
local UpdateIdentity = identity.UpdateIdentity
local NormalizeRows = identity.NormalizeRows
damage = WarlockHudMultiTargetDamage.New(function() return rows end,
    ReadableGuid)

local function UpdateGhostRows()
    local ghostRows, liveGuids, liveCount = {}, {}, 0
    local changed = false
    for _, row in ipairs(rows) do
        if row.source == "ghost" then
            ghostRows[#ghostRows + 1] = row
        elseif row.present then
            liveCount = liveCount + 1
            local guid = ReadableGuid(row.unit)
            if guid == "unavailable" and row.source == "nameplate" then
                guid = row.lastGuid
            end
            if guid then liveGuids[guid] = true end
        end
    end
    local candidates = {}
    if InCombatLockdown() and Profile().multiDotDamageEnabled ~= false then
        for guid, seen in pairs(lastSeen) do
            local remaining = damage.RemainingForGuid(guid)
            if remaining <= 0 and not liveGuids[guid] then
                lastSeen[guid] = nil
            elseif remaining > 0 and not liveGuids[guid] then
                candidates[#candidates + 1] = {
                    guid = guid, name = seen.name, seen = seen.seen,
                    remaining = remaining, health = seen.health,
                    maximum = seen.maximum, percent = seen.percent,
                    portrait = seen.portrait }
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.seen == b.seen then return a.guid < b.guid end
        return a.seen > b.seen
    end)
    for i, row in ipairs(ghostRows) do
        local ghost = i <= ROWS - liveCount and candidates[i]
        if ghost then
            if row.ghostGuid ~= ghost.guid or not row.present then changed = true end
            row.ghostGuid = ghost.guid
            row.present = true
            row.display:SetAlpha(0.55)
            row.name:SetText(ghost.name)
            if row.SetThreat then row:SetThreat("UNKNOWN") end
            row.name:SetTextColor(0.62, 0.62, 0.62)
            local dotLabel = WarlockHudMultiTargetIdentity.FormatNumber(
                ghost.remaining)
            local healthLabel = WarlockHudMultiTargetIdentity.FormatNumber(
                ghost.health)
            local healthOK = ghost.maximum and ghost.health
                and pcall(row.healthBar.SetMinMaxValues, row.healthBar,
                    0, ghost.maximum)
            healthOK = healthOK and pcall(row.healthBar.SetValue,
                row.healthBar, ghost.health)
            if not healthOK then row.healthBar:SetValue(0) end
            row.healthBar:SetStatusBarColor(0.5, 0.5, 0.5, 0.8)
            local textOK = healthLabel and ghost.percent and pcall(
                row.healthText.SetFormattedText, row.healthText,
                "%s %.0f%% (DoT %s)", healthLabel, ghost.percent, dotLabel)
            if not textOK then
                row.healthText:SetText("DoT " .. dotLabel .. " (last seen)")
            end
            row.icons:SetAlpha(0.65)
            local estimates = damage.EstimatesForGuid(ghost.guid)
            local byKey = {
                corruption = estimates["Corruption"] or 0,
                bane = estimates["Bane of Agony"] or 0,
                siphonlife = estimates["Siphon Life"] or 0,
                immolate = estimates["Immolate"] or 0,
                curse = estimates["Curse of the Elements"] or 0,
            }
            for _, entry in ipairs(row.dotVisuals) do
                entry.icon:SetAlpha((byKey[entry.key] or 0) > 0 and 0.9 or 0.18)
                entry.icon:SetDesaturated(true)
            end
            row.portrait:SetTexture(ghost.portrait
                or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.portraitCover:SetAlpha(0)
        elseif row.present then
            changed = true
            row.ghostGuid = nil
            ClearIdentity(row)
        end
    end
    return changed
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

local CompactRows = WarlockHudMultiTargetLayout.New(function() return rows end,
    function() return DOT_SLOTS end, ICON_SIZE,
    ROW_HEIGHT, Profile, function() return scrollFrame, scrollContent, scrollBar end,
    function() pending = true end)

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
        15 + (index - 1) * (size + 3), 0)
end

local function ApplyDotOrder(profile)
    local positions = DotOrder(profile)
    for _, row in ipairs(rows) do
        for _, entry in ipairs(row.dotVisuals) do
            PlaceDot(entry.icon, row.display, positions[entry.key], ICON_SIZE)
        end
    end
end

local CastTexture, CreateAuraSlot = WarlockHudMultiTargetAuras.New(Plain, Profile,
    PlaceDot, SLOT_KEYS, ICON_CROP, COUNTDOWN_FONT,
    function() return countdownFontReady end)

local function SameEffects(current)
    if #current ~= DOT_SLOTS then return false end
    local included = {}
    for _, key in ipairs(DOT_KEYS) do included[key] = true end
    for _, key in ipairs(current) do
        if not included[key] then return false end
    end
    return true
end

local function RetireWindow()
    damage.SetDebugEnabled(false)
    if visibilityDriver and UnregisterStateDriver then
        UnregisterStateDriver(visibilityController, "mtdvisibility")
    end
    visibilityDriver = false
    for _, row in ipairs(rows) do
        if row.source ~= "ghost" then row.auras:SetEnabled(false) end
        row.auras:Hide()
    end
    root:Hide()
    rows, root, visibilityController = {}, nil, nil
    built = false
    builtTimerMilliseconds = nil
end

local function Build()
    if built or not Safe() then pending = true; return false end
    local p = Profile()
    if not p or not api.IsAddonEnabled() then return false end
    DOT_KEYS = api.GetMultiTargetEffectOrder()
    DOT_SLOTS = #DOT_KEYS
    local active = {}
    for _, key in ipairs(DOT_KEYS) do active[key] = true end
    if not C_AddOns or not C_AddOns.LoadAddOn then return false end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        local loaded = C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        if not loaded then return false end
    end
    if CreateFont then
        local font = _G[COUNTDOWN_FONT] or CreateFont(COUNTDOWN_FONT)
        if font then
            font:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            font:SetShadowColor(0, 0, 0, 1)
            font:SetShadowOffset(1, -1)
            WarlockHudFonts.ConfigureCountdown(COUNTDOWN_FONT, p,
                "fontMultiTargetTimerSize", 10, "multiTargetFontFace")
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
    WarlockHudFonts.Apply(title, p, "fontMultiTargetSize", 10, "multiTargetFontFace")
    title:SetPoint("TOPLEFT", root, "TOPLEFT", 9, -8)
    title:SetText("Multi-Target DoTs (view only)")
    title:SetShadowColor(0, 0, 0, 1)
    title:SetShadowOffset(1, -1)
    status = root:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    WarlockHudFonts.Apply(status, p, "fontMultiTargetSize", 10, "multiTargetFontFace")
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
        local portraitWarning = display:CreateTexture(nil, "OVERLAY")
        portraitWarning:SetAllPoints(portrait)
        portraitWarning:SetVertexColor(1, 0.06, 0.06, 1)
        portraitWarning:SetAlpha(0)
        -- The native fill hides the warning while health exceeds the plain
        -- damage estimate. No Lua comparison or position read is involved.
        local portraitCover = CreateFrame("StatusBar", nil, display)
        portraitCover:SetAllPoints(portrait)
        portraitCover:SetFrameLevel(display:GetFrameLevel() + 1)
        portraitCover:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        portraitCover:SetMinMaxValues(0, 1)
        portraitCover:SetValue(1)
        local marker = portraitCover:CreateTexture(nil, "OVERLAY")
        marker:SetSize(16, 16)
        marker:SetPoint("TOPRIGHT", portrait, "TOPRIGHT", 2, 2)
        marker:SetTexture(RAID_ICONS)
        marker:Hide()
        local healthBar = CreateFrame("StatusBar", nil, display)
        healthBar:SetPoint("BOTTOMLEFT", display, "BOTTOMLEFT", 44, 3)
        healthBar:SetPoint("BOTTOMRIGHT", display, "BOTTOMRIGHT", 7, 3)
        healthBar:SetHeight(11)
        healthBar:SetFrameLevel(display:GetFrameLevel())
        healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        healthBar:SetStatusBarColor(0.5, 0.15, 0.17, 0.9)
        local healthTrack = healthBar:CreateTexture(nil, "BACKGROUND")
        healthTrack:SetAllPoints(healthBar)
        healthTrack:SetColorTexture(0.025, 0.025, 0.03, 0.95)
        local executeLayer = CreateFrame("Frame", nil, display)
        executeLayer:SetAllPoints(healthBar)
        executeLayer:SetFrameLevel(healthBar:GetFrameLevel() + 5)
        local executeOutline = executeLayer:CreateTexture(nil, "OVERLAY", nil, -2)
        executeOutline:SetSize(4, 15)
        executeOutline:SetColorTexture(0, 0, 0, 1)
        local executeLine = executeLayer:CreateTexture(nil, "OVERLAY", nil, -1)
        executeLine:SetSize(2, 15)
        executeLine:SetColorTexture(0.78, 0.43, 0.20, 1)
        healthBar:SetMinMaxValues(0, 1)
        healthBar:SetValue(0)
        local healthText = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        WarlockHudFonts.Apply(healthText, p, "fontMultiTargetSize", 10,
            "multiTargetFontFace")
        healthText:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", 0, 13)
        healthText:SetSize(128, math.max(12, p.fontMultiTargetSize or 10))
        healthText:SetJustifyH("RIGHT")
        healthText:SetTextColor(0.96, 0.96, 0.94)
        healthText:SetShadowColor(0, 0, 0, 1)
        healthText:SetShadowOffset(1, -1)
        healthText:SetText("")
        local function DamageSegment(level, red, green, blue, previous)
            local bar = CreateFrame("StatusBar", nil, display)
            if previous then
                bar:SetPoint("TOPLEFT", previous:GetStatusBarTexture(),
                    "TOPRIGHT", 0, 0)
            else
                bar:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 0, 0)
            end
            bar:SetWidth(width - (DOT_SLOTS * (size + 3) + 75))
            bar:SetHeight(4)
            bar:SetFrameLevel(healthBar:GetFrameLevel() + level)
            bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            bar:SetStatusBarColor(red, green, blue, 0.95)
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            return bar
        end
        local damageMarker = DamageSegment(4, 1, 0.66, 0.2)
        local baneMarker = DamageSegment(3, 0.7, 0.38, 0.9, damageMarker)
        local siphonMarker = DamageSegment(2, 0.24, 0.75, 0.68, baneMarker)
        local immolateMarker = DamageSegment(1, 1, 0.29, 0.13, siphonMarker)
        -- Anchor these ticks once, while the row is built safely. The native
        -- status bars move their fill textures as health and estimates change;
        -- Lua never reads back their protected widths or positions.
        local healthEdge = executeLayer:CreateTexture(nil, "OVERLAY", nil, 1)
        healthEdge:SetSize(2, 11)
        healthEdge:SetPoint("CENTER", healthBar:GetStatusBarTexture(), "RIGHT", 0, 0)
        healthEdge:SetColorTexture(1, 1, 1, 1)
        local damageEdge = executeLayer:CreateTexture(nil, "OVERLAY", nil, 2)
        damageEdge:SetSize(3, 8)
        damageEdge:SetPoint("CENTER", immolateMarker:GetStatusBarTexture(),
            "RIGHT", 0, 0)
        damageEdge:SetColorTexture(1, 0.93, 0.28, 1)
        damageEdge:SetAlpha(0)
        local name = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        WarlockHudFonts.Apply(name, p, "fontMultiTargetSize", 10,
            "multiTargetFontFace")
        name:SetPoint("TOPLEFT", display, "TOPLEFT", 45, -2)
        name:SetWidth(math.max(42, width - (DOT_SLOTS * (size + 3) + 261)))
        name:SetJustifyH("LEFT")
        name:SetTextColor(0.96, 0.96, 0.94)
        name:SetShadowColor(0, 0, 0, 1)
        name:SetShadowOffset(1, -1)
        if name.SetWordWrap then name:SetWordWrap(false) end
        local threatLabel = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        WarlockHudFonts.Apply(threatLabel, p, "fontMultiTargetSize", 10,
            "multiTargetFontFace")
        threatLabel:SetPoint("RIGHT", healthText, "LEFT", -4, 0)
        threatLabel:SetWidth(38)
        threatLabel:SetJustifyH("RIGHT")
        local threatDot = display:CreateTexture(nil, "OVERLAY")
        threatDot:SetPoint("RIGHT", threatLabel, "LEFT", -3, 0)
        threatDot:SetSize(8, 8)
        threatDot:SetTexture("Interface\\AddOns\\Warlock_Hud\\Textures\\ThreatDot")
        local iconHolder = CreateFrame("Frame", nil, display)
        iconHolder:SetAllPoints(display)
        local selection = display:CreateTexture(nil, "OVERLAY")
        selection:SetSize(4, size + 5)
        selection:SetPoint("LEFT", display, "LEFT", 0, 0)
        selection:SetColorTexture(0.86, 0.66, 0.25, 0)
        local source = i > LIVE_UNITS and "ghost" or (i <= ROWS and "nameplate" or
            (i == ROWS + 1 and "target" or (i <= ROWS + 5 and "party" or "raid")))
        local auras
        if source == "ghost" then
            auras = CreateFrame("Frame", nil, iconHolder)
        else
            auras = CreateFrame("AuraContainer", nil, iconHolder,
                "CustomAuraContainerTemplate")
        end
        auras:SetSize(math.max(1, DOT_SLOTS * (size + 3)), size)
        auras:SetPoint("LEFT", display, "RIGHT", 14, 0)
        local row = { unit = unit, source = source,
            display = display, icons = iconHolder, name = name,
            threatLabel = threatLabel, threatDot = threatDot,
            healthBar = healthBar, healthText = healthText,
            damageMarker = damageMarker, baneMarker = baneMarker,
            siphonMarker = siphonMarker, immolateMarker = immolateMarker,
            healthEdge = healthEdge, damageEdge = damageEdge,
            executeOutline = executeOutline, executeLine = executeLine,
            portrait = portrait, portraitWarning = portraitWarning,
            portraitCover = portraitCover, marker = marker,
            target = selection, auras = auras,
            dotVisuals = {} }
        function row:SetThreat(state)
            if self.threatState == state then return end
            self.threatState = state
            local colors = {
                LOW = { 0.259, 0.651, 0.416 },
                MED = { 0.843, 0.682, 0.259 },
                HIGH = { 0.878, 0.322, 0.322 },
                UNKNOWN = { 0.55, 0.55, 0.55 },
            }
            local color = colors[state] or colors.UNKNOWN
            self.threatLabel:SetText(state == "UNKNOWN" and "—" or state)
            self.threatLabel:SetTextColor(color[1], color[2], color[3])
            self.threatDot:SetVertexColor(color[1], color[2], color[3])
        end
        row:SetThreat("UNKNOWN")
        rows[i] = row
        local positions = DotOrder(p)
        for _, key in ipairs(DOT_KEYS) do
            local preview = api.GetDotDefaultSpell(key)
            if not preview then
                for _, spell in ipairs(SPELLS) do
                    if spell.group ~= 2 and SLOT_KEYS[spell.slot] == key
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
        if source ~= "ghost" then
            for _, spell in ipairs(SPELLS) do
                if spell.group ~= 2 and active[SLOT_KEYS[spell.slot]]
                    and (not p.enabled or p.enabled[spell.name] ~= false) then
                    CreateAuraSlot(row, spell, positions[SLOT_KEYS[spell.slot]], size)
                end
            end
            auras:SetUnit(unit)
            auras:Show()
            auras:UpdateAllAuras()
        else
            auras:Hide()
        end
        ClearIdentity(row)
        UpdateIdentity(row)
    end
    NormalizeRows()
    UpdateGhostRows()
    UpdateStatus()
    ApplyLayout(width, height)
    damage.SetDebugEnabled(damageDebug)
    builtTimerMilliseconds = p.dotTimerMilliseconds ~= false
    builtFontFace, builtFontSize, builtTimerFontSize =
        p.multiTargetFontFace, p.fontMultiTargetSize, p.fontMultiTargetTimerSize
    built, pending = true, false
    ApplyAppearance()
    return true
end

local function Refresh()
    local p = Profile()
    if not p then return false end
    if not Safe() then pending = true; return false end
    if built and (not SameEffects(api.GetMultiTargetEffectOrder())
        or builtTimerMilliseconds ~= (p.dotTimerMilliseconds ~= false)
        or builtFontFace ~= p.multiTargetFontFace
        or builtFontSize ~= p.fontMultiTargetSize
        or builtTimerFontSize ~= p.fontMultiTargetTimerSize) then
        RetireWindow()
    end
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

local probe = WarlockHudMultiTargetProbe.New(function() return rows end, ROWS,
    Plain, GroupThreat, TargetsGroup, TargetedByGroup)

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
    ProbeRunning = probe.IsRunning,
    Probe = probe.Command,
    DamageDebugRunning = function() return damageDebug end,
    DamageSnapshot = function()
        if WarlockHudOpenDebugTrace then WarlockHudOpenDebugTrace() end
        if WarlockHudTraceHUD then
            WarlockHudTraceHUD("Multi-Target ratios: "
                .. damage.DebugSnapshot())
        end
    end,
    ToggleDamageDebug = function()
        damageDebug = not damageDebug
        if damageDebug and not built then GuardedRefresh() end
        damage.SetDebugEnabled(damageDebug)
        if damageDebug then
            WarlockHudMultiTarget.DamageSnapshot()
        end
        print("Warlock HUD: Multi-Target ratio debug "
            .. (damageDebug and "on" or "off") .. ".")
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
        probe.EnableThreatDebug()
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
    if event == "UNIT_THREAT_LIST_UPDATE"
        or event == "UNIT_THREAT_SITUATION_UPDATE"
        or event == "PLAYER_TARGET_CHANGED"
        or event == "NAME_PLATE_UNIT_ADDED"
        or event == "NAME_PLATE_UNIT_REMOVED"
        or event == "UNIT_TARGET" or event == "GROUP_ROSTER_UPDATE" then
        probe.ThreatEvent(event)
    end
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
        lastSeen = {}
        ApplyAppearance()
        for _, row in ipairs(rows) do UpdateIdentity(row) end
        NormalizeRows()
        UpdateGhostRows()
        UpdateStatus()
        ReflowRows()
        damage.Update()
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
                damage.Clear(row)
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
        UpdateGhostRows()
        UpdateStatus()
        ReflowRows()
        damage.Update()
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
        UpdateGhostRows()
        UpdateStatus()
        ReflowRows()
        damage.Update()
    end
end)
local ghostElapsed = 0
events:SetScript("OnUpdate", function(_, delta)
    if not built then return end
    ghostElapsed = ghostElapsed + delta
    if ghostElapsed < 0.2 then return end
    ghostElapsed = 0
    if UpdateGhostRows() then
        UpdateStatus()
        ReflowRows()
    end
end)
