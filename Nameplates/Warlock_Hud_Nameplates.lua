-- A fixed tick on the health bar shows the execute threshold without reading
-- or comparing a unit's health, which can be restricted during combat.
local markers = setmetatable({}, { __mode = "k" })
local events = CreateFrame("Frame")

local function IsForbidden(frame)
    if not frame or not isforbidden then return false end
    local ok, forbidden = pcall(isforbidden, frame)
    return not ok or forbidden == true
end

local function Settings()
    local profile = WarlockHudAPI and WarlockHudAPI.GetProfile()
    if not WarlockHudAPI or not WarlockHudAPI.IsAddonEnabled()
        or not profile or type(profile.enabled) ~= "table" then return nil end
    return profile.enabled
end

local function UpdateMarker(bar, marker)
    if IsForbidden(bar) then return end
    local widthOK, width = pcall(function() return bar:GetWidth() end)
    local heightOK, height = pcall(function() return bar:GetHeight() end)
    if not widthOK or not heightOK then return end
    if issecretvalue and (issecretvalue(width) or issecretvalue(height)) then
        return
    end
    if type(width) ~= "number" or type(height) ~= "number" then return end
    if width <= 0 or height <= 0 then return end
    if marker.lastWidth == width and marker.lastHeight == height then return end
    marker.lastWidth, marker.lastHeight = width, height
    for _, texture in ipairs({ marker.outline, marker.line }) do
        texture:SetHeight(math.max(6, height + (marker.heightPadding or 6)))
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", bar, "LEFT", width * marker.position, 0)
    end
end

local function CreateMarker(bar, compact, position)
    if IsForbidden(bar) then return nil end
    local marker = { position = position }
    local outline = bar:CreateTexture(nil, "OVERLAY", nil, -2)
    outline:SetWidth(compact and 4 or 5)
    outline:SetColorTexture(0, 0, 0, 1)
    local line = bar:CreateTexture(nil, "OVERLAY", nil, -1)
    line:SetWidth(compact and 2 or 3)
    line:SetColorTexture(0.78, 0.43, 0.20, 1)
    marker.outline, marker.line = outline, line
    marker.heightPadding = compact and -2 or 6
    outline:Hide()
    line:Hide()
    function marker:Show()
        self.outline:Show()
        self.line:Show()
    end
    function marker:Hide()
        self.outline:Hide()
        self.line:Hide()
    end
    local updater = CreateFrame("Frame", nil, bar)
    updater:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 0.2 then
            self.elapsed = 0
            UpdateMarker(bar, marker)
        end
    end)
    UpdateMarker(bar, marker)
    return marker
end

local function GetMarkers(bar, compact)
    if IsForbidden(bar) then return nil end
    local entry = markers[bar]
    if entry then return entry end
    entry = {
        twenty = CreateMarker(bar, compact, 0.20),
        thirtyFive = CreateMarker(bar, compact, 0.35),
    }
    if not entry.twenty or not entry.thirtyFive then return nil end
    markers[bar] = entry
    return entry
end

local function SetMarkers(entry, settings)
    if not entry then return end
    local show20 = settings and settings.executeMarker ~= false or false
    local show35 = settings and settings.executeMarker35 ~= false or false
    entry.twenty.outline:SetShown(show20)
    entry.twenty.line:SetShown(show20)
    entry.thirtyFive.outline:SetShown(show35)
    entry.thirtyFive.line:SetShown(show35)
end

local function UpdatePlate(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate or IsForbidden(plate) then return end
    local found, bar = pcall(function()
        local unitFrame = plate.UnitFrame
        if not unitFrame or IsForbidden(unitFrame) then return end
        return unitFrame.healthBar
            or (unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar)
    end)
    if not found or not bar or IsForbidden(bar) then return end
    local settings = Settings()
    local attackable = false
    if settings and (settings.executeMarker ~= false
        or settings.executeMarker35 ~= false) then
        local canCheck, result = pcall(UnitCanAttack, "player", unit)
        if canCheck and (not issecretvalue or not issecretvalue(result)) then
            attackable = result == true
        end
    end
    local marker = markers[bar]
    if not attackable then
        if marker then SetMarkers(marker, nil) end
        return
    end
    local created, result = pcall(GetMarkers, bar)
    if created and result then
        SetMarkers(result, settings)
        UpdateMarker(bar, result.twenty)
        UpdateMarker(bar, result.thirtyFive)
    end
end

local function UpdateTargetFrame(create)
    local bar = TargetFrameHealthBar
        or (TargetFrame and TargetFrame.healthbar)
    if not bar then return end
    local marker = markers[bar]
    local settings = Settings()
    if not settings or (settings.executeMarker == false
        and settings.executeMarker35 == false) then
        if marker then SetMarkers(marker, nil) end
        return
    end
    if not marker and create and not InCombatLockdown() then
        local ok, result = pcall(GetMarkers, bar, true)
        if ok then marker = result end
    end
    if marker then
        SetMarkers(marker, settings)
        UpdateMarker(bar, marker.twenty)
        UpdateMarker(bar, marker.thirtyFive)
    end
end

function WarlockHudRefreshNameplates()
    UpdateTargetFrame(true)
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or not plates then return end
    for _, plate in ipairs(plates) do
        local found, unit = pcall(function()
            return plate.unitToken or (plate.GetUnit and plate:GetUnit())
        end)
        if found and unit then UpdatePlate(unit) end
    end
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        WarlockHudRefreshNameplates()
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        UpdateTargetFrame(event == "PLAYER_REGEN_ENABLED")
    else
        UpdatePlate(unit)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() UpdatePlate(unit) end)
        end
    end
end)
