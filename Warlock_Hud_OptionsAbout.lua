-- About and reset settings page.
WarlockHudOptionsAbout = {}

function WarlockHudOptionsAbout.Build(context)
    local api = context.api
    local Panel, Text, Button = context.Panel, context.Text, context.Button

    local about = Panel("Warlock HUD - About", false)
    local function AddonMetadata(key)
        return C_AddOns and C_AddOns.GetAddOnMetadata
            and C_AddOns.GetAddOnMetadata("Warlock_Hud", key) or "unknown"
    end
    Text(about, "A movable Warlock HUD for World of Warcraft: Forever beta.",
        20, -50, "GameFontHighlightSmall")
    Text(about, "Build", 20, -88, "GameFontNormal")
    Text(about, "Version " .. AddonMetadata("Version") .. "  |  Interface "
        .. AddonMetadata("Interface"), 20, -115, "GameFontHighlight")
    Text(about, "What it shows", 20, -155, "GameFontNormal")
    Text(about, "Target DoTs, utility cooldowns, buffs, procs, and Soul Shards.",
        20, -182, "GameFontHighlight")
    Text(about, "Controls", 20, -222, "GameFontNormal")
    Text(about, "/whub or /whud opens settings. Move rows and the shard icon in Edit Mode.",
        20, -249, "GameFontHighlight")
    Text(about, "Settings save automatically to the current profile.",
        20, -279, "GameFontHighlight")
    Text(about, "GitHub", 20, -319, "GameFontNormal")
    Text(about, "https://github.com/data-lock/warlock_hud", 20, -346, "GameFontHighlight")
    Text(about, "Reset addon", 20, -390, "GameFontNormal")
    Text(about, "Deletes all Warlock HUD profiles, settings, and saved character data.",
        20, -415, "GameFontHighlightSmall")
    local resetStatus = Text(about, "", 20, -485, "GameFontHighlightSmall")
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
    Button(about, "Reset All Data", 20, -445, 140, function()
        StaticPopup_Show("WARLOCKHUD_RESET_ALL")
    end)
    return about
end
