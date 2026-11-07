-- Remember each demon's pet spellbook and mark known grimoires at merchants.
local frame = CreateFrame("Frame")
local tooltip = CreateFrame("GameTooltip", "WarlockHudGrimoireScanTooltip",
    UIParent, "GameTooltipTemplate")
tooltip:SetOwner(UIParent, "ANCHOR_NONE")
local petScanQueued = false
local merchantPaintQueued = false
local merchantHooked = false
local iconBorders = {}
local iconTints = {}
local petNames = { "Imp", "Voidwalker", "Succubus", "Felhunter",
    "Felguard", "Infernal", "Doomguard" }
local petFamilyAliases = { incubus = "succubus", sayaad = "succubus" }
local QueueMerchantPaint

local function CanonicalFamily(family)
    local key = type(family) == "string" and family:lower()
    return key and (petFamilyAliases[key] or key)
end

local function FamilyLabel(family)
    return family == "succubus" and "Succubus/Incubus" or family
end

local function Rank(text)
    return type(text) == "string" and tonumber(text:match("[Rr]ank%s*(%d+)"))
        or nil
end

local function Store()
    local guid = UnitGUID("player")
    if not guid or type(WarlockHudDB) ~= "table" then return nil end
    WarlockHudDB.petGrimoiresByCharacter =
        WarlockHudDB.petGrimoiresByCharacter or {}
    local byCharacter = WarlockHudDB.petGrimoiresByCharacter
    byCharacter[guid] = byCharacter[guid] or {}
    return byCharacter[guid]
end

local function ScanPet()
    petScanQueued = false
    if not UnitExists("pet") or not UnitCreatureFamily
        or not C_SpellBook or not C_SpellBook.HasPetSpells
        or not C_SpellBook.GetSpellBookItemInfo then return end
    local family = CanonicalFamily(UnitCreatureFamily("pet"))
    local count = C_SpellBook.HasPetSpells()
    local bank = Enum and Enum.SpellBookSpellBank
        and Enum.SpellBookSpellBank.Pet
    if not family or not count or count < 1 or bank == nil then return end
    local spells = {}
    for slot = 1, count do
        local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
        if info and info.name then
            local rank = Rank(info.subName) or Rank(info.name)
            if not rank and C_Spell and C_Spell.GetSpellSubtext then
                rank = Rank(C_Spell.GetSpellSubtext(
                    info.spellID or info.actionID))
            end
            local key = info.name:gsub("%s*%([Rr]ank%s*%d+%)$", ""):lower()
            spells[key] = math.max(spells[key] or 0, rank or 1)
        end
    end
    if not next(spells) then return false end
    local store = Store()
    if store then
        local known = store[family] or {}
        for name, rank in pairs(spells) do
            known[name] = math.max(known[name] or 0, rank)
        end
        store[family] = known
        return true
    end
    return false
end

local function QueuePetScan(retries)
    if petScanQueued then return end
    petScanQueued = true
    local function ScanWhenReady()
        petScanQueued = false
        local scanned = ScanPet()
        if scanned then
            if QueueMerchantPaint and MerchantFrame and MerchantFrame:IsShown() then
                QueueMerchantPaint()
            end
        elseif retries and retries > 0 then
            QueuePetScan(retries - 1)
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, ScanWhenReady)
    else
        ScanWhenReady()
    end
end

local function MerchantName(index)
    local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo
        and C_MerchantFrame.GetItemInfo(index)
    if info and info.name then return info.name end
    local link = GetMerchantItemLink and GetMerchantItemLink(index)
    if link and C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(link)
    end
end

local function GrimoireInfo(index)
    local itemName = MerchantName(index)
    if type(itemName) ~= "string" then return nil end
    local spellName = itemName:match("^[Gg]rimoire of (.-)%s*%([Rr]ank%s*%d+%)")
    local rank = Rank(itemName)
    if not spellName or not rank then return nil end
    tooltip:ClearLines()
    tooltip:SetMerchantItem(index)
    local store = Store()
    local families = {}
    for _, family in ipairs(petNames) do
        local key = CanonicalFamily(family)
        families[family:lower()] = { key = key, display = FamilyLabel(key) }
    end
    families.incubus = { key = "succubus", display = FamilyLabel("succubus") }
    families.sayaad = { key = "succubus", display = FamilyLabel("succubus") }
    if store then
        for family in pairs(store) do
            local key = CanonicalFamily(family)
            families[family] = { key = key, display = FamilyLabel(key) }
        end
    end
    for line = 2, tooltip:NumLines() do
        local textRegion = _G[tooltip:GetName() .. "TextLeft" .. line]
        local text = textRegion and textRegion:GetText()
        if type(text) == "string" then
            local lower = text:lower()
            for family, info in pairs(families) do
                if lower:find("%f[%a]" .. family .. "%f[%A]") then
                    return spellName:lower(), rank, info.key, info.display
                end
            end
        end
    end
