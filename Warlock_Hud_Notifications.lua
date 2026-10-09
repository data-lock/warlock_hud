local api = WarlockHudAPI
local events = CreateFrame("Frame")
local pendingCasts = {}
local tradeHasHealthstone = false
local tradePartner
local tradeStoneClearedAt
local tradeClosedAt
local lastSoulstoneAt = 0
local tradeDebug = false
local soulstoneDebug = false
local summonDebug = false
local assignmentDebug = false
local TraceSoulstone
local lastPlayerDeathAt
local tradeCandidate
local acceptedTrade
local SOULSTONE_AURAS = {
    [20707] = true, [20762] = true, [20763] = true,
    [20764] = true, [20765] = true,
}

local function Public(value)
    return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

local function StoneOptions()
    local profile = api.GetProfile()
    if not profile then return {} end
    profile.stones = profile.stones or {}
    return profile.stones
end

local function SoulstoneState()
    local character = UnitGUID("player")
    if not character or (issecretvalue and issecretvalue(character)) then return nil end
    WarlockHudDB.soulstoneState = WarlockHudDB.soulstoneState or {}
    WarlockHudDB.soulstoneState[character] = WarlockHudDB.soulstoneState[character] or {}
    return WarlockHudDB.soulstoneState[character]
end

local function FindRecipient(label)
    if not label or label == "your target" then return nil end
    local units = { "player", "target", "focus" }
    local prefix, count = IsInRaid() and "raid" or "party",
        IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
    for index = 1, count do units[#units + 1] = prefix .. index end
    for _, unit in ipairs(units) do
        local name, realm = UnitName(unit)
        if Public(name) then
            local fullName = Public(realm) and realm ~= ""
                and name .. "-" .. realm or name
            local displayName = GetUnitName and GetUnitName(unit, true)
            if name == label or fullName == label
                or (Public(displayName) and displayName == label) then
                local guid = UnitGUID(unit)
                if guid and (not issecretvalue or not issecretvalue(guid)) then
                    return unit, guid
                end
            end
        end
    end
end

local function FindSoulstoneAura(unit)
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataBySpellName then return nil end
    local ok, aura = pcall(function()
        if C_UnitAuras.GetAuraDataBySpellID then
            for spellID in pairs(SOULSTONE_AURAS) do
                local found = C_UnitAuras.GetAuraDataBySpellID(unit, spellID, "HELPFUL")
                if found then return found end
            end
        end
        local names = { "Soulstone Resurrection", "Soulstone" }
        if C_Spell and C_Spell.GetSpellName then
            for spellID in pairs(SOULSTONE_AURAS) do
                local name = C_Spell.GetSpellName(spellID)
                if Public(name) then names[#names + 1] = name end
            end
        end
        for _, name in ipairs(names) do
            local found = C_UnitAuras.GetAuraDataBySpellName(unit, name, "HELPFUL")
            if found then return found end
        end
    end)
    if not ok or not Public(aura) then
        if TraceSoulstone then TraceSoulstone("AURA", unit .. " unavailable or absent") end
        return nil
    end
    local read, source = pcall(function() return aura.sourceUnit end)
    if read and Public(source) and source ~= "player" then
        if TraceSoulstone then TraceSoulstone("AURA", unit .. " from another caster") end
        return nil
    end
    if TraceSoulstone then TraceSoulstone("AURA", unit .. " found; source="
        .. (Public(source) and tostring(source) or "unknown")) end
    return aura, read and Public(source) and source or nil
end

local function ObserveSoulstone(unit)
    local state = SoulstoneState()
    if not state or not state.recipientGUID or InCombatLockdown()
        or (C_Secrets and C_Secrets.ShouldAurasBeSecret
            and C_Secrets.ShouldAurasBeSecret())
        or not C_UnitAuras or not C_UnitAuras.GetAuraDataBySpellName then return end
    local guid = UnitGUID(unit)
    if not guid or (issecretvalue and issecretvalue(guid))
        or guid ~= state.recipientGUID then return end
    local aura = FindSoulstoneAura(unit)
    if aura then
        local read, expiration = pcall(function() return aura.expirationTime end)
        if not read then expiration = nil end
        if expiration and (not issecretvalue or not issecretvalue(expiration))
            and type(expiration) == "number" then
            state.expiresAt = time() + math.max(0, expiration - GetTime())
        end
        state.observed = true
        state.status = "APPLIED"
        state.statusAt = nil
    elseif state.observed and state.status == "APPLIED" then
        local playerGUID = UnitGUID("player")
        local selfDiedRecently = Public(playerGUID)
            and state.recipientGUID == playerGUID
            and lastPlayerDeathAt and GetTime() - lastPlayerDeathAt < 30
        state.status = not selfDiedRecently
            and state.expiresAt and time() >= state.expiresAt - 2
            and "EXPIRED" or "LOST / UNKNOWN"
        state.statusAt = time()
        state.observed = false
        TraceSoulstone("OUTCOME", state.status)
        if StoneOptions().notifySoulstoneLoss == true then
            print("|cffff7a7aWarlock HUD:|r Soulstone on "
                .. (state.recipientName or "recipient") .. " " .. state.status .. ".")
        end
    end
end

local function RecheckSoulstone()
    local state = SoulstoneState()
    if not state or InCombatLockdown()
        or (C_Secrets and C_Secrets.ShouldAurasBeSecret
            and C_Secrets.ShouldAurasBeSecret()) then
        if TraceSoulstone then TraceSoulstone("RECHECK", "deferred: unavailable or combat") end
        return
    end
    local selfAura, selfSource = FindSoulstoneAura("player")
    if not state.recipientGUID and selfAura
        and (selfSource == "player"
            or (state.appliedAt and time() - state.appliedAt < 10)) then
        local guid = UnitGUID("player")
        local name = GetUnitName and GetUnitName("player", true) or UnitName("player")
        if Public(guid) and Public(name) then
            state.recipientGUID = guid
            state.recipientName = name
        end
    end
    if TraceSoulstone then TraceSoulstone("RECHECK", "recipient="
        .. (state.recipientName or "unknown") .. " guid="
        .. (state.recipientGUID and "known" or "unknown")) end
    if state.recipientGUID then
        for _, unit in ipairs({ "player", "target", "focus" }) do
            ObserveSoulstone(unit)
        end
        local prefix, count = IsInRaid() and "raid" or "party",
            IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
        for index = 1, count do ObserveSoulstone(prefix .. index) end
    end
end

function WarlockHudSoulstoneText()
    if StoneOptions().soulstoneTracker == false then return nil end
    local state = SoulstoneState()
    if state and state.status == "APPLIED" and state.observed then
        if state.expiresAt and time() >= state.expiresAt then
            state.status = "EXPIRED (EST.)"
            state.statusAt = time()
            if StoneOptions().notifySoulstoneLoss == true then
                print("|cffff7a7aWarlock HUD:|r Soulstone on "
                    .. (state.recipientName or "recipient") .. " expired (estimated).")
            end
        else
            local label = StoneOptions().showSoulstoneName == false
                and "APPLIED" or (state.recipientName or "APPLIED")
            if StoneOptions().showSoulstoneCountdown ~= false and state.expiresAt then
                local remaining = math.max(0, state.expiresAt - time())
                return label .. " - " .. string.format("%d:%02d", math.floor(remaining / 60), remaining % 60)
            end
            return label
        end
    end
    return nil
end

local function Accepted(value)
    return value == true or value == 1
end

local function GroupPartner()
    if not IsInGroup() then return nil end
    local partnerGUID = UnitGUID("npc")
    if not partnerGUID or (issecretvalue and issecretvalue(partnerGUID)) then return nil end
    local prefix, count = IsInRaid() and "raid" or "party",
        IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
    for index = 1, count do
        local unit = prefix .. index
        local groupGUID = UnitGUID(unit)
        if groupGUID and (not issecretvalue or not issecretvalue(groupGUID))
            and groupGUID == partnerGUID then
            local name, realm = UnitName(unit)
            local _, class = UnitClass(unit)
            if name and (not issecretvalue or not issecretvalue(name)) then
                local fullName = realm and (not issecretvalue or not issecretvalue(realm))
                    and realm ~= "" and name .. "-" .. realm or name
                return partnerGUID, fullName,
                    (not issecretvalue or not issecretvalue(class)) and class or nil
            end
        end
    end
end

local function SuppliedPlayers()
    local character = UnitGUID("player")
    if not character or (issecretvalue and issecretvalue(character)) then return nil end
    WarlockHudDB.stoneDistribution = WarlockHudDB.stoneDistribution or {}
    local state = WarlockHudDB.stoneDistribution[character]
    if not state then
        state = { round = 1, players = {} }
        WarlockHudDB.stoneDistribution[character] = state
    end
    return state
end

function WarlockHudShowStones()
    local state = SuppliedPlayers()
    if not state then return end
    print("|cffff7a7aWarlock HUD:|r Healthstone distribution round " .. state.round)
    local count = 0
    for _, player in pairs(state.players) do
        count = count + 1
        print("|cffff7a7aWarlock HUD:|r " .. player.name .. " (" .. (player.class or "class unknown")
            .. ") supplied " .. date("%Y-%m-%d %H:%M", player.suppliedAt))
    end
    if count == 0 then print("|cffff7a7aWarlock HUD:|r No completed Healthstone trades recorded.") end
end

function WarlockHudDistributionSummary()
    local state = SuppliedPlayers()
    if not state then return "Unavailable" end
    local lines, count = {}, 0
    for _, player in pairs(state.players) do
        count = count + 1
        lines[#lines + 1] = player.name .. " (" .. (player.class or "class unknown") .. ")"
    end
    table.sort(lines)
    return "Round " .. state.round .. ": " .. count .. " supplied"
        .. (#lines > 0 and ("\n" .. table.concat(lines, ", ", 1, math.min(8, #lines))
            .. (#lines > 8 and ", ..." or "")) or "")
end

function WarlockHudResetDistribution()
    local state = SuppliedPlayers()
    if not state then return end
    state.round = state.round + 1
    state.players = {}
end

local tradeLines = {}
local tradeWindow, tradeText, tradeScroll, tradeStatus
local tradeToggle, soulstoneToggle, summonToggle, assignmentToggle

local function RefreshTradeWindow()
    if not tradeWindow then return end
    tradeStatus:SetText("Trade " .. (tradeDebug and "on" or "off")
        .. " / Soulstone " .. (soulstoneDebug and "on" or "off")
        .. " / Summon " .. (summonDebug and "on" or "off")
        .. " / Assignments " .. (assignmentDebug and "on" or "off"))
    if tradeToggle then
        tradeToggle:SetText("Trade: " .. (tradeDebug and "On" or "Off"))
    end
    if soulstoneToggle then
        soulstoneToggle:SetText("Soulstone: " .. (soulstoneDebug and "On" or "Off"))
    end
    if summonToggle then
        summonToggle:SetText("Summon: " .. (summonDebug and "On" or "Off"))
    end
    if assignmentToggle then
        assignmentToggle:SetText("Assignments: " .. (assignmentDebug and "On" or "Off"))
    end
    tradeText:SetText(table.concat(tradeLines, "\n"))
    tradeText:SetHeight(math.max(330, #tradeLines * 16 + 20))
    tradeScroll:UpdateScrollChildRect()
    tradeScroll:SetVerticalScroll(tradeScroll:GetVerticalScrollRange())
end

local function OpenTradeWindow()
    if not tradeWindow then
        local frame = CreateFrame("Frame", "WarlockHudTradeDebugWindow", UIParent)
        frame:SetSize(680, 470)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.06, 0.06, 0.08, 0.96)
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -14)
        title:SetText("Warlock HUD debug trace")
        tradeStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tradeStatus:SetPoint("TOPRIGHT", -42, -18)
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 16, -44)
        hint:SetText("Choose what to record below. Select All, then press Ctrl+C to copy.")
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -68)
        scroll:SetPoint("BOTTOMRIGHT", -34, 78)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(620)
        edit:SetHeight(330)
        edit:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scroll:SetScrollChild(edit)
        local selectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        selectAll:SetSize(110, 24)
        selectAll:SetPoint("BOTTOMLEFT", 16, 12)
        selectAll:SetText("Select All")
        selectAll:SetScript("OnClick", function()
            edit:SetFocus()
            edit:HighlightText()
        end)
        local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        clear:SetSize(80, 24)
        clear:SetPoint("LEFT", selectAll, "RIGHT", 8, 0)
        clear:SetText("Clear")
        clear:SetScript("OnClick", function()
            tradeLines = {}
            RefreshTradeWindow()
        end)
        tradeToggle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        tradeToggle:SetSize(110, 24)
        tradeToggle:SetPoint("LEFT", clear, "RIGHT", 18, 0)
        tradeToggle:SetScript("OnClick", function()
            tradeDebug = not tradeDebug
            RefreshTradeWindow()
        end)
        soulstoneToggle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        soulstoneToggle:SetSize(135, 24)
        soulstoneToggle:SetPoint("LEFT", tradeToggle, "RIGHT", 8, 0)
        soulstoneToggle:SetScript("OnClick", function()
            soulstoneDebug = not soulstoneDebug
            RefreshTradeWindow()
        end)
        summonToggle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        summonToggle:SetSize(110, 24)
        summonToggle:SetPoint("LEFT", soulstoneToggle, "RIGHT", 8, 0)
        summonToggle:SetScript("OnClick", function()
            summonDebug = not summonDebug
            RefreshTradeWindow()
        end)
        assignmentToggle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        assignmentToggle:SetSize(145, 24)
        assignmentToggle:SetPoint("BOTTOMLEFT", 16, 42)
        assignmentToggle:SetScript("OnClick", function()
            assignmentDebug = not assignmentDebug
            RefreshTradeWindow()
            if assignmentDebug and WarlockHudAssignmentTraceState then
                WarlockHudAssignmentTraceState()
            end
        end)
        local syncState = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        syncState:SetSize(110, 24)
        syncState:SetPoint("LEFT", assignmentToggle, "RIGHT", 8, 0)
        syncState:SetText("Sync State")
        syncState:SetScript("OnClick", function()
            if WarlockHudAssignmentTraceState then WarlockHudAssignmentTraceState() end
        end)
        tradeWindow, tradeText, tradeScroll = frame, edit, scroll
    end
    tradeWindow:Show()
    RefreshTradeWindow()
end

function WarlockHudOpenDebugTrace()
    OpenTradeWindow()
end

function WarlockHudToggleTradeDebug()
    tradeDebug = not tradeDebug
    OpenTradeWindow()
end

function WarlockHudToggleSoulstoneDebug()
    soulstoneDebug = not soulstoneDebug
    OpenTradeWindow()
end

function WarlockHudSummonDebugEnabled()
    return summonDebug
end

function WarlockHudTraceSummon(event, details)
    if not summonDebug then return end
    tradeLines[#tradeLines + 1] = date("%H:%M:%S") .. " SUMMON " .. event
        .. (details and (" " .. details) or "")
    if #tradeLines > 200 then table.remove(tradeLines, 1) end
    RefreshTradeWindow()
end

function WarlockHudTraceAssignment(event, details, force)
    if not assignmentDebug and not force then return end
    tradeLines[#tradeLines + 1] = date("%H:%M:%S") .. " ASSIGN " .. event
        .. (details and (" " .. details) or "")
    if #tradeLines > 200 then table.remove(tradeLines, 1) end
    RefreshTradeWindow()
end

local function TraceTrade(event, details)
    if not tradeDebug then return end
    tradeLines[#tradeLines + 1] = date("%H:%M:%S") .. " " .. event
        .. (details and (" " .. details) or "")
    if #tradeLines > 200 then table.remove(tradeLines, 1) end
    RefreshTradeWindow()
end

TraceSoulstone = function(event, details)
    if not soulstoneDebug then return end
    tradeLines[#tradeLines + 1] = date("%H:%M:%S") .. " SOULSTONE " .. event
        .. (details and (" " .. details) or "")
    if #tradeLines > 200 then table.remove(tradeLines, 1) end
    RefreshTradeWindow()
end

local function TradeSlots()
    local slots = {}
    if not GetTradePlayerItemLink then return "slots unavailable" end
    for slot = 1, 6 do
        local ok, link = pcall(GetTradePlayerItemLink, slot)
        if ok and (not issecretvalue or not issecretvalue(link))
            and type(link) == "string" then
            local itemID = link:match("|Hitem:(%d+)")
            slots[#slots + 1] = slot .. ":" .. (itemID or "?")
        end
    end
    return #slots > 0 and table.concat(slots, ",") or "empty"
end

local SOULSTONE_ITEMS = api.Stones[2].ids
local HEALTHSTONES = {}
for _, itemID in ipairs(api.Stones[1].ids) do HEALTHSTONES[itemID] = true end

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

local autoPlacedThisTrade = false
local tradeGeneration = 0
local function TradeIsEmpty()
    if not GetTradePlayerItemLink or not GetTradeTargetItemLink then
        return false, "trade item API unavailable"
    end
    for slot = 1, 7 do
        local okPlayer, playerLink = pcall(GetTradePlayerItemLink, slot)
        local okTarget, targetLink = pcall(GetTradeTargetItemLink, slot)
        if not okPlayer or not okTarget or not Public(playerLink) and playerLink ~= nil
            or not Public(targetLink) and targetLink ~= nil
            or playerLink or targetLink then return false, "trade slots occupied or unavailable" end
    end
    if not GetPlayerTradeMoney or not GetTargetTradeMoney then
        return false, "trade money API unavailable"
    end
    local okPlayerMoney, playerMoney = pcall(GetPlayerTradeMoney)
    if not okPlayerMoney or not Public(playerMoney) or playerMoney ~= 0 then
        return false, "player money occupied or unavailable"
    end
    local okTargetMoney, targetMoney = pcall(GetTargetTradeMoney)
    if not okTargetMoney or not Public(targetMoney) or targetMoney ~= 0 then
        return false, "partner money occupied or unavailable"
    end
    return true
end

local function FindBestHealthstone()
    if not C_Container or not C_Container.GetContainerNumSlots
        or not C_Container.GetContainerItemInfo then return nil end
    for _, itemID in ipairs(api.Stones[1].ids) do
        for bag = 0, NUM_BAG_SLOTS or 4 do
            local okCount, count = pcall(C_Container.GetContainerNumSlots, bag)
            if okCount and Public(count) and type(count) == "number" then
                for slot = 1, count do
                    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                    if ok and Public(info) and info and Public(info.itemID)
                        and info.itemID == itemID
                        and (not issecretvalue or not issecretvalue(info.isLocked))
                        and info.isLocked ~= true
                        and Public(info.stackCount) and info.stackCount > 0 then
                        return bag, slot, itemID
                    end
                end
            end
        end
    end
end

local function AutoPlaceHealthstone()
    if StoneOptions().autoPlaceHealthstone ~= true then
        TraceTrade("AUTO_PLACE", "skipped: setting off")
        return
    end
    if not tradeCandidate then TraceTrade("AUTO_PLACE", "skipped: group partner unknown"); return end
    if autoPlacedThisTrade then TraceTrade("AUTO_PLACE", "skipped: already attempted"); return end
    if InCombatLockdown() then TraceTrade("AUTO_PLACE", "skipped: combat"); return end
    local empty, reason = TradeIsEmpty()
    if not empty then TraceTrade("AUTO_PLACE", "skipped: " .. reason); return end
    if not C_Container or not C_Container.PickupContainerItem
        or not ClickTradeButton or not GetCursorInfo then
        TraceTrade("AUTO_PLACE", "skipped: placement API unavailable")
        return
    end
    local cursorType = GetCursorInfo()
    if cursorType ~= nil then
        TraceTrade("AUTO_PLACE", "skipped: cursor occupied or unavailable")
        return
    end
    local bag, slot = FindBestHealthstone()
    if not bag then TraceTrade("AUTO_PLACE", "skipped: no unlocked Healthstone in bags"); return end
    local checked, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if not checked or not Public(info) or not info then
        TraceTrade("AUTO_PLACE", "skipped: bag item unavailable")
        return
    end
    local split = info and Public(info.stackCount) and info.stackCount > 1
    if split and not C_Container.SplitContainerItem then
        TraceTrade("AUTO_PLACE", "skipped: stack split API unavailable")
        return
    end
    local picked
    if split then
        picked = pcall(C_Container.SplitContainerItem, bag, slot, 1)
    else
        picked = pcall(C_Container.PickupContainerItem, bag, slot)
    end
    if not picked then TraceTrade("AUTO_PLACE", "skipped: pickup failed"); return end
    local cursor = GetCursorInfo()
    if not Public(cursor) or cursor ~= "item" then
        TraceTrade("AUTO_PLACE", "skipped: item not on cursor")
        return
    end
    autoPlacedThisTrade = true
    local placed = pcall(ClickTradeButton, 1)
    TraceTrade("AUTO_PLACE", "item=" .. api.Stones[1].name
        .. " result=" .. (placed and "called" or "failed"))
end

events:RegisterEvent("UNIT_SPELLCAST_SENT")
events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
events:RegisterEvent("UNIT_SPELLCAST_FAILED")
events:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
events:RegisterEvent("TRADE_SHOW")
events:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED")
events:RegisterEvent("TRADE_TARGET_ITEM_CHANGED")
events:RegisterEvent("TRADE_ACCEPT_UPDATE")
events:RegisterEvent("TRADE_CLOSED")
events:RegisterEvent("TRADE_REQUEST_CANCEL")
events:RegisterEvent("UI_INFO_MESSAGE")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_UNGHOST")
events:SetScript("OnEvent", function(_, event, ...)
    if not api.IsAddonEnabled() then return end
    if event == "PLAYER_LOGIN" then
        local state = SoulstoneState()
        if state and state.status == "APPLIED" then
            state.status = "LAST APPLIED / UNKNOWN"
            state.statusAt = time()
            state.observed = false
        elseif state and (state.status == "USED"
            or state.status == "PENDING RESURRECTION") then
            state.status = "LOST / UNKNOWN"
            state.statusAt = time()
            state.observed = false
        end
        if C_Timer and C_Timer.After then C_Timer.After(1, RecheckSoulstone) end
    elseif event == "PLAYER_DEAD" then
        if not lastPlayerDeathAt or GetTime() - lastPlayerDeathAt > 1 then
            lastPlayerDeathAt = GetTime()
        end
        TraceSoulstone(event, "self died; aura check deferred until safe")
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        TraceSoulstone(event, "self returned; checking aura when safe")
        RecheckSoulstone()
    elseif event == "UNIT_SPELLCAST_SENT" then
        local unit, target, castGUID, spellID = ...
        if unit ~= "player" or not Public(spellID) then return end
        if spellID == 698 or IsSoulstoneCast(spellID) then
            local label = TargetLabel(target)
            if Public(castGUID) then pendingCasts[castGUID] = label end
            if spellID ~= 698 then
                TraceSoulstone("SENT", "spell=" .. spellID .. " target=" .. label
                    .. " cast=" .. (Public(castGUID) and castGUID or "unknown"))
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        if unit ~= "player" or not Public(spellID) then return end
        if soulstoneDebug and lastPlayerDeathAt
            and GetTime() - lastPlayerDeathAt < 60 then
            TraceSoulstone("POST_DEATH_CAST", "spell=" .. spellID)
        end
        if spellID == 698 then
            local label = Public(castGUID) and pendingCasts[castGUID] or "your target"
            local queueClicked = WarlockHudConsumeSummonQueueRecipient
                and WarlockHudConsumeSummonQueueRecipient()
            if label == "your target" then
                label = queueClicked or label
            end
            WarlockHudTraceSummon("ANNOUNCEMENT", "recipient=" .. label
                .. " source=" .. (queueClicked and "queue click"
                    or "cast event/fallback"))
            local count = api.GetSoulShardCount and api.GetSoulShardCount()
            local shardText = count and (" " .. count .. " Soul Shard"
                .. (count == 1 and "" or "s") .. " left.") or ""
            Notify("notifySummon", "Summoning " .. label
                .. ". Please click the portal." .. shardText)
        end
        if IsSoulstoneCast(spellID) then
            local label = Public(castGUID) and pendingCasts[castGUID] or "your target"
            TraceSoulstone("SUCCEEDED", "spell=" .. spellID .. " target=" .. label)
            AnnounceSoulstone(label)
            local state = SoulstoneState()
            if state then
                local unit, guid = FindRecipient(label)
                TraceSoulstone("RECIPIENT", "unit=" .. (unit or "unknown")
                    .. " guid=" .. (guid and "known" or "unknown"))
                state.recipientName = label
                state.recipientGUID = guid
                state.status = "APPLIED"
                state.statusAt = nil
                state.observed = false
                state.expiresAt = nil
                state.appliedAt = time()
                if unit then ObserveSoulstone(unit) end
                if C_Timer and C_Timer.After then
                    local appliedAt = state.appliedAt
                    for _, delay in ipairs({ 0.2, 1, 3 }) do
                        C_Timer.After(delay, function()
                            local current = SoulstoneState()
                            if current and current.appliedAt == appliedAt then
                                RecheckSoulstone()
                            end
                        end)
                    end
                end
            end
        end
        if Public(castGUID) then pendingCasts[castGUID] = nil end
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit, castGUID = ...
        if unit == "player" and Public(castGUID) and pendingCasts[castGUID] then
            TraceSoulstone(event, "target=" .. pendingCasts[castGUID])
        end
        if unit == "player" and Public(castGUID) then pendingCasts[castGUID] = nil end
    elseif event == "TRADE_SHOW" then
        tradeGeneration = tradeGeneration + 1
        autoPlacedThisTrade = false
        tradeHasHealthstone = false
        tradeStoneClearedAt = nil
        tradeClosedAt = nil
        tradeCandidate = nil
        acceptedTrade = nil
        local name = UnitName("NPC")
        tradePartner = Public(name) and name or "your trade partner"
        local guid, groupName, class = GroupPartner()
        if guid then
            tradeCandidate = { guid = guid, name = groupName, class = class }
        end
        if tradeDebug then
            TraceTrade(event, "partner=" .. tradePartner
                .. " group match=" .. tostring(tradeCandidate ~= nil)
                .. " slots=" .. TradeSlots())
        end
        if tradeCandidate and C_Timer and C_Timer.After then
            local generation = tradeGeneration
            TraceTrade("AUTO_PLACE", "scheduled")
            C_Timer.After(0.1, function()
                if generation == tradeGeneration then AutoPlaceHealthstone() end
            end)
        elseif tradeCandidate then
            TraceTrade("AUTO_PLACE", "skipped: timer API unavailable")
        end
    elseif event == "TRADE_PLAYER_ITEM_CHANGED" then
        tradeHasHealthstone = IsHealthstoneInTrade()
        if not tradeHasHealthstone then
            if acceptedTrade and not tradeStoneClearedAt then
                tradeStoneClearedAt = GetTime()
            end
        elseif not tradeCandidate then
            local guid, groupName, class = GroupPartner()
            if guid then
                tradeCandidate = { guid = guid, name = groupName, class = class }
            end
        end
        if tradeHasHealthstone then tradeStoneClearedAt = nil end
        if tradeDebug then
            TraceTrade(event, "slots=" .. TradeSlots()
                .. " healthstone=" .. tostring(tradeHasHealthstone))
        end
    elseif event == "TRADE_TARGET_ITEM_CHANGED" then
        if tradeDebug then TraceTrade(event, "player slots=" .. TradeSlots()) end
    elseif event == "TRADE_ACCEPT_UPDATE" then
        local playerAccepted, targetAccepted = ...
        if tradeDebug then
            local player = Public(playerAccepted) and tostring(playerAccepted) or "secret"
            local target = Public(targetAccepted) and tostring(targetAccepted) or "secret"
            TraceTrade(event, "player=" .. player .. " target=" .. target
                .. " slots=" .. TradeSlots())
        end
        if Public(playerAccepted) and Accepted(playerAccepted)
            and tradeHasHealthstone and tradeCandidate then
            acceptedTrade = {
                guid = tradeCandidate.guid, name = tradeCandidate.name,
                class = tradeCandidate.class, acceptedAt = GetTime(),
            }
            tradeStoneClearedAt = nil
        elseif Public(playerAccepted) and Accepted(playerAccepted) then
            acceptedTrade = nil
            tradeStoneClearedAt = nil
        end
    elseif event == "TRADE_CLOSED" or event == "TRADE_REQUEST_CANCEL" then
        tradeGeneration = tradeGeneration + 1
        if event == "TRADE_CLOSED" then tradeClosedAt = GetTime() end
        if tradeDebug then
            TraceTrade(event, "last healthstone=" .. tostring(tradeHasHealthstone))
        end
        tradeHasHealthstone = false
        tradePartner = nil
        if event == "TRADE_REQUEST_CANCEL" then
            acceptedTrade = nil
            tradeStoneClearedAt = nil
            tradeClosedAt = nil
        end
    elseif event == "UI_INFO_MESSAGE" or event == "CHAT_MSG_SYSTEM" then
        local first, second = ...
        local message = event == "UI_INFO_MESSAGE" and second or first
        if Public(message) and type(message) == "string" then
            local complete = event == "UI_INFO_MESSAGE"
                and ((Public(ERR_TRADE_COMPLETE) and message == ERR_TRADE_COMPLETE)
                    or (first == 251 and message == "Trade complete."))
            local cancelled = Public(ERR_TRADE_CANCELLED) and message == ERR_TRADE_CANCELLED
            if tradeDebug and (complete or cancelled or message:lower():find("trad", 1, true)) then
                local id = Public(first) and tostring(first) or "secret"
                TraceTrade(event, "id=" .. id .. " message=" .. message)
            end
            if complete and acceptedTrade and GetTime() - acceptedTrade.acceptedAt < 30
                and (not tradeClosedAt or GetTime() - tradeClosedAt < 2)
                and (not tradeStoneClearedAt or GetTime() - tradeStoneClearedAt < 2) then
                Notify("notifyHealthstone", "Healthstone trade completed with "
                    .. acceptedTrade.name .. ".")
                local state = SuppliedPlayers()
                if state and StoneOptions().distributionTracker ~= false then
                    state.players[acceptedTrade.guid] = {
                        name = acceptedTrade.name, class = acceptedTrade.class,
                        suppliedAt = time(),
                    }
                    TraceTrade("DISTRIBUTION", "recorded " .. acceptedTrade.name)
                    if StoneOptions().notifyDistribution == true then
                        print("|cffff7a7aWarlock HUD:|r Healthstone supplied to "
                            .. acceptedTrade.name .. ".")
                    end
                end
                acceptedTrade = nil
                tradeStoneClearedAt = nil
                tradeClosedAt = nil
            elseif complete then
                TraceTrade("DISTRIBUTION", "not recorded: no recent accepted Healthstone trade")
                acceptedTrade = nil
                tradeStoneClearedAt = nil
                tradeClosedAt = nil
            elseif cancelled then
                acceptedTrade = nil
                tradeStoneClearedAt = nil
                tradeClosedAt = nil
            end
        end
    elseif event == "UNIT_AURA" then
        local unit = ...
        if type(unit) == "string" then
            local state = SoulstoneState()
            if soulstoneDebug and state and state.recipientGUID then
                local guid = UnitGUID(unit)
                if Public(guid) and guid == state.recipientGUID then
                    TraceSoulstone(event, unit .. (InCombatLockdown()
                        and " deferred in combat" or " checking"))
                end
            end
            ObserveSoulstone(unit)
        end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "GROUP_ROSTER_UPDATE" then
        RecheckSoulstone()
    end
end)
