-- Blizzard selects and renders each aura; this addon never reads target aura
-- data or computes a timer. Each spell rank has its own aura ID.
local SPELLS = {
    { name = "Corruption", slot = 1, ids = { 172, 6222, 6223, 7648, 11671, 11672, 25311 } },
    { name = "Immolate", slot = 5, ids = { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 } },
    { name = "Bane of Agony", slot = 2, ids = { 980, 1014, 6217, 11711, 11712, 11713 } },
    { name = "Bane of Doom", slot = 2, ids = { 603 } },
    { name = "Bane of Havoc", slot = 2, ids = { 1225228, 1243339 } },
    { name = "Curse of the Elements", slot = 3, ids = { 440892, 440982, 1311676, 1311677, 1311680, 1490, 11721, 11722 } },
    { name = "Curse of Weakness", slot = 3, ids = { 702, 1108, 6205, 7646, 11707, 11708 } },
    { name = "Curse of Recklessness", slot = 3, ids = { 704, 7658, 7659, 11717 } },
    { name = "Curse of Tongues", slot = 3, ids = { 1714, 11719 } },
    { name = "Curse of Exhaustion", slot = 3, ids = { 18223 } },
    { name = "Drain Soul", slot = 4, ids = { 1120, 8288, 8289, 11675 } },
    { name = "Drain Life", slot = 4, ids = { 689, 699, 709, 7651, 11699, 11700 } },
    { name = "Drain Mana", slot = 4, ids = { 5138, 6226, 11703, 11704 } },
    { name = "Siphon Life", slot = 6, ids = { 18265, 18879, 18880, 18881 } },
    { name = "Fear", group = 2, slot = 3, ids = { 5782, 6213, 6215 } },
}
local ICON_SIZE = 48
local COOLDOWN_ICON_SIZE = 24
local BUFF_ICON_SIZE = 24
local consumeState = { size = 24, keys = {
    "wellfed", "flask", "spelldamage", "shadow", "fire", "wizardoil", "manaregen",
}, glows = {} }
local PROC_ICON_SIZE = 32
local ICON_SPACING = 4
local BORDER_SIZE = 2
local ICON_CROP = (1 - 1 / 1.3) / 2
local IN_RANGE_COLOR = CreateColor(1, 1, 1, 1)
local OUT_OF_RANGE_COLOR = CreateColor(1, 0.2, 0.2, 1)

local container
local hudRoot
local rowFrames = {}
local soulstoneLabel
local armorGlow
local wellFedGlow
local shardState = {}
local playerAuraContainer
local wellFedSlotCreated = false
local icons = {}
local itemIcons = {}
local spellCooldownIcons = {}
local groupBuffIcons = {}
local sacrificeState
WarlockHudRowVisibility = {
    masks = {},
    containers = {},
}
local lastGroupCasterClasses = {}
local pendingSpecRebuild = false
local pendingKnownRebuild = false
local pendingDemonRebuild = false
local events = CreateFrame("Frame")
local ARMOR_IDS = { 687, 696, 706, 1086, 11733, 11734, 11735 }
local ARMOR_SPELL = { name = "Demon Armor", ids = ARMOR_IDS }
local SOUL_SHARD_ID = 6265
local function IsSoulShardBag(bag)
    if bag == 0 then return false end
    if not C_Container or not C_Container.GetContainerNumFreeSlots then return nil end
    local ok, _, family = pcall(C_Container.GetContainerNumFreeSlots, bag)
    if not ok or (issecretvalue and issecretvalue(family))
        or type(family) ~= "number" then return nil end
    return math.floor(family / 4) % 2 == 1
