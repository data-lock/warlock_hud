local api = WarlockHudAPI
local window, scroll, scrollBar, content, queueStatus
local rows = {}
local elapsed = 0
local pendingRefresh = false
local manualOpen = false
local dismissed = false
local clickedRecipient
local demoEntries
local ROW_HEIGHT = 29
local MAX_VISIBLE = 8

local function SyncContentWidth(frame)
    content:SetWidth(math.max(1, frame:GetWidth() - 44))
    for _, row in ipairs(rows) do row.frame:SetWidth(content:GetWidth()) end
end

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
    local scale = math.max(0.5, math.min(1,
        tonumber(settings and settings.scale) or 1))
    window:SetScale(scale)
    window:ClearAllPoints()
    if settings and type(settings.x) == "number" and type(settings.y) == "number" then
        window:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            settings.x * UIParent:GetWidth() / scale,
            settings.y * UIParent:GetHeight() / scale)
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 260 / scale, 0)
    end
    if settings and type(settings.width) == "number" then
        window:SetWidth(math.max(370, math.min(650, settings.width)))
    end
    if settings and type(settings.height) == "number" then
        window:SetHeight(math.max(130, math.min(420, settings.height)))
    end
end

function WarlockHudSetSummonQueueWindowScale(value)
    local settings = PositionSettings()
    if not settings then return end
    settings.scale = math.max(0.5, math.min(1, tonumber(value) or 1))
    if window then ApplyPosition() end
end

local function WaitText(entry)
    local seconds = math.max(0, math.floor(GetTime() - entry.requestedAt))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function MakeDemoEntries()
    local names = {
        "Bristle North", "Aelwyn Moonfall", "Thorn Blackwater",
        "Mira Suncrest", "Kael Emberwood", "Vesper Ash",
        "Liora Dawnshield", "Garron Stone", "Nyssa Vale",
        "Torren Dusk", "Selene Bright", "Darian Hollow",
        "Riven Frost", "Yara Windward", "Mordecai Flint",
    }
    local entries = {}
    local now = GetTime()
    local classes = {
        "WARRIOR", "MAGE", "ROGUE", "PRIEST", "HUNTER",
        "WARLOCK", "PALADIN", "DRUID", "SHAMAN", "MAGE",
        "WARRIOR", "PRIEST", "ROGUE", "HUNTER", "WARLOCK",
    }
    for index, name in ipairs(names) do
        entries[index] = {
            guid = "demo-" .. index,
            fullName = name:gsub(" ", "-"),
            chatName = name,
            class = classes[index],
            requestedAt = now - math.random(15, 900),
        }
    end
    table.sort(entries, function(a, b) return a.requestedAt < b.requestedAt end)
    for index, entry in ipairs(entries) do
        entry.summonPending = index == 2 or index == 5
            or index == 9 or index == 13
    end
    return entries
end

local function CreateRowButton(parent, width, height, label, isRemove, secure)
    local template = secure and "SecureActionButtonTemplate" or nil
    local button = CreateFrame("Button", nil, parent, template)
    button:SetSize(width, height)
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(button)
    background:SetColorTexture(0.035, 0.035, 0.045, 0.78)
    local border = {}
    border[1] = button:CreateTexture(nil, "OVERLAY")
    border[1]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border[1]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    border[1]:SetHeight(1)
    border[2] = button:CreateTexture(nil, "OVERLAY")
    border[2]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    border[2]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    border[2]:SetHeight(1)
    border[3] = button:CreateTexture(nil, "OVERLAY")
    border[3]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border[3]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    border[3]:SetWidth(1)
    border[4] = button:CreateTexture(nil, "OVERLAY")
    border[4]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    border[4]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    border[4]:SetWidth(1)
    local text, mark1, mark2
    if isRemove then
        mark1 = button:CreateTexture(nil, "OVERLAY")
        mark1:SetSize(9, 1.25)
        mark1:SetPoint("CENTER", button, "CENTER", 0, 0)
        mark1:SetRotation(math.pi / 4)
        mark2 = button:CreateTexture(nil, "OVERLAY")
        mark2:SetSize(9, 1.25)
        mark2:SetPoint("CENTER", button, "CENTER", 0, 0)
        mark2:SetRotation(-math.pi / 4)
    else
        text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER", button, "CENTER", 0, 0)
        text:SetText(label)
    end
    local function SetState(hovered)
        if isRemove then
            background:SetColorTexture(hovered and 0.20 or 0.035,
                hovered and 0.07 or 0.035, hovered and 0.065 or 0.045,
                hovered and 0.95 or 0.55)
            local red, green, blue = hovered and 1 or 0.78,
                hovered and 0.48 or 0.68, hovered and 0.42 or 0.58
            if text then text:SetTextColor(red, green, blue) end
            if mark1 then mark1:SetColorTexture(red, green, blue, 1) end
            if mark2 then mark2:SetColorTexture(red, green, blue, 1) end
            for _, edge in ipairs(border) do
                edge:SetColorTexture(hovered and 1 or 0.86,
                    hovered and 0.35 or 0.66, hovered and 0.28 or 0.25,
                    hovered and 0.9 or 0.45)
            end
        else
            background:SetColorTexture(hovered and 0.20 or 0.035,
                hovered and 0.13 or 0.035, hovered and 0.08 or 0.045,
                hovered and 0.95 or 0.78)
            if text then
                text:SetTextColor(1, hovered and 0.88 or 0.82,
                    hovered and 0.48 or 0.2)
            end
            for _, edge in ipairs(border) do
                edge:SetColorTexture(1, 0.82, 0.2, hovered and 0.95 or 0.5)
            end
        end
    end
    SetState(false)
    button:SetScript("OnEnter", function() SetState(true) end)
    button:SetScript("OnLeave", function() SetState(false) end)
    return button
