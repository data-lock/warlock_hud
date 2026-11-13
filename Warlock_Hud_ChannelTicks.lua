-- Tick markers for channeled Warlock spells, drawn over Blizzard's player
-- castbar without changing the castbar itself.
local DRAIN_IDS = {
    [1120] = true, [8288] = true, [8289] = true, [11675] = true,
    [689] = true, [699] = true, [709] = true, [7651] = true,
    [11699] = true, [11700] = true,
    [5138] = true, [6226] = true, [11703] = true, [11704] = true,
}
local RAIN_OF_FIRE_IDS = {
    [5740] = true, [6219] = true, [11677] = true, [11678] = true,
    [27212] = true,
}
local DRAIN_NAMES = {
    ["Drain Life"] = true, ["Drain Mana"] = true, ["Drain Soul"] = true,
}
local DRAIN_TICK_POSITIONS = { 0.2, 0.4, 0.6, 0.8 }
local RAIN_OF_FIRE_TICK_POSITIONS = { 0.25, 0.5, 0.75, 1 }
local frame = CreateFrame("Frame")
local overlays = {}
local eventTickPositions
local elapsed = 0
local channelState = "unknown"

local function Public(value)
    return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

local function TickPositions(name, spellID)
    if Public(spellID) and RAIN_OF_FIRE_IDS[spellID] then
        return RAIN_OF_FIRE_TICK_POSITIONS
    end
    if (Public(spellID) and DRAIN_IDS[spellID])
        or (Public(name) and type(name) == "string" and DRAIN_NAMES[name]) then
        return DRAIN_TICK_POSITIONS
    end
end

local function CurrentChannel()
    local reader = UnitChannelInfo or ChannelInfo
    if not reader then return nil, "API unavailable" end
    local ok, name, _, _, _, _, _, _, spellID
    if UnitChannelInfo then
        ok, name, _, _, _, _, _, _, spellID =
            pcall(UnitChannelInfo, "player")
    else
        ok, name, _, _, _, _, _, _, spellID = pcall(reader)
    end
    if not ok then return nil, "API error" end
    if not Public(name) and not Public(spellID) then
        return nil, "channel identity unavailable"
    end
    local positions = TickPositions(name, spellID)
    if not positions then return false, "other channel" end
    local isRainOfFire = Public(spellID) and RAIN_OF_FIRE_IDS[spellID]
    return positions, isRainOfFire and "Rain of Fire channel" or "drain channel"
end

local function CreateOverlay(bar)
    if not bar or overlays[bar] or InCombatLockdown() then return end
    local overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetAllPoints(bar)
    overlay:SetFrameStrata("TOOLTIP")
    overlay:SetFrameLevel(100)
    local markers = {}
    for index = 1, 4 do
        local marker = overlay:CreateTexture(nil, "OVERLAY")
        marker:SetSize(2, 15)
        marker:SetColorTexture(1, 0.82, 0.3, 1)
        markers[index] = marker
    end
    overlays[bar] = { frame = overlay, markers = markers }
    overlay:Hide()
end

local function EnsureOverlays()
    CreateOverlay(_G.PlayerCastingBarFrame)
    CreateOverlay(_G.CastingBarFrame)
end

local function Update()
    EnsureOverlays()
    local profile = WarlockHudAPI.GetProfile()
    local enabled = profile and profile.enabled
        and profile.enabled.channelTicks ~= false
    local fromAPI, reason = CurrentChannel()
    channelState = reason
    local tickPositions = fromAPI or (fromAPI == nil and eventTickPositions)
    for bar, entry in pairs(overlays) do
        local shown = WarlockHudAPI.IsAddonEnabled() and enabled
            and tickPositions and bar:IsShown()
        local width = shown and bar:GetWidth()
        if not Public(width) or type(width) ~= "number" or width < 20 then
            shown = false
        end
        if shown then
            for index, marker in ipairs(entry.markers) do
                marker:ClearAllPoints()
                if tickPositions[index] == 1 then
                    marker:SetPoint("RIGHT", entry.frame, "LEFT", width, 0)
                else
                    marker:SetPoint("CENTER", entry.frame, "LEFT",
                        width * tickPositions[index], 0)
                end
            end
            entry.frame:Show()
        else
            entry.frame:Hide()
        end
    end
end

function WarlockHudChannelTickTraceState()
    if not WarlockHudTraceChannel then return end
    local pieces = {}
    local function Geometry(region)
        if not region then return "missing" end
        local ok, left, bottom, width, height = pcall(region.GetRect, region)
        local alphaOK, alpha = pcall(region.GetEffectiveAlpha, region)
        if not ok or not alphaOK or not Public(left) or not Public(bottom)
            or not Public(width) or not Public(height)
            or not Public(alpha) then return "unavailable" end
        return math.floor(left) .. "," .. math.floor(bottom)
            .. ":" .. math.floor(width) .. "x" .. math.floor(height)
            .. ":a" .. string.format("%.2f", alpha)
    end
    for _, name in ipairs({ "PlayerCastingBarFrame", "CastingBarFrame" }) do
        local bar = _G[name]
        pieces[#pieces + 1] = name .. "=" .. (bar and
            ("shown:" .. tostring(bar:IsShown())
                .. ",overlay:" .. tostring(overlays[bar] ~= nil)
                .. ",ticks:" .. tostring(overlays[bar]
                    and overlays[bar].frame:IsShown())
                .. ",bar:" .. Geometry(bar)
                .. ",overlay:" .. Geometry(overlays[bar] and overlays[bar].frame)
                .. ",marker:" .. Geometry(overlays[bar]
                    and overlays[bar].markers[1]))
                or "missing")
    end
    WarlockHudTraceChannel("STATE", "api=" .. channelState
        .. " eventTicks=" .. tostring(eventTickPositions ~= nil)
        .. " " .. table.concat(pieces, " "), true)
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
frame:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_CHANNEL_START" and unit == "player" then
        eventTickPositions = TickPositions(nil, spellID)
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" and unit == "player" then
        eventTickPositions = nil
    end
    Update()
    if event == "UNIT_SPELLCAST_CHANNEL_START" and unit == "player" then
        if WarlockHudTraceChannel then
            WarlockHudTraceChannel("START", "spellID="
                .. (Public(spellID) and tostring(spellID) or "unavailable"))
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0.2, function()
                Update()
                WarlockHudChannelTickTraceState()
            end)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" and unit == "player" then
        if WarlockHudTraceChannel then WarlockHudTraceChannel("STOP") end
    end
end)
frame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    Update()
end)
