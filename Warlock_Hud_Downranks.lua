-- Warn once per changed action-bar spell when a higher learned rank exists.
local frame = CreateFrame("Frame")
local warned = {}
local queued = false
local highestRanks = {}

local function Rank(text)
    return type(text) == "string"
        and tonumber(text:match("[Rr]ank%s*(%d+)")) or nil
end

local function SpellDetails(spellID)
    if not spellID or not C_Spell then return nil end
    local name = C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    local subtext = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID)
    return name, Rank(subtext)
end

local function HighestKnownRanks()
    local highest = {}
    if not C_SpellBook or not C_SpellBook.GetNumSpellBookSkillLines
        or not C_SpellBook.GetSpellBookSkillLineInfo
        or not C_SpellBook.GetSpellBookItemInfo then return highest end
    local playerBank = Enum and Enum.SpellBookSpellBank
        and Enum.SpellBookSpellBank.Player
    local spellType = Enum and Enum.SpellBookItemType
        and Enum.SpellBookItemType.Spell
    if playerBank == nil or spellType == nil then return highest end
    for tab = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(tab)
        if line and line.itemIndexOffset and line.numSpellBookItems then
            for slot = line.itemIndexOffset + 1,
                line.itemIndexOffset + line.numSpellBookItems do
                local info = C_SpellBook.GetSpellBookItemInfo(slot, playerBank)
                if info and info.itemType == spellType then
                    local name = info.name
                    local rank = Rank(info.subName)
                    if not rank then
                        local resolvedName, resolvedRank = SpellDetails(
                            info.spellID or info.actionID)
                        name = name or resolvedName
                        rank = resolvedRank
                    end
                    if name and rank and rank > (highest[name] or 0) then
                        highest[name] = rank
                    end
                end
            end
        end
    end
    return highest
end

local function CheckActionBars()
    queued = false
    if not WarlockHudAPI or not WarlockHudAPI.IsAddonEnabled()
        or not GetActionInfo then return end
    local highest = HighestKnownRanks()
    highestRanks = highest
    local found = {}
    for slot = 1, 180 do
        local kind, spellID = GetActionInfo(slot)
        if kind == "spell" and type(spellID) == "number" then
            local name, rank = SpellDetails(spellID)
            local best = name and highest[name]
            if rank and best and rank < best then
                local key = name .. ":" .. rank .. ":" .. best
                local entry = found[key]
                if not entry then
                    entry = { name = name, rank = rank, best = best, slots = {} }
                    found[key] = entry
                end
                entry.slots[#entry.slots + 1] = slot
            end
        end
    end
    local current = {}
    for key, entry in pairs(found) do
        current[key] = true
        if not warned[key] then
            print("|cffffaa33Warlock HUD:|r " .. entry.name .. " Rank "
                .. entry.rank .. " is on your action bar (slot "
                .. table.concat(entry.slots, ", ") .. "); Rank " .. entry.best
                .. " is known. Replace the button if you want the newer rank.")
        end
    end
    warned = current
end

local function CheckCast(unit, _, spellID)
    if unit ~= "player" or not WarlockHudAPI
        or not WarlockHudAPI.IsAddonEnabled() then return end
    if issecretvalue and issecretvalue(spellID) then return end
    if type(spellID) ~= "number" then return end
    local name, rank = SpellDetails(spellID)
    if (issecretvalue and (issecretvalue(name) or issecretvalue(rank)))
        or not name or not rank then return end
    local best = highestRanks[name]
    if not best or rank >= best then return end
    print("|cffffaa33Warlock HUD:|r You cast " .. name .. " Rank "
        .. rank .. ", but Rank " .. best .. " is known.")
end

local function QueueCheck()
    if queued then return end
    queued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, CheckActionBars)
    else
        CheckActionBars()
    end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("SPELL_TEXT_UPDATE")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("TRAINER_CLOSED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        CheckCast(...)
    else
        QueueCheck()
    end
end)
