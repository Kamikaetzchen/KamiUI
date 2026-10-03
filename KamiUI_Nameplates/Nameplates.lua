local UI = KamiUI

local Module = UI:NewModule("Nameplates")

Module.name = "KamiUI_Nameplates"
Module.version = "0.3.0"

local PLATE_WIDTH = 200
local HEALTH_HEIGHT = 12
local CAST_HEIGHT = 10
local BORDER_SIZE = 1

local AURA_SIZE = 20
local AURA_SPACING = 2
local MAX_AURAS = 5

local flatTexture = "Interface\\Buttons\\WHITE8X8"
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

local function CanAccessValue(value)
    if canaccessvalue then
        return canaccessvalue(value)
    end

    if issecretvalue then
        return not issecretvalue(value)
    end

    return true
end

local function SetBorderColor(border, r, g, b, a)
    if not border then
        return
    end

    for _, edge in ipairs(border) do
        edge:SetColorTexture(r, g, b, a or 1)
    end
end

local function CreateBorder(parent)
    local edges = {}

    local top = parent:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(BORDER_SIZE)
    top:SetColorTexture(0, 0, 0, 1)
    edges[#edges + 1] = top

    local bottom = parent:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(BORDER_SIZE)
    bottom:SetColorTexture(0, 0, 0, 1)
    edges[#edges + 1] = bottom

    local left = parent:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(BORDER_SIZE)
    left:SetColorTexture(0, 0, 0, 1)
    edges[#edges + 1] = left

    local right = parent:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(BORDER_SIZE)
    right:SetColorTexture(0, 0, 0, 1)
    edges[#edges + 1] = right

    return edges
end

local function ConfigureSingleLine(fontString)
    if fontString.SetWordWrap then
        fontString:SetWordWrap(false)
    end

    if fontString.SetMaxLines then
        fontString:SetMaxLines(1)
    end
end

local function GetDisplayIdentity(unit)
    local name = GetUnitName and GetUnitName(unit) or UnitName(unit)

    if not name or not CanAccessValue(name) then
        return "", "", 1, 0.10, 0.10
    end

    local level = UnitLevel(unit)
    local classification = UnitClassification(unit)

    local levelText = ""
    local suffix = ""
    local levelR, levelG, levelB = 1, 0.10, 0.10

    if level and CanAccessValue(level) then
        levelText = level > 0 and tostring(level) or "??"

        if level > 0 and GetQuestDifficultyColor then
            local color = GetQuestDifficultyColor(level)

            if color then
                levelR = color.r or levelR
                levelG = color.g or levelG
                levelB = color.b or levelB

                local isGray =
                    math.abs(levelR - levelG) < 0.04
                    and math.abs(levelG - levelB) < 0.04

                if isGray and levelR < 0.72 then
                    levelR, levelG, levelB = 0.72, 0.72, 0.72
                end
            end
        end
    end

    if classification and CanAccessValue(classification) then
        suffix = CLASSIFICATION_SUFFIX[classification] or ""
    end

    return name, levelText .. suffix, levelR, levelG, levelB
end

local function GetUnitColor(unit)
    local tapDenied = UnitIsTapDenied and UnitIsTapDenied(unit)

    if CanAccessValue(tapDenied) and tapDenied then
        return 0.35, 0.35, 0.35
    end

    local multiplier = 0.60
    local threat = UnitThreatSituation and UnitThreatSituation("player", unit)

    if threat and CanAccessValue(threat) and threat >= 2 then
        multiplier = 0.90
    end

    local isPlayer = UnitIsPlayer(unit)

    if CanAccessValue(isPlayer) and isPlayer then
        local _, class = UnitClass(unit)

        if class and CanAccessValue(class) and RAID_CLASS_COLORS then
            local color = RAID_CLASS_COLORS[class]

            if color then
                return color.r * multiplier,
                    color.g * multiplier,
                    color.b * multiplier
            end
        end
    end

    local reaction = UnitReaction(unit, "player")

    if reaction and CanAccessValue(reaction) and FACTION_BAR_COLORS then
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
    button:SetSize(AURA_SIZE, AURA_SIZE)
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
    duration:SetFont(fontPath, 7, "OUTLINE")
    duration:SetTextColor(1, 1, 1)

    local count = overlay:CreateFontString(nil, "OVERLAY")
    count:SetPoint("TOPRIGHT", -1, -1)
    count:SetFont(fontPath, 8, "OUTLINE")
    count:SetTextColor(1, 1, 1)

    CreateBorder(button)

    button:SetIcon(icon)
    button:SetDurationText(duration)
    button:SetApplicationCount(count)
    button:SetMouseMotionEnabled(false)
end

local function CreateAuraContainer(data)
    local width = MAX_AURAS * AURA_SIZE
        + (MAX_AURAS - 1) * AURA_SPACING

    local container = CreateFrame(
        "AuraContainer",
        nil,
        data.root,
        "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate"
    )

    container:SetSize(width, AURA_SIZE)
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutAnchorPoint("LEFT")
    container:SetFlowLayoutGrowthDirection(
        AnchorUtil.FlowDirection.Right,
        AnchorUtil.FlowDirection.Down
    )
    container:SetFlowLayoutMaximumLineSize(width)

    local function AddGroup(key, filter, layoutIndex)
        container:AddAuraGroup(key, filter, {
            maxFrameCount = MAX_AURAS,
            sortMethod = AuraContainerSortMethod.Expiration,
            sortDirection = AuraContainerSortDirection.Reverse,
            initializeFrame = InitializeAuraButton,
            layout = {
                elementWidth = AURA_SIZE,
                elementHeight = AURA_SIZE,
                elementSpacing = AURA_SPACING,
                lineSpacing = AURA_SPACING,
                groupSpacing = AURA_SPACING,
                groupLineSpacing = AURA_SPACING,
                forceNewLine = false,
                layoutIndex = layoutIndex,
            },
        })
    end

    AddGroup("helpful", "HELPFUL|PLAYER", 1)
    AddGroup("harmful", "HARMFUL|PLAYER", 2)

    container:SetEnabled(true)
    container:SetPoint("BOTTOMLEFT", data.health, "TOPLEFT", 0, 2)

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
    root:SetSize(PLATE_WIDTH, HEALTH_HEIGHT + CAST_HEIGHT + 24)
    root:SetPoint("CENTER", namePlate, "CENTER", 0, 0)
    root:SetFrameLevel((unitFrame:GetFrameLevel() or 0) + 50)
    root:EnableMouse(false)

    local health = CreateFrame("StatusBar", nil, root)
    health:SetSize(PLATE_WIDTH, HEALTH_HEIGHT)
    health:SetPoint("CENTER", root, "CENTER", 0, 0)
    health:SetStatusBarTexture(flatTexture)

    local healthBackground = health:CreateTexture(nil, "BACKGROUND")
    healthBackground:SetAllPoints()
    healthBackground:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    local healthBorder = CreateBorder(health)

    local raidMarker = root:CreateTexture(nil, "OVERLAY")
    raidMarker:SetSize(14, 14)
    raidMarker:SetPoint("RIGHT", health, "LEFT", -3, 0)
    raidMarker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    raidMarker:Hide()

    local level = health:CreateFontString(nil, "OVERLAY")
    level:SetPoint("LEFT", health, "LEFT", 3, 0)
    level:SetJustifyH("LEFT")
    level:SetFont(fontPath, 10, "OUTLINE")
    level:SetShadowColor(0, 0, 0, 1)
    level:SetShadowOffset(1, -1)
    ConfigureSingleLine(level)

    local name = health:CreateFontString(nil, "OVERLAY")
    name:SetPoint("LEFT", level, "RIGHT", 3, 0)
    name:SetPoint("RIGHT", health, "RIGHT", -36, 0)
    name:SetJustifyH("LEFT")
    name:SetFont(fontPath, 9, fontFlags)
    name:SetTextColor(1, 1, 1)
    name:SetShadowColor(0, 0, 0, 1)
    name:SetShadowOffset(1, -1)
    ConfigureSingleLine(name)

    local percent = health:CreateFontString(nil, "OVERLAY")
    percent:SetPoint("RIGHT", health, "RIGHT", -3, 0)
    percent:SetJustifyH("RIGHT")
    percent:SetFont(fontPath, 9, fontFlags)
    percent:SetTextColor(1, 1, 1)
    percent:SetShadowColor(0, 0, 0, 1)
    percent:SetShadowOffset(1, -1)

    local cast = CreateFrame("StatusBar", nil, root)
    cast:SetSize(PLATE_WIDTH, CAST_HEIGHT)
    cast:SetPoint("TOP", health, "BOTTOM", 0, -1)
    cast:SetStatusBarTexture(flatTexture)
    cast:SetStatusBarColor(0.55, 0.35, 0.08)
    cast:Hide()

    local castBackground = cast:CreateTexture(nil, "BACKGROUND")
    castBackground:SetAllPoints()
    castBackground:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    CreateBorder(cast)

    local castName = cast:CreateFontString(nil, "OVERLAY")
    castName:SetPoint("LEFT", cast, "LEFT", 2, 0)
    castName:SetPoint("RIGHT", cast, "RIGHT", -42, 0)
    castName:SetJustifyH("LEFT")
    castName:SetFont(fontPath, 8, fontFlags)
    castName:SetTextColor(1, 1, 1)
    castName:SetShadowColor(0, 0, 0, 1)
    castName:SetShadowOffset(1, -1)
    ConfigureSingleLine(castName)

    local castTime = cast:CreateFontString(nil, "OVERLAY")
    castTime:SetPoint("RIGHT", cast, "RIGHT", -2, 0)
    castTime:SetJustifyH("RIGHT")
    castTime:SetFont(fontPath, 8, fontFlags)
    castTime:SetTextColor(1, 1, 1)
    castTime:SetShadowColor(0, 0, 0, 1)
    castTime:SetShadowOffset(1, -1)

    local data = {
        plate = namePlate,
        unitFrame = unitFrame,
        root = root,
        health = health,
        healthBorder = healthBorder,
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

    local nameText, levelText, levelR, levelG, levelB =
        GetDisplayIdentity(data.unit)

    data.level:SetText(levelText)
    data.level:SetTextColor(levelR, levelG, levelB)
    data.level:SetShown(levelText ~= "")

    data.name:ClearAllPoints()

    if levelText ~= "" then
        data.name:SetPoint("LEFT", data.level, "RIGHT", 3, 0)
    else
        data.name:SetPoint("LEFT", data.health, "LEFT", 3, 0)
    end

    data.name:SetPoint("RIGHT", data.health, "RIGHT", -36, 0)
    data.name:SetText(nameText)

    local isTarget = UnitIsUnit and UnitIsUnit(data.unit, "target")

    if CanAccessValue(isTarget) and isTarget then
        SetBorderColor(data.healthBorder, 1.0, 0.82, 0.0, 1)
    else
        SetBorderColor(data.healthBorder, 0, 0, 0, 1)
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
    if not data.unit or not UnitExists(data.unit) then
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

function Module:Initialize()
    if SetCVar then
        SetCVar("nameplateShowEnemies", 1)
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
        if not C_NamePlate or not C_NamePlate.GetNamePlates then
            return
        end

        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            local data = styled[plate]

            if data and data.unit then
                UpdateIdentity(data)
            end
        end
    end)

    UI:RegisterEvent("PLAYER_TARGET_CHANGED", function()
        if not C_NamePlate or not C_NamePlate.GetNamePlates then
            return
        end

        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            local data = styled[plate]

            if data and data.unit then
                UpdateIdentity(data)
                UpdateHealth(data)
            end
        end
    end)

    C_Timer.After(0, function()
        if not C_NamePlate or not C_NamePlate.GetNamePlates then
            return
        end

        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            local unit = plate.namePlateUnitToken

            if unit then
                RefreshUnit(unit)
            end
        end
    end)
end

Module:Initialize()
