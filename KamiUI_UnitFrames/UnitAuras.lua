local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local DEFAULT_AURAS_PER_ROW = 8
local TARGET_AURAS_PER_ROW = 10
local AURA_SPACING = 1
local containers = {}

local DISPEL_TYPES = {
    "Curse",
    "Disease",
    "Magic",
    "Poison",
}

local function BuildDispelColorMap(defaultColor)
    local source = DebuffTypeColor or {
        Magic = { r = 0.20, g = 0.60, b = 1.00 },
        Disease = { r = 0.60, g = 0.40, b = 0.00 },
        Poison = { r = 0.00, g = 0.60, b = 0.00 },
        Curse = { r = 0.60, g = 0.00, b = 1.00 },
    }

    local map = {}

    for _, dispelType in ipairs(DISPEL_TYPES) do
        local color = source[dispelType]

        if color then
            map[dispelType] = CreateColor(color.r, color.g, color.b, 1)
        end
    end

    map.Bleed = CreateColor(0.80, 0.20, 0.20, 1)
    map.None = CreateColor(
        defaultColor[1],
        defaultColor[2],
        defaultColor[3],
        1
    )

    return map
end

local BUFF_BORDER_COLORS = BuildDispelColorMap({ 0, 0, 0 })
local DEBUFF_BORDER_COLORS = BuildDispelColorMap({ 0.80, 0.20, 0.20 })

local function CreateBorderEdge(parent, pointA, pointB, width, height)
    local edge = parent:CreateTexture(nil, "OVERLAY")
    edge:SetColorTexture(1, 1, 1, 1)
    edge:SetPoint(pointA)
    edge:SetPoint(pointB)

    if width then
        edge:SetWidth(width)
    end

    if height then
        edge:SetHeight(height)
    end

    return edge
end

local function CreateDispelBorder(button, colorMap)
    local edges = {
        CreateBorderEdge(button, "TOPLEFT", "TOPRIGHT", nil, 1),
        CreateBorderEdge(button, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1),
        CreateBorderEdge(button, "TOPLEFT", "BOTTOMLEFT", 1, nil),
        CreateBorderEdge(button, "TOPRIGHT", "BOTTOMRIGHT", 1, nil),
    }

    for _, edge in ipairs(edges) do
        button:AddDispelTypeTexture(edge, {
            style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
            showWhenHelpful = true,
            showWhenHarmful = true,
            showWithoutDispelType = true,
            customDispelColorMap = colorMap,
        })
    end
end

local function InitializeAuraButton(button, size, harmful)
    button:SetSize(size, size)
    button:EnableMouse(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(button:GetFrameLevel() + 2)
    overlay:EnableMouse(false)

    local duration = overlay:CreateFontString(nil, "OVERLAY")
    duration:SetPoint("BOTTOM", button, "BOTTOM", 0, 1)
    duration:SetJustifyH("CENTER")
    duration:SetTextColor(1, 1, 1)
    duration:SetShadowColor(0, 0, 0, 1)
    duration:SetShadowOffset(1, -1)

    local stacks = overlay:CreateFontString(nil, "OVERLAY")
    stacks:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -1)
    stacks:SetJustifyH("RIGHT")
    stacks:SetTextColor(1, 1, 1)
    stacks:SetShadowColor(0, 0, 0, 1)
    stacks:SetShadowOffset(1, -1)

    local fontPath = GameFontNormalSmall:GetFont()
    local fontSize = math.max(5, math.min(8, math.floor(size * 0.32)))

    duration:SetFont(fontPath, fontSize, "OUTLINE")
    stacks:SetFont(fontPath, fontSize, "OUTLINE")

    CreateDispelBorder(
        button,
        harmful and DEBUFF_BORDER_COLORS or BUFF_BORDER_COLORS
    )

    button:SetIcon(icon)
    button:SetDurationText(duration)
    button:SetApplicationCount(stacks)
    button:SetTooltipAnchorPoint("ANCHOR_RIGHT")
    button:SetMouseMotionEnabled(true)
    button:SetHideTooltipInCombat(false)
end

