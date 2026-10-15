-- Unit identity and row presentation for the Multi-Target tracker.
-- Native aura containers remain owned by Warlock_Hud_MultiTarget.lua.
WarlockHudMultiTargetIdentity = {}

function WarlockHudMultiTargetIdentity.New(getRows, spells, rowLimit, plain)
    local SPELLS, ROWS, Plain = spells, rowLimit, plain
    local healthColorCurve
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor
        and Enum and Enum.LuaCurveType then
        local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
        if ok and curve then
            curve:SetType(Enum.LuaCurveType.Linear)
            curve:AddPoint(0, CreateColor(0.88, 0.12, 0.12, 0.9))
            curve:AddPoint(0.5, CreateColor(0.95, 0.72, 0.16, 0.9))
            curve:AddPoint(1, CreateColor(0.2, 0.72, 0.3, 0.9))
            healthColorCurve = curve
        end
    end

    local function ClearIdentity(row)
        row.present = false
        row.eligible = false
        row.relevant = false
        -- Alpha also hides native aura children without changing protected
        -- visibility or anchors during combat.
        row.display:SetAlpha(0)
        row.name:SetText("")
        if row.healthBar then
            pcall(row.healthBar.SetMinMaxValues, row.healthBar, 0, 1)
            pcall(row.healthBar.SetValue, row.healthBar, 0)
        end
        if row.healthText then row.healthText:SetText("") end
        row.name:SetTextColor(0.94, 0.94, 0.92)
        row.portrait:SetTexture(nil)
        row.portraitReady = false
        row.marker:Hide()
        row.markerMode = "none"
        row.target:SetColorTexture(0.86, 0.66, 0.25, 0)
    end

    local function UpdateHealth(row, name)
        row.name:SetText(name)
        if not UnitHealth or not UnitHealthMax or not UnitHealthPercent
            or not CurveConstants or not CurveConstants.ScaleTo100 then
            row.healthText:SetText("")
            return
        end
        local healthOK, health = pcall(UnitHealth, row.unit, true)
        local maxOK, maximum = pcall(UnitHealthMax, row.unit)
        local percentOK, percent = pcall(UnitHealthPercent, row.unit, true,
            CurveConstants.ScaleTo100)
        if not healthOK or not maxOK or not percentOK then
            row.healthText:SetText("")
            return
        end
        local function Numeric(value)
            return (issecretvalue and issecretvalue(value))
                or type(value) == "number"
        end
        if not Numeric(health) or not Numeric(maximum) or not Numeric(percent) then
            row.healthText:SetText("")
            return
        end
        -- These values may be secret. Native widgets accept them directly; Lua
        -- never compares, divides, concatenates, or formats them.
        pcall(row.healthBar.SetMinMaxValues, row.healthBar, 0, maximum)
        pcall(row.healthBar.SetValue, row.healthBar, health)
        if healthColorCurve then
            local colorOK, color = pcall(UnitHealthPercent, row.unit, true,
                healthColorCurve)
            if colorOK and color then
                pcall(function()
                    row.healthBar:SetStatusBarColor(color:GetRGBA())
                end)
            end
        elseif not (issecretvalue and issecretvalue(percent)) then
            local fraction = math.max(0, math.min(1, percent / 100))
            row.healthBar:SetStatusBarColor(1 - 0.8 * fraction,
                0.12 + 0.6 * fraction, 0.12 + 0.18 * fraction, 0.9)
        end
        local formatted = pcall(row.healthText.SetFormattedText, row.healthText,
            "%.0f / %.0f  %.0f%%", health, maximum, percent)
        if not formatted then row.healthText:SetText("") end
    end

    local function GroupThreat(unit)
        if not UnitThreatSituation then return nil end
        local unknown = false
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
            if not existsOK or not Plain(memberExists) then
                unknown = true
            elseif memberExists then
                local threatOK, status = pcall(UnitThreatSituation, member, unit)
                if not threatOK or (issecretvalue and issecretvalue(status)) then
                    unknown = true
                elseif type(status) == "number" then
                    return true
                end
            end
        end
        return unknown and nil or false
    end

    local function TargetsGroup(unit)
        if not UnitIsUnit or not UnitExists then return false end
        local target = unit .. "target"
        local targetOK, exists = pcall(UnitExists, target)
        if not targetOK or not Plain(exists) or not exists then return false end
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
            local sameOK, same = pcall(UnitIsUnit, target, member)
            if sameOK and Plain(same) and same then return true end
        end
        return false
    end

    local function TargetedByGroup(unit)
        if not UnitIsUnit then return false end
        local candidates = { "pettarget" }
        if IsInRaid and IsInRaid() then
            for i = 1, 40 do candidates[#candidates + 1] = "raid" .. i .. "target" end
        elseif IsInGroup and IsInGroup() then
            for i = 1, 4 do candidates[#candidates + 1] = "party" .. i .. "target" end
        end
        local unitGuid
        if UnitGUID then
            local ok, guid = pcall(UnitGUID, unit)
            if ok and Plain(guid) and type(guid) == "string" then unitGuid = guid end
        end
        for _, other in ipairs(candidates) do
            local existsOK, exists = pcall(UnitExists, other)
            if existsOK and Plain(exists) and exists then
                local sameOK, same = pcall(UnitIsUnit, unit, other)
                if sameOK and Plain(same) and same then return true end
                if unitGuid and UnitGUID then
                    local guidOK, otherGuid = pcall(UnitGUID, other)
                    if guidOK and Plain(otherGuid) and type(otherGuid) == "string"
                        and otherGuid == unitGuid then return true end
                end
            end
        end
        return false
    end

    local function OwnDot(unit)
        -- Native slots render combat auras. Lua only checks presence while the
        -- aura APIs are unrestricted, never their protected duration fields.
        if InCombatLockdown() or not C_UnitAuras
            or not C_UnitAuras.GetAuraDataBySpellID
            or (C_Secrets and C_Secrets.ShouldAurasBeSecret
                and C_Secrets.ShouldAurasBeSecret()) then return nil end
        for _, spell in ipairs(SPELLS) do
            if spell.group ~= 2 then for _, id in ipairs(spell.ids) do
                local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellID,
                    unit, id, "HARMFUL|PLAYER")
                if not ok or (issecretvalue and issecretvalue(aura)) then return nil end
                if aura then return true end
            end end
        end
        return false
    end

    local function UpdatePortrait(row)
        if row.present and SetPortraitTexture then
            row.portraitReady = pcall(SetPortraitTexture, row.portrait, row.unit)
        end
    end

    local function ReadRaidMarker(unit)
        if not GetRaidTargetIndex then return nil end
        local ok, index = pcall(GetRaidTargetIndex, unit)
        if ok and Plain(index) and type(index) == "number"
            and index >= 1 and index <= 8 then return index end
    end

    local function ReadGuidRaidMarker(unit)
        if not UnitGUID then return nil end
        local ok, guid = pcall(UnitGUID, unit)
        if not ok or not Plain(guid) or type(guid) ~= "string" then return nil end
        return ReadRaidMarker(guid)
    end

    local function MarkerProbeResult(unit)
        if not GetRaidTargetIndex then return "API unavailable" end
        local ok, index = pcall(GetRaidTargetIndex, unit)
        if not ok then return "error" end
        if issecretvalue and issecretvalue(index) then return "restricted" end
        if index == nil then return "nil" end
        return tostring(index)
    end

    local function ReadableGuid(unit)
        if not UnitGUID then return "unavailable" end
        local ok, guid = pcall(UnitGUID, unit)
        return ok and Plain(guid) and type(guid) == "string"
            and guid or "unavailable"
    end

    local function RaidMarkerFor(unit)
        local index = ReadRaidMarker(unit)
        if index then return index, unit end
        index = ReadGuidRaidMarker(unit)
        if index then return index, unit .. " GUID" end
        local alternatives = { "target", "focus", "pettarget" }
        if IsInRaid and IsInRaid() then
            for i = 1, 40 do alternatives[#alternatives + 1] = "raid" .. i .. "target" end
        elseif IsInGroup and IsInGroup() then
            for i = 1, 4 do alternatives[#alternatives + 1] = "party" .. i .. "target" end
        end
        for _, other in ipairs(alternatives) do
            local sameOK, same = pcall(UnitIsUnit, unit, other)
            if sameOK and Plain(same) and same then
                index = ReadRaidMarker(other)
                if index then return index, other end
                index = ReadGuidRaidMarker(other)
                if index then return index, other .. " GUID" end
            end
        end
    end

    local function UpdateIdentity(row)
        local unit = row.unit
        local source = row.source
        if source == "party" and (not IsInGroup or not IsInGroup()
            or (IsInRaid and IsInRaid())) then ClearIdentity(row); return end
        if source == "raid" and (not IsInRaid or not IsInRaid()) then
            ClearIdentity(row); return
        end
        local existsOK, exists = pcall(UnitExists, unit)
        if not existsOK or not Plain(exists) or not exists then
            ClearIdentity(row)
            return
        end
        if UnitIsDeadOrGhost then
            local deadOK, dead = pcall(UnitIsDeadOrGhost, unit)
            if deadOK and Plain(dead) and dead then
                ClearIdentity(row)
                return
            end
        end
        if source ~= "nameplate" then
            local attackOK, attackable = pcall(UnitCanAttack, "player", unit)
            if not attackOK or not Plain(attackable) or not attackable then
                ClearIdentity(row); return
            end
        end
        if source == "nameplate" or source == "target" then
            local threat, dot = GroupThreat(unit), OwnDot(unit)
            local targetingGroup = TargetsGroup(unit)
            local groupTarget = TargetedByGroup(unit)
            -- A row confirmed before combat stays visible while DoT evidence is
            -- restricted. New rows still need confirmation, and safe reads recheck it.
            local retainConfirmed = row.eligible and InCombatLockdown() and dot == nil
            if threat ~= true and dot ~= true and not targetingGroup and not groupTarget
                and not retainConfirmed then
                ClearIdentity(row)
                return
            end
        end
        row.present = true
        row.eligible = true
        row.relevant = true
        row.display:SetAlpha(1)
        row.name:SetTextColor(0.96, 0.96, 0.94)
        row.target:SetColorTexture(0.86, 0.66, 0.25, 0)
        if not row.portraitReady then UpdatePortrait(row) end
        local ok, name = pcall(UnitName, unit)
        if ok then UpdateHealth(row, name) end
        local index = RaidMarkerFor(unit)
        if index then
            local column = (index - 1) % 4
            local line = math.floor((index - 1) / 4)
            row.marker:SetTexCoord(column * 0.25, (column + 1) * 0.25,
                line * 0.25, (line + 1) * 0.25)
            row.marker:Show()
            row.markerMode = "readable"
        else
            -- Blizzard's untainted renderer may accept a restricted marker index
            -- even though addon Lua cannot compare or calculate with it.
            local markerOK, restrictedIndex = pcall(GetRaidTargetIndex, unit)
            local rendered = false
            if markerOK and issecretvalue and issecretvalue(restrictedIndex)
                and SetRaidTargetIconTexture then
                rendered = pcall(SetRaidTargetIconTexture, row.marker, restrictedIndex)
            end
            if rendered then
                row.marker:Show()
                row.markerMode = "native"
            else
                row.marker:Hide()
                row.markerMode = "none"
            end
        end
        local targetOK, selected = pcall(UnitIsUnit, unit, "target")
        if targetOK and Plain(selected) and selected == true then
            row.target:SetColorTexture(0.86, 0.66, 0.25, 0.95)
        end
        -- Match the HUD's full/half icon alpha for an attackable target while
        -- leaving row text and health legible. The parent also carries native aura
        -- buttons, so Blizzard continues to control their visibility and timers.
        row.icons:SetAlpha((row.relevant == true
            or (targetOK and Plain(selected) and selected == true)) and 1 or 0.5)
    end

    local function NormalizeRows()
        local seen, accepted, count = {}, {}, 0
        for _, row in ipairs(getRows()) do
            if row.eligible then
                local guid = ReadableGuid(row.unit)
                local duplicate = guid ~= "unavailable" and seen[guid]
                if not duplicate and UnitIsUnit then
                    for _, prior in ipairs(accepted) do
                        local ok, same = pcall(UnitIsUnit, row.unit, prior)
                        if ok and Plain(same) and same then
                            duplicate = true
                            break
                        end
                    end
                end
                if duplicate or count >= ROWS then
                    row.present = false
                    row.display:SetAlpha(0)
                else
                    row.present = true
                    row.display:SetAlpha(1)
                    if guid ~= "unavailable" then seen[guid] = true end
                    accepted[#accepted + 1] = row.unit
                    count = count + 1
                end
            end
        end
    end
    return {
        ClearIdentity = ClearIdentity,
        GroupThreat = GroupThreat,
        TargetsGroup = TargetsGroup,
        TargetedByGroup = TargetedByGroup,
        UpdatePortrait = UpdatePortrait,
        MarkerProbeResult = MarkerProbeResult,
        ReadableGuid = ReadableGuid,
        RaidMarkerFor = RaidMarkerFor,
        UpdateIdentity = UpdateIdentity,
        NormalizeRows = NormalizeRows,
    }
end
