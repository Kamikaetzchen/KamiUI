local UI = KamiUI

local Module = UI:NewModule("Nameplates")

Module.name = "KamiUI_Nameplates"
Module.version = "0.1.0"

local PLATE_WIDTH = 120
local HEALTH_HEIGHT = 14
local CAST_HEIGHT = 8
local BORDER_SIZE = 1

local AURA_SIZE = 20
local AURA_SPACING = 2
local MAX_AURAS = 5

local flatTexture = "Interface\\Buttons\\WHITE8X8"
local fontPath, _, fontFlags = GameFontNormalSmall:GetFont()

local styled = {}

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

local function GetUnitColor(unit)
    local isPlayer = UnitIsPlayer(unit)

    if CanAccessValue(isPlayer) and isPlayer then
        local _, class = UnitClass(unit)

        if class and CanAccessValue(class) and RAID_CLASS_COLORS then
            local color = RAID_CLASS_COLORS[class]

            if color then
                return color.r * 0.60, color.g * 0.60, color.b * 0.60
            end
        end
    end

    local reaction = UnitReaction(unit, "player")

    if reaction and CanAccessValue(reaction) and FACTION_BAR_COLORS then
        local color = FACTION_BAR_COLORS[reaction]

        if color then
            return color.r * 0.60, color.g * 0.60, color.b * 0.60
        end
    end

    return 0.20, 0.65, 0.20
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

local function GetDisplayName(unit)
    local name = GetUnitName and GetUnitName(unit) or UnitName(unit)

    if not name or not CanAccessValue(name) then
        return ""
    end

    local level = UnitLevel(unit)
    local classification = UnitClassification(unit)

    local levelText = ""
    local suffix = ""

    if level and CanAccessValue(level) and level > 0 then
        levelText = tostring(level)
    elseif level and CanAccessValue(level) then
        levelText = "??"
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

local function GetNativeName(unitFrame)
    return unitFrame.name
        or unitFrame.Name
        or unitFrame.nameText
end

local function HideNativePlateArt(unitFrame)
    for _, key in ipairs({
        "Border",
        "border",
        "Highlight",
        "highlight",
        "SelectionHighlight",
        "aggroHighlight",
        "classificationIndicator",
        "ClassificationFrame",
        "AurasFrame",
    }) do
        local object = unitFrame[key]

        if object and object.Hide then
            object:Hide()
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
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(button:GetFrameLevel() + 2)
    overlay:EnableMouse(false)

    local duration = overlay:CreateFontString(nil, "OVERLAY")
    duration:SetPoint("BOTTOM", button, "BOTTOM", 0, 1)
    duration:SetFont(fontPath, 7, "OUTLINE")
    duration:SetTextColor(1, 1, 1)

    local count = overlay:CreateFontString(nil, "OVERLAY")
    count:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    count:SetFont(fontPath, 8, "OUTLINE")
    count:SetTextColor(1, 1, 1)

    CreateBorder(button)

    button:SetIcon(icon)
    button:SetDurationText(duration)
    button:SetApplicationCount(count)
    button:SetMouseMotionEnabled(false)
end

local function EnsureAuras(data)
    if data.auras then
        return
    end

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

    local layout = {
        elementWidth = AURA_SIZE,
        elementHeight = AURA_SIZE,
        elementSpacing = AURA_SPACING,
        lineSpacing = AURA_SPACING,
        groupSpacing = AURA_SPACING,
        groupLineSpacing = AURA_SPACING,
        forceNewLine = false,
        layoutIndex = 1,
    }

    container:AddAuraGroup("helpful", "HELPFUL|PLAYER", {
        maxFrameCount = MAX_AURAS,
        sortMethod = AuraContainerSortMethod.Expiration,
        sortDirection = AuraContainerSortDirection.Reverse,
        initializeFrame = InitializeAuraButton,
        layout = layout,
    })

    container:AddAuraGroup("harmful", "HARMFUL|PLAYER", {
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
            layoutIndex = 2,
        },
    })

    container:SetEnabled(true)
    container:SetPoint("TOP", data.cast, "BOTTOM", 0, -2)

    data.auras = container
end

local function UpdateAuras(data)
    EnsureAuras(data)

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

local function GetCastInfo(unit)
    local name, _, _, fourth, fifth, sixth = UnitCastingInfo(unit)
    local startTime = fourth
    local endTime = fifth

    if name and (type(startTime) ~= "number" or type(endTime) ~= "number") then
        startTime = fifth
        endTime = sixth
    end

    if not name then
        name, _, _, fourth, fifth, sixth = UnitChannelInfo(unit)
        startTime = fourth
        endTime = fifth

        if name
            and (type(startTime) ~= "number" or type(endTime) ~= "number")
        then
            startTime = fifth
            endTime = sixth
        end
    end

    return name, startTime, endTime
end

