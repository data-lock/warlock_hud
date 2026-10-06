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
local PROC_ICON_SIZE = 32
local ICON_SPACING = 4
local BORDER_SIZE = 2
local ICON_CROP = (1 - 1 / 1.3) / 2
local IN_RANGE_COLOR = CreateColor(1, 1, 1, 1)
local OUT_OF_RANGE_COLOR = CreateColor(1, 0.2, 0.2, 1)

local container
local hudRoot
local hudAnchor
local editMover
local cooldownAnchor
local soulstoneLabel
local cooldownMover
local buffAnchor
local buffMover
local procAnchor
local procMover
local armorGlow
local wellFedGlow
local shardState = {}
local playerAuraContainer
local wellFedSlotCreated = false
local icons = {}
local itemIcons = {}
local racialIcons = {}
local groupBuffIcons = {}
local lastGroupCasterClasses = {}
local pendingSpecRebuild = false
local pendingKnownRebuild = false
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
local COOLDOWN_KEYS = { "healthstone", "soulstone", "fear", "racial1", "racial2" }
local BUFF_KEYS = { "fort", "motw", "int", "spirit", "kings", "salv", "armor", "wellfed", "thorns", "breath" }
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
}
local profile
local wellFedIDs = { [19705] = true }
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
                if playerAuraContainer and buffSlotCreated[buff.key] then
                    playerAuraContainer:SetAuraSlotCandidateFilters(buff.key,
                        { includeSpellIDs = buffIDs[buff.key] })
                    playerAuraContainer:UpdateAllAuras()
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
    if playerAuraContainer and wellFedSlotCreated then
        playerAuraContainer:SetAuraSlotCandidateFilters("Well Fed", { includeSpellIDs = wellFedIDs })
        playerAuraContainer:UpdateAllAuras()
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
    if p.notificationChannel ~= "GROUP" then p.notificationChannel = "SELF" end
    if type(p.enabled) ~= "table" then p.enabled = {} end
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
    profile = NormalizeProfile(WarlockHudDB.profiles[WarlockHudDB.activeProfile])
    WarlockHudDB.profiles[WarlockHudDB.activeProfile] = profile
    ICON_SIZE = profile.mainSize
    COOLDOWN_ICON_SIZE = profile.cooldownSize
    BUFF_ICON_SIZE = profile.buffSize
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
end

local function Enabled(key)
    return profile and profile.enabled[key] ~= false
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
    local border = CreateFrame("Frame", nil, hudRoot)
    border:SetSize(iconSize + 2 * BORDER_SIZE, iconSize + 2 * BORDER_SIZE)
    border:SetPoint("CENTER", anchor, "CENTER", x, 0)
    border:SetFrameStrata("HIGH")
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
    local glow = CreateFrame("Frame", nil, hudRoot)
    -- The border texture has transparent padding. Give it room outside the
    -- icon so the yellow pulse remains visible after row-three icons move.
    glow:SetSize(iconSize + 16, iconSize + 16)
    glow:SetPoint("CENTER", anchor, "CENTER", x, 0)
    glow:SetFrameStrata("MEDIUM")
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

local function UpdateShardCount()
    if not shardState.countText then return end
    local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(SOUL_SHARD_ID) or 0
    if issecretvalue and issecretvalue(count) then return end
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
    for _, entry in ipairs(icons) do
        entry.icon:SetAlpha(hasAttackableTarget and 1 or 0.5)
        entry.border:SetAlpha(hasAttackableTarget and 1 or 0.5)
    end
    for _, entry in ipairs(itemIcons) do
        entry.icon:SetAlpha(1)
        entry.border:SetAlpha(1)
    end
end

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
        entry.icon:SetDesaturated(not owned)
        local start, duration = C_Item.GetItemCooldown(chosen)
        if start and duration then
            -- The widget accepts cooldown values without inspecting them in Lua.
            pcall(entry.cooldown.SetCooldown, entry.cooldown, start, duration)
        end
    end
end

