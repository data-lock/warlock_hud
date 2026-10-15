-- Spellbook and talent availability checks shared by HUD features.
WarlockHudSpellbook = {}

local function KnownSpellID(spellID)
    local checker = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell
    if not checker then return nil end
    local ok, known = pcall(checker, spellID)
    if not ok or (issecretvalue and issecretvalue(known)) then return nil end
    return known and true or false
end

local function KnownSpell(spell)
    local checked = false
    for _, spellID in ipairs(spell.ids) do
        local known = KnownSpellID(spellID)
        if known then return true end
        if known == false then checked = true end
    end
    local currentID = C_Spell and C_Spell.GetSpellIDForSpellIdentifier
        and C_Spell.GetSpellIDForSpellIdentifier(spell.name)
    if currentID then
        local known = KnownSpellID(currentID)
        if known then return true end
        if known == false then checked = true end
    end
    return not checked
end

local function KnowsDemonicBrand()
    -- Passive talents may not be reported as known spellbook spells. Prefer
    -- the active talent group's learned rank when the talent API is present.
    if GetNumTalents and GetTalentInfo then
        local ok, count = pcall(GetNumTalents, 2)
        if ok and type(count) == "number" then
            for index = 1, count do
                local found, name, _, _, _, rank = pcall(GetTalentInfo, 2, index)
                if found and name == "Demonic Brand" then
                    return type(rank) == "number" and rank > 0
                end
            end
        end
    end
    return KnownSpellID(1293695) == true
end

local function ConflagrateSpellID()
    local spellID = C_Spell and C_Spell.GetSpellIDForSpellIdentifier
        and C_Spell.GetSpellIDForSpellIdentifier("Conflagrate")
    if spellID and KnownSpellID(spellID) == true then return spellID end
    for _, rankID in ipairs({ 18932, 18931, 18930, 17962, 1293818, 1293817 }) do
        if KnownSpellID(rankID) == true then return rankID end
    end
end

local function CastSpellTexture(spell, currentID)
    if not spell or not C_Spell or not C_Spell.GetSpellTexture then return nil end
    local identifiers = {}
    if currentID then identifiers[#identifiers + 1] = currentID end
    identifiers[#identifiers + 1] = spell.name
    for _, id in ipairs(spell.ids) do identifiers[#identifiers + 1] = id end
    for _, identifier in ipairs(identifiers) do
        local ok, texture = pcall(C_Spell.GetSpellTexture, identifier)
        if ok and texture and (not issecretvalue or not issecretvalue(texture))
            and texture ~= 134400
            and (type(texture) ~= "string"
                or not texture:lower():find("questionmark", 1, true)) then
            return texture
        end
    end
end

WarlockHudSpellbook.KnownSpellID = KnownSpellID
WarlockHudSpellbook.KnownSpell = KnownSpell
WarlockHudSpellbook.KnowsDemonicBrand = KnowsDemonicBrand
WarlockHudSpellbook.ConflagrateSpellID = ConflagrateSpellID
WarlockHudSpellbook.CastSpellTexture = CastSpellTexture
