local api = WarlockHudAPI
local state = WarlockHudOnboarding
local window, welcome, finish
local selected = "basic"
local shownThisSession = false
local dismissedThisSession = false
local worldReady = false
local pendingApply, pendingSettings
local pendingVisual = false
local manualFlow = false
local suspendedForCombat = false
local tick = 0

local function Safe()
    return not InCombatLockdown()
        and not (C_Secrets and C_Secrets.ShouldAurasBeSecret
            and C_Secrets.ShouldAurasBeSecret())
end

local function Label(parent, value, x, y, width, font)
    local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(value)
    return label
end

local function Button(parent, value, x, y, width, action)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 28)
    button:SetPoint("BOTTOMLEFT", x, y)
    button:SetText(value)
    button:SetScript("OnClick", action)
    return button
end

local function ShowFinish()
    welcome:Hide()
    finish:Show()
    window.TitleText:SetText("Warlock HUD")
    window:Show()
end

local function Apply(preset, expectedProfile)
    if not Safe() then
        pendingApply = { preset = preset, profile = expectedProfile }
        if window then window:Hide() end
        return
    end
    local db = api.GetDB()
    if not db or db.activeProfile ~= expectedProfile or not db.profiles[expectedProfile] then
        print("|cffff7a7aWarlock HUD:|r Active profile changed. Reopen Getting Started and review the preset.")
        return
    end
    local keys = { main = api.MainKeys, cooldown = api.CooldownKeys,
        buff = api.BuffKeys, proc = api.ProcKeys }
    local ok, staged = pcall(state.Preset, db.profiles[expectedProfile], preset, keys)
    if not ok or not staged then
        print("|cffff7a7aWarlock HUD:|r Preset could not be applied.")
        return
    end
    local original = db.profiles[expectedProfile]
    db.profiles[expectedProfile] = staged
    local initialized = pcall(api.InitializeProfiles)
    if not initialized then
        db.profiles[expectedProfile] = original
        api.InitializeProfiles()
        print("|cffff7a7aWarlock HUD:|r Preset could not be applied.")
        return
    end
    local rebuilt, visualReady = pcall(api.Rebuild)
    if not rebuilt then
        db.profiles[expectedProfile] = original
        api.InitializeProfiles()
        print("|cffff7a7aWarlock HUD:|r Preset could not be applied.")
        return
    end
    db.onboarding = { schemaVersion = 2, completed = true,
        selectedPreset = preset }
    pendingVisual = not visualReady
    if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
    if WarlockHudSummonQueueChanged then WarlockHudSummonQueueChanged() end
    ShowFinish()
end

local function ConfirmOrApply()
    local db = api.GetDB()
    if not db or not db.activeProfile then return end
    local profileName = db.activeProfile
    if manualFlow or (db.onboarding and
        (db.onboarding.completed or db.onboarding.requireConfirm)) then
        StaticPopup_Show("WARLOCKHUD_APPLY_ONBOARDING_PRESET",
            selected == "basic" and "Basic" or "Advanced",
            profileName, { preset = selected, profile = profileName })
    else
        Apply(selected, profileName)
    end
end

