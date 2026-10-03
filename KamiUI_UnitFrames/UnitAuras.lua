local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local AURAS_PER_ROW = 8
local containers = {}

local function CreateBorder(parent)
    local top = parent:CreateTexture(nil, "OVERLAY")
    top:SetColorTexture(0, 0, 0, 1)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)

    local bottom = parent:CreateTexture(nil, "OVERLAY")
    bottom:SetColorTexture(0, 0, 0, 1)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)

    local left = parent:CreateTexture(nil, "OVERLAY")
    left:SetColorTexture(0, 0, 0, 1)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)

    local right = parent:CreateTexture(nil, "OVERLAY")
    right:SetColorTexture(0, 0, 0, 1)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)
end

local function InitializeAuraButton(button, size)
    button:SetSize(size, size)
    button:EnableMouse(false)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(button:GetFrameLevel() + 2)

    local duration = overlay:CreateFontString(nil, "OVERLAY")
    duration:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
    duration:SetJustifyH("CENTER")
    duration:SetTextColor(1, 1, 1)
    duration:SetShadowColor(0, 0, 0, 1)
    duration:SetShadowOffset(1, -1)

    local stacks = overlay:CreateFontString(nil, "OVERLAY")
    stacks:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
    stacks:SetJustifyH("RIGHT")
    stacks:SetTextColor(1, 1, 1)
    stacks:SetShadowColor(0, 0, 0, 1)
    stacks:SetShadowOffset(1, -1)

    local fontPath = GameFontNormalSmall:GetFont()
    local fontSize = math.max(7, math.min(10, math.floor(size * 0.42)))

    duration:SetFont(fontPath, fontSize, "OUTLINE")
    stacks:SetFont(fontPath, fontSize, "OUTLINE")

    CreateBorder(button)

    button:SetIcon(icon)
    button:SetDurationText(duration)
    button:SetApplicationCount(stacks)
end

local function AddAuraGroup(container, key, filter, maxCount, size, index, forceNewLine)
    container:AddAuraGroup(key, filter, {
        maxFrameCount = maxCount,
        sortMethod = AuraContainerSortMethod.Expiration,
        sortDirection = AuraContainerSortDirection.Reverse,
        initializeFrame = function(button)
            InitializeAuraButton(button, size)
        end,
        layout = {
            elementWidth = size,
            elementHeight = size,
            elementSpacing = 0,
            lineSpacing = 0,
            groupSpacing = 0,
            groupLineSpacing = 0,
            forceNewLine = forceNewLine,
            layoutIndex = index,
        },
    })
end

local function CreateAuraContainer(parent, unit, buffCount, debuffCount, rows, growUp)
    local size = parent:GetWidth() / AURAS_PER_ROW
    local container = CreateFrame(
        "AuraContainer",
        nil,
        parent,
        "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate"
    )

    container:SetSize(parent:GetWidth(), size * rows)
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutAnchorPoint(growUp and "BOTTOMLEFT" or "TOPLEFT")
    container:SetFlowLayoutGrowthDirection(
        AnchorUtil.FlowDirection.Right,
        growUp and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down
    )
    container:SetFlowLayoutMaximumLineSize(parent:GetWidth())

    AddAuraGroup(container, "buffs", "HELPFUL", buffCount, size, 1, false)
    AddAuraGroup(container, "debuffs", "HARMFUL", debuffCount, size, 2, true)

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
            true
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
            frame.auras = CreateAuraContainer(frame, unit, 8, 8, 2, false)
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