end
local MAIN_KEYS = { "corruption", "bane", "curse", "drain", "immolate", "siphonlife" }
local DEFAULT_SUMMON_KEYWORDS = "123, sum, summ"
local DOT_DEFAULT_SLOTS = { bane = 2, curse = 3, drain = 4 }
local COOLDOWN_KEYS = { "healthstone", "soulstone", "fear", "conflagrate", "racial1", "racial2", "demon" }
local BUFF_KEYS = { "fort", "motw", "int", "spirit", "kings", "salv", "armor", "thorns", "sacrifice", "soullink", "breath" }
local PROC_KEYS = { "powerinfusion", "nightfall" }
local PROCS = {
    { key = "powerinfusion", name = "Power Infusion", ids = { 10060 } },
    { key = "nightfall", name = "Shadow Trance", ids = { 17941 } },
}
local BUFFS = {
    { key = "fort", name = "Fortitude", casterClass = "PRIEST",
        names = { "Power Word: Fortitude", "Prayer of Fortitude" },
        ids = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 } },
    { key = "motw", name = "Mark of the Wild", casterClass = "DRUID",
        names = { "Mark of the Wild", "Gift of the Wild" },
        ids = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 48469,
            21849, 21850, 26991, 48470 } },
    { key = "int", name = "Arcane Intellect", casterClass = "MAGE",
        names = { "Arcane Intellect", "Arcane Brilliance" },
        ids = { 1459, 1460, 1461, 10156, 10157, 23028 } },
    { key = "spirit", name = "Divine Spirit", casterClass = "PRIEST",
        names = { "Divine Spirit", "Prayer of Spirit" },
        ids = { 14752, 14818, 14819, 27841, 27681 } },
    { key = "kings", name = "Blessing of Kings", casterClass = "PALADIN",
        names = { "Blessing of Kings", "Greater Blessing of Kings" },
        ids = { 20217, 25898 } },
    { key = "salv", name = "Blessing of Salvation", casterClass = "PALADIN",
        names = { "Blessing of Salvation", "Greater Blessing of Salvation" },
        ids = { 1038, 25895 } },
    { key = "thorns", name = "Thorns", casterClass = "DRUID",
        names = { "Thorns" },
        ids = { 467, 782, 1075, 8914, 9756, 9910, 26992, 53307 } },
    { key = "breath", name = "Unending Breath", activeOnly = true,
        names = { "Unending Breath" }, ids = { 5697 } },
    { key = "sacrifice", name = "Demonic Sacrifice", activeOnly = true,
        names = { "Burning Shadow", "Fel Stamina", "Touch of Fire", "Fel Energy" },
        ids = { 18789, 18790, 18791, 18792 } },
    { key = "soullink", name = "Soul Link", activeOnly = true,
        names = { "Soul Link" }, ids = { 25228, 19028 } },
}
local SACRIFICE_BUFF = BUFFS[#BUFFS - 1]
local profile
local wellFedIDs = { [19705] = true }
-- Forever aura IDs are item effects, not alchemy recipe or item IDs. The
-- unverified Greater Mageblood effect ID can be learned out of combat.
consumeState.effects = {
    { key = "flask", label = "Flask", names = { "Supreme Power" },
        ids = { [17628] = true }, itemID = 13512 },
    { key = "spelldamage", label = "Spell Damage Elixir",
        names = { "Lesser Arcane Elixir", "Arcane Elixir", "Greater Arcane Elixir" },
        ids = { [1250971] = true, [439959] = true, [11390] = true,
            [16889] = true }, itemID = 13454 },
    { key = "shadow", label = "Shadow Damage Elixir", names = { "Shadow Power" },
        ids = { [11474] = true }, itemID = 9264 },
    { key = "fire", label = "Fire Damage Elixir",
        names = { "Fire Power", "Greater Firepower" },
        ids = { [7844] = true, [26276] = true }, itemID = 21546 },
    { key = "manaregen", label = "Mana Regeneration",
        names = { "Minor Mageblood Elixir", "Lesser Mageblood Elixir",
            "Mana Regeneration", "Greater Mageblood Elixir" },
        learnNames = { "Greater Mageblood Elixir" },
        ids = { [1250942] = true, [1250944] = true, [24363] = true },
        itemID = 20007 },
}
consumeState.oilEnchantIDs = { [2623] = true, [2626] = true,
    [2627] = true, [2628] = true }
local buffIDs = {}
local buffSlotCreated = {}

for _, buff in ipairs(BUFFS) do
    buffIDs[buff.key] = {}
    for _, id in ipairs(buff.ids) do buffIDs[buff.key][id] = true end
end

local function LearnBuffs()
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataBySpellName
        or InCombatLockdown()
        or (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) then
        return
    end
    for _, buff in ipairs(BUFFS) do
        for _, name in ipairs(buff.names) do
            local ok, spellID = pcall(function()
                local aura = C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL")
                if aura then return aura.spellId end
            end)
            if ok and (not issecretvalue or not issecretvalue(spellID))
                and type(spellID) == "number" and not buffIDs[buff.key][spellID] then
                buffIDs[buff.key][spellID] = true
                WarlockHudDB.buffIDs = WarlockHudDB.buffIDs or {}
                WarlockHudDB.buffIDs[buff.key] = WarlockHudDB.buffIDs[buff.key] or {}
                WarlockHudDB.buffIDs[buff.key][spellID] = true
                local targetContainer = buff.key == "soullink"
                    and WarlockHudRowVisibility.containers.pet or playerAuraContainer
                if targetContainer and buffSlotCreated[buff.key] then
                    targetContainer:SetAuraSlotCandidateFilters(buff.key,
                        { includeSpellIDs = buffIDs[buff.key] })
                    targetContainer:UpdateAllAuras()
                end
            end
        end
    end
end

local function LearnWellFed()
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataBySpellName
        or InCombatLockdown()
        or (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) then
        return
    end
    local ok, spellID = pcall(function()
        local aura = C_UnitAuras.GetAuraDataBySpellName("player", "Well Fed", "HELPFUL")
        if aura then return aura.spellId end
    end)
    if not ok or (issecretvalue and issecretvalue(spellID)) then return end
    if type(spellID) ~= "number" or wellFedIDs[spellID] then return end
    wellFedIDs[spellID] = true
    WarlockHudDB.wellFedIDs = WarlockHudDB.wellFedIDs or {}
    WarlockHudDB.wellFedIDs[spellID] = true
    if consumeState.auraContainer and wellFedSlotCreated then
        consumeState.auraContainer:SetAuraSlotCandidateFilters("Well Fed", { includeSpellIDs = wellFedIDs })
        consumeState.auraContainer:UpdateAllAuras()
    end
end

local function LearnConsumables()
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataBySpellName
        or InCombatLockdown()
        or (C_Secrets and C_Secrets.ShouldAurasBeSecret
            and C_Secrets.ShouldAurasBeSecret()) then return end
    for _, effect in ipairs(consumeState.effects) do
        for _, name in ipairs(effect.learnNames or {}) do
            local ok, spellID = pcall(function()
                local aura = C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL")
                if aura then return aura.spellId end
            end)
            if ok and (not issecretvalue or not issecretvalue(spellID))
                and type(spellID) == "number" and not effect.ids[spellID] then
                effect.ids[spellID] = true
                WarlockHudDB.consumeIDs = WarlockHudDB.consumeIDs or {}
                WarlockHudDB.consumeIDs[effect.key] = WarlockHudDB.consumeIDs[effect.key] or {}
                WarlockHudDB.consumeIDs[effect.key][spellID] = true
                if consumeState.auraContainer and consumeState.slots
                    and consumeState.slots[effect.key] then
                    consumeState.auraContainer:SetAuraSlotCandidateFilters(
                        effect.label, { includeSpellIDs = effect.ids })
                    consumeState.auraContainer:UpdateAllAuras()
                end
            end
        end
    end
end

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

local function NormalizeSummonKeywords(value)
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

local function NormalizeProfile(p)
    if type(p) ~= "table" then p = {} end
    p.mainSize = math.max(16, math.min(96, tonumber(p.mainSize) or 48))
    p.cooldownSize = math.max(16, math.min(64, tonumber(p.cooldownSize) or 24))
    if not p.shardLayoutAdjusted then
        if p.shardSize == nil or tonumber(p.shardSize) == 24 then
            p.shardSize = 32
        end
        p.shardLayoutAdjusted = true
    end
    p.shardSize = math.max(16, math.min(64, tonumber(p.shardSize) or 32))
    p.buffSize = math.max(16, math.min(64, tonumber(p.buffSize) or 24))
    p.multiDotEnabled = p.multiDotEnabled == true
    p.multiDotScale = math.max(0.7, math.min(1.6, tonumber(p.multiDotScale) or 1))
    if not p.multiDotHealthLayoutVersion then
        p.multiDotWidth = math.max(430,
            tonumber(p.multiDotWidth) or 310 * p.multiDotScale)
        p.multiDotHealthLayoutVersion = 1
    end
    p.multiDotWidth = math.max(260, math.min(700,
        tonumber(p.multiDotWidth) or 430))
    p.multiDotHeight = math.max(287, math.min(640,
        tonumber(p.multiDotHeight) or 316 * p.multiDotScale))
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
    for _, key in ipairs(consumeState.keys) do
        if key ~= "wellfed" and p.enabled[key] == nil then
            p.enabled[key] = false
        end
    end
    p.consumesSchemaVersion = 2
    if type(p.consumeReminders) ~= "table" then p.consumeReminders = {} end
    if p.consumeReminders.wellfed == nil then p.consumeReminders.wellfed = true end
    p.consumeSize = math.max(16, math.min(64, tonumber(p.consumeSize) or 24))
    p.procSize = math.max(20, math.min(64, tonumber(p.procSize) or 32))
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
    p.mainOrder = NormalizeOrder(p.mainOrder, MAIN_KEYS)
    p.cooldownOrder = NormalizeOrder(p.cooldownOrder, COOLDOWN_KEYS)
    p.buffOrder = NormalizeOrder(p.buffOrder, BUFF_KEYS)
    p.consumeOrder = NormalizeOrder(p.consumeOrder, consumeState.keys)
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
    p.procOrder = NormalizeOrder(p.procOrder, PROC_KEYS)
    if type(p.defaultDotIcons) ~= "table" then p.defaultDotIcons = {} end
    for key, slot in pairs(DOT_DEFAULT_SLOTS) do
        local selected = p.defaultDotIcons[key]
        local valid = false
        for _, spell in ipairs(SPELLS) do
            if spell.slot == slot and spell.group ~= 2 and spell.name == selected then
                valid = true
                break
            end
        end
        if not valid then p.defaultDotIcons[key] = nil end
    end
    if p.notificationChannel ~= "GROUP" then p.notificationChannel = "SELF" end
    if p.summonKeywords == nil then
        local legacy = NormalizeSummonKeywords(p.summonKeyword)
        p.summonKeywords = legacy and legacy ~= "123"
            and legacy or DEFAULT_SUMMON_KEYWORDS
    end
    if not p.summonKeywordDefaultsV2 then
        if p.summonKeywords == "123, summ, taxi, sum, sumplz" then
            p.summonKeywords = DEFAULT_SUMMON_KEYWORDS
        end
        p.summonKeywordDefaultsV2 = true
    end
    p.summonKeywords = NormalizeSummonKeywords(p.summonKeywords)
        or DEFAULT_SUMMON_KEYWORDS
    p.summonKeyword = nil
    p.summonQueueEnabled = p.summonQueueEnabled ~= false
    p.summonAutoRemoveNearby = p.summonAutoRemoveNearby ~= false
    if type(p.summonSources) ~= "table" then p.summonSources = {} end
    return p
end

local function ActiveTalentGroup()
    local getters = {}
    if C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
        getters[#getters + 1] = C_SpecializationInfo.GetActiveSpecGroup
    end
    if GetActiveTalentGroup then getters[#getters + 1] = GetActiveTalentGroup end
    for _, getter in ipairs(getters) do
        local ok, group = pcall(getter)
        if ok and (not issecretvalue or not issecretvalue(group))
            and (group == 1 or group == 2) then
            return group
        end
    end
end

local function InitializeProfiles()
    if type(WarlockHudDB) ~= "table" then WarlockHudDB = {} end
    if type(WarlockHudDB.wellFedIDs) == "table" then
        for spellID, known in pairs(WarlockHudDB.wellFedIDs) do
            if type(spellID) == "number" and known then wellFedIDs[spellID] = true end
        end
    end
    if type(WarlockHudDB.consumeIDs) == "table" then
        for _, effect in ipairs(consumeState.effects) do
            local ids = WarlockHudDB.consumeIDs[effect.key]
            if type(ids) == "table" then
                for spellID, known in pairs(ids) do
                    if type(spellID) == "number" and known then
                        effect.ids[spellID] = true
                    end
                end
            end
        end
    end
    if type(WarlockHudDB.buffIDs) == "table" then
        for key, ids in pairs(WarlockHudDB.buffIDs) do
            if buffIDs[key] and type(ids) == "table" then
                for spellID, known in pairs(ids) do
                    if type(spellID) == "number" and known then buffIDs[key][spellID] = true end
                end
            end
        end
    end
    if type(WarlockHudDB.profiles) ~= "table" then
        -- Keep positions from versions that stored them at the top level.
        WarlockHudDB.profiles = { Default = NormalizeProfile({
            x = WarlockHudDB.x, y = WarlockHudDB.y,
            cooldownX = WarlockHudDB.cooldownX, cooldownY = WarlockHudDB.cooldownY,
        }) }
    end
    if not next(WarlockHudDB.profiles) then
        WarlockHudDB.profiles.Default = NormalizeProfile({})
    end
    for name, savedProfile in pairs(WarlockHudDB.profiles) do
        WarlockHudDB.profiles[name] = NormalizeProfile(savedProfile)
    end
    if type(WarlockHudDB.activeProfile) ~= "string"
        or not WarlockHudDB.profiles[WarlockHudDB.activeProfile] then
        WarlockHudDB.activeProfile = WarlockHudDB.profiles.Default and "Default"
            or next(WarlockHudDB.profiles)
    end
    if WarlockHudDB.autoSpecProfiles and type(WarlockHudDB.specProfiles) == "table" then
        local group = ActiveTalentGroup()
        local assigned = group and WarlockHudDB.specProfiles[group]
        if assigned and WarlockHudDB.profiles[assigned] then
            WarlockHudDB.activeProfile = assigned
        end
    end
    profile = WarlockHudDB.profiles[WarlockHudDB.activeProfile]
    ICON_SIZE = profile.mainSize
    COOLDOWN_ICON_SIZE = profile.cooldownSize
    BUFF_ICON_SIZE = profile.buffSize
    consumeState.size = profile.consumeSize
    PROC_ICON_SIZE = profile.procSize
end

local playerClass, playerGUID
local function PlayerIdentity()
    if not playerClass then _, playerClass = UnitClass("player") end
    if not playerGUID then playerGUID = UnitGUID("player") end
    return playerClass, playerGUID
end

local function IsAddonEnabled()
    local class, character = PlayerIdentity()
    local overrides = WarlockHudDB and WarlockHudDB.characterEnabled
    local choice = character and overrides and overrides[character]
    if choice ~= nil then return choice == true end
    return class == "WARLOCK"
end

local function SetAddonEnabled(value)
    local _, character = PlayerIdentity()
    if not character then return end
    WarlockHudDB.characterEnabled = WarlockHudDB.characterEnabled or {}
    WarlockHudDB.characterEnabled[character] = value and true or false
    if WarlockHudRefreshWandBinding then WarlockHudRefreshWandBinding() end
end

local function Enabled(key)
    return profile and profile.enabled[key] ~= false
end

local function GetDotDefaultSpell(key)
    local selected = profile and profile.defaultDotIcons
        and profile.defaultDotIcons[key]
    local slot = DOT_DEFAULT_SLOTS[key]
    if not selected or not slot then return nil end
    for _, spell in ipairs(SPELLS) do
        if spell.slot == slot and spell.group ~= 2
            and spell.name == selected then return spell end
    end
end

local function CastSpellTexture(spell, currentID)
    if not spell or not C_Spell or not C_Spell.GetSpellTexture then return nil end
    local identifiers = {}
    if currentID then identifiers[#identifiers + 1] = currentID end
    identifiers[#identifiers + 1] = spell.name
    for _, id in ipairs(spell.ids) do identifiers[#identifiers + 1] = id end
    for _, identifier in ipairs(identifiers) do
        local ok, texture = pcall(C_Spell.GetSpellTexture, identifier)
        if ok and texture and (not issecretvalue or not issecretvalue(texture))
            and texture ~= 134400
            and (type(texture) ~= "string"
                or not texture:lower():find("questionmark", 1, true)) then
            return texture
        end
    end
end

local function KnownSpellID(spellID)
    local checker = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell
    if not checker then return nil end
    local ok, known = pcall(checker, spellID)
    if not ok or (issecretvalue and issecretvalue(known)) then return nil end
    return known and true or false
end

local function KnownSpell(spell)
    local checked = false
    for _, spellID in ipairs(spell.ids) do
        local known = KnownSpellID(spellID)
        if known then return true end
        if known == false then checked = true end
    end
    local currentID = C_Spell and C_Spell.GetSpellIDForSpellIdentifier
        and C_Spell.GetSpellIDForSpellIdentifier(spell.name)
    if currentID then
        local known = KnownSpellID(currentID)
        if known then return true end
        if known == false then checked = true end
    end
    return not checked
end

function WarlockHudRowVisibility.ConflagrateSpellID()
    local spellID = C_Spell and C_Spell.GetSpellIDForSpellIdentifier
        and C_Spell.GetSpellIDForSpellIdentifier("Conflagrate")
    if spellID and KnownSpellID(spellID) == true then return spellID end
    for _, rankID in ipairs({ 18932, 18931, 18930, 17962, 1293818, 1293817 }) do
        if KnownSpellID(rankID) == true then return rankID end
    end
end

function WarlockHudRowVisibility.RefreshConflagrate()
    local entry = groupBuffIcons.conflagrate
    if not entry then return end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret
        and C_Secrets.ShouldAurasBeSecret() then
        entry.icon:SetDesaturated(true)
        entry.glow:Hide()
        return
    end
    local immolateActive = false
    for _, button in ipairs(entry.immolateButtons) do
        local ok, shown = pcall(button.IsShown, button)
        if not ok or (issecretvalue and issecretvalue(shown)) then
            entry.icon:SetDesaturated(true)
            entry.glow:Hide()
            return
        end
        if shown then
            immolateActive = true
            break
        end
    end
    entry.icon:SetDesaturated(not immolateActive)
    entry.glow:SetShown(immolateActive)
    if not immolateActive then entry.icon:SetAlpha(1) end
end

local function VisibleOrder(order)
    local visible = {}
    for _, key in ipairs(order) do
        local hasSpell = true
        if key == "fear" or key == "corruption" or key == "bane"
            or key == "curse" or key == "drain" or key == "immolate"
            or key == "siphonlife" then
            hasSpell = false
            for _, spell in ipairs(SPELLS) do
                local spellKey = spell.group == 2 and "fear" or MAIN_KEYS[spell.slot]
                if spellKey == key and Enabled(spell.name) and KnownSpell(spell) then
                    hasSpell = true
                    break
                end
            end
        elseif key == "armor" then
            hasSpell = KnownSpell(ARMOR_SPELL)
        elseif key == "soullink" then
            hasSpell = KnownSpellID(19028) == true
        elseif key == "conflagrate" then
            hasSpell = WarlockHudRowVisibility.ConflagrateSpellID() ~= nil
        elseif key == "demon" then
            hasSpell = KnownSpellID(688) == true
                and groupBuffIcons.demonLayoutVisible == true
        end
        if Enabled(key) and hasSpell then visible[#visible + 1] = key end
    end
    return visible
end

local function Position(order, key, size)
    for i, value in ipairs(order) do
        if value == key then
            return (i - (#order + 1) / 2) * (size + ICON_SPACING)
        end
    end
end

local STONES = {
    { name = "Healthstone", defaultID = 5512,
        ids = { 9421, 19012, 19013, 5510, 19010, 19011, 5509, 19008, 19009,
            5511, 19006, 19007, 5512, 19004, 19005 } },
    { name = "Soulstone", defaultID = 5232,
        ids = { 16896, 16895, 16893, 16892, 5232 } },
}

-- Only active racials have a cooldown to display. These are the five
-- races that can be Warlocks in Forever's current beta build.
local RACIALS = {
    [1] = { { "Perception", 20600 }, { "Will to Survive", 1259718 } },
    [7] = { { "Escape Artist", 20589 }, { "Eureka!", 1259821 } },
    [2] = { { "Blood Fury", 20572 }, { "Shatter Curse", 1299026 } },
    [5] = { { "Will of the Forsaken", 7744 }, { "Cannibalize", 20577 } },
    [8] = { { "Berserking", 20554 }, { "Rapid Regeneration", 1260270 } },
}

local function CooldownX(key)
    return Position(VisibleOrder(profile.cooldownOrder), key, COOLDOWN_ICON_SIZE)
end

local function MakeBorder(anchor, x, iconSize)
    iconSize = iconSize or ICON_SIZE
    local border = CreateFrame("Frame", nil, anchor)
    border:SetSize(iconSize + 2 * BORDER_SIZE, iconSize + 2 * BORDER_SIZE)
    border:SetPoint("CENTER", anchor, "CENTER", x, 0)
    border:SetFrameStrata(hudRoot:GetFrameStrata())
    border:SetFrameLevel(hudRoot:GetFrameLevel() + 3)
    local edges = {
        { "TOP", iconSize + 2 * BORDER_SIZE, BORDER_SIZE },
        { "BOTTOM", iconSize + 2 * BORDER_SIZE, BORDER_SIZE },
        { "LEFT", BORDER_SIZE, iconSize + 2 * BORDER_SIZE },
        { "RIGHT", BORDER_SIZE, iconSize + 2 * BORDER_SIZE },
    }
    for _, edgeInfo in ipairs(edges) do
        local edge = border:CreateTexture(nil, "OVERLAY")
        edge:SetSize(edgeInfo[2], edgeInfo[3])
        edge:SetPoint(edgeInfo[1], border, edgeInfo[1])
        edge:SetColorTexture(0, 0, 0, 1)
    end
    return border
end

local function MakeNativeButtonBorder(button, iconSize)
    local edges = {
        { "TOP", iconSize + 4, 2, 0, 2 },
        { "BOTTOM", iconSize + 4, 2, 0, -2 },
        { "LEFT", 2, iconSize + 4, -2, 0 },
        { "RIGHT", 2, iconSize + 4, 2, 0 },
    }
    for _, edgeInfo in ipairs(edges) do
        local edge = button:CreateTexture(nil, "OVERLAY")
        edge:SetSize(edgeInfo[2], edgeInfo[3])
        edge:SetPoint(edgeInfo[1], button, edgeInfo[1], edgeInfo[4], edgeInfo[5])
        edge:SetColorTexture(0, 0, 0, 1)
    end
end

local function MakeReminderGlow(anchor, x, border, iconSize, red)
    local glow = CreateFrame("Frame", nil, anchor)
    -- The border texture has transparent padding. Give it room outside the
    -- icon so the yellow pulse remains visible after row-three icons move.
    glow:SetSize(iconSize + 16, iconSize + 16)
    glow:SetPoint("CENTER", anchor, "CENTER", x, 0)
    glow:SetFrameStrata(hudRoot:GetFrameStrata())
    glow:SetFrameLevel(hudRoot:GetFrameLevel() + 1)
    local texture = glow:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(glow)
    texture:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    texture:SetBlendMode("ADD")
    glow.texture = texture
    if red then
        texture:SetVertexColor(1, 0.12, 0.12, 1)
    else
        texture:SetVertexColor(1, 0.75, 0, 1)
    end
    glow:SetScript("OnUpdate", function(self, elapsed)
        self.pulseTime = (self.pulseTime or 0) + elapsed
        local alpha = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(self.pulseTime * 6))
        self:SetAlpha(alpha)
        if self.pulseIcon then self.pulseIcon:SetAlpha(alpha) end
    end)
    glow:Hide()
    return glow
end

local function Report(message)
    print("|cffff7a7aWarlock HUD:|r " .. message)
end

local function HasShardOverflow()
    if not C_Container or not C_Container.GetContainerNumSlots
        or not C_Container.GetContainerItemID then return nil end
    local soulBagCapacity, regularShards = 0, false
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
        if not ok or (issecretvalue and issecretvalue(slots))
            or type(slots) ~= "number" then return nil end
        if slots > 0 then
            local isSoulBag = IsSoulShardBag(bag)
            if isSoulBag == nil then return nil end
            if isSoulBag then soulBagCapacity = soulBagCapacity + slots end
            for slot = 1, slots do
                local itemOK, itemID = pcall(C_Container.GetContainerItemID, bag, slot)
                if not itemOK or (issecretvalue and issecretvalue(itemID)) then return nil end
                if itemID == SOUL_SHARD_ID and not isSoulBag then regularShards = true end
            end
        end
    end
    return soulBagCapacity > 0 and regularShards
end

local function GetShardWarningState(count)
    if not profile or not profile.shardWarningsEnabled or type(count) ~= "number" then
        return "NORMAL"
    end
    if count <= profile.shardLowThreshold then return "LOW" end
    if count >= profile.shardHighThreshold then return "HIGH" end
    if profile.shardWarnOverflow and HasShardOverflow() then return "HIGH" end
    return "NORMAL"
end

local function UpdateShardWarningVisual(state, count)
    if not shardState.glow or not shardState.icon then return end
    if state == "NORMAL" then
        shardState.glow:Hide()
        shardState.icon:SetAlpha(1)
        shardState.icon:SetVertexColor(1, 1, 1)
        shardState.button:SetAlpha(count > 0 and 1 or 0.5)
        return
    end
    shardState.button:SetAlpha(1)
    shardState.icon:SetVertexColor(1,
        state == "LOW" and 0.2 or 0.85, state == "LOW" and 0.2 or 0.1)
    shardState.glow.texture:SetVertexColor(1,
        state == "LOW" and 0.12 or 0.75, state == "LOW" and 0.12 or 0)
    shardState.glow:Show()
end

local function GetSoulShardCount()
    if not C_Item or not C_Item.GetItemCount then return nil end
    local ok, count = pcall(C_Item.GetItemCount, SOUL_SHARD_ID)
    if not ok or (issecretvalue and issecretvalue(count))
        or type(count) ~= "number" then return nil end
    return count
end

local function UpdateShardCount()
    if not shardState.countText then return end
    local count = GetSoulShardCount()
    if not count then return end
    shardState.countText:SetText(count)
    UpdateShardWarningVisual(GetShardWarningState(count), count)
end

local function DestroyOneShard()
    if InCombatLockdown() then
        Report("Destroy soul shards after combat.")
        return false
    end
    if GetCursorInfo and GetCursorInfo() then
        Report("Clear your cursor before destroying a shard.")
        return false
    end
    if not GetCursorInfo or not C_Container or not C_Container.GetContainerItemID
        or not C_Container.GetContainerNumSlots
        or not C_Container.GetContainerNumFreeSlots or not DeleteCursorItem then
        Report("Soul shard deletion is unavailable on this client.")
        return false
    end
    local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(SOUL_SHARD_ID)
    if type(count) ~= "number" then
        Report("Soul shard count is unavailable on this client.")
        return false
    end
    if count <= profile.shardKeepCount then return false end
    for bag = 0, 4 do
        if IsSoulShardBag(bag) == false then
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            if C_Container.GetContainerItemID(bag, slot) == SOUL_SHARD_ID then
                local info = C_Container.GetContainerItemInfo
                    and C_Container.GetContainerItemInfo(bag, slot)
                if not info or not info.isLocked then
                    local stacked = info and info.stackCount and info.stackCount > 1
                    local pickup = stacked and C_Container.SplitContainerItem
                        or C_Container.PickupContainerItem
                    if not pickup then return false end
                    local ok
                    if stacked then
                        ok = pcall(pickup, bag, slot, 1)
                    else
                        ok = pcall(pickup, bag, slot)
                    end
                    if not ok then
                        Report("Could not pick up a soul shard.")
                        return false
                    end
                    local kind, itemID = GetCursorInfo()
                    if kind ~= "item" or itemID ~= SOUL_SHARD_ID then
                        if ClearCursor then ClearCursor() end
                        Report("No soul shard was picked up.")
                        return false
                    end
                    if not pcall(DeleteCursorItem) then
                        if ClearCursor then ClearCursor() end
                        Report("The client did not allow shard deletion.")
                        return false
                    end
                    UpdateShardCount()
                    return true
                end
            end
        end
        end
    end
    return false
end

local function DestroyShardClick()
    DestroyOneShard()
    UpdateShardCount()
end
shardState.click = DestroyShardClick

local function UpdateVisualState()
    local hasAttackableTarget = UnitExists("target")
        and not UnitIsDeadOrGhost("target")
        and UnitCanAttack("player", "target")
    if container then
        container:SetAlpha(hasAttackableTarget and 1 or 0.5)
    end
    if WarlockHudRowVisibility.containers.utility then
        WarlockHudRowVisibility.containers.utility:SetAlpha(
            hasAttackableTarget and 1 or 0.5)
    end
    for _, entry in ipairs(icons) do
        entry.icon:SetAlpha(hasAttackableTarget and 1 or 0.5)
        entry.border:SetAlpha(hasAttackableTarget and 1 or 0.5)
    end
    for _, entry in ipairs(itemIcons) do
        entry.icon:SetAlpha(1)
        entry.border:SetAlpha(1)
    end
end

local function RowAlpha(key)
    if not profile then return end
    local editMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    if key == "consumes" and profile.consumesEnabled == false and not editMode then
        return 0
    end
    local settings = profile.showOutOfCombat or {}
    return (InCombatLockdown() or editMode or settings[key] ~= false) and 1 or 0
end

local function UpdateRowVisibility()
    for key, mask in pairs(WarlockHudRowVisibility.masks) do
        local alpha = RowAlpha(key)
        mask:SetAlpha(alpha)
        if key == "shards" and shardState.button then
            shardState.button:EnableMouse(alpha == 1)
        end
    end
end
WarlockHudRowVisibility.Update = UpdateRowVisibility

local function UpdateStones()
    if not C_Item or not C_Item.GetItemCooldown then
        return
    end
    for _, entry in ipairs(itemIcons) do
        local chosen = entry.itemID or entry.stone.defaultID
        local owned = false
        for _, itemID in ipairs(entry.stone.ids) do
            if C_Item.GetItemCount and C_Item.GetItemCount(itemID) > 0 then
                chosen = itemID
                owned = true
                break
            end
        end
        if entry.itemID ~= chosen then
            entry.itemID = chosen
            local texture = C_Item.GetItemIconByID and C_Item.GetItemIconByID(chosen)
            if texture then
                entry.icon:SetTexture(texture)
            end
        end
        local start, duration = C_Item.GetItemCooldown(chosen)
        if start and duration then
            -- The widget accepts cooldown values without inspecting them in Lua.
            pcall(entry.cooldown.SetCooldown, entry.cooldown, start, duration)
        end
        if entry.stone.name == "Soulstone" then
            local ready
            if (not issecretvalue
                or (not issecretvalue(start) and not issecretvalue(duration)))
                and type(start) == "number" and type(duration) == "number" then
                ready = duration <= 0 or start + duration <= GetTime()
            elseif not owned then
                -- An uncreated stone has no usable item cooldown to wait for.
                ready = true
            end
            local target = WarlockHudSoulstoneAssignmentTarget
                and WarlockHudSoulstoneAssignmentTarget()
            local status = target and WarlockHudSoulstoneAuraStatus
                and WarlockHudSoulstoneAuraStatus(target)
            local flash = target and status == false and ready == true
            if WarlockHudSoulstoneWarningState then
                WarlockHudSoulstoneWarningState.owned = owned
                WarlockHudSoulstoneWarningState.ready = ready
                WarlockHudSoulstoneWarningState.status = status
                WarlockHudSoulstoneWarningState.target = target
                WarlockHudSoulstoneWarningState.flash = flash and true or false
                WarlockHudSoulstoneWarningState.cooldown =
                    (not issecretvalue or (not issecretvalue(start)
                        and not issecretvalue(duration)))
                    and (tostring(start) .. "/" .. tostring(duration)) or "secret"
            end
            entry.glow:SetShown(flash and true or false)
            entry.icon:SetDesaturated(not owned and not flash)
            if not flash then entry.icon:SetAlpha(1) end
        else
            entry.icon:SetDesaturated(not owned)
        end
    end
end

WarlockHudSoulstoneWarningState = {}

function WarlockHudSoulstoneWarningTraceState()
    if not WarlockHudTraceAssignment then return end
    local state = WarlockHudSoulstoneWarningState
    WarlockHudTraceAssignment("STATE", "soulstoneHUD target="
        .. tostring(state.target or "NONE") .. " aura="
        .. tostring(state.status) .. " owned=" .. tostring(state.owned)
        .. " ready=" .. tostring(state.ready)
        .. " cooldown=" .. tostring(state.cooldown)
        .. " flash=" .. tostring(state.flash), true)
end

function WarlockHudRefreshSoulstoneWarning()
    UpdateStones()
end

local function UpdateSpellCooldowns()
    if not C_Spell or not C_Spell.GetSpellCooldownDuration then
        return
    end
    for _, entry in ipairs(spellCooldownIcons) do
        local duration = C_Spell.GetSpellCooldownDuration(entry.spellID, true)
        if duration then
            pcall(entry.cooldown.SetCooldownFromDurationObject, entry.cooldown, duration)
        end
    end
end

local function ReadPlayerBuffNames(names)
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataBySpellName
        or (C_Secrets and C_Secrets.ShouldAurasBeSecret
            and C_Secrets.ShouldAurasBeSecret()) then return nil end
    for _, name in ipairs(names) do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName,
            "player", name, "HELPFUL")
        if not ok or (issecretvalue and issecretvalue(aura)) then return nil end
        if aura then return true end
    end
    return false
end

local function SetMissingGlow(glow, status, colorActive)
    if not glow then return end
    if status ~= nil and glow.pulseIcon and profile then
        glow.pulseIcon:SetDesaturated((status == true)
            ~= (colorActive ~= false))
    end
    local missing = status == false
    glow:SetShown(missing)
    if not missing and glow.pulseIcon then glow.pulseIcon:SetAlpha(1) end
end

local function UpdateArmorGlow()
    SetMissingGlow(armorGlow, ReadPlayerBuffNames({ "Demon Armor", "Demon Skin" }),
        profile.colorActiveBuffs)
end

local function UpdateWellFedGlow()
    SetMissingGlow(wellFedGlow, ReadPlayerBuffNames({ "Well Fed" }),
        profile.colorActiveConsumes)
    if wellFedGlow and profile.consumeReminders.wellfed == false then
        wellFedGlow:Hide()
        if wellFedGlow.pulseIcon then wellFedGlow.pulseIcon:SetAlpha(1) end
    end
end

local function ReadConsumableEffect(effect)
    if InCombatLockdown() or not C_UnitAuras
        or (C_Secrets and C_Secrets.ShouldAurasBeSecret
            and C_Secrets.ShouldAurasBeSecret()) then return nil end
    if not C_UnitAuras.GetPlayerAuraBySpellID then
        return ReadPlayerBuffNames(effect.names)
    end
    for spellID in pairs(effect.ids) do
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if not ok or (issecretvalue and issecretvalue(aura)) then return nil end
        if aura then return true end
    end
    return false
end

local function ReadWizardOil()
    -- Oils are temporary weapon enchants, not UNIT_AURA buffs. Never inspect
    -- or calculate their protected remaining time in Lua.
    if InCombatLockdown() or not C_Item or not C_Item.GetWeaponEnchantInfo
        or (C_Secrets and C_Secrets.ShouldAurasBeSecret
            and C_Secrets.ShouldAurasBeSecret()) then return nil end
    local ok, status = pcall(function()
        local enchants = C_Item.GetWeaponEnchantInfo(0)
        if (issecretvalue and issecretvalue(enchants))
            or type(enchants) ~= "table" then return nil end
        for _, enchant in ipairs(enchants) do
            if type(enchant) ~= "table" then return nil end
            local present, enchantType, id = enchant.hasEnchant,
                enchant.enchantType, enchant.enchantID
            if issecretvalue and (issecretvalue(present)
                or issecretvalue(enchantType) or issecretvalue(id)) then return nil end
            if present and type(id) ~= "number" then return nil end
            if present and consumeState.oilEnchantIDs[id] then return true end
        end
        return false
    end)
    if not ok or (issecretvalue and issecretvalue(status)) then return nil end
    return status
end

local function UpdateConsumableGlows()
    if not profile then return end
    for _, effect in ipairs(consumeState.effects) do
        local glow = consumeState.glows[effect.key]
        if glow then
            SetMissingGlow(glow, ReadConsumableEffect(effect),
                profile.colorActiveConsumes)
            if not profile.consumeReminders[effect.key] then
                glow:Hide()
                glow.pulseIcon:SetAlpha(1)
            end
        end
    end
    local oilGlow = consumeState.glows.wizardoil
    if oilGlow then
        SetMissingGlow(oilGlow, ReadWizardOil(), profile.colorActiveConsumes)
        if not profile.consumeReminders.wizardoil then
            oilGlow:Hide()
            oilGlow.pulseIcon:SetAlpha(1)
        end
    end
end

local function ReadGroupBuff(buff)
    if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID
        or (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) then
        return nil
    end
    local uncertain = false
    for spellID in pairs(buffIDs[buff.key]) do
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if ok and (not issecretvalue or not issecretvalue(aura)) then
            if aura ~= nil then return true end
        else
            uncertain = true
        end
    end
    if uncertain then
        if not C_UnitAuras.GetAuraDataBySpellName then return nil end
        for _, name in ipairs(buff.names) do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName,
                "player", name, "HELPFUL")
            if not ok or (issecretvalue and issecretvalue(aura)) then return nil end
            if aura ~= nil then return true end
        end
    end
    return false
end

local function DemonPresence()
    if not UnitExists or not UnitIsDeadOrGhost then return nil end
    local ok, exists, dead = pcall(function()
        local present = UnitExists("pet")
        return present, present and UnitIsDeadOrGhost("pet")
    end)
    if not ok or (issecretvalue and (issecretvalue(exists) or issecretvalue(dead))) then
        return nil
    end
    if exists and not dead then return true end
    return false
end

local function ReadDemonologyBuff(buff)
    if InCombatLockdown() then return nil end
    return ReadGroupBuff(buff)
end

function WarlockHudRowVisibility.DemonLayoutNeeded()
    return DemonPresence() == false
        and ReadDemonologyBuff(SACRIFICE_BUFF) == false
end

local function ReadSoulLink()
    if InCombatLockdown() or not C_UnitAuras
        or not C_UnitAuras.GetAuraDataBySpellName
        or (C_Secrets and C_Secrets.ShouldAurasBeSecret
            and C_Secrets.ShouldAurasBeSecret()) then return nil end
    for _, unit in ipairs({ "pet", "player" }) do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName,
            unit, "Soul Link", "HELPFUL")
        if not ok or (issecretvalue and issecretvalue(aura)) then return nil end
        if aura then return true end
    end
    return false
end

local function UpdateDemonology()
    if not profile then return end
    local pet = DemonPresence()
    local sacrifice = ReadDemonologyBuff(SACRIFICE_BUFF)
    sacrificeState = sacrifice
    local demonReminder = groupBuffIcons.demonReminder
    if demonReminder then
        local missing = pet == false and sacrifice == false
        demonReminder.icon:SetShown(missing)
        demonReminder.border:SetShown(missing)
        demonReminder.glow:SetShown(missing)
        if not missing then demonReminder.icon:SetAlpha(1) end
    end
    if (pet == true or sacrifice == true or (pet == false and sacrifice == false))
        and groupBuffIcons.demonLayoutVisible ~= (pet == false and sacrifice == false) then
        pendingDemonRebuild = true
    end
    local soulLinkReminder = groupBuffIcons.soulLinkReminder
    if soulLinkReminder then
        local active = ReadSoulLink()
        local missing = pet == true and active == false
        soulLinkReminder.icon:SetShown(missing)
        soulLinkReminder.border:SetShown(missing)
        soulLinkReminder.glow:SetShown(missing)
        if not missing then soulLinkReminder.icon:SetAlpha(1) end
        soulLinkReminder.holder:SetShown(pet == true or active ~= false)
    end
    if groupBuffIcons.holders and groupBuffIcons.holders.sacrifice then
        groupBuffIcons.holders.sacrifice:SetShown(sacrificeState ~= false)
    end
end

local function GroupCasterClasses()
    if InCombatLockdown() then return lastGroupCasterClasses end
    local classes = {}
    if not IsInGroup() then
        lastGroupCasterClasses = classes
        return classes
    end
    local raid = IsInRaid()
    local count = GetNumGroupMembers()
    for index = 1, raid and count or count - 1 do
        local unit = (raid and "raid" or "party") .. index
        local ok, class = pcall(function() return select(2, UnitClass(unit)) end)
        if ok and class and (not issecretvalue or not issecretvalue(class)) then
            classes[class] = true
        end
    end
    lastGroupCasterClasses = classes
    return classes
end

local function UpdateGroupBuffs()
    if not profile then return end
    UpdateDemonology()
    local classes = GroupCasterClasses()
    for _, entry in ipairs(groupBuffIcons) do
        if not entry.buff.activeOnly then
            local hasBuff = ReadGroupBuff(entry.buff)
            if hasBuff ~= nil then entry.hasBuff = hasBuff end
            local hasCaster = classes[entry.buff.casterClass] and true or false
            entry.hasCaster = hasCaster
            -- During restricted aura states, the last readable value may say
            -- "active" after the native aura button has already disappeared.
            -- Show the reminder icon for a present caster so its border never
            -- becomes an empty square; leave native aura rendering alone.
            entry.icon:SetShown(hasCaster
                and (hasBuff == nil or entry.hasBuff ~= true))
            entry.border:SetShown(hasCaster
                or (hasBuff ~= nil and entry.hasBuff == true))
            -- A caster being present does not prove the buff is absent. Keep
            -- the placeholder during unknown aura states, but only pulse on
            -- a confirmed missing result.
            entry.glow:SetShown(hasCaster and hasBuff == false)
            if hasBuff ~= false and entry.icon then entry.icon:SetAlpha(1) end
        end
    end
    local visible = 0
    local breathHolder
    for _, key in ipairs(profile.buffOrder) do
        local holder = groupBuffIcons.holders and groupBuffIcons.holders[key]
        if holder then
            if key == "breath" then
                breathHolder = holder
            else
                local shown = key == "armor"
                    or (key == "sacrifice" and sacrificeState ~= false)
                    or (key == "soullink" and groupBuffIcons.soulLinkReminder
                        and groupBuffIcons.soulLinkReminder.holder:IsShown())
                if not shown then
                    for _, entry in ipairs(groupBuffIcons) do
                        if entry.buff.key == key then
                            shown = entry.hasBuff == true or entry.hasCaster
                            break
                        end
                    end
                end
                holder:SetShown(shown and true or false)
                if shown then
                    holder:ClearAllPoints()
                    holder:SetPoint("CENTER", rowFrames.buffAnchor, "LEFT",
                        visible * (BUFF_ICON_SIZE + ICON_SPACING) + BUFF_ICON_SIZE / 2, 0)
                    visible = visible + 1
                end
            end
        end
    end
    if breathHolder then
        breathHolder:ClearAllPoints()
        breathHolder:SetPoint("CENTER", rowFrames.buffAnchor, "LEFT",
            visible * (BUFF_ICON_SIZE + ICON_SPACING) + BUFF_ICON_SIZE / 2, 0)
        breathHolder:Show()
    end
end

local function SetRangeColor(icon, inRange)
    if not icon then
        return
    end
    if (not issecretvalue or not issecretvalue(inRange)) and inRange == nil then
        icon:SetVertexColor(1, 1, 1)
    else
        icon:SetVertexColorFromBoolean(inRange, IN_RANGE_COLOR, OUT_OF_RANGE_COLOR)
    end
end

local function UpdateRange()
    if not C_Spell or not C_Spell.IsSpellInRange then
        return
    end

    for _, entry in ipairs(icons) do
        local inRange = C_Spell.IsSpellInRange(entry.rangeSpell.name, "target")
        SetRangeColor(entry.icon, inRange)
    end
end

local assignmentFlashes = {}
local activeAssignmentWarnings = {}
function WarlockHudPositionAssignmentHighlights()
    for key, frame in pairs(assignmentFlashes) do
        frame:Hide()
        if activeAssignmentWarnings[key] then
            for _, entry in ipairs(icons) do
                if entry.key == key then
                    frame:ClearAllPoints()
                    frame:SetPoint("CENTER", entry.icon, "CENTER")
                    frame:Show()
                    break
                end
            end
        end
    end
end

function WarlockHudPrepareAssignmentFlash(root, size)
    assignmentFlashes = {}
    for _, key in ipairs({ "curse", "bane" }) do
        local frame = CreateFrame("Frame", nil, root)
        frame:SetFrameLevel(root:GetFrameLevel() + 6)
        frame:SetSize(size, size)
        local tint = frame:CreateTexture(nil, "OVERLAY")
        tint:SetAllPoints(frame)
        tint:SetColorTexture(0.48, 0.12, 0.82, 0.5)
        local edges = {
            { "BOTTOM", "TOP", 0, 0, size + 8, 3, 0.85 },
            { "TOP", "BOTTOM", 0, 0, size + 8, 3, 0.85 },
            { "RIGHT", "LEFT", 0, 0, 3, size + 8, 0.85 },
            { "LEFT", "RIGHT", 0, 0, 3, size + 8, 0.85 },
            { "BOTTOM", "TOP", 0, 3, size + 14, 3, 0.3 },
            { "TOP", "BOTTOM", 0, -3, size + 14, 3, 0.3 },
            { "RIGHT", "LEFT", -3, 0, 3, size + 14, 0.3 },
            { "LEFT", "RIGHT", 3, 0, 3, size + 14, 0.3 },
        }
        for _, edge in ipairs(edges) do
            local glow = frame:CreateTexture(nil, "OVERLAY")
            glow:SetSize(edge[5], edge[6])
            glow:SetPoint(edge[1], frame, edge[2], edge[3], edge[4])
            glow:SetColorTexture(0.68, 0.28, 1, edge[7])
            glow:SetBlendMode("ADD")
        end
        frame:Hide()
        assignmentFlashes[key] = frame
    end
end
local function Build()
    if container then
        return
    end

    InitializeProfiles()
    if not IsAddonEnabled() then return end

    -- Build once at a safe time. The completed container can update in combat.
    if InCombatLockdown() or
        (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) then
        return
    end
    LearnConsumables()

    if not C_AddOns or not C_AddOns.LoadAddOn then
        Report("C_AddOns.LoadAddOn is unavailable.")
        return
    end

    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        local loaded, reason = C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        if not loaded then
            Report("Could not load Blizzard_AuraContainer: " .. tostring(reason))
            return
        end
    end

    hudRoot = CreateFrame("Frame", nil, UIParent)
    hudRoot:SetAllPoints(UIParent)
    hudRoot:SetFrameStrata(PlayerFrame and PlayerFrame:GetFrameStrata() or "LOW")
    hudRoot:SetFrameLevel(PlayerFrame and PlayerFrame:GetFrameLevel() or 1)
    for _, key in ipairs({ "main", "utility", "consumes", "buffs", "procs", "shards" }) do
        local mask = CreateFrame("Frame", nil, hudRoot)
        mask:SetAllPoints(UIParent)
        WarlockHudRowVisibility.masks[key] = mask
    end
    WarlockHudPrepareAssignmentFlash(WarlockHudRowVisibility.masks.main, ICON_SIZE)

    local auraContainer = CreateFrame("AuraContainer", nil,
        WarlockHudRowVisibility.masks.main, "CustomAuraContainerTemplate")
    if not auraContainer or type(auraContainer.AddAuraSlot) ~= "function" then
        Report("CustomAuraContainerTemplate is unavailable on this client.")
        return
    end
    local playerAuras = CreateFrame("AuraContainer", nil,
        WarlockHudRowVisibility.masks.buffs, "CustomAuraContainerTemplate")
    if not playerAuras or type(playerAuras.AddAuraSlot) ~= "function" then
        Report("Could not create the player buff container.")
        return
    end
    local consumeAuras = CreateFrame("AuraContainer", nil,
        WarlockHudRowVisibility.masks.consumes, "CustomAuraContainerTemplate")
    if not consumeAuras or type(consumeAuras.AddAuraSlot) ~= "function" then
        Report("Could not create the consumables aura container.")
        return
    end
    local petAuras = CreateFrame("AuraContainer", nil,
        WarlockHudRowVisibility.masks.buffs, "CustomAuraContainerTemplate")
    if not petAuras or type(petAuras.AddAuraSlot) ~= "function" then
        Report("Could not create the pet buff container.")
        return
    end
    local utilityAuras = CreateFrame("AuraContainer", nil,
        WarlockHudRowVisibility.masks.utility, "CustomAuraContainerTemplate")
    local procAuras = CreateFrame("AuraContainer", nil,
        WarlockHudRowVisibility.masks.procs, "CustomAuraContainerTemplate")
    if not utilityAuras or not procAuras then
        Report("Could not create the utility or proc aura container.")
        return
    end
    -- Native aura buttons cover their reminder glow within the HUD stratum.
    auraContainer:SetFrameLevel(hudRoot:GetFrameLevel() + 2)
    utilityAuras:SetFrameLevel(hudRoot:GetFrameLevel() + 2)
    playerAuras:SetFrameStrata(hudRoot:GetFrameStrata())
    playerAuras:SetFrameLevel(hudRoot:GetFrameLevel() + 2)
    consumeAuras:SetFrameStrata(hudRoot:GetFrameStrata())
    consumeAuras:SetFrameLevel(hudRoot:GetFrameLevel() + 2)
    petAuras:SetFrameStrata(hudRoot:GetFrameStrata())
    petAuras:SetFrameLevel(hudRoot:GetFrameLevel() + 2)
    procAuras:SetFrameStrata(hudRoot:GetFrameStrata())
    procAuras:SetFrameLevel(hudRoot:GetFrameLevel() + 2)
    WarlockHudRowVisibility.containers.utility = utilityAuras
    WarlockHudRowVisibility.containers.procs = procAuras
    WarlockHudRowVisibility.containers.pet = petAuras
    WarlockHudRowVisibility.containers.consumes = consumeAuras
    LearnWellFed()
    LearnBuffs()
    groupBuffIcons.demonLayoutVisible = WarlockHudRowVisibility.DemonLayoutNeeded()

    local mainOrder = VisibleOrder(profile.mainOrder)
    local cooldownOrder = VisibleOrder(profile.cooldownOrder)
    local buffOrder = VisibleOrder(profile.buffOrder)
    local consumeOrder = VisibleOrder(profile.consumeOrder)
    local procOrder = VisibleOrder(profile.procOrder)
    local rowWidth = math.max(1, #mainOrder * ICON_SIZE + math.max(0, #mainOrder - 1) * ICON_SPACING)
    rowFrames.hudAnchor = CreateFrame("Frame", nil, WarlockHudRowVisibility.masks.main)
    rowFrames.hudAnchor:SetSize(rowWidth, ICON_SIZE)
    rowFrames.hudAnchor:SetMovable(true)
    rowFrames.hudAnchor:SetClampedToScreen(true)
    local saved = profile
    if type(saved) == "table" and type(saved.x) == "number" and type(saved.y) == "number" then
        rowFrames.hudAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            saved.x * UIParent:GetWidth(), saved.y * UIParent:GetHeight())
    else
        rowFrames.hudAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    end

    rowFrames.editMover = CreateFrame("Button", nil, rowFrames.hudAnchor)
    rowFrames.editMover:SetAllPoints(rowFrames.hudAnchor)
    rowFrames.editMover:SetFrameStrata("DIALOG")
    rowFrames.editMover:EnableMouse(true)
    rowFrames.editMover:RegisterForDrag("LeftButton")
    local moverShade = rowFrames.editMover:CreateTexture(nil, "BACKGROUND")
    moverShade:SetAllPoints(rowFrames.editMover)
    moverShade:SetColorTexture(0, 0.65, 0.85, 0.25)
    local moverLabel = rowFrames.editMover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    moverLabel:SetPoint("BOTTOM", rowFrames.editMover, "TOP", 0, 5)
    moverLabel:SetText("Warlock HUD")
    rowFrames.editMover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then
            rowFrames.hudAnchor:StartMoving()
        end
    end)
    rowFrames.editMover:SetScript("OnDragStop", function()
        rowFrames.hudAnchor:StopMovingOrSizing()
        local centerX, centerY = rowFrames.hudAnchor:GetCenter()
        if centerX and centerY then
            local grid = EditModeManagerFrame and EditModeManagerFrame.Grid
            if grid and grid:IsShown() and type(grid.gridSpacing) == "number"
                and grid.gridSpacing > 0 then
                local gridX, gridY = grid:GetCenter()
                if gridX and gridY then
                    local spacing = grid.gridSpacing
                    centerX = gridX + math.floor((centerX - gridX) / spacing + 0.5) * spacing
                    centerY = gridY + math.floor((centerY - gridY) / spacing + 0.5) * spacing
                    rowFrames.hudAnchor:ClearAllPoints()
                    rowFrames.hudAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
                end
            end
            profile.x = centerX / UIParent:GetWidth()
            profile.y = centerY / UIParent:GetHeight()
        end
    end)
    rowFrames.editMover:Hide()

    local cooldownWidth = math.max(1, #cooldownOrder * COOLDOWN_ICON_SIZE
        + math.max(0, #cooldownOrder - 1) * ICON_SPACING)
    rowFrames.cooldownAnchor = CreateFrame("Frame", nil, WarlockHudRowVisibility.masks.utility)
    rowFrames.cooldownAnchor:SetSize(cooldownWidth, COOLDOWN_ICON_SIZE)
    rowFrames.cooldownAnchor:SetMovable(true)
    rowFrames.cooldownAnchor:SetClampedToScreen(true)
    if type(saved) == "table" and type(saved.cooldownX) == "number"
        and type(saved.cooldownY) == "number" then
        rowFrames.cooldownAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            saved.cooldownX * UIParent:GetWidth(), saved.cooldownY * UIParent:GetHeight())
    else
        rowFrames.cooldownAnchor:SetPoint("CENTER", rowFrames.hudAnchor, "CENTER", 0, -60)
    end
    rowFrames.cooldownMover = CreateFrame("Button", nil, rowFrames.cooldownAnchor)
    rowFrames.cooldownMover:SetAllPoints(rowFrames.cooldownAnchor)
    rowFrames.cooldownMover:SetFrameStrata("DIALOG")
    rowFrames.cooldownMover:EnableMouse(true)
    rowFrames.cooldownMover:RegisterForDrag("LeftButton")
    local cooldownShade = rowFrames.cooldownMover:CreateTexture(nil, "BACKGROUND")
    cooldownShade:SetAllPoints(rowFrames.cooldownMover)
    cooldownShade:SetColorTexture(0, 0.65, 0.85, 0.25)
    local cooldownLabel = rowFrames.cooldownMover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cooldownLabel:SetPoint("BOTTOM", rowFrames.cooldownMover, "TOP", 0, 5)
    cooldownLabel:SetText("Warlock HUD Cooldowns")
    rowFrames.cooldownMover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then
            rowFrames.cooldownAnchor:StartMoving()
        end
    end)
    rowFrames.cooldownMover:SetScript("OnDragStop", function()
        rowFrames.cooldownAnchor:StopMovingOrSizing()
        local centerX, centerY = rowFrames.cooldownAnchor:GetCenter()
        if centerX and centerY then
            local grid = EditModeManagerFrame and EditModeManagerFrame.Grid
            if grid and grid:IsShown() and type(grid.gridSpacing) == "number"
                and grid.gridSpacing > 0 then
                local gridX, gridY = grid:GetCenter()
                if gridX and gridY then
                    local spacing = grid.gridSpacing
                    centerX = gridX + math.floor((centerX - gridX) / spacing + 0.5) * spacing
                    centerY = gridY + math.floor((centerY - gridY) / spacing + 0.5) * spacing
                    rowFrames.cooldownAnchor:ClearAllPoints()
                    rowFrames.cooldownAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
                end
            end
            profile.cooldownX = centerX / UIParent:GetWidth()
            profile.cooldownY = centerY / UIParent:GetHeight()
        end
    end)
    rowFrames.cooldownMover:Hide()

    local buffWidth = math.max(1, #buffOrder * BUFF_ICON_SIZE
        + math.max(0, #buffOrder - 1) * ICON_SPACING)
    rowFrames.buffAnchor = CreateFrame("Frame", nil, WarlockHudRowVisibility.masks.buffs)
    rowFrames.buffAnchor:SetSize(buffWidth, BUFF_ICON_SIZE)
    rowFrames.buffAnchor:SetMovable(true)
    rowFrames.buffAnchor:SetClampedToScreen(true)
    if type(saved.buffX) == "number" and type(saved.buffY) == "number" then
        if not saved.buffLeftAligned then
            saved.buffX = saved.buffX - buffWidth / (2 * UIParent:GetWidth())
            saved.buffLeftAligned = true
        end
        rowFrames.buffAnchor:SetPoint("LEFT", UIParent, "BOTTOMLEFT",
            saved.buffX * UIParent:GetWidth(), saved.buffY * UIParent:GetHeight())
    elseif PlayerFrame then
        local fullWidth = #BUFF_KEYS * BUFF_ICON_SIZE
            + (#BUFF_KEYS - 1) * ICON_SPACING
        rowFrames.buffAnchor:SetPoint("LEFT", PlayerFrame, "TOP",
            -fullWidth / 2, 12 + BUFF_ICON_SIZE / 2)
    else
        rowFrames.buffAnchor:SetPoint("LEFT", UIParent, "BOTTOMLEFT",
            180, 210 + BUFF_ICON_SIZE / 2)
    end
    rowFrames.buffMover = CreateFrame("Button", nil, rowFrames.buffAnchor)
    rowFrames.buffMover:SetAllPoints(rowFrames.buffAnchor)
    rowFrames.buffMover:SetFrameStrata("DIALOG")
    rowFrames.buffMover:EnableMouse(true)
    rowFrames.buffMover:RegisterForDrag("LeftButton")
    local buffShade = rowFrames.buffMover:CreateTexture(nil, "BACKGROUND")
    buffShade:SetAllPoints(rowFrames.buffMover)
    buffShade:SetColorTexture(0, 0.65, 0.85, 0.25)
    local buffLabel = rowFrames.buffMover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    buffLabel:SetPoint("BOTTOM", rowFrames.buffMover, "TOP", 0, 5)
    buffLabel:SetText("Warlock HUD Buffs")
    rowFrames.buffMover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then rowFrames.buffAnchor:StartMoving() end
    end)
    rowFrames.buffMover:SetScript("OnDragStop", function()
        rowFrames.buffAnchor:StopMovingOrSizing()
        local leftX = rowFrames.buffAnchor:GetLeft()
        local _, centerY = rowFrames.buffAnchor:GetCenter()
        if leftX and centerY then
            local grid = EditModeManagerFrame and EditModeManagerFrame.Grid
            if grid and grid:IsShown() and type(grid.gridSpacing) == "number"
                and grid.gridSpacing > 0 then
                local gridX, gridY = grid:GetCenter()
                if gridX and gridY then
                    local spacing = grid.gridSpacing
                    leftX = gridX + math.floor((leftX - gridX) / spacing + 0.5) * spacing
                    centerY = gridY + math.floor((centerY - gridY) / spacing + 0.5) * spacing
                    rowFrames.buffAnchor:ClearAllPoints()
                    rowFrames.buffAnchor:SetPoint("LEFT", UIParent, "BOTTOMLEFT", leftX, centerY)
                end
            end
            profile.buffX = leftX / UIParent:GetWidth()
            profile.buffY = centerY / UIParent:GetHeight()
            profile.buffLeftAligned = true
        end
    end)
    rowFrames.buffMover:Hide()

    local consumeWidth = math.max(1, #consumeOrder * consumeState.size
        + math.max(0, #consumeOrder - 1) * ICON_SPACING)
    consumeState.anchor = CreateFrame("Frame", nil, WarlockHudRowVisibility.masks.consumes)
    consumeState.anchor:SetSize(consumeWidth, consumeState.size)
    consumeState.anchor:SetMovable(true)
    consumeState.anchor:SetClampedToScreen(true)
    if type(saved.consumeX) == "number" and type(saved.consumeY) == "number" then
        if not saved.consumeLeftAligned then
            local buffCenterX, buffCenterY = rowFrames.buffAnchor:GetCenter()
            local defaultY = buffCenterY
                and buffCenterY + (BUFF_ICON_SIZE + consumeState.size) / 2 + 18
            if buffCenterX and defaultY and rowFrames.buffAnchor:GetLeft()
                and math.abs(saved.consumeX * UIParent:GetWidth() - buffCenterX) < 1
                and math.abs(saved.consumeY * UIParent:GetHeight() - defaultY) < 1 then
                saved.consumeX = rowFrames.buffAnchor:GetLeft() / UIParent:GetWidth()
            else
                saved.consumeX = saved.consumeX - consumeWidth / (2 * UIParent:GetWidth())
            end
            saved.consumeLeftAligned = true
        end
        consumeState.anchor:SetPoint("LEFT", UIParent, "BOTTOMLEFT",
            saved.consumeX * UIParent:GetWidth(), saved.consumeY * UIParent:GetHeight())
    else
        local buffLeftX = rowFrames.buffAnchor:GetLeft()
        local _, buffCenterY = rowFrames.buffAnchor:GetCenter()
        buffLeftX = buffLeftX or UIParent:GetWidth() / 2
        buffCenterY = buffCenterY or UIParent:GetHeight() / 2
        local consumeY = buffCenterY + (BUFF_ICON_SIZE + consumeState.size) / 2 + 18
        consumeState.anchor:SetPoint("LEFT", UIParent, "BOTTOMLEFT", buffLeftX, consumeY)
        saved.consumeX = buffLeftX / UIParent:GetWidth()
        saved.consumeY = consumeY / UIParent:GetHeight()
        saved.consumeLeftAligned = true
    end
    consumeState.mover = CreateFrame("Button", nil, consumeState.anchor)
    consumeState.mover:SetAllPoints(consumeState.anchor)
    consumeState.mover:SetFrameStrata("DIALOG")
    consumeState.mover:EnableMouse(true)
    consumeState.mover:RegisterForDrag("LeftButton")
    local consumeShade = consumeState.mover:CreateTexture(nil, "BACKGROUND")
    consumeShade:SetAllPoints(consumeState.mover)
    consumeShade:SetColorTexture(0, 0.65, 0.85, 0.25)
    local consumeLabel = consumeState.mover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    consumeLabel:SetPoint("BOTTOM", consumeState.mover, "TOP", 0, 5)
    consumeLabel:SetText("Warlock HUD Consumes")
    consumeState.mover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then consumeState.anchor:StartMoving() end
    end)
    consumeState.mover:SetScript("OnDragStop", function()
        consumeState.anchor:StopMovingOrSizing()
        local leftX = consumeState.anchor:GetLeft()
        local _, centerY = consumeState.anchor:GetCenter()
        if leftX and centerY then
            local grid = EditModeManagerFrame and EditModeManagerFrame.Grid
            if grid and grid:IsShown() and type(grid.gridSpacing) == "number"
                and grid.gridSpacing > 0 then
                local gridX, gridY = grid:GetCenter()
                if gridX and gridY then
                    local spacing = grid.gridSpacing
                    leftX = gridX + math.floor((leftX - gridX) / spacing + 0.5) * spacing
                    centerY = gridY + math.floor((centerY - gridY) / spacing + 0.5) * spacing
                    consumeState.anchor:ClearAllPoints()
                    consumeState.anchor:SetPoint("LEFT", UIParent, "BOTTOMLEFT", leftX, centerY)
                end
            end
            profile.consumeX = leftX / UIParent:GetWidth()
            profile.consumeY = centerY / UIParent:GetHeight()
            profile.consumeLeftAligned = true
        end
    end)
    consumeState.mover:Hide()

    local procWidth = math.max(1, #procOrder * PROC_ICON_SIZE
        + math.max(0, #procOrder - 1) * ICON_SPACING)
    rowFrames.procAnchor = CreateFrame("Frame", nil, WarlockHudRowVisibility.masks.procs)
    rowFrames.procAnchor:SetSize(procWidth, PROC_ICON_SIZE)
    rowFrames.procAnchor:SetMovable(true)
    rowFrames.procAnchor:SetClampedToScreen(true)
    if type(saved.procX) == "number" and type(saved.procY) == "number" then
        rowFrames.procAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            saved.procX * UIParent:GetWidth(), saved.procY * UIParent:GetHeight())
    else
        rowFrames.procAnchor:SetPoint("BOTTOM", rowFrames.hudAnchor, "TOP", 0, 12)
    end
    rowFrames.procMover = CreateFrame("Button", nil, rowFrames.procAnchor)
    rowFrames.procMover:SetAllPoints(rowFrames.procAnchor)
    rowFrames.procMover:SetFrameStrata("DIALOG")
    rowFrames.procMover:EnableMouse(true)
    rowFrames.procMover:RegisterForDrag("LeftButton")
    local procShade = rowFrames.procMover:CreateTexture(nil, "BACKGROUND")
    procShade:SetAllPoints(rowFrames.procMover)
    procShade:SetColorTexture(0, 0.65, 0.85, 0.25)
    local procLabel = rowFrames.procMover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    procLabel:SetPoint("BOTTOM", rowFrames.procMover, "TOP", 0, 5)
    procLabel:SetText("Warlock HUD Procs")
    rowFrames.procMover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then rowFrames.procAnchor:StartMoving() end
    end)
    rowFrames.procMover:SetScript("OnDragStop", function()
        rowFrames.procAnchor:StopMovingOrSizing()
        local centerX, centerY = rowFrames.procAnchor:GetCenter()
        if centerX and centerY then
            local grid = EditModeManagerFrame and EditModeManagerFrame.Grid
            if grid and grid:IsShown() and type(grid.gridSpacing) == "number"
                and grid.gridSpacing > 0 then
                local gridX, gridY = grid:GetCenter()
                if gridX and gridY then
                    local spacing = grid.gridSpacing
                    centerX = gridX + math.floor((centerX - gridX) / spacing + 0.5) * spacing
                    centerY = gridY + math.floor((centerY - gridY) / spacing + 0.5) * spacing
                    rowFrames.procAnchor:ClearAllPoints()
                    rowFrames.procAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
                end
            end
            profile.procX = centerX / UIParent:GetWidth()
            profile.procY = centerY / UIParent:GetHeight()
        end
    end)
    rowFrames.procMover:Hide()

    for _, stone in ipairs(STONES) do
        local x = CooldownX(stone.name == "Healthstone" and "healthstone" or "soulstone")
        if x then
        local icon = rowFrames.cooldownAnchor:CreateTexture(nil, "ARTWORK")
        icon:SetSize(COOLDOWN_ICON_SIZE, COOLDOWN_ICON_SIZE)
        icon:SetPoint("CENTER", rowFrames.cooldownAnchor, "CENTER", x, 0)
        icon:SetTexture(C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(stone.defaultID))
        icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        if stone.name == "Soulstone" then
            soulstoneLabel = rowFrames.cooldownAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            soulstoneLabel:SetPoint("TOP", rowFrames.cooldownAnchor, "BOTTOM", 0, -5)
            soulstoneLabel:SetWidth(220)
            soulstoneLabel:SetJustifyH("CENTER")
        end
        local cooldown = CreateFrame("Cooldown", nil, rowFrames.cooldownAnchor, "CooldownFrameTemplate")
        cooldown:SetAllPoints(icon)
        cooldown:SetDrawBling(false)
        cooldown:SetDrawEdge(false)
        cooldown:SetHideCountdownNumbers(true)
        local border = MakeBorder(rowFrames.cooldownAnchor, x, COOLDOWN_ICON_SIZE)
        local glow
        if stone.name == "Soulstone" then
            glow = MakeReminderGlow(rowFrames.cooldownAnchor, x, border, COOLDOWN_ICON_SIZE, true)
            glow.pulseIcon = icon
        end
        itemIcons[#itemIcons + 1] = {
            stone = stone, icon = icon, border = border, cooldown = cooldown,
            glow = glow,
        }
        end
    end

    local _, _, raceID = UnitRace("player")
    for index, racial in ipairs(RACIALS[raceID] or {}) do
        local x = CooldownX("racial" .. index)
        if x then
        local icon = rowFrames.cooldownAnchor:CreateTexture(nil, "ARTWORK")
        icon:SetSize(COOLDOWN_ICON_SIZE, COOLDOWN_ICON_SIZE)
        icon:SetPoint("CENTER", rowFrames.cooldownAnchor, "CENTER", x, 0)
        icon:SetTexture(C_Spell.GetSpellTexture(racial[2]))
        icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        local cooldown = CreateFrame("Cooldown", nil, rowFrames.cooldownAnchor, "CooldownFrameTemplate")
        cooldown:SetAllPoints(icon)
        cooldown:SetDrawBling(false)
        cooldown:SetDrawEdge(false)
        cooldown:SetHideCountdownNumbers(true)
        spellCooldownIcons[#spellCooldownIcons + 1] = {
            spellID = racial[2], cooldown = cooldown,
            border = MakeBorder(rowFrames.cooldownAnchor, x, COOLDOWN_ICON_SIZE),
        }
        end
    end

    local conflagrateID = WarlockHudRowVisibility.ConflagrateSpellID()
    local conflagrateX = CooldownX("conflagrate")
    if conflagrateID and conflagrateX then
        local icon = rowFrames.cooldownAnchor:CreateTexture(nil, "ARTWORK")
        icon:SetSize(COOLDOWN_ICON_SIZE, COOLDOWN_ICON_SIZE)
        icon:SetPoint("CENTER", rowFrames.cooldownAnchor, "CENTER", conflagrateX, 0)
        icon:SetTexture(C_Spell.GetSpellTexture(conflagrateID))
        icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        local cooldown = CreateFrame("Cooldown", nil, rowFrames.cooldownAnchor, "CooldownFrameTemplate")
        cooldown:SetAllPoints(icon)
        cooldown:SetDrawBling(false)
        cooldown:SetDrawEdge(false)
        cooldown:SetHideCountdownNumbers(false)
        spellCooldownIcons[#spellCooldownIcons + 1] = {
            spellID = conflagrateID, cooldown = cooldown,
            border = MakeBorder(rowFrames.cooldownAnchor, conflagrateX, COOLDOWN_ICON_SIZE),
        }
        local glow = MakeReminderGlow(rowFrames.cooldownAnchor, conflagrateX, nil,
            COOLDOWN_ICON_SIZE)
        glow.pulseIcon = icon
        groupBuffIcons.conflagrate = {
            icon = icon, glow = glow, immolateButtons = {},
        }
        icon:SetDesaturated(true)
    end

    local demonX = CooldownX("demon")
    if demonX then
        local icon = rowFrames.cooldownAnchor:CreateTexture(nil, "ARTWORK")
        icon:SetSize(COOLDOWN_ICON_SIZE, COOLDOWN_ICON_SIZE)
        icon:SetPoint("CENTER", rowFrames.cooldownAnchor, "CENTER", demonX, 0)
        icon:SetTexture(C_Spell.GetSpellTexture(5500))
        icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        icon:SetVertexColor(1, 0.3, 0.3, 1)
        local border = MakeBorder(rowFrames.cooldownAnchor, demonX, COOLDOWN_ICON_SIZE)
        local glow = MakeReminderGlow(rowFrames.cooldownAnchor, demonX, border,
            COOLDOWN_ICON_SIZE, true)
        glow.pulseIcon = icon
        groupBuffIcons.demonReminder = { icon = icon, border = border, glow = glow }
        icon:Hide()
        border:Hide()
    end

    if profile.enabled.soulshards ~= false then
        local shardSize = profile.shardSize
        local shardAnchor = CreateFrame("Frame", nil, WarlockHudRowVisibility.masks.shards)
        shardState.anchor = shardAnchor
        shardAnchor:SetSize(shardSize, shardSize)
        shardAnchor:SetMovable(true)
        shardAnchor:SetClampedToScreen(true)
        if type(saved.shardX) == "number" and type(saved.shardY) == "number" then
            shardAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
                saved.shardX * UIParent:GetWidth(), saved.shardY * UIParent:GetHeight())
        elseif PlayerFrame then
            shardAnchor:SetPoint("RIGHT", PlayerFrame, "TOPLEFT", -8, -44)
        else
            shardAnchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 100, 210)
        end
        local shardMover = CreateFrame("Button", nil, shardAnchor)
        shardState.mover = shardMover
        shardMover:SetAllPoints(shardAnchor)
        shardMover:SetFrameStrata("DIALOG")
        shardMover:EnableMouse(true)
        shardMover:RegisterForDrag("LeftButton")
        local shardShade = shardMover:CreateTexture(nil, "BACKGROUND")
        shardShade:SetAllPoints(shardMover)
        shardShade:SetColorTexture(0, 0.65, 0.85, 0.25)
        local shardLabel = shardMover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        shardLabel:SetPoint("BOTTOM", shardMover, "TOP", 0, 5)
        shardLabel:SetText("Soul Shards")
        shardMover:SetScript("OnDragStart", function()
            if not InCombatLockdown() then shardAnchor:StartMoving() end
        end)
        shardMover:SetScript("OnDragStop", function()
            shardAnchor:StopMovingOrSizing()
            local centerX, centerY = shardAnchor:GetCenter()
            if centerX and centerY then
                local grid = EditModeManagerFrame and EditModeManagerFrame.Grid
                if grid and grid:IsShown() and type(grid.gridSpacing) == "number"
                    and grid.gridSpacing > 0 then
                    local gridX, gridY = grid:GetCenter()
                    if gridX and gridY then
                        local spacing = grid.gridSpacing
                        centerX = gridX + math.floor((centerX - gridX) / spacing + 0.5) * spacing
                        centerY = gridY + math.floor((centerY - gridY) / spacing + 0.5) * spacing
                        shardAnchor:ClearAllPoints()
                        shardAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
                    end
                end
                profile.shardX = centerX / UIParent:GetWidth()
                profile.shardY = centerY / UIParent:GetHeight()
            end
        end)
        shardMover:Hide()
        local shardButton = CreateFrame("Button", nil, shardAnchor)
        shardState.button = shardButton
        shardButton:SetSize(shardSize, shardSize)
        shardButton:SetPoint("CENTER", shardAnchor, "CENTER")
        shardButton:RegisterForClicks("LeftButtonUp")
        local icon = shardButton:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(shardButton)
        icon:SetTexture(C_Item and C_Item.GetItemIconByID
            and C_Item.GetItemIconByID(SOUL_SHARD_ID)
            or "Interface\\Icons\\INV_Misc_Gem_Amethyst_02")
        icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        shardState.icon = icon
        local shardCountText = shardButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        shardState.countText = shardCountText
        shardCountText:SetPoint("BOTTOMRIGHT", shardButton, "BOTTOMRIGHT", -2, 2)
        shardCountText:SetTextColor(1, 1, 1)
        shardButton:SetScript("OnClick", shardState.click)
        shardButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Soul Shards")
            GameTooltip:AddLine("Click to destroy one shard from a regular bag.", 1, 1, 1)
            GameTooltip:AddLine("Stops when regular bags are clear or " ..
                profile.shardKeepCount .. " shards remain.", 1, 1, 1)
            GameTooltip:AddLine("Unavailable in combat.", 1, 1, 1)
            GameTooltip:Show()
        end)
        shardButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        MakeBorder(shardAnchor, 0, shardSize)
        shardState.glow = MakeReminderGlow(shardAnchor, 0, nil, shardSize)
        shardState.glow.pulseIcon = icon
        UpdateShardCount()
    end

    auraContainer:SetSize(rowWidth, ICON_SIZE)
    auraContainer:SetPoint("CENTER", rowFrames.hudAnchor, "CENTER")

    local baseCreated = {}
    for _, spell in ipairs(SPELLS) do
        local includeSpellIDs = {}
        for _, spellID in ipairs(spell.ids) do
            includeSpellIDs[spellID] = true
        end
        local currentSpellID = C_Spell and C_Spell.GetSpellIDForSpellIdentifier
            and C_Spell.GetSpellIDForSpellIdentifier(spell.name)
        if currentSpellID then
            includeSpellIDs[currentSpellID] = true
        end
        local groupKey = spell.group == 2 and "fear" or MAIN_KEYS[spell.slot]
        local x = spell.group == 2 and CooldownX(groupKey)
            or Position(mainOrder, groupKey, ICON_SIZE)
        if x and Enabled(spell.name) and KnownSpell(spell) and next(includeSpellIDs) then
            local anchor = spell.group == 2 and rowFrames.cooldownAnchor or rowFrames.hudAnchor
            local iconSize = spell.group == 2 and COOLDOWN_ICON_SIZE or ICON_SIZE
            if not baseCreated[groupKey] then
                local assigned = WarlockHudAssignmentSpell
                    and WarlockHudAssignmentSpell(groupKey)
                local preview = assigned or spell
                local selected = profile.defaultDotIcons
                    and profile.defaultDotIcons[groupKey]
                if selected and not assigned then
                    for _, candidate in ipairs(SPELLS) do
                        if candidate.slot == spell.slot
                            and candidate.name == selected then
                            preview = candidate
                            break
                        end
                    end
                end
                local previewID = C_Spell and C_Spell.GetSpellIDForSpellIdentifier
                    and C_Spell.GetSpellIDForSpellIdentifier(preview.name)
                    or preview.ids[1]
                local icon = anchor:CreateTexture(nil, "ARTWORK")
                icon:SetSize(iconSize, iconSize)
                icon:SetPoint("CENTER", anchor, "CENTER", x, 0)
                icon:SetTexture(CastSpellTexture(preview, previewID)
                    or CastSpellTexture(spell, currentSpellID))
                icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
                if spell.group ~= 2 then
                    icon:SetDesaturated(profile.colorActiveDoTs ~= false)
                end
                icons[#icons + 1] = {
                    spell = spell, key = groupKey, rangeSpell = preview,
                    icon = icon, border = MakeBorder(anchor, x, iconSize),
                }
                baseCreated[groupKey] = true
            end

            (spell.group == 2 and utilityAuras or auraContainer):AddAuraSlot(
                spell.name, "HARMFUL|PLAYER", {
                candidateFilters = {
                    includeSpellIDs = includeSpellIDs,
                },
                initializeFrame = function(button)
                    button:SetSize(iconSize, iconSize)
                    button:ClearAllPoints()
                    button:SetPoint("CENTER", anchor, "CENTER", x, 0)
                    if spell.name == "Immolate" and groupBuffIcons.conflagrate then
                        local entry = groupBuffIcons.conflagrate
                        entry.immolateButtons[#entry.immolateButtons + 1] = button
                    end

                    local auraIcon = button:CreateTexture(nil, "ARTWORK")
                    auraIcon:SetAllPoints(button)
                    auraIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
                    if spell.group ~= 2 then
                        auraIcon:SetDesaturated(profile.colorActiveDoTs == false)
                    end
                    button:SetIcon(auraIcon)
                    if spell.group ~= 2 then
                        -- Forever can supply a question-mark aura texture for a
                        -- custom effect. This slot represents one cast spell,
                        -- so its known cast texture can cover that placeholder
                        -- while Blizzard still owns visibility and duration.
                        local castTexture = CastSpellTexture(spell, currentSpellID)
                        if castTexture then
                            local castIcon = button:CreateTexture(nil, "OVERLAY")
                            castIcon:SetAllPoints(button)
                            castIcon:SetTexture(castTexture)
                            castIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP,
                                ICON_CROP, 1 - ICON_CROP)
                            castIcon:SetDesaturated(profile.colorActiveDoTs == false)
                        end
                    end

                    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                    cooldown:SetAllPoints(button)
                    cooldown:SetDrawBling(false)
                    cooldown:SetDrawEdge(false)
                    if spell.group == 2 then
                        cooldown:SetHideCountdownNumbers(true)
                    else
                        cooldown:SetCountdownMillisecondsThreshold(10)
                        cooldown:SetReverse(true)
                    end
                    button:SetDurationCooldown(cooldown)
                end,
            })
        end
    end

    for _, key in ipairs(buffOrder) do
        local holder = CreateFrame("Frame", nil, rowFrames.buffAnchor)
        holder:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
        holder:SetPoint("CENTER", rowFrames.buffAnchor, "CENTER",
            Position(buffOrder, key, BUFF_ICON_SIZE), 0)
        groupBuffIcons.holders = groupBuffIcons.holders or {}
        groupBuffIcons.holders[key] = holder
    end
    local armorX = Position(buffOrder, "armor", BUFF_ICON_SIZE)
    if armorX then
    local armorHolder = groupBuffIcons.holders.armor
    local armorIcon = armorHolder:CreateTexture(nil, "ARTWORK")
    armorIcon:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
    armorIcon:SetPoint("CENTER", armorHolder, "CENTER")
    armorIcon:SetTexture(C_Spell.GetSpellTexture(
        C_Spell.GetSpellIDForSpellIdentifier("Demon Armor")
        or C_Spell.GetSpellIDForSpellIdentifier("Demon Skin") or 706))
    armorIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    armorIcon:SetDesaturated(profile.colorActiveBuffs ~= false)
    local armorBorder = MakeBorder(armorHolder, 0, BUFF_ICON_SIZE)
    armorGlow = MakeReminderGlow(armorHolder, 0, armorBorder, BUFF_ICON_SIZE)
    armorGlow.pulseIcon = armorIcon

    local armorIDs = {}
    for _, spellID in ipairs(ARMOR_IDS) do
        armorIDs[spellID] = true
    end
    for _, spellName in ipairs({ "Demon Armor", "Demon Skin" }) do
        local currentArmorID = C_Spell.GetSpellIDForSpellIdentifier(spellName)
        if currentArmorID then
            armorIDs[currentArmorID] = true
            local known = false
            for _, spellID in ipairs(ARMOR_IDS) do
                if spellID == currentArmorID then known = true break end
            end
            if not known then ARMOR_IDS[#ARMOR_IDS + 1] = currentArmorID end
        end
    end
    playerAuras:AddAuraSlot("Demon Armor / Demon Skin", "HELPFUL|PLAYER", {
        candidateFilters = { includeSpellIDs = armorIDs },
        initializeFrame = function(button)
            button:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
            button:ClearAllPoints()
            button:SetPoint("CENTER", armorHolder, "CENTER")
            local auraIcon = button:CreateTexture(nil, "ARTWORK")
            auraIcon:SetAllPoints(button)
            auraIcon:SetDesaturated(profile.colorActiveBuffs == false)
            auraIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
            button:SetIcon(auraIcon)
            local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            cooldown:SetAllPoints(button)
            cooldown:SetDrawBling(false)
            cooldown:SetDrawEdge(false)
            cooldown:SetHideCountdownNumbers(true)
            cooldown:SetReverse(true)
            button:SetDurationCooldown(cooldown)
        end,
    })
    end

    local consumeHolders = {}
    for index, key in ipairs(consumeOrder) do
        local holder = CreateFrame("Frame", nil, consumeState.anchor)
        holder:SetSize(consumeState.size, consumeState.size)
        holder:SetPoint("CENTER", consumeState.anchor, "LEFT",
            (index - 1) * (consumeState.size + ICON_SPACING)
                + consumeState.size / 2, 0)
        consumeHolders[key] = holder
    end
    local foodX = Position(consumeOrder, "wellfed", consumeState.size)
    if foodX then
        local foodHolder = consumeHolders.wellfed
        wellFedSlotCreated = true
        local foodIcon = foodHolder:CreateTexture(nil, "ARTWORK")
        foodIcon:SetSize(consumeState.size, consumeState.size)
        foodIcon:SetPoint("CENTER", foodHolder, "CENTER")
        foodIcon:SetTexture(C_Spell.GetSpellTexture(19705) or "Interface\\Icons\\INV_Misc_Food_15")
        foodIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        foodIcon:SetDesaturated(profile.colorActiveConsumes ~= false)
        local foodBorder = MakeBorder(foodHolder, 0, consumeState.size)
        wellFedGlow = MakeReminderGlow(foodHolder, 0, foodBorder, consumeState.size)
        wellFedGlow.pulseIcon = foodIcon
        consumeAuras:AddAuraSlot("Well Fed", "HELPFUL", {
            candidateFilters = { includeSpellIDs = wellFedIDs },
            initializeFrame = function(button)
                button:SetSize(consumeState.size, consumeState.size)
                button:ClearAllPoints()
                button:SetPoint("CENTER", foodHolder, "CENTER")
                local auraIcon = button:CreateTexture(nil, "ARTWORK")
                auraIcon:SetAllPoints(button)
                auraIcon:SetDesaturated(profile.colorActiveConsumes == false)
                auraIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
                button:SetIcon(auraIcon)
                local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                cooldown:SetAllPoints(button)
                cooldown:SetDrawBling(false)
                cooldown:SetDrawEdge(false)
                cooldown:SetHideCountdownNumbers(true)
                cooldown:SetReverse(true)
                button:SetDurationCooldown(cooldown)
            end,
        })
    end

    consumeState.glows = {}
    consumeState.slots = {}
    for _, effect in ipairs(consumeState.effects) do
        local holder = consumeHolders[effect.key]
        if holder then
            local icon = holder:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(holder)
            icon:SetTexture(C_Item and C_Item.GetItemIconByID
                and C_Item.GetItemIconByID(effect.itemID)
                or C_Spell.GetSpellTexture(next(effect.ids)))
            icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
            icon:SetDesaturated(profile.colorActiveConsumes ~= false)
            local border = MakeBorder(holder, 0, consumeState.size)
            local glow = MakeReminderGlow(holder, 0, border, consumeState.size, true)
            glow.pulseIcon = icon
            consumeState.glows[effect.key] = glow
            consumeState.slots[effect.key] = true
            consumeAuras:AddAuraSlot(effect.label, "HELPFUL|PLAYER", {
                candidateFilters = { includeSpellIDs = effect.ids },
                initializeFrame = function(button)
                    button:SetSize(consumeState.size, consumeState.size)
                    button:ClearAllPoints()
                    button:SetPoint("CENTER", holder, "CENTER")
                    local auraIcon = button:CreateTexture(nil, "ARTWORK")
                    auraIcon:SetAllPoints(button)
                    auraIcon:SetDesaturated(profile.colorActiveConsumes == false)
                    auraIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP,
                        ICON_CROP, 1 - ICON_CROP)
                    button:SetIcon(auraIcon)
                    local cooldown = CreateFrame("Cooldown", nil, button,
                        "CooldownFrameTemplate")
                    cooldown:SetAllPoints(button)
                    cooldown:SetDrawBling(false)
                    cooldown:SetDrawEdge(false)
                    cooldown:SetHideCountdownNumbers(true)
                    cooldown:SetReverse(true)
                    button:SetDurationCooldown(cooldown)
                end,
            })
        end
    end
    local oilHolder = consumeHolders.wizardoil
    if oilHolder then
        oilHolder:EnableMouse(true)
        oilHolder:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Wizard Oil")
            GameTooltip:AddLine("Tracks Minor, Lesser, regular, or Brilliant Wizard Oil on your main-hand weapon.",
                1, 1, 1, true)
            GameTooltip:AddLine("No HUD timer is shown for temporary weapon enchants.",
                1, 1, 1, true)
            GameTooltip:Show()
        end)
        oilHolder:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local oilIcon = oilHolder:CreateTexture(nil, "ARTWORK")
        oilIcon:SetAllPoints(oilHolder)
        oilIcon:SetTexture(C_Item and C_Item.GetItemIconByID
            and C_Item.GetItemIconByID(20749)
            or "Interface\\Icons\\INV_Potion_104")
        oilIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        oilIcon:SetDesaturated(profile.colorActiveConsumes ~= false)
        local oilBorder = MakeBorder(oilHolder, 0, consumeState.size)
        local oilGlow = MakeReminderGlow(oilHolder, 0, oilBorder,
            consumeState.size, true)
        oilGlow.pulseIcon = oilIcon
        consumeState.glows.wizardoil = oilGlow
    end

    for _, buff in ipairs(BUFFS) do
        local x = Position(buffOrder, buff.key, BUFF_ICON_SIZE)
        if x then
            local holder = groupBuffIcons.holders[buff.key]
            for _, name in ipairs(buff.names) do
                local spellID = C_Spell.GetSpellIDForSpellIdentifier(name)
                if spellID then buffIDs[buff.key][spellID] = true end
            end
            local icon, border, glow
            if not buff.activeOnly then
                icon = holder:CreateTexture(nil, "ARTWORK")
                icon:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
                icon:SetPoint("CENTER", holder, "CENTER")
                icon:SetTexture(C_Spell.GetSpellTexture(buff.ids[1])
                    or "Interface\\Icons\\INV_Misc_QuestionMark")
                icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
                icon:SetDesaturated(profile.colorActiveBuffs ~= false)
                border = MakeBorder(holder, 0, BUFF_ICON_SIZE)
                glow = MakeReminderGlow(holder, 0, border, BUFF_ICON_SIZE, true)
                glow.pulseIcon = icon
            elseif buff.key == "soullink" then
                icon = holder:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints(holder)
                icon:SetTexture(C_Spell.GetSpellTexture(19028)
                    or "Interface\\Icons\\Spell_Shadow_GatherShadows")
                icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
                icon:SetDesaturated(profile.colorActiveBuffs ~= false)
                border = MakeBorder(holder, 0, BUFF_ICON_SIZE)
                glow = MakeReminderGlow(holder, 0, border, BUFF_ICON_SIZE, true)
                glow.pulseIcon = icon
                groupBuffIcons.soulLinkReminder = { holder = holder, icon = icon,
                    border = border, glow = glow }
                icon:Hide()
                border:Hide()
            end
            groupBuffIcons[#groupBuffIcons + 1] = {
                buff = buff, icon = icon, border = border, glow = glow,
            }
            buffSlotCreated[buff.key] = true
            (buff.key == "soullink" and petAuras or playerAuras):AddAuraSlot(buff.key, "HELPFUL", {
                candidateFilters = { includeSpellIDs = buffIDs[buff.key] },
                initializeFrame = function(button)
                    button:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
                    button:ClearAllPoints()
                    button:SetPoint("CENTER", holder, "CENTER")
                    local auraIcon = button:CreateTexture(nil, "ARTWORK")
                    auraIcon:SetAllPoints(button)
                    auraIcon:SetDesaturated(profile.colorActiveBuffs == false)
                    auraIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
                    button:SetIcon(auraIcon)
                    if buff.activeOnly then
                        MakeNativeButtonBorder(button, BUFF_ICON_SIZE)
                    end
                    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                    cooldown:SetAllPoints(button)
                    cooldown:SetDrawBling(false)
                    cooldown:SetDrawEdge(false)
                    cooldown:SetHideCountdownNumbers(true)
                    cooldown:SetReverse(true)
                    button:SetDurationCooldown(cooldown)
                end,
            })
        end
    end

    for _, proc in ipairs(PROCS) do
        local x = Position(procOrder, proc.key, PROC_ICON_SIZE)
        if x then
            local includeSpellIDs = {}
            for _, spellID in ipairs(proc.ids) do includeSpellIDs[spellID] = true end
            local currentID = C_Spell.GetSpellIDForSpellIdentifier(proc.name)
            if currentID then includeSpellIDs[currentID] = true end
            procAuras:AddAuraSlot(proc.key, "HELPFUL", {
                candidateFilters = { includeSpellIDs = includeSpellIDs },
                initializeFrame = function(button)
                    button:SetSize(PROC_ICON_SIZE, PROC_ICON_SIZE)
                    button:ClearAllPoints()
                    button:SetPoint("CENTER", rowFrames.procAnchor, "CENTER", x, 0)
                    local auraIcon = button:CreateTexture(nil, "ARTWORK")
                    auraIcon:SetAllPoints(button)
                    auraIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
                    button:SetIcon(auraIcon)

                    local glow = CreateFrame("Frame", nil, button)
                    glow:SetSize(PROC_ICON_SIZE + 20, PROC_ICON_SIZE + 20)
                    glow:SetPoint("CENTER", button, "CENTER")
                    local glowTexture = glow:CreateTexture(nil, "OVERLAY")
                    glowTexture:SetAllPoints(glow)
                    glowTexture:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                    glowTexture:SetBlendMode("ADD")
                    glowTexture:SetVertexColor(1, 0.72, 0.12, 1)
                    local pulse = glow:CreateAnimationGroup()
                    pulse:SetLooping("BOUNCE")
                    local fade = pulse:CreateAnimation("Alpha")
                    fade:SetFromAlpha(0.25)
                    fade:SetToAlpha(1)
                    fade:SetDuration(0.45)
                    pulse:Play()

                    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                    cooldown:SetAllPoints(button)
                    cooldown:SetDrawBling(false)
                    cooldown:SetDrawEdge(false)
                    cooldown:SetHideCountdownNumbers(false)
                    cooldown:SetReverse(true)
                    button:SetDurationCooldown(cooldown)
                end,
            })
        end
    end

    playerAuras:SetSize(math.max(1, #buffOrder * BUFF_ICON_SIZE), BUFF_ICON_SIZE)
    playerAuras:SetPoint("CENTER", rowFrames.buffAnchor, "CENTER")
    consumeAuras:SetSize(consumeWidth, consumeState.size)
    consumeAuras:SetPoint("LEFT", consumeState.anchor, "LEFT")
    petAuras:SetSize(math.max(1, #buffOrder * BUFF_ICON_SIZE), BUFF_ICON_SIZE)
    petAuras:SetPoint("CENTER", rowFrames.buffAnchor, "CENTER")
    utilityAuras:SetSize(cooldownWidth, COOLDOWN_ICON_SIZE)
    utilityAuras:SetPoint("CENTER", rowFrames.cooldownAnchor, "CENTER")
    procAuras:SetSize(math.max(1, #procOrder * PROC_ICON_SIZE), PROC_ICON_SIZE)
    procAuras:SetPoint("CENTER", rowFrames.procAnchor, "CENTER")

    auraContainer:SetUnit("target")
    auraContainer:Show()
    auraContainer:UpdateAllAuras()
    utilityAuras:SetUnit("target")
    utilityAuras:Show()
    utilityAuras:UpdateAllAuras()
    playerAuras:SetUnit("player")
    playerAuras:Show()
    playerAuras:UpdateAllAuras()
    consumeAuras:SetUnit("player")
    consumeAuras:Show()
    consumeAuras:UpdateAllAuras()
    petAuras:SetUnit("pet")
    petAuras:Show()
    petAuras:UpdateAllAuras()
    procAuras:SetUnit("player")
    procAuras:Show()
    procAuras:UpdateAllAuras()
    playerAuraContainer = playerAuras
    consumeState.auraContainer = consumeAuras
    container = auraContainer
    UpdateVisualState()
    UpdateRange()
    UpdateStones()
    UpdateSpellCooldowns()
    WarlockHudRowVisibility.RefreshConflagrate()
    UpdateArmorGlow()
    UpdateWellFedGlow()
    UpdateConsumableGlows()
    UpdateGroupBuffs()
    WarlockHudRowVisibility.Update()
    WarlockHudPositionAssignmentHighlights()
end

local function Rebuild()
    if InCombatLockdown() or
        (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) then
        return false
    end
    if hudRoot then hudRoot:Hide() end
    hudRoot = nil
    container = nil
    playerAuraContainer = nil
    consumeState.auraContainer = nil
    consumeState.glows, consumeState.slots = {}, nil
    wellFedSlotCreated = false
    buffSlotCreated = {}
    armorGlow = nil
    wellFedGlow = nil
    shardState.button, shardState.countText = nil, nil
    shardState.anchor, shardState.mover = nil, nil
    shardState.icon, shardState.glow = nil, nil
    rowFrames.hudAnchor, rowFrames.editMover, rowFrames.cooldownAnchor, rowFrames.cooldownMover = nil, nil, nil, nil
    soulstoneLabel = nil
    rowFrames.buffAnchor, rowFrames.buffMover = nil, nil
    consumeState.anchor, consumeState.mover = nil, nil
    rowFrames.procAnchor, rowFrames.procMover = nil, nil
    icons, itemIcons, spellCooldownIcons, groupBuffIcons = {}, {}, {}, {}
    WarlockHudRowVisibility.masks = {}
    WarlockHudRowVisibility.containers = {}
    assignmentFlashes = {}
    if not IsAddonEnabled() then
        pendingKnownRebuild = false
        pendingSpecRebuild = false
        pendingDemonRebuild = false
        if WarlockHudRefreshNameplates then WarlockHudRefreshNameplates() end
        return true
    end
    Build()
    if WarlockHudRefreshNameplates then WarlockHudRefreshNameplates() end
    if container then
        pendingKnownRebuild = false
        pendingSpecRebuild = false
        pendingDemonRebuild = false
        return true
    end
    return false
end

function WarlockHudRefreshAssignmentIcons()
    if not profile then return end
    for _, entry in ipairs(icons) do
        if entry.key == "bane" or entry.key == "curse" then
            local preview = WarlockHudAssignmentSpell
                and WarlockHudAssignmentSpell(entry.key)
                or GetDotDefaultSpell(entry.key) or entry.spell
            entry.rangeSpell = preview
            local id = C_Spell and C_Spell.GetSpellIDForSpellIdentifier
                and C_Spell.GetSpellIDForSpellIdentifier(preview.name)
                or preview.ids[1]
            local texture = CastSpellTexture(preview, id)
            if texture then entry.icon:SetTexture(texture) end
        end
    end
    UpdateRange()
    WarlockHudPositionAssignmentHighlights()
end

function WarlockHudFlashAssignmentSlot(key, show)
    if key == "curse" or key == "bane" then
        activeAssignmentWarnings[key] = show and true or nil
    elseif not show then
        activeAssignmentWarnings.curse = nil
        activeAssignmentWarnings.bane = nil
    end
    WarlockHudPositionAssignmentHighlights()
end

local function UpdateSpecProfile()
    if not WarlockHudDB or not WarlockHudDB.autoSpecProfiles then return end
    local previous = WarlockHudDB.activeProfile
    InitializeProfiles()
    if WarlockHudDB.activeProfile ~= previous then
        if Rebuild() then
            pendingSpecRebuild = false
        else
            pendingSpecRebuild = true
        end
        return true
    end
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("PLAYER_TALENT_UPDATE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("BAG_UPDATE_COOLDOWN")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterUnitEvent("UNIT_AURA", "player", "pet")
events:RegisterUnitEvent("UNIT_PET", "player")
events:RegisterUnitEvent("UNIT_HEALTH", "pet")
events:SetScript("OnEvent", function(_, event)
    -- Roster and aura events can arrive before PLAYER_LOGIN. Initialize the
    -- profile on the first event so those events cannot block HUD startup.
    if event == "PLAYER_LOGIN" or not profile then InitializeProfiles() end
    if not IsAddonEnabled() then return end
    if event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if not UpdateSpecProfile() then
            if not Rebuild() then pendingKnownRebuild = true end
        end
        return
    end
    if event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        if not Rebuild() then pendingKnownRebuild = true end
        return
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
        if pendingSpecRebuild or pendingKnownRebuild then
            if not Rebuild() then Build() end
        else
            Build()
        end
        -- Login can happen while native auras are still protected. Retry the
        -- guarded build when they become available instead of leaving an
        -- initialized addon with no HUD until another rebuild event occurs.
        if not container and (InCombatLockdown()
            or (C_Secrets and C_Secrets.ShouldAurasBeSecret
                and C_Secrets.ShouldAurasBeSecret())) then
            pendingKnownRebuild = true
        end
        UpdateVisualState()
        UpdateArmorGlow()
        UpdateWellFedGlow()
        UpdateConsumableGlows()
        UpdateGroupBuffs()
        UpdateRowVisibility()
        if event == "PLAYER_LOGIN" then
            local version = C_AddOns and C_AddOns.GetAddOnMetadata
                and C_AddOns.GetAddOnMetadata("Warlock_Hud", "Version") or "unknown"
            Report("v" .. version .. " loaded. Tracks Warlock spells, cooldowns, and buffs. Type /whub for settings.")
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        UpdateVisualState()
        UpdateArmorGlow()
        UpdateWellFedGlow()
        UpdateConsumableGlows()
        UpdateGroupBuffs()
        UpdateRowVisibility()
    elseif event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE_COOLDOWN" then
        UpdateStones()
        UpdateShardCount()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        UpdateShardCount()
        UpdateConsumableGlows()
    elseif event == "UNIT_INVENTORY_CHANGED" then
        UpdateConsumableGlows()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        UpdateSpellCooldowns()
    elseif event == "UNIT_AURA" then
        UpdateArmorGlow()
        LearnWellFed()
        LearnConsumables()
        LearnBuffs()
        if playerAuraContainer then playerAuraContainer:UpdateAllAuras() end
        if WarlockHudRowVisibility.containers.pet then
            WarlockHudRowVisibility.containers.pet:UpdateAllAuras()
        end
        if WarlockHudRowVisibility.containers.procs then
            WarlockHudRowVisibility.containers.procs:UpdateAllAuras()
        end
        UpdateWellFedGlow()
        UpdateConsumableGlows()
        UpdateGroupBuffs()
        UpdateRowVisibility()
    elseif event == "UNIT_PET" or event == "UNIT_HEALTH" then
        if event == "UNIT_PET" and WarlockHudRowVisibility.containers.pet then
            WarlockHudRowVisibility.containers.pet:UpdateAllAuras()
        end
        UpdateGroupBuffs()
        UpdateRowVisibility()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA" then
        if event == "PLAYER_ENTERING_WORLD" then UpdateSpecProfile() end
        UpdateGroupBuffs()
    elseif event == "PLAYER_TARGET_CHANGED" and container then
        -- Target swaps are not aura changes on the previous target.
        container:UpdateAllAuras()
        WarlockHudRowVisibility.RefreshConflagrate()
        if WarlockHudRowVisibility.containers.utility then
            WarlockHudRowVisibility.containers.utility:UpdateAllAuras()
        end
        UpdateVisualState()
        UpdateRange()
    end
end)

local rangeElapsed = 0
events:SetScript("OnUpdate", function(_, elapsed)
    if not IsAddonEnabled() then return end
    rangeElapsed = rangeElapsed + elapsed
    if rangeElapsed >= 0.2 then
        rangeElapsed = 0
        if pendingSpecRebuild or pendingKnownRebuild or pendingDemonRebuild then Rebuild() end
        if container then
            if soulstoneLabel then
                local status = WarlockHudSoulstoneText and WarlockHudSoulstoneText()
                soulstoneLabel:SetText(status or "")
            end
            WarlockHudRowVisibility.RefreshConflagrate()
            UpdateVisualState()
            UpdateRange()
            UpdateStones()
            UpdateSpellCooldowns()
            if rowFrames.editMover then
                local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
                if inEditMode then
                    rowFrames.editMover:Show()
                    rowFrames.cooldownMover:Show()
                    rowFrames.buffMover:Show()
                    consumeState.mover:Show()
                    rowFrames.procMover:Show()
                    if shardState.mover then shardState.mover:Show() end
                else
                    rowFrames.editMover:Hide()
                    rowFrames.cooldownMover:Hide()
                    rowFrames.buffMover:Hide()
                    consumeState.mover:Hide()
                    rowFrames.procMover:Hide()
                    if shardState.mover then shardState.mover:Hide() end
                end
            end
            UpdateRowVisibility()
        end
    end
end)

SLASH_WARLOCKHUD1 = "/whud"
SLASH_WARLOCKHUD2 = "/whub"
local function DebugState()
    local db = WarlockHudDB
    local output = WarlockHudTraceHUD or Report
    if WarlockHudMultiTarget and WarlockHudMultiTarget.Debug then
        WarlockHudMultiTarget.Debug()
    end
    local auraSecret = C_Secrets and C_Secrets.ShouldAurasBeSecret
        and C_Secrets.ShouldAurasBeSecret()
    output("HUD: " .. (container and "built" or "not built")
        .. "; enabled: " .. tostring(IsAddonEnabled())
        .. "; pending rebuild: " .. tostring(pendingKnownRebuild
            or pendingSpecRebuild or pendingDemonRebuild)
        .. "; combat: " .. tostring(InCombatLockdown())
        .. "; secret auras: " .. tostring(auraSecret))
    output("Profile: " .. tostring(db and db.activeProfile or "unavailable")
        .. "; spec switching: " .. (db and db.autoSpecProfiles and "on" or "off"))
    if profile then
        for _, row in ipairs({
            { "Target DoTs", profile.mainOrder },
            { "Utility", profile.cooldownOrder },
            { "Buffs", profile.buffOrder },
            { "Consumes", profile.consumeOrder },
            { "Procs", profile.procOrder },
        }) do
            local enabled = {}
            for _, key in ipairs(row[2]) do
                if Enabled(key) then enabled[#enabled + 1] = key end
            end
            output(row[1] .. ": " .. (#enabled > 0 and table.concat(enabled, ", ") or "none"))
        end
    end
    output("Trackers: target " .. (container and "ready" or "not initialized")
        .. ", player " .. (playerAuraContainer and "ready" or "not initialized")
        .. "; rebuild pending: " .. ((pendingSpecRebuild or pendingKnownRebuild) and "yes" or "no"))
    if InCombatLockdown() then
        output("Target/range: unavailable during combat.")
    else
        local ok, attackable = pcall(function()
            return UnitExists("target") and not UnitIsDeadOrGhost("target")
                and UnitCanAttack("player", "target")
        end)
        if not ok or (issecretvalue and issecretvalue(attackable)) then
            output("Target/range: unavailable.")
        elseif not attackable then
            output("Target/range: no attackable target.")
        else
            local spell = icons[1] and icons[1].rangeSpell
            local rangeOK, inRange
            if spell and C_Spell and C_Spell.IsSpellInRange then
                rangeOK, inRange = pcall(C_Spell.IsSpellInRange, spell.name, "target")
            end
            local range = "unavailable"
            if rangeOK and (not issecretvalue or not issecretvalue(inRange)) then
                if inRange == true then range = "in range"
                elseif inRange == false then range = "out of range" end
            end
            output("Target: attackable; " .. (spell and spell.name or "spell")
                .. " range: " .. range)
        end
    end
    for _, spell in ipairs(SPELLS) do
        if Enabled(spell.name) then
            output("Tracked " .. spell.name .. " IDs: " .. table.concat(spell.ids, ", "))
        end
    end
end
local function TracePetBuffs()
    if InCombatLockdown() or (C_Secrets and C_Secrets.ShouldAurasBeSecret
        and C_Secrets.ShouldAurasBeSecret()) then
        Report("Pet buff scan is unavailable during combat or secret aura states.")
        return
    end
    if not C_UnitAuras or not C_UnitAuras.GetBuffDataByIndex then
        Report("Pet buff scan API is unavailable on this client.")
        return
    end
    local ok, exists = pcall(UnitExists, "pet")
    if not ok or (issecretvalue and issecretvalue(exists)) then
        Report("Pet presence is unreadable.")
        return
    end
    if not exists then
        Report("No pet to scan.")
        return
    end
    local count = 0
    for index = 1, 40 do
        local readOK, aura = pcall(C_UnitAuras.GetBuffDataByIndex, "pet", index)
        if not readOK or (issecretvalue and issecretvalue(aura)) then
            Report("Pet buff " .. index .. " is unreadable; scan stopped.")
            return
        end
        if not aura then break end
        local name, spellID = aura.name, aura.spellId
        if (issecretvalue and (issecretvalue(name) or issecretvalue(spellID))) then
            Report("Pet buff " .. index .. " has restricted fields; scan stopped.")
            return
        end
        Report("Pet buff " .. index .. ": " .. tostring(name)
            .. " (ID " .. tostring(spellID) .. ")")
        count = count + 1
    end
    if count == 0 then Report("Pet has no visible buffs.") end
end
SlashCmdList.WARLOCKHUD = function(message)
    if message == "petbuffs" then
        TracePetBuffs()
        return
    end
    if message == "announceassignments" and WarlockHudAnnounceAssignments then
        WarlockHudAnnounceAssignments()
        return
    end
    if message == "assignments" and WarlockHudOpenAssignments then
        WarlockHudOpenAssignments()
        return
    end
    if message == "assignprobe" and WarlockHudAssignmentProbe then
        WarlockHudAssignmentProbe("show")
        return
    end
    if message == "assignprobe send" and WarlockHudAssignmentProbe then
        WarlockHudAssignmentProbe("send")
        return
    end
    if message == "assignprobe off" and WarlockHudAssignmentProbe then
        WarlockHudAssignmentProbe("off")
        return
    end
    if message == "summonqueue demo" and WarlockHudOpenSummonQueueDemo then
        WarlockHudOpenSummonQueueDemo()
        return
    end
    if message == "summonqueue" and WarlockHudOpenSummonQueue then
        WarlockHudOpenSummonQueue()
        return
    end
    if message == "summonqueue report" and WarlockHudSummonQueueReport then
        WarlockHudSummonQueueReport()
        return
    end
    if message == "stones" and WarlockHudShowStones then
        WarlockHudShowStones()
        return
    end
    if message == "trace" and WarlockHudOpenDebugTrace then
        WarlockHudOpenDebugTrace()
        return
    end
    if message == "tradedebug" and WarlockHudToggleTradeDebug then
        WarlockHudToggleTradeDebug()
        return
    end
    if message == "soulstonedebug" and WarlockHudToggleSoulstoneDebug then
        WarlockHudToggleSoulstoneDebug()
        return
    end
    if message == "debug" then
        if WarlockHudOpenDebugTrace then WarlockHudOpenDebugTrace() end
        DebugState()
        return
    end
    if WarlockHudOpenSettings and WarlockHudOpenSettings() then
        return
    end
    Build()
    Report("Settings are unavailable; target tracker: "
        .. (container and "ready" or "not initialized"))
end

WarlockHudAPI = {
    Stones = STONES,
    IsAddonEnabled = IsAddonEnabled,
    SetAddonEnabled = SetAddonEnabled,
    InitializeProfiles = InitializeProfiles,
    ActiveTalentGroup = ActiveTalentGroup,
    MainKeys = MAIN_KEYS,
    CooldownKeys = COOLDOWN_KEYS,
    BuffKeys = BUFF_KEYS,
    ConsumeKeys = consumeState.keys,
    Buffs = BUFFS,
    ProcKeys = PROC_KEYS,
    Procs = PROCS,
    Spells = SPELLS,
    DotDefaultSlots = DOT_DEFAULT_SLOTS,
    GetDotDefaultSpell = GetDotDefaultSpell,
    DefaultSummonKeywords = DEFAULT_SUMMON_KEYWORDS,
    NormalizeSummonKeywords = NormalizeSummonKeywords,
    Racials = RACIALS,
    GetProfile = function() return profile end,
    GetDemoAnchors = function()
        if not container or not hudRoot then return nil end
        return {
            root = hudRoot,
            main = rowFrames.hudAnchor,
            utility = rowFrames.cooldownAnchor,
            buffs = rowFrames.buffAnchor,
            consumes = consumeState.anchor,
            procs = rowFrames.procAnchor,
            shards = shardState.anchor,
        }
    end,
    GetDB = function() return WarlockHudDB end,
    NormalizeProfile = NormalizeProfile,
    GetSoulShardCount = GetSoulShardCount,
    RefreshShardWarning = UpdateShardCount,
    RefreshConsumableGlows = function()
        UpdateWellFedGlow()
        UpdateConsumableGlows()
    end,
    RefreshRowVisibility = UpdateRowVisibility,
    Rebuild = Rebuild,
}
