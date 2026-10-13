"""Run with: uv run --with lupa python tests/sharing_smoke.py"""

from pathlib import Path
import base64
from lupa import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
local db = { activeProfile = 'Default', profiles = {
    Default = { mainSize = 48, multiDotEnabled = true, multiDotScale = 1.25,
        multiDotWidth = 370, multiDotHeight = 410,
        multiDotX = 0.55, multiDotY = 0.48, consumesSchemaVersion = 2,
        consumeSize = 35, consumeOrder = {'wellfed', 'flask'},
        consumeReminders = { wellfed = true, flask = false },
        consumeX = 0.42, consumeY = 0.61, consumeLeftAligned = true,
        colorActiveConsumes = false,
        shardSize = 24, shardKeepCount = 8,
        enabled = { notifySummon = false, soulshards = false, flask = true },
        mainOrder = {'corruption', 'immolate'},
        stones = { autoPlaceHealthstone = true },
        x = 0.25, notificationChannel = 'GROUP' }
} }
WarlockHudAPI = {
    GetDB = function() return db end,
    NormalizeProfile = function(p) return p end,
    InitializeProfiles = function() end,
    NormalizeSummonKeywords = function(s) return s:match('^[A-Za-z0-9, ]+$') and s end,
}
""")
lua.execute(Path("Warlock_Hud_Sharing.lua").read_text(encoding="utf-8"))
code = lua.eval("WarlockHudSharing.Export({ bars=true }, false)")
plain = base64.b64decode(code[6:]).decode("utf-8")
lua.globals().future_code = "WHUD1:" + base64.b64encode(
    (plain.replace("WHUD|1|unknown", "WHUD|1|99.0")
     + "\nDefault|bars|futureSetting|3\nDefault|futureSection|thing|1").encode("utf-8")
).decode("ascii")
lua.globals().bad_number_code = "WHUD1:" + base64.b64encode(
    plain.replace("Default|bars|mainSize|48", "Default|bars|mainSize|999999").encode("utf-8")
).decode("ascii")
lua.execute("""
local future, futureError = WarlockHudSharing.Decode(future_code)
assert(future and future.version == '99.0', futureError)
local bad, badError = WarlockHudSharing.Decode(bad_number_code)
assert(not bad and badError)
local selected = { bars=true, positions=true, notifications=true,
    summons=true, stones=true, shards=true }
local code = WarlockHudSharing.Export(selected, false)
local parsed, err = WarlockHudSharing.Decode(code)
assert(parsed, err)
assert(parsed.version and parsed.available.bars and parsed.available.shards)
assert(parsed.profiles.Default.bars.consumeSize == 35)
assert(parsed.profiles.Default.bars.multiDotEnabled == true)
assert(parsed.profiles.Default.bars.multiDotScale == 1.25)
assert(parsed.profiles.Default.bars.multiDotWidth == 370)
assert(parsed.profiles.Default.bars.multiDotHeight == 410)
assert(parsed.profiles.Default.positions.multiDotX == 0.55)
assert(parsed.profiles.Default.positions.multiDotY == 0.48)
assert(parsed.profiles.Default.bars.consumesSchemaVersion == 2)
assert(parsed.profiles.Default.bars.consumeReminders.wellfed == true)
assert(parsed.profiles.Default.bars.enabled.flask == true)
assert(parsed.profiles.Default.positions.consumeX == 0.42)
assert(parsed.profiles.Default.positions.consumeLeftAligned == true)
assert(parsed.profiles.Default.bars.colorActiveConsumes == false)
assert(parsed.profiles.Default.bars.consumesEnabled == nil)
local db = WarlockHudAPI.GetDB()
db.profiles.Default.mainSize = 72
db.profiles.Default.x = 0.8
db.profiles.Default.enabled.notifySummon = nil
local count, result = WarlockHudSharing.Import(parsed, { bars=true, notifications=true }, false)
assert(count == 1, result)
assert(db.profiles.Default.mainSize == 48 and db.profiles.Default.x == 0.8)
assert(db.profiles.Default.enabled.notifySummon == false)
assert(db.profiles.Default.enabled.soulshards == false)
assert(db.profiles.Default.shardLayoutAdjusted == true)
local legacy = WarlockHudSharing.Decode(WarlockHudSharing.Export({bars=true}, false))
legacy.profiles.Default.bars.multiDotWidth = nil
legacy.profiles.Default.bars.multiDotHeight = nil
legacy.profiles.Default.bars.multiDotScale = 1.4
local legacyCount = WarlockHudSharing.Import(legacy, {bars=true}, false)
assert(legacyCount == 1)
assert(db.profiles.Default.multiDotWidth == nil and db.profiles.Default.multiDotHeight == nil)
assert(not WarlockHudSharing.Decode(code:sub(1, -3) .. '!!'))
local original = db.profiles.Default
local invalid, reason = WarlockHudSharing.Decode('WHUD1:%%%%')
assert(not invalid and reason)
assert(db.profiles.Default == original)
local count2, result2 = WarlockHudSharing.Import(parsed, { stones=true }, true)
assert(count2 == 1, result2)
assert(db.profiles['Default Imported'].stones.autoPlaceHealthstone == true)
""")
print("Sharing smoke tests OK")
