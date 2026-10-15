-- Original, approximate periodic damage estimates for Multi-Target rows.
-- Never reads aura data or performs arithmetic on protected health values.
WarlockHudMultiTargetDamage = {}

function WarlockHudMultiTargetDamage.New(getRows, readableGuid)
    local casts = {} -- readable GUID -> spell key -> cast
    local SPELLS = {
        ["Corruption"] = { duration = 18, tick = 3, school = 32, fallback = 40 },
        ["Bane of Agony"] = { duration = 24, tick = 2, school = 32, fallback = 84 },
        ["Siphon Life"] = { duration = 30, tick = 3, school = 32 },
        ["Immolate"] = { duration = 15, tick = 3, school = 4 },
    }
    -- Review calibration from the player's displayed totals for these exact
    -- ranks. Prefer a readable spell description when the client provides one.
    local REVIEW_TOTALS = { [6223] = 223, [1014] = 214 }
    local spellKeys = {}
    for _, spell in ipairs(WarlockHudEffects.Spells) do
        if SPELLS[spell.name] then
            for _, id in ipairs(spell.ids) do spellKeys[id] = spell.name end
        end
    end
    local WINDOW = 0.65

    local function ParseTotal(description, expectedDuration, key)
        if (issecretvalue and issecretvalue(description))
            or type(description) ~= "string" then return nil end
        if key == "Siphon Life" then
            local amount, interval = description:match(
                "([%d,]+)%s+health[^%.]-every%s+([%d%.]+)%s+sec")
            amount = amount and tonumber((amount:gsub(",", "")))
            if amount and amount > 0 and tonumber(interval) == 3 then
                return amount * (expectedDuration / 3)
            end
        end
        local total
        for amount, duration in description:gmatch(
            "([%d,]+)%s+[%a%s]-damage%s+over%s+([%d%.]+)%s+sec") do
            amount = tonumber((amount:gsub(",", "")))
            if amount and amount > 0 and tonumber(duration) == expectedDuration then
                total = amount
            end
        end
        return total
    end

    local function DescriptionTotal(spellID, expectedDuration, key)
        if C_Spell and C_Spell.GetSpellDescription then
            local ok, description = pcall(C_Spell.GetSpellDescription, spellID)
            local total = ok and ParseTotal(description, expectedDuration, key)
            if total then return total, "description" end
        end
        if InCombatLockdown() or not C_TooltipInfo
            or not C_TooltipInfo.GetSpellByID then return nil end
        local ok, tooltip = pcall(C_TooltipInfo.GetSpellByID, spellID)
        if not ok or (issecretvalue and issecretvalue(tooltip))
            or type(tooltip) ~= "table" then return nil end
        local lines = tooltip.lines
        if (issecretvalue and issecretvalue(lines))
            or type(lines) ~= "table" then return nil end
        for _, line in ipairs(lines) do
            if not (issecretvalue and issecretvalue(line))
                and type(line) == "table" then
                local total = ParseTotal(line.leftText, expectedDuration, key)
                if total then return total, "tooltip" end
            end
        end
    end

    local cachedTotals, cachedSources, learnedTicks = {}, {}, {}
    local function RefreshDescriptions()
        if InCombatLockdown() then return end
        for id, key in pairs(spellKeys) do
            local total, source = DescriptionTotal(id, SPELLS[key].duration, key)
            if total then
                cachedTotals[id], cachedSources[id] = total, source
            end
        end
    end
    RefreshDescriptions()

    local function Clear(row)
        if row.damageMarker then pcall(row.damageMarker.SetValue, row.damageMarker, 0) end
        if row.baneMarker then pcall(row.baneMarker.SetValue, row.baneMarker, 0) end
        if row.siphonMarker then pcall(row.siphonMarker.SetValue, row.siphonMarker, 0) end
        if row.immolateMarker then pcall(row.immolateMarker.SetValue, row.immolateMarker, 0) end
    end

    local function Update()
        local now = GetTime()
        for guid, spells in pairs(casts) do
            for key, cast in pairs(spells) do
                if now >= cast.ends or (not cast.confirmed
                    and now > cast.started + cast.interval + WINDOW) then
                    spells[key] = nil
                end
            end
            if not next(spells) then casts[guid] = nil end
        end
        for _, row in ipairs(getRows()) do
            local guid = row.present and readableGuid(row.unit)
            local spells = guid and casts[guid]
            local estimates = {}
            if spells then
                for key, cast in pairs(spells) do
                    if cast.damage then
                        local remaining = math.max(0,
                            math.floor((cast.ends - now) / cast.interval + 0.5))
                        -- Observed noncritical ticks reflect the caster's
                        -- current bonuses and the mob's damage modifiers.
                        -- Agony grows over time, so retain at least its
                        -- original average per tick while later ticks grow.
                        local perTick = cast.damage
                        if cast.observedDamage then
                            if key ~= "Bane of Agony" then
                                perTick = cast.observedDamage
                            else
                                perTick = math.max(perTick, cast.observedDamage)
                            end
                        end
                        estimates[key] = remaining * perTick
                    end
                end
            end
            local corruption = estimates["Corruption"] or 0
            local bane = estimates["Bane of Agony"] or 0
            local siphon = estimates["Siphon Life"] or 0
            local immolate = estimates["Immolate"] or 0
            local total = corruption + bane + siphon + immolate
            if total > 0
                and row.damageMarker and row.baneMarker
                and row.siphonMarker and row.immolateMarker then
                local ok, maximum = pcall(UnitHealthMax, row.unit)
                if ok and ((issecretvalue and issecretvalue(maximum))
                    or type(maximum) == "number") then
                    -- The native bar receives potentially secret max health.
                    -- Lua never compares or formats that value.
                    local scaled = pcall(row.damageMarker.SetMinMaxValues,
                        row.damageMarker, 0, maximum)
                    local baneScaled = pcall(row.baneMarker.SetMinMaxValues,
                        row.baneMarker, 0, maximum)
                    local siphonScaled = pcall(row.siphonMarker.SetMinMaxValues,
                        row.siphonMarker, 0, maximum)
                    local immolateScaled = pcall(row.immolateMarker.SetMinMaxValues,
                        row.immolateMarker, 0, maximum)
                    if scaled and baneScaled and siphonScaled and immolateScaled then
                        -- Cumulative native bars leave each spell's colored
                        -- portion visible behind the previous one.
                        pcall(row.immolateMarker.SetValue, row.immolateMarker,
                            corruption + bane + siphon + immolate)
                        pcall(row.siphonMarker.SetValue, row.siphonMarker,
                            corruption + bane + siphon)
                        pcall(row.baneMarker.SetValue, row.baneMarker,
                            corruption + bane)
                        pcall(row.damageMarker.SetValue, row.damageMarker,
                            corruption)
                    else
                        Clear(row)
                    end
                else
                    Clear(row)
                end
            else
                Clear(row)
            end
        end
    end

    local function Cast(unit, spellID)
        if (issecretvalue and issecretvalue(spellID))
            or unit ~= "player" then return end
        local key = spellKeys[spellID]
        local definition = key and SPELLS[key]
        if not definition then return end
        local guid = readableGuid("target")
        if guid == "unavailable" then return end
        local now = GetTime()
        local total, source = cachedTotals[spellID], cachedSources[spellID]
        if not total then
            total, source = DescriptionTotal(spellID, definition.duration, key)
        end
        if not total then
            total, source = DescriptionTotal(key, definition.duration, key)
        end
        if not total and learnedTicks[spellID]
            and (key == "Siphon Life" or key == "Immolate") then
            total = learnedTicks[spellID]
                * (definition.duration / definition.tick)
            source = "previous noncritical tick"
        end
        if not total and REVIEW_TOTALS[spellID] then
            total, source = REVIEW_TOTALS[spellID], "review calibration"
        end
        if not total then
            total = definition.fallback or 0
            source = definition.fallback and "fallback" or "waiting for first tick"
        end
        if WarlockHudTraceHUD then
            WarlockHudTraceHUD("Multi-Target damage: " .. key .. " spell "
                .. tostring(spellID) .. " total=" .. tostring(total)
                .. " source=" .. source)
        end
        local count = definition.duration / definition.tick
        casts[guid] = casts[guid] or {}
        casts[guid][key] = { started = now,
            ends = now + definition.duration, interval = definition.tick,
            school = definition.school, damage = total / count,
            spellID = spellID, key = key }
    end

    local function Hit(unit, action, flag, amount, school)
        if (issecretvalue and (issecretvalue(action) or issecretvalue(flag)
                or issecretvalue(school) or issecretvalue(amount)))
            or action ~= "WOUND" or (school ~= 32 and school ~= 4)
            or type(amount) ~= "number" or amount <= 0 then return end
        local guid = readableGuid(unit)
        if guid == "unavailable" then return end
        local spells = casts[guid]
        if not spells then return end
        local best, bestIndex, distance, ambiguous
        local now = GetTime()
        for _, cast in pairs(spells) do
            local elapsed = now - cast.started
            local index = math.floor(elapsed / cast.interval + 0.5)
            local difference = math.abs(elapsed - index * cast.interval)
            if cast.school == school and index >= 1
                and index <= (cast.ends - cast.started) / cast.interval
                and index > (cast.lastTickIndex or 0) and difference <= WINDOW
                and (cast.damage == 0 or (amount >= cast.damage * 0.4
                    and amount <= cast.damage * 2.5)) then
                if not distance or difference < distance - 0.15 then
                    best, bestIndex, distance, ambiguous = cast, index,
                        difference, false
                elseif math.abs(difference - distance) <= 0.15 then
                    ambiguous = true
                end
            end
        end
        if best and not ambiguous then
            best.lastTickIndex = bestIndex
            best.confirmed = true
            if type(flag) ~= "string" or not flag:find("CRITICAL", 1, true) then
                best.observedDamage = amount
                if best.key == "Siphon Life" or best.key == "Immolate" then
                    learnedTicks[best.spellID] = amount
                end
            end
        end
    end

    local driver = CreateFrame("Frame")
    driver:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    driver:RegisterEvent("UNIT_COMBAT")
    driver:RegisterEvent("PLAYER_LOGIN")
    driver:RegisterEvent("SPELLS_CHANGED")
    driver:RegisterEvent("SPELL_TEXT_UPDATE")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    driver:SetScript("OnEvent", function(_, event, unit, a, b, c, d)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            Cast(unit, b)
        elseif event == "UNIT_COMBAT" then
            Hit(unit, a, b, c, d)
        else
            RefreshDescriptions()
        end
    end)
    local elapsed = 0
    driver:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.2 then return end
        elapsed = 0
        Update()
    end)

    return { Update = Update, Clear = Clear }
end