local function UpdateRacials()
    if not C_Spell or not C_Spell.GetSpellCooldownDuration then
        return
    end
    for _, entry in ipairs(racialIcons) do
        local duration = C_Spell.GetSpellCooldownDuration(entry.spellID, true)
        if duration then
            pcall(entry.cooldown.SetCooldownFromDurationObject, entry.cooldown, duration)
        end
    end
end

local function UpdateArmorGlow()
    if armorGlow then armorGlow:Show() end
end

local function UpdateWellFedGlow()
    if wellFedGlow then wellFedGlow:Show() end
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
    local classes = GroupCasterClasses()
    for _, entry in ipairs(groupBuffIcons) do
        if not entry.buff.activeOnly then
            local hasBuff = ReadGroupBuff(entry.buff)
            if hasBuff ~= nil then entry.hasBuff = hasBuff end
            local hasCaster = classes[entry.buff.casterClass] and true or false
            entry.hasCaster = hasCaster
            entry.icon:SetShown(hasCaster and entry.hasBuff ~= true)
            entry.border:SetShown(entry.hasBuff == true or hasCaster)
            entry.glow:SetShown(hasCaster)
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
                local shown = key == "armor" or key == "wellfed"
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
                    holder:SetPoint("CENTER", buffAnchor, "LEFT",
                        visible * (BUFF_ICON_SIZE + ICON_SPACING) + BUFF_ICON_SIZE / 2, 0)
                    visible = visible + 1
                end
            end
        end
    end
    if breathHolder then
        breathHolder:ClearAllPoints()
        breathHolder:SetPoint("CENTER", buffAnchor, "LEFT",
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
        local inRange = C_Spell.IsSpellInRange(entry.spell.name, "target")
        SetRangeColor(entry.icon, inRange)
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

    local auraContainer = CreateFrame("AuraContainer", nil, hudRoot, "CustomAuraContainerTemplate")
    if not auraContainer or type(auraContainer.AddAuraSlot) ~= "function" then
        Report("CustomAuraContainerTemplate is unavailable on this client.")
        return
    end
    local playerAuras = CreateFrame("AuraContainer", nil, hudRoot, "CustomAuraContainerTemplate")
    if not playerAuras or type(playerAuras.AddAuraSlot) ~= "function" then
        Report("Could not create the player buff container.")
        return
    end
    -- Active buff buttons cover the pulsing reminder underneath them.
    playerAuras:SetFrameStrata("HIGH")
    LearnWellFed()
    LearnBuffs()

    local mainOrder = VisibleOrder(profile.mainOrder)
    local cooldownOrder = VisibleOrder(profile.cooldownOrder)
    local buffOrder = VisibleOrder(profile.buffOrder)
    local procOrder = VisibleOrder(profile.procOrder)
    local rowWidth = math.max(1, #mainOrder * ICON_SIZE + math.max(0, #mainOrder - 1) * ICON_SPACING)
    hudAnchor = CreateFrame("Frame", nil, hudRoot)
    hudAnchor:SetSize(rowWidth, ICON_SIZE)
    hudAnchor:SetMovable(true)
    hudAnchor:SetClampedToScreen(true)
    local saved = profile
    if type(saved) == "table" and type(saved.x) == "number" and type(saved.y) == "number" then
        hudAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            saved.x * UIParent:GetWidth(), saved.y * UIParent:GetHeight())
    else
        hudAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    end

    editMover = CreateFrame("Button", nil, hudAnchor)
    editMover:SetAllPoints(hudAnchor)
    editMover:SetFrameStrata("DIALOG")
    editMover:EnableMouse(true)
    editMover:RegisterForDrag("LeftButton")
    local moverShade = editMover:CreateTexture(nil, "BACKGROUND")
    moverShade:SetAllPoints(editMover)
    moverShade:SetColorTexture(0, 0.65, 0.85, 0.25)
    local moverLabel = editMover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    moverLabel:SetPoint("BOTTOM", editMover, "TOP", 0, 5)
    moverLabel:SetText("Warlock HUD")
    editMover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then
            hudAnchor:StartMoving()
        end
    end)
    editMover:SetScript("OnDragStop", function()
        hudAnchor:StopMovingOrSizing()
        local centerX, centerY = hudAnchor:GetCenter()
        if centerX and centerY then
            local grid = EditModeManagerFrame and EditModeManagerFrame.Grid
            if grid and grid:IsShown() and type(grid.gridSpacing) == "number"
                and grid.gridSpacing > 0 then
                local gridX, gridY = grid:GetCenter()
                if gridX and gridY then
                    local spacing = grid.gridSpacing
                    centerX = gridX + math.floor((centerX - gridX) / spacing + 0.5) * spacing
                    centerY = gridY + math.floor((centerY - gridY) / spacing + 0.5) * spacing
                    hudAnchor:ClearAllPoints()
                    hudAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
                end
            end
            profile.x = centerX / UIParent:GetWidth()
            profile.y = centerY / UIParent:GetHeight()
        end
    end)
    editMover:Hide()

    local cooldownWidth = math.max(1, #cooldownOrder * COOLDOWN_ICON_SIZE
        + math.max(0, #cooldownOrder - 1) * ICON_SPACING)
    cooldownAnchor = CreateFrame("Frame", nil, hudRoot)
    cooldownAnchor:SetSize(cooldownWidth, COOLDOWN_ICON_SIZE)
    cooldownAnchor:SetMovable(true)
    cooldownAnchor:SetClampedToScreen(true)
    if type(saved) == "table" and type(saved.cooldownX) == "number"
        and type(saved.cooldownY) == "number" then
        cooldownAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            saved.cooldownX * UIParent:GetWidth(), saved.cooldownY * UIParent:GetHeight())
    else
        cooldownAnchor:SetPoint("CENTER", hudAnchor, "CENTER", 0, -60)
    end
    cooldownMover = CreateFrame("Button", nil, cooldownAnchor)
    cooldownMover:SetAllPoints(cooldownAnchor)
    cooldownMover:SetFrameStrata("DIALOG")
    cooldownMover:EnableMouse(true)
    cooldownMover:RegisterForDrag("LeftButton")
    local cooldownShade = cooldownMover:CreateTexture(nil, "BACKGROUND")
    cooldownShade:SetAllPoints(cooldownMover)
    cooldownShade:SetColorTexture(0, 0.65, 0.85, 0.25)
    local cooldownLabel = cooldownMover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cooldownLabel:SetPoint("BOTTOM", cooldownMover, "TOP", 0, 5)
    cooldownLabel:SetText("Warlock HUD Cooldowns")
    cooldownMover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then
            cooldownAnchor:StartMoving()
        end
    end)
    cooldownMover:SetScript("OnDragStop", function()
        cooldownAnchor:StopMovingOrSizing()
        local centerX, centerY = cooldownAnchor:GetCenter()
        if centerX and centerY then
            local grid = EditModeManagerFrame and EditModeManagerFrame.Grid
            if grid and grid:IsShown() and type(grid.gridSpacing) == "number"
                and grid.gridSpacing > 0 then
                local gridX, gridY = grid:GetCenter()
                if gridX and gridY then
                    local spacing = grid.gridSpacing
                    centerX = gridX + math.floor((centerX - gridX) / spacing + 0.5) * spacing
                    centerY = gridY + math.floor((centerY - gridY) / spacing + 0.5) * spacing
                    cooldownAnchor:ClearAllPoints()
                    cooldownAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
                end
            end
            profile.cooldownX = centerX / UIParent:GetWidth()
            profile.cooldownY = centerY / UIParent:GetHeight()
        end
    end)
    cooldownMover:Hide()

    local buffWidth = math.max(1, #buffOrder * BUFF_ICON_SIZE
        + math.max(0, #buffOrder - 1) * ICON_SPACING)
    buffAnchor = CreateFrame("Frame", nil, hudRoot)
    buffAnchor:SetSize(buffWidth, BUFF_ICON_SIZE)
    buffAnchor:SetMovable(true)
    buffAnchor:SetClampedToScreen(true)
    if type(saved.buffX) == "number" and type(saved.buffY) == "number" then
        if not saved.buffLeftAligned then
            saved.buffX = saved.buffX - buffWidth / (2 * UIParent:GetWidth())
            saved.buffLeftAligned = true
        end
        buffAnchor:SetPoint("LEFT", UIParent, "BOTTOMLEFT",
            saved.buffX * UIParent:GetWidth(), saved.buffY * UIParent:GetHeight())
    elseif PlayerFrame then
        local fullWidth = #BUFF_KEYS * BUFF_ICON_SIZE
            + (#BUFF_KEYS - 1) * ICON_SPACING
        buffAnchor:SetPoint("LEFT", PlayerFrame, "TOP",
            -fullWidth / 2, 12 + BUFF_ICON_SIZE / 2)
    else
        buffAnchor:SetPoint("LEFT", UIParent, "BOTTOMLEFT",
            180, 210 + BUFF_ICON_SIZE / 2)
    end
    buffMover = CreateFrame("Button", nil, buffAnchor)
    buffMover:SetAllPoints(buffAnchor)
    buffMover:SetFrameStrata("DIALOG")
    buffMover:EnableMouse(true)
    buffMover:RegisterForDrag("LeftButton")
    local buffShade = buffMover:CreateTexture(nil, "BACKGROUND")
    buffShade:SetAllPoints(buffMover)
    buffShade:SetColorTexture(0, 0.65, 0.85, 0.25)
    local buffLabel = buffMover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    buffLabel:SetPoint("BOTTOM", buffMover, "TOP", 0, 5)
    buffLabel:SetText("Warlock HUD Buffs")
    buffMover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then buffAnchor:StartMoving() end
    end)
    buffMover:SetScript("OnDragStop", function()
        buffAnchor:StopMovingOrSizing()
        local leftX = buffAnchor:GetLeft()
        local _, centerY = buffAnchor:GetCenter()
        if leftX and centerY then
            local grid = EditModeManagerFrame and EditModeManagerFrame.Grid
            if grid and grid:IsShown() and type(grid.gridSpacing) == "number"
                and grid.gridSpacing > 0 then
                local gridX, gridY = grid:GetCenter()
                if gridX and gridY then
                    local spacing = grid.gridSpacing
                    leftX = gridX + math.floor((leftX - gridX) / spacing + 0.5) * spacing
                    centerY = gridY + math.floor((centerY - gridY) / spacing + 0.5) * spacing
                    buffAnchor:ClearAllPoints()
                    buffAnchor:SetPoint("LEFT", UIParent, "BOTTOMLEFT", leftX, centerY)
                end
            end
            profile.buffX = leftX / UIParent:GetWidth()
            profile.buffY = centerY / UIParent:GetHeight()
            profile.buffLeftAligned = true
        end
    end)
    buffMover:Hide()

    local procWidth = math.max(1, #procOrder * PROC_ICON_SIZE
        + math.max(0, #procOrder - 1) * ICON_SPACING)
    procAnchor = CreateFrame("Frame", nil, hudRoot)
    procAnchor:SetSize(procWidth, PROC_ICON_SIZE)
    procAnchor:SetMovable(true)
    procAnchor:SetClampedToScreen(true)
    if type(saved.procX) == "number" and type(saved.procY) == "number" then
        procAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            saved.procX * UIParent:GetWidth(), saved.procY * UIParent:GetHeight())
    else
        procAnchor:SetPoint("BOTTOM", hudAnchor, "TOP", 0, 12)
    end
    procMover = CreateFrame("Button", nil, procAnchor)
    procMover:SetAllPoints(procAnchor)
    procMover:SetFrameStrata("DIALOG")
    procMover:EnableMouse(true)
    procMover:RegisterForDrag("LeftButton")
    local procShade = procMover:CreateTexture(nil, "BACKGROUND")
    procShade:SetAllPoints(procMover)
    procShade:SetColorTexture(0, 0.65, 0.85, 0.25)
    local procLabel = procMover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    procLabel:SetPoint("BOTTOM", procMover, "TOP", 0, 5)
    procLabel:SetText("Warlock HUD Procs")
    procMover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then procAnchor:StartMoving() end
    end)
    procMover:SetScript("OnDragStop", function()
        procAnchor:StopMovingOrSizing()
        local centerX, centerY = procAnchor:GetCenter()
        if centerX and centerY then
            local grid = EditModeManagerFrame and EditModeManagerFrame.Grid
            if grid and grid:IsShown() and type(grid.gridSpacing) == "number"
                and grid.gridSpacing > 0 then
                local gridX, gridY = grid:GetCenter()
                if gridX and gridY then
                    local spacing = grid.gridSpacing
                    centerX = gridX + math.floor((centerX - gridX) / spacing + 0.5) * spacing
                    centerY = gridY + math.floor((centerY - gridY) / spacing + 0.5) * spacing
                    procAnchor:ClearAllPoints()
                    procAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
                end
            end
            profile.procX = centerX / UIParent:GetWidth()
            profile.procY = centerY / UIParent:GetHeight()
        end
    end)
    procMover:Hide()

    for _, stone in ipairs(STONES) do
        local x = CooldownX(stone.name == "Healthstone" and "healthstone" or "soulstone")
        if x then
        local icon = hudRoot:CreateTexture(nil, "ARTWORK")
        icon:SetSize(COOLDOWN_ICON_SIZE, COOLDOWN_ICON_SIZE)
        icon:SetPoint("CENTER", cooldownAnchor, "CENTER", x, 0)
        icon:SetTexture(C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(stone.defaultID))
        icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        if stone.name == "Soulstone" then
            soulstoneLabel = cooldownAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            soulstoneLabel:SetPoint("TOP", cooldownAnchor, "BOTTOM", 0, -5)
            soulstoneLabel:SetWidth(220)
            soulstoneLabel:SetJustifyH("CENTER")
        end
        local cooldown = CreateFrame("Cooldown", nil, hudRoot, "CooldownFrameTemplate")
        cooldown:SetAllPoints(icon)
        cooldown:SetDrawBling(false)
        cooldown:SetDrawEdge(false)
        cooldown:SetHideCountdownNumbers(true)
        itemIcons[#itemIcons + 1] = {
            stone = stone, icon = icon, border = MakeBorder(cooldownAnchor, x, COOLDOWN_ICON_SIZE), cooldown = cooldown,
        }
        end
    end

    local _, _, raceID = UnitRace("player")
    for index, racial in ipairs(RACIALS[raceID] or {}) do
        local x = CooldownX("racial" .. index)
        if x then
        local icon = hudRoot:CreateTexture(nil, "ARTWORK")
        icon:SetSize(COOLDOWN_ICON_SIZE, COOLDOWN_ICON_SIZE)
        icon:SetPoint("CENTER", cooldownAnchor, "CENTER", x, 0)
        icon:SetTexture(C_Spell.GetSpellTexture(racial[2]))
        icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        local cooldown = CreateFrame("Cooldown", nil, hudRoot, "CooldownFrameTemplate")
        cooldown:SetAllPoints(icon)
        cooldown:SetDrawBling(false)
        cooldown:SetDrawEdge(false)
        cooldown:SetHideCountdownNumbers(true)
        racialIcons[#racialIcons + 1] = {
            spellID = racial[2], cooldown = cooldown,
            border = MakeBorder(cooldownAnchor, x, COOLDOWN_ICON_SIZE),
        }
        end
    end

    if profile.enabled.soulshards ~= false then
        local shardSize = profile.shardSize
        local shardAnchor = CreateFrame("Frame", nil, hudRoot)
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
        local shardButton = CreateFrame("Button", nil, hudRoot)
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
    auraContainer:SetPoint("CENTER", hudAnchor, "CENTER")

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
            local anchor = spell.group == 2 and cooldownAnchor or hudAnchor
            local iconSize = spell.group == 2 and COOLDOWN_ICON_SIZE or ICON_SIZE
            if not baseCreated[groupKey] then
                local icon = hudRoot:CreateTexture(nil, "ARTWORK")
                icon:SetSize(iconSize, iconSize)
                icon:SetPoint("CENTER", anchor, "CENTER", x, 0)
                icon:SetTexture(C_Spell.GetSpellTexture(currentSpellID or spell.ids[1]))
                icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
                if spell.group ~= 2 then
                    icon:SetDesaturated(profile.colorActiveDoTs ~= false)
                end
                icons[#icons + 1] = { spell = spell, icon = icon, border = MakeBorder(anchor, x, iconSize) }
                baseCreated[groupKey] = true
            end

            auraContainer:AddAuraSlot(spell.name, "HARMFUL|PLAYER", {
                candidateFilters = {
                    includeSpellIDs = includeSpellIDs,
                },
                initializeFrame = function(button)
                    button:SetSize(iconSize, iconSize)
                    button:ClearAllPoints()
                    button:SetPoint("CENTER", anchor, "CENTER", x, 0)

                    local auraIcon = button:CreateTexture(nil, "ARTWORK")
                    auraIcon:SetAllPoints(button)
                    auraIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
                    if spell.group ~= 2 then
                        auraIcon:SetDesaturated(profile.colorActiveDoTs == false)
                    end
                    button:SetIcon(auraIcon)

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
        local holder = CreateFrame("Frame", nil, buffAnchor)
        holder:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
        holder:SetPoint("CENTER", buffAnchor, "CENTER",
            Position(buffOrder, key, BUFF_ICON_SIZE), 0)
        groupBuffIcons.holders = groupBuffIcons.holders or {}
        groupBuffIcons.holders[key] = holder
    end
    local armorX = Position(buffOrder, "armor", BUFF_ICON_SIZE)
    if armorX then
    local armorHolder = groupBuffIcons.holders.armor
    local armorIcon = hudRoot:CreateTexture(nil, "ARTWORK")
    armorIcon:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
    armorIcon:SetPoint("CENTER", armorHolder, "CENTER")
    armorIcon:SetTexture(C_Spell.GetSpellTexture(
        C_Spell.GetSpellIDForSpellIdentifier("Demon Armor")
        or C_Spell.GetSpellIDForSpellIdentifier("Demon Skin") or 706))
    armorIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
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
            auraIcon:SetDesaturated(true)
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

    local foodX = Position(buffOrder, "wellfed", BUFF_ICON_SIZE)
    if foodX then
        local foodHolder = groupBuffIcons.holders.wellfed
        wellFedSlotCreated = true
        local foodIcon = hudRoot:CreateTexture(nil, "ARTWORK")
        foodIcon:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
        foodIcon:SetPoint("CENTER", foodHolder, "CENTER")
        foodIcon:SetTexture(C_Spell.GetSpellTexture(19705) or "Interface\\Icons\\INV_Misc_Food_15")
        foodIcon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        foodIcon:SetDesaturated(false)
        local foodBorder = MakeBorder(foodHolder, 0, BUFF_ICON_SIZE)
        wellFedGlow = MakeReminderGlow(foodHolder, 0, foodBorder, BUFF_ICON_SIZE)
        wellFedGlow.pulseIcon = foodIcon
        playerAuras:AddAuraSlot("Well Fed", "HELPFUL", {
            candidateFilters = { includeSpellIDs = wellFedIDs },
            initializeFrame = function(button)
                button:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
                button:ClearAllPoints()
                button:SetPoint("CENTER", foodHolder, "CENTER")
                local auraIcon = button:CreateTexture(nil, "ARTWORK")
                auraIcon:SetAllPoints(button)
                auraIcon:SetDesaturated(true)
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
                icon = hudRoot:CreateTexture(nil, "ARTWORK")
                icon:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
                icon:SetPoint("CENTER", holder, "CENTER")
                icon:SetTexture(C_Spell.GetSpellTexture(buff.ids[1])
                    or "Interface\\Icons\\INV_Misc_QuestionMark")
                icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
                icon:SetDesaturated(false)
                icon:SetVertexColor(1, 0.3, 0.3)
                border = MakeBorder(holder, 0, BUFF_ICON_SIZE)
                glow = MakeReminderGlow(holder, 0, border, BUFF_ICON_SIZE, true)
                glow.pulseIcon = icon
            end
            groupBuffIcons[#groupBuffIcons + 1] = {
                buff = buff, icon = icon, border = border, glow = glow,
            }
            buffSlotCreated[buff.key] = true
            playerAuras:AddAuraSlot(buff.key, "HELPFUL", {
                candidateFilters = { includeSpellIDs = buffIDs[buff.key] },
                initializeFrame = function(button)
                    button:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
                    button:ClearAllPoints()
                    button:SetPoint("CENTER", holder, "CENTER")
                    local auraIcon = button:CreateTexture(nil, "ARTWORK")
                    auraIcon:SetAllPoints(button)
                    auraIcon:SetDesaturated(true)
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
            playerAuras:AddAuraSlot(proc.key, "HELPFUL", {
                candidateFilters = { includeSpellIDs = includeSpellIDs },
                initializeFrame = function(button)
                    button:SetSize(PROC_ICON_SIZE, PROC_ICON_SIZE)
                    button:ClearAllPoints()
                    button:SetPoint("CENTER", procAnchor, "CENTER", x, 0)
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

    playerAuras:SetSize(cooldownWidth, COOLDOWN_ICON_SIZE)
    playerAuras:SetPoint("CENTER", cooldownAnchor, "CENTER")

    auraContainer:SetUnit("target")
    auraContainer:Show()
    auraContainer:UpdateAllAuras()
    playerAuras:SetUnit("player")
    playerAuras:Show()
    playerAuras:UpdateAllAuras()
    playerAuraContainer = playerAuras
    container = auraContainer
    UpdateVisualState()
    UpdateRange()
    UpdateStones()
    UpdateRacials()
    UpdateArmorGlow()
    UpdateWellFedGlow()
    UpdateGroupBuffs()
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
    wellFedSlotCreated = false
    buffSlotCreated = {}
    armorGlow = nil
    wellFedGlow = nil
    shardState.button, shardState.countText = nil, nil
    shardState.anchor, shardState.mover = nil, nil
    shardState.icon, shardState.glow = nil, nil
    hudAnchor, editMover, cooldownAnchor, cooldownMover = nil, nil, nil, nil
    soulstoneLabel = nil
    buffAnchor, buffMover = nil, nil
    procAnchor, procMover = nil, nil
    icons, itemIcons, racialIcons, groupBuffIcons = {}, {}, {}, {}
    if not IsAddonEnabled() then
        pendingKnownRebuild = false
        pendingSpecRebuild = false
        if WarlockHudRefreshNameplates then WarlockHudRefreshNameplates() end
        return true
    end
    Build()
    if WarlockHudRefreshNameplates then WarlockHudRefreshNameplates() end
    if container then
        pendingKnownRebuild = false
        pendingSpecRebuild = false
        return true
    end
    return false
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
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then InitializeProfiles() end
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
        UpdateVisualState()
        UpdateArmorGlow()
        UpdateWellFedGlow()
        UpdateGroupBuffs()
        if event == "PLAYER_LOGIN" then
            local version = C_AddOns and C_AddOns.GetAddOnMetadata
                and C_AddOns.GetAddOnMetadata("Warlock_Hud", "Version") or "unknown"
            Report("v" .. version .. " loaded. Tracks Warlock spells, cooldowns, and buffs. Type /whub for settings.")
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        UpdateVisualState()
        UpdateArmorGlow()
        UpdateWellFedGlow()
        UpdateGroupBuffs()
    elseif event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE_COOLDOWN" then
        UpdateStones()
        UpdateShardCount()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        UpdateShardCount()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        UpdateRacials()
    elseif event == "UNIT_AURA" then
        UpdateArmorGlow()
        LearnWellFed()
        LearnBuffs()
        if playerAuraContainer then playerAuraContainer:UpdateAllAuras() end
        UpdateWellFedGlow()
        UpdateGroupBuffs()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED_NEW_AREA" then
        if event == "PLAYER_ENTERING_WORLD" then UpdateSpecProfile() end
        UpdateGroupBuffs()
    elseif event == "PLAYER_TARGET_CHANGED" and container then
        -- Target swaps are not aura changes on the previous target.
        container:UpdateAllAuras()
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
        if pendingSpecRebuild or pendingKnownRebuild then Rebuild() end
        if container then
            if soulstoneLabel then
                local status = WarlockHudSoulstoneText and WarlockHudSoulstoneText()
                soulstoneLabel:SetText(status or "")
            end
            UpdateVisualState()
            UpdateRange()
            UpdateStones()
            UpdateRacials()
            UpdateArmorGlow()
            UpdateWellFedGlow()
            if editMover then
                local inEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
                if inEditMode then
                    editMover:Show()
                    cooldownMover:Show()
                    buffMover:Show()
                    procMover:Show()
                    if shardState.mover then shardState.mover:Show() end
                else
                    editMover:Hide()
                    cooldownMover:Hide()
                    buffMover:Hide()
                    procMover:Hide()
                    if shardState.mover then shardState.mover:Hide() end
                end
            end
        end
    end
end)

SLASH_WARLOCKHUD1 = "/whud"
SLASH_WARLOCKHUD2 = "/whub"
local function DebugState()
    local db = WarlockHudDB
    Report("Profile: " .. tostring(db and db.activeProfile or "unavailable")
        .. "; spec switching: " .. (db and db.autoSpecProfiles and "on" or "off"))
    if profile then
        for _, row in ipairs({
            { "Target DoTs", profile.mainOrder },
            { "Utility", profile.cooldownOrder },
            { "Buffs", profile.buffOrder },
            { "Procs", profile.procOrder },
        }) do
            local enabled = {}
            for _, key in ipairs(row[2]) do
                if Enabled(key) then enabled[#enabled + 1] = key end
            end
            Report(row[1] .. ": " .. (#enabled > 0 and table.concat(enabled, ", ") or "none"))
        end
    end
    Report("Trackers: target " .. (container and "ready" or "not initialized")
        .. ", player " .. (playerAuraContainer and "ready" or "not initialized")
        .. "; rebuild pending: " .. ((pendingSpecRebuild or pendingKnownRebuild) and "yes" or "no"))
    if InCombatLockdown() then
        Report("Target/range: unavailable during combat.")
    else
        local ok, attackable = pcall(function()
            return UnitExists("target") and not UnitIsDeadOrGhost("target")
                and UnitCanAttack("player", "target")
        end)
        if not ok or (issecretvalue and issecretvalue(attackable)) then
            Report("Target/range: unavailable.")
        elseif not attackable then
            Report("Target/range: no attackable target.")
        else
            local spell = icons[1] and icons[1].spell
            local rangeOK, inRange
            if spell and C_Spell and C_Spell.IsSpellInRange then
                rangeOK, inRange = pcall(C_Spell.IsSpellInRange, spell.name, "target")
            end
            local range = "unavailable"
            if rangeOK and (not issecretvalue or not issecretvalue(inRange)) then
                if inRange == true then range = "in range"
                elseif inRange == false then range = "out of range" end
            end
            Report("Target: attackable; " .. (spell and spell.name or "spell")
                .. " range: " .. range)
        end
    end
    for _, spell in ipairs(SPELLS) do
        if Enabled(spell.name) then
            Report("Tracked " .. spell.name .. " IDs: " .. table.concat(spell.ids, ", "))
        end
    end
end
SlashCmdList.WARLOCKHUD = function(message)
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
    Buffs = BUFFS,
    ProcKeys = PROC_KEYS,
    Procs = PROCS,
    Spells = SPELLS,
    Racials = RACIALS,
    GetProfile = function() return profile end,
    GetDemoAnchors = function()
        if not container or not hudRoot then return nil end
        return {
            root = hudRoot,
            main = hudAnchor,
            utility = cooldownAnchor,
            buffs = buffAnchor,
            procs = procAnchor,
            shards = shardState.anchor,
        }
    end,
    GetDB = function() return WarlockHudDB end,
    NormalizeProfile = NormalizeProfile,
    RefreshShardWarning = UpdateShardCount,
    Rebuild = Rebuild,
}
