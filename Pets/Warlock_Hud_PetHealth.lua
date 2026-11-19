-- Low-health warning localized to Blizzard's Pet Frame.
local warning
local pulsePlaying = false
local healthThresholdCurve
local glowBorders = {}
local appliedAlertConfig

local function CreateHealthThresholdCurve()
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor
        and Enum and Enum.LuaCurveType) then return nil end
    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve then return nil end
    local configured = pcall(function()
        curve:SetType(Enum.LuaCurveType.Linear)
        curve:AddPoint(0, CreateColor(1, 0, 0, 1))
        curve:AddPoint(0.35, CreateColor(1, 0, 0, 1))
        curve:AddPoint(0.36, CreateColor(1, 0, 0, 0))
        curve:AddPoint(1, CreateColor(1, 0, 0, 0))
    end)
    return configured and curve or nil
end

local function SafePetPercent()
    if not UnitExists or not UnitExists("pet") then return nil end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("pet") then return nil end
    if not UnitHealthPercent or not CurveConstants
        or not CurveConstants.ScaleTo100 then return nil end
    local ok, percent = pcall(UnitHealthPercent, "pet", false,
        CurveConstants.ScaleTo100)
    if not ok or (issecretvalue and issecretvalue(percent))
        or type(percent) ~= "number" then
        return nil
    end
    return percent
end

local function Update()
    if not warning or not PetFrame then return end
    local profile = WarlockHudAPI and WarlockHudAPI.GetProfile
        and WarlockHudAPI.GetProfile()
    if profile then
        if profile.petHealthAlertEnabled == false then
            warning:Hide()
            warning.flash.pulse:Stop()
            pulsePlaying = false
            return
        end
        local red = profile.petHealthAlertColorR or 1
        local green = profile.petHealthAlertColorG or 0.015
        local blue = profile.petHealthAlertColorB or 0.015
        local frequency = profile.petHealthAlertFrequency or 0.3
        local minAlpha = (profile.petHealthAlertMinAlpha or 12) / 100
        local maxAlpha = (profile.petHealthAlertMaxAlpha or 100) / 100
        local config = string.format("%.3f:%.3f:%.3f:%.2f:%.2f:%.2f",
            red, green, blue, frequency, minAlpha, maxAlpha)
        if config ~= appliedAlertConfig then
            warning.fill:SetColorTexture(red, green, blue, 0.34)
            for _, border in ipairs(glowBorders) do
                border.frame:SetBackdropBorderColor(red, green, blue, border.alpha)
            end
            warning.flash.fade:SetDuration(frequency)
            warning.flash.fade:SetFromAlpha(minAlpha)
            warning.flash.fade:SetToAlpha(maxAlpha)
            appliedAlertConfig = config
        end
    end
    local shown = warning.petFrame:IsShown()
    local hasPet = UnitExists and UnitExists("pet")
    local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("pet")
    if not shown or not hasPet or dead then
        warning:Hide()
        warning.flash.pulse:Stop()
        pulsePlaying = false
        return
    end

    warning:Show()
    if not pulsePlaying then
        warning.flash.pulse:Play()
        pulsePlaying = true
    end

    if healthThresholdCurve and UnitHealthPercent then
        -- Health can be secret during combat. The color curve evaluates the
        -- threshold in the engine; pass its alpha directly to the native frame.
        local ok, color = pcall(UnitHealthPercent, "pet", false,
            healthThresholdCurve)
        if ok and color then
            pcall(function()
                local _, _, _, alpha = color:GetRGBA()
                warning:SetAlpha(alpha)
            end)
        end
    else
        local percent = SafePetPercent()
        if percent ~= nil then warning:SetAlpha(percent <= 35 and 1 or 0) end
    end
end

local function CreateWarning()
    if warning or not PetFrame or InCombatLockdown() then return end
    local healthBar = PetFrameHealthBar or PetFrameManaBar or PetFrame
    local manaBar = PetFrameManaBar or healthBar
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata(PetFrame:GetFrameStrata())
    frame:SetFrameLevel(math.max(0, PetFrame:GetFrameLevel() - 1))
    frame:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -2, 14)
    frame:SetPoint("BOTTOMRIGHT", manaBar, "BOTTOMRIGHT", 0, -2)
    frame:EnableMouse(false)
    frame:SetAlpha(0)

    local flash = CreateFrame("Frame", nil, frame)
    flash:SetAllPoints(frame)
    local fill = flash:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    fill:SetColorTexture(1, 0.015, 0.015, 0.34)

    local function AddRoundedGlow(outset, edgeSize, alpha, level)
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local rounded = CreateFrame("Frame", nil, flash, template)
        rounded:SetFrameLevel(flash:GetFrameLevel() + level)
        rounded:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
        rounded:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset, -outset)
        if not rounded.SetBackdrop then return end
        rounded:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = edgeSize,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
        rounded:SetBackdropBorderColor(1, 0.055, 0.02, alpha)
        glowBorders[#glowBorders + 1] = { frame = rounded, alpha = alpha }
    end
    AddRoundedGlow(3, 14, 0.1, 1)
    AddRoundedGlow(1, 12, 0.24, 2)
    AddRoundedGlow(0, 9, 0.72, 3)

    local pulse = flash:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.12)
    fade:SetToAlpha(1)
    fade:SetDuration(0.3)
    fade:SetSmoothing("IN_OUT")

    warning = frame
    warning.petFrame = PetFrame
    warning.flash = flash
    warning.fill = fill
    warning.flash.pulse = pulse
    warning.flash.fade = fade
    warning:Hide()
    PetFrame:HookScript("OnShow", Update)
    PetFrame:HookScript("OnHide", Update)
    Update()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterUnitEvent("UNIT_HEALTH", "pet")
events:RegisterUnitEvent("UNIT_MAXHEALTH", "pet")
events:RegisterUnitEvent("UNIT_FLAGS", "pet")
events:RegisterUnitEvent("UNIT_PET", "player")
healthThresholdCurve = CreateHealthThresholdCurve()
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_REGEN_ENABLED" then
        CreateWarning()
    end
    Update()
end)

WarlockHudPetHealthWarning = {
    Update = Update,
}
