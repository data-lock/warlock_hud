"""Check the explicit pet-buff diagnostic and its protected-data guards."""

from pathlib import Path
from lupa.lua51 import LuaRuntime


lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
messages = {}
reads = 0
combat = false
secret = false
InCombatLockdown = function() return combat end
C_Secrets = { ShouldAurasBeSecret = function() return secret end }
issecretvalue = function(value) return value == 'SECRET' end
UnitExists = function(unit) assert(unit == 'pet'); return true end
C_UnitAuras = { GetBuffDataByIndex = function(unit, index)
    assert(unit == 'pet')
    reads = reads + 1
    if index == 1 then return { name = 'Soul Link', spellId = 19028 } end
end }
report = function(message) messages[#messages + 1] = message end
''')
lua.execute(Path("Warlock_Hud_Debug.lua").read_text(encoding="utf-8"))
lua.execute(r'''
combat = true
WarlockHudDebug.TracePetBuffs(report)
assert(reads == 0)
assert(messages[1] == 'Pet buff scan is unavailable during combat or secret aura states.')
combat = false
secret = true
WarlockHudDebug.TracePetBuffs(report)
assert(reads == 0)
secret = false
WarlockHudDebug.TracePetBuffs(report)
assert(reads == 2)
assert(messages[3] == 'Pet buff 1: Soul Link (ID 19028)')
''')
print("Pet buff diagnostic smoke tests OK")
