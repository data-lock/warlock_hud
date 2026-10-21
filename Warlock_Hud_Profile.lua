-- Profile normalization is deliberately in one place. Keep saved keys and
-- migration order stable so old profiles and share codes retain their meaning.
WarlockHudProfile = { DefaultSummonKeywords = "123, sum, summ" }

local function NormalizeOrder(order, defaults)
    local valid, seen, result = {}, {}, {}
    for _, key in ipairs(defaults) do valid[key] = true end
    if type(order) == "table" then
        for _, key in ipairs(order) do
            if valid[key] and not seen[key] then
                result[#result + 1] = key
                seen[key] = true
            end
        end
    end
    for _, key in ipairs(defaults) do
        if not seen[key] then result[#result + 1] = key end
    end
    return result
end

local function NormalizeTargetAndUtility(mainOrder, utilityOrder, mainDefaults, utilityDefaults)
    local valid, seen, main, utility = {}, {}, {}, {}
    for _, key in ipairs(mainDefaults) do valid[key] = true end
    for _, key in ipairs(utilityDefaults) do valid[key] = true end
    local function Append(source, result)
        if type(source) ~= "table" then return end
        for _, key in ipairs(source) do
            if valid[key] and not seen[key] then
                result[#result + 1] = key
                seen[key] = true
            end
        end
    end
    Append(mainOrder, main)
    Append(utilityOrder, utility)
    Append(mainDefaults, main)
    Append(utilityDefaults, utility)
    return main, utility
end

local function OptionalFontSize(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return math.max(minimum, math.min(maximum, math.floor(value + 0.5)))
end

function WarlockHudProfile.NormalizeSummonKeywords(value)
    if type(value) ~= "string" or #value > 142 or value:match("^%s*,")
        or value:match(",%s*,") or value:match(",%s*$") then return nil end
    local words, seen = {}, {}
    for part in value:gmatch("[^,]+") do
        local word = part:match("^%s*(.-)%s*$")
        if #word < 1 or #word > 16 or not word:match("^[A-Za-z0-9]+$") then
            return nil
        end
        local key = word:lower()
        if not seen[key] then
            words[#words + 1] = word
            seen[key] = true
        end
        if #words > 8 then return nil end
    end
    return #words > 0 and table.concat(words, ", ") or nil
end

function WarlockHudProfile.CreateNormalizer(keys)
    local effects = WarlockHudEffects
    local normalizeKeywords = WarlockHudProfile.NormalizeSummonKeywords
    local defaultKeywords = WarlockHudProfile.DefaultSummonKeywords
    return function(p)
        if type(p) ~= "table" then p = {} end
        p.mainSize = math.max(16, math.min(96, tonumber(p.mainSize) or 48))
        p.dotTimerMilliseconds = p.dotTimerMilliseconds ~= false
        p.cooldownSize = math.max(16, math.min(64, tonumber(p.cooldownSize) or 24))
        if not p.shardLayoutAdjusted then
            if p.shardSize == nil or tonumber(p.shardSize) == 24 then
                p.shardSize = 32
            end
            p.shardLayoutAdjusted = true
        end
        p.shardSize = math.max(16, math.min(64, tonumber(p.shardSize) or 32))
        p.buffSize = math.max(16, math.min(64, tonumber(p.buffSize) or 24))
        -- New profiles show MTD; an explicit saved off choice stays off.
        p.multiDotEnabled = p.multiDotEnabled ~= false
        p.multiDotThreatIndicator = p.multiDotThreatIndicator ~= false
        p.multiDotDamageEnabled = p.multiDotDamageEnabled ~= false
        p.multiDotHideOutOfCombat = p.multiDotHideOutOfCombat == true
        p.multiDotAlpha = math.max(0.3, math.min(1, tonumber(p.multiDotAlpha) or 1))
        p.multiDotScale = math.max(0.7, math.min(1.6, tonumber(p.multiDotScale) or 1))
        if not p.multiDotHealthLayoutVersion then
            p.multiDotWidth = math.max(430,
                tonumber(p.multiDotWidth) or 310 * p.multiDotScale)
            p.multiDotHealthLayoutVersion = 1
        end
        p.multiDotWidth = math.max(260, math.min(700,
            tonumber(p.multiDotWidth) or 430))
        p.multiDotHeight = math.max(150, math.min(800,
            tonumber(p.multiDotHeight) or 548 * p.multiDotScale))
        if (tonumber(p.consumesSchemaVersion) or 0) < 1 then
            -- Well Fed keeps its existing enabled flag. Copy row preferences once;
            -- subsequent loads must not follow later Buffs changes.
            if p.consumeSize == nil then p.consumeSize = p.buffSize end
            if p.colorActiveConsumes == nil then p.colorActiveConsumes = p.colorActiveBuffs end
            if type(p.showOutOfCombat) == "table"
                and p.showOutOfCombat.consumes == nil then
                p.showOutOfCombat.consumes = p.showOutOfCombat.buffs
            end
            p.consumesSchemaVersion = 1
        end
        if type(p.enabled) ~= "table" then p.enabled = {} end
        -- New categories stay opt-in even when an older share code omits them.
        for _, key in ipairs(keys.consume) do
            if key ~= "wellfed" and p.enabled[key] == nil then
                p.enabled[key] = false
            end
        end
        p.consumesSchemaVersion = 2
        if type(p.consumeReminders) ~= "table" then p.consumeReminders = {} end
        if p.consumeReminders.wellfed == nil then p.consumeReminders.wellfed = true end
        p.consumeSize = math.max(16, math.min(64, tonumber(p.consumeSize) or 24))
        p.procSize = math.max(20, math.min(64, tonumber(p.procSize) or 32))
        local validFonts = { friz = true, arial = true, morpheus = true,
            nimrod = true, skurri = true }
        if not validFonts[p.fontFace] then p.fontFace = nil end
        if not validFonts[p.multiTargetFontFace] then p.multiTargetFontFace = nil end
        p.fontIconSize = OptionalFontSize(p.fontIconSize, 8, 24)
        p.fontTimerSize = OptionalFontSize(p.fontTimerSize, 8, 30)
        p.fontMultiTargetSize = OptionalFontSize(p.fontMultiTargetSize, 8, 18)
        p.fontMultiTargetTimerSize = OptionalFontSize(p.fontMultiTargetTimerSize, 8, 24)
        p.shardDestroyCount = nil
        p.shardKeepCount = math.max(0, math.min(64, math.floor(tonumber(p.shardKeepCount) or 8)))
        p.shardWarningsEnabled = p.shardWarningsEnabled ~= false
        p.shardWarnOverflow = p.shardWarnOverflow ~= false
        if not p.shardWarningDefaultsV2 then
            if p.shardLowThreshold == 5 and p.shardHighThreshold == 20 then
                p.shardLowThreshold, p.shardHighThreshold = 4, 18
            end
            p.shardWarningDefaultsV2 = true
        end
        p.shardLowThreshold = math.max(0, math.min(63,
            math.floor(tonumber(p.shardLowThreshold) or 4)))
        p.shardHighThreshold = math.max(p.shardLowThreshold + 1, math.min(64,
            math.floor(tonumber(p.shardHighThreshold) or 18)))
        p.mainOrder, p.cooldownOrder = NormalizeTargetAndUtility(
            p.mainOrder, p.cooldownOrder, effects.MainKeys, keys.cooldown)
        p.buffOrder = NormalizeOrder(p.buffOrder, keys.buff)
        p.consumeOrder = NormalizeOrder(p.consumeOrder, keys.consume)
        if type(p.showOutOfCombat) ~= "table" then p.showOutOfCombat = {} end
        -- Unending Breath is optional and its native button is anchored after
        -- the packed buffs, so keep its settings tile at that same right edge.
        for index, key in ipairs(p.buffOrder) do
            if key == "breath" then
                table.remove(p.buffOrder, index)
                break
            end
        end
        p.buffOrder[#p.buffOrder + 1] = "breath"
        p.procOrder = NormalizeOrder(p.procOrder, keys.proc)
        if type(p.defaultDotIcons) ~= "table" then p.defaultDotIcons = {} end
        for key, slot in pairs(effects.DefaultSlots) do
            local selected = p.defaultDotIcons[key]
            local valid = false
            for _, spell in ipairs(effects.Spells) do
                if spell.slot == slot and spell.group ~= 2 and spell.name == selected then
                    valid = true
                    break
                end
            end
            if not valid then p.defaultDotIcons[key] = nil end
        end
        if p.notificationChannel ~= "GROUP" then p.notificationChannel = "SELF" end
        if p.summonKeywords == nil then
            local legacy = normalizeKeywords(p.summonKeyword)
            p.summonKeywords = legacy and legacy ~= "123"
                and legacy or defaultKeywords
        end
        if not p.summonKeywordDefaultsV2 then
            if p.summonKeywords == "123, summ, taxi, sum, sumplz" then
                p.summonKeywords = defaultKeywords
            end
            p.summonKeywordDefaultsV2 = true
        end
        p.summonKeywords = normalizeKeywords(p.summonKeywords)
            or defaultKeywords
        p.summonKeyword = nil
        p.summonQueueEnabled = p.summonQueueEnabled ~= false
        p.summonAutoRemoveNearby = p.summonAutoRemoveNearby ~= false
        if type(p.summonSources) ~= "table" then p.summonSources = {} end
        return p
    end
end
