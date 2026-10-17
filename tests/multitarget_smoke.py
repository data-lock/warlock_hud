"""Run with: uv run --with lupa python tests/multitarget_smoke.py"""

from pathlib import Path
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
frames = {}
topFrames = {}
plates = {}
mobTargets = {}
dead = {}
health = {}
maximum = {}
dots = {}
auraChecks = 0
trace = {}
WarlockHudTraceHUD = function(message) trace[#trace + 1] = message end
traceOpened = false
WarlockHudOpenDebugTrace = function() traceOpened = true end
chat = {}
print = function(message) chat[#chat + 1] = message end
combat = false
profile = { multiDotEnabled = true, multiDotSize = 24,
    dotTimerMilliseconds = true,
    enabled = { executeMarker = true },
    mainOrder = {'immolate', 'corruption', 'bane', 'curse', 'drain', 'siphonlife', 'demonicbrand'} }
brandKnown = false
WarlockHudRowVisibility = { KnowsDemonicBrand = function() return brandKnown end }
cursorX, cursorY = 500, 500
GetCursorPosition = function() return cursorX, cursorY end
WarlockHudAPI = {
    MainKeys = {'corruption', 'bane', 'curse', 'drain', 'immolate', 'siphonlife', 'demonicbrand'},
    Spells = {
        {name='Corruption', slot=1, ids={172}},
        {name='Bane of Agony', slot=2, ids={980}},
        {name='Curse of Weakness', slot=3, ids={702}},
        {name='Drain Life', slot=4, ids={689}},
        {name='Immolate', slot=5, ids={348}},
        {name='Siphon Life', slot=6, ids={18265}},
        {name='Demonic Brand', slot=7, ids={1293696}, talentEffect=true},
    },
    GetDotDefaultSpell = function() return nil end,
    GetMultiTargetEffectOrder = function()
        local keys = {}
        for _, key in ipairs(profile.mainOrder) do
            if key == 'demonicbrand' then
                if brandKnown and profile.enabled['Demonic Brand'] ~= false
                    and profile.enabled.demonicbrand ~= false then
                    keys[#keys + 1] = key
                end
            elseif profile.enabled[key] ~= false then
                keys[#keys + 1] = key
            end
        end
        return keys
    end,
    GetProfile = function() return profile end,
    InitializeProfiles = function() end,
    IsAddonEnabled = function() return true end,
}
WarlockHudEffects = { Spells = WarlockHudAPI.Spells }
GetTime = function() return 0 end
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
UnitExists = function(unit)
    return unit == 'player' or plates[unit] ~= nil or mobTargets[unit] ~= nil
end
UnitCanAttack = function(player, unit) return player == 'player' and UnitExists(unit) end
UnitIsDeadOrGhost = function(unit) return dead[unit] == true end
UnitName = function(unit) return plates[unit] end
targetUnit = 'nameplate2'
UnitIsUnit = function(unit, other)
    if mobTargets[unit] then return mobTargets[unit] == other end
    if other == 'target' then return unit == targetUnit end
    if unit == 'target' then return other == targetUnit end
    return unit == other
end
UnitThreatSituation = function(member, unit)
    if member == 'player' and unit == 'nameplate5' then return 'SECRET' end
    if member == 'player' and unit == 'nameplate2' then return 0 end
end
raidMarkers = {}
GetRaidTargetIndex = function(unit) return raidMarkers[unit] end
SetRaidTargetIconTexture = function(texture, index)
    if index == 'SECRET' then texture:SetTexCoord(0.25, 0.5, 0, 0.25) end
end
guids = {}
UnitGUID = function(unit) return guids[unit] end
portraitCalls = 0
SetPortraitTexture = function(texture, unit)
    portraitCalls = portraitCalls + 1
    texture.portraitUnit = unit
    texture.texture = 'portrait:' .. unit
end
raiding = false
IsInRaid = function() return raiding end
grouped = false
IsInGroup = function() return grouped end
local methods = {}
setmetatable(methods, { __index = function()
    return function() end
end })
function methods:SetText(value) self.text = value end
function methods:SetFormattedText(pattern, ...)
    self.text = string.format(pattern, ...)
end
function methods:SetTextColor(...) self.textColor = {...} end
function methods:SetFont(path, size, flags) self.font = {path, size, flags} end
function methods:SetCountdownFont(value) self.countdownFont = value end
function methods:SetCountdownMillisecondsThreshold(value) self.millisecondsThreshold = value end
function methods:GetCountdownFontString()
    if not rawget(self, 'countdownText') then
        self.countdownText = CreateFrame('FontString', nil, self)
    end
    return self.countdownText
end
function methods:SetApplicationCount(value) self.applicationCount = value end
function methods:SetShown(value) self.shown = value end
function methods:SetColorTexture(...) self.color = {...} end
function methods:SetStatusBarTexture(texture)
    self.statusBarTexture = { source = texture }
end
function methods:GetStatusBarTexture() return self.statusBarTexture end
function methods:SetTexture(value)
    self.texture = value
    if value == nil then self.portraitUnit = nil end
end
function methods:GetTexture() return rawget(self, 'texture') end
function methods:SetTexCoord(...) self.texCoord = {...} end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetHeight(h) self.height = h end
function methods:SetMinMaxValues(minimum, maximumValue)
    self.minimum, self.maximum = minimum, maximumValue
end
function methods:SetValue(value)
    self.value = value
    if self.kind == 'Slider' and self.scripts.OnValueChanged then
        self.scripts.OnValueChanged(self, value)
    end
end
function methods:GetValue() return rawget(self, 'value') or 0 end
function methods:SetScrollChild(child) self.scrollChild = child end
function methods:SetVerticalScroll(value) self.scrollOffset = value end
function methods:SetWidth(w) self.width = w end
function methods:SetAlpha(value) self.alpha = value end
function methods:ClearAllPoints() self.point = nil end
function methods:SetPoint(...) self.point = {...} end
function methods:GetSize() return self.width, self.height end
function methods:GetWidth() return self.width end
function methods:GetEffectiveScale() return 1 end
function methods:SetScale(value) self.scale = value end
function methods:GetFrameLevel() return 1 end
function methods:IsProtected() return rawget(self, 'protected') == true end
function methods:GetCenter() return 600, 400 end
function methods:GetLeft() return self.point and self.point[4] end
function methods:GetTop() return self.point and self.point[5] end
function methods:SetAttribute(key, value) self.attributes[key] = value end
function methods:SetFrameRef(key, value) self.frameRefs = rawget(self, 'frameRefs') or {}; self.frameRefs[key] = value end
function methods:GetFrameRef(key) return self.frameRefs[key] end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
function methods:SetDurationCooldown(value) self.cooldown = value end
function methods:SetScript(key, value) self.scripts[key] = value end
function methods:RegisterEvent(event)
    self.registered = rawget(self, 'registered') or {}
    self.registered[event] = true
end
function methods:RegisterUnitEvent(event)
    self:RegisterEvent(event)
end
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
function methods:UpdateAllAuras()
    self.auraRefreshes = (rawget(self, 'auraRefreshes') or 0) + 1
end
function CreateFrame(kind, name, parent)
    local frame = setmetatable({kind=kind, parent=parent, attributes={},
        scripts={}, slots={}, children={}}, {__index=methods})
    if parent then
        parent.children = parent.children or {}
        parent.children[#parent.children + 1] = frame
    end
    if name then frames[name] = frame end
    if kind == 'Frame' and not parent then
        eventFrame = frame
        topFrames[#topFrames + 1] = frame
    end
    return frame
end
CreateFont = function(name) return CreateFrame('Font', name) end
RegisterStateDriver = function(button, state, condition)
    button.driver = {state, condition}
    if state == 'mtdvisibility' then button.frameRefs.window:SetShown(combat) end
end
UnregisterStateDriver = function(button, state)
    if state == 'mtdvisibility' then button.driver = nil end
end
''')
lua.execute(Path("Warlock_Hud_MultiTargetIdentity.lua").read_text(encoding="utf-8"))
lua.execute(Path("Warlock_Hud_MultiTargetLayout.lua").read_text(encoding="utf-8"))
lua.execute(Path("Warlock_Hud_MultiTargetAuras.lua").read_text(encoding="utf-8"))
lua.execute(Path("Warlock_Hud_MultiTargetProbe.lua").read_text(encoding="utf-8"))
lua.execute(Path("Warlock_Hud_MultiTargetDamage.lua").read_text(encoding="utf-8"))
lua.execute(Path("Warlock_Hud_MultiTarget.lua").read_text(encoding="utf-8"))
lua.execute(r'''
eventFrame.scripts.OnEvent(nil, 'PLAYER_LOGIN')
local root = frames.WarlockHudMultiTargetWindow
assert(root and root.shown == true, table.concat(chat, '; '))
local viewport = frames.WarlockHudMultiTargetScroll
local scroll = frames.WarlockHudMultiTargetScrollBar
local function Display(i) return viewport.scrollChild.children[i] end
assert(root.children[2].text == 'Multi-Target DoTs (view only)')
local status = root.children[3]
assert(status.text == 'No engaged or dotted targets')
local move = frames.WarlockHudMultiTargetMove
move.scripts.OnDragStart()
move.scripts.OnDragStop()
assert(profile.multiDotX == 0.5 and profile.multiDotY == 0.5)
local resize = frames.WarlockHudMultiTargetResize
resize.scripts.OnDragStart()
cursorX, cursorY = 550, 500
resize.scripts.OnUpdate()
assert(root.width > 430 and root.height == 548)
cursorY = 460
resize.scripts.OnUpdate()
resize.scripts.OnDragStop()
assert(root.width > 430 and root.height > 548)
assert(profile.multiDotWidth == root.width and profile.multiDotHeight == root.height)
assert(root.point[1] == 'TOPLEFT')
local left, top = root.point[4], root.point[5]
combat = true
local beforeWidth, beforeHeight = root:GetSize()
resize.scripts.OnDragStart()
cursorX, cursorY = cursorX + 30, cursorY - 30
resize.scripts.OnUpdate()
resize.scripts.OnDragStop()
assert(profile.multiDotWidth == root.width and profile.multiDotHeight == root.height)
assert(root.width == beforeWidth and root.height == beforeHeight)
assert(root.point[4] == left and root.point[5] == top)
move.scripts.OnDragStart()
cursorX, cursorY = cursorX + 40, cursorY - 20
move.scripts.OnDragStop()
assert(root.point[4] == left and root.point[5] == top)
combat = false
local close = frames.WarlockHudMultiTargetClose
assert(close.scripts.OnClick)
for i = 1, 16 do
    assert(frames['WarlockHudMultiTarget' .. i] == nil)
    local display = Display(i)
    assert(display.kind == 'Frame' and display.parent == viewport.scrollChild)
    assert(display.alpha == 0)
    local container
    for _, child in ipairs(display.children) do
        if child.kind == 'Frame' then
            for _, grandchild in ipairs(child.children) do
                if grandchild.kind == 'AuraContainer' then
                    container = grandchild
                end
            end
        end
    end
    assert(container and #container.slots == 6)
    assert(container.slots[1][1] == 'Corruption')
    assert(container.slots[4][1] == 'Drain Life')
    for _, aura in ipairs(container.children) do
        assert(aura.cooldown and aura.cooldown.kind == 'Cooldown')
        assert(aura.cooldown.countdownFont == 'WarlockHudMultiDotCountdownFont')
        assert(aura.cooldown.millisecondsThreshold == 10)
    end
end
assert(frames.WarlockHudMultiDotCountdownFont.font[2] == 10)
local firstDisplay = Display(1)
local firstContainer
for _, child in ipairs(firstDisplay.children[15].children) do
    if child.kind == 'AuraContainer' then firstContainer = child end
end
assert(firstContainer.children[1].point[4] == 15 + 27) -- Corruption follows Immolate
assert(firstDisplay.width + firstContainer.children[6].point[4] + 24
    == root.width - 26) -- rightmost DoT stays inside the scroll viewport
profile.mainOrder = {'corruption', 'immolate', 'bane', 'curse', 'drain', 'siphonlife', 'demonicbrand'}
assert(WarlockHudMultiTarget.Refresh() == true)
assert(firstContainer.children[1].point[4] == 15)
plates.nameplate2 = 'First Mob'
raidMarkers.nameplate2 = 8
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate2')
assert(status.text == '1 engaged or dotted target')
local display = Display(2)
assert(display.children[13].text == 'LOW')
local fullNameWidth = display.children[12].width
profile.multiDotThreatIndicator = false
WarlockHudMultiTarget.UpdateAppearance()
assert(display.children[13].shown == false and display.children[14].shown == false)
assert(display.children[12].width > fullNameWidth)
profile.multiDotThreatIndicator = true
WarlockHudMultiTarget.UpdateAppearance()
assert(display.children[13].shown == true and display.children[14].shown == true)
assert(display.point[5] == 0)
assert(display.alpha == 1)
assert(display.children[15].alpha == 1)
assert(display.children[1].color[1] < 0.1) -- row stays dark when selected
assert(display.children[16].color[4] == 0.95) -- narrow selection accent
assert(display.children[16].width == 4 and display.children[16].height == 29)
local portrait = display.children[2]
assert(portrait.point[4] == 8)
local warning = display.children[3]
local cover = display.children[4]
local marker = cover.children[1]
assert(warning.portraitUnit == 'nameplate2')
assert(cover.statusBarTexture.portraitUnit == 'nameplate2')
assert(portrait.portraitUnit == 'nameplate2')
assert(marker.shown == true and marker.texCoord[1] == 0.75)
local firstPortraitCalls = portraitCalls
raidMarkers.nameplate2 = 1
eventFrame.scripts.OnEvent(nil, 'RAID_TARGET_UPDATE')
assert(marker.shown == true and marker.texCoord[1] == 0)
raidMarkers.nameplate2 = nil
guids.nameplate2 = 'Creature-test-2'
raidMarkers['Creature-test-2'] = 8
eventFrame.scripts.OnEvent(nil, 'RAID_TARGET_UPDATE')
assert(marker.shown == true and marker.texCoord[1] == 0.75)
raidMarkers['Creature-test-2'] = nil
guids.nameplate2 = nil
raidMarkers.nameplate2 = 'SECRET'
eventFrame.scripts.OnEvent(nil, 'RAID_TARGET_UPDATE')
assert(marker.shown == true and marker.texCoord[1] == 0.25)
assert(WarlockHudMultiTarget.ProbeRunning() == false)
raidMarkers.nameplate2 = 1
assert(portraitCalls == firstPortraitCalls) -- routine updates keep the portrait
eventFrame.scripts.OnEvent(nil, 'UNIT_PORTRAIT_UPDATE', 'nameplate2')
assert(portraitCalls == firstPortraitCalls + 3)
firstPortraitCalls = portraitCalls
local bar = display.children[5]
assert(bar.point[4] == 7) -- HP bar reaches into the gap before the icons
local name = display.children[12]
local tickOutline, tick = display.children[6].children[1],
    display.children[6].children[2]
local healthEdge, damageEdge = display.children[6].children[3],
    display.children[6].children[4]
local healthText = display.children[7]
assert(healthText.point[2] == bar and healthText.point[3] == 'TOPRIGHT'
    and healthText.point[4] == 0)
assert(name.text == 'First Mob')
assert(bar.children[1].color[1] < 0.1) -- depleted bar track is dark
assert(tickOutline.width == 4 and tickOutline.height == 15)
assert(tick.width == 2 and tick.height == 15)
assert(healthEdge.point[2] == bar.statusBarTexture)
assert(damageEdge.point[2] == display.children[11].statusBarTexture)
for i = 9, 11 do
    assert(display.children[i].point[2]
        == display.children[i - 1].statusBarTexture)
    assert(display.children[i].width == display.width - 37)
end
assert(damageEdge.alpha == 0)
assert(tick.point[4] == (display.width - 37) * 0.2)
assert(tick.color[1] == 0.78 and tick.shown == true)
profile.enabled.executeMarker = false
assert(WarlockHudMultiTarget.Refresh() == true)
assert(tick.shown == false and tickOutline.shown == false)
profile.enabled.executeMarker = true
assert(WarlockHudMultiTarget.Refresh() == true)
assert(tick.shown == true and tickOutline.shown == true)
assert(healthText.text == '80 80%')
assert(bar.kind == 'StatusBar' and bar.value == 80 and bar.maximum == 100)
assert(WarlockHudMultiTarget.DamageDebugRunning() == true)
WarlockHudMultiTarget.ToggleDamageDebug()
assert(status.text == '1 engaged or dotted target')
assert(healthText.text == '80 80%')
WarlockHudMultiTarget.ToggleDamageDebug()
assert(healthText.text == '80 80%')
assert(trace[#trace]:find('health=80/100', 1, true))
assert(trace[#trace]:find('total 0.0%', 1, true))
chat = {}
health.nameplate2 = 45
maximum.nameplate2 = 150
eventFrame.scripts.OnEvent(nil, 'UNIT_HEALTH', 'nameplate2')
assert(name.text == 'First Mob')
assert(healthText.text == '45 30%')
assert(bar.value == 45 and bar.maximum == 150)
assert(portraitCalls == firstPortraitCalls)
WarlockHudMultiTarget.Debug()
assert(trace[#trace]:find('nameplate2 = First Mob; relevant=true', 1, true))
WarlockHudMultiTarget.PrintTargets()
assert(traceOpened and trace[#trace]:find('Multi-Target: nameplate2 = First Mob; GUID=', 1, true))
assert(trace[#trace]:find('; direct marker=', 1, true))
assert(#chat == 0)
WarlockHudMultiTarget.Probe('on')
assert(WarlockHudMultiTarget.ProbeRunning() == true)
assert(trace[#trace]:find('hostile tokens currently resolved', 1, true))
WarlockHudMultiTarget.Probe('off')
assert(WarlockHudMultiTarget.ProbeRunning() == false)
plates.nameplate3 = 'Dotted Mob'
dots.nameplate3 = 172
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate3')
local dottedDisplay = Display(3)
local rowStep = 29
assert(dottedDisplay.point[5] == -rowStep)
assert(dottedDisplay.children[12].text == 'Dotted Mob')
assert(status.text == '2 engaged or dotted targets')
plates.nameplate4 = 'Idle Mob'
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate4')
local idleDisplay = Display(4)
assert(idleDisplay.alpha == 0 and idleDisplay.children[12].text == '')
targetUnit = 'nameplate4'
eventFrame.scripts.OnEvent(nil, 'PLAYER_TARGET_CHANGED')
assert(idleDisplay.alpha == 0) -- selecting an idle mob is not combat evidence
targetUnit = 'nameplate2'
eventFrame.scripts.OnEvent(nil, 'PLAYER_TARGET_CHANGED')
assert(status.text == '2 engaged or dotted targets')
mobTargets.nameplate4target = 'player'
eventFrame.scripts.OnEvent(nil, 'UNIT_TARGET', 'nameplate4')
assert(idleDisplay.alpha == 1)
mobTargets.nameplate4target = nil
eventFrame.scripts.OnEvent(nil, 'UNIT_TARGET', 'nameplate4')
assert(idleDisplay.alpha == 0)
grouped = true
mobTargets.party1target = 'nameplate4'
guids.nameplate4 = 'Creature-group-test'
guids.party1target = 'Creature-group-test'
eventFrame.scripts.OnEvent(nil, 'UNIT_TARGET', 'party1')
assert(idleDisplay.alpha == 1)
local partyDisplay = Display(18)
assert(partyDisplay.alpha == 0) -- nameplate copy wins the GUID dedupe
guids.party1target = nil
guids.nameplate4 = nil
mobTargets.party1target = nil
grouped = false
eventFrame.scripts.OnEvent(nil, 'UNIT_TARGET', 'party1')
assert(idleDisplay.alpha == 0)
plates.party1target = 'Group-only Mob'
guids.party1target = 'Creature-party-only'
grouped = true
eventFrame.scripts.OnEvent(nil, 'UNIT_TARGET', 'party1')
assert(partyDisplay.alpha == 1)
assert(partyDisplay.children[12].text == 'Group-only Mob')
plates.party1target = nil
guids.party1target = nil
grouped = false
eventFrame.scripts.OnEvent(nil, 'GROUP_ROSTER_UPDATE')
assert(partyDisplay.alpha == 0)
plates.target = 'Player-only target'
dots.target = 172
targetUnit = 'target'
eventFrame.scripts.OnEvent(nil, 'PLAYER_TARGET_CHANGED')
assert(Display(17).alpha == 1)
plates.target = nil
dots.target = nil
targetUnit = 'nameplate2'
eventFrame.scripts.OnEvent(nil, 'PLAYER_TARGET_CHANGED')
assert(Display(17).alpha == 0)
plates.party4target = 'Fifth member target'
grouped = true
eventFrame.scripts.OnEvent(nil, 'UNIT_TARGET', 'party4')
assert(Display(21).alpha == 1)
plates.party4target = nil
grouped = false
eventFrame.scripts.OnEvent(nil, 'GROUP_ROSTER_UPDATE')
plates.raid40target = 'Last raid member target'
raiding = true
eventFrame.scripts.OnEvent(nil, 'UNIT_TARGET', 'raid40')
assert(Display(61).alpha == 1)
plates.raid40target = nil
raiding = false
eventFrame.scripts.OnEvent(nil, 'GROUP_ROSTER_UPDATE')
-- A DoT makes an otherwise idle row visible, and clearing it hides the row.
dots.nameplate4 = 172
eventFrame.scripts.OnEvent(nil, 'UNIT_AURA', 'nameplate4')
assert(idleDisplay.alpha == 1 and idleDisplay.point[5] == -2 * rowStep)
assert(status.text == '3 engaged or dotted targets')
dots.nameplate4 = nil
eventFrame.scripts.OnEvent(nil, 'UNIT_AURA', 'nameplate4')
assert(idleDisplay.alpha == 0 and idleDisplay.children[12].text == '')
assert(status.text == '2 engaged or dotted targets')
plates.nameplate5 = 'Unreadable Mob'
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate5')
local unknownDisplay = Display(5)
assert(unknownDisplay.alpha == 0 and unknownDisplay.children[12].text == '')
assert(status.text == '2 engaged or dotted targets')
plates.nameplate2 = nil
local reusedContainer
for _, child in ipairs(display.children[15].children) do
    if child.kind == 'AuraContainer' then reusedContainer = child end
end
assert(reusedContainer)
local refreshesBeforeReuse = rawget(reusedContainer, 'auraRefreshes') or 0
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_REMOVED', 'nameplate2')
assert((rawget(reusedContainer, 'auraRefreshes') or 0) == refreshesBeforeReuse + 1)
assert(name.text == '')
assert(display.alpha == 0)
assert(rawget(portrait, 'portraitUnit') == nil and marker.shown == false)
assert(bar.value == 0)
assert(healthText.text == '')
assert(status.text == '1 engaged or dotted target')
assert(dottedDisplay.point[5] == 0)
plates.nameplate2 = 'Second Mob'
raidMarkers.nameplate2 = nil
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate2')
assert((rawget(reusedContainer, 'auraRefreshes') or 0) == refreshesBeforeReuse + 2)
assert(name.text == 'Second Mob' and healthText.text == '45 30%')
assert(portrait.portraitUnit == 'nameplate2' and marker.shown == false)
assert(portraitCalls > firstPortraitCalls)
dead.nameplate2 = true
eventFrame.scripts.OnEvent(nil, 'UNIT_HEALTH', 'nameplate2')
assert(name.text == '' and status.text == '1 engaged or dotted target')
assert(dottedDisplay.point[5] == 0) -- surviving rows compact after death
dead.nameplate2 = false
eventFrame.scripts.OnEvent(nil, 'UNIT_FLAGS', 'nameplate2')
assert(name.text == 'Second Mob' and healthText.text == '45 30%')
assert(dottedDisplay.point[5] == -rowStep)
combat = true
local dottedPosition = dottedDisplay.point[5]
eventFrame.scripts.OnEvent(nil, 'UNIT_AURA', 'nameplate3')
assert(dottedDisplay.alpha == 1) -- keep a previously confirmed DoT row
dead.nameplate2 = true
eventFrame.scripts.OnEvent(nil, 'UNIT_HEALTH', 'nameplate2')
assert(display.alpha == 0 and dottedDisplay.point[5] == 0)
dead.nameplate2 = false
eventFrame.scripts.OnEvent(nil, 'UNIT_FLAGS', 'nameplate2')
assert(dottedDisplay.point[5] == dottedPosition)
plates.nameplate2 = nil
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_REMOVED', 'nameplate2')
assert(name.text == '' and dottedDisplay.point[5] == 0)
plates.nameplate2 = 'Second Mob'
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate2')
assert(dottedDisplay.point[5] == dottedPosition)
health.nameplate2 = 'SECRET'
eventFrame.scripts.OnEvent(nil, 'UNIT_HEALTH', 'nameplate2')
assert(name.text == 'Second Mob')
assert(healthText.text == '')
health.nameplate2 = 45
local previousChecks = auraChecks
eventFrame.scripts.OnEvent(nil, 'UNIT_AURA', 'nameplate4')
assert(auraChecks == previousChecks)
assert(WarlockHudMultiTarget.Toggle() == false)
assert(profile.multiDotEnabled == true and root.shown == true)
close.scripts.OnClick()
assert(profile.multiDotEnabled == true and root.shown == true)
combat = false
close.scripts.OnClick()
assert(profile.multiDotEnabled == false)
WarlockHudMultiTarget.Refresh()
assert(root.shown == false)
eventFrame.scripts.OnEvent(nil, 'PLAYER_REGEN_ENABLED')
assert(root.shown == false)
assert(dottedDisplay.alpha == 1) -- safely rechecked after combat
profile.multiDotEnabled = true
assert(WarlockHudMultiTarget.Refresh() == true)
mobTargets.nameplate5target = 'player' -- its DoT probe is intentionally restricted
for i = 1, 16 do
    local unit = 'nameplate' .. i
    plates[unit] = 'Mob ' .. i
    dots[unit] = 172
    eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', unit)
end
assert(status.text == '16 engaged or dotted targets')
assert(Display(16).alpha == 1) -- nameplate16 is the last visible row
plates.target = 'Overflow target'
dots.target = 172
targetUnit = 'target'
eventFrame.scripts.OnEvent(nil, 'PLAYER_TARGET_CHANGED')
assert(Display(17).alpha == 0) -- seventeenth candidate waits
plates.nameplate1 = nil
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_REMOVED', 'nameplate1')
assert(Display(17).alpha == 1)
assert(status.text == '16 engaged or dotted targets')
local priorWidth = root.width
resize.scripts.OnDragStart()
cursorY = cursorY + 1000
resize.scripts.OnUpdate()
resize.scripts.OnDragStop()
assert(root.height == 150 and viewport.height == 93)
assert(root.width == priorWidth)
assert(profile.multiDotHeight == 150)
assert(scroll.shown == true and scroll.maximum == 16 * 29 - 93)
combat = true
scroll:SetValue(58)
assert(viewport.scrollOffset == 58)
for i = 2, 16 do
    local unit = 'nameplate' .. i
    plates[unit] = nil
    eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_REMOVED', unit)
end
assert(scroll.shown == false and viewport.scrollOffset == 0)
combat = false
assert(WarlockHudMultiTarget.Toggle() == true)
assert(profile.multiDotEnabled == false and root.shown == false)
assert(WarlockHudMultiTarget.Toggle() == true)
assert(profile.multiDotEnabled == true and root.shown == true)
profile.multiDotAlpha = 0.6
profile.multiDotHideOutOfCombat = true
assert(WarlockHudMultiTarget.UpdateAppearance() == true)
assert(root.alpha == 0.6 and root.shown == false)
assert(rawget(root, 'driver') == nil) -- the driver must not protect the resizable window
combat = true
root:SetShown(true) -- the client applies the secure visibility driver
eventFrame.scripts.OnEvent(nil, 'PLAYER_REGEN_DISABLED')
assert(root.shown == true)
combat = false
root:SetShown(false)
eventFrame.scripts.OnEvent(nil, 'PLAYER_REGEN_ENABLED')
assert(root.shown == false)
close.scripts.OnClick()
assert(profile.multiDotEnabled == false)
profile.multiDotEnabled = true
profile.multiDotHideOutOfCombat = false
brandKnown = true
assert(WarlockHudMultiTarget.Refresh() == true)
assert(root.shown == false) -- retired window and its native slots are hidden
local function LatestWindow()
    local foundRoot, foundViewport
    for _, child in ipairs(UIParent.children) do
        for _, descendant in ipairs(child.children or {}) do
            if descendant.kind == 'ScrollFrame' then
                foundRoot, foundViewport = child, descendant
            end
        end
    end
    return foundRoot, foundViewport
end
local brandedRoot, brandedViewport = LatestWindow()
assert(brandedRoot and brandedViewport)
local brandedDisplay = brandedViewport.scrollChild.children[1]
local brandedContainer
for _, child in ipairs(brandedDisplay.children[15].children) do
    if child.kind == 'AuraContainer' then brandedContainer = child end
end
assert(brandedContainer and #brandedContainer.slots == 7)
local brandButton
for index, slot in ipairs(brandedContainer.slots) do
    if slot[1] == 'Demonic Brand' then brandButton = brandedContainer.children[index] end
end
assert(brandButton and brandButton.applicationCount)
assert(brandButton.applicationCount.point[1] == 'TOPLEFT')
assert(brandButton.cooldown.millisecondsThreshold == 10)
assert(brandButton.cooldown.countdownText.point[1] == 'CENTER')
assert(brandButton.cooldown.countdownText.point[4] == 3)
assert(brandedDisplay.width + 8 + 6 * 27 + 24 <= brandedViewport.width,
    tostring(brandedDisplay.width) .. ' / ' .. tostring(brandedViewport.width))
plates.nameplate3 = 'Other Branded Mob'
dots.nameplate3 = 172
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate3')
plates.nameplate2 = 'Branded Mob'
dots.nameplate2 = 172
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate2')
local brandedSecond = brandedViewport.scrollChild.children[2]
local brandedThird = brandedViewport.scrollChild.children[3]
assert(brandedSecond.alpha == 1 and brandedSecond.children[12].text == 'Branded Mob')
assert(brandedThird.point[5] == -29)
plates.nameplate2 = nil
dots.nameplate2 = nil
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_REMOVED', 'nameplate2')
assert(brandedSecond.alpha == 0 and brandedSecond.children[12].text == '')
assert(brandedThird.point[5] == 0)
table.insert(WarlockHudAPI.MainKeys, 'extra')
table.insert(WarlockHudAPI.Spells, {name='Extra Effect', slot=8, ids={123456}})
table.insert(profile.mainOrder, 'extra')
assert(WarlockHudMultiTarget.Refresh() == true)
local expandedRoot, expandedViewport = LatestWindow()
assert(expandedRoot ~= brandedRoot)
local expandedDisplay = expandedViewport.scrollChild.children[1]
local expandedContainer
for _, child in ipairs(expandedDisplay.children[15].children) do
    if child.kind == 'AuraContainer' then expandedContainer = child end
end
assert(expandedContainer and #expandedContainer.slots == 8)
assert(expandedDisplay.width + 8 + 7 * 27 + 24 <= expandedViewport.width)
profile.enabled.immolate = false
profile.enabled.curse = false
profile.enabled.drain = false
assert(WarlockHudMultiTarget.Refresh() == true)
local compactRoot, compactViewport = LatestWindow()
assert(compactRoot ~= expandedRoot)
local compactDisplay = compactViewport.scrollChild.children[1]
local compactContainer
for _, child in ipairs(compactDisplay.children[15].children) do
    if child.kind == 'AuraContainer' then compactContainer = child end
end
assert(compactContainer and #compactContainer.slots == 5)
assert(compactDisplay.width + 8 + 4 * 27 + 24 <= compactViewport.width)
profile.enabled['Demonic Brand'] = false
assert(WarlockHudMultiTarget.Refresh() == true)
local noBrandRoot, noBrandViewport = LatestWindow()
assert(noBrandRoot ~= compactRoot)
local noBrandContainer
for _, child in ipairs(noBrandViewport.scrollChild.children[1].children[15].children) do
    if child.kind == 'AuraContainer' then noBrandContainer = child end
end
assert(noBrandContainer and #noBrandContainer.slots == 4)
profile.enabled['Demonic Brand'] = nil
profile.enabled.demonicbrand = false
assert(WarlockHudMultiTarget.Refresh() == true)
local noBrandRowRoot, noBrandRowViewport = LatestWindow()
assert(noBrandRowRoot == noBrandRoot)
local noBrandRowContainer
for _, child in ipairs(noBrandRowViewport.scrollChild.children[1].children[15].children) do
    if child.kind == 'AuraContainer' then noBrandRowContainer = child end
end
assert(noBrandRowContainer and #noBrandRowContainer.slots == 4)
profile.dotTimerMilliseconds = false
assert(WarlockHudMultiTarget.Refresh() == true)
local secondsRoot, secondsViewport = LatestWindow()
assert(secondsRoot ~= noBrandRowRoot)
local secondsContainer
for _, child in ipairs(secondsViewport.scrollChild.children[1].children[15].children) do
    if child.kind == 'AuraContainer' then secondsContainer = child end
end
assert(secondsContainer and #secondsContainer.slots == 4)
for _, aura in ipairs(secondsContainer.children) do
    assert(aura.cooldown.millisecondsThreshold == 0)
end
profile.dotTimerMilliseconds = true
assert(WarlockHudMultiTarget.Refresh() == true)
local decimalsRoot, decimalsViewport = LatestWindow()
assert(decimalsRoot ~= secondsRoot)
local decimalsContainer
for _, child in ipairs(decimalsViewport.scrollChild.children[1].children[15].children) do
    if child.kind == 'AuraContainer' then decimalsContainer = child end
end
for _, aura in ipairs(decimalsContainer.children) do
    assert(aura.cooldown.millisecondsThreshold == 10)
end
-- A lost nameplate keeps a separate grey row while its estimated DoT lasts.
local damageDriver
for _, frame in ipairs(topFrames) do
    local registered = rawget(frame, 'registered')
    if registered and registered.UNIT_SPELLCAST_SUCCEEDED then
        damageDriver = frame
    end
end
assert(damageDriver)
C_Spell.GetSpellDescription = function(id)
    if id == 172 then return 'Deals 223 Shadow damage over 18 sec' end
end
local clock = 0
GetTime = function() return clock end
plates.target = nil
eventFrame.scripts.OnEvent(nil, 'PLAYER_TARGET_CHANGED')
plates.nameplate2 = 'Lost Mob'
dots.nameplate2 = 172
guids.nameplate2 = 'Creature-lost-2'
guids.target = 'Creature-lost-2'
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate2')
assert(decimalsViewport.scrollChild.children[2].children[12].text == 'Lost Mob')
combat = true
damageDriver.scripts.OnEvent(nil, 'UNIT_SPELLCAST_SUCCEEDED', 'player', nil, 172)
assert(trace[#trace]:find('Multi-Target damage: Corruption', 1, true),
    tostring(trace[#trace]))
plates.nameplate2 = nil
dots.nameplate2 = nil
guids.nameplate2 = nil
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_REMOVED', 'nameplate2')
local ghost = decimalsViewport.scrollChild.children[62]
assert(ghost.alpha == 0.55 and ghost.children[12].text == 'Lost Mob',
    tostring(ghost.alpha) .. '/' .. tostring(ghost.children[12].text)
    .. '/' .. tostring(status.text))
assert(ghost.children[7].text == '45 30% (DoT 223)')
assert(ghost.children[5].value == 45 and ghost.children[5].maximum == 150)
assert(ghost.children[2].texture == 'portrait:nameplate2')
assert(ghost.children[3].alpha == 0)
assert(ghost.children[15].children[1].shown == false)
local activeSnapshotIcon = false
for _, icon in ipairs(ghost.children[15].children) do
    if icon.alpha == 0.9 then activeSnapshotIcon = true end
end
assert(activeSnapshotIcon)
plates.target = 'Lost Mob'
dots.target = 172
targetUnit = 'target'
eventFrame.scripts.OnEvent(nil, 'PLAYER_TARGET_CHANGED')
assert(ghost.alpha == 0) -- live target token takes over
plates.target = nil
dots.target = nil
guids.target = nil
targetUnit = 'nameplate2'
eventFrame.scripts.OnEvent(nil, 'PLAYER_TARGET_CHANGED')
assert(ghost.alpha == 0.55) -- lost again
clock = 19
eventFrame.scripts.OnUpdate(nil, 0.21)
assert(ghost.alpha == 0) -- estimate expired
clock = 20
plates.nameplate2 = 'Lost Mob'
dots.nameplate2 = 172
guids.nameplate2 = 'Creature-lost-2'
guids.target = 'Creature-lost-2'
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate2')
assert(decimalsViewport.scrollChild.children[2].children[12].text == 'Lost Mob',
    tostring(decimalsViewport.scrollChild.children[2].alpha) .. '/'
    .. tostring(decimalsViewport.scrollChild.children[2].children[12].text))
assert(guids.nameplate2 == 'Creature-lost-2')
damageDriver.scripts.OnEvent(nil, 'UNIT_SPELLCAST_SUCCEEDED', 'player', nil, 172)
plates.nameplate2 = nil
dots.nameplate2 = nil
guids.nameplate2 = nil
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_REMOVED', 'nameplate2')
assert(ghost.alpha == 0.55, tostring(ghost.alpha) .. '/'
    .. tostring(ghost.children[12].text) .. '/' .. tostring(status.text))
plates.nameplate4 = 'Second Lost'
mobTargets.nameplate4target = 'player'
guids.nameplate4 = 'Creature-lost-4'
guids.target = 'Creature-lost-4'
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate4')
damageDriver.scripts.OnEvent(nil, 'UNIT_SPELLCAST_SUCCEEDED', 'player', nil, 172)
plates.nameplate4 = nil
mobTargets.nameplate4target = nil
guids.nameplate4 = nil
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_REMOVED', 'nameplate4')
local secondGhost = decimalsViewport.scrollChild.children[63]
assert(ghost.alpha == 0.55 and secondGhost.alpha == 0.55)
assert(ghost.children[12].text == 'Lost Mob'
    and secondGhost.children[12].text == 'Second Lost')
plates.nameplate2 = 'Lost Mob'
guids.nameplate2 = 'Creature-lost-2'
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_ADDED', 'nameplate2')
dead.nameplate2 = true
eventFrame.scripts.OnEvent(nil, 'UNIT_FLAGS', 'nameplate2')
plates.nameplate2 = nil
guids.nameplate2 = nil
eventFrame.scripts.OnEvent(nil, 'NAME_PLATE_UNIT_REMOVED', 'nameplate2')
assert(ghost.children[12].text ~= 'Lost Mob' or ghost.alpha == 0)
assert(secondGhost.children[12].text ~= 'Lost Mob' or secondGhost.alpha == 0)
assert((ghost.alpha == 0.55 and ghost.children[12].text == 'Second Lost')
    or (secondGhost.alpha == 0.55 and secondGhost.children[12].text == 'Second Lost'))
combat = false
eventFrame.scripts.OnEvent(nil, 'PLAYER_REGEN_ENABLED')
assert(ghost.alpha == 0)
assert(secondGhost.alpha == 0)
''')

deferred = LuaRuntime(unpack_returned_tuples=True)
deferred.execute(r'''
WarlockHudAPI = { GetProfile = function() return { multiDotEnabled = true } end,
    InitializeProfiles = function() end, IsAddonEnabled = function() return true end,
    MainKeys = {'corruption', 'bane', 'curse', 'drain', 'immolate', 'siphonlife'},
    Spells = {}, GetDotDefaultSpell = function() return nil end,
    GetMultiTargetEffectOrder = function() return {} end }
WarlockHudMultiTargetDamage = { New = function()
    return { Update = function() end, Clear = function() end }
end }
combat = true
InCombatLockdown = function() return combat end
C_Secrets = { ShouldAurasBeSecret = function() return false end }
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function(self, _, fn) self.event = fn end }
end
''')
deferred.execute(Path("Warlock_Hud_MultiTargetIdentity.lua").read_text(encoding="utf-8"))
deferred.execute(Path("Warlock_Hud_MultiTargetLayout.lua").read_text(encoding="utf-8"))
deferred.execute(Path("Warlock_Hud_MultiTargetAuras.lua").read_text(encoding="utf-8"))
deferred.execute(Path("Warlock_Hud_MultiTargetProbe.lua").read_text(encoding="utf-8"))
deferred.execute(Path("Warlock_Hud_MultiTarget.lua").read_text(encoding="utf-8"))
deferred.execute("assert(WarlockHudMultiTarget.Refresh() == false)")
print("Multi-target fixed-token smoke tests OK")
