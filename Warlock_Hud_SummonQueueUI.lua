local api = WarlockHudAPI
local window, scroll, content, lockButton, emptyLabel
local rows = {}
local elapsed = 0
local pendingRefresh = false
local manualOpen = false
local dismissed = false
local clickedRecipient
local ROW_HEIGHT = 34
local MAX_VISIBLE = 8

local function PositionSettings()
    local profile = api.GetProfile()
    if not profile then return nil end
    profile.summonQueueWindow = profile.summonQueueWindow or {}
    return profile.summonQueueWindow
end

local function SavePosition()
    local settings = PositionSettings()
    if not settings then return end
    local x, y = window:GetCenter()
    if x and y and UIParent:GetWidth() > 0 and UIParent:GetHeight() > 0 then
        settings.x = x / UIParent:GetWidth()
        settings.y = y / UIParent:GetHeight()
    end
    settings.width = window:GetWidth()
    settings.height = window:GetHeight()
end

local function ApplyPosition()
    local settings = PositionSettings()
    window:ClearAllPoints()
    if settings and type(settings.x) == "number" and type(settings.y) == "number" then
        window:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            settings.x * UIParent:GetWidth(), settings.y * UIParent:GetHeight())
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 260, 0)
    end
    lockButton:SetText(settings and settings.locked and "Unlock" or "Lock")
    if settings and type(settings.width) == "number" then
        window:SetWidth(math.max(370, math.min(650, settings.width)))
    end
    if settings and type(settings.height) == "number" then
        window:SetHeight(math.max(81, math.min(420, settings.height)))
    end
end

local function WaitText(entry)
    local seconds = math.max(0, math.floor(GetTime() - entry.requestedAt))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, content)
    row:SetSize(386, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    local number = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    number:SetPoint("LEFT", row, "LEFT", 2, 0)
    number:SetWidth(22)
    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", row, "LEFT", 28, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -190, 0)
    name:SetJustifyH("LEFT")
    local waiting = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    waiting:SetPoint("RIGHT", row, "RIGHT", -138, 0)
    waiting:SetWidth(48)
    local pending = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pending:SetPoint("RIGHT", row, "RIGHT", -138, -12)
    pending:SetWidth(54)
    pending:SetTextColor(1, 0.82, 0.2)
    local summon = CreateFrame("Button", nil, row,
        "SecureActionButtonTemplate,UIPanelButtonTemplate")
    summon:SetSize(88, 22)
    summon:SetPoint("RIGHT", row, "RIGHT", -42, 0)
    summon:SetText("Summon")
    summon:SetAttribute("type", "macro")
    summon:SetAttribute("useOnKeyDown", false)
    summon:RegisterForClicks("AnyUp", "AnyDown")
    summon:HookScript("PostClick", function()
        local current = rows[index]
        if not current or not current.guid or not current.unit then return end
        local guid = UnitGUID(current.unit)
        if not guid or (issecretvalue and issecretvalue(guid))
            or guid ~= current.guid then return end
        local now = GetTime()
        if clickedRecipient and clickedRecipient.guid == guid
            and now - clickedRecipient.at < 0.25 then return end
        clickedRecipient = { guid = guid, name = current.displayName, at = now }
        if WarlockHudTraceSummon then
            WarlockHudTraceSummon("QUEUE_CLICK", "recipient=" .. current.displayName)
        end
    end)
    local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    remove:SetSize(28, 22)
    remove:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    remove:SetText("X")
    remove:SetScript("OnClick", function()
        if rows[index] and rows[index].guid then
            WarlockHudRemoveSummonRequest(rows[index].guid)
        end
    end)
    rows[index] = { frame = row, number = number, name = name,
        waiting = waiting, pending = pending, summon = summon, remove = remove }
    return rows[index]
end

local function MakeWindow()
    if window then return end
    local frame = CreateFrame("Frame", "WarlockHudSummonQueueWindow", UIParent)
    frame:SetSize(410, 74)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(370, 81, 650, 420)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        local settings = PositionSettings()
        if not InCombatLockdown() and (not settings or not settings.locked) then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.06, 0.06, 0.08, 0.94)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText("Summon Requests")
    lockButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    lockButton:SetSize(66, 21)
    lockButton:SetPoint("TOPRIGHT", -42, -9)
    lockButton:SetScript("OnClick", function()
        local settings = PositionSettings()
        if not settings then return end
        settings.locked = not settings.locked
        lockButton:SetText(settings.locked and "Unlock" or "Lock")
    end)
    local announce = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    announce:SetSize(100, 21)
    announce:SetPoint("TOPRIGHT", -116, -9)
    announce:SetText("Announce")
    announce:SetScript("OnClick", function()
        if not IsInGroup() and not (LE_PARTY_CATEGORY_INSTANCE
            and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then
            print("|cffff7a7aWarlock HUD:|r Join a group before announcing summons.")
            return
        end
        if not C_ChatInfo or not C_ChatInfo.SendChatMessage then return end
        local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT"
            or IsInRaid() and "RAID" or "PARTY"
        local profile = api.GetProfile()
        local keyword = profile and profile.summonKeyword or "123"
        local count = api.GetSoulShardCount and api.GetSoulShardCount()
        local shardText = count and (" I have " .. count .. " Soul Shard"
            .. (count == 1 and "" or "s") .. " left.") or ""
        local ok = pcall(C_ChatInfo.SendChatMessage,
            "Summons available! Type " .. keyword
                .. " here or whisper me to request one." .. shardText, channel)
        if not ok then
            print("|cffff7a7aWarlock HUD:|r Could not send the summon announcement.")
        end
    end)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function()
        dismissed = true
        manualOpen = false
        if InCombatLockdown() then
            pendingRefresh = true
            print("|cffff7a7aWarlock HUD:|r Summon window will close after combat.")
        else
            frame:Hide()
        end
    end)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(20, 20)
    grip:SetPoint("BOTTOMRIGHT", -1, 1)
    grip:SetFrameLevel(frame:GetFrameLevel() + 3)
    local gripIcon = grip:CreateTexture(nil, "ARTWORK")
    gripIcon:SetAllPoints()
    gripIcon:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetScript("OnMouseDown", function()
        local settings = PositionSettings()
        if not InCombatLockdown() and (not settings or not settings.locked) then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SavePosition()
    end)
    scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -43)
    scroll:SetPoint("BOTTOMRIGHT", -10, 10)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(386, ROW_HEIGHT)
    scroll:SetScrollChild(content)
    emptyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -54)
    emptyLabel:SetText("No pending requests")
    emptyLabel:Hide()
    frame:SetScript("OnSizeChanged", function()
        if InCombatLockdown() then
            pendingRefresh = true
            return
        end
        content:SetWidth(math.max(350, scroll:GetWidth()))
        for _, row in ipairs(rows) do row.frame:SetWidth(content:GetWidth()) end
    end)
    window = frame
    ApplyPosition()
    frame:Hide()
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 1 then return end
        elapsed = 0
        local entries = WarlockHudGetSummonQueue()
        for index, entry in ipairs(entries) do
            if rows[index] then
                rows[index].waiting:SetText(WaitText(entry))
                rows[index].pending:SetText(entry.summonPending and "Pending" or "")
            end
        end
    end)