end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, content)
    row:SetSize(386, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    local number = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    number:SetPoint("LEFT", row, "LEFT", 2, 0)
    number:SetWidth(22)
    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
    local summon = CreateRowButton(row, 76, 18, "Summon", false, true)
    summon:SetPoint("RIGHT", row, "RIGHT", -32, 0)
    summon:SetAttribute("type", "macro")
    summon:SetAttribute("useOnKeyDown", false)
    summon:RegisterForClicks("AnyUp", "AnyDown")
    summon:HookScript("PostClick", function()
        local current = rows[index]
        if current and current.demo then
            print("|cffff7a7aWarlock HUD:|r Demo request; no summon was cast.")
            return
        end
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
    local remove = CreateRowButton(row, 20, 20, "x", true, false)
    remove:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    remove:SetScript("OnClick", function()
        if demoEntries then
            table.remove(demoEntries, index)
            WarlockHudSummonQueueChanged()
            return
        end
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
    frame:SetSize(410, 130)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(370, 130, 650, 420)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    local title = WarlockHudWindowChrome.Apply(frame, "Summon Requests", function()
        demoEntries = nil
        dismissed = true
        manualOpen = false
        local settings = PositionSettings()
        if settings then settings.open = false end
        if InCombatLockdown() then
            pendingRefresh = true
            print("|cffff7a7aWarlock HUD:|r Summon window will close after combat.")
        else
            frame:Hide()
        end
    end, 0.5)
    frame.title = title
    local announce = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    announce:SetSize(84, 18)
    announce:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 10)
    announce:SetText("Announce")
    WarlockHudWindowChrome.StyleButton(announce)
    announce:SetScript("OnClick", function()
        if demoEntries then
            print("|cffff7a7aWarlock HUD:|r Demo request; no chat message was sent.")
            return
        end
        if not IsInGroup() and not (LE_PARTY_CATEGORY_INSTANCE
            and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then
            print("|cffff7a7aWarlock HUD:|r Join a group before announcing summons.")
            return
        end
        if not C_ChatInfo or not C_ChatInfo.SendChatMessage then return end
        local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT"
            or IsInRaid() and "RAID" or "PARTY"
        local profile = api.GetProfile()
        local keywords = profile and profile.summonKeywords
            or api.DefaultSummonKeywords
        local count = api.GetSoulShardCount and api.GetSoulShardCount()
        local shardText = count and (" I have " .. count .. " Soul Shard"
            .. (count == 1 and "" or "s") .. " left.") or ""
        local ok = pcall(C_ChatInfo.SendChatMessage,
            "Summons available! Type " .. keywords
                .. " here or whisper me to request one." .. shardText, channel)
        if not ok then
            print("|cffff7a7aWarlock HUD:|r Could not send the summon announcement.")
        end
    end)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(20, 20)
    grip:SetPoint("BOTTOMRIGHT", -1, 1)
    grip:SetFrameLevel(frame:GetFrameLevel() + 3)
    local gripIcon = grip:CreateTexture(nil, "ARTWORK")
    gripIcon:SetAllPoints()
    gripIcon:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    local resizing, startX, startY, startWidth, startHeight
    local startLeft, startTop
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or InCombatLockdown() then return end
        local x, y = GetCursorPosition()
        local left, top = frame:GetLeft(), frame:GetTop()
        if not x or not y or not left or not top then return end
        resizing = true
        startX, startY = x, y
        startWidth, startHeight = frame:GetSize()
        startLeft, startTop = left, top
        frame:ClearAllPoints()
        local scale = frame:GetScale()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            startLeft / scale, startTop / scale)
    end)
    grip:SetScript("OnUpdate", function()
        if not resizing then return end
        if InCombatLockdown() then resizing = false; return end
        local x, y = GetCursorPosition()
        if not x or not y then return end
        local scale = frame:GetEffectiveScale()
        local width = math.max(370, math.min(650,
            startWidth + (x - startX) / scale))
        local height = math.max(130, math.min(420,
            startHeight - (y - startY) / scale))
        frame:SetSize(width, height)
    end)
    grip:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not resizing then return end
        resizing = false
        SavePosition()
    end)
    scroll = CreateFrame("ScrollFrame", "WarlockHudSummonQueueScrollFrame",
        frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -60)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 35)
    if scroll.SetClipsChildren then scroll:SetClipsChildren(true) end
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(370, ROW_HEIGHT)
    scroll:SetScrollChild(content)
    scrollBar = scroll.ScrollBar
        or _G.WarlockHudSummonQueueScrollFrameScrollBar
    if WarlockHudWindowChrome and WarlockHudWindowChrome.StyleScrollbar then
        WarlockHudWindowChrome.StyleScrollbar(scrollBar)
    end
    queueStatus = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    queueStatus:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
    queueStatus:SetText("No summons in queue")
    queueStatus:SetShadowColor(0, 0, 0, 1)
    queueStatus:SetShadowOffset(1, -1)
    frame:SetScript("OnSizeChanged", function()
        if InCombatLockdown() then
            pendingRefresh = true
            return
        end
        SyncContentWidth(frame)
    end)
    window = frame
    ApplyPosition()
    frame:Hide()
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 1 then return end
        elapsed = 0
        local entries = demoEntries or WarlockHudGetSummonQueue()
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
    local settings = PositionSettings()
    if settings and settings.open == true then
        manualOpen = true
        dismissed = false
    end
    if not api.IsAddonEnabled() or not profile
        or (profile.summonQueueEnabled == false and not demoEntries) then
        if window then window:Hide() end
        if settings then settings.open = false end
        return
    end
    local entries = demoEntries or WarlockHudGetSummonQueue()
    if #entries == 0 and not manualOpen then
        if window then window:Hide() end
        if settings then settings.open = false end
        return
    end
    MakeWindow()
    SyncContentWidth(window)
    window.title:SetText(demoEntries and "Summon Demo" or "Summon Requests")
    local queueCount, pendingCasts = #entries, 0
    for _, entry in ipairs(entries) do
        if entry.summonPending then pendingCasts = pendingCasts + 1 end
    end
    local statusText = queueCount == 0 and "No summons in queue"
        or queueCount .. (queueCount == 1 and " summon in queue" or " summons in queue")
    if pendingCasts > 0 then
        statusText = statusText .. "; " .. pendingCasts
            .. (pendingCasts == 1 and " summon pending" or " summons pending")
    end
    queueStatus:SetText(statusText)
    local visible = math.min(#entries, MAX_VISIBLE)
    if not settings or not settings.height then
        window:SetHeight(96 + math.max(1, visible) * ROW_HEIGHT)
    end
    content:SetHeight(math.max(ROW_HEIGHT, #entries * ROW_HEIGHT))
    for index, entry in ipairs(entries) do
        local row = rows[index] or CreateRow(index)
        row.frame:SetWidth(content:GetWidth())
        row.guid = entry.guid
        row.unit = entry.unit
        row.demo = demoEntries ~= nil
        row.displayName = entry.chatName or entry.fullName
        row.number:SetText(index .. ".")
        row.name:SetText(row.displayName)
        local classColor = entry.class and RAID_CLASS_COLORS
            and RAID_CLASS_COLORS[entry.class]
        if classColor then
            row.name:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            row.name:SetTextColor(1, 1, 1)
        end
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
        row.summon:SetEnabled(row.demo or sameMember and true or false)
        row.frame:Show()
    end
    for index = #entries + 1, #rows do rows[index].frame:Hide() end
    scroll:UpdateScrollChildRect()
    if scrollBar then
        scrollBar:SetShown(scroll:GetVerticalScrollRange() > 0)
    end
    scroll:SetShown(#entries > 0)
    if not dismissed then
        window:Show()
        if settings then settings.open = true end
    else
        window:Hide()
        if settings then settings.open = false end
    end
end

function WarlockHudConsumeSummonQueueRecipient()
    local clicked = clickedRecipient
    clickedRecipient = nil
    if clicked and GetTime() - clicked.at <= 8 then return clicked.name end
end

function WarlockHudOpenSummonQueue()
    demoEntries = nil
    manualOpen = true
    dismissed = false
    local settings = PositionSettings()
    if settings then settings.open = true end
    WarlockHudSummonQueueChanged()
end

function WarlockHudOpenSummonQueueDemo()
    if InCombatLockdown() then
        print("|cffff7a7aWarlock HUD:|r Open the summon demo after combat.")
        return
    end
    demoEntries = MakeDemoEntries()
    manualOpen = true
    dismissed = false
    local settings = PositionSettings()
    if settings then settings.open = true end
    WarlockHudSummonQueueChanged()
    if scroll then scroll:SetVerticalScroll(0) end
end

function WarlockHudReopenSummonQueue()
    if not dismissed then return end
    dismissed = false
    local settings = PositionSettings()
    if settings then settings.open = true end
    WarlockHudSummonQueueChanged()
end

local restoreWindow = CreateFrame("Frame")
restoreWindow:RegisterEvent("PLAYER_ENTERING_WORLD")
restoreWindow:SetScript("OnEvent", function()
    local settings = PositionSettings()
    if settings and settings.open == true then
        manualOpen = true
        dismissed = false
        WarlockHudSummonQueueChanged()
    end
end)

local combatEvents = CreateFrame("Frame")
combatEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
combatEvents:SetScript("OnEvent", function()
    if pendingRefresh then WarlockHudSummonQueueChanged() end
end)