local function AddAuraGroup(
    container,
    key,
    filter,
    maxCount,
    size,
    index,
    forceNewLine,
    harmful
)
    container:AddAuraGroup(key, filter, {
        maxFrameCount = maxCount,
        sortMethod = AuraContainerSortMethod.Expiration,
        sortDirection = AuraContainerSortDirection.Reverse,
        initializeFrame = function(button)
            InitializeAuraButton(button, size, harmful)
        end,
        layout = {
            elementWidth = size,
            elementHeight = size,
            elementSpacing = AURA_SPACING,
            lineSpacing = AURA_SPACING,
            groupSpacing = AURA_SPACING,
            groupLineSpacing = AURA_SPACING,
            forceNewLine = forceNewLine,
            layoutIndex = index,
        },
    })
end

local function CreateAuraContainer(
    parent,
    unit,
    buffCount,
    debuffCount,
    rows,
    growUp,
    aurasPerRow
)
    local width = parent:GetWidth()
    aurasPerRow = aurasPerRow or DEFAULT_AURAS_PER_ROW

    local size = (width - (aurasPerRow - 1) * AURA_SPACING)
        / aurasPerRow
    local height = size * rows + (rows - 1) * AURA_SPACING

    local container = CreateFrame(
        "AuraContainer",
        nil,
        parent,
        "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate"
    )

    container:SetSize(width, height)
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutAnchorPoint(growUp and "BOTTOMLEFT" or "TOPLEFT")
    container:SetFlowLayoutGrowthDirection(
        AnchorUtil.FlowDirection.Right,
        growUp and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down
    )
    container:SetFlowLayoutMaximumLineSize(width)

    AddAuraGroup(
        container,
        "buffs",
        "HELPFUL",
        buffCount,
        size,
        1,
        false,
        false
    )
    AddAuraGroup(
        container,
        "debuffs",
        "HARMFUL",
        debuffCount,
        size,
        2,
        true,
        true
    )

    if growUp then
        container:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, 0)
    else
        container:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, 0)
    end

    container:SetEnabled(true)
    container:SetUnit(unit)
    container:UpdateAllAuras()

    container.unit = unit
    containers[#containers + 1] = container

    return container
end

local function RefreshAuras(unit)
    for _, container in ipairs(containers) do
        if not unit or container.unit == unit then
            container:SetUnit(container.unit)
            container:UpdateAllAuras()
        end
    end
end

local function AttachAuras()
    if UF.targetFrame then
        UF.targetFrame.auras = CreateAuraContainer(
            UF.targetFrame,
            "target",
            16,
            8,
            3,
            true,
            TARGET_AURAS_PER_ROW
        )
    end

    local secondary = {
        { UF.targetTargetFrame, "targettarget" },
        { UF.targetTargetTargetFrame, "targettargettarget" },
        { UF.focusFrame, "focus" },
        { UF.focusTargetFrame, "focustarget" },
        { UF.petFrame, "pet" },
    }

    for _, entry in ipairs(secondary) do
        local frame, unit = unpack(entry)

        if frame then
            frame.auras = CreateAuraContainer(
                frame,
                unit,
                8,
                8,
                2,
                false,
                DEFAULT_AURAS_PER_ROW
            )
        end
    end
end

AttachAuras()

UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(0, function()
        RefreshAuras()
    end)
end)

UI:RegisterEvent("PLAYER_TARGET_CHANGED", function()
    C_Timer.After(0, function()
        RefreshAuras("target")
        RefreshAuras("targettarget")
        RefreshAuras("targettargettarget")
    end)
end)

UI:RegisterEvent("PLAYER_FOCUS_CHANGED", function()
    C_Timer.After(0, function()
        RefreshAuras("focus")
        RefreshAuras("focustarget")
    end)
end)

UI:RegisterEvent("UNIT_TARGET", function(_, unit)
    if unit == "target" then
        RefreshAuras("targettarget")
        RefreshAuras("targettargettarget")
    elseif unit == "targettarget" then
        RefreshAuras("targettargettarget")
    elseif unit == "focus" then
        RefreshAuras("focustarget")
    end
end)

UI:RegisterEvent("UNIT_PET", function(_, unit)
    if unit == "player" then
        C_Timer.After(0, function()
            RefreshAuras("pet")
        end)
    end
end)
