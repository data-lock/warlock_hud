"""Run with: uv run --with lupa python tests/consumables_smoke.py"""

from pathlib import Path
from lupa import LuaRuntime

source = Path("Warlock_Hud.lua").read_text(encoding="utf-8")
effect_start = source.index("local function ReadConsumableEffect(effect)")
effect_end = source.index("local function ReadWizardOil()", effect_start)
start = source.index("local function ReadWizardOil()")
end = source.index("local function UpdateConsumableGlows()", start)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
consumeState = { oilEnchantIDs = { [2623]=true, [2626]=true,
    [2627]=true, [2628]=true } }
C_Item = {}
C_Secrets = { ShouldAurasBeSecret = function() return false end }
combat = false
InCombatLockdown = function() return combat end
issecretvalue = function(value) return value == 'SECRET' end
C_UnitAuras = {}
ReadPlayerBuffNames = function() return false end
""")
lua.execute(source[effect_start:effect_end] + "\nReadConsumableEffectForTest = ReadConsumableEffect")
lua.execute(source[start:end] + "\nReadWizardOilForTest = ReadWizardOil")
lua.execute("""
local flask = { ids = { [17628] = true }, names = { 'Supreme Power' } }
C_UnitAuras.GetPlayerAuraBySpellID = function() return { spellId = 17628 } end
assert(ReadConsumableEffectForTest(flask) == true)
C_UnitAuras.GetPlayerAuraBySpellID = function() return nil end
assert(ReadConsumableEffectForTest(flask) == false)
C_UnitAuras.GetPlayerAuraBySpellID = function() return 'SECRET' end
assert(ReadConsumableEffectForTest(flask) == nil)
C_UnitAuras.GetPlayerAuraBySpellID = function() error('protected') end
assert(ReadConsumableEffectForTest(flask) == nil)
C_UnitAuras.GetPlayerAuraBySpellID = function() return nil end
combat = true
assert(ReadConsumableEffectForTest(flask) == nil)
combat = false
C_Item.GetWeaponEnchantInfo = function()
    return { { hasEnchant=true, enchantType=2, enchantID=2628 } }
end
assert(ReadWizardOilForTest() == true)
C_Item.GetWeaponEnchantInfo = function()
    return { { hasEnchant=true, enchantType=2, enchantID=9999 } }
end
assert(ReadWizardOilForTest() == false)
C_Item.GetWeaponEnchantInfo = function() return {} end
assert(ReadWizardOilForTest() == false)
C_Item.GetWeaponEnchantInfo = function()
    return { { hasEnchant=true, enchantType=2, enchantID='SECRET' } }
end
assert(ReadWizardOilForTest() == nil)
C_Item.GetWeaponEnchantInfo = function() error('protected') end
assert(ReadWizardOilForTest() == nil)
combat = true
assert(ReadWizardOilForTest() == nil)
""")
print("Consumables weapon-oil status smoke tests OK")
