"""Run with: uv run --with lupa python tests/cast_icon_smoke.py"""

from pathlib import Path
from lupa import LuaRuntime

source = Path("Warlock_Hud.lua").read_text(encoding="utf-8")
spellbook_source = Path("Warlock_Hud_Spellbook.lua").read_text(encoding="utf-8")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
C_Spell = { GetSpellTexture = function(identifier)
    if identifier == 9000 then return 134400 end
    if identifier == 'Bane of Havoc' then return 2468 end
    if identifier == 1225228 then return 1359 end
end }
""")
lua.execute(spellbook_source)
lua.execute("""
assert(WarlockHudSpellbook.CastSpellTexture({ name = 'Bane of Havoc', ids = {1225228} }, 9000) == 2468)
C_Spell.GetSpellTexture = function(identifier)
    if identifier == 9000 then return 'INV_Misc_QuestionMark' end
    if identifier == 1225228 then return 1359 end
end
assert(WarlockHudSpellbook.CastSpellTexture({ name = 'Bane of Havoc', ids = {1225228} }, 9000) == 1359)
""")
assert 'local CastSpellTexture = WarlockHudSpellbook.CastSpellTexture' in source
assert 'button:SetIcon(auraIcon)' in source
assert 'local castIcon = button:CreateTexture(nil, "OVERLAY")' in source
assert 'button:HookScript(' not in source
print("Cast icon smoke tests OK")
