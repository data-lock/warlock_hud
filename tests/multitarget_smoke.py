"""Run with: uv run --with lupa python tests/multitarget_smoke.py"""

from pathlib import Path
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
frames = {}
plates = {}
combat = false
profile = { multiDotEnabled = true, multiDotSize = 24 }
cursor = 500
GetCursorPosition = function() return cursor, 0 end
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
UnitExists = function(unit) return plates[unit] ~= nil end
UnitName = function(unit) return plates[unit] end
UnitIsUnit = function(unit) return unit == 'nameplate2' end
UnitThreatSituation = function(member, unit)
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
function methods:SetShown(value) self.shown = value end
function methods:SetColorTexture(...) self.color = {...} end
function methods:SetSize(w, h) self.width, self.height = w, h end
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
local status = root.children[3]
assert(status.text:find('Waiting for enemy nameplates', 1, true))
local move = frames.WarlockHudMultiTargetMove
move.scripts.OnDragStart()
move.scripts.OnDragStop()
assert(profile.multiDotX == 0.5 and profile.multiDotY == 0.5)
local resize = frames.WarlockHudMultiTargetResize
resize.scripts.OnDragStart()
cursor = 550
resize.scripts.OnUpdate()
resize.scripts.OnDragStop()
assert(root.scale > 1 and profile.multiDotScale == root.scale)
local close = frames.WarlockHudMultiTargetClose
assert(close.frameRefs.window == root)
assert(close.attributes._onclick:find(':Hide()', 1, true))
for i = 1, 8 do
    local row = frames['WarlockHudMultiTarget' .. i]
    assert(row.attributes.type1 == 'target')
    assert(row.attributes.unit == 'nameplate' .. i)
    assert(row.driver[2]:find('nameplate' .. i, 1, true))
    assert(row.parent == root)
    local display = row.parent.children[7 + (i - 1) * 2]
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
assert(status.text == 'Visible nameplate tokens: 1 / 8')
local second = frames.WarlockHudMultiTarget2
local display = second.parent.children[7 + (2 - 1) * 2]
local name = display.children[3]
assert(name.text == 'First Mob')
assert(second.attributes.unit == 'nameplate2')
assert(second.attributes.type1 == 'target')
plates.nameplate2 = nil
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_REMOVED', 'nameplate2')
assert(name.text == 'nameplate2 (waiting)')
assert(status.text:find('Waiting for enemy nameplates', 1, true))
assert(second.attributes.unit == 'nameplate2')
plates.nameplate2 = 'Second Mob'
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate2')
assert(name.text == 'Second Mob')
assert(second.attributes.unit == 'nameplate2')
combat = true
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
