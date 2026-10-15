-- Read only shard and bag queries. The deletion action remains in the HUD.
WarlockHudShards = { ItemID = 6265 }

function WarlockHudShards.IsSoulShardBag(bag)
    if bag == 0 then return false end
    if not C_Container or not C_Container.GetContainerNumFreeSlots then return nil end
    local ok, _, family = pcall(C_Container.GetContainerNumFreeSlots, bag)
    if not ok or (issecretvalue and issecretvalue(family))
        or type(family) ~= "number" then return nil end
    return math.floor(family / 4) % 2 == 1
end

function WarlockHudShards.HasShardOverflow()
    if not C_Container or not C_Container.GetContainerNumSlots
        or not C_Container.GetContainerItemID then return nil end
    local soulBagCapacity, regularShards = 0, false
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
        if not ok or (issecretvalue and issecretvalue(slots))
            or type(slots) ~= "number" then return nil end
        if slots > 0 then
            local isSoulBag = WarlockHudShards.IsSoulShardBag(bag)
            if isSoulBag == nil then return nil end
            if isSoulBag then soulBagCapacity = soulBagCapacity + slots end
            for slot = 1, slots do
                local itemOK, itemID = pcall(C_Container.GetContainerItemID, bag, slot)
                if not itemOK or (issecretvalue and issecretvalue(itemID)) then return nil end
                if itemID == WarlockHudShards.ItemID and not isSoulBag then regularShards = true end
            end
        end
    end
    return soulBagCapacity > 0 and regularShards
end

function WarlockHudShards.WarningState(count, profile)
    if not profile or not profile.shardWarningsEnabled or type(count) ~= "number" then
        return "NORMAL"
    end
    if count <= profile.shardLowThreshold then return "LOW" end
    if count >= profile.shardHighThreshold then return "HIGH" end
    if profile.shardWarnOverflow and WarlockHudShards.HasShardOverflow() then return "HIGH" end
    return "NORMAL"
end

function WarlockHudShards.GetCount()
    if not C_Item or not C_Item.GetItemCount then return nil end
    local ok, count = pcall(C_Item.GetItemCount, WarlockHudShards.ItemID)
    if not ok or (issecretvalue and issecretvalue(count))
        or type(count) ~= "number" then return nil end
    return count
end
