-- Shared dark window shell used by the auxiliary Warlock HUD windows.
WarlockHudWindowChrome = {}
local BORDER_COLOR = { 1, 0.82, 0.2, 0.5 }

function WarlockHudWindowChrome.SetBackground(frame, bodyAlpha)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    if bodyAlpha then
        background:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, -25)
        local body = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -25)
        body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        body:SetColorTexture(0.035, 0.035, 0.045, bodyAlpha)
    else
        background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    end
    background:SetColorTexture(0.035, 0.035, 0.045, 0.88)
end

function WarlockHudWindowChrome.AddBorder(frame)
    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints(frame)
    border:SetFrameLevel(frame:GetFrameLevel() + 3)
    local left = border:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT", border, "TOPLEFT", 1, -1)
    left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 1, 1)
    left:SetWidth(1)
    left:SetColorTexture(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])
    local right = border:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT", border, "TOPRIGHT", -1, -1)
    right:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -1, 1)
    right:SetWidth(1)
    right:SetColorTexture(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])
    local top = border:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT", border, "TOPLEFT", 1, 0)
    top:SetPoint("TOPRIGHT", border, "TOPRIGHT", -1, 0)
    top:SetHeight(1)
    top:SetColorTexture(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])
    local bottom = border:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 2, 1)
    bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -2, 1)
    bottom:SetHeight(1)
    bottom:SetColorTexture(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])
end

function WarlockHudWindowChrome.StyleButton(button)
    if not button then return end
    local regions = { button:GetRegions() }
    for _, region in ipairs(regions) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetAlpha(0)
        end
    end
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(button)
    local border = {}
    local function Edge(point1, point2, width, height)
        local texture = button:CreateTexture(nil, "OVERLAY")
        texture:SetPoint(point1, button, point1, 0, 0)
        texture:SetPoint(point2, button, point2, 0, 0)
        if width then texture:SetWidth(width) end
        if height then texture:SetHeight(height) end
        border[#border + 1] = texture
    end
    Edge("TOPLEFT", "TOPRIGHT", nil, 1)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    Edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
    Edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
    local label = button:GetFontString()
    if label then
        label:SetFontObject(GameFontNormalSmall)
        label:SetTextColor(1, 0.82, 0.2)
    end
    local function SetState(hovered)
        background:SetColorTexture(hovered and 0.20 or 0.035,
            hovered and 0.13 or 0.035, hovered and 0.08 or 0.045,
            hovered and 0.95 or 0.78)
        for _, edge in ipairs(border) do
            edge:SetColorTexture(1, 0.82, 0.2, hovered and 0.95 or 0.5)
        end
        if label then
            label:SetTextColor(1, hovered and 0.88 or 0.82,
                hovered and 0.48 or 0.2)
        end
    end
    SetState(false)
    button:HookScript("OnEnter", function() SetState(true) end)
    button:HookScript("OnLeave", function() SetState(false) end)
end

function WarlockHudWindowChrome.StyleScrollbar(scrollBar)
    if not scrollBar then return end
    scrollBar:SetWidth(6)
    for _, key in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do
        local button = scrollBar[key]
        if button then button:Hide() end
    end
    if scrollBar.SetThumbTexture and scrollBar.GetThumbTexture then
        scrollBar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        local thumb = scrollBar:GetThumbTexture()
        if thumb then
            thumb:SetSize(6, 28)
            thumb:SetColorTexture(0.86, 0.66, 0.25, 0.78)
        end
    end
    local track = scrollBar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(scrollBar)
    track:SetColorTexture(0.02, 0.02, 0.025, 0.55)
end

function WarlockHudWindowChrome.CreateCloseButton(frame, onClose, name)
    local close = CreateFrame("Button", name, frame)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -4)
    close:SetFrameLevel(frame:GetFrameLevel() + 5)
    local background = close:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(close)
    background:SetColorTexture(0.035, 0.035, 0.045, 0.88)
    local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeText:SetAllPoints(close)
    closeText:SetText("X")
    closeText:SetTextColor(0.72, 0.75, 0.80)
    close:SetScript("OnEnter", function()
        closeText:SetTextColor(1, 0.72, 0.35)
        background:SetColorTexture(0.20, 0.13, 0.08, 0.95)
    end)
    close:SetScript("OnLeave", function()
        closeText:SetTextColor(0.72, 0.75, 0.80)
        background:SetColorTexture(0.035, 0.035, 0.045, 0.88)
    end)
    close:SetScript("OnClick", onClose)
    return close
end

function WarlockHudWindowChrome.Apply(frame, titleText, onClose, bodyAlpha, closeName)
    WarlockHudWindowChrome.SetBackground(frame, bodyAlpha)
    WarlockHudWindowChrome.AddBorder(frame)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -8)
    title:SetWidth(math.max(1, frame:GetWidth() - 48))
    title:SetJustifyH("LEFT")
    title:SetText(titleText)
    title:SetShadowColor(0, 0, 0, 1)
    title:SetShadowOffset(1, -1)

    local close = WarlockHudWindowChrome.CreateCloseButton(frame, onClose, closeName)

    return title, close
end
