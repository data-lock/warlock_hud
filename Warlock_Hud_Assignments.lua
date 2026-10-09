-- Group assignments are deliberately temporary. Only personal display settings persist.
local api = WarlockHudAPI
local PREFIX = "WHUD_ASSIGN"
local TYPES = {
    curse = {
        { "NONE", "None" }, { "ELEMENTS", "Elements" },
        { "RECKLESSNESS", "Recklessness" }, { "WEAKNESS", "Weakness" },
        { "TONGUES", "Tongues" }, { "EXHAUSTION", "Exhaustion" },
    },
    bane = {
        { "NONE", "None" }, { "DOOM", "Doom" },
        { "AGONY", "Agony" }, { "HAVOC", "Havoc" },
    },
}
local SPELL_NAMES = {
    curse = {
        ELEMENTS = "Curse of the Elements", RECKLESSNESS = "Curse of Recklessness",
        WEAKNESS = "Curse of Weakness", TONGUES = "Curse of Tongues",
        EXHAUSTION = "Curse of Exhaustion",
    },
    bane = {
        DOOM = "Bane of Doom", AGONY = "Bane of Agony", HAVOC = "Bane of Havoc",
    },
}
local byGUID, roster, rosterByName = {}, {}, {}
local assignments = {}
local wasGrouped = false
local pendingSnapshot
local requestAt, lastRequestAt, lastSnapshotAt = 0, -100, 0
local revision = 0
local requestRevision = 0
local registered = false
local lastCastGUID, lastCastID
local window, rowsFrame, compactRowsFrame, statusText, enableCheck, warningCheck
local rows, compactRows = {}, {}
local FULL_WIDTH, COMPACT_WIDTH = 635, 385
local events = CreateFrame("Frame")

local function Public(value)
    return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

local function Say(message)
    print("|cff9482c9Warlock HUD:|r " .. message)
end

local function Profile()
    return api.GetProfile()
end

local function Enabled()
    local profile = Profile()
    return profile and api.IsAddonEnabled()
        and profile.assignmentsEnabled ~= false
end

local function NameKey(name)
    return type(name) == "string" and name:lower():gsub("%s+", "") or nil
end

local function FullName(unit)
    local name, realm = UnitName(unit)
    if not Public(name) or type(name) ~= "string" then return nil end
    if Public(realm) and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function DisplayName(name)
    return name and name:gsub("%-", " ") or "Unassigned"
end

