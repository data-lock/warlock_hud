-- Optional typography for addon-owned labels and Blizzard cooldown text.
WarlockHudFonts = {}

WarlockHudFonts.Choices = {
    { key = "default", label = "Blizzard default" },
    { key = "friz", label = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { key = "arial", label = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { key = "morpheus", label = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { key = "nimrod", label = "Nimrod", path = "Fonts\\NIM_____.TTF" },
    { key = "skurri", label = "Skurri", path = "Fonts\\SKURRI.TTF" },
}

local paths = {}
for _, choice in ipairs(WarlockHudFonts.Choices) do
    paths[choice.key] = choice.path
end

function WarlockHudFonts.Path(profile, faceKey)
    return paths[profile and profile[faceKey or "fontFace"] or "default"]
        or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

function WarlockHudFonts.Apply(fontString, profile, sizeKey, defaultSize, faceKey)
    if not fontString or not profile then return end
    local face = profile[faceKey or "fontFace"]
    if (not face or face == "default")
        and profile[sizeKey] == nil then return end
    local size = profile[sizeKey] or defaultSize
    local ok, applied = pcall(fontString.SetFont, fontString,
        WarlockHudFonts.Path(profile, faceKey), size, "OUTLINE")
    if not ok or applied == false then
        fontString:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
            size, "OUTLINE")
    end
end

function WarlockHudFonts.ConfigureCountdown(name, profile, sizeKey, defaultSize, faceKey)
    local face = profile and profile[faceKey or "fontFace"]
    if not profile or ((not face or face == "default")
        and profile[sizeKey] == nil) then
        return false
    end
    local font = _G[name] or (CreateFont and CreateFont(name))
    if not font then return false end
    local size = profile[sizeKey] or defaultSize
    local ok, applied = pcall(font.SetFont, font,
        WarlockHudFonts.Path(profile, faceKey), size, "OUTLINE")
    if not ok or applied == false then
        font:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
            size, "OUTLINE")
    end
    font:SetShadowColor(0, 0, 0, 1)
    font:SetShadowOffset(1, -1)
    return true
end
