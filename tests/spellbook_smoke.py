"""Run with: uv run --with lupa python tests/spellbook_smoke.py"""

from pathlib import Path
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
known = {}
talentRank = 0
issecretvalue = function(value) return value == 'SECRET' end
C_SpellBook = { IsSpellKnown = function(id) return known[id] end }
C_Spell = { GetSpellIDForSpellIdentifier = function(name)
    if name == 'Conflagrate' then return 1293817 end
    if name == 'Create Healthstone' then return 6201 end
end }
GetNumTalents = function(tab) assert(tab == 2); return 1 end
GetTalentInfo = function(tab, index)
    assert(tab == 2 and index == 1)
    return 'Demonic Brand', nil, nil, nil, talentRank
end
''')
lua.execute(Path("Warlock_Hud_Spellbook.lua").read_text(encoding="utf-8"))
lua.execute(r'''
assert(WarlockHudSpellbook.KnowsDemonicBrand() == false)
talentRank = 2
assert(WarlockHudSpellbook.KnowsDemonicBrand() == true)
talentRank = 0
known[1293695] = true
assert(WarlockHudSpellbook.KnowsDemonicBrand() == false)
GetNumTalents = nil
assert(WarlockHudSpellbook.KnowsDemonicBrand() == true)
known[1293695] = 'SECRET'
assert(WarlockHudSpellbook.KnowsDemonicBrand() == false)
assert(WarlockHudSpellbook.KnownSpellID(1293695) == nil)
known[1293817] = true
assert(WarlockHudSpellbook.ConflagrateSpellID() == 1293817)
assert(WarlockHudSpellbook.KnownSpell({name='Known', ids={1293817}}) == true)
known[6201] = true
assert(WarlockHudSpellbook.LearnedAnySpell({'Create Healthstone'}, {6201}) == true)
known[6201] = false
assert(WarlockHudSpellbook.LearnedAnySpell({'Create Healthstone'}, {6201}) == false)
known[1293817] = false
assert(WarlockHudSpellbook.KnownSpell({name='Unknown', ids={1293817}}) == false)
known[999999] = 'SECRET'
assert(WarlockHudSpellbook.KnownSpell({name='Unreadable', ids={999999}}) == true)
''')
print("Spellbook smoke tests OK")
