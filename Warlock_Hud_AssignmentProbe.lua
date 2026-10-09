-- Temporary, opt-in Forever API probe for the assignment feature.
-- It never changes assignments, auras, or saved variables.
local PREFIX = "WHUD_ASSIGN"
local frame = CreateFrame("Frame")
local active = false
local serial = 0
local castIDs = {}

local function Public(value)
    return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

local function Report(message)
    print("|cff9482c9Warlock HUD assignment probe:|r " .. message)
end

local function FullName(unit)
    local name, realm = UnitName(unit)
    if not Public(name) then return nil end
    if Public(realm) and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function Roster()
    local units = { "player" }
    local count = IsInRaid() and GetNumGroupMembers()
        or (IsInGroup() and GetNumSubgroupMembers() or 0)
    local prefix = IsInRaid() and "raid" or "party"
    for index = 1, count do units[#units + 1] = prefix .. index end
    local seen = {}
    for _, unit in ipairs(units) do
        local exists = UnitExists(unit)
        if Public(exists) and exists then
            local guid = UnitGUID(unit)
            if Public(guid) and not seen[guid] then
                seen[guid] = true
                local _, class = UnitClass(unit)
                if Public(class) and class == "WARLOCK" then
                    local leaderOK, leader, assistantOK, assistant
                    if UnitIsGroupLeader then
                        leaderOK, leader = pcall(UnitIsGroupLeader, unit)
                    end
                    if UnitIsGroupAssistant then
                        assistantOK, assistant = pcall(UnitIsGroupAssistant, unit)
                    end
                    Report(unit .. " " .. (FullName(unit) or "?")
                        .. " GUID=" .. tostring(guid)
                        .. " leader=" .. tostring(leaderOK and Public(leader) and leader or false)
                        .. " assistant=" .. tostring(assistantOK and Public(assistant) and assistant or false))
                end
            end
        end
    end
end

local function Spellbook()
    wipe(castIDs)
    for _, spell in ipairs(WarlockHudAPI.Spells) do
        if spell.slot == 2 or spell.slot == 3 then
            local knownIDs = {}
            for _, id in ipairs(spell.ids) do
                castIDs[id] = spell.name
                local checker = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell
                local ok, known
                if checker then ok, known = pcall(checker, id) end
                if ok and Public(known) and known then
                    knownIDs[#knownIDs + 1] = tostring(id)
                end
            end
            Report(spell.name .. " known IDs: "
                .. (#knownIDs > 0 and table.concat(knownIDs, ", ") or "none reported"))
        end
    end
    local resolver = C_Spell and C_Spell.GetSpellIDForSpellIdentifier
    local ok, shadowID
    if resolver then ok, shadowID = pcall(resolver, "Curse of Shadow") end
    if ok and Public(shadowID) and type(shadowID) == "number" then
        castIDs[shadowID] = "Curse of Shadow"
    end
    Report("Curse of Shadow resolved ID: "
        .. (ok and Public(shadowID) and tostring(shadowID) or "unavailable"))
end

local function Channel()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE
        and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

function WarlockHudAssignmentProbe(action)
    if action == "off" then
        active = false
        frame:UnregisterAllEvents()
        Report("off")
        return
    end
    local register = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix
    local ok, registered
    if register then ok, registered = pcall(register, PREFIX) end
    Report("prefix registration: " .. (ok and tostring(registered) or "unavailable"))
    if not ok or registered == false then return end
    active = true
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    Roster()
    Spellbook()
    if action == "send" then
        local channel = Channel()
        if not channel then
            Report("join a group before sending")
            return
        end
        local send = C_ChatInfo and C_ChatInfo.SendAddonMessage
        serial = serial + 1
        local payload = "PROBE:" .. serial
        local sent, result
        if send then sent, result = pcall(send, PREFIX, payload, channel) end
        Report("send " .. payload .. " via " .. channel .. ": "
            .. (sent and tostring(result) or "unavailable"))
    else
        Report("listening; use /whud assignprobe send in a group, or /whud assignprobe off")
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if not active then return end
    if event == "CHAT_MSG_ADDON" then
        local prefix, payload, channel, sender = ...
        if prefix == PREFIX and Public(payload) and Public(sender)
            and type(payload) == "string" and #payload <= 40 then
            Report("received " .. payload .. " from " .. sender .. " via " .. tostring(channel))
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        if unit == "player" and Public(spellID) and castIDs[spellID] then
            Report("cast " .. castIDs[spellID] .. " ID=" .. spellID
                .. " GUID=" .. (Public(castGUID) and tostring(castGUID) or "unavailable"))
        end
    end
end)