end

function WarlockHudSummonQueueChanged()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end
    pendingRefresh = false
    local profile = api.GetProfile()
    if not api.IsAddonEnabled() or not profile
        or profile.summonQueueEnabled == false then
        if window then window:Hide() end
        return
    end
    local entries = WarlockHudGetSummonQueue()
    if #entries == 0 and not manualOpen then
        if window then window:Hide() end
        return
    end
    MakeWindow()
    local visible = math.min(#entries, MAX_VISIBLE)
    local settings = PositionSettings()
    if not settings or not settings.height then
        window:SetHeight(53 + math.max(1, visible) * ROW_HEIGHT)
    end
    content:SetHeight(math.max(ROW_HEIGHT, #entries * ROW_HEIGHT))
    for index, entry in ipairs(entries) do
        local row = rows[index] or CreateRow(index)
        row.frame:SetWidth(content:GetWidth())
        row.guid = entry.guid
        row.unit = entry.unit
        row.displayName = entry.chatName or entry.fullName
        row.number:SetText(index .. ".")
        row.name:SetText(row.displayName)
        row.waiting:SetText(WaitText(entry))
        row.pending:SetText(entry.summonPending and "Pending" or "")
        local spellName = C_Spell and C_Spell.GetSpellName
            and C_Spell.GetSpellName(698) or "Ritual of Summoning"
        if issecretvalue and issecretvalue(spellName) then spellName = nil end
        if type(spellName) ~= "string" or spellName == "" then
            spellName = "Ritual of Summoning"
        end
        local validUnit = type(entry.unit) == "string"
            and (entry.unit:match("^party%d+$") or entry.unit:match("^raid%d+$"))
        local currentGUID = validUnit and UnitGUID(entry.unit)
        if issecretvalue and issecretvalue(currentGUID) then currentGUID = nil end
        local sameMember = currentGUID and currentGUID == entry.guid
        if sameMember then
            local targetName = type(entry.chatName) == "string"
                and entry.chatName ~= ""
                and not entry.chatName:find("[%c/;]")
                and entry.chatName or entry.unit
            row.summon:SetAttribute("macrotext",
                "/target " .. targetName .. "\n/cast " .. spellName)
        else
            row.summon:SetAttribute("macrotext", nil)
        end
        row.summon:SetEnabled(sameMember and true or false)
        row.frame:Show()
    end
    for index = #entries + 1, #rows do rows[index].frame:Hide() end
    scroll:UpdateScrollChildRect()
    emptyLabel:SetShown(#entries == 0)
    scroll:SetShown(#entries > 0)
    if not dismissed then window:Show() end
end

function WarlockHudConsumeSummonQueueRecipient()
    local clicked = clickedRecipient
    clickedRecipient = nil
    if clicked and GetTime() - clicked.at <= 8 then return clicked.name end
end

function WarlockHudOpenSummonQueue()
    manualOpen = true
    dismissed = false
    WarlockHudSummonQueueChanged()
end

function WarlockHudReopenSummonQueue()
    if not dismissed then return end
    dismissed = false
    WarlockHudSummonQueueChanged()
end

local combatEvents = CreateFrame("Frame")
combatEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
combatEvents:SetScript("OnEvent", function()
    if pendingRefresh then WarlockHudSummonQueueChanged() end
end)
