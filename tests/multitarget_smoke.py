"""Run with: uv run --with lupa python tests/multitarget_smoke.py"""

from pathlib import Path
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
frames = {}
plates = {}
dead = {}
health = {}
maximum = {}
dots = {}
auraChecks = 0
trace = {}
WarlockHudTraceHUD = function(message) trace[#trace + 1] = message end
combat = false
profile = { multiDotEnabled = true, multiDotSize = 24 }
cursorX, cursorY = 500, 500
GetCursorPosition = function() return cursorX, cursorY end
WarlockHudAPI = {
    GetProfile = function() return profile end,
    InitializeProfiles = function() end,
    IsAddonEnabled = function() return true end,
}
UIParent = { GetWidth = function() return 1200 end,
    GetHeight = function() return 800 end,
    GetEffectiveScale = function() return 1 end }
InCombatLockdown = function() return combat end
C_Secrets = { ShouldAurasBeSecret = function() return false end }
issecretvalue = function(value) return value == 'SECRET' end
C_AddOns = { IsAddOnLoaded = function() return true end,
    LoadAddOn = function() return true end }
C_Spell = { GetSpellTexture = function() return 123 end }
CurveConstants = { ScaleTo100 = {} }
UnitHealth = function(unit) return health[unit] or 80 end
UnitHealthMax = function(unit) return maximum[unit] or 100 end
UnitHealthPercent = function(unit, predicted, curve)
    assert(curve == CurveConstants.ScaleTo100)
    return (health[unit] or 80) / (maximum[unit] or 100) * 100
end
C_UnitAuras = { GetAuraDataBySpellID = function(unit, id)
    auraChecks = auraChecks + 1
    if unit == 'nameplate5' and id == 172 then return 'SECRET' end
    if dots[unit] == id then return {} end
end }
UnitExists = function(unit) return unit == 'player' or plates[unit] ~= nil end
UnitIsDeadOrGhost = function(unit) return dead[unit] == true end
UnitName = function(unit) return plates[unit] end
UnitIsUnit = function(unit) return unit == 'nameplate2' end
UnitThreatSituation = function(member, unit)
    if member == 'player' and unit == 'nameplate5' then return 'SECRET' end
    if member == 'player' and unit == 'nameplate2' then return 0 end
end
GetRaidTargetIndex = function() return nil end
IsInRaid = function() return false end
IsInGroup = function() return false end
local methods = {}
setmetatable(methods, { __index = function()
    return function() end
end })
function methods:SetText(value) self.text = value end
function methods:SetFormattedText(pattern, ...)
    self.text = string.format(pattern, ...)
end
function methods:SetTextColor(...) self.textColor = {...} end
function methods:SetShown(value) self.shown = value end
function methods:SetColorTexture(...) self.color = {...} end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetHeight(h) self.height = h end
function methods:SetMinMaxValues(minimum, maximumValue)
    self.minimum, self.maximum = minimum, maximumValue
end
function methods:SetValue(value) self.value = value end
function methods:SetWidth(w) self.width = w end
function methods:GetSize() return self.width, self.height end
function methods:GetEffectiveScale() return 1 end
function methods:SetScale(value) self.scale = value end
function methods:GetFrameLevel() return 1 end
function methods:GetCenter() return 600, 400 end
function methods:SetAttribute(key, value) self.attributes[key] = value end
function methods:SetFrameRef(key, value) self.frameRefs = rawget(self, 'frameRefs') or {}; self.frameRefs[key] = value end
function methods:GetFrameRef(key) return self.frameRefs[key] end
function methods:Hide() self.shown = false end
function methods:SetDurationCooldown(value) self.cooldown = value end
function methods:SetScript(key, value) self.scripts[key] = value end
function methods:HookScript(key, value) self.scripts[key] = value end
function methods:RegisterForClicks(...) self.clicks = {...} end
function methods:EnableMouse(value) self.mouse = value end
function methods:IsShown() return self.shown end
function methods:CreateTexture() return CreateFrame('Texture', nil, self) end
function methods:CreateFontString() return CreateFrame('FontString', nil, self) end
function methods:AddAuraSlot(key, filter, options)
    self.slots[#self.slots + 1] = {key, filter, options}
    local aura = CreateFrame('AuraButton', nil, self)
    options.initializeFrame(aura)
end
function CreateFrame(kind, name, parent)
    local frame = setmetatable({kind=kind, parent=parent, attributes={},
        scripts={}, slots={}, children={}}, {__index=methods})
    if parent then
        parent.children = parent.children or {}
        parent.children[#parent.children + 1] = frame
    end
    if name then frames[name] = frame end
    if kind == 'Frame' and not parent then eventFrame = frame end
    return frame
end
RegisterStateDriver = function(button, state, condition)
    button.driver = {state, condition}
end
''')
lua.execute(Path("Warlock_Hud_MultiTarget.lua").read_text(encoding="utf-8"))
lua.execute(r'''
eventFrame.scripts.OnEvent(nil, 'PLAYER_LOGIN')
local root = frames.WarlockHudMultiTargetWindow
assert(root and root.shown == true)
assert(root.children[2].text == 'Multi-Target DoTs (view only)')
local status = root.children[3]
assert(status.text == 'No visible live targets')
local move = frames.WarlockHudMultiTargetMove
move.scripts.OnDragStart()
move.scripts.OnDragStop()
assert(profile.multiDotX == 0.5 and profile.multiDotY == 0.5)
local resize = frames.WarlockHudMultiTargetResize
resize.scripts.OnDragStart()
cursorX, cursorY = 550, 500
resize.scripts.OnUpdate()
assert(root.width > 430 and root.height == 316)
cursorY = 460
resize.scripts.OnUpdate()
resize.scripts.OnDragStop()
assert(root.width > 430 and root.height > 316)
assert(profile.multiDotWidth == root.width and profile.multiDotHeight == root.height)
local close = frames.WarlockHudMultiTargetClose
assert(close.frameRefs.window == root)
assert(close.attributes._onclick:find(':Hide()', 1, true))
for i = 1, 8 do
    assert(frames['WarlockHudMultiTarget' .. i] == nil)
    local display = root.children[7 + (i - 1)]
    assert(display.kind == 'Frame' and display.parent == root)
    local container = display.children[#display.children]
    assert(container.kind == 'AuraContainer' and #container.slots == 4)
    assert(container.slots[1][1] == 'Corruption')
    assert(container.slots[4][1] == 'Banes')
    for _, aura in ipairs(container.children) do
        assert(aura.cooldown and aura.cooldown.kind == 'Cooldown')
    end
end
plates.nameplate2 = 'First Mob'
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate2')
assert(status.text == 'Relevant: 1 / 1 visible (other rows dimmed)')
local display = root.children[7 + (2 - 1)]
local bar = display.children[3]
local name = display.children[4]
assert(name.text == 'First Mob (80/100) 80%')
assert(bar.kind == 'StatusBar' and bar.value == 80 and bar.maximum == 100)
health.nameplate2 = 45
maximum.nameplate2 = 150
eventFrame.scripts.OnEvent(nil, 'UNIT_HEALTH', 'nameplate2')
assert(name.text == 'First Mob (45/150) 30%')
assert(bar.value == 45 and bar.maximum == 150)
WarlockHudMultiTarget.Debug()
assert(trace[#trace]:find('nameplate2: relevant=true', 1, true))
plates.nameplate3 = 'Dotted Mob'
dots.nameplate3 = 172
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate3')
local dottedDisplay = root.children[7 + (3 - 1)]
assert(dottedDisplay.children[4].text == 'Dotted Mob (80/100) 80%')
plates.nameplate4 = 'Idle Mob'
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate4')
local idleDisplay = root.children[7 + (4 - 1)]
assert(idleDisplay.children[4].textColor[1] == 0.45)
assert(status.text == 'Relevant: 2 / 3 visible (other rows dimmed)')
plates.nameplate5 = 'Unreadable Mob'
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate5')
local unknownDisplay = root.children[7 + (5 - 1)]
assert(unknownDisplay.children[4].text == 'Unreadable Mob (80/100) 80%')
assert(status.text == 'Relevant: 2 / 4 visible (other rows dimmed)')
plates.nameplate2 = nil
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_REMOVED', 'nameplate2')
assert(name.text == '')
assert(bar.value == 0)
assert(status.text == 'Relevant: 1 / 3 visible (other rows dimmed)')
plates.nameplate2 = 'Second Mob'
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate2')
assert(name.text == 'Second Mob (45/150) 30%')
dead.nameplate2 = true
eventFrame.scripts.OnEvent(nil, 'UNIT_HEALTH', 'nameplate2')
assert(name.text == '' and status.text == 'Relevant: 1 / 3 visible (other rows dimmed)')
dead.nameplate2 = false
eventFrame.scripts.OnEvent(nil, 'UNIT_FLAGS', 'nameplate2')
assert(name.text == 'Second Mob (45/150) 30%')
combat = true
health.nameplate2 = 'SECRET'
eventFrame.scripts.OnEvent(nil, 'UNIT_HEALTH', 'nameplate2')
assert(name.text == 'Second Mob')
health.nameplate2 = 45
local previousChecks = auraChecks
eventFrame.scripts.OnEvent(nil, 'UNIT_AURA', 'nameplate4')
assert(auraChecks == previousChecks)
loadstring('return function(self) ' .. close.attributes._onclick .. ' end')()(close)
assert(root.shown == false)
close.scripts.OnClick()
assert(profile.multiDotEnabled == false)
assert(WarlockHudMultiTarget.Refresh() == false)
assert(root.shown == false)
combat = false
eventFrame.scripts.OnEvent(nil, 'PLAYER_REGEN_ENABLED')
assert(root.shown == false)
profile.multiDotEnabled = true
assert(WarlockHudMultiTarget.Refresh() == true)
close.scripts.OnClick()
assert(profile.multiDotEnabled == false)
''')

deferred = LuaRuntime(unpack_returned_tuples=True)
deferred.execute(r'''
WarlockHudAPI = { GetProfile = function() return { multiDotEnabled = true } end,
    InitializeProfiles = function() end, IsAddonEnabled = function() return true end }
combat = true
InCombatLockdown = function() return combat end
C_Secrets = { ShouldAurasBeSecret = function() return false end }
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function(self, _, fn) self.event = fn end }
end
''')
deferred.execute(Path("Warlock_Hud_MultiTarget.lua").read_text(encoding="utf-8"))
deferred.execute("assert(WarlockHudMultiTarget.Refresh() == false)")
print("Multi-target fixed-token smoke tests OK")
