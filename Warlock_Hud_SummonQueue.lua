-- Session-only summon requests and guarded nearby checks.
local api = WarlockHudAPI
local events = CreateFrame("Frame")
local ordered = {}
local byGUID = {}
local rangeElapsed = 0
local SUMMON_PENDING = Enum and Enum.SummonStatus and Enum.SummonStatus.Pending or 1
local function NotifyChanged()
    if WarlockHudSummonQueueChanged then WarlockHudSummonQueueChanged() end
end
local chatSources = {
    CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_WHISPER = "WHISPER",
}

local function Readable(value)
    return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

local function Trace(event, details)
    if WarlockHudTraceSummon then WarlockHudTraceSummon(event, details) end
end

local function GroupCategory()
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return LE_PARTY_CATEGORY_INSTANCE
    end
    if LE_PARTY_CATEGORY_HOME and IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return LE_PARTY_CATEGORY_HOME
    end
    if IsInGroup() then return LE_PARTY_CATEGORY_HOME or 1 end
end

local function GroupUnits()
    local units = {}
    local category = GroupCategory()
    if not category then return units end
    local raid = IsInRaid(category)
    local count = raid and GetNumGroupMembers(category)
        or GetNumSubgroupMembers(category)
    for index = 1, count do
        units[#units + 1] = (raid and "raid" or "party") .. index
    end
    return units
end

local function Roster()
    local roster = {}
    local playerGUID = UnitGUID("player")
    local category = GroupCategory()
    local expected = category and (IsInRaid(category)
        and GetNumGroupMembers(category) or GetNumSubgroupMembers(category)) or 0
    local readableCount = 0
    for _, unit in ipairs(GroupUnits()) do
        local guid = UnitGUID(unit)
        local name, realm = UnitName(unit)
        if Readable(guid) and Readable(name) then
            readableCount = readableCount + 1
        end
        if Readable(guid) and Readable(name) and Readable(playerGUID)
            and guid ~= playerGUID then
            local full = Readable(realm) and realm ~= ""
                and name .. "-" .. realm or name
            local display = GetUnitName and GetUnitName(unit, true)
            local _, class = UnitClass(unit)
            roster[#roster + 1] = {
                guid = guid, name = name, fullName = full, unit = unit,
                displayName = Readable(display) and display or nil,
                class = Readable(class) and class or nil,
            }
        end
    end
    return roster, readableCount == expected
        and (expected == 0 or Readable(playerGUID))
end

local function MatchSender(sender, senderGUID, roster)
    if Readable(senderGUID) and type(senderGUID) == "string"
        and senderGUID ~= "" then
        for _, member in ipairs(roster) do
            if member.guid == senderGUID then return member end
        end
        return nil
    end
    if not Readable(sender) or type(sender) ~= "string" then return nil end
    local normalized = sender:gsub("%s+", "-")
    local found
    for _, member in ipairs(roster) do
        if sender == member.fullName or sender == member.name
            or sender == member.displayName
            or normalized == member.fullName then
            if found then return nil end -- Never guess between same-name players.
            found = member
        end
    end
    return found
end

local function RefreshSummonStatus(entry)
    local unit = entry.unit
    local pending = false
    if type(unit) == "string" and C_IncomingSummon
        and C_IncomingSummon.IncomingSummonStatus then
        local guid = UnitGUID(unit)
        if Readable(guid) and guid == entry.guid then
            local ok, status = pcall(C_IncomingSummon.IncomingSummonStatus, unit)
            pending = ok and Readable(status) and status == SUMMON_PENDING
        end
    end
    if entry.summonPending ~= pending then
        entry.summonPending = pending
        Trace("QUEUE_SUMMON_STATUS", entry.fullName
            .. (pending and " pending" or " cleared"))
    end
end

local function RefreshSummonStatuses()
    for _, entry in ipairs(ordered) do RefreshSummonStatus(entry) end
end

local function RefreshRoster()
    local roster, complete = Roster()
    local current = {}
    local changed = false
    for _, member in ipairs(roster) do current[member.guid] = member end
    for index = #ordered, 1, -1 do
        local entry = ordered[index]
        local member = current[entry.guid]
        if not member and complete then
            table.remove(ordered, index)
            byGUID[entry.guid] = nil
            changed = true
            Trace("QUEUE_REMOVE", entry.fullName .. " reason=LEFT_GROUP")
        elseif member then
            entry.unit = member.unit
            entry.name = member.name
            entry.fullName = member.fullName
            entry.class = member.class
            RefreshSummonStatus(entry)
        end
    end
    if not complete then Trace("QUEUE_ROSTER", "incomplete; removals deferred") end
    if changed then NotifyChanged() end
    return roster
end

local function Nearby(entry)
    local unit = entry.unit
    if type(unit) ~= "string" then return false end
    local guid = UnitGUID(unit)
    if not Readable(guid) or guid ~= entry.guid then return false end
    if UnitDistanceSquared then
        local ok, squared, checked = pcall(UnitDistanceSquared, unit)
        if ok and Readable(squared) and type(squared) == "number"
            and Readable(checked) and checked == true
            and squared <= 40 * 40 then
            return true, "DISTANCE_40"
        end
    end
    if not InCombatLockdown() and CheckInteractDistance then
        local ok, inRange = pcall(CheckInteractDistance, unit, 4)
        if ok and Readable(inRange) and inRange == true then
            return true, "INTERACT_28"
        end
    end
    return false
end

local function RemoveNearby()
    local profile = api.GetProfile()
    if not api.IsAddonEnabled() or not profile
        or profile.summonQueueEnabled == false
        or profile.summonAutoRemoveNearby == false or #ordered == 0 then return end
    local changed = false
    for index = #ordered, 1, -1 do
        local entry = ordered[index]
        local nearby, signal = Nearby(entry)
        if nearby then
            table.remove(ordered, index)
            byGUID[entry.guid] = nil
            changed = true
            Trace("QUEUE_REMOVE", entry.fullName .. " reason=IN_RANGE signal=" .. signal)
        end
    end
    if changed then NotifyChanged() end
end

local function AddRequest(sender, senderGUID, source)
    local profile = api.GetProfile()
    if not api.IsAddonEnabled() or not profile
        or profile.summonQueueEnabled == false then return end
    if not GroupCategory() then
        Trace("QUEUE_IGNORE", "source=" .. source .. " no active group")
        return
    end
    if profile.summonSources and profile.summonSources[source] == false then
        Trace("QUEUE_IGNORE", "source=" .. source .. " disabled")
        return
    end
    local member = MatchSender(sender, senderGUID, Roster())
    if not member then
        Trace("QUEUE_IGNORE", "source=" .. source .. " sender not in group")
        return
    end
    local existing = byGUID[member.guid]
    if existing then
        Trace("QUEUE_DUPLICATE", existing.fullName .. " position unchanged")
        if WarlockHudReopenSummonQueue then WarlockHudReopenSummonQueue() end
        return
    end
    local entry = {
        guid = member.guid, name = member.name,
        fullName = member.fullName, class = member.class,
        chatName = Readable(sender) and type(sender) == "string" and sender or nil,
        unit = member.unit, requestedAt = GetTime(), source = source,
    }
    ordered[#ordered + 1] = entry
    byGUID[entry.guid] = entry
    RefreshSummonStatus(entry)
    NotifyChanged()
    Trace("QUEUE_ADD", entry.fullName .. " source=" .. source
        .. " position=" .. #ordered)
end

function WarlockHudGetSummonQueue()
    return ordered
end

function WarlockHudRemoveSummonRequest(guid)
    local entry = byGUID[guid]
    if not entry then return end
    for index, queued in ipairs(ordered) do
        if queued == entry then table.remove(ordered, index); break end
    end
    byGUID[guid] = nil
    Trace("QUEUE_REMOVE", entry.fullName .. " reason=MANUAL")
    NotifyChanged()
end

function WarlockHudClearSummonQueue(reason)
    if #ordered == 0 then
        NotifyChanged()
        return
    end
    ordered = {}
    byGUID = {}
    Trace("QUEUE_CLEAR", "reason=" .. (reason or "MANUAL"))
    NotifyChanged()
end

function WarlockHudSummonQueueReport()
    if WarlockHudOpenDebugTrace then WarlockHudOpenDebugTrace() end
    Trace("QUEUE", #ordered .. " pending; enable Summon tracing to copy entries")
    for index, entry in ipairs(ordered) do
        Trace("QUEUE", index .. " " .. entry.fullName .. " "
            .. math.floor(GetTime() - entry.requestedAt) .. "s source=" .. entry.source)
    end
end

for event in pairs(chatSources) do events:RegisterEvent(event) end
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("INCOMING_SUMMON_CHANGED")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        RefreshRoster()
        return
    end
    if event == "INCOMING_SUMMON_CHANGED" then
        RefreshSummonStatuses()
        return
    end
    local message, sender, _, _, _, _, _, _, _, _, _, guid = ...
    if not Readable(message) or type(message) ~= "string" then return end
    local profile = api.GetProfile()
    local keyword = profile and profile.summonKeyword or "123"
    local request = message:match("^%s*(.-)%s*$")
    if not request or request:lower() ~= keyword:lower() then return end
    AddRequest(sender, guid, chatSources[event])
end)
events:SetScript("OnUpdate", function(_, elapsed)
    if #ordered == 0 then rangeElapsed = 0; return end
    rangeElapsed = rangeElapsed + elapsed
    if rangeElapsed < 2 then return end
    rangeElapsed = 0
    RefreshSummonStatuses()
    RemoveNearby()
end)
