local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles

local Module = UI:NewModule("Nameplates", "KamiUI_Nameplates")


local Layout = UI.Layout.Nameplates

local flatTexture = "Interface\\Buttons\\WHITE8X8"
-- Restored from the original 5px nameplate design (256x8 RGBA).
-- The baked alpha fades vertically from 100% through 60% to 20%,
-- and horizontally toward fully transparent rounded ends.
local healthFadeTexture =
    "Interface\\AddOns\\KamiUI_Nameplates\\Textures\\HealthFade"
local fontPath, _, fontFlags = GameFontNormalSmall:GetFont()

local styled = {}

local healthPercentCurve = C_CurveUtil.CreateCurve()
healthPercentCurve:AddPoint(0.0, 0.0)
healthPercentCurve:AddPoint(1.0, 100.0)

local CLASSIFICATION_SUFFIX = {
    elite = "E",
    rare = "R",
    rareelite = "RE",
    worldboss = "B",
}

local function ConfigureSingleLine(fontString)
    if fontString.SetWordWrap then
        fontString:SetWordWrap(false)
    end

    if fontString.SetMaxLines then
        fontString:SetMaxLines(1)
    end
end

local function GetDisplayIdentity(unit)
    -- Names and levels may be secret in instances. Keep the raw values:
    -- FontString:SetText / SetFormattedText can render them even though
    -- Lua cannot compare, concatenate or stringify them.
    local name
    if GetUnitName then
        name = GetUnitName(unit)
    end
    if UI:CanAccessValue(name) and not name and UnitName then
        name = UnitName(unit)
    end

    local level = UnitLevel(unit)
    local levelIsSecret = not UI:CanAccessValue(level)
    local classification = UnitClassification(unit)

    local levelText = ""
    local suffix = ""
    local levelR, levelG, levelB = 1, 0.10, 0.10

    if not levelIsSecret and type(level) == "number" then
        levelText = level > 0 and tostring(level) or "??"

        if level > 0 then
            local color = Palette:GetLevelDifficultyColor(level)

            if color then
                levelR = color.r or color[1] or levelR
                levelG = color.g or color[2] or levelG
                levelB = color.b or color[3] or levelB
            end
        end
    end

    if UI:CanAccessValue(classification) and classification then
        suffix = CLASSIFICATION_SUFFIX[classification] or ""
    end

    return name, level, levelText, suffix, levelIsSecret,
        levelR, levelG, levelB
end

local function GetUnitColor(unit)
    local tapDenied = UnitIsTapDenied and UnitIsTapDenied(unit)

    if UI:CanAccessValue(tapDenied) and tapDenied then
        return 0.35, 0.35, 0.35
    end

    local multiplier = 0.60
    local threat = UnitThreatSituation and UnitThreatSituation("player", unit)

    if threat and UI:CanAccessValue(threat) and threat >= 2 then
        multiplier = 0.90
    end

    local isPlayer = UnitIsPlayer(unit)

    if UI:CanAccessValue(isPlayer) and isPlayer then
        local _, class = UnitClass(unit)

        if class and UI:CanAccessValue(class) then
            local color = Palette:GetClassColor(class)

            if color then
                local r = color.r or color[1]
                local g = color.g or color[2]
                local b = color.b or color[3]

                return r * multiplier,
                    g * multiplier,
                    b * multiplier
            end
        end
    end

    local reaction = UnitReaction(unit, "player")

    if reaction and UI:CanAccessValue(reaction) and FACTION_BAR_COLORS then
        local color = FACTION_BAR_COLORS[reaction]

        if color then
            return color.r * multiplier,
                color.g * multiplier,
                color.b * multiplier
        end
    end

    return 0.20, 0.65, 0.20
end

local function HideNativeVisuals(unitFrame)
    -- Do not touch Blizzard's native health/cast StatusBars themselves.
    -- They can contain secret values and become unusable by Blizzard code
    -- once addon code taints their state. Only fade their surrounding
    -- containers/regions; our bars are completely separate objects.
    if unitFrame.HealthBarsContainer then
        unitFrame.HealthBarsContainer:SetAlpha(0)
    end

    if unitFrame.CastBarsContainer then
        unitFrame.CastBarsContainer:SetAlpha(0)
    end

    for _, key in ipairs({
        "name",
        "Name",
        "nameText",
        "AurasFrame",
        "ClassificationFrame",
        "classificationIndicator",
        "LevelFrame",
        "PlayerLevelDiffFrame",
        "RaidTargetFrame",
        "selectionHighlight",
        "SelectionHighlight",
        "aggroHighlight",
    }) do
        local object = unitFrame[key]

        if object and object.SetAlpha then
            object:SetAlpha(0)
        end
    end
