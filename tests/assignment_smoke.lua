-- Run from the addon directory with Lua 5.1: lua51.exe tests/assignment_smoke.lua
-- This covers local state and message handling, not the Forever client APIs.
local profile = { enabled = {} }
WarlockHudDB = {}
local grouped = true
local raid, instance = false, false
local now = 100
local sent, printed, flashes, chat = {}, {}, {}, {}
local activeWarnings = {}
local timers = {}
local frame
local units = {
    player = { guid = "Player-1", name = "Alice", class = "WARLOCK" },
    party1 = { guid = "Player-2", name = "Leader", class = "WARLOCK" },
    party2 = { guid = "Player-3", name = "ClassLead", realm = "TestRealm",
        class = "WARLOCK" },
}

function CreateFrame()
    frame = {
        RegisterEvent = function() end,
        SetScript = function(self, script, handler) self[script] = handler end,
    }
    return frame
end
function UnitExists(unit) return units[unit] ~= nil end
function UnitGUID(unit) return units[unit] and units[unit].guid end
function UnitClass(unit)
    local class = units[unit] and units[unit].class
    return class, class
end
function UnitName(unit)
    local member = units[unit]
    return member and member.name, member and member.realm
end
function IsInRaid() return raid end
LE_PARTY_CATEGORY_INSTANCE = 2
function IsInGroup(category)
    if category == LE_PARTY_CATEGORY_INSTANCE then return grouped and instance end
    return grouped
