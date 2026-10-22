-- Root overview and reset settings page.
WarlockHudOptionsAbout = {}

function WarlockHudOptionsAbout.Build(context)
    local api = context.api
    local Panel, Text, Button = context.Panel, context.Text, context.Button
    local about = Panel("Warlock HUD", false)

    local function Metadata(key)
        local value = C_AddOns and C_AddOns.GetAddOnMetadata
            and C_AddOns.GetAddOnMetadata("Warlock_Hud", key)
        if type(value) ~= "string" or value == "" then return "Unknown" end
        return value
    end

    Text(about, "Your Warlock. Your HUD. Your raid, organized.",
        24, -55, "GameFontNormalLarge")
    Text(about, "A customizable combat HUD and Warlock utility toolkit for World of Warcraft.",
        24, -82, "GameFontHighlight")

    Text(about, "Quick Actions", 24, -122, "GameFontNormal")
    Button(about, "Getting Started", 24, -145, 128, function()
        if WarlockHudOpenGettingStarted then WarlockHudOpenGettingStarted() end
    end)
    Button(about, "Edit Mode Help", 160, -145, 128, function()
        print("|cffffc44dWarlock HUD:|r Open Blizzard Edit Mode to move HUD rows and the Soul Shards icon.")
    end)
    local demoButton = Button(about, "Demo All HUD Bars", 296, -145, 128,
        context.ShowIconDemo)
    Button(about, "Share Settings", 432, -145, 128, function()
        if context.OpenSharingSettings then context.OpenSharingSettings() end
    end)

    Text(about, "Your Setup", 24, -195, "GameFontNormal")
    local setupRows = {}
    for index, label in ipairs({
        "Version", "Interface", "Active profile", "Specialization",
        "Spec profile", "Multi-Target DoTs", "Summon Queue",
    }) do
        local row = Text(about, "", 24, -220 - (index - 1) * 21,
            "GameFontHighlightSmall")
        row:SetWidth(270)
        row:SetWordWrap(false)
        row:SetJustifyH("LEFT")
        setupRows[index] = { label = label, text = row }
    end

    Text(about, "Help & Community", 315, -195, "GameFontNormal")
    local function HelpLine(value, y)
        local line = Text(about, value, 315, y, "GameFontHighlightSmall")
        line:SetWidth(320)
        line:SetWordWrap(false)
        line:SetJustifyH("LEFT")
        return line
    end
    HelpLine("Settings: /whud or /whub", -220)
    HelpLine("Move rows and shards in Edit Mode.", -242)
    HelpLine("Bug reports: include the game version", -264)
    HelpLine("and steps to reproduce.", -285)
    Text(about, "GitHub", 315, -314, "GameFontNormal")
    HelpLine("https://github.com/data-lock/warlock_hud", -334)
    Text(about, "CurseForge", 315, -374, "GameFontNormal")
    HelpLine("https://www.curseforge.com/wow/addons/warlock-hud", -394)

    Text(about, "Advanced / Troubleshooting", 24, -440, "GameFontNormal")
    Text(about, "Reset removes all profiles, settings, and saved character data.",
        24, -466, "GameFontHighlightSmall")
    local resetStatus = Text(about, "", 24, -530, "GameFontHighlightSmall")
    local resetReload = CreateFrame("Frame")
    resetReload:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        ReloadUI()
    end)
    StaticPopupDialogs.WARLOCKHUD_RESET_ALL = {
        text = "Reset all Warlock HUD data to defaults?\nThis deletes every profile, setting, and saved character record. Export a share code first if you want a backup. The UI will reload.",
        button1 = "Reset Everything",
        button2 = CANCEL,
        OnAccept = function()
            WarlockHudDB = {}
            api.InitializeProfiles()
            if InCombatLockdown() then
                resetStatus:SetText("Reset saved. UI will reload after combat.")
                resetReload:RegisterEvent("PLAYER_REGEN_ENABLED")
            else
                ReloadUI()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    Button(about, "Reset All Data", 24, -492, 140, function()
        StaticPopup_Show("WARLOCKHUD_RESET_ALL")
    end)

    local refreshers = context.refreshers
    refreshers[#refreshers + 1] = function()
        local db, profile = api.GetDB(), api.GetProfile()
        if not db or not profile then return end
        local group = api.ActiveTalentGroup and api.ActiveTalentGroup()
        local groupName = group == 1 and "Primary" or group == 2 and "Secondary"
            or "Unavailable"
        local specProfile = group and db.specProfiles and db.specProfiles[group]
            or "None"
        local setupValues = {
            Metadata("Version"), Metadata("Interface"),
            tostring(db.activeProfile or "Unknown"), groupName,
            tostring(specProfile), profile.multiDotEnabled and "On" or "Off",
            profile.summonQueueEnabled and "On" or "Off",
        }
        for index, row in ipairs(setupRows) do
            row.text:SetText(row.label .. ": " .. setupValues[index])
        end
        demoButton:SetText(context.IsDemoShown and context.IsDemoShown()
            and "End HUD Demo" or "Demo All HUD Bars")
    end
    return about
end
