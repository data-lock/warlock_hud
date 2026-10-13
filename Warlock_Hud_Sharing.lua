local api = WarlockHudAPI
local sharing = {}
-- Format 1 uses named fields. Add fields without changing it; bump the format
-- when a field's meaning changes so older clients reject incompatible codes.
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local sections = {
    bars = { mainSize="number", cooldownSize="number", multiDotEnabled="boolean",
        multiDotScale="number", multiDotWidth="number", multiDotHeight="number",
        consumesSchemaVersion="number",
        consumeSize="number",
        buffSize="number", procSize="number", consumesEnabled="boolean",
        mainOrder="list", cooldownOrder="list", consumeOrder="list",
        buffOrder="list", procOrder="list",
        enabled="boolmap", consumeReminders="boolmap",
        showOutOfCombat="boolmap", defaultDotIcons="stringmap",
        colorActiveDoTs="boolean", colorActiveConsumes="boolean", colorActiveBuffs="boolean",
        assignmentsEnabled="boolean", assignmentWarnings="boolean", assignmentWindowCompact="boolean",
        assignmentWindowWidth="number", assignmentWindowHeight="number" },
    positions = { x="number", y="number", cooldownX="number", cooldownY="number",
        multiDotX="number", multiDotY="number",
        consumeX="number", consumeY="number", consumeLeftAligned="boolean",
        buffX="number", buffY="number",
        buffLeftAligned="boolean", procX="number", procY="number",
        shardX="number", shardY="number", assignmentWindowX="number", assignmentWindowY="number" },
    notifications = { notificationChannel="string", notificationFlags="boolmap" },
    summons = { summonKeywords="string", summonQueueEnabled="boolean",
        summonAutoRemoveNearby="boolean", summonSources="boolmap" },
    stones = { stones="boolmap" },
    shards = { shardVisible="boolean", shardSize="number", shardKeepCount="number", shardWarningsEnabled="boolean",
        shardLowThreshold="number", shardHighThreshold="number", shardWarnOverflow="boolean" },
}
sharing.Sections = { "bars", "positions", "notifications", "summons", "stones", "shards" }