StaticPopupDialogs.WARLOCKHUD_APPLY_ONBOARDING_PRESET = {
    text = "Apply %s preset to current profile %s?\nOnly the listed HUD and utility settings will change. Positions and other profiles stay as they are.",
    button1 = "Apply Preset", button2 = CANCEL,
    OnAccept = function(_, request)
        if request then Apply(request.preset, request.profile) end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local function MakeCard(parent, preset, x, heading, summary, features, artworkPath)
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(295, 164)
    card:SetPoint("TOPLEFT", x, -108)
    local artwork = card:CreateTexture(nil, "BACKGROUND")
    artwork:SetAllPoints()
    artwork:SetTexture(artworkPath)
    local background = card:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local edge = card:CreateTexture(nil, "BORDER")
        if side == "TOP" or side == "BOTTOM" then
            edge:SetHeight(1)
            edge:SetPoint(side .. "LEFT", card, side .. "LEFT")
            edge:SetPoint(side .. "RIGHT", card, side .. "RIGHT")
        else
            edge:SetWidth(1)
            edge:SetPoint("TOP" .. side, card, "TOP" .. side)
            edge:SetPoint("BOTTOM" .. side, card, "BOTTOM" .. side)
        end
        edges[#edges + 1] = edge
    end
    card.background, card.edges = background, edges
    card.heading = Label(card, heading, 15, -13, 240, "GameFontNormalLarge")
    card.check = card:CreateTexture(nil, "OVERLAY")
    card.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    card.check:SetSize(20, 20)
    card.check:SetPoint("TOPRIGHT", card, "TOPRIGHT", -11, -11)
    local summaryLabel = Label(card, summary, 15, -48, 265,
        "GameFontHighlight")
    summaryLabel:ClearAllPoints()
    summaryLabel:SetPoint("TOPLEFT", card.heading, "BOTTOMLEFT", 0, -13)
    local previous = summaryLabel
    for index, feature in ipairs(features) do
        local line = Label(card, "• " .. feature, 15, -83, 265,
            "GameFontHighlightSmall")
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0,
            index == 1 and -17 or -7)
        previous = line
    end
    card:SetScript("OnClick", function()
        selected = preset
        parent.basic:Refresh()
        parent.advanced:Refresh()
        parent.start:SetText("Get Started with " .. (selected == "basic" and "Basic" or "Advanced"))
    end)
    card:SetScript("OnEnter", function(self)
        self.hovered = true
        self:Refresh()
    end)
    card:SetScript("OnLeave", function(self)
        self.hovered = false
        self:Refresh()
    end)
    function card:Refresh()
        local active = selected == preset
        self.check:SetShown(active)
        self.heading:SetTextColor(active and 1 or 0.9,
            active and 0.82 or 0.76, active and 0.38 or 0.58)
        local red, green, blue, alpha = 0.36, 0.31, 0.42, 0.65
        if active then
            red, green, blue, alpha = 0.67, 0.43, 0.82, 0.95
        elseif self.hovered then
            red, green, blue, alpha = 0.54, 0.44, 0.62, 0.8
        end
        for _, edge in ipairs(self.edges) do
            edge:SetColorTexture(red, green, blue, alpha)
        end
        self.background:SetColorTexture(active and 0.15 or 0.09,
            active and 0.10 or 0.08, active and 0.19 or 0.12,
            self.hovered and 0.48 or 0.58)
    end
    return card
end

local function MakeWindow()
    if window then return end
    window = CreateFrame("Frame", "WarlockHudWelcomeFrame", UIParent,
        "BasicFrameTemplateWithInset")
    window:SetSize(650, 380)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    window.TitleText:SetText("Welcome to Warlock HUD")
    window:Hide()
    table.insert(UISpecialFrames, "WarlockHudWelcomeFrame")
    window:SetScript("OnHide", function()
        if suspendedForCombat then return end
        if not (api.GetDB() and api.GetDB().onboarding
            and api.GetDB().onboarding.completed) then
            dismissedThisSession = true
        end
    end)
    local scale = math.min(1, UIParent:GetWidth() / 690,
        UIParent:GetHeight() / 420)
    window:SetScale(scale)

    local version = C_AddOns and C_AddOns.GetAddOnMetadata
        and C_AddOns.GetAddOnMetadata("Warlock_Hud", "Version") or "1.0"
    local versionLabel = window:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    versionLabel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -22, 10)
    versionLabel:SetText("v" .. version)

    welcome = CreateFrame("Frame", nil, window)
    welcome:SetAllPoints()
    Label(welcome, "Your Warlock companion for WoW Forever.",
        22, -46, 600, "GameFontHighlight")
    Label(welcome, "Choose how you'd like to get started.",
        22, -72, 600, "GameFontHighlight")
    welcome.basic = MakeCard(welcome, "basic", 22, "Basic",
        "Clean combat essentials.",
        { "DoTs, Buffs & Procs", "Utility & Soul Shards", "Consumables" },
        "Interface\\AddOns\\Warlock_Hud\\Textures\\WelcomeBasic.tga")
    welcome.advanced = MakeCard(welcome, "advanced", 333, "Advanced",
        "The complete Warlock toolkit.",
        { "Everything in Basic", "Multi-Target & Threat", "Summons & Raid Tools" },
        "Interface\\AddOns\\Warlock_Hud\\Textures\\WelcomeAdvanced.tga")
    welcome.basic:Refresh()
    welcome.advanced:Refresh()
    welcome.start = Button(welcome, "Get Started with Basic", 202, 30, 245,
        ConfirmOrApply)
    local footer = Label(welcome, "You can enable any feature later in Settings.",
        22, -306, 606, "GameFontHighlightSmall")
    footer:SetJustifyH("CENTER")
    local unlockNote = Label(welcome,
        "Soul Shards require Drain Soul; stone icons require their creation spells. Enable them early in Settings.",
        22, -288, 606, "GameFontHighlightSmall")
    unlockNote:SetJustifyH("CENTER")

    finish = CreateFrame("Frame", nil, window)
    finish:SetAllPoints()
    local ready = Label(finish, "You're ready to go!", 22, -62, 606,
        "GameFontNormalLarge")
    ready:SetJustifyH("CENTER")
    local configured = Label(finish, "Warlock HUD is configured and ready.",
        22, -104, 606)
    configured:SetJustifyH("CENTER")
    Label(finish, "Customize", 120, -174, 125, "GameFontNormal")
    Label(finish, "/whud opens Settings", 245, -174, 285)
    Label(finish, "Rearrange", 120, -211, 125, "GameFontNormal")
    Label(finish, "Move your HUD in Edit Mode", 245, -211, 285)
    Label(finish, "Share", 120, -248, 125, "GameFontNormal")
    Label(finish, "Profile Import / Export", 245, -248, 285)
    Button(finish, "Start Playing", 167, 30, 150, function() window:Hide() end)
    Button(finish, "Open Settings", 333, 30, 150, function()
        window:Hide()
        if Safe() then WarlockHudOpenSettings() else pendingSettings = true end
    end)
    finish:Hide()