local function AddRosterUnit(unit)
    local exists = UnitExists(unit)
    if not Public(exists) or not exists then return end
    local guid = UnitGUID(unit)
    local _, class = UnitClass(unit)
    local name = FullName(unit)
    if not Public(guid) or not Public(class)
        or not name or byGUID[guid] then return end
    local row = { guid = guid, name = name, unit = unit, class = class }
    byGUID[guid] = row
    if class == "WARLOCK" then roster[#roster + 1] = row end
    local full = NameKey(name)
    rosterByName[full] = row
    local short = NameKey(name:match("^[^-]+"))
    if rosterByName[short] == nil then
        rosterByName[short] = row
    elseif rosterByName[short] ~= row then
        rosterByName[short] = false
    end
end

local function RefreshRoster()
    local grouped = IsInGroup()
    local disbanded = wasGrouped and not grouped
    byGUID, roster, rosterByName = {}, {}, {}
    AddRosterUnit("player")
    local raid = IsInRaid()
    local count = raid and GetNumGroupMembers()
        or (grouped and GetNumSubgroupMembers() or 0)
    for index = 1, count do
        AddRosterUnit((raid and "raid" or "party") .. index)
    end
    if disbanded then
        assignments, pendingSnapshot = {}, nil
    else
        for guid in pairs(assignments) do
            if not byGUID[guid] or byGUID[guid].class ~= "WARLOCK" then
                assignments[guid] = nil
            end
        end
    end
    wasGrouped = grouped
    table.sort(roster, function(a, b)
        if a.unit == "player" then return true end
        if b.unit == "player" then return false end
        return a.name < b.name
    end)
    return disbanded
end

local function SenderRow(sender)
    local key = NameKey(sender)
    local row = key and rosterByName[key]
    if row then return row end
    local short = key and key:match("^[^-]+")
    return short and rosterByName[short] or nil
end

local function OwnRow()
    local guid = UnitGUID("player")
    return Public(guid) and byGUID[guid] or nil
end

local function Channel()
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function Send(parts)
    if not registered or not Enabled() then return false end
    local channel = Channel()
    if not channel then return false end
    local payload = table.concat(parts, "|")
    if #payload > 240 then return false end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, channel)
    return ok and result ~= false
end

local function ValidKey(category, key)
    if not TYPES[category] then return false end
    for _, choice in ipairs(TYPES[category]) do
        if choice[1] == key then return true end
    end
    return false
end

local function SaveAssignmentCache()
    local own = OwnRow()
    local db = api.GetDB and api.GetDB() or WarlockHudDB
    if not own or type(db) ~= "table" then return end
    local entries = {}
    for guid, state in pairs(assignments) do
        if byGUID[guid] and byGUID[guid].class == "WARLOCK" then
            entries[guid] = {
                curse = state.curse, bane = state.bane,
                curseBy = state.curseBy, baneBy = state.baneBy,
            }
        end
    end
    db.assignmentCache = { owner = own.guid, entries = entries }
end

local function RestoreAssignmentCache()
    local own = OwnRow()
    local db = api.GetDB and api.GetDB() or WarlockHudDB
    local cache = type(db) == "table" and db.assignmentCache
    if not own or type(cache) ~= "table" or cache.owner ~= own.guid
        or type(cache.entries) ~= "table" then return end
    for guid, state in pairs(cache.entries) do
        if byGUID[guid] and byGUID[guid].class == "WARLOCK"
            and type(state) == "table" then
            local restored = {}
            for _, category in ipairs({ "curse", "bane" }) do
                local key = state[category]
                if ValidKey(category, key) then
                    restored[category] = key
                    local author = state[category .. "By"]
                    if key ~= "NONE" and byGUID[author] then
                        restored[category .. "By"] = author
                    end
                end
            end
            if next(restored) then assignments[guid] = restored end
        end
    end
end

local function AssignedSpell(category, key)
    local name = SPELL_NAMES[category] and SPELL_NAMES[category][key]
    if not name then return nil end
    for _, spell in ipairs(api.Spells) do
        if spell.name == name then return spell end
    end
end

local function Known(spell)
    local checker = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell
    if not spell or not checker then return false end
    for _, id in ipairs(spell.ids) do
        local ok, known = pcall(checker, id)
        if ok and Public(known) and known then return true end
    end
    local resolver = C_Spell and C_Spell.GetSpellIDForSpellIdentifier
    if resolver then
        local ok, id = pcall(resolver, spell.name)
        if ok and Public(id) and id then
            local knownOK, known = pcall(checker, id)
            if knownOK and Public(known) and known then return true end
        end
    end
    return false
end

function WarlockHudAssignmentSpell(category)
    if not Enabled() then return nil end
    local own = OwnRow()
    local state = own and assignments[own.guid]
    local key = state and state[category]
    if not key or key == "NONE" then return nil end
    return AssignedSpell(category, key)
end

local function ClearWarning(category)
    if WarlockHudFlashAssignmentSlot then
        WarlockHudFlashAssignmentSlot(category, false)
    end
end

local function Changed(clearWarning)
    revision = revision + 1
    SaveAssignmentCache()
    if clearWarning ~= false then ClearWarning() end
    if WarlockHudRefreshAssignmentIcons then WarlockHudRefreshAssignmentIcons() end
    if window and window:IsShown() and window.Refresh then window:Refresh() end
end

local function SetAssignment(guid, category, key, by)
    if not byGUID[guid] or byGUID[guid].class ~= "WARLOCK"
        or not ValidKey(category, key) then return false end
    local state = assignments[guid] or {}
    state[category] = key
    state[category .. "By"] = key ~= "NONE" and by or nil
    assignments[guid] = state
    Changed()
    return true
end

local function RequestSnapshot()
    if not Enabled() or not Channel() or not OwnRow() then return end
    local now = GetTime()
    if now - lastRequestAt < 2 then return end
    lastRequestAt, requestAt, requestRevision = now, now, revision
    Send({ "V1", "REQ", OwnRow().guid })
end

local function Snapshot()
    local own = OwnRow()
    if not own or not Channel() then return end
    local nonce = tostring(math.floor(GetTime() * 1000))
    if not Send({ "V1", "BEGIN", nonce, own.guid }) then return end
    for _, row in ipairs(roster) do
        local state = assignments[row.guid]
        if state and (state.curse or state.bane) then
            Send({ "V1", "ROW", nonce, row.guid,
                state.curse or "NONE", state.bane or "NONE",
                state.curseBy or "0", state.baneBy or "0" })
        end
    end
    Send({ "V1", "END", nonce, own.guid })
end

local function Fields(payload)
    if type(payload) ~= "string" or #payload > 240 then return nil end
    local fields = {}
    for field in (payload .. "|"):gmatch("(.-)|") do
        fields[#fields + 1] = field
        if #fields > 9 then return nil end
    end
    if fields[1] ~= "V1" then return nil end
    return fields
end

local function Receive(payload, sender)
    local fields = Fields(payload)
    local from = SenderRow(sender)
    if not fields or not from or not Enabled() then return end
    local action = fields[2]
    if action == "REQ" then
        if #fields ~= 3 or fields[3] ~= from.guid then return end
        if not OwnRow() or not next(assignments) then return end
        local seen = lastSnapshotAt
        if C_Timer and C_Timer.After then
            C_Timer.After(0.4, function()
                if lastSnapshotAt == seen and byGUID[from.guid] then Snapshot() end
            end)
        end
    elseif action == "SET" then
        if #fields ~= 6 or fields[6] ~= from.guid then return end
        SetAssignment(fields[3], fields[4], fields[5], from.guid)
    elseif action == "BEGIN" then
        if #fields ~= 4 or fields[4] ~= from.guid
            or #fields[3] > 20 or not fields[3]:match("^%d+$")
            or requestAt == 0 or GetTime() - requestAt > 8
            or revision ~= requestRevision then return end
        pendingSnapshot = { nonce = fields[3], sender = from.guid,
            rows = {}, revision = revision }
    elseif action == "ROW" then
        local pending = pendingSnapshot
        if #fields ~= 8 or not pending or pending.sender ~= from.guid
            or pending.nonce ~= fields[3] or not byGUID[fields[4]]
            or byGUID[fields[4]].class ~= "WARLOCK"
            or not ValidKey("curse", fields[5]) or not ValidKey("bane", fields[6])
            or (fields[7] ~= "0" and not byGUID[fields[7]])
            or (fields[8] ~= "0" and not byGUID[fields[8]]) then return end
        pending.rows[fields[4]] = {
            curse = fields[5], bane = fields[6],
            curseBy = fields[7] ~= "0" and fields[7] or nil,
            baneBy = fields[8] ~= "0" and fields[8] or nil,
        }
    elseif action == "END" then
        local pending = pendingSnapshot
        if #fields ~= 4 or not pending or pending.sender ~= from.guid
            or pending.nonce ~= fields[3] or fields[4] ~= from.guid then return end
        pendingSnapshot = nil
        if pending.revision ~= revision or revision ~= requestRevision then return end
        assignments = pending.rows
        lastSnapshotAt = GetTime()
        requestAt = 0
        Changed()
    end
end

function WarlockHudSetAssignment(guid, category, key)
    local own = OwnRow()
    if not Enabled() or not own then return end
    if SetAssignment(guid, category, key, own.guid) then
        Send({ "V1", "SET", guid, category, key, own.guid })
    end
end

local function Label(category, key)
    for _, choice in ipairs(TYPES[category]) do
        if choice[1] == key then return choice[2] end
    end
    return "None"
end

local function WarningForCast(spellID, castGUID)
    if not Public(spellID) or type(spellID) ~= "number" then return end
    local profile = Profile()
    if not Enabled() or not profile or profile.assignmentWarnings == false then return end
    if Public(castGUID) and castGUID == lastCastGUID and spellID == lastCastID then return end
    lastCastGUID, lastCastID = Public(castGUID) and castGUID or nil, spellID
    local own = OwnRow()
    local state = own and assignments[own.guid]
    if not state then return end
    for category, names in pairs(SPELL_NAMES) do
        for key, name in pairs(names) do
            local spell = AssignedSpell(category, key)
            if spell then
                local matched = false
                for _, id in ipairs(spell.ids) do
                    if id == spellID then matched = true; break end
                end
                if not matched and C_Spell
                    and C_Spell.GetSpellIDForSpellIdentifier then
                    local ok, currentID = pcall(
                        C_Spell.GetSpellIDForSpellIdentifier, name)
                    matched = ok and Public(currentID) and currentID == spellID
                end
                if matched then
                    local expected = state[category]
                    if expected and expected ~= "NONE" then
                        ClearWarning(category)
                        if expected ~= key then
                            Say("Assigned " .. category .. ": " .. Label(category, expected)
                                .. "; you cast " .. Label(category, key) .. ".")
                            if WarlockHudFlashAssignmentSlot then
                                WarlockHudFlashAssignmentSlot(category, true)
                            end
                        end
                    end
                    return
                end
            end
        end
    end
end

local function PlayerStatus()
    local own = OwnRow()
    local state = own and assignments[own.guid]
    local messages = {}
    if not Enabled() then return "Assignments are disabled for this profile." end
    for category, names in pairs(SPELL_NAMES) do
        local key = state and state[category]
        if key and key ~= "NONE" then
            local spell = AssignedSpell(category, key)
            if not Known(spell) then
                messages[#messages + 1] = Label(category, key) .. ": Not known"
            elseif Profile().enabled[spell.name] == false then
                messages[#messages + 1] = Label(category, key) .. ": aura tracking disabled"
            end
        end
    end
    if #messages > 0 then return table.concat(messages, "  |  ") end
    if not Channel() then return "Solo choices are saved for this character." end
    if not registered then return "Group sync is unavailable on this client." end
    return "Any group member using Warlock HUD can edit assignments."
end

local function NewButton(parent, label, width, x, y, handler)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 23)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(label)
    button:SetScript("OnClick", handler)
    return button
end

local function NewDrop(parent, category, x)
    local drop = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    drop:SetPoint("TOPLEFT", x, 3)
    UIDropDownMenu_SetWidth(drop, 145)
    UIDropDownMenu_Initialize(drop, function(_, level)
        if (level or 1) ~= 1 then return end
        for _, choice in ipairs(TYPES[category]) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = choice[2]
            info.checked = drop.key == choice[1]
            info.func = function() WarlockHudSetAssignment(parent.guid, category, choice[1]) end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    return drop
end

local function NewRow(index)
    local row = CreateFrame("Frame", nil, rowsFrame)
    row:SetSize(590, 58)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * 59)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", 4, -4)
    row.name:SetWidth(185)
    row.name:SetJustifyH("LEFT")
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints(row)
    row.highlight:SetColorTexture(0.35, 0.3, 0.55, 0.25)
    row.by = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.by:SetPoint("TOPLEFT", 4, -31)
    row.by:SetWidth(575)
    row.by:SetHeight(24)
    row.by:SetJustifyH("LEFT")
    row.curse = NewDrop(row, "curse", 205)
    row.bane = NewDrop(row, "bane", 385)
    rows[index] = row
    return row
end

local function SpellTexture(category, key)
    if not key or key == "NONE" then return nil end
    local spell = AssignedSpell(category, key)
    local identifier = spell and spell.ids and spell.ids[1]
        or SPELL_NAMES[category][key]
    if not identifier or not C_Spell or not C_Spell.GetSpellTexture then return nil end
    local ok, texture = pcall(C_Spell.GetSpellTexture, identifier)
    return ok and Public(texture) and texture or nil
end

local function NewCompactRow(index)
    local row = CreateFrame("Frame", nil, compactRowsFrame)
    row:SetSize(COMPACT_WIDTH - 40, 36)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * 38)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetWidth(238)
    row.name:SetJustifyH("LEFT")
    row.icons = {}
    for category, x in pairs({ curse = 257, bane = 309 }) do
        local iconCategory = category
        local icon = CreateFrame("Frame", nil, row)
        icon:SetSize(30, 30)
        icon:SetPoint("LEFT", x, 0)
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints(icon)
        icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon.text = icon:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        icon.text:SetPoint("CENTER")
        icon.text:SetText("—")
        icon:EnableMouse(true)
        icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText((iconCategory == "curse" and "Curse: " or "Bane: ")
                .. Label(iconCategory, self.key or "NONE"))
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.icons[iconCategory] = icon
    end
    compactRows[index] = row
    return row
end

local function MinimumFullHeight()
    return math.max(420, 200 + #roster * 59)
end

local function ApplyWindowMode()
    local profile = Profile()
    local compact = profile.assignmentWindowCompact == true
    window:SetResizable(not compact)
    rowsFrame:SetShown(not compact)
    compactRowsFrame:SetShown(compact)
    window.fullControls:SetShown(not compact)
    window.toggle:SetText(compact and "Expand" or "Compact")
    window.toggle:ClearAllPoints()
    if compact then
        window.toggle:SetPoint("TOPRIGHT", -20, -35)
        window:SetSize(COMPACT_WIDTH, 135 + #roster * 38)
    else
        window.toggle:SetPoint("BOTTOMRIGHT", -30, 10)
        local width = math.max(FULL_WIDTH, profile.assignmentWindowWidth or FULL_WIDTH)
        local height = math.max(MinimumFullHeight(),
            profile.assignmentWindowHeight or MinimumFullHeight())
        if window.SetResizeBounds then
            window:SetResizeBounds(FULL_WIDTH, MinimumFullHeight())
        elseif window.SetMinResize then
            window:SetMinResize(FULL_WIDTH, MinimumFullHeight())
        end
        window:SetSize(width, height)
        window.resizeGrip:Show()
    end
    window.resizeGrip:SetShown(not compact)
end

local function RefreshWindow()
    if not window then return end
    local own = OwnRow()
    local canEdit = own and Enabled()
    statusText:SetText(PlayerStatus())
    enableCheck:SetChecked(Enabled())
    warningCheck:SetChecked(Profile().assignmentWarnings ~= false)
    for index, member in ipairs(roster) do
        local row = rows[index] or NewRow(index)
        row.guid = member.guid
        local state = assignments[member.guid] or {}
        local isLocal = own and member.guid == own.guid
        row.name:SetText(DisplayName(member.name) .. (isLocal and " (you)" or ""))
        row.highlight:SetShown(isLocal and true or false)
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS.WARLOCK
        row.name:SetTextColor(color and color.r or 0.58,
            color and color.g or 0.51, color and color.b or 0.79)
        local curseBy = state.curseBy and byGUID[state.curseBy]
        local baneBy = state.baneBy and byGUID[state.baneBy]
        row.by:SetText("Curse by: " .. DisplayName(curseBy and curseBy.name)
            .. "     Bane by: " .. DisplayName(baneBy and baneBy.name))
        for _, category in ipairs({ "curse", "bane" }) do
            local drop = row[category]
            drop.key = state[category] or "NONE"
            UIDropDownMenu_SetText(drop, Label(category, drop.key))
            if canEdit then UIDropDownMenu_EnableDropDown(drop)
            else UIDropDownMenu_DisableDropDown(drop) end
        end
        row:Show()
    end
    for index = #roster + 1, #rows do rows[index]:Hide() end
    rowsFrame:SetHeight(math.max(58, #roster * 59))
    for index, member in ipairs(roster) do
        local row = compactRows[index] or NewCompactRow(index)
        local state = assignments[member.guid] or {}
        row.name:SetText(DisplayName(member.name))
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS.WARLOCK
        row.name:SetTextColor(color and color.r or 0.58,
            color and color.g or 0.51, color and color.b or 0.79)
        for _, category in ipairs({ "curse", "bane" }) do
            local icon = row.icons[category]
            icon.key = state[category] or "NONE"
            local texture = SpellTexture(category, icon.key)
            icon.texture:SetTexture(texture)
            icon.texture:SetShown(texture and true or false)
            icon.text:SetShown(not texture)
        end
        row:Show()
    end
    for index = #roster + 1, #compactRows do compactRows[index]:Hide() end
    compactRowsFrame:SetHeight(math.max(36, #roster * 38))
    ApplyWindowMode()
    window:Layout(window:GetWidth())
    for _, header in ipairs(window.compactHeaders) do
        header:SetShown(Profile().assignmentWindowCompact == true)
    end
    local channel = Channel()
    local destination = channel == "INSTANCE_CHAT" and "Instance"
        or channel == "RAID" and "Raid" or "Party"
    window.announce:SetText("Announce to " .. destination)
    window.announce:SetEnabled(channel and canEdit and true or false)
end

function WarlockHudAnnounceAssignments()
    local channel = Channel()
    if not channel then
        Say("Join a party, raid, or instance group before announcing assignments.")
        return
    end
    local lines = {}
    for _, row in ipairs(roster) do
        local state = assignments[row.guid] or {}
        lines[#lines + 1] = "Warlock assignments - " .. DisplayName(row.name) .. ": Curse "
            .. Label("curse", state.curse or "NONE") .. ", Bane "
            .. Label("bane", state.bane or "NONE")
    end
    if #lines == 0 then
        Say("No Warlocks are available to announce.")
        return
    end
    for _, line in ipairs(lines) do
        local sent = false
        if C_ChatInfo and C_ChatInfo.SendChatMessage then
            sent = pcall(C_ChatInfo.SendChatMessage, line, channel)
        end
        if not sent and SendChatMessage then
            pcall(SendChatMessage, line, channel)
        end
    end
end

local function CreateWindow()
    window = CreateFrame("Frame", "WarlockHudAssignmentsWindow", UIParent,
        "BasicFrameTemplateWithInset")
    window:SetSize(635, 420)
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:SetResizable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window.TitleText:SetText("Warlock HUD - Assignments")
    window.fullControls = {}
    function window.fullControls:SetShown(shown)
        for _, control in ipairs(self) do control:SetShown(shown) end
    end
    local profile = Profile()
    if type(profile.assignmentWindowX) == "number"
        and type(profile.assignmentWindowY) == "number" then
        window:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            profile.assignmentWindowX * UIParent:GetWidth(),
            profile.assignmentWindowY * UIParent:GetHeight())
    else
        window:SetPoint("CENTER")
    end
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        if x and y then
            Profile().assignmentWindowX = x / UIParent:GetWidth()
            Profile().assignmentWindowY = y / UIParent:GetHeight()
        end
    end)
    local subtitle = window:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", 20, -37)
    subtitle:SetText("Anyone can assign. Solo choices are local. This window never casts spells.")
    window.fullControls[#window.fullControls + 1] = subtitle
    enableCheck = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 16, -55)
    enableCheck:SetScript("OnClick", function(self)
        Profile().assignmentsEnabled = self:GetChecked() and true or false
        if not Enabled() then ClearWarning() end
        Changed()
        if Enabled() then RequestSnapshot() end
    end)
    window.fullControls[#window.fullControls + 1] = enableCheck
    local enableLabel = window:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 2, 0)
    enableLabel:SetText("Enable assignments")
    window.fullControls[#window.fullControls + 1] = enableLabel
    warningCheck = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    warningCheck:SetPoint("TOPLEFT", 205, -55)
    warningCheck:SetScript("OnClick", function(self)
        Profile().assignmentWarnings = self:GetChecked() and true or false
        if Profile().assignmentWarnings == false then ClearWarning() end
    end)
    window.fullControls[#window.fullControls + 1] = warningCheck
    local warningLabel = window:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    warningLabel:SetPoint("LEFT", warningCheck, "RIGHT", 2, 0)
    warningLabel:SetText("Warn on wrong cast")
    window.fullControls[#window.fullControls + 1] = warningLabel
    local nameHeader = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameHeader:SetPoint("TOPLEFT", 24, -100)
    nameHeader:SetText("Warlock")
    window.fullControls[#window.fullControls + 1] = nameHeader
    local curseHeader = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    curseHeader:SetPoint("TOPLEFT", 243, -100)
    curseHeader:SetText("Curse")
    window.fullControls[#window.fullControls + 1] = curseHeader
    local baneHeader = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    baneHeader:SetPoint("TOPLEFT", 423, -100)
    baneHeader:SetText("Bane")
    window.fullControls[#window.fullControls + 1] = baneHeader
    rowsFrame = CreateFrame("Frame", nil, window)
    rowsFrame:SetPoint("TOPLEFT", 20, -120)
    rowsFrame:SetSize(590, 58)
    compactRowsFrame = CreateFrame("Frame", nil, window)
    compactRowsFrame:SetPoint("TOPLEFT", 20, -93)
    compactRowsFrame:SetSize(COMPACT_WIDTH - 40, 36)
    local compactName = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    compactName:SetPoint("TOPLEFT", 24, -74)
    compactName:SetText("Name")
    local compactCurse = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    compactCurse:SetPoint("TOPLEFT", 278, -74)
    compactCurse:SetText("Curse")
    local compactBane = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    compactBane:SetPoint("TOPLEFT", 330, -74)
    compactBane:SetText("Bane")
    window.compactHeaders = { compactName, compactCurse, compactBane }
    statusText = window:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOMLEFT", 22, 48)
    statusText:SetWidth(590)
    statusText:SetHeight(24)
    statusText:SetJustifyH("LEFT")
    window.fullControls[#window.fullControls + 1] = statusText
    window.announce = NewButton(window, "Announce to Party", 180, 20, -390,
        WarlockHudAnnounceAssignments)
    window.announce:ClearAllPoints()
    window.announce:SetPoint("BOTTOMLEFT", 20, 10)
    window.fullControls[#window.fullControls + 1] = window.announce
    local sync = NewButton(window, "Request Sync", 115, 210, -390, RequestSnapshot)
    sync:ClearAllPoints()
    sync:SetPoint("BOTTOMLEFT", 210, 10)
    window.fullControls[#window.fullControls + 1] = sync
    window.toggle = NewButton(window, "Compact", 85, 0, 0, function()
        Profile().assignmentWindowCompact = not (Profile().assignmentWindowCompact == true)
        window:Refresh()
    end)
    window.toggle:ClearAllPoints()
    window.toggle:SetPoint("BOTTOMRIGHT", -30, 10)
    window.resizeGrip = CreateFrame("Button", nil, window)
    window.resizeGrip:SetSize(18, 18)
    window.resizeGrip:SetPoint("BOTTOMRIGHT", -4, 4)
    window.resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    window.resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    window.resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    window.resizeGrip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then window:StartSizing("BOTTOMRIGHT") end
    end)
    window.resizeGrip:SetScript("OnMouseUp", function()
        window:StopMovingOrSizing()
        Profile().assignmentWindowWidth = window:GetWidth()
        Profile().assignmentWindowHeight = window:GetHeight()
    end)
    function window:Layout(width)
        local contentWidth = math.max(590, width - 45)
        rowsFrame:SetWidth(contentWidth)
        statusText:SetWidth(contentWidth)
        for _, row in ipairs(rows) do
            row:SetWidth(contentWidth)
            row.name:SetWidth(contentWidth - 405)
            row.by:SetWidth(contentWidth - 15)
            row.curse:ClearAllPoints()
            row.curse:SetPoint("TOPRIGHT", row, "TOPRIGHT", -205, 3)
            row.bane:ClearAllPoints()
            row.bane:SetPoint("TOPRIGHT", row, "TOPRIGHT", -25, 3)
        end
        curseHeader:ClearAllPoints()
        curseHeader:SetPoint("TOPRIGHT", self, "TOPRIGHT", -344, -100)
        baneHeader:ClearAllPoints()
        baneHeader:SetPoint("TOPRIGHT", self, "TOPRIGHT", -164, -100)
    end
    window:SetScript("OnSizeChanged", function(self, width) self:Layout(width) end)
    window.Refresh = RefreshWindow
    window:Hide()
end

function WarlockHudOpenAssignments()
    if not Profile() then api.InitializeProfiles() end
    RefreshRoster()
    local own = OwnRow()
    local state = own and assignments[own.guid]
    if state and ((state.curse and state.curse ~= "NONE")
        or (state.bane and state.bane ~= "NONE")) then
        Profile().assignmentWindowCompact = true
    end
    if not window then CreateWindow() end
    window:Refresh()
    window:Show()
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if not Profile() then api.InitializeProfiles() end
        local register = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix
        local ok, value
        if register then ok, value = pcall(register, PREFIX) end
        registered = ok and value ~= false and true or false
        RefreshRoster()
        RestoreAssignmentCache()
        Changed()
        RequestSnapshot()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        local disbanded = RefreshRoster()
        Changed(disbanded)
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, RequestSnapshot)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        ClearWarning()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        if unit == "player" then WarningForCast(spellID, castGUID) end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, payload, _, sender = ...
        if prefix == PREFIX and Public(payload) and Public(sender) then
            Receive(payload, sender)
        end
    end
end)
