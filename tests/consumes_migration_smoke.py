"""Run with: uv run --with lupa python tests/consumes_migration_smoke.py"""

from pathlib import Path
from lupa import LuaRuntime

source = Path("Warlock_Hud.lua").read_text(encoding="utf-8")
assert source.count('consumeAuras:AddAuraSlot("Well Fed"') == 1
assert 'playerAuras:AddAuraSlot("Well Fed"' not in source
start = source.index("local function NormalizeOrder(")
end = source.index("local function ActiveTalentGroup(", start)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
MAIN_KEYS = {'corruption'}
COOLDOWN_KEYS = {'healthstone'}
BUFF_KEYS = {'fort', 'motw', 'armor', 'breath'}
consumeState = { keys = {'wellfed', 'flask', 'spelldamage', 'shadow', 'fire', 'wizardoil', 'manaregen'} }
PROC_KEYS = {'nightfall'}
DOT_DEFAULT_SLOTS = {}
SPELLS = {}
DEFAULT_SUMMON_KEYWORDS = '123, sum, summ'
""")
lua.execute(source[start:end] + "\nNormalizeProfileForTest = NormalizeProfile")
lua.execute("""
local old = {
    buffSize = 38, buffOrder = {'motw', 'wellfed', 'fort', 'armor', 'breath'},
    enabled = { wellfed = false, fort = false },
    colorActiveBuffs = false,
    showOutOfCombat = { buffs = false },
    buffX = 0.21, buffY = 0.67,
}
local migrated = NormalizeProfileForTest(old)
assert(migrated.consumesSchemaVersion == 2)
assert(migrated.enabled.wellfed == false and migrated.enabled.fort == false)
for _, key in ipairs(consumeState.keys) do
    if key ~= 'wellfed' then assert(migrated.enabled[key] == false) end
end
assert(migrated.consumeReminders.wellfed == true)
assert(migrated.consumeSize == 38 and migrated.colorActiveConsumes == false)
assert(migrated.showOutOfCombat.consumes == false)
assert(migrated.consumeOrder[1] == 'wellfed')
assert(migrated.buffOrder[1] == 'motw' and migrated.buffOrder[2] == 'fort')
assert(migrated.buffOrder[#migrated.buffOrder] == 'breath')
for _, key in ipairs(migrated.buffOrder) do assert(key ~= 'wellfed') end
assert(migrated.buffX == 0.21 and migrated.buffY == 0.67)
migrated.consumeSize = 42
migrated.enabled.flask = true
migrated.colorActiveConsumes = true
migrated.showOutOfCombat.consumes = true
migrated.buffSize = 24
NormalizeProfileForTest(migrated)
assert(migrated.consumeSize == 42 and migrated.colorActiveConsumes == true)
assert(migrated.showOutOfCombat.consumes == true)
assert(migrated.enabled.wellfed == false)
assert(migrated.enabled.flask == true)
assert(migrated.consumeReminders.flask == nil)
local order = table.concat(migrated.buffOrder, ',')
local consumeOrder = table.concat(migrated.consumeOrder, ',')
NormalizeProfileForTest(migrated)
assert(table.concat(migrated.buffOrder, ',') == order)
assert(table.concat(migrated.consumeOrder, ',') == consumeOrder)
assert(migrated.enabled.flask == true and migrated.enabled.wellfed == false)
local fresh = NormalizeProfileForTest({})
assert(fresh.consumeOrder[1] == 'wellfed' and fresh.consumeSize == 24)
assert(fresh.consumeReminders.wellfed == true and fresh.enabled.wizardoil == false)
assert(fresh.multiDotEnabled == false)
assert(fresh.multiDotScale == 1)
assert(fresh.multiDotWidth == 430 and fresh.multiDotHeight == 316)
local oldWindow = NormalizeProfileForTest({ multiDotScale = 1.25 })
assert(oldWindow.multiDotWidth == 430 and oldWindow.multiDotHeight == 395)
oldWindow.multiDotWidth = 500
NormalizeProfileForTest(oldWindow)
assert(oldWindow.multiDotWidth == 500)
""")
print("Consumes migration smoke tests OK")
