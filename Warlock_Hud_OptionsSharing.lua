-- Profile sharing settings page.
WarlockHudOptionsSharing = {}

function WarlockHudOptionsSharing.Build(context)
    local api = context.api
    local Panel, Text, Button = context.Panel, context.Text, context.Button
    local MarkChanged = context.MarkChanged

    local sharingPanel = Panel("Warlock HUD - Share Settings")
    Text(sharingPanel, "Choose sections, then export. Paste a code to preview it before importing.",
        20, -50, "GameFontHighlightSmall")
    local share = WarlockHudSharing
    local labels = {
        bars = "Bars and tracked icons", positions = "Edit Mode locations",
        notifications = "Notifications", summons = "Summons",
        stones = "Stone options", shards = "Soul Shards",
    }
    local selected = {}
    for index, section in ipairs(share.Sections) do
        selected[section] = true
        local x = index <= 3 and 20 or 335
        local y = -80 - ((index - 1) % 3) * 31
        local check = CreateFrame("CheckButton", nil, sharingPanel, "UICheckButtonTemplate")
        check:SetSize(22, 22)
        check:SetPoint("TOPLEFT", sharingPanel, "TOPLEFT", x, y)
        check:SetChecked(true)
        Text(sharingPanel, labels[section], x + 27, y - 5, "GameFontHighlight")
        check:SetScript("OnClick", function(self) selected[section] = self:GetChecked() and true or false end)
    end
    local allProfiles = false
    local allCheck = CreateFrame("CheckButton", nil, sharingPanel, "UICheckButtonTemplate")
    allCheck:SetSize(22, 22)
    allCheck:SetPoint("TOPLEFT", sharingPanel, "TOPLEFT", 20, -182)
    Text(sharingPanel, "All profiles (import creates new profiles)", 47, -187, "GameFontHighlight")
    allCheck:SetScript("OnClick", function(self) allProfiles = self:GetChecked() and true or false end)
    Text(sharingPanel, "Import current merges selected sections into the active profile.",
        20, -213, "GameFontHighlightSmall")
    Text(sharingPanel, "Import all creates new profiles; existing profiles are never overwritten.",
        20, -230, "GameFontHighlightSmall")
    Text(sharingPanel, "Share code", 20, -257, "GameFontNormal")
    local shareArea = CreateFrame("Frame", nil, sharingPanel)
    shareArea:SetPoint("TOPLEFT", sharingPanel, "TOPLEFT", 20, -278)
    shareArea:SetSize(575, 158)
    local shareBackground = shareArea:CreateTexture(nil, "BACKGROUND")
    shareBackground:SetAllPoints()
    shareBackground:SetColorTexture(0.04, 0.04, 0.06, 0.85)
    for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local border = shareArea:CreateTexture(nil, "BORDER")
        border:SetColorTexture(0.45, 0.45, 0.45, 0.7)
        if edge == "TOP" or edge == "BOTTOM" then
            border:SetHeight(1)
            border:SetPoint(edge .. "LEFT", shareArea, edge .. "LEFT")
            border:SetPoint(edge .. "RIGHT", shareArea, edge .. "RIGHT")
        else
            border:SetWidth(1)
            border:SetPoint("TOP" .. edge, shareArea, "TOP" .. edge)
            border:SetPoint("BOTTOM" .. edge, shareArea, "BOTTOM" .. edge)
        end
    end
    local shareScroll = CreateFrame("ScrollFrame", nil, shareArea, "UIPanelScrollFrameTemplate")
    shareScroll:SetPoint("TOPLEFT", shareArea, "TOPLEFT", 8, -7)
    shareScroll:SetSize(540, 144)
    local shareInput = CreateFrame("EditBox", nil, shareScroll)
    shareInput:SetMultiLine(true)
    shareInput:SetAutoFocus(false)
    shareInput:SetMaxLetters(60000)
    shareInput:SetSize(530, 144)
    shareInput:SetFontObject("ChatFontNormal")
    shareInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local shareMeasure = shareInput:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    shareMeasure:SetWidth(530)
    shareInput:SetScript("OnTextChanged", function(self)
        shareMeasure:SetText(self:GetText())
        self:SetHeight(math.max(144, shareMeasure:GetStringHeight() + 20))
    end)
    shareScroll:SetScrollChild(shareInput)
    local shareStatus = Text(sharingPanel, "", 20, -485, "GameFontHighlightSmall")
    shareStatus:SetWidth(570)
    shareStatus:SetJustifyH("LEFT")
    local function SetShareStatus(message, good)
        shareStatus:SetText(message)
        shareStatus:SetTextColor(good and 0.4 or 1, good and 1 or 0.5, 0.4)
    end
    Button(sharingPanel, "Export", 20, -448, 105, function()
        local any
        for _, section in ipairs(share.Sections) do
            if selected[section] then any = true; break end
        end
        if not any then SetShareStatus("Select at least one section to export.", false); return end
        local code = share.Export(selected, allProfiles)
        shareInput:SetText(code)
        shareInput:SetFocus()
        shareInput:HighlightText()
        SetShareStatus("Export ready. Press Ctrl+C to copy the selected code.", true)
    end)
    Button(sharingPanel, "Preview Import", 135, -448, 125, function()
        local parsed, reason = share.Decode(shareInput:GetText())
        if not parsed then SetShareStatus(reason, false); return end
        local count, included = 0, {}
        for _ in pairs(parsed.profiles) do count = count + 1 end
        for _, section in ipairs(share.Sections) do
            if parsed.available[section] then included[#included + 1] = labels[section] end
        end
        SetShareStatus("Code v" .. parsed.version .. "; " .. count .. " profile(s). Available: "
            .. table.concat(included, ", ") .. ".", true)
    end)
    StaticPopupDialogs.WARLOCKHUD_CONFIRM_IMPORT = {
        text = "Import from addon version %s?\n%s\nSelected settings save immediately. The HUD refreshes when safe.",
        button1 = "Import Settings",
        button2 = CANCEL,
        OnAccept = function(_, request)
            if not request then return end
            if not request.allProfiles and api.GetDB().activeProfile ~= request.profileName then
                SetShareStatus("Active profile changed. Review the import again.", false)
                return
            end
            local imported, result = share.Import(request.parsed, request.selected, request.allProfiles)
            if not imported then SetShareStatus(result, false); return end
            MarkChanged()
            SetShareStatus(result .. " Saved now; HUD refreshes when safe.", true)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    Button(sharingPanel, "Import Selected", 270, -448, 125, function()
        local parsed, reason = share.Decode(shareInput:GetText())
        if not parsed then SetShareStatus(reason, false); return end
        local chosen, snapshot = {}, {}
        for _, section in ipairs(share.Sections) do
            snapshot[section] = selected[section]
            if selected[section] and parsed.available[section] then
                chosen[#chosen + 1] = labels[section]
            end
        end
        if #chosen == 0 then
            SetShareStatus("Select at least one section available in the code.", false)
            return
        end
        local profileName = api.GetDB().activeProfile
        local destination = allProfiles and "Create new profiles" or
            ("Merge into current profile: " .. profileName)
        StaticPopup_Show("WARLOCKHUD_CONFIRM_IMPORT", parsed.version,
            destination .. "\nSections: " .. table.concat(chosen, ", "),
            { parsed = parsed, selected = snapshot, allProfiles = allProfiles,
                profileName = profileName })
    end)
    Button(sharingPanel, "Clear", 405, -448, 90, function()
        shareInput:SetText("")
        shareInput:ClearFocus()
        shareScroll:SetVerticalScroll(0)
        SetShareStatus("Share code cleared.", true)
    end)
    return sharingPanel
end
