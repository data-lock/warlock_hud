-- Optional diagnostics. Aura reads here run only on explicit slash commands
-- and stop during combat or when the client marks aura data as secret.
WarlockHudDebug = {}

function WarlockHudDebug.TracePetBuffs(report)
    if InCombatLockdown() or (C_Secrets and C_Secrets.ShouldAurasBeSecret
        and C_Secrets.ShouldAurasBeSecret()) then
        report("Pet buff scan is unavailable during combat or secret aura states.")
        return
    end
    if not C_UnitAuras or not C_UnitAuras.GetBuffDataByIndex then
        report("Pet buff scan API is unavailable on this client.")
        return
    end
    local ok, exists = pcall(UnitExists, "pet")
    if not ok or (issecretvalue and issecretvalue(exists)) then
        report("Pet presence is unreadable.")
        return
    end
    if not exists then
        report("No pet to scan.")
        return
    end
    local count = 0
    for index = 1, 40 do
        local readOK, aura = pcall(C_UnitAuras.GetBuffDataByIndex, "pet", index)
        if not readOK or (issecretvalue and issecretvalue(aura)) then
            report("Pet buff " .. index .. " is unreadable; scan stopped.")
            return
        end
        if not aura then break end
        local name, spellID = aura.name, aura.spellId
        if (issecretvalue and (issecretvalue(name) or issecretvalue(spellID))) then
            report("Pet buff " .. index .. " has restricted fields; scan stopped.")
            return
        end
        report("Pet buff " .. index .. ": " .. tostring(name)
            .. " (ID " .. tostring(spellID) .. ")")
        count = count + 1
    end
    if count == 0 then report("Pet has no visible buffs.") end
end
