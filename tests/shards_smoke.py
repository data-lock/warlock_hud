"""Check shard queries and warning decisions without invoking deletion."""

from pathlib import Path
from lupa.lua51 import LuaRuntime


lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
issecretvalue = function(value) return value == 'SECRET' end
NUM_BAG_SLOTS = 2
C_Item = { GetItemCount = function(id) assert(id == 6265); return 3 end }
C_Container = {
    GetContainerNumFreeSlots = function(bag)
        if bag == 1 then return 0, 4 end
        return 0, 0
    end,
    GetContainerNumSlots = function(bag)
        if bag == 0 then return 2 end
        if bag == 1 then return 2 end
        return 0
    end,
    GetContainerItemID = function(bag, slot)
        if bag == 0 and slot == 1 then return 6265 end
    end,
}
''')
lua.execute(Path("Warlock_Hud_Shards.lua").read_text(encoding="utf-8"))
lua.execute(r'''
assert(WarlockHudShards.IsSoulShardBag(0) == false)
assert(WarlockHudShards.IsSoulShardBag(1) == true)
assert(WarlockHudShards.GetCount() == 3)
assert(WarlockHudShards.HasShardOverflow() == true)
local profile = {
    shardWarningsEnabled = true, shardLowThreshold = 1,
    shardHighThreshold = 5, shardWarnOverflow = true,
}
assert(WarlockHudShards.WarningState(0, profile) == 'LOW')
assert(WarlockHudShards.WarningState(6, profile) == 'HIGH')
assert(WarlockHudShards.WarningState(3, profile) == 'HIGH')
local visual = { countText = {}, icon = {}, button = {}, glow = { texture = {} } }
visual.countText.SetText = function(_, value) visual.count = value end
visual.icon.SetAlpha = function(_, value) visual.iconAlpha = value end
visual.icon.SetVertexColor = function(_, r, g, b) visual.iconColor = { r, g, b } end
visual.button.SetAlpha = function(_, value) visual.buttonAlpha = value end
visual.glow.texture.SetVertexColor = function(_, r, g, b)
    visual.glowColor = { r, g, b }
end
visual.glow.Show = function() visual.shown = true end
visual.glow.Hide = function() visual.shown = false end
WarlockHudShards.UpdateDisplay(visual, profile)
assert(visual.count == 3 and visual.shown == true)
profile.shardWarnOverflow = false
assert(WarlockHudShards.WarningState(3, profile) == 'NORMAL')
WarlockHudShards.UpdateDisplay(visual, profile)
assert(visual.shown == false and visual.iconAlpha == 1)
C_Item.GetItemCount = function() return 'SECRET' end
assert(WarlockHudShards.GetCount() == nil)
''')
print("Shard query smoke tests OK")
