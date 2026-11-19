-- Remember each demon's pet spellbook and mark known grimoires at merchants.
local frame = CreateFrame("Frame")
local tooltip = CreateFrame("GameTooltip", "WarlockHudGrimoireScanTooltip",
    UIParent, "GameTooltipTemplate")
tooltip:SetOwner(UIParent, "ANCHOR_NONE")
local petScanQueued = false
local merchantPaintQueued = false
local merchantHooked = false
local merchantLastPaintSignature
local merchantHasGrimoires
local merchantGeneration = 0
local grimoireVendorNames = {
    ["Cylina Darkheart"] = true,
    ["Dane Winslow"] = true,
    ["Dannie Fizzwizzle"] = true,
    ["Gina Lang"] = true,
    ["Greshka"] = true,
    ["Hraug"] = true,
    ["Jubahl Corpseeker"] = true,
    ["Jubahl Corpseseeker"] = true,
    ["Kayla Smithe"] = true,
    ["Kitha"] = true,
    ["Kurgul"] = true,
    ["Martha Strain"] = true,
    ["Spackle Thornberry"] = true,
    ["Wren Darkspring"] = true,
}
local petScanRevision = 0
local grimoireDebug = false
local iconBorders = {}
local iconTints = {}
local petNames = { "Imp", "Voidwalker", "Succubus", "Felhunter",
    "Felguard", "Infernal", "Doomguard" }
local petFamilyAliases = { incubus = "succubus", sayaad = "succubus" }
local QueueMerchantPaint

local function DebugValue(value)
    if issecretvalue and issecretvalue(value) then return "restricted" end
    if value == nil then return "nil" end
    return tostring(value):gsub("[%c]", " ")
end

local function TraceGrimoire(event, details)
    if not grimoireDebug or not WarlockHudTraceHUD then return end
    WarlockHudTraceHUD("Grimoire " .. event
        .. (details and (" " .. details) or ""))
end

function WarlockHudGrimoireDebugEnabled()
    return grimoireDebug
end

function WarlockHudToggleGrimoireDebug()
    grimoireDebug = not grimoireDebug
    if WarlockHudOpenDebugTrace then WarlockHudOpenDebugTrace() end
    TraceGrimoire("DEBUG", grimoireDebug and "enabled" or "disabled")
end

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
    if not next(spells) then
        TraceGrimoire("PET_SCAN", "family=" .. tostring(family)
            .. "; spells=none")
        return false
    end
    local spellCount = 0
    for _ in pairs(spells) do spellCount = spellCount + 1 end
    local store = Store()
    if store then
        local known = store[family] or {}
        for name, rank in pairs(spells) do
            known[name] = math.max(known[name] or 0, rank)
        end
        store[family] = known
        petScanRevision = petScanRevision + 1
        TraceGrimoire("PET_SCAN", "family=" .. tostring(family)
            .. "; spells=" .. spellCount)
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

local function MerchantHasGrimoires()
    if merchantHasGrimoires ~= nil then return merchantHasGrimoires end
    local vendorName
    if MerchantNameText and MerchantNameText.GetText then
        vendorName = MerchantNameText:GetText()
    end
    if type(vendorName) ~= "string" or vendorName == "" then
        local ok, name = pcall(UnitName, "npc")
        if ok then vendorName = name end
    end
    if type(vendorName) ~= "string" or vendorName == "" then return nil end
    merchantHasGrimoires = type(vendorName) == "string"
        and grimoireVendorNames[vendorName] == true or false
    return merchantHasGrimoires
end

