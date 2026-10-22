-- Profile management settings page.
WarlockHudOptionsProfiles = {}

function WarlockHudOptionsProfiles.Build(context)
    local api = context.api
    local Panel, Text, Check, Button = context.Panel, context.Text, context.Check, context.Button
    local Profile, MarkChanged = context.Profile, context.MarkChanged
    local refreshers = context.refreshers

    local profiles = Panel("Warlock HUD - Profiles")
    Text(profiles, "Profiles keep row sizes, order, visibility, and Edit Mode positions together.",
        20, -50, "GameFontHighlightSmall")
    Text(profiles, "Active profile", 20, -85, "GameFontNormal")
    Text(profiles, "Profile summary", 430, -85, "GameFontNormal")
    local profileSummary = Text(profiles, "", 430, -115, "GameFontHighlightSmall")
    profileSummary:SetWidth(260)
    profileSummary:SetJustifyH("LEFT")
    Text(profiles, "Current profile", 20, -115, "GameFontHighlight")
    local selector = CreateFrame("Frame", "WarlockHudProfileSelector", profiles, "UIDropDownMenuTemplate")
    selector:SetPoint("TOPLEFT", profiles, "TOPLEFT", 150, -102)
    UIDropDownMenu_SetWidth(selector, 180)
    UIDropDownMenu_Initialize(selector, function(_, level)
        if (level or 1) ~= 1 then return end
        local db = api.GetDB()
        if not db or not db.profiles then return end
        local names = {}
        for name in pairs(db.profiles) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.checked = name == api.GetDB().activeProfile
            info.func = function()
                local db = api.GetDB()
                local changed = db.activeProfile ~= name
                db.activeProfile = name
                if db.autoSpecProfiles then
                    local group = api.ActiveTalentGroup()
                    if group then
                        db.specProfiles = db.specProfiles or {}
                        if db.specProfiles[group] ~= name then changed = true end
                        db.specProfiles[group] = name
                    end
                end
                if changed then
                    api.InitializeProfiles()
                    MarkChanged()
                end
                UIDropDownMenu_SetText(selector, name)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    refreshers[#refreshers + 1] = function()
        UIDropDownMenu_SetText(selector, api.GetDB().activeProfile)
    end

    Text(profiles, "Manage profiles", 20, -160, "GameFontNormal")
    Text(profiles, "Profile name", 20, -190, "GameFontHighlight")
    local nameInput = CreateFrame("EditBox", nil, profiles, "InputBoxTemplate")
    nameInput:SetSize(180, 24)
    nameInput:SetPoint("TOPLEFT", profiles, "TOPLEFT", 150, -182)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(40)
    local displayedProfile = ((api.GetDB() and api.GetDB().activeProfile) or "Default")
    nameInput:SetText(displayedProfile)
    nameInput:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    local nameStatus = Text(profiles, "", 400, -190, "GameFontHighlightSmall")
    refreshers[#refreshers + 1] = function()
        local db = api.GetDB()
        if db and not nameInput:HasFocus() and db.activeProfile ~= displayedProfile then
            displayedProfile = db.activeProfile
            nameInput:SetText(displayedProfile)
        end
    end

    local function EnteredName()
        return (nameInput:GetText() or ""):match("^%s*(.-)%s*$")
    end

    local function ValidProfileName(candidate)
        local name = candidate or EnteredName()
        if name == "" then return nil, "Enter a profile name." end
        if name:find("%c") or name:lower() == "none" then
            return nil, "Choose another name."
        end
        local db = api.GetDB()
        for existing in pairs(db and db.profiles or {}) do
            if existing:lower() == name:lower() then
                return nil, "That name already exists."
            end
        end
        return name
    end

    local function CopyProfileName()
        local db = api.GetDB()
        local entered = EnteredName()
        if not db or entered ~= db.activeProfile then
            return ValidProfileName(entered)
        end
        local base = db.activeProfile .. " Copy"
        local candidate, suffix = base, 2
        while not ValidProfileName(candidate) do
            candidate = base .. " " .. suffix
            suffix = suffix + 1
        end
        return candidate
    end

    local createButton, renameButton, deleteButton
    local function UpdateNameActions()
        local db = api.GetDB()
        local name, reason = ValidProfileName()
        local copyName = CopyProfileName()
        local isCurrentName = db and EnteredName() == db.activeProfile
        if createButton then createButton:SetEnabled(copyName ~= nil) end
        if renameButton then renameButton:SetEnabled(name ~= nil and not isCurrentName) end
        nameStatus:SetText(isCurrentName and "Copy adds a duplicate of this profile."
            or name and "Name is available." or reason)
        local valid = isCurrentName or name ~= nil
        nameStatus:SetTextColor(valid and 0.4 or 1, valid and 1 or 0.55, 0.4)
    end

    local function CopyProfile(source)
        local copy = {}
        for key, value in pairs(source) do
            if type(value) == "table" then
                copy[key] = {}
                for childKey, childValue in pairs(value) do copy[key][childKey] = childValue end
            else
                copy[key] = value
            end
        end
        return copy
    end

    createButton = Button(profiles, "Copy", 20, -225, 120, function()
        local name = CopyProfileName()
        if not name then return end
        api.GetDB().profiles[name] = api.NormalizeProfile(CopyProfile(Profile()))
        api.GetDB().activeProfile = name
        local db = api.GetDB()
        if db.autoSpecProfiles then
            local group = api.ActiveTalentGroup()
            if group then
                db.specProfiles = db.specProfiles or {}
                db.specProfiles[group] = name
            end
        end
        api.InitializeProfiles()
        displayedProfile = name
        nameInput:SetText(name)
        MarkChanged()
    end)

    renameButton = Button(profiles, "Rename", 148, -225, 100, function()
        local name = ValidProfileName()
        if not name then return end
        local db = api.GetDB()
        if type(db.specProfiles) == "table" then
            for group = 1, 2 do
                if db.specProfiles[group] == db.activeProfile then db.specProfiles[group] = name end
            end
        end
        db.profiles[name] = db.profiles[db.activeProfile]
        db.profiles[db.activeProfile] = nil
        db.activeProfile = name
        api.InitializeProfiles()
        displayedProfile = name
        nameInput:SetText(name)
        MarkChanged()
    end)

    local function DeleteProfile(name)
        local db = api.GetDB()
        if db.activeProfile ~= name then return end
        local count = 0
        for _ in pairs(db.profiles) do count = count + 1 end
        if count <= 1 then return end
        if type(db.specProfiles) == "table" then
            for group = 1, 2 do
                if db.specProfiles[group] == db.activeProfile then db.specProfiles[group] = nil end
            end
        end
        db.profiles[db.activeProfile] = nil
        db.activeProfile = db.profiles.Default and "Default" or next(db.profiles)
        api.InitializeProfiles()
        MarkChanged()
    end

    StaticPopupDialogs.WARLOCKHUD_DELETE_PROFILE = {
        text = "Delete profile %s? This cannot be undone.",
        button1 = "Delete Profile",
        button2 = CANCEL,
        OnAccept = function(_, name) DeleteProfile(name) end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    deleteButton = Button(profiles, "Delete Current", 256, -225, 125, function()
        local db = api.GetDB()
        if db and db.activeProfile then
            StaticPopup_Show("WARLOCKHUD_DELETE_PROFILE", db.activeProfile, nil, db.activeProfile)
        end
    end)

    nameInput:SetScript("OnTextChanged", UpdateNameActions)

    Text(profiles, "Dual spec", 20, -275, "GameFontNormal")
    local specStatus = Text(profiles, "", 350, -305, "GameFontHighlightSmall")
    specStatus:SetWidth(230)
    specStatus:SetJustifyH("LEFT")
    Check(profiles, 20, -300, "Switch profiles with dual spec",
        function() return api.GetDB().autoSpecProfiles == true end,
        function(value)
            local db = api.GetDB()
            db.autoSpecProfiles = value
            if value then
                local group = api.ActiveTalentGroup()
                if group then
                    db.specProfiles = db.specProfiles or {}
                    db.specProfiles[group] = db.specProfiles[group] or db.activeProfile
                end
            end
            api.InitializeProfiles()
        end)

    local function SpecProfileSelector(group, label, y)
        Text(profiles, label, 20, y - 7, "GameFontHighlight")
        local menu = CreateFrame("Frame", nil, profiles, "UIDropDownMenuTemplate")
        menu:SetPoint("TOPLEFT", profiles, "TOPLEFT", 150, y)
        UIDropDownMenu_SetWidth(menu, 180)
        UIDropDownMenu_Initialize(menu, function(_, level)
            if (level or 1) ~= 1 then return end
            local db = api.GetDB()
            if not db or not db.profiles then return end
            local names = {}
            for name in pairs(db.profiles) do names[#names + 1] = name end
            table.sort(names)
            local options = { "None" }
            for _, name in ipairs(names) do options[#options + 1] = name end
            for _, name in ipairs(options) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.checked = (db.specProfiles and db.specProfiles[group] or "None") == name
                info.func = function()
                    db.specProfiles = db.specProfiles or {}
                    db.specProfiles[group] = name ~= "None" and name or nil
                    api.InitializeProfiles()
                    MarkChanged()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        refreshers[#refreshers + 1] = function()
            local db = api.GetDB()
            UIDropDownMenu_SetText(menu, db.specProfiles and db.specProfiles[group] or "None")
        end
    end

    SpecProfileSelector(1, "Primary spec", -345)
    SpecProfileSelector(2, "Secondary spec", -390)
    Text(profiles, "Create a copy above, then assign it to the other spec.",
        20, -445, "GameFontHighlightSmall")
    Text(profiles, "Selecting a profile assigns it to the current spec when automatic switching is on.",
        20, -468, "GameFontHighlightSmall")

    refreshers[#refreshers + 1] = function()
        local db = api.GetDB()
        local profile = Profile()
        if not db or not profile then return end
        local count = 0
        for _ in pairs(db.profiles) do count = count + 1 end
        deleteButton:SetEnabled(count > 1)
        UpdateNameActions()

        local function EnabledCount(keys)
            local enabled = 0
            for _, key in ipairs(keys) do
                if profile.enabled[key] ~= false then enabled = enabled + 1 end
            end
            return enabled
        end
        profileSummary:SetText("Selected: " .. db.activeProfile
            .. "\nEnabled slots: " .. EnabledCount(api.MainKeys)
            .. " / " .. EnabledCount(api.CooldownKeys)
            .. " / " .. EnabledCount(api.ConsumeKeys) .. " / "
            .. EnabledCount(api.BuffKeys) .. " / " .. EnabledCount(api.ProcKeys)
            .. "\nSizes: " .. profile.mainSize .. " / " .. profile.cooldownSize
            .. " / " .. profile.consumeSize .. " / " .. profile.buffSize
            .. " / " .. profile.procSize .. " px"
            .. "\n(DoTs / Utility / Consumes / Buffs / Procs)")

        if not db.autoSpecProfiles then
            specStatus:SetText("Automatic switching is off.")
        else
            local group = api.ActiveTalentGroup()
            local groupName = group == 1 and "Primary" or group == 2 and "Secondary"
                or "Unavailable"
            local assigned = group and db.specProfiles and db.specProfiles[group] or "None"
            specStatus:SetText("Current spec: " .. groupName
                .. "\nAssigned profile: " .. (assigned or "None"))
        end
    end
    return profiles
end
