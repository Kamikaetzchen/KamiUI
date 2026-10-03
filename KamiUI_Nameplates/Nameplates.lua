local UI = KamiUI

local Module = UI:NewModule("Nameplates")

Module.name = "KamiUI_Nameplates"
Module.version = "0.2.0"

local PLATE_WIDTH = 200
local HEALTH_HEIGHT = 10
local CAST_HEIGHT = 10
local BORDER_SIZE = 1

local AURA_SIZE = 20
local AURA_SPACING = 2
local MAX_AURAS = 5

local flatTexture = "Interface\\Buttons\\WHITE8X8"
local fontPath, _, fontFlags = GameFontNormalSmall:GetFont()

local styled = {}

local hiddenNativeParent = CreateFrame("Frame")
hiddenNativeParent:Hide()

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

local function CreateBorder(parent)
    local edges = {}

    local top = parent:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(BORDER_SIZE)
    edges[#edges + 1] = top

    local bottom = parent:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(BORDER_SIZE)
    edges[#edges + 1] = bottom

    local left = parent:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(BORDER_SIZE)
    edges[#edges + 1] = left

    local right = parent:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(BORDER_SIZE)
    edges[#edges + 1] = right

    for _, edge in ipairs(edges) do
        edge:SetColorTexture(0, 0, 0, 1)
    end

    return edges
end

local function SetSingleLine(fontString, text)
    if not fontString then
        return
    end

    if fontString.SetWordWrap then
        fontString:SetWordWrap(false)
    end

    if fontString.SetMaxLines then
        fontString:SetMaxLines(1)
    end

    fontString:SetText(text or "")
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

    return 0.20 * multiplier / 0.60,
        0.65 * multiplier / 0.60,
        0.20 * multiplier / 0.60
end

local function GetDisplayName(unit)
    local name = GetUnitName and GetUnitName(unit) or UnitName(unit)

    if not name or not CanAccessValue(name) then
        return ""
    end

    local level = UnitLevel(unit)
    local classification = UnitClassification(unit)

    local levelText = ""
    local suffix = ""

    if level and CanAccessValue(level) then
        levelText = level > 0 and tostring(level) or "??"
    end

    if classification and CanAccessValue(classification) then
        suffix = CLASSIFICATION_SUFFIX[classification] or ""
    end

    if levelText ~= "" then
        return levelText .. suffix .. " " .. name
    end

    return name
end

local function GetNativeHealthBar(unitFrame)
    return unitFrame.healthBar
        or unitFrame.HealthBar
        or unitFrame.healthbar
end

local function GetNativeCastBar(unitFrame)
    return unitFrame.SpellCastBar
        or unitFrame.castBar
        or unitFrame.CastBar
        or (
            unitFrame.CastBarsContainer
            and unitFrame.CastBarsContainer.castBar
        )
end

local function HideNativeVisuals(unitFrame)
    for _, key in ipairs({
        "name",
        "Name",
        "nameText",
        "AurasFrame",
        "ClassificationFrame",
        "classificationIndicator",
        "Border",
        "border",
        "Highlight",
        "highlight",
        "SelectionHighlight",
        "selectionHighlight",
        "aggroHighlight",
    }) do
        local object = unitFrame[key]

        if object then
            if object.SetAlpha then
                object:SetAlpha(0)
            end

            if object.Hide then
                object:Hide()
            end
        end
    end

    local levelFrame = unitFrame.LevelFrame

    if levelFrame and levelFrame:GetParent() ~= hiddenNativeParent then
        levelFrame:SetParent(hiddenNativeParent)
        levelFrame:Hide()
    end

    local playerLevelDiffFrame = unitFrame.PlayerLevelDiffFrame

    if playerLevelDiffFrame
        and playerLevelDiffFrame:GetParent() ~= hiddenNativeParent
    then
        playerLevelDiffFrame:SetParent(hiddenNativeParent)
        playerLevelDiffFrame:Hide()
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
    if not data.auras then
        CreateAuraContainer(data)
    end

    if not data.unit then
        return
    end

    if data.auraUnit ~= data.unit then
        data.auras:SetUnit(data.unit)
        data.auraUnit = data.unit
    else
        data.auras:UpdateAllAuras()
    end
end

local function NeutralizeHealthSelection(data)
    local health = data.nativeHealth

    if health.SetShouldUseSelectedBorder then
        health:SetShouldUseSelectedBorder(false)
    end

    if health.selectedBorder then
        health.selectedBorder:SetAlpha(0)
        health.selectedBorder:Hide()
    end

    if health.deselectedOverlay then
        health.deselectedOverlay:SetAlpha(0)
        health.deselectedOverlay:Hide()
    end

    health:SetAlpha(1)

    local texture = health:GetStatusBarTexture()

    if texture then
        texture:SetAlpha(1)
    end
end

local function StyleNativeHealthBar(data)
    local health = data.nativeHealth

    health:ClearAllPoints()
    health:SetSize(PLATE_WIDTH, HEALTH_HEIGHT)
    health:SetPoint("CENTER", data.plate, "CENTER", 0, 0)
    health:SetStatusBarTexture(flatTexture)

    if not data.healthBackground then
        local background = health:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.05, 0.05, 0.05, 0.90)
        data.healthBackground = background
        data.healthBorder = CreateBorder(health)
    end

    NeutralizeHealthSelection(data)

    if not data.selectionHooked
        and hooksecurefunc
        and health.UpdateSelectionBorder
    then
        data.selectionHooked = true
        hooksecurefunc(health, "UpdateSelectionBorder", function()
            NeutralizeHealthSelection(data)
        end)
    end

    if health.Text then
        health.Text:ClearAllPoints()
        health.Text:SetPoint("RIGHT", health, "RIGHT", -3, 0)
        health.Text:SetJustifyH("RIGHT")
        health.Text:SetFont(fontPath, 8, fontFlags)
        health.Text:SetTextColor(1, 1, 1)
        health.Text:SetShadowColor(0, 0, 0, 1)
        health.Text:SetShadowOffset(1, -1)
        data.healthPercent = health.Text
    end
end

local function StyleNativeCastBar(data)
    local cast = data.nativeCast

    if not cast then
        return
    end

    cast:ClearAllPoints()
    cast:SetSize(PLATE_WIDTH, CAST_HEIGHT)
    cast:SetPoint("TOP", data.nativeHealth, "BOTTOM", 0, -1)
    cast:SetStatusBarTexture(flatTexture)
    cast:SetStatusBarColor(0.55, 0.35, 0.08)

    if not data.castBackground then
        local background = cast:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.05, 0.05, 0.05, 0.90)
        data.castBackground = background
        data.castBorder = CreateBorder(cast)
    end

    if cast.Text then
        cast.Text:SetAlpha(1)
        cast.Text:Show()
        cast.Text:ClearAllPoints()
        cast.Text:SetPoint("LEFT", cast, "LEFT", 2, 0)
        cast.Text:SetFont(fontPath, 8, fontFlags)
        cast.Text:SetTextColor(1, 1, 1)
        cast.Text:SetShadowColor(0, 0, 0, 1)
        cast.Text:SetShadowOffset(1, -1)
        cast.Text:SetJustifyH("LEFT")
        data.castName = cast.Text
    end

    if not cast.CastTimeText then
        cast.CastTimeText = cast:CreateFontString(nil, "OVERLAY")
    end

    cast.CastTimeText:SetAlpha(1)
    cast.CastTimeText:ClearAllPoints()
    cast.CastTimeText:SetPoint("RIGHT", cast, "RIGHT", -2, 0)
    cast.CastTimeText:SetFont(fontPath, 8, fontFlags)
    cast.CastTimeText:SetTextColor(1, 1, 1)
    cast.CastTimeText:SetShadowColor(0, 0, 0, 1)
    cast.CastTimeText:SetShadowOffset(1, -1)
    cast.CastTimeText:SetJustifyH("RIGHT")
    data.castTime = cast.CastTimeText

    if cast.Text then
        cast.Text:SetPoint("RIGHT", cast.CastTimeText, "LEFT", -3, 0)
    end

    if cast.SetNameTextShown then
        cast:SetNameTextShown(true)
    end

    if cast.SetCastTimeTextShown then
        cast:SetCastTimeTextShown(true)
    else
        cast.CastTimeText:Show()
    end

    if cast.CastTargetNameText then
        cast.CastTargetNameText:SetAlpha(0)
        cast.CastTargetNameText:Hide()
    end

    if cast.Icon then
        cast.Icon:SetAlpha(0)
    end

    if cast.Border then
        cast.Border:SetAlpha(0)
    end
end

local function UpdateCastTexts(data)
    local cast = data.nativeCast

    if not cast then
        return
    end

    if cast.Text then
        cast.Text:SetAlpha(1)
    end

    if cast.CastTimeText then
        cast.CastTimeText:SetAlpha(1)

        if cast.SetCastTimeTextShown then
            cast:SetCastTimeTextShown(true)
        else
            cast.CastTimeText:SetShown(cast:IsShown())
        end
    end
end

local function UpdatePlate(data)
    local unit = data.unit

    if not unit or not UnitExists(unit) then
        return
    end

    HideNativeVisuals(data.root)
    StyleNativeHealthBar(data)
    StyleNativeCastBar(data)

    if data.nativeHealth.selectedBorder then
        data.nativeHealth.selectedBorder:SetAlpha(0)
        data.nativeHealth.selectedBorder:Hide()
    end

    if data.nativeHealth.deselectedOverlay then
        data.nativeHealth.deselectedOverlay:SetAlpha(0)
        data.nativeHealth.deselectedOverlay:Hide()
    end

    if data.nativeCast then
        data.nativeCast:SetStatusBarColor(0.55, 0.35, 0.08)
    end

    local r, g, b = GetUnitColor(unit)
    data.nativeHealth:SetStatusBarColor(r, g, b)

    SetSingleLine(data.name, GetDisplayName(unit))
    UpdateAuras(data)
    UpdateCastTexts(data)
end

local function CreatePlate(namePlate, unit)
    local unitFrame = namePlate and namePlate.UnitFrame

    if not unitFrame then
        return
    end

    local nativeHealth = GetNativeHealthBar(unitFrame)

    if not nativeHealth then
        return
    end

    local data = styled[namePlate]

    if not data then
        data = {
            plate = namePlate,
            root = unitFrame,
            nativeHealth = nativeHealth,
            nativeCast = GetNativeCastBar(unitFrame),
        }
        styled[namePlate] = data

        data.health = data.nativeHealth

        HideNativeVisuals(unitFrame)
        StyleNativeHealthBar(data)
        StyleNativeCastBar(data)

        local name = unitFrame:CreateFontString(nil, "OVERLAY")
        name:SetPoint("LEFT", data.nativeHealth, "LEFT", 3, 0)

        if data.healthPercent then
            name:SetPoint("RIGHT", data.healthPercent, "LEFT", -3, 0)
        else
            name:SetPoint("RIGHT", data.nativeHealth, "RIGHT", -3, 0)
        end

        name:SetJustifyH("LEFT")
        name:SetFont(fontPath, 8, fontFlags)
        name:SetTextColor(1, 1, 1)
        name:SetShadowColor(0, 0, 0, 1)
        name:SetShadowOffset(1, -1)
        SetSingleLine(name, "")
        data.name = name

        CreateAuraContainer(data)

    end

    data.unit = unit
    data.nativeCast = GetNativeCastBar(unitFrame) or data.nativeCast

    if data.auras then
        data.auras:Show()
    end

    UpdatePlate(data)
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

    if plate then
        CreatePlate(plate, unit)
    end
end

function Module:Initialize()
    if SetCVar then
        SetCVar("nameplateShowEnemies", 1)
        SetCVar("nameplateShowOnlyNameForFriendlyPlayerUnits", 0)
    end

    if CVarCallbackRegistry
        and CVarCallbackRegistry.SetCVarBitfieldMask
        and Enum
        and Enum.NamePlateInfoDisplay
        and Enum.NamePlateInfoDisplay.CurrentHealthPercent
    then
        local index = Enum.NamePlateInfoDisplay.CurrentHealthPercent
        local mask = bit and bit.lshift and bit.lshift(1, index - 1)

        if mask then
            CVarCallbackRegistry:SetCVarBitfieldMask(
                "nameplateInfoDisplay",
                mask
            )
        end
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

            if data.auras then
                data.auras:Hide()
                data.auraUnit = nil
            end

            if data.castName then
                data.castName:SetText("")
            end

            if data.castTime then
                data.castTime:SetText("")
            end
        end
    end)

    for _, event in ipairs({
        "UNIT_HEALTH",
        "UNIT_MAXHEALTH",
        "UNIT_NAME_UPDATE",
        "UNIT_AURA",
        "UNIT_THREAT_SITUATION_UPDATE",
        "UNIT_THREAT_LIST_UPDATE",
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
            RefreshUnit(unit)
        end)
    end

    UI:RegisterEvent("PLAYER_TARGET_CHANGED", function()
        if not C_NamePlate or not C_NamePlate.GetNamePlates then
            return
        end

        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            local data = styled[plate]

            if data and data.unit then
                UpdatePlate(data)
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
                CreatePlate(plate, unit)
            end
        end
    end)
end

Module:Initialize()