end

local function InitializeAuraButton(button)
    button:SetSize(Layout.AURA_SIZE, Layout.AURA_SIZE)
    button:EnableMouse(false)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 1)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(button:GetFrameLevel() + 2)
    overlay:EnableMouse(false)

    local duration = overlay:CreateFontString(nil, "OVERLAY")
    duration:SetPoint("BOTTOM", 0, 1)
    duration:SetFont(fontPath, Styles.FontSize.Nameplates.duration, "OUTLINE")
    duration:SetTextColor(1, 1, 1)

    local count = overlay:CreateFontString(nil, "OVERLAY")
    count:SetPoint("TOPRIGHT", -1, -1)
    count:SetFont(fontPath, Styles.FontSize.Nameplates.count, "OUTLINE")
    count:SetTextColor(1, 1, 1)

    Styles:CreateBorder(button, Palette.black)

    button:SetIcon(icon)
    button:SetDurationText(duration)
    button:SetApplicationCount(count)
    button:SetMouseMotionEnabled(false)
end

local function CreateAuraContainer(data)
    local width = Layout.MAX_AURAS * Layout.AURA_SIZE
        + (Layout.MAX_AURAS - 1) * Layout.AURA_SPACING

    local container = CreateFrame(
        "AuraContainer",
        nil,
        data.root,
        "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate"
    )

    container:SetSize(width, Layout.AURA_SIZE)
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutAnchorPoint("LEFT")
    container:SetFlowLayoutGrowthDirection(
        AnchorUtil.FlowDirection.Right,
        AnchorUtil.FlowDirection.Down
    )
    container:SetFlowLayoutMaximumLineSize(width)

    local function AddGroup(key, filter, layoutIndex)
        container:AddAuraGroup(key, filter, {
            maxFrameCount = Layout.MAX_AURAS,
            sortMethod = AuraContainerSortMethod.Expiration,
            sortDirection = AuraContainerSortDirection.Reverse,
            initializeFrame = InitializeAuraButton,
            layout = {
                elementWidth = Layout.AURA_SIZE,
                elementHeight = Layout.AURA_SIZE,
                elementSpacing = Layout.AURA_SPACING,
                lineSpacing = Layout.AURA_SPACING,
                groupSpacing = Layout.AURA_SPACING,
                groupLineSpacing = Layout.AURA_SPACING,
                forceNewLine = false,
                layoutIndex = layoutIndex,
            },
        })
    end

    AddGroup("helpful", "HELPFUL|PLAYER", 1)
    AddGroup("harmful", "HARMFUL|PLAYER", 2)

    container:SetEnabled(true)
    -- Align the aura strip with the level label's 3px left inset.
    -- Applies to both friendly and hostile nameplates.
    container:SetPoint(
        "BOTTOMLEFT",
        data.textRow,
        "TOPLEFT",
        3,
        Layout.AURA_GAP
    )

    data.auras = container
end

local function UpdateAuras(data)
    if not data.auras or not data.unit then
        return
    end

    if data.auraUnit ~= data.unit then
        data.auras:SetUnit(data.unit)
        data.auraUnit = data.unit
    else
        data.auras:UpdateAllAuras()
    end
end

