-- Native Multi-Target aura button presentation.
WarlockHudMultiTargetAuras = {}

function WarlockHudMultiTargetAuras.New(plain, profile, placeDot, slotKeys,
    iconCrop, countdownFont, countdownFontReady)
    local Plain, Profile, PlaceDot = plain, profile, placeDot
    local SLOT_KEYS, ICON_CROP, COUNTDOWN_FONT = slotKeys, iconCrop, countdownFont

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
                PlaceDot(button, row.display, index, size)
                row.dotVisuals[#row.dotVisuals + 1] = {
                    icon = button, key = SLOT_KEYS[spell.slot] }
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
                cooldown:SetCountdownMillisecondsThreshold(spell.talentEffect and 10 or 0)
                if cooldown.SetCountdownAbbrevThreshold then
                    cooldown:SetCountdownAbbrevThreshold(60)
                end
                if countdownFontReady() and cooldown.SetCountdownFont then
                    cooldown:SetCountdownFont(COUNTDOWN_FONT)
                end
                if spell.talentEffect and cooldown.GetCountdownFontString then
                    local countdownText = cooldown:GetCountdownFontString()
                    if countdownText then
                        countdownText:ClearAllPoints()
                        countdownText:SetSize(size, size)
                        countdownText:SetJustifyH("CENTER")
                        countdownText:SetJustifyV("MIDDLE")
                        countdownText:SetPoint("CENTER", button, "CENTER", 3, 0)
                    end
                end
                if cooldown.SetSwipeColor then
                    cooldown:SetSwipeColor(0, 0, 0, 0.58)
                end
                cooldown:SetReverse(true)
                button:SetDurationCooldown(cooldown)
                if spell.talentEffect and button.SetApplicationCount then
                    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                    count:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
                    count:SetSize(10, 9)
                    count:SetJustifyH("LEFT")
                    count:SetPoint("TOPLEFT", button, "TOPLEFT", 1, 0)
                    button:SetApplicationCount(count, {})
                end
                -- Blizzard owns the aura button and its cooldown. No script
                -- handlers or insecure combat visibility changes are attached.
            end,
        })
    end
    return CastTexture, CreateAuraSlot
end