local function UpdateCast(data)
    local spellName, startTime, endTime = GetCastInfo(data.unit)

    if not spellName or not startTime or not endTime
        or not CanAccessValue(spellName)
        or not CanAccessValue(startTime)
        or not CanAccessValue(endTime)
    then
        data.castStart = nil
        data.castEnd = nil
        data.cast:Hide()
        data.auras:ClearAllPoints()
        data.auras:SetPoint("TOP", data.health, "BOTTOM", 0, -2)
        return
    end

    data.castStart = startTime / 1000
    data.castEnd = endTime / 1000

    local duration = math.max(data.castEnd - data.castStart, 0.001)

    data.cast:SetMinMaxValues(0, duration)
    data.castName:SetText(spellName)
    data.cast:Show()

    data.auras:ClearAllPoints()
    data.auras:SetPoint("TOP", data.cast, "BOTTOM", 0, -2)
end

local function UpdatePlate(data)
    local unit = data.unit

    if not unit or not UnitExists(unit) then
        return
    end

    -- Never feed UnitHealth/UnitHealthMax back into Blizzard's native
    -- TextStatusBar. On Forever those values can be secret, and touching the
    -- native bar from addon code taints Blizzard_TextStatusBar's comparisons.
    -- Blizzard already owns and updates the actual bar value; we only style it.
    local r, g, b = GetUnitColor(unit)
    data.health:SetStatusBarColor(r, g, b)

    SetSingleLine(data.name, GetDisplayName(unit))
    UpdateAuras(data)
    UpdateCast(data)
end

local function StylePlate(namePlate, unit)
    local unitFrame = namePlate and namePlate.UnitFrame

    if not unitFrame then
        return
    end

    local health = GetNativeHealthBar(unitFrame)

    if not health then
        return
    end

    local data = styled[namePlate]

    if not data then
        data = {
            plate = namePlate,
            root = unitFrame,
            health = health,
        }
        styled[namePlate] = data

        HideNativePlateArt(unitFrame)

        health:ClearAllPoints()
        health:SetSize(PLATE_WIDTH, HEALTH_HEIGHT)
        health:SetPoint("CENTER", unitFrame, "CENTER", 0, 0)
        health:SetStatusBarTexture(flatTexture)

        local background = health:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.05, 0.05, 0.05, 0.90)
        data.background = background
        data.border = CreateBorder(health)

        local name = GetNativeName(unitFrame)

        if name then
            name:ClearAllPoints()
            name:SetPoint("BOTTOMLEFT", health, "TOPLEFT", 0, 2)
            name:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", 0, 2)
            name:SetJustifyH("LEFT")
            name:SetFont(fontPath, 10, fontFlags)
            SetSingleLine(name, "")
            data.name = name
        else
            name = unitFrame:CreateFontString(nil, "OVERLAY")
            name:SetPoint("BOTTOMLEFT", health, "TOPLEFT", 0, 2)
            name:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", 0, 2)
            name:SetJustifyH("LEFT")
            name:SetFont(fontPath, 10, fontFlags)
            data.name = name
        end

        local cast = CreateFrame("StatusBar", nil, unitFrame)
        cast:SetSize(PLATE_WIDTH, CAST_HEIGHT)
        cast:SetPoint("TOP", health, "BOTTOM", 0, -1)
        cast:SetStatusBarTexture(flatTexture)
        cast:SetStatusBarColor(0.65, 0.45, 0.10)

        local castBackground = cast:CreateTexture(nil, "BACKGROUND")
        castBackground:SetAllPoints()
        castBackground:SetColorTexture(0.05, 0.05, 0.05, 0.90)

        CreateBorder(cast)

        local castName = cast:CreateFontString(nil, "OVERLAY")
        castName:SetFont(fontPath, 7, "OUTLINE")
        castName:SetPoint("LEFT", 2, 0)
        castName:SetPoint("RIGHT", -2, 0)
        castName:SetJustifyH("LEFT")
        castName:SetTextColor(1, 1, 1)

        data.cast = cast
        data.castName = castName
        cast:Hide()

        EnsureAuras(data)

        cast:SetScript("OnUpdate", function()
            if not data.castStart or not data.castEnd then
                return
            end

            local now = GetTime()
            local elapsed = math.max(now - data.castStart, 0)
            local duration = math.max(data.castEnd - data.castStart, 0.001)

            if elapsed >= duration then
                UpdateCast(data)
                return
            end

            data.cast:SetValue(elapsed)
        end)
    end

    data.unit = unit

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
        StylePlate(plate, unit)
    end
end

function Module:Initialize()
    if SetCVar then
        SetCVar("nameplateShowEnemies", 1)
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
            data.castStart = nil
            data.castEnd = nil
            data.cast:Hide()

            if data.auras then
                data.auras:Hide()
                data.auraUnit = nil
            end
        end
    end)

    for _, event in ipairs({
        "UNIT_HEALTH",
        "UNIT_MAXHEALTH",
        "UNIT_NAME_UPDATE",
        "UNIT_AURA",
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
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
                local data = styled[plate]

                if data and data.unit then
                    UpdatePlate(data)
                end
            end
        end
    end)

    C_Timer.After(0, function()
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
                local unit = plate.namePlateUnitToken

                if unit then
                    StylePlate(plate, unit)
                end
            end
        end
    end)
end

Module:Initialize()