local function GrimoireInfo(index)
    local itemName = MerchantName(index)
    if type(itemName) ~= "string" then return nil end
    local spellName = itemName:match(
        "^[Gg]rimoire of (.-)%s*%([Rr]ank%s*%d+%)$")
    local rank = Rank(itemName)
    if not spellName then
        spellName = itemName:match("^[Gg]rimoire of (.+)$")
        rank = spellName and 1 or nil
    end
    if not spellName or not rank then return nil end
    tooltip:ClearLines()
    tooltip:SetMerchantItem(index)
    local store = Store()
    local families = {}
    local familyPatterns = {}
    for _, family in ipairs(petNames) do
        local key = CanonicalFamily(family)
        families[family:lower()] = { key = key, display = FamilyLabel(key) }
        familyPatterns[#familyPatterns + 1] = family:lower()
    end
    families.incubus = { key = "succubus", display = FamilyLabel("succubus") }
    families.sayaad = { key = "succubus", display = FamilyLabel("succubus") }
    familyPatterns[#familyPatterns + 1] = "incubus"
    familyPatterns[#familyPatterns + 1] = "sayaad"
    if store then
        for family in pairs(store) do
            local key = CanonicalFamily(family)
            families[family] = { key = key, display = FamilyLabel(key) }
            familyPatterns[#familyPatterns + 1] = family
        end
    end
    for line = 1, tooltip:NumLines() do
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
    if grimoireDebug then
        local tooltipLines = {}
        for line = 1, tooltip:NumLines() do
            local textRegion = _G[tooltip:GetName() .. "TextLeft" .. line]
            local text = textRegion and textRegion:GetText()
            if type(text) == "string" and text ~= "" then
                tooltipLines[#tooltipLines + 1] = text
            end
        end
        local haystack = table.concat(tooltipLines, " "):lower()
        local matchedFamily
        for _, family in ipairs(familyPatterns) do
            if haystack:find(family, 1, true) then
                matchedFamily = family
                break
            end
        end
        TraceGrimoire("CLASSIFY", "index=" .. DebugValue(index)
            .. "; item=" .. DebugValue(itemName)
            .. "; tooltipLineCount=" .. DebugValue(#tooltipLines)
            .. "; family=unmatched"
            .. "; candidate=" .. DebugValue(matchedFamily))
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
    local existing = iconBorders[visible]
    if existing and existing.frame:GetParent() == button then return existing end
    if existing then existing.frame:Hide() end
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

local function ClearMerchantMark(button, visible)
    TintIcon(button, visible)
    local border = BorderFor(button, visible)
    border.frame:Hide()
end

local function ClearMerchantMarks()
    local perPage = MERCHANT_ITEMS_PER_PAGE or 10
    for visible = 1, perPage do
        local button = _G["MerchantItem" .. visible .. "ItemButton"]
        if button then ClearMerchantMark(button, visible) end
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

local function MerchantAvailabilityDetails(index)
    local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo
        and C_MerchantFrame.GetItemInfo(index)
    if info then
        return "usable=" .. DebugValue(info.isUsable)
            .. "; purchasable=" .. DebugValue(info.isPurchasable)
            .. "; stock=" .. DebugValue(info.numAvailable)
    end
    if GetMerchantItemInfo then
        local _, _, _, _, stock, usable = GetMerchantItemInfo(index)
        return "usable=" .. DebugValue(usable)
            .. "; stock=" .. DebugValue(stock)
    end
    return "api=unavailable"
end

local function RequiredItemLevel(index)
    local link = GetMerchantItemLink and GetMerchantItemLink(index)
    if not link then return nil end
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not getInfo then return nil end
    local _, _, _, _, requiredLevel = getInfo(link)
    return type(requiredLevel) == "number" and requiredLevel or nil
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

local function MerchantPageSignature(perPage, total)
    local parts = {
        DebugValue(MerchantFrame.selectedTab),
        DebugValue(total),
        DebugValue(UnitLevel("player")),
        DebugValue(petScanRevision),
    }
    for visible = 1, perPage do
        local button = _G["MerchantItem" .. visible .. "ItemButton"]
        local index = button and button:GetID()
        local link = type(index) == "number" and GetMerchantItemLink
            and GetMerchantItemLink(index)
        local itemID = type(link) == "string"
            and link:match("|Hitem:(%d+)") or ""
        local available = ""
        local requiredLevel = ""
        if MerchantFrame.selectedTab == 1 and type(index) == "number"
            and index <= total then
            available = DebugValue(MerchantAvailable(index))
            requiredLevel = DebugValue(RequiredItemLevel(index))
        end
        parts[#parts + 1] = table.concat({
            DebugValue(index), itemID, available, requiredLevel,
        }, ":")
    end
    return table.concat(parts, "|")
end

local function PaintMerchant()
    merchantPaintQueued = false
    if not MerchantFrame or not MerchantFrame:IsShown()
        or not GetMerchantNumItems then return end
    if MerchantHasGrimoires() ~= true then return end
    local perPage = MERCHANT_ITEMS_PER_PAGE or 10
    local total = GetMerchantNumItems()
    local signature = MerchantPageSignature(perPage, total)
    if signature == merchantLastPaintSignature then return end
    merchantLastPaintSignature = signature
    TraceGrimoire("PAINT", "tab=" .. DebugValue(MerchantFrame.selectedTab)
        .. "; total=" .. DebugValue(total)
        .. "; visibleSlots=" .. DebugValue(perPage))
    -- Clear previous grimoire colors before reading the current merchant page.
    -- Merchant buttons are recycled between vendors and pages, and one stale
    -- item-info read must not leave a grimoire mark on an ordinary item.
    for visible = 1, perPage do
        local button = _G["MerchantItem" .. visible .. "ItemButton"]
        if button then
            ClearMerchantMark(button, visible)
        end
    end
    local availableRanks = {}
    if MerchantFrame.selectedTab == 1 then
        local ok, ranks = pcall(AvailableRanks)
        if ok and type(ranks) == "table" then availableRanks = ranks end
    end
    for visible = 1, perPage do
        local button = _G["MerchantItem" .. visible .. "ItemButton"]
        if button then
            local border = BorderFor(button, visible)
            local index = button and button:GetID()
            local state, spell, rank, family, classifyError
            local itemName
            if grimoireDebug and type(index) == "number" then
                local nameOK, name = pcall(MerchantName, index)
                if nameOK then itemName = name end
            end
            if MerchantFrame.selectedTab == 1 and button:IsShown()
                and type(index) == "number" and index <= total then
                local ok, currentState, _, currentSpell, currentRank,
                    currentFamily = pcall(KnownState, index)
                if ok then
                    state, spell, rank, family = currentState, currentSpell,
                        currentRank, currentFamily
                else
                    classifyError = currentState
                end
            end
            local r, g, b
            local requiredLevel
            if state and type(index) == "number" then
                local levelOK, value = pcall(RequiredItemLevel, index)
                if levelOK then requiredLevel = value end
            end
            local belowLevel = requiredLevel
                and UnitLevel("player") < requiredLevel
            if state == "known" or belowLevel then
                r, g, b = 1, 0.2, 0.2
            elseif state == "unscanned" then
                if requiredLevel and UnitLevel("player") >= requiredLevel then
                    r, g, b = 0.6, 0.6, 0.6
                end
            elseif state == "missing" then
                local ok, available = pcall(MerchantAvailable, index)
                if ok and available then
                    local rankOK, higher = pcall(HigherAvailableRank,
                        spell, rank, family, availableRanks)
                    if rankOK and higher then
                        r, g, b = 1, 0.82, 0.15
                    else
                        r, g, b = 0.25, 1, 0.35
                    end
                end
            end
            if r then
                TintIcon(button, visible, r, g, b)
                for _, edge in ipairs(border.edges) do
                    edge:SetVertexColor(r, g, b)
                end
                border.frame:Show()
            end
            if grimoireDebug then
                local link
                if type(index) == "number" then
                    if GetMerchantItemLink then
                        local linkOK, itemLink = pcall(GetMerchantItemLink, index)
                        if linkOK then link = itemLink end
                    end
                end
                local itemID = type(link) == "string"
                    and link:match("|Hitem:(%d+)") or nil
                local available = "n/a"
                local availabilityDetails = "n/a"
                if MerchantFrame.selectedTab == 1 and type(index) == "number"
                    and index <= total then
                    local ok, result = pcall(MerchantAvailable, index)
                    available = ok and tostring(result) or "error"
                    local detailsOK, details = pcall(MerchantAvailabilityDetails, index)
                    if detailsOK then availabilityDetails = details end
                end
                local mark = r and string.format("rgb(%.2f,%.2f,%.2f)", r, g, b)
                    or "cleared"
                TraceGrimoire("ROW", "slot=" .. DebugValue(visible)
                    .. "; index=" .. DebugValue(index)
                    .. "; tab=" .. DebugValue(MerchantFrame.selectedTab)
                    .. "; item=" .. DebugValue(itemName)
                    .. "; itemID=" .. DebugValue(itemID)
                    .. "; state=" .. DebugValue(state)
                    .. "; spell=" .. DebugValue(spell)
                    .. "; rank=" .. DebugValue(rank)
                    .. "; family=" .. DebugValue(family)
                    .. "; requiredLevel=" .. DebugValue(requiredLevel)
                    .. "; playerLevel=" .. DebugValue(UnitLevel("player"))
                    .. "; available=" .. available
                    .. "; " .. availabilityDetails
                    .. "; iconTint=" .. DebugValue(r and "applied" or "reset")
                    .. "; classifyError=" .. DebugValue(classifyError)
                    .. "; mark=" .. mark)
            end
        end
    end
end

QueueMerchantPaint = function()
    if MerchantFrame and MerchantFrame:IsShown()
        and MerchantHasGrimoires() ~= true then return end
    if merchantPaintQueued then return end
    merchantPaintQueued = true
    local generation = merchantGeneration
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            if generation ~= merchantGeneration then return end
            PaintMerchant()
        end)
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
    if MerchantNextPageButton then
        MerchantNextPageButton:HookScript("OnClick", function()
            QueueMerchantPaint()
        end)
    end
    if MerchantPrevPageButton then
        MerchantPrevPageButton:HookScript("OnClick", function()
            QueueMerchantPaint()
        end)
    end
    if GameTooltip and GameTooltip.SetMerchantItem then
        hooksecurefunc(GameTooltip, "SetMerchantItem", function(self, index)
            if MerchantHasGrimoires() == false then return end
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
        merchantGeneration = merchantGeneration + 1
        merchantPaintQueued = false
        merchantLastPaintSignature = nil
        merchantHasGrimoires = nil
        ClearMerchantMarks()
        QueuePetScan(4)
    end
    if event == "GET_ITEM_INFO_RECEIVED" and merchantHasGrimoires == nil then
        merchantLastPaintSignature = nil
    end
    if event == "MERCHANT_UPDATE" then
        -- Buying an item may cause Blizzard to reset the merchant icon tint
        -- even when stock and row identity are unchanged. Force our mark back.
        merchantLastPaintSignature = nil
    end
    if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE"
        or event == "GET_ITEM_INFO_RECEIVED" then
        QueueMerchantPaint()
    elseif event == "SPELLS_CHANGED" or event == "PET_BAR_UPDATE" then
        QueueMerchantPaint()
    end
end)
