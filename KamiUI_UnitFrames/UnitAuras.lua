local UI = KamiUI
local UF = UI:GetModule("UnitFrames")

local AURAS_PER_ROW = 8

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

local function CreateAuraContainer(parent, unit, filter, maxCount, rows, size)
    local container = CreateFrame(
        "AuraContainer",
        nil,
        parent,
        "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate"
    )

    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutAnchorPoint("TOPLEFT")
    container:SetFlowLayoutGrowthDirection(
        AnchorUtil.FlowDirection.Right,
        AnchorUtil.FlowDirection.Down
    )
    container:SetFlowLayoutMaximumLineSize(size * AURAS_PER_ROW)

    container:AddAuraGroup("auras", filter, {
        maxFrameCount = maxCount,
        sortMethod = AuraContainerSortMethod.Expiration,
        sortDirection = AuraContainerSortDirection.Reverse,
        initializeFrame = function(button)
            InitializeAuraButton(button, size)
        end,
        layout = {
            elementWidth = size,
            elementHeight = size,
            layoutIndex = 1,
        },
    })

    container:SetSize(size * AURAS_PER_ROW, size * rows)
    container:SetEnabled(true)
    container:SetUnit(unit)
    container:UpdateAllAuras()

    return container
end

local function AttachTargetAuras()
    local frame = UF.targetFrame
    if not frame then
        return
    end

    local size = frame:GetWidth() / AURAS_PER_ROW

    local debuffs = CreateAuraContainer(frame, "target", "HARMFUL", 8, 1, size)
    debuffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)

    local buffs = CreateAuraContainer(frame, "target", "HELPFUL", 16, 2, size)
    buffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, size)

    frame.auraBuffs = buffs
    frame.auraDebuffs = debuffs
end

local function AttachBottomAuras(frame, unit)
    if not frame then
        return
    end

    local size = frame:GetWidth() / AURAS_PER_ROW

    local buffs = CreateAuraContainer(frame, unit, "HELPFUL", 8, 1, size)
    buffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)

    local debuffs = CreateAuraContainer(frame, unit, "HARMFUL", 8, 1, size)
    debuffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -size)

    frame.auraBuffs = buffs
    frame.auraDebuffs = debuffs
end

AttachTargetAuras()
AttachBottomAuras(UF.targetTargetFrame, "targettarget")
AttachBottomAuras(UF.targetTargetTargetFrame, "targettargettarget")
AttachBottomAuras(UF.focusFrame, "focus")
AttachBottomAuras(UF.focusTargetFrame, "focustarget")
AttachBottomAuras(UF.petFrame, "pet")
