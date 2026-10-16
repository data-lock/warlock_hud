"""Run with: uv run --with lupa python tests/multitarget_damage_smoke.py"""

from pathlib import Path
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
now = 0
GetTime = function() return now end
InCombatLockdown = function() return false end
issecretvalue = function() return false end
WarlockHudEffects = { Spells = {
    { name = 'Corruption', ids = { 6223 } },
    { name = 'Bane of Agony', ids = { 1014 } },
} }
C_Spell = { GetSpellDescription = function(id)
    if id == 6223 then return 'Deals 223 Shadow damage over 18 sec' end
    if id == 1014 then return 'Deals 235 Shadow damage over 24 sec' end
end }
UnitHealthMax = function() return 691 end
UnitHealth = function() return 691 end
CurveConstants = { ScaleTo100 = {} }
UnitHealthPercent = function() return 100 end
local function Bar()
    return { SetMinMaxValues = function(self, a, b) self.minimum, self.maximum = a, b end,
        SetValue = function(self, value) self.value = value end }
end
row = { present = true, unit = 'nameplate1', damageMarker = Bar(),
    baneMarker = Bar(), siphonMarker = Bar(), immolateMarker = Bar(),
    healthText = { SetFormattedText = function(self, pattern, ...)
        self.text = string.format(pattern, ...)
    end } }
CreateFrame = function()
    driver = { RegisterUnitEvent = function() end, RegisterEvent = function() end,
        SetScript = function(self, name, handler) self[name] = handler end }
    return driver
end
''')
lua.execute(Path("Warlock_Hud_MultiTargetIdentity.lua").read_text(encoding="utf-8"))
lua.execute(Path("Warlock_Hud_MultiTargetDamage.lua").read_text(encoding="utf-8"))
lua.execute(r'''
assert(WarlockHudMultiTargetIdentity.FormatNumber(9000) == '9.00k')
assert(WarlockHudMultiTargetIdentity.FormatNumber(10000) == '10.00k')
assert(WarlockHudMultiTargetIdentity.FormatNumber(1000000) == '1.00M')
assert(WarlockHudMultiTargetIdentity.FormatNumber(691) == '691')
local damage = WarlockHudMultiTargetDamage.New(function() return { row } end,
    function() return 'mob' end)
damage.SetDebugEnabled(true)
driver.OnEvent(nil, 'UNIT_SPELLCAST_SUCCEEDED', 'player', nil, 6223)
damage.Update()
assert(math.abs(row.damageMarker.value - 223) < 0.01)
assert(row.healthText.text == '691 100% (DoT 223)')
now = 5
damage.Update()
assert(math.abs(row.damageMarker.value - 223 * 4 / 6) < 0.01,
    'an unmatched first tick must not discard Corruption')
assert(row.healthText.text == '691 100% (DoT 149)')
now = 6
driver.OnEvent(nil, 'UNIT_SPELLCAST_SUCCEEDED', 'player', nil, 1014)
now = 9
driver.OnEvent(nil, 'UNIT_COMBAT', 'nameplate1', 'WOUND', 'NORMAL', 80, 32)
damage.Update()
assert(row.damageMarker.value < 223 and row.damageMarker.value > 0)
assert(row.baneMarker.value <= 235,
    'an observed Shadow tick must not inflate description-based Agony')

-- Each visible mob owns a separate warning and native cover. A cast on one
-- nameplate must not change the other nameplates' warning state.
local units = { 'nameplate1', 'nameplate2', 'nameplate3' }
local hp = { nameplate1 = 100, nameplate2 = 500, nameplate3 = 80 }
local activeTarget = units[1]
local function Bar()
    return { SetMinMaxValues = function(self, minimum, maximum)
            self.minimum, self.maximum = minimum, maximum end,
        SetValue = function(self, value) self.value = value end }
end
UnitHealth = function(unit) return hp[unit] end
UnitHealthMax = function() return 600 end
UnitHealthPercent = function(unit) return hp[unit] / 6 end
local rows = {}
for _, unit in ipairs(units) do
    local warning = { SetAlpha = function(self, alpha) self.alpha = alpha end }
    local cover = Bar()
    rows[#rows + 1] = { present = true, unit = unit,
        damageMarker = Bar(), baneMarker = Bar(), siphonMarker = Bar(),
        immolateMarker = Bar(), portraitCover = cover,
        portraitWarning = warning, portraitCoverReady = true,
        portraitWarningReady = true,
        healthText = { SetFormattedText = function(self, pattern, ...)
            self.text = string.format(pattern, ...)
        end } }
end
local multi = WarlockHudMultiTargetDamage.New(function() return rows end,
    function(unit) return unit == 'target' and activeTarget or unit end)
now = 0
for _, unit in ipairs(units) do
    activeTarget = unit
    driver.OnEvent(nil, 'UNIT_SPELLCAST_SUCCEEDED', 'player', nil, 6223)
end
now = 0.3
multi.Update()
for i, mob in ipairs(rows) do
    assert(mob.portraitCover.minimum == 222 and mob.portraitCover.maximum == 223)
    assert(mob.portraitCover.value == hp[mob.unit])
    assert(mob.portraitWarning.alpha > 0)
end
assert(rows[1].portraitCover.value < rows[1].portraitCover.minimum)
assert(rows[2].portraitCover.value > rows[2].portraitCover.maximum)
assert(rows[3].portraitCover.value < rows[3].portraitCover.minimum)
rows[3].present = false
multi.Update()
assert(rows[3].portraitWarning.alpha == 0)
driver.OnEvent(nil, 'UNIT_COMBAT', 'nameplate1', 'EVADE', '', 0, 0)
assert(multi.RemainingForGuid('nameplate1') == 0)
multi.Update()
assert(rows[1].portraitWarning.alpha == 0)
''')
print("Multi-target damage estimate smoke tests OK")
