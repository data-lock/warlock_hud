"""Exercise extracted row builders' width contracts with simple frame stubs."""

from pathlib import Path
from lupa.lua51 import LuaRuntime


source = Path("Warlock_Hud.lua").read_text(encoding="utf-8")
start = source.index("local function BuildConsumeAnchor(")
end = source.index("local function Build()", start)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
function Frame()
    local frame = {}
    return setmetatable(frame, { __index = function(_, name)
        if name == 'CreateTexture' or name == 'CreateFontString' then
            return function() return Frame() end
        end
        if name == 'GetWidth' then return function() return 1000 end end
        if name == 'GetHeight' then return function() return 800 end end
        if name == 'SetSize' then
            return function(self, width, height) self.width, self.height = width, height end
        end
        return function() end
    end })
end
CreateFrame = function() return Frame() end
UIParent = Frame()
rowFrames = { hudAnchor = Frame(), buffAnchor = Frame() }
WarlockHudRowVisibility = { masks = { consumes = Frame(), utility = Frame() } }
consumeState = { size = 24 }
ICON_SPACING = 4
COOLDOWN_ICON_SIZE = 24
BUFF_ICON_SIZE = 24
profile = {
    consumeX = 0.3, consumeY = 0.3, consumeLeftAligned = true,
    cooldownX = 0.5, cooldownY = 0.2,
}
''')
lua.execute(source[start:end] + r'''
assert(BuildConsumeAnchor(profile, { 'wellfed', 'wizardoil' }) == 52)
assert(consumeState.anchor.width == 52)
assert(BuildCooldownAnchor(profile, { 'healthstone', 'soulstone' }) == 52)
assert(rowFrames.cooldownAnchor.width == 52)
''')
assert "local consumeWidth = BuildConsumeAnchor(saved, consumeOrder)" in source
assert "consumeAuras:SetSize(consumeWidth, consumeState.size)" in source
assert "local cooldownWidth = BuildCooldownAnchor(saved, cooldownOrder)" in source
assert "utilityAuras:SetSize(cooldownWidth, COOLDOWN_ICON_SIZE)" in source
print("Row anchor width contracts OK")