end

function WarlockHudOpenGettingStarted(automatic)
    if InCombatLockdown() then
        print("|cffff7a7aWarlock HUD:|r Open Getting Started after combat.")
        return
    end
    MakeWindow()
    window.TitleText:SetText("Welcome to Warlock HUD")
    manualFlow = automatic ~= true
    selected = "basic"
    welcome.basic:Refresh()
    welcome.advanced:Refresh()
    welcome.start:SetText("Get Started with Basic")
    finish:Hide()
    welcome:Show()
    window:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then worldReady = true end
    if event == "PLAYER_REGEN_DISABLED" and window and window:IsShown() then
        suspendedForCombat = true
        window:Hide()
    end
end)
events:SetScript("OnUpdate", function(_, elapsed)
    tick = tick + elapsed
    if tick < 0.5 then return end
    tick = 0
    if pendingSettings and Safe() then
        pendingSettings = false
        WarlockHudOpenSettings()
    end
    if pendingVisual and Safe() and api.Rebuild() then
        pendingVisual = false
        if WarlockHudMultiTarget then WarlockHudMultiTarget.Refresh() end
    end
    if pendingApply and Safe() then
        local request = pendingApply
        pendingApply = nil
        Apply(request.preset, request.profile)
        return
    end
    if suspendedForCombat and Safe() and window then
        suspendedForCombat = false
        window:Show()
        return
    end
    local db = api.GetDB()
    if not worldReady or shownThisSession or dismissedThisSession
        or not db or not db.onboarding
        or db.onboarding.completed or not api.IsAddonEnabled()
        or not Safe() or not UIParent:IsShown()
        or (WorldFrame and not WorldFrame:IsShown()) then return end
    for index = 1, 4 do
        local popup = _G["StaticPopup" .. index]
        if popup and popup:IsShown() then return end
    end
    shownThisSession = true
    WarlockHudOpenGettingStarted(true)
end)
