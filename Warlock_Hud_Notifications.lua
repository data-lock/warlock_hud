local api = WarlockHudAPI
local events = CreateFrame("Frame")
local pendingCasts = {}
local tradeHasHealthstone = false
local tradeNotified = false
local tradePartner
local lastSoulstoneAt = 0

local SOULSTONE_AURAS = {
    [20707] = true, [20762] = true, [20763] = true,
    [20764] = true, [20765] = true,
}
local SOULSTONE_ITEMS = { 16896, 16895, 16893, 16892, 5232 }
local HEALTHSTONES = {
    [9421] = true, [19012] = true, [19013] = true,
    [5510] = true, [19010] = true, [19011] = true,
    [5509] = true, [19008] = true, [19009] = true,
    [5511] = true, [19006] = true, [19007] = true,
    [5512] = true, [19004] = true, [19005] = true,
}

local function Public(value)
    return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

local function Notify(key, message, groupMessage)
    local profile = api.GetProfile()
    if not profile or profile.enabled[key] == false then return end
    if (groupMessage or profile.notificationChannel == "GROUP") and IsInGroup()
        and C_ChatInfo and C_ChatInfo.SendChatMessage then
        local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT"
            or IsInRaid() and "RAID" or "PARTY"
        if pcall(C_ChatInfo.SendChatMessage, message, channel) then return end
    end
    print("|cffff7a7aWarlock HUD:|r " .. message)
end

local function IsSoulstoneCast(spellID)
    if SOULSTONE_AURAS[spellID] then return true end
    if C_Item and C_Item.GetItemSpell then
        for _, itemID in ipairs(SOULSTONE_ITEMS) do
            local ok, _, itemSpellID = pcall(C_Item.GetItemSpell, itemID)
            if ok and Public(itemSpellID) and itemSpellID == spellID then
                return true
            end
        end
    end
    if not C_Spell or not C_Spell.GetSpellName then return false end
    local ok, name = pcall(C_Spell.GetSpellName, spellID)
    return ok and Public(name) and type(name) == "string"
        and name:find("Soulstone", 1, true) ~= nil
        and name:find("Create Soulstone", 1, true) == nil
end

local function TargetLabel(target)
    if Public(target) and type(target) == "string" and target ~= "" then
        return target
    end
    return "your target"
end

local function AnnounceSoulstone(target)
    local now = GetTime()
    if now - lastSoulstoneAt < 2 then return end
    lastSoulstoneAt = now
    Notify("notifySoulstone", "Soulstone cast on " .. TargetLabel(target) .. ".", true)
end

local function IsHealthstoneInTrade()
    for slot = 1, 6 do
        local ok, link = false, nil
        if GetTradePlayerItemLink then ok, link = pcall(GetTradePlayerItemLink, slot) end
        if ok and Public(link) and type(link) == "string" then
            local itemID = tonumber(link:match("|Hitem:(%d+)"))
            if itemID and HEALTHSTONES[itemID] then return true end
        elseif GetTradePlayerItemInfo then
            local name = GetTradePlayerItemInfo(slot)
            if Public(name) and type(name) == "string" then
                if name:find("Healthstone", 1, true) then return true end
                for itemID in pairs(HEALTHSTONES) do
                    local knownName = C_Item and C_Item.GetItemNameByID
                        and C_Item.GetItemNameByID(itemID)
                    if knownName and name == knownName then return true end
                end
            end
        end
    end
    return false
end

events:RegisterEvent("UNIT_SPELLCAST_SENT")
events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
events:RegisterEvent("UNIT_SPELLCAST_FAILED")
events:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
events:RegisterEvent("TRADE_SHOW")
events:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED")
events:RegisterEvent("TRADE_ACCEPT_UPDATE")
events:RegisterEvent("TRADE_CLOSED")
events:RegisterEvent("TRADE_REQUEST_CANCEL")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SENT" then
        local unit, target, castGUID, spellID = ...
        if unit ~= "player" or not Public(spellID) then return end
        if spellID == 698 or IsSoulstoneCast(spellID) then
            local label = TargetLabel(target)
            if Public(castGUID) then pendingCasts[castGUID] = label end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        if unit ~= "player" or not Public(spellID) then return end
        if spellID == 698 then
            local label = Public(castGUID) and pendingCasts[castGUID] or "your target"
            Notify("notifySummon", "Summoning " .. label .. ". Please click the portal.")
        end
        if IsSoulstoneCast(spellID) then
            local label = Public(castGUID) and pendingCasts[castGUID] or "your target"
            AnnounceSoulstone(label)
        end
        if Public(castGUID) then pendingCasts[castGUID] = nil end
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit, castGUID = ...
        if unit == "player" and Public(castGUID) then pendingCasts[castGUID] = nil end
    elseif event == "TRADE_SHOW" then
        tradeHasHealthstone = false
        tradeNotified = false
        local name = UnitName("NPC")
        tradePartner = Public(name) and name or "your trade partner"
    elseif event == "TRADE_PLAYER_ITEM_CHANGED" then
        tradeHasHealthstone = IsHealthstoneInTrade()
        tradeNotified = false
    elseif event == "TRADE_ACCEPT_UPDATE" then
        local playerAccepted, targetAccepted = ...
        if playerAccepted and targetAccepted and tradeHasHealthstone and not tradeNotified then
            tradeNotified = true
            Notify("notifyHealthstone", "Healthstone trade accepted with "
                .. (tradePartner or "your trade partner") .. ".")
        end
    elseif event == "TRADE_CLOSED" or event == "TRADE_REQUEST_CANCEL" then
        tradeHasHealthstone = false
        tradeNotified = false
        tradePartner = nil
    end
end)
