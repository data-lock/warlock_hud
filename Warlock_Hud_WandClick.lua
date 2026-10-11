-- World clicks need a secure state driver: ordinary right-click remains
-- available when Shift is up or the cursor is not over a living enemy.
-- Adapted for wand-only use from Shift & Shoot (MIT license, Osaki_).
local SHOOT_WAND = 5019
local owner = CreateFrame("Frame")
local button = CreateFrame("Button", "WarlockHudWandClickButton", UIParent,
    "SecureActionButtonTemplate")
button:RegisterForClicks("AnyDown", "AnyUp")
button:SetAttribute("type", "macro")

local driver = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
driver:SetFrameRef("button", button)
driver:SetAttribute("_onstate-wand", [[
    if newstate == "on" then
        self:SetBindingClick(true, "SHIFT-BUTTON2", self:GetFrameRef("button"))
    else
        self:ClearBindings()
    end
]])

-- The default state driver cadence can miss a click immediately after the
-- cursor moves onto a unit.
if SecureStateDriverManager then
    SecureStateDriverManager:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
end

local pendingUpdate = false
local debugEnabled = false
local function WandSpellName()
    local itemID = GetInventoryItemID("player", INVSLOT_RANGED)
    if not itemID or not C_Item or not C_Item.GetItemInfoInstant
        or not Enum or not Enum.ItemWeaponSubclass then return nil end
    local _, _, _, _, _, _, subClassID = C_Item.GetItemInfoInstant(itemID)
    if subClassID ~= Enum.ItemWeaponSubclass.Wand then return nil end
    if C_SpellBook and C_SpellBook.IsSpellKnown
        and not C_SpellBook.IsSpellKnown(SHOOT_WAND) then return nil end
    return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(SHOOT_WAND)
end

local function RefreshBinding()
    if InCombatLockdown() then
        pendingUpdate = true
        return
    end
    pendingUpdate = false
    UnregisterStateDriver(driver, "wand")
    driver:SetAttribute("state-wand", "off")
    ClearOverrideBindings(driver)
    local spellName = WarlockHudAPI and WarlockHudAPI.IsAddonEnabled()
        and WandSpellName()
    if spellName then
        button:SetAttribute("macrotext", ("/target [@mouseover,harm,nodead]\n"
            .. "/cast [@mouseover,harm,nodead] %s"):format(spellName))
        RegisterStateDriver(driver, "wand",
            "[@mouseover,harm,nodead,mod:shift] on; off")
    end
end

WarlockHudRefreshWandBinding = RefreshBinding

button:HookScript("PostClick", function(_, _, down)
    if debugEnabled and down == GetCVarBool("ActionButtonUseKeyDown") then
        local name = UnitName("mouseover")
        if issecretvalue and issecretvalue(name) then name = "?" end
        print("Warlock HUD wand: click received; mouseover="
            .. tostring(name))
    end
end)
driver:HookScript("OnAttributeChanged", function(_, name, value)
    if debugEnabled and name == "state-wand" then
        print("Warlock HUD wand: state=" .. tostring(value))
    end
end)

SLASH_WARLOCKHUDWAND1 = "/whwand"
SlashCmdList.WARLOCKHUDWAND = function(message)
    if message == "debug" then
        debugEnabled = not debugEnabled
    end
    local itemID = GetInventoryItemID("player", INVSLOT_RANGED)
    print("Warlock HUD wand: item=" .. tostring(itemID)
        .. " spell=" .. tostring(WandSpellName())
        .. " state=" .. tostring(driver:GetAttribute("state-wand"))
        .. " binding=" .. tostring(GetBindingAction("SHIFT-BUTTON2", true))
        .. " debug=" .. tostring(debugEnabled))
end

owner:RegisterEvent("PLAYER_LOGIN")
owner:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
owner:RegisterEvent("SPELLS_CHANGED")
owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:SetScript("OnEvent", function(_, event, slot)
    if event == "PLAYER_EQUIPMENT_CHANGED" and slot ~= INVSLOT_RANGED then return end
    if event == "PLAYER_REGEN_ENABLED" and not pendingUpdate then return end
    RefreshBinding()
end)
