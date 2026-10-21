-- Addon-owned shortcut to the existing Settings category.
local button
local DEFAULT_ANGLE = math.rad(225)

local function Database()
    if type(WarlockHudDB) ~= "table" then return nil end
    return WarlockHudDB
end

local function Angle()
    local db = Database()
    local saved = db and db.minimapButtonAngle
    return type(saved) == "number" and saved == saved and saved or DEFAULT_ANGLE
end

local function Place(angle)
    local x, y = math.cos(angle), math.sin(angle)
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then
        local edge = math.max(math.abs(x), math.abs(y))
        x, y = x / edge, y / edge
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        x * (Minimap:GetWidth() / 2 + 5),
        y * (Minimap:GetHeight() / 2 + 5))
end

local function CursorAngle()
    local centerX, centerY = Minimap:GetCenter()
    if not centerX or not centerY then return nil end
    local scale = Minimap:GetEffectiveScale()
    if not scale or scale <= 0 then return nil end
    local cursorX, cursorY = GetCursorPosition()
    local x, y = cursorX / scale - centerX, cursorY / scale - centerY
    if x == 0 then return y >= 0 and math.pi / 2 or -math.pi / 2 end
    local angle = math.atan(y / x)
    if x < 0 then angle = angle + math.pi end
    return angle
end

local function CreateButton()
    if button or not Minimap then return end
    button = CreateFrame("Button", nil, Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        icon:SetSize(18, 18)
        icon:SetPoint("CENTER")
    else
        icon:SetSize(17, 17)
        icon:SetPoint("TOPLEFT", 7, -6)
    end
    icon:SetTexture(626007)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        background:SetSize(24, 24)
        background:SetPoint("CENTER")
    else
        background:SetSize(20, 20)
        background:SetPoint("TOPLEFT", 7, -5)
    end
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and 50 or 53,
        WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and 50 or 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Warlock HUD")
        GameTooltip:AddLine("Click to open settings. Drag to move around the minimap.",
            1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnMouseDown", function(self)
        self.dragged = false
    end)
    button:SetScript("OnDragStart", function(self)
        self.dragging = true
        self.dragged = true
        self:SetScript("OnUpdate", function()
            local angle = CursorAngle()
            if angle then Place(angle) end
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        local angle = CursorAngle()
        if angle then
            Place(angle)
            local db = Database()
            if db then db.minimapButtonAngle = angle end
        end
    end)
    button:SetScript("OnClick", function(self)
        if self.dragged or self.dragging then return end
        if not (WarlockHudOpenSettings and WarlockHudOpenSettings()) then
            print("|cffff7a7aWarlock HUD:|r Settings are not ready yet. Try /whud.")
        end
    end)
    Place(Angle())
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", CreateButton)
