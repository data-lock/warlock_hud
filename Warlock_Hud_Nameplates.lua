-- A fixed tick on the health bar shows the execute threshold without reading
-- or comparing a unit's health, which can be restricted during combat.
local markers = setmetatable({}, { __mode = "k" })
local events = CreateFrame("Frame")

local function Enabled()
    local profile = WarlockHudAPI and WarlockHudAPI.GetProfile()
    return WarlockHudAPI and WarlockHudAPI.IsAddonEnabled()
        and profile and profile.enabled.executeMarker ~= false
end

local function UpdateMarker(bar, marker)
    local width, height = bar:GetWidth(), bar:GetHeight()
    if width <= 0 or height <= 0 then return end
    if marker.lastWidth == width and marker.lastHeight == height then return end
    marker.lastWidth, marker.lastHeight = width, height
    for _, texture in ipairs({ marker.outline, marker.line }) do
        texture:SetHeight(height + 6)
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", bar, "LEFT", width * 0.2, 0)
    end
end

local function GetMarker(bar)
    local marker = markers[bar]
    if marker then return marker end
    marker = {}
    local outline = bar:CreateTexture(nil, "OVERLAY", nil, -2)
    outline:SetWidth(5)
    outline:SetColorTexture(0, 0, 0, 1)
    local line = bar:CreateTexture(nil, "OVERLAY", nil, -1)
    line:SetWidth(3)
    line:SetColorTexture(0.78, 0.43, 0.20, 1)
    marker.outline, marker.line = outline, line
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
    if not ok or not plate or (isforbidden and isforbidden(plate)) then return end
    local found, bar = pcall(function()
        local unitFrame = plate.UnitFrame
        if not unitFrame or (isforbidden and isforbidden(unitFrame)) then return end
        return unitFrame.healthBar
            or (unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar)
    end)
    if not found or not bar or (isforbidden and isforbidden(bar)) then return end
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

function WarlockHudRefreshNameplates()
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
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        WarlockHudRefreshNameplates()
    else
        UpdatePlate(unit)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() UpdatePlate(unit) end)
        end
    end
end)
