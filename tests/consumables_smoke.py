"""Run with: uv run --with lupa python tests/consumables_smoke.py"""

from pathlib import Path
from lupa import LuaRuntime

source = Path("Warlock_Hud.lua").read_text(encoding="utf-8")
effect_start = source.index("local function ReadConsumableEffect(effect)")
effect_end = source.index("local function ReadWeaponCoating()", effect_start)
start = source.index("local function ReadWeaponCoating()")
end = source.index("local function ReadGroupBuff", start)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
consumeState = { oilEnchantIDs = { [2623]=true, [2626]=true,
    [2627]=true, [2628]=true }, firestoneEnchantIDs = { [1803]=true } }
C_Item = {}
C_Secrets = { ShouldAurasBeSecret = function() return false end }
combat = false
InCombatLockdown = function() return combat end
GetTime = function() return 100 end
issecretvalue = function(value) return value == 'SECRET' end
C_UnitAuras = {}
ReadPlayerBuffNames = function() return false end
profile = { colorActiveConsumes = true, consumeReminders = { wizardoil = true } }
SetMissingGlow = function(glow, status)
    glow.applied = status
    glow.shown = status == false
end
consumeState.effects = {}
consumeState.glows = { wizardoil = { pulseIcon = { SetAlpha = function() end } } }
consumeState.oilTexture = 'oil-icon'
consumeState.firestoneTexture = 'firestone-icon'
consumeState.oilIcon = { SetTexture = function(self, texture) self.texture = texture end }
consumeState.coatingCooldown = {
    SetCooldown = function(self, start, duration)
        self.start, self.duration = start, duration
    end,
    SetShown = function(self, shown) self.shown = shown end,
    Hide = function(self) self.shown = false end,
}
""")
lua.execute(source[effect_start:effect_end] + "\nReadConsumableEffectForTest = ReadConsumableEffect")
lua.execute(source[start:end] + "\nReadWeaponCoatingForTest = ReadWeaponCoating\nUpdateConsumableGlowsForTest = UpdateConsumableGlows")
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
C_Secrets.ShouldAurasBeSecret = function() return true end
assert(ReadConsumableEffectForTest(flask) == nil)
assert(ReadWeaponCoatingForTest() == nil)
C_Secrets.ShouldAurasBeSecret = function() return false end
C_UnitAuras.GetPlayerAuraBySpellID = nil
ReadPlayerBuffNames = function() return nil end
assert(ReadConsumableEffectForTest(flask) == nil)
ReadPlayerBuffNames = function() return true end
assert(ReadConsumableEffectForTest(flask) == true)
C_UnitAuras.GetPlayerAuraBySpellID = function() return nil end
C_Item.GetWeaponEnchantInfo = function()
    return { { hasEnchant=true, enchantType=2, enchantID=2628 } }
end
assert(ReadWeaponCoatingForTest() == 'oil')
C_Item.GetWeaponEnchantInfo = function()
    return { { hasEnchant=true, enchantType=3, enchantID=1803,
        timeLeft=6871263 } }
end
local coating, remaining = ReadWeaponCoatingForTest()
assert(coating == 'firestone' and remaining == 6871263)
UpdateConsumableGlowsForTest()
assert(consumeState.glows.wizardoil.applied == true)
assert(consumeState.glows.wizardoil.shown == false)
assert(consumeState.oilIcon.texture == 'firestone-icon')
assert(consumeState.coatingCooldown.shown == true)
assert(consumeState.coatingCooldown.duration == 7200)
assert(math.abs(consumeState.coatingCooldown.start + 228.737) < 0.001)
assert(consumeState.coatingExpiresAt == 6971.263)
C_Item.GetWeaponEnchantInfo = function()
    return { { hasEnchant=true, enchantType=2, enchantID=2628 },
        { hasEnchant=true, enchantType=3, enchantID=1803 } }
end
assert(ReadWeaponCoatingForTest() == 'firestone')
C_Item.GetWeaponEnchantInfo = function()
    return { { hasEnchant=true, enchantType=2, enchantID=9999 } }
end
assert(ReadWeaponCoatingForTest() == false)
UpdateConsumableGlowsForTest()
assert(consumeState.glows.wizardoil.applied == false)
assert(consumeState.glows.wizardoil.shown == true)
assert(consumeState.oilIcon.texture == 'oil-icon')
assert(consumeState.coatingCooldown.shown == false)
assert(consumeState.coatingExpiresAt == nil)
C_Item.GetWeaponEnchantInfo = function() return {} end
assert(ReadWeaponCoatingForTest() == false)
C_Item.GetWeaponEnchantInfo = function()
    return { { hasEnchant=true, enchantType=2, enchantID='SECRET' } }
end
assert(ReadWeaponCoatingForTest() == nil)
C_Item.GetWeaponEnchantInfo = function()
    return { { hasEnchant=true, enchantType=3, enchantID=1803,
        timeLeft='SECRET' } }
end
local secretCoating, secretRemaining = ReadWeaponCoatingForTest()
assert(secretCoating == 'firestone' and secretRemaining == nil)
C_Item.GetWeaponEnchantInfo = function() error('protected') end
assert(ReadWeaponCoatingForTest() == nil)
combat = true
assert(ReadWeaponCoatingForTest() == nil)
""")
print("Consumables weapon-oil status smoke tests OK")