local function CreateCustomPlate(namePlate)
    local unitFrame = namePlate.UnitFrame

    if not unitFrame then
        return
    end

    local root = CreateFrame("Frame", nil, namePlate)
    root:SetSize(
        Layout.PLATE_WIDTH,
        Layout.HEALTH_HEIGHT + Layout.CAST_HEIGHT
            + Layout.TEXT_ROW_HEIGHT + Layout.TEXT_GAP
            + Layout.AURA_GAP + Layout.AURA_SIZE
    )
    root:SetPoint("CENTER", namePlate, "CENTER", 0, 0)
    root:SetFrameLevel((unitFrame:GetFrameLevel() or 0) + 50)
    root:EnableMouse(false)

    local health = CreateFrame("StatusBar", nil, root)
    health:SetSize(Layout.PLATE_WIDTH, Layout.HEALTH_HEIGHT)
    health:SetPoint("CENTER", root, "CENTER", 0, 0)
    health:SetStatusBarTexture(healthFadeTexture)

    local healthBackground = health:CreateTexture(nil, "BACKGROUND")
    healthBackground:SetAllPoints()
    -- Use exactly the same alpha silhouette for missing health, so the
    -- healthbar remains softly tapered even when partially depleted.
    healthBackground:SetTexture(healthFadeTexture)
    healthBackground:SetVertexColor(
        Styles:GetColorChannels(Palette.nameplates.missingHealth)
    )

    -- The thin health bar is intentionally borderless. Text is positioned
    -- on its own row above it, for all unit reactions.
    local textRow = CreateFrame("Frame", nil, root)
    textRow:SetSize(Layout.PLATE_WIDTH, Layout.TEXT_ROW_HEIGHT)
    textRow:SetPoint(
        "BOTTOMLEFT",
        health,
        "TOPLEFT",
        0,
        Layout.TEXT_GAP
    )

    local raidMarker = root:CreateTexture(nil, "OVERLAY")
    raidMarker:SetSize(14, 14)
    raidMarker:SetPoint("RIGHT", health, "LEFT", -3, 0)
    raidMarker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    raidMarker:Hide()

    local level = textRow:CreateFontString(nil, "OVERLAY")
    level:SetPoint("LEFT", textRow, "LEFT", 3, 0)
    level:SetJustifyH("LEFT")
    level:SetFont(fontPath, Styles.FontSize.Nameplates.level, "OUTLINE")
    level:SetShadowColor(0, 0, 0, 1)
    level:SetShadowOffset(1, -1)
    ConfigureSingleLine(level)

    local name = textRow:CreateFontString(nil, "OVERLAY")
    name:SetPoint("LEFT", level, "RIGHT", 3, 0)
    name:SetPoint("RIGHT", textRow, "RIGHT", -36, 0)
    name:SetJustifyH("LEFT")

    if GameTooltipText and name.SetFontObject then
        name:SetFontObject(GameTooltipText)
        name:SetTextHeight(9)
    else
        name:SetFont(fontPath, Styles.FontSize.Nameplates.name, fontFlags)
    end

    name:SetTextColor(1, 1, 1)
    name:SetShadowColor(0, 0, 0, 1)
    name:SetShadowOffset(1, -1)
    ConfigureSingleLine(name)

    local percent = textRow:CreateFontString(nil, "OVERLAY")
    percent:SetPoint("RIGHT", textRow, "RIGHT", -3, 0)
    percent:SetJustifyH("RIGHT")
    percent:SetFont(fontPath, Styles.FontSize.Nameplates.percent, fontFlags)
    percent:SetTextColor(1, 1, 1)
    percent:SetShadowColor(0, 0, 0, 1)
    percent:SetShadowOffset(1, -1)

    local cast = CreateFrame("StatusBar", nil, root)
    cast:SetSize(Layout.PLATE_WIDTH, Layout.CAST_HEIGHT)
    cast:SetPoint("TOP", health, "BOTTOM", 0, -1)
    cast:SetStatusBarTexture(flatTexture)
    cast:SetStatusBarColor(0.55, 0.35, 0.08)
    cast:Hide()

    local castBackground = cast:CreateTexture(nil, "BACKGROUND")
    castBackground:SetAllPoints()
    castBackground:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    Styles:CreateBorder(cast, Palette.black)

    local castName = cast:CreateFontString(nil, "OVERLAY")
    castName:SetPoint("LEFT", cast, "LEFT", 2, 0)
    castName:SetPoint("RIGHT", cast, "RIGHT", -42, 0)
    castName:SetJustifyH("LEFT")
    castName:SetFont(fontPath, Styles.FontSize.Nameplates.castName, fontFlags)
    castName:SetTextColor(1, 1, 1)
    castName:SetShadowColor(0, 0, 0, 1)
    castName:SetShadowOffset(1, -1)
    ConfigureSingleLine(castName)

    local castTime = cast:CreateFontString(nil, "OVERLAY")
    castTime:SetPoint("RIGHT", cast, "RIGHT", -2, 0)
    castTime:SetJustifyH("RIGHT")
    castTime:SetFont(fontPath, Styles.FontSize.Nameplates.castTime, fontFlags)
    castTime:SetTextColor(1, 1, 1)
    castTime:SetShadowColor(0, 0, 0, 1)
    castTime:SetShadowOffset(1, -1)

    local data = {
        plate = namePlate,
        unitFrame = unitFrame,
        root = root,
        health = health,
        textRow = textRow,
        raidMarker = raidMarker,
        level = level,
        name = name,
        percent = percent,
        cast = cast,
        castName = castName,
        castTime = castTime,
    }

    styled[namePlate] = data
    CreateAuraContainer(data)

    cast:SetScript("OnUpdate", function()
        if not data.castDuration then
            return
        end

        local remaining = data.castDuration:GetRemainingDuration()
        data.castTime:SetFormattedText("%.1f", remaining)
    end)

    return data
