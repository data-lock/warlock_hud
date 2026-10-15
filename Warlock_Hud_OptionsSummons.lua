-- Summon queue settings page.
WarlockHudOptionsSummons = {}

function WarlockHudOptionsSummons.Build(context)
    local api = context.api
    local Panel, Text, Check, Button = context.Panel, context.Text, context.Check, context.Button
    local ResetPageButton = context.ResetPageButton
    local Profile, MarkChanged = context.Profile, context.MarkChanged
    local refreshers = context.refreshers

    local summons = Panel("Warlock HUD - Summons", false)
    Text(summons, "Summon Request Queue", 20, -55, "GameFontNormal")
    Text(summons, "Request keywords", 20, -92, "GameFontHighlight")
    local summonKeywordInput = CreateFrame("EditBox", nil, summons, "InputBoxTemplate")
    summonKeywordInput:SetSize(300, 24)
    summonKeywordInput:SetPoint("TOPLEFT", summons, "TOPLEFT", 175, -82)
    summonKeywordInput:SetAutoFocus(false)
    summonKeywordInput:SetMaxLetters(142)
    summonKeywordInput:SetFontObject(ChatFontNormal)
    local summonKeywordDisplay = summonKeywordInput:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    summonKeywordDisplay:SetPoint("LEFT", summonKeywordInput, "LEFT", 6, 0)
    summonKeywordDisplay:SetWidth(286)
    summonKeywordDisplay:SetJustifyH("LEFT")
    summonKeywordDisplay:SetText(api.DefaultSummonKeywords)
    Text(summons, "Default: 123, sum, summ", 175, -116,
        "GameFontHighlightSmall")
    local summonKeywordHint = Text(summons,
        "Separate with commas. Up to 8 words, 1-16 letters or digits each. Exact message match.",
        20, -140, "GameFontHighlightSmall")
    summonKeywordHint:SetWidth(650)
    summonKeywordHint:SetJustifyH("LEFT")
    local function SaveSummonKeyword(self)
        local value = api.NormalizeSummonKeywords(self:GetText())
        if value then
            if Profile().summonKeywords ~= value then
                Profile().summonKeywords = value
                MarkChanged(false)
            end
        else
            print("|cffff7a7aWarlock HUD:|r Enter 1-8 comma-separated words, each 1-16 letters or digits.")
        end
    end
    local function RefreshSummonKeywordInput()
        local profile = Profile()
        local keyword = profile and profile.summonKeywords
        if type(keyword) ~= "string" or keyword == "" then
            keyword = api.DefaultSummonKeywords
            if profile then profile.summonKeywords = keyword end
        end
        if not summonKeywordInput:HasFocus() then
            summonKeywordInput:SetText("")
            summonKeywordDisplay:SetText(keyword)
            summonKeywordDisplay:Show()
        end
    end
    local editingSummonKeyword = false
    summonKeywordInput:SetScript("OnEditFocusGained", function(self)
        editingSummonKeyword = true
        summonKeywordDisplay:Hide()
        self:SetText(Profile() and Profile().summonKeywords
            or api.DefaultSummonKeywords)
        self:HighlightText()
    end)
    summonKeywordInput:SetScript("OnEnterPressed", function(self)
        SaveSummonKeyword(self)
        editingSummonKeyword = false
        self:ClearFocus()
        RefreshSummonKeywordInput()
    end)
    summonKeywordInput:SetScript("OnEscapePressed", function(self)
        editingSummonKeyword = false
        self:ClearFocus()
        RefreshSummonKeywordInput()
    end)
    summonKeywordInput:SetScript("OnEditFocusLost", function(self)
        if editingSummonKeyword then SaveSummonKeyword(self) end
        editingSummonKeyword = false
        RefreshSummonKeywordInput()
    end)
    refreshers[#refreshers + 1] = function()
        RefreshSummonKeywordInput()
    end
    summons:HookScript("OnShow", function()
        RefreshSummonKeywordInput()
    end)
    Text(summons, "Open the queue with /whub summonqueue. Announce lists these words.",
        20, -163, "GameFontHighlightSmall")
    Button(summons, "Open Summon Queue", 20, -199, 180, function()
        if WarlockHudOpenSummonQueue then WarlockHudOpenSummonQueue() end
    end)
    Button(summons, "Preview 15 requests", 215, -199, 180, function()
        if WarlockHudOpenSummonQueueDemo then WarlockHudOpenSummonQueueDemo() end
    end)
    Text(summons, "Demo uses sample names; its buttons do not cast or announce.",
        20, -229, "GameFontHighlightSmall")
    Check(summons, 20, -250, "Enable summon request queue",
        function() return Profile().summonQueueEnabled ~= false end,
        function(value)
            Profile().summonQueueEnabled = value
            if not value and WarlockHudClearSummonQueue then
                WarlockHudClearSummonQueue("DISABLED")
            end
        end,
        "When off, new requests are ignored and pending requests are cleared.", false)
    Check(summons, 20, -285, "Automatically remove players when nearby",
        function() return Profile().summonAutoRemoveNearby ~= false end,
        function(value) Profile().summonAutoRemoveNearby = value end,
        "Uses a readable group-distance check, or interaction range when permitted. Unavailable results leave requests queued.", false)
    Text(summons, "Accepted request sources", 20, -328, "GameFontNormal")
    local summonSources = {
        { "PARTY", "Party", -355 },
        { "RAID", "Raid", -390 },
        { "INSTANCE_CHAT", "Instance", -425 },
        { "WHISPER", "Whisper from group members", -460 },
    }
    for _, source in ipairs(summonSources) do
        local key = source[1]
        Check(summons, 20, source[3], source[2],
            function()
                local sources = Profile().summonSources
                return not sources or sources[key] ~= false
            end,
            function(value)
                Profile().summonSources = Profile().summonSources or {}
                Profile().summonSources[key] = value and nil or false
            end,
            nil, false)
    end
    ResetPageButton(summons, "Summons", function()
        Profile().summonKeywords = api.DefaultSummonKeywords
        Profile().summonQueueEnabled = true
        Profile().summonAutoRemoveNearby = true
        Profile().summonSources = {}
        MarkChanged(false)
    end)
    return summons
end