end
function GetNumSubgroupMembers() return grouped and 2 or 0 end
function UnitIsGroupLeader(unit) return unit == "party1" end
function UnitIsGroupAssistant() return false end
function GetTime() return now end
function print(message) printed[#printed + 1] = message end
function SendChatMessage(message, channel)
    chat[#chat + 1] = { message = message, channel = channel }
end

C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix)
        assert(prefix == "WHUD_ASSIGN")
        return true
    end,
    SendAddonMessage = function(prefix, payload, channel)
        sent[#sent + 1] = { prefix, payload, channel }
        return true
    end,
}
C_Timer = {
    After = function(delay, callback)
        timers[#timers + 1] = { delay, callback }
    end,
}
C_SpellBook = { IsSpellKnown = function(id) return id == 1490 end }
C_Spell = {
    GetSpellIDForSpellIdentifier = function(name)
        if name == "Curse of the Elements" then return 1490 end
    end,
}
WarlockHudRefreshAssignmentIcons = function() end
WarlockHudFlashAssignmentSlot = function(category, show)
    flashes[#flashes + 1] = { category, show }
    if category then
        activeWarnings[category] = show and true or nil
    elseif not show then
        activeWarnings.curse, activeWarnings.bane = nil, nil
    end
end
WarlockHudAPI = {
    GetProfile = function() return profile end,
    IsAddonEnabled = function() return true end,
    Spells = {
        { name = "Curse of the Elements", slot = 3, ids = { 1490 } },
        { name = "Curse of Recklessness", slot = 3, ids = { 704 } },
        { name = "Bane of Doom", slot = 2, ids = { 603 } },
        { name = "Bane of Agony", slot = 2, ids = { 980 } },
    },
}

assert(loadfile("Warlock_Hud_Assignments.lua"))()
local function event(name, ...)
    frame.OnEvent(frame, name, ...)
end
local function receive(payload, sender)
    event("CHAT_MSG_ADDON", "WHUD_ASSIGN", payload, "PARTY", sender)
end

event("PLAYER_LOGIN")
assert(sent[1][2] == "V1|REQ|Player-1", "login should request a snapshot")
assert(WarlockHudAssignmentSpell("curse") == nil, "no initial assignment")

receive("V1|SET|Player-1|curse|ELEMENTS|Player-1", "Alice")
assert(WarlockHudAssignmentSpell("curse").name == "Curse of the Elements",
    "a group member can assign without leader status")
WarlockHudSetAssignment("Player-1", "curse", "NONE")
receive("V1|SET|Player-1|curse|RECKLESSNESS|Player-4", "Stranger")
assert(WarlockHudAssignmentSpell("curse") == nil,
    "a sender outside the roster is rejected")
receive("V1|SET|Player-1|curse|INVALID|Player-2", "Leader")
assert(WarlockHudAssignmentSpell("curse") == nil, "invalid type is rejected")
receive("V1|SET|Player-1|curse|ELEMENTS|Player-3", "ClassLead")
assert(WarlockHudAssignmentSpell("curse").name == "Curse of the Elements",
    "the class leader can assign without raid authority")
assert(WarlockHudAssignmentSpell("bane") == nil, "categories are independent")

local timersBeforeWarning = #timers
event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 704)
assert(#printed == 1 and printed[1]:find("you cast Recklessness", 1, true),
    "wrong curse should warn once")
assert(flashes[#flashes][1] == "curse" and flashes[#flashes][2] == true,
    "wrong curse should flash its slot")
assert(#timers == timersBeforeWarning,
    "wrong-cast color should not have a timeout")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 704)
assert(#printed == 1, "duplicate cast should not warn twice")
event("GROUP_ROSTER_UPDATE")
assert(flashes[#flashes][2] == true,
    "routine roster refresh should not clear the wrong-cast color")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 1490)
assert(flashes[#flashes][2] == false, "correct curse clears flash")

receive("V1|SET|Player-1|bane|DOOM|Player-1", "Alice")
assert(WarlockHudAssignmentSpell("bane").name == "Bane of Doom",
    "a group member can assign a Bane")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-3", 980)
event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-4", 704)
assert(activeWarnings.bane and activeWarnings.curse,
    "wrong Curse and Bane should be highlighted independently")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-5", 1490)
assert(activeWarnings.bane and not activeWarnings.curse,
    "correct Curse must not clear the Bane warning")
event("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-6", 603)
assert(not activeWarnings.bane, "correct Bane clears its warning")
assert(#chat == 0, "assignment changes must not announce automatically")
WarlockHudAnnounceAssignments()
assert(#chat == 3 and chat[1].channel == "PARTY",
    "explicit announcement should use party chat for all Warlocks")
local foundRealmDisplay = false
for _, message in ipairs(chat) do
    if message.message:find("ClassLead TestRealm", 1, true) then
        foundRealmDisplay = true
    end
end
assert(foundRealmDisplay, "announcement should display a space before the realm")
raid = true
WarlockHudAnnounceAssignments()
assert(#chat == 6 and chat[4].channel == "RAID",
    "explicit announcement should use raid chat")
instance = true
WarlockHudAnnounceAssignments()
assert(#chat == 9 and chat[7].channel == "INSTANCE_CHAT",
    "instance chat should take priority")
raid, instance = false, false

grouped = false
event("GROUP_ROSTER_UPDATE")
assert(WarlockHudAssignmentSpell("curse") == nil
    and WarlockHudAssignmentSpell("bane") == nil,
    "disband clears temporary assignments")
assert(not next(WarlockHudDB.assignmentCache.entries),
    "disband also clears saved group assignments")
WarlockHudAnnounceAssignments()
assert(#chat == 9, "solo announcement should not send to group chat")
WarlockHudSetAssignment("Player-1", "curse", "ELEMENTS")
assert(WarlockHudAssignmentSpell("curse").name == "Curse of the Elements",
    "solo self-assignment should work")
event("PLAYER_ENTERING_WORLD")
assert(WarlockHudAssignmentSpell("curse") ~= nil,
    "solo assignment should survive roster refreshes")
WarlockHudSetAssignment("Player-1", "curse", "NONE")

grouped = true
now = 103
event("GROUP_ROSTER_UPDATE")
timers[#timers][2]()
receive("V1|BEGIN|103000|Player-3", "ClassLead")
receive("V1|ROW|103000|Player-1|ELEMENTS|DOOM|Player-3|Player-3", "ClassLead")
receive("V1|END|103000|Player-3", "ClassLead")
assert(WarlockHudAssignmentSpell("curse").name == "Curse of the Elements"
    and WarlockHudAssignmentSpell("bane").name == "Bane of Doom",
    "snapshot restores assignments after a reload")

now = 106
event("GROUP_ROSTER_UPDATE")
timers[#timers][2]()
receive("V1|BEGIN|106000|Player-3", "ClassLead")
receive("V1|SET|Player-1|curse|NONE|Player-3", "ClassLead")
receive("V1|ROW|106000|Player-1|ELEMENTS|DOOM|Player-3|Player-3", "ClassLead")
receive("V1|END|106000|Player-3", "ClassLead")
assert(WarlockHudAssignmentSpell("curse") == nil,
    "a stale snapshot must not overwrite a newer assignment")
WarlockHudSetAssignment("Player-1", "curse", "ELEMENTS")
assert(WarlockHudDB.assignmentCache.entries["Player-1"].curse == "ELEMENTS"
    and WarlockHudDB.assignmentCache.entries["Player-1"].bane == "DOOM",
    "both assignment categories should be saved")
assert(loadfile("Warlock_Hud_Assignments.lua"))()
event("PLAYER_LOGIN")
assert(WarlockHudAssignmentSpell("curse").name == "Curse of the Elements"
    and WarlockHudAssignmentSpell("bane").name == "Bane of Doom",
    "a reload should restore saved Curse and Bane choices")

-- Exercise the ordinary assignment window with a minimal frame mock.
local ui = {}
local methods = {}
local function region()
    return setmetatable({ shown = true }, { __index = methods })
end
function methods:SetSize(width, height)
    self.width, self.height = width, height
    if self.OnSizeChanged then self:OnSizeChanged(width, height) end
end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:GetWidth() return self.width or 0 end
function methods:GetHeight() return self.height or 0 end
function methods:SetShown(shown) self.shown = shown end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:SetText(value) self.text = value end
function methods:SetTexture(value) self.value = value end
function methods:SetScript(name, handler) self[name] = handler end
function methods:CreateFontString() return region() end
function methods:CreateTexture() return region() end
function methods:GetCenter() return 500, 400 end
function methods:GetChecked() return true end
setmetatable(methods, { __index = function() return function() end end })
UIParent = region()
UIParent.width, UIParent.height = 1000, 800
function CreateFrame(_, name)
    local item = region()
    if name then ui[name] = item end
    if name == "WarlockHudAssignmentsWindow" then item.TitleText = region() end
    return item
end
function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_Initialize() end
function UIDropDownMenu_SetText() end
function UIDropDownMenu_EnableDropDown() end
function UIDropDownMenu_DisableDropDown() end
C_Spell.GetSpellTexture = function(id) return id and "icon:" .. id end

WarlockHudOpenAssignments()
local window = ui.WarlockHudAssignmentsWindow
assert(window and profile.assignmentWindowCompact and window.width == 385
    and window.height == 135 + 3 * 38,
    "a saved personal assignment should open in compact mode")
window.toggle:OnClick()
assert(window.width == 635 and window.height == 420,
    "expanding should open the full window at its minimum size")
window:SetSize(760, 500)
window.resizeGrip:OnMouseUp()
assert(profile.assignmentWindowWidth == 760 and profile.assignmentWindowHeight == 500,
    "resized full dimensions should save")
window:Hide()
WarlockHudOpenAssignments()
assert(profile.assignmentWindowCompact and window.width == 385,
    "reopening with a personal assignment should return to compact mode")
window.toggle:OnClick()
window.toggle:OnClick()
assert(profile.assignmentWindowCompact and window.width == 385
    and window.height == 135 + 3 * 38,
    "compact window should fit three Warlocks")
assert(window.resizeGrip.shown == false and window.compactHeaders[1].shown,
    "compact view should show headers and hide the resize grip")
window.toggle:OnClick()
assert(not profile.assignmentWindowCompact and window.width == 760
    and window.height == 500,
    "expanding should restore full dimensions")
window.toggle:OnClick()
units.party2 = nil
event("GROUP_ROSTER_UPDATE")
assert(window.height == 135 + 2 * 38,
    "compact height should follow the current Warlock roster")

io.write("assignment smoke checks passed\n")
