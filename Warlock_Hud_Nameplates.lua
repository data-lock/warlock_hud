-- A fixed tick on the health bar shows the execute threshold without reading
-- or comparing a unit's health, which can be restricted during combat.
local markers = setmetatable({}, { __mode = "k" })
local events = CreateFrame("Frame")

local function IsForbidden(frame)
    if not frame or not isforbidden then return false end
    local ok, forbidden = pcall(isforbidden, frame)
    return not ok or forbidden == true
end

local function Enabled()
    local profile = WarlockHudAPI and WarlockHudAPI.GetProfile()
    return WarlockHudAPI and WarlockHudAPI.IsAddonEnabled()
        and profile and profile.enabled.executeMarker ~= false
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
        texture:SetPoint("CENTER", bar, "LEFT", width * 0.2, 0)
    end
end

local function GetMarker(bar, compact)
    if IsForbidden(bar) then return nil end
    local marker = markers[bar]
    if marker then return marker end
    marker = {}
    local outline = bar:CreateTexture(nil, "OVERLAY", nil, -2)
    outline:SetWidth(compact and 4 or 5)
    outline:SetColorTexture(0, 0, 0, 1)
    local line = bar:CreateTexture(nil, "OVERLAY", nil, -1)
    line:SetWidth(compact and 2 or 3)
    line:SetColorTexture(0.78, 0.43, 0.20, 1)
    marker.outline, marker.line = outline, line
    marker.heightPadding = compact and -2 or 6
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
    markers[bar] = marker
    UpdateMarker(bar, marker)
    return marker
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
    local attackable = false
    if Enabled() then
        local canCheck, result = pcall(UnitCanAttack, "player", unit)
        if canCheck and (not issecretvalue or not issecretvalue(result)) then
            attackable = result == true
        end
    end
    local marker = markers[bar]
    if not attackable then
        if marker then marker:Hide() end
        return
    end
    local created, result = pcall(GetMarker, bar)
    if created and result then
        result:Show()
        UpdateMarker(bar, result)
    end
end

local function UpdateTargetFrame(create)
    local bar = TargetFrameHealthBar
        or (TargetFrame and TargetFrame.healthbar)
    if not bar then return end
    local marker = markers[bar]
    if not Enabled() then
        if marker then marker:Hide() end
        return
    end
    if not marker and create and not InCombatLockdown() then
        local ok, result = pcall(GetMarker, bar, true)
        if ok then marker = result end
    end
    if marker then
        marker:Show()
        UpdateMarker(bar, marker)
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
