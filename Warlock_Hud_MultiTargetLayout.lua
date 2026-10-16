-- Multi-Target row compaction and scroll range.
WarlockHudMultiTargetLayout = {}

function WarlockHudMultiTargetLayout.New(getRows, dotSlots, iconSize, rowHeight,
    profile, getScrollFrames, markPending)
    local ICON_SIZE, ROW_HEIGHT = iconSize, rowHeight
    local Profile = profile

    local function UpdateScrollRange(height, present)
        local scrollFrame, _, scrollBar = getScrollFrames()
        local viewportHeight = height - 57
        local maxScroll = math.max(0, present * ROW_HEIGHT - viewportHeight)
        scrollBar:SetMinMaxValues(0, maxScroll)
        scrollBar:SetShown(maxScroll > 0)
        if scrollBar:GetValue() > maxScroll then scrollBar:SetValue(maxScroll) end
        if maxScroll == 0 then scrollFrame:SetVerticalScroll(0) end
    end

    local function CompactRows(width, height, positionsOnly)
        local _, scrollContent = getScrollFrames()
        local displayWidth = width - (dotSlots() * (ICON_SIZE + 3) + 38)
        local healthWidth = displayWidth - 37
        local profile = Profile()
        local showExecute = profile and profile.enabled
            and profile.enabled.executeMarker ~= false
        local step = ROW_HEIGHT
        local present = 0
        for _, row in ipairs(getRows()) do
            if row.present then present = present + 1 end
        end
        local activePosition, emptyPosition = 0, present
        for _, row in ipairs(getRows()) do
            local position
            if row.present then
                activePosition = activePosition + 1
                position = activePosition
            else
                emptyPosition = emptyPosition + 1
                position = emptyPosition
            end
            if not positionsOnly then row.display:SetWidth(displayWidth) end
            if row.position ~= position or row.step ~= step then
                local y = -(position - 1) * step
                if positionsOnly then
                    -- These display frames are created outside combat. Move only
                    -- an unprotected existing parent; never rebuild native auras.
                    local checked, protected = pcall(row.display.IsProtected, row.display)
                    if not checked or (issecretvalue and issecretvalue(protected))
                        or protected then
                        markPending()
                    else
                        local moved = pcall(row.display.SetPoint, row.display,
                            "TOPLEFT", scrollContent, "TOPLEFT", 0, y)
                        if moved then row.position, row.step = position, step
                        else markPending() end
                    end
                else
                    row.display:ClearAllPoints()
                    row.display:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, y)
                    row.position, row.step = position, step
                end
            end
            if not positionsOnly then
                row.name:SetWidth(math.max(42, displayWidth - 168))
                for _, segment in ipairs({ row.damageMarker, row.baneMarker,
                    row.siphonMarker, row.immolateMarker }) do
                    segment:SetWidth(healthWidth)
                end
                for _, tick in ipairs({ row.executeOutline, row.executeLine }) do
                    tick:ClearAllPoints()
                    tick:SetPoint("CENTER", row.healthBar, "LEFT", healthWidth * 0.2, 0)
                    tick:SetShown(showExecute)
                end
            end
        end
        UpdateScrollRange(height, present)
    end
    return CompactRows
end
