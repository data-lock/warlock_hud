-- Pet health warning settings page.
WarlockHudOptionsPetHealth = {}

function WarlockHudOptionsPetHealth.Build(context)
    local Panel, Text, Check, Button = context.Panel, context.Text,
        context.Check, context.Button
    local Profile, MarkChanged = context.Profile, context.MarkChanged
    local refreshers = context.refreshers
    local panel = Panel("Warlock HUD - Pet Health Alert", false)

    Text(panel, "Pet Health Alert", 20, -55, "GameFontNormal")
    Text(panel, "Flash the pet frame when your pet is at or below 35% health.",
        20, -82, "GameFontHighlightSmall")

    local function RefreshAlert()
        if WarlockHudPetHealthWarning and WarlockHudPetHealthWarning.Update then
            WarlockHudPetHealthWarning.Update()
        end
    end
    local function Changed()
        MarkChanged(false)
        RefreshAlert()
    end

    Check(panel, 20, -112, "Enable low-health pet alert",
        function() return Profile().petHealthAlertEnabled ~= false end,
        function(value)
            Profile().petHealthAlertEnabled = value
            RefreshAlert()
        end,
        "Show the flashing warning around the pet name and health/mana bars.",
        false)

    local colorLabel = Text(panel, "Alert color", 20, -164, "GameFontHighlight")
    local swatch = CreateFrame("Button", nil, panel, "BackdropTemplate")
    swatch:SetSize(36, 22)
    swatch:SetPoint("LEFT", colorLabel, "RIGHT", 18, 0)
    swatch:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    local color = swatch:CreateTexture(nil, "ARTWORK")
    color:SetPoint("TOPLEFT", 2, -2)
    color:SetPoint("BOTTOMRIGHT", -2, 2)
    local function GetColor()
        local profile = Profile()
        return profile.petHealthAlertColorR or 1,
            profile.petHealthAlertColorG or 0.015,
            profile.petHealthAlertColorB or 0.015
    end
    local function SaveColor(r, g, b)
        local profile = Profile()
        profile.petHealthAlertColorR = r
        profile.petHealthAlertColorG = g
        profile.petHealthAlertColorB = b
        Changed()
    end
    swatch:SetScript("OnClick", function()
        local r, g, b = GetColor()
        local previous = { r, g, b }
        local info = {
            r = r, g = g, b = b,
            hasOpacity = false,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                SaveColor(nr, ng, nb)
            end,
            cancelFunc = function()
                SaveColor(previous[1], previous[2], previous[3])
            end,
        }
        if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        elseif OpenColorPicker then
            OpenColorPicker(info)
        end
    end)
    swatch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Alert color")
        GameTooltip:AddLine("Choose the fill and glow color.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)
    refreshers[#refreshers + 1] = function()
        color:SetColorTexture(GetColor())
    end

    local function AddSlider(label, key, minimum, maximum, step, y, formatValue)
        Text(panel, label, 20, y, "GameFontHighlight")
        local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
        slider:SetSize(220, 17)
        slider:SetPoint("TOPLEFT", panel, "TOPLEFT", 220, y + 2)
        slider:SetMinMaxValues(minimum, maximum)
        slider:SetValueStep(step)
        local valueText = Text(panel, "", 460, y, "GameFontHighlight")
        local function Round(value)
            return math.max(minimum, math.min(maximum,
                math.floor(value / step + 0.5) * step))
        end
        slider:SetScript("OnValueChanged", function(_, value)
            valueText:SetText(formatValue(Round(value)))
        end)
        local function Commit(value)
            value = Round(value)
            local profile = Profile()
            if profile[key] ~= value then
                profile[key] = value
                if key == "petHealthAlertMinAlpha"
                    and value > profile.petHealthAlertMaxAlpha then
                    profile.petHealthAlertMaxAlpha = value
                elseif key == "petHealthAlertMaxAlpha"
                    and value < profile.petHealthAlertMinAlpha then
                    profile.petHealthAlertMinAlpha = value
                end
                Changed()
            end
            slider:SetValue(value)
        end
        slider:SetScript("OnMouseUp", function(self) Commit(self:GetValue()) end)
        Button(panel, "-", 185, y + 4, 24, function()
            Commit(Profile()[key] - step)
        end)
        Button(panel, "+", 445, y + 4, 24, function()
            Commit(Profile()[key] + step)
        end)
        refreshers[#refreshers + 1] = function()
            local value = Profile()[key]
            slider:SetValue(value)
            valueText:SetText(formatValue(value))
        end
    end

    AddSlider("Flash cycle", "petHealthAlertFrequency", 0.15, 1, 0.05,
        -215, function(value) return string.format("%.2f s", value) end)
    AddSlider("Minimum flash opacity", "petHealthAlertMinAlpha", 5, 100, 1,
        -275, function(value) return value .. "%" end)
    AddSlider("Maximum flash opacity", "petHealthAlertMaxAlpha", 5, 100, 1,
        -335, function(value) return value .. "%" end)
    Text(panel, "Flash cycle is the time for one fade direction. Opacity is clamped between the minimum and maximum values.",
        20, -390, "GameFontHighlightSmall")
    return panel
end