end

local function KnownState(index)
    local spell, rank, family, displayName = GrimoireInfo(index)
    if not family then return nil end
    local store = Store()
    local spells = store and store[family]
    local scanned = spells ~= nil
    if store and family == "succubus" then
        spells = spells or {}
        for alias in pairs(petFamilyAliases) do
            local old = store[alias]
            if old then
                scanned = true
                for name, knownRank in pairs(old) do
                    spells[name] = math.max(spells[name] or 0, knownRank)
                end
            end
        end
    end
    if not scanned then
        return "unscanned", displayName, spell, rank, family
    end
    return (spells[spell] or 0) >= rank and "known" or "missing",
        displayName, spell, rank, family
end

local function BorderFor(button, visible)
    if iconBorders[visible] then return iconBorders[visible] end
    local border = CreateFrame("Frame", nil, button)
    border:EnableMouse(false)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    border:SetFrameLevel(button:GetFrameLevel() + 5)
    local edges = {}
    for i = 1, 4 do
        edges[i] = border:CreateTexture(nil, "OVERLAY")
        edges[i]:SetColorTexture(1, 1, 1, 1)
    end
    edges[1]:SetPoint("TOPLEFT")
    edges[1]:SetPoint("TOPRIGHT")
    edges[1]:SetHeight(3)
    edges[2]:SetPoint("BOTTOMLEFT")
    edges[2]:SetPoint("BOTTOMRIGHT")
    edges[2]:SetHeight(3)
    edges[3]:SetPoint("TOPLEFT")
    edges[3]:SetPoint("BOTTOMLEFT")
    edges[3]:SetWidth(3)
    edges[4]:SetPoint("TOPRIGHT")
    edges[4]:SetPoint("BOTTOMRIGHT")
    edges[4]:SetWidth(3)
    iconBorders[visible] = { frame = border, edges = edges }
    return iconBorders[visible]
end

local function TintIcon(button, visible, r, g, b)
    local icon = button.icon or button.Icon
    if not icon and button.GetName then
        local name = button:GetName()
        icon = name and _G[name .. "IconTexture"]
    end
    if not icon then return end
    local tint = iconTints[visible]
    if not tint or tint.icon ~= icon then
        local red, green, blue = icon:GetVertexColor()
        tint = { icon = icon, red = red, green = green, blue = blue }
        iconTints[visible] = tint
    end
    if r then
        icon:SetVertexColor(r, g, b)
    else
        icon:SetVertexColor(tint.red, tint.green, tint.blue)
    end
end

local function MerchantAvailable(index)
    local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo
        and C_MerchantFrame.GetItemInfo(index)
    if info and info.isUsable ~= nil then
        return info.isUsable and info.numAvailable ~= 0
    end
    if GetMerchantItemInfo then
        local _, _, _, _, count, usable = GetMerchantItemInfo(index)
        return usable and count ~= 0
    end
    return false
end

local function MeetsItemLevel(index)
    local link = GetMerchantItemLink and GetMerchantItemLink(index)
    if not link then return false end
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not getInfo then return false end
    local _, _, _, _, requiredLevel = getInfo(link)
    return type(requiredLevel) == "number"
        and UnitLevel("player") >= requiredLevel
end

local function AvailableRanks()
    local ranks = {}
    if not GetMerchantNumItems then return ranks end
    for index = 1, GetMerchantNumItems() do
        if MerchantAvailable(index) then
            local candidateSpell, candidateRank, candidateFamily =
                GrimoireInfo(index)
            if candidateSpell and candidateRank and candidateFamily then
                local bySpell = ranks[candidateFamily] or {}
                bySpell[candidateSpell] = math.max(
                    bySpell[candidateSpell] or 0, candidateRank)
                ranks[candidateFamily] = bySpell
            end
        end
    end
    return ranks
