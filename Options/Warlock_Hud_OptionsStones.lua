-- Soulstone and Healthstone settings page.
WarlockHudOptionsStones = {}

function WarlockHudOptionsStones.Build(context)
    local Panel, Text, Check, Button = context.Panel, context.Text, context.Check, context.Button
    local Profile, RefreshAll = context.Profile, context.RefreshAll
    local refreshers = context.refreshers

    local stones = Panel("Warlock HUD - Stones", false)
    Text(stones, "Soulstone", 20, -55, "GameFontNormal")
    local soulstoneStatus = Text(stones, "", 330, -55, "GameFontHighlightSmall")
    refreshers[#refreshers + 1] = function()
        local status = WarlockHudSoulstoneText and WarlockHudSoulstoneText()
        soulstoneStatus:SetText(status and ("Applied: " .. status) or "")
    end
    local function Stones()
        local profile = Profile()
        profile.stones = profile.stones or {}
        return profile.stones
    end
    local function StoneCheck(y, label, key, defaultOn, tooltip)
        Check(stones, 20, y, label,
            function()
                local value = Stones()[key]
                return value == nil and defaultOn or value == true
            end,
            function(value) Stones()[key] = value end,
            tooltip, false)
    end
    StoneCheck(-80, "Enable Soulstone tracker", "soulstoneTracker", true)
    StoneCheck(-115, "Show recipient name", "showSoulstoneName", true)
    StoneCheck(-150, "Show estimated countdown", "showSoulstoneCountdown", true,
        "Uses a safe out-of-combat aura observation. It may be stale during combat.")
    StoneCheck(-185, "Notify on expiry or uncertain loss", "notifySoulstoneLoss", false)
    Text(stones, "Details appear only while the Soulstone aura is confirmed active.",
        48, -223, "GameFontHighlightSmall")
    Text(stones, "Healthstones", 20, -260, "GameFontNormal")
    StoneCheck(-285, "Track completed Healthstone trades", "distributionTracker", true)
    StoneCheck(-320, "Auto-place one Healthstone for group members", "autoPlaceHealthstone", false,
        "Only in an empty trade with a matched group member. You must press Accept yourself.")
    StoneCheck(-355, "Notify me after a recorded distribution", "notifyDistribution", false)
    Text(stones, "Supplied means a completed trade was recorded; current possession is unknown.",
        48, -395, "GameFontHighlightSmall")
    local distributionText = Text(stones, "", 20, -425, "GameFontHighlightSmall")
    distributionText:SetWidth(610)
    distributionText:SetJustifyH("LEFT")
    refreshers[#refreshers + 1] = function()
        distributionText:SetText(WarlockHudDistributionSummary and WarlockHudDistributionSummary()
            or "Distribution list unavailable")
    end
    Button(stones, "Reset supplied list", 20, -500, 155, function()
        if WarlockHudResetDistribution then WarlockHudResetDistribution() end
        RefreshAll()
    end)
    return stones
end
