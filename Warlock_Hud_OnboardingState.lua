-- Capture this before Warlock_Hud.lua can create a default database.
WarlockHudOnboarding = { freshAtLoad = WarlockHudDB == nil }

local onboarding = WarlockHudOnboarding

function onboarding.Migrate(db)
    if type(db) ~= "table" then return false end
    if type(db.onboarding) == "table" and db.onboarding.schemaVersion == 1 then
        return db.onboarding.completed ~= true
    end
    if onboarding.freshAtLoad then
        db.onboarding = { schemaVersion = 1, completed = false }
        return true
    end
    -- An old account has no onboarding field. Never infer that it is new.
    db.onboarding = { schemaVersion = 1, completed = true }
    return false
end

local function CopyProfile(source)
    local result = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            local copy = {}
            for child, setting in pairs(value) do copy[child] = setting end
            result[key] = copy
        else
            result[key] = value
        end
    end
    return result
end

function onboarding.Preset(profile, preset, keys)
    if type(profile) ~= "table" or (preset ~= "basic" and preset ~= "advanced") then
        return nil
    end
    local result = CopyProfile(profile)
    result.enabled = result.enabled or {}
    for _, group in ipairs({ keys.main, keys.cooldown, keys.buff, keys.proc }) do
        for _, key in ipairs(group) do result.enabled[key] = nil end
    end
    result.enabled.wellfed = nil
    result.enabled.soulshards = nil
    result.consumesEnabled = true
    result.multiDotEnabled = preset == "advanced"
    result.multiDotDamageEnabled = preset == "advanced"
    result.multiDotThreatIndicator = preset == "advanced"
    result.summonQueueEnabled = preset == "advanced"
    return result
end