end

local function UpdateHealth(data)
    local unit = data.unit

    if not unit then
        return
    end

    -- StatusBar sinks explicitly accept secret values while tainted. Pass the
    -- health values straight through without comparing or doing arithmetic.
    local current = UnitHealth(unit)
    local maximum = UnitHealthMax(unit)

    data.health:SetMinMaxValues(0, maximum)
    data.health:SetValue(current)

    local percent = UnitHealthPercent
        and UnitHealthPercent(unit, true, healthPercentCurve)

    if percent then
        data.percent:SetFormattedText("%.0f%%", percent)
    else
        data.percent:SetText("")
    end

    local r, g, b = GetUnitColor(unit)
    data.health:SetStatusBarColor(r, g, b)
end

local function UpdateIdentity(data)
    if not data.unit then
        return
    end

    local nameText, level, levelText, suffix, levelIsSecret,
        levelR, levelG, levelB = GetDisplayIdentity(data.unit)

    -- Only the widget gets to handle secret level/name values. Never
    -- branch on a secret or run tostring/string operations on it.
    if levelIsSecret then
        data.level:SetFormattedText("%s%s", level, suffix)
    else
        data.level:SetText(levelText .. suffix)
    end

    data.level:SetTextColor(levelR, levelG, levelB)
    local hasLevel = levelIsSecret or levelText ~= "" or suffix ~= ""
    data.level:SetShown(hasLevel)

    data.name:ClearAllPoints()

    if hasLevel then
        data.name:SetPoint("LEFT", data.level, "RIGHT", 3, 0)
    else
        data.name:SetPoint("LEFT", data.textRow, "LEFT", 3, 0)
    end

    data.name:SetPoint("RIGHT", data.textRow, "RIGHT", -36, 0)
    if UI:CanAccessValue(nameText) then
        data.name:SetText(nameText or "")
    else
        data.name:SetText(nameText)
    end

    local isTarget = UnitIsUnit and UnitIsUnit(data.unit, "target")

    -- Highlight target identity instead of putting a large border around
    -- the 5px bar; applies equally to friendly and hostile targets.
    if UI:CanAccessValue(isTarget) and isTarget then
        Styles:SetTextColor(data.name, Palette.highlight)
    else
        Styles:SetTextColor(data.name, Palette.white)
    end

    local index = GetRaidTargetIndex and GetRaidTargetIndex(data.unit)
    local valid = false

    if SetRaidTargetIconTexture then
        valid = pcall(SetRaidTargetIconTexture, data.raidMarker, index)
    end

    data.raidMarker:SetShown(valid)
end

local function UpdateCast(data)
    local unit = data.unit

    if not unit then
        return
    end

    local duration = UnitCastingDuration and UnitCastingDuration(unit)
    local name

    if duration then
        name = UnitCastingInfo(unit)
    else
        duration = UnitChannelDuration and UnitChannelDuration(unit)

        if duration then
            name = UnitChannelInfo(unit)
        end
    end

    if not duration then
        data.castDuration = nil
        data.cast:Hide()
        data.castName:SetText("")
        data.castTime:SetText("")
        return
    end

    data.castDuration = duration
    data.cast:SetTimerDuration(duration)
    data.castName:SetText(name or "")
    data.cast:Show()
end

local function UpdatePlate(data)
    if not data.unit or not UI:CanAccessValue(data.unit) then
        return
    end

    local exists = UnitExists(data.unit)
    if UI:CanAccessValue(exists) and not exists then
        return
    end

    HideNativeVisuals(data.unitFrame)
    UpdateIdentity(data)
    UpdateHealth(data)
    UpdateAuras(data)
    UpdateCast(data)
end

local function IsNamePlateUnitToken(unit)
    return type(unit) == "string"
        and string.match(unit, "^nameplate%d+$") ~= nil
end

local function RefreshUnit(unit)
    if not IsNamePlateUnitToken(unit)
        or not C_NamePlate
        or not C_NamePlate.GetNamePlateForUnit
    then
        return
    end

    local plate = C_NamePlate.GetNamePlateForUnit(unit)

    if not plate then
        return
    end

    local data = styled[plate] or CreateCustomPlate(plate)

    if not data then
        return
    end

    data.unit = unit
    data.root:Show()
    data.auras:Show()

    UpdatePlate(data)
