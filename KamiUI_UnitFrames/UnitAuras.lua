local UI = KamiUI
local Styles = UI.Styles
local UF = UI:GetModule("UnitFrames")

local DEFAULT_AURAS_PER_ROW = 8
local TARGET_AURAS_PER_ROW = 10
local AURA_SPACING = 1
local containers = {}
local pendingBounce = {}

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

local function CreateDispelBorder(button, colorMap)
    local edges = Styles:CreateBorder(button, {
        color = { 1, 1, 1, 1 },
    })

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
        container:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, 1)
    else
        container:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -1)
    end

    container:SetEnabled(true)
    container:SetUnit(unit)
    container:UpdateAllAuras()

    container.unit = unit
    containers[#containers + 1] = container

    return container
end

local function RebindContainer(container)
    -- SetUnit() is a no-op when the token string is unchanged. Dynamic chains
    -- such as targettargettarget can therefore keep the previous resolved
    -- unit. Clear the cached token first so SetUnit() actually re-registers.
    if container.SetUnit and container.unit then
        -- SetUnit() only refreshes when the token string changes. Bounce
        -- through an inert token so dynamic chains are resolved again.
        container:SetUnit("none")
        container:SetUnit(container.unit)
    end
end

local function BounceContainer(container)
    if InCombatLockdown and InCombatLockdown() then
        pendingBounce[container] = true
        container:UpdateAllAuras()
        return
    end

    pendingBounce[container] = nil
    RebindContainer(container)
    container:Hide()
    container:Show()
    container:UpdateAllAuras()
end

local function RefreshAuras(unit)
    for _, container in ipairs(containers) do
        if not unit or container.unit == unit then
            BounceContainer(container)
        end
    end
end

local function CreatePartyBuffContainer(parent, unit)
    local size = (parent:GetWidth() - 9 * AURA_SPACING) / 10

    local container = CreateFrame(
        "AuraContainer",
        nil,
        parent,
        "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate"
    )

    container:SetSize(parent:GetWidth(), size)
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutAnchorPoint("TOPLEFT")
    container:SetFlowLayoutGrowthDirection(
        AnchorUtil.FlowDirection.Right,
        AnchorUtil.FlowDirection.Down
    )
    container:SetFlowLayoutMaximumLineSize(parent:GetWidth())

    AddAuraGroup(
        container,
        "buffs",
        "HELPFUL",
        10,
        size,
        1,
        false,
        false
    )

    container:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -1)
    container:SetEnabled(true)
    container:SetUnit(unit)
    container:UpdateAllAuras()

    container.unit = unit
    containers[#containers + 1] = container

    return container
end

local function CreatePartyDebuffContainer(parent, unit)
    local size = 25
    local width = size * 5 + AURA_SPACING * 4

    local container = CreateFrame(
        "AuraContainer",
        nil,
        parent,
        "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate"
    )

    container:SetSize(width, size)
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutAnchorPoint("LEFT")
    container:SetFlowLayoutGrowthDirection(
        AnchorUtil.FlowDirection.Right,
        AnchorUtil.FlowDirection.Down
    )
    container:SetFlowLayoutMaximumLineSize(width)

    AddAuraGroup(
        container,
        "debuffs",
        "HARMFUL",
        5,
        size,
        1,
        false,
        true
    )

    container:SetPoint("LEFT", parent, "RIGHT", 2, 0)
    container:SetEnabled(true)
    container:SetUnit(unit)
    container:UpdateAllAuras()

    container.unit = unit
    containers[#containers + 1] = container

    return container
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

    for index, group in ipairs(UF.partyFrames or {}) do
        local unit = "party" .. index

        group.main.buffs = CreatePartyBuffContainer(
            group.main,
            unit
        )
        group.debuffs = CreatePartyDebuffContainer(
            group.pet,
            unit
        )
    end
end

AttachAuras()

UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(0, function()
        RefreshAuras()
    end)
end)

UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    for container in pairs(pendingBounce) do
        pendingBounce[container] = nil
        RebindContainer(container)
        container:Hide()
        container:Show()
        container:UpdateAllAuras()
    end
end)

UI:RegisterEvent("PLAYER_TARGET_CHANGED", function()
    RefreshAuras("target")
    RefreshAuras("targettarget")

    C_Timer.After(0, function()
        RefreshAuras("targettargettarget")
    end)
end)

UI:RegisterEvent("PLAYER_FOCUS_CHANGED", function()
    RefreshAuras("focus")
end)

UI:RegisterEvent("UNIT_TARGET", function(_, unit)
    if unit == "target" then
        RefreshAuras("targettarget")

        C_Timer.After(0, function()
            RefreshAuras("targettargettarget")
        end)
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
    elseif unit and string.match(unit, "^party%d$") then
        C_Timer.After(0, function()
            RefreshAuras(unit)
        end)
    end
end)

UI:RegisterEvent("GROUP_ROSTER_UPDATE", function()
    C_Timer.After(0, function()
        for index = 1, 4 do
            RefreshAuras("party" .. index)
        end
    end)
end)
