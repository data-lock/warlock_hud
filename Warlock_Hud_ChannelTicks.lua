-- Four interior tick markers for five-tick drains, drawn over Blizzard's
-- player castbar without changing the castbar itself.
local DRAIN_IDS = {
    [1120] = true, [8288] = true, [8289] = true, [11675] = true,
    [689] = true, [699] = true, [709] = true, [7651] = true,
    [11699] = true, [11700] = true,
    [5138] = true, [6226] = true, [11703] = true, [11704] = true,
}
local DRAIN_NAMES = {
    ["Drain Life"] = true, ["Drain Mana"] = true, ["Drain Soul"] = true,
}
local frame = CreateFrame("Frame")
local overlays = {}
local eventDrain = false
local elapsed = 0
local channelState = "unknown"

local function Public(value)
    return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

local function IsDrain(name, spellID)
    return (Public(spellID) and DRAIN_IDS[spellID])
        or (Public(name) and type(name) == "string" and DRAIN_NAMES[name])
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
    if not IsDrain(name, spellID) then return false, "other channel" end
    return true, "drain channel"
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
    local fromAPI, reason = CurrentChannel()
    channelState = reason
    local draining = fromAPI == true or (fromAPI == nil and eventDrain)
    for bar, entry in pairs(overlays) do
        local shown = WarlockHudAPI.IsAddonEnabled() and draining and bar:IsShown()
        local width = shown and bar:GetWidth()
        if not Public(width) or type(width) ~= "number" or width < 20 then
            shown = false
        end
        if shown then
            for index, marker in ipairs(entry.markers) do
                marker:ClearAllPoints()
                marker:SetPoint("CENTER", entry.frame, "LEFT",
                    width * index / 5, 0)
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
        .. " eventDrain=" .. tostring(eventDrain)
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
        eventDrain = IsDrain(nil, spellID) and true or false
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" and unit == "player" then
        eventDrain = false
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