end

-- Reuse the same nameplate enumeration for event refreshes and startup.
local function RefreshExistingNameplates(refreshPlate)
    if not C_NamePlate or not C_NamePlate.GetNamePlates then
        return
    end

    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        refreshPlate(plate)
    end
end

local function RefreshExistingIdentity(plate)
    local data = styled[plate]

    if data and data.unit then
        UpdateIdentity(data)
    end

    return data
end

local function RefreshExistingTarget(plate)
    local data = RefreshExistingIdentity(plate)

    if data and data.unit then
        UpdateHealth(data)
    end
end

local function InitializeExistingPlate(plate)
    local unit = plate.namePlateUnitToken

    if unit then
        RefreshUnit(unit)
    end
end

function Module:Initialize()
    if SetCVar then
        SetCVar("nameplateShowEnemies", 1)
        -- Include friendly players and NPCs instead of styling enemies only.
        -- A nameplate must exist before the shared custom layout can apply.
        SetCVar("nameplateShowFriends", 1)
        SetCVar("nameplateShowOnlyNameForFriendlyPlayerUnits", 0)
    end

    UI:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit)
        RefreshUnit(unit)
    end)

    UI:RegisterEvent("NAME_PLATE_UNIT_REMOVED", function(_, unit)
        if not IsNamePlateUnitToken(unit) then
            return
        end

        local plate = C_NamePlate
            and C_NamePlate.GetNamePlateForUnit
            and C_NamePlate.GetNamePlateForUnit(unit)

        local data = plate and styled[plate]

        if data then
            data.unit = nil
            data.auraUnit = nil
            data.castDuration = nil
            data.root:Hide()
            data.auras:Hide()
            data.cast:Hide()
        end
    end)

    UI:RegisterEvent("UNIT_HEALTH", function(_, unit)
        if IsNamePlateUnitToken(unit) then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            local data = plate and styled[plate]

            if data then
                UpdateHealth(data)
            end
        end
    end)

    UI:RegisterEvent("UNIT_MAXHEALTH", function(_, unit)
        if IsNamePlateUnitToken(unit) then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            local data = plate and styled[plate]

            if data then
                UpdateHealth(data)
            end
        end
    end)

    UI:RegisterEvent("UNIT_NAME_UPDATE", function(_, unit)
        if IsNamePlateUnitToken(unit) then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            local data = plate and styled[plate]

            if data then
                UpdateIdentity(data)
            end
        end
    end)

    UI:RegisterEvent("UNIT_AURA", function(_, unit)
        if IsNamePlateUnitToken(unit) then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            local data = plate and styled[plate]

            if data then
                UpdateAuras(data)
            end
        end
    end)

    for _, event in ipairs({
        "UNIT_SPELLCAST_START",
        "UNIT_SPELLCAST_STOP",
        "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED",
        "UNIT_SPELLCAST_DELAYED",
        "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_UPDATE",
        "UNIT_SPELLCAST_CHANNEL_STOP",
    }) do
        UI:RegisterEvent(event, function(_, unit)
            if IsNamePlateUnitToken(unit) then
                local plate = C_NamePlate.GetNamePlateForUnit(unit)
                local data = plate and styled[plate]

                if data then
                    UpdateCast(data)
                end
            end
        end)
    end

    for _, event in ipairs({
        "UNIT_THREAT_SITUATION_UPDATE",
        "UNIT_THREAT_LIST_UPDATE",
    }) do
        UI:RegisterEvent(event, function(_, unit)
            if IsNamePlateUnitToken(unit) then
                local plate = C_NamePlate.GetNamePlateForUnit(unit)
                local data = plate and styled[plate]

                if data then
                    UpdateHealth(data)
                end
            end
        end)
    end

    UI:RegisterEvent("RAID_TARGET_UPDATE", function()
        RefreshExistingNameplates(RefreshExistingIdentity)
    end)

    UI:RegisterEvent("PLAYER_TARGET_CHANGED", function()
        RefreshExistingNameplates(RefreshExistingTarget)
    end)

    -- Keep the next-tick scan in case Blizzard populates nameplates late.
    C_Timer.After(0, function()
        RefreshExistingNameplates(InitializeExistingPlate)
    end)
end

Module:Initialize()