end

local function HigherAvailableRank(spell, rank, family, ranks)
    if not spell or not rank or not family then return nil end
    local bySpell = (ranks or AvailableRanks())[family]
    local highest = bySpell and bySpell[spell]
    return highest and highest > rank and highest or nil
end

local function PaintMerchant()
    merchantPaintQueued = false
    if not MerchantFrame or not MerchantFrame:IsShown()
        or not GetMerchantNumItems then return end
    if not ScanPet() then QueuePetScan(4) end
    local perPage = MERCHANT_ITEMS_PER_PAGE or 10
    local total = GetMerchantNumItems()
    local availableRanks = MerchantFrame.selectedTab == 1
        and AvailableRanks() or {}
    for visible = 1, perPage do
        local button = _G["MerchantItem" .. visible .. "ItemButton"]
        if button then
            local border = BorderFor(button, visible)
            local index = button and button:GetID()
            local state, spell, rank, family
            if MerchantFrame.selectedTab == 1 and button:IsShown()
                and type(index) == "number" and index <= total then
                local displayName
                state, displayName, spell, rank, family = KnownState(index)
            end
            local r, g, b
            if state == "known" then
                r, g, b = 1, 0.2, 0.2
            elseif state == "unscanned" and MeetsItemLevel(index) then
                r, g, b = 0.6, 0.6, 0.6
            elseif state == "missing" and MerchantAvailable(index) then
                if HigherAvailableRank(spell, rank, family,
                    availableRanks) then
                    r, g, b = 1, 0.82, 0.15
                else
                    r, g, b = 0.25, 1, 0.35
                end
            end
            if r then
                TintIcon(button, visible, r, g, b)
                for _, edge in ipairs(border.edges) do
                    edge:SetVertexColor(r, g, b)
                end
                border.frame:Show()
            else
                TintIcon(button, visible)
                border.frame:Hide()
            end
        end
    end
end

QueueMerchantPaint = function()
    if merchantPaintQueued then return end
    merchantPaintQueued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, PaintMerchant)
    else
        PaintMerchant()
    end
end

local function HookMerchant()
    if merchantHooked then return end
    merchantHooked = true
    if type(MerchantFrame_UpdateMerchantInfo) == "function" then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", QueueMerchantPaint)
    end
    if type(MerchantFrame_Update) == "function" then
        hooksecurefunc("MerchantFrame_Update", QueueMerchantPaint)
    end
    if MerchantNextPageButton then
        MerchantNextPageButton:HookScript("OnClick", QueueMerchantPaint)
    end
    if MerchantPrevPageButton then
        MerchantPrevPageButton:HookScript("OnClick", QueueMerchantPaint)
    end
    if GameTooltip and GameTooltip.SetMerchantItem then
        hooksecurefunc(GameTooltip, "SetMerchantItem", function(self, index)
            local state, family, spell, rank, familyKey = KnownState(index)
            if state == "known" then
                self:AddLine("Already known by your " .. family .. ".",
                    1, 0.2, 0.2)
                self:Show()
            elseif state == "missing" then
                local better = HigherAvailableRank(spell, rank, familyKey)
                if better then
                    self:AddLine("Not yet known. Rank " .. better
                        .. " is available for sale.", 1, 0.82, 0.15)
                else
                    self:AddLine("Not yet known by your " .. family .. ".",
                        0.25, 1, 0.35)
                end
                self:Show()
            elseif state == "unscanned" then
                self:AddLine("Summon your " .. family
                    .. " once to check its known spells.", 0.75, 0.75, 0.75)
                self:Show()
            end
        end)
    end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UNIT_PET")
frame:RegisterEvent("PET_BAR_UPDATE")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_UPDATE")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_PET" and unit ~= "player" then return end
    if event == "PLAYER_LOGIN" or event == "UNIT_PET"
        or event == "PET_BAR_UPDATE" or event == "SPELLS_CHANGED" then
        QueuePetScan(4)
    end
    if event == "MERCHANT_SHOW" then
        HookMerchant()
        QueuePetScan(4)
    end
    if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE"
        or event == "GET_ITEM_INFO_RECEIVED" or event == "SPELLS_CHANGED"
        or event == "PET_BAR_UPDATE" then
        QueueMerchantPaint()
    end
end)
