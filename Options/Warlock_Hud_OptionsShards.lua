-- Soul Shards settings page. Shard deletion remains in the core addon.
WarlockHudOptionsShards = {}

function WarlockHudOptionsShards.Build(context)
    local api = context.api
    local Panel, Text, Check, Button = context.Panel, context.Text, context.Check, context.Button
    local SizeSlider, ResetPageButton = context.SizeSlider, context.ResetPageButton
    local Profile, DefaultProfile, MarkChanged = context.Profile, context.DefaultProfile, context.MarkChanged
    local refreshers = context.refreshers

    local shards = Panel("Warlock HUD - Soul Shards")
    Text(shards, "Hidden until Drain Soul is learned by default. Enable it early to arrange in Edit Mode.",
        20, -50, "GameFontHighlightSmall")
    Text(shards, "Shard icon", 20, -80, "GameFontNormal")
    Check(shards, 20, -105, "Show Soul Shards icon",
        function()
            local enabled = Profile().enabled.soulshards
            if enabled ~= nil then return enabled == true end
            return api.FeatureSpellLearned
                and api.FeatureSpellLearned("soulshards") == true
        end,
        function(value)
            Profile().enabled.soulshards = value and true or false
        end,
        "Appears automatically after Drain Soul is learned unless disabled. Enable early to show it before then.")
    SizeSlider(shards, "Shard icon size", "shardSize", 16, 64, 20, -140)
    local function ShardNumberSlider(label, key, y, limits, onChange)
        Text(shards, label, 20, y - 5, "GameFontHighlight")
        local slider = CreateFrame("Slider", nil, shards, "OptionsSliderTemplate")
        slider:SetSize(165, 17)
        slider:SetPoint("TOPLEFT", shards, "TOPLEFT", 245, y - 3)
        slider:SetValueStep(1)
        local valueText = Text(shards, "", 470, y - 5, "GameFontHighlight")
        local function Clamp(value)
            local minimum, maximum = limits()
            return math.max(minimum, math.min(maximum, math.floor(value + 0.5)))
        end
        local function Commit(value)
            value = Clamp(value)
            slider:SetValue(value)
            if Profile()[key] ~= value then
                Profile()[key] = value
                if onChange then onChange() end
                MarkChanged(false)
            end
        end
        slider:SetScript("OnValueChanged", function(_, value)
            valueText:SetText(tostring(Clamp(value)))
        end)
        slider:SetScript("OnMouseUp", function(self) Commit(self:GetValue()) end)
        local minus = Button(shards, "-", 210, y, 24, function()
            Commit(Profile()[key] - 1)
        end)
        local plus = Button(shards, "+", 420, y, 24, function()
            Commit(Profile()[key] + 1)
        end)
        refreshers[#refreshers + 1] = function()
            local minimum, maximum = limits()
            slider:SetMinMaxValues(minimum, maximum)
            local value = Profile()[key]
            slider:SetValue(value)
            valueText:SetText(tostring(value))
            minus:SetEnabled(value > minimum)
            plus:SetEnabled(value < maximum)
        end
    end
    Text(shards, "Shard reserve", 20, -185, "GameFontNormal")
    ShardNumberSlider("Minimum shards to keep", "shardKeepCount", -210,
        function() return 0, 64 end)
    Button(shards, "Use default 8", 520, -210, 125, function()
        if Profile().shardKeepCount ~= 8 then
            Profile().shardKeepCount = 8
            MarkChanged(false)
        end
    end)
    local shardWarning = Text(shards,
        "Clicking the icon permanently destroys one shard from a regular bag.",
        20, -480, "GameFontHighlightSmall")
    shardWarning:SetTextColor(1, 0.65, 0.25)
    Text(shards, "Deletion stops at your reserve and is unavailable in combat.",
        20, -500, "GameFontHighlightSmall")
    Text(shards, "Shard warnings", 20, -265, "GameFontNormal")
    local function RefreshShardWarning()
        if api.RefreshShardWarning then api.RefreshShardWarning() end
    end
    Check(shards, 20, -290, "Enable shard warnings",
        function() return Profile().shardWarningsEnabled end,
        function(value)
            Profile().shardWarningsEnabled = value
            RefreshShardWarning()
        end, nil, false)
    ShardNumberSlider("Red at or below", "shardLowThreshold", -330,
        function() return 0, Profile().shardHighThreshold - 1 end, RefreshShardWarning)
    ShardNumberSlider("Yellow at or above", "shardHighThreshold", -370,
        function() return Profile().shardLowThreshold + 1, 64 end, RefreshShardWarning)
    Check(shards, 20, -410, "Warn when shards overflow the Soul Bag",
        function() return Profile().shardWarnOverflow end,
        function(value)
            Profile().shardWarnOverflow = value
            RefreshShardWarning()
        end,
        "Detects shards in regular bags while a Soul Bag is equipped.", false)
    Button(shards, "Use warning defaults", 20, -445, 165, function()
        local defaults = DefaultProfile()
        Profile().shardLowThreshold = defaults.shardLowThreshold
        Profile().shardHighThreshold = defaults.shardHighThreshold
        RefreshShardWarning()
        MarkChanged(false)
    end)
    ResetPageButton(shards, "Soul Shards", function()
        local defaults = DefaultProfile()
        Profile().enabled.soulshards = nil
        Profile().shardSize = defaults.shardSize
        Profile().shardKeepCount = defaults.shardKeepCount
        Profile().shardWarningsEnabled = defaults.shardWarningsEnabled
        Profile().shardLowThreshold = defaults.shardLowThreshold
        Profile().shardHighThreshold = defaults.shardHighThreshold
        Profile().shardWarnOverflow = defaults.shardWarnOverflow
        RefreshShardWarning()
        MarkChanged()
    end)
    return shards
end
