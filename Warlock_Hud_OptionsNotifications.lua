-- Notification settings page.
WarlockHudOptionsNotifications = {}

function WarlockHudOptionsNotifications.Build(context)
    local Panel, Text, Check = context.Panel, context.Text, context.Check
    local ResetPageButton = context.ResetPageButton
    local Profile, MarkChanged = context.Profile, context.MarkChanged

    local notifications = Panel("Warlock HUD - Notifications")
    Text(notifications, "Choose which Warlock actions show a chat notification.",
        20, -50, "GameFontHighlightSmall")
    Text(notifications, "Announcements", 20, -85, "GameFontNormal")
    local notificationChoices = {
        { "notifySummon", "Ritual of Summoning", -115 },
        { "notifySoulstone", "Soulstone cast on a player", -180 },
        { "notifyHealthstone", "Healthstone trade completed", -245 },
    }
    for _, choice in ipairs(notificationChoices) do
        local key = choice[1]
        Check(notifications, 20, choice[3], choice[2],
            function() return Profile().enabled[key] ~= false end,
            function(value)
                if value then Profile().enabled[key] = nil
                else Profile().enabled[key] = false end
            end, nil, false)
    end
    Text(notifications, "Example: Summoning Player. Please click the portal.",
        48, -148, "GameFontHighlightSmall")
    Text(notifications, "Example: Soulstone cast on Player.",
        48, -213, "GameFontHighlightSmall")
    Text(notifications, "Example: Healthstone trade completed with Player.",
        48, -278, "GameFontHighlightSmall")
    Text(notifications, "Delivery", 20, -325, "GameFontNormal")
    Check(notifications, 20, -355, "Send summon and Healthstone trade notices to group chat",
        function() return Profile().notificationChannel == "GROUP" end,
        function(value) Profile().notificationChannel = value and "GROUP" or "SELF" end,
        nil, false)
    Text(notifications, "When off, summon and trade notices appear only in your chat window.",
        48, -390, "GameFontHighlightSmall")
    Text(notifications, "Soulstone goes to party, raid, or instance chat when grouped regardless of this setting.",
        20, -420, "GameFontHighlightSmall")
    ResetPageButton(notifications, "Notifications", function()
        for _, choice in ipairs(notificationChoices) do
            Profile().enabled[choice[1]] = nil
        end
        Profile().notificationChannel = "SELF"
        MarkChanged(false)
    end)
    return notifications
end
