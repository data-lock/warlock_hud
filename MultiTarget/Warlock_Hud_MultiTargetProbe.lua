-- Optional diagnostic unit probe; inactive unless explicitly started.
WarlockHudMultiTargetProbe = {}

function WarlockHudMultiTargetProbe.New(getRows, rowLimit, plain,
    groupThreat, targetsGroup, targetedByGroup)
    local ROWS, Plain = rowLimit, plain
    local GroupThreat, TargetsGroup = groupThreat, targetsGroup
    local TargetedByGroup = targetedByGroup

    -- Temporary discovery probe. It reads unit identities only; it never scans
    -- auras or changes the protected multi-target rows.
    local probeFrame = CreateFrame("Frame")
    local probeRunning, probeElapsed = false, 0
    local probePrevious = {}
    local ProbeValue
    local threatDebug, threatPrevious = false, nil
    local threatEventsSeen = {}
    local function ThreatSnapshot(reason, force)
        if not WarlockHudTraceHUD then return end
        local tokens = { "target", "nameplate1", "nameplate2" }
        if IsInRaid and IsInRaid() then
            for i = 1, 40 do tokens[#tokens + 1] = "raid" .. i .. "target" end
        elseif IsInGroup and IsInGroup() then
            for i = 1, 4 do tokens[#tokens + 1] = "party" .. i .. "target" end
        end
        local results = {}
        for _, unit in ipairs(tokens) do
            if ProbeValue(UnitExists, unit) then
                local status = "API absent"
                if UnitThreatSituation then
                    local ok, value = pcall(UnitThreatSituation, "player", unit)
                    if not ok then status = "ERROR"
                    elseif issecretvalue and issecretvalue(value) then status = "SECRET"
                    elseif value == nil then status = "nil"
                    elseif type(value) ~= "number" then status = "non-number"
                    elseif value == 0 or value == 1 or value == 2 or value == 3 then
                        status = tostring(value)
                    else status = "other-number" end
                end
                results[#results + 1] = unit .. "=" .. status
            end
        end
        local state = "combat=" .. tostring(InCombatLockdown()) .. " "
            .. (#results > 0 and table.concat(results, " ") or "no sampled units")
        if force or state ~= threatPrevious then
            WarlockHudTraceHUD("Threat probe " .. reason .. ": " .. state)
            threatPrevious = state
        end
    end
    ProbeValue = function(fn, unit)
        if not fn then return nil end
        local ok, value = pcall(fn, unit)
        if not ok or not Plain(value) then return nil end
        return value
    end
    local function ProbeTokens()
        local tokens = { "target", "focus", "pettarget" }
        if IsInRaid and IsInRaid() then
            for i = 1, 40 do tokens[#tokens + 1] = "raid" .. i .. "target" end
        elseif IsInGroup and IsInGroup() then
            for i = 1, 4 do tokens[#tokens + 1] = "party" .. i .. "target" end
        end
        for i = 1, 8 do tokens[#tokens + 1] = "boss" .. i end
        for i = 1, ROWS do tokens[#tokens + 1] = "nameplate" .. i end
        return tokens
    end
    local function ProbeEngagement(unit)
        local threat = GroupThreat(unit)
        local targeting = TargetsGroup(unit)
        local selected = TargetedByGroup(unit)
        local combat
        if UnitAffectingCombat then
            local ok, value = pcall(UnitAffectingCombat, unit)
            if ok and Plain(value) then combat = value end
        end
        local shown = false
        for _, row in ipairs(getRows()) do
            if row.unit == unit then shown = row.present == true; break end
        end
        local function Flag(value)
            return value == nil and "?" or (value and "1" or "0")
        end
        return "; threat=" .. Flag(threat)
            .. "; targetsGroup=" .. Flag(targeting)
            .. "; groupTargets=" .. Flag(selected)
            .. "; combat=" .. Flag(combat)
            .. "; shown=" .. Flag(shown)
    end
    local function ProbeSnapshot()
        local output = WarlockHudTraceHUD
        if not output then return end
        local nextState, found = {}, 0
        for _, unit in ipairs(ProbeTokens()) do
            if ProbeValue(UnitExists, unit) then
                local hostile = ProbeValue(UnitCanAttack and function(token)
                    return UnitCanAttack("player", token)
                end, unit)
                if hostile then
                    local name = ProbeValue(UnitName, unit)
                    local guid = ProbeValue(UnitGUID, unit)
                    local dead = ProbeValue(UnitIsDeadOrGhost, unit)
                    local identity = (type(guid) == "string" and guid)
                        or (type(name) == "string" and name) or "unknown"
                    local engagement = unit:match("^nameplate%d+$")
                        and ProbeEngagement(unit) or ""
                    local state = identity .. (dead and " [dead]" or "") .. engagement
                    nextState[unit] = state
                    found = found + 1
                    if probePrevious[unit] ~= state then
                        output("Unit probe: " .. unit .. " = "
                            .. (type(name) == "string" and name or "name restricted")
                            .. "; GUID=" .. (type(guid) == "string" and guid or "restricted")
                            .. (dead and "; dead" or "") .. engagement)
                    end
                end
            end
        end
        for unit in pairs(probePrevious) do
            if not nextState[unit] then output("Unit probe: " .. unit .. " cleared") end
        end
        probePrevious = nextState
        return found
    end
    probeFrame:SetScript("OnUpdate", function(_, elapsed)
        if not probeRunning then return end
        probeElapsed = probeElapsed + elapsed
        if probeElapsed < 1 then return end
        probeElapsed = 0
        ProbeSnapshot()
    end)
    local function Command(command)
        if WarlockHudOpenDebugTrace then WarlockHudOpenDebugTrace() end
        if not WarlockHudTraceHUD then return end
        if command == "toggle" then command = probeRunning and "off" or "on" end
        if command == "off" then
            probeRunning = false
            WarlockHudTraceHUD("Unit probe: stopped")
            return
        end
        probePrevious = {}
        probeElapsed = 0
        probeRunning = true
        WarlockHudTraceHUD("Unit probe: sampling hostile target, focus, pet/group targets, boss1-8, nameplate1-16 once per second; /whud unitprobe off to stop")
        local found = ProbeSnapshot()
        WarlockHudTraceHUD("Unit probe: " .. found .. " hostile tokens currently resolved")
    end

    return {
        IsRunning = function() return probeRunning end,
        Command = Command,
        EnableThreatDebug = function()
            threatDebug = true
            ThreatSnapshot("/whud debug", true)
        end,
        ThreatEvent = function(event)
            if threatDebug then
                local first = not threatEventsSeen[event]
                threatEventsSeen[event] = true
                ThreatSnapshot(event, first)
            end
        end,
    }
end