local function Base64Encode(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        out[#out + 1] = alphabet:sub(math.floor(n / 262144) + 1, math.floor(n / 262144) + 1)
        out[#out + 1] = alphabet:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        out[#out + 1] = b and alphabet:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "="
        out[#out + 1] = c and alphabet:sub(n % 64 + 1, n % 64 + 1) or "="
    end
    return table.concat(out)
end

local function Base64Decode(data)
    if #data > 60000 or #data % 4 ~= 0 or data:find("[^A-Za-z0-9+/=]")
        or not data:match("^[A-Za-z0-9+/]*=?=?$") then return nil end
    local out = {}
    for i = 1, #data, 4 do
        local a, b, c, d = data:sub(i, i + 3):byte(1, 4)
        local function digit(byte)
            if byte >= 65 and byte <= 90 then return byte - 65 end
            if byte >= 97 and byte <= 122 then return byte - 71 end
            if byte >= 48 and byte <= 57 then return byte + 4 end
            if byte == 43 then return 62 end
            if byte == 47 then return 63 end
        end
        a, b, c, d = digit(a), digit(b), c == 61 and nil or digit(c), d == 61 and nil or digit(d)
        if not a or not b or (not c and d) then return nil end
        local n = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
        out[#out + 1] = string.char(math.floor(n / 65536))
        if c then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
        if d then out[#out + 1] = string.char(n % 256) end
    end
    return table.concat(out)
end

local function Escape(s)
    return tostring(s):gsub("([^A-Za-z0-9_. -])", function(c)
        return string.format("%%%02X", c:byte())
    end)
end
local function Unescape(s)
    if s:find("%%[^0-9A-F]") or s:find("%%$") or s:find("%%[0-9A-F]$") then return nil end
    return (s:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end
local function ValueEncode(value, kind)
    if kind == "number" then return type(value) == "number" and tostring(value) or nil end
    if kind == "boolean" then
        if type(value) ~= "boolean" then return nil end
        return value and "1" or "0"
    end
    if kind == "string" then return type(value) == "string" and Escape(value) or nil end
    if type(value) ~= "table" then return nil end
    local parts = {}
    if kind == "list" then
        for _, item in ipairs(value) do parts[#parts + 1] = Escape(item) end
    else
        local keys = {}
        for key in pairs(value) do if type(key) == "string" then keys[#keys + 1] = key end end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local item = value[key]
            if kind == "stringmap" and type(item) == "string" then
                parts[#parts + 1] = Escape(key) .. ":" .. Escape(item)
            elseif kind == "boolmap" and type(item) == "boolean" then
                parts[#parts + 1] = Escape(key) .. ":" .. (item and "1" or "0")
            end
        end
    end
    return table.concat(parts, ",")
end
local function ValueDecode(raw, kind)
    if kind == "number" then
        local n = tonumber(raw)
        if n and n == n and n > -100000 and n < 100000 then return n end
    elseif kind == "boolean" then
        if raw == "1" then return true end
        if raw == "0" then return false end
    elseif kind == "string" then
        local s = Unescape(raw)
        if s and #s <= 256 and not s:find("%c") then return s end
    elseif #raw <= 12000 then
        local result = {}
        if raw == "" then return result end
        local count = 0
        for part in (raw .. ","):gmatch("(.-),") do
            count = count + 1
            if count > 150 then return nil end
            if kind == "list" then
                local item = Unescape(part)
                if not item or #item > 80 or item == "" then return nil end
                result[#result + 1] = item
            else
                local key, value = part:match("^(.-):(.*)$")
                key, value = key and Unescape(key), value and Unescape(value)
                if not key or #key > 80 or key == "" or result[key] ~= nil then return nil end
                if kind == "boolmap" then
                    if value ~= "0" and value ~= "1" then return nil end
                    result[key] = value == "1"
                elseif kind == "stringmap" then
                    if not value or #value > 80 then return nil end
                    result[key] = value
                end
            end
        end
        return result
    end
end

local notificationKeys = { notifySummon=true, notifySoulstone=true, notifyHealthstone=true }
local function ExportValue(profile, section, key)
    if key == "notificationFlags" then
        local flags = {}
        for name in pairs(notificationKeys) do flags[name] = profile.enabled[name] ~= false end
        return flags
    elseif key == "shardVisible" then
        return profile.enabled.soulshards ~= false
    elseif key == "enabled" then
        local flags = {}
        for name, value in pairs(profile.enabled or {}) do
            if not notificationKeys[name] and name ~= "soulshards" then flags[name] = value end
        end
        return flags
    end
    return profile[key]
end

function sharing.Export(selected, allProfiles)
    local db = api.GetDB()
    local names = {}
    if allProfiles then
        for name in pairs(db.profiles) do names[#names + 1] = name end
        table.sort(names)
    else names[1] = db.activeProfile end
    local version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Warlock_Hud", "Version"))
        or (GetAddOnMetadata and GetAddOnMetadata("Warlock_Hud", "Version")) or "unknown"
    local lines = { "WHUD|1|" .. Escape(version) }
    for _, name in ipairs(names) do
        local profile = db.profiles[name]
        for _, section in ipairs(sharing.Sections) do
            if selected[section] then
                local keys = {}
                for key in pairs(sections[section]) do keys[#keys + 1] = key end
                table.sort(keys)
                for _, key in ipairs(keys) do
                    local encoded = ValueEncode(ExportValue(profile, section, key), sections[section][key])
                    if encoded then lines[#lines + 1] = table.concat({ Escape(name), section, key, encoded }, "|") end
                end
            end
        end
    end
    return "WHUD1:" .. Base64Encode(table.concat(lines, "\n"))
end

function sharing.Decode(code)
    code = (code or ""):gsub("%s", "")
    local payload = code:match("^WHUD1:(.+)$")
    if not payload then return nil, "Invalid or unsupported share code." end
    local plain = Base64Decode(payload)
    if not plain or #plain > 45000 then return nil, "Invalid share code encoding." end
    local newline = plain:find("\n", 1, true)
    local header = newline and plain:sub(1, newline - 1) or plain
    local rest = newline and plain:sub(newline + 1) or ""
    local format, version = header:match("^WHUD|(%d+)|(.+)$")
    if format ~= "1" or not version or #version > 80 then return nil, "Unsupported share format." end
    version = Unescape(version)
    if not version then return nil, "Invalid version label." end
    local data, available, records = {}, {}, 0
    for line in (rest .. "\n"):gmatch("([^\n]*)\n") do
        if line ~= "" then
            records = records + 1
            if records > 1500 then return nil, "Share code has too many settings." end
            local rawName, section, key, raw = line:match("^([^|]+)|([^|]+)|([^|]+)|([^|]*)$")
            if not rawName then return nil, "Malformed share code record." end
            local name = Unescape(rawName)
            if not name or #name < 1 or #name > 40 or name:find("%c") then
                return nil, "Invalid profile name in share code."
            end
            if sections[section] and sections[section][key] then
                local value = ValueDecode(raw, sections[section][key])
                if value == nil then return nil, "Invalid setting: " .. key end
                if sections[section][key] == "number" then
                    if key:match("[XY]$") and (value < -2 or value > 2) then
                        return nil, "Invalid location: " .. key
                    end
                    if not key:match("[XY]$") and (value < 0 or value > 2000) then
                        return nil, "Invalid number: " .. key
                    end
                elseif key == "summonKeywords" and not api.NormalizeSummonKeywords(value) then
                    return nil, "Invalid summon keywords."
                elseif key == "notificationChannel" and value ~= "SELF" and value ~= "GROUP" then
                    return nil, "Invalid notification channel."
                elseif key == "notificationFlags" then
                    for flag in pairs(value) do
                        if not notificationKeys[flag] then return nil, "Invalid notification flag." end
                    end
                end
                data[name] = data[name] or {}
                data[name][section] = data[name][section] or {}
                if data[name][section][key] ~= nil then return nil, "Duplicate setting: " .. key end
                data[name][section][key] = value
                available[section] = true
            end
        end
    end
    if not next(available) then return nil, "No compatible settings in share code." end
    return { version = version, profiles = data, available = available }
end

function sharing.Import(parsed, selected, importAll)
    local db = api.GetDB()
    local names = {}
    for name in pairs(parsed.profiles) do names[#names + 1] = name end
    table.sort(names)
    local chosen = {}
    for _, section in ipairs(sharing.Sections) do
        if selected[section] and parsed.available[section] then chosen[#chosen + 1] = section end
    end
    if #chosen == 0 then return nil, "Select at least one available section." end
    local staged = {}
    for index, name in ipairs(names) do
        if importAll or index == 1 then
            local target = importAll and name or db.activeProfile
            if importAll and db.profiles[target] then
                local base, suffix = name .. " Imported", 2
                target = base
                while db.profiles[target] or staged[target] do
                    target = base .. " " .. suffix
                    suffix = suffix + 1
                end
            end
            if #target > 40 then return nil, "Imported profile name is too long." end
            local copy = {}
            local original = importAll and nil or db.profiles[target]
            if original then
                for key, value in pairs(original) do copy[key] = value end
            end
            for _, section in ipairs(chosen) do
                local values = parsed.profiles[name][section]
                if values then
                    for key, value in pairs(values) do
                        if key == "notificationFlags" or key == "shardVisible" then
                            local enabled = {}
                            for flag, setting in pairs(copy.enabled or {}) do enabled[flag] = setting end
                            if key == "shardVisible" then enabled.soulshards = value and nil or false
                            else
                                for flag, setting in pairs(value) do enabled[flag] = setting and nil or false end
                            end
                            copy.enabled = enabled
                        elseif key == "enabled" then
                            local enabled = {}
                            for flag, setting in pairs(copy.enabled or {}) do
                                if notificationKeys[flag] or flag == "soulshards" then enabled[flag] = setting end
                            end
                            for flag, setting in pairs(value) do
                                if not notificationKeys[flag] and flag ~= "soulshards" then enabled[flag] = setting end
                            end
                            copy.enabled = enabled
                        else copy[key] = value end
                    end
                end
            end
            -- These flags describe past in-place migrations, not user options.
            -- Imported values already use the share schema's current meaning.
            local barValues = parsed.profiles[name].bars
            if barValues and barValues.multiDotScale
                and not barValues.multiDotWidth and not barValues.multiDotHeight then
                copy.multiDotWidth, copy.multiDotHeight = nil, nil
            end
            copy.shardLayoutAdjusted = true
            copy.shardWarningDefaultsV2 = true
            copy.summonKeywordDefaultsV2 = true
            staged[target] = api.NormalizeProfile(copy)
        end
    end
    for name, profile in pairs(staged) do db.profiles[name] = profile end
    api.InitializeProfiles()
    return #names, importAll and "Imported new profiles (existing names got 'Imported')." or "Imported into current profile."
end

WarlockHudSharing = sharing
