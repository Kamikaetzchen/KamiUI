local UI = KamiUI

local Module = UI:NewModule("Auras")

Module.name = "KamiUI_Auras"
Module.version = "0.1.0"

local defaults = {
    width = 300,
    height = 25,
    iconSize = 25,
    groupGap = 4,
    x = 0,
    y = 300,
    fontSize = 11,
    barAlpha = 0.40,
    backgroundAlpha = 0.60,
    helpfulColor = { 0.20, 0.55, 0.90 },
    harmfulColor = { 0.80, 0.20, 0.20 },
    backgroundColor = { 0.03, 0.03, 0.03 },
}

local hiddenObjects = setmetatable({}, { __mode = "k" })
local container

local function HideObject(object)
    if not object then
        return
    end

    object:Hide()

    if not hiddenObjects[object] and object.HookScript then
        hiddenObjects[object] = true

        object:HookScript("OnShow", function(self)
            self:Hide()
        end)
    end
end

local function HideBlizzardAuras()
    HideObject(BuffFrame)
    HideObject(DebuffFrame)
end

local function CreateBorder(parent, top, bottom, left, right)
    local function CreateEdge(pointA, pointB, width, height)
        local edge = parent:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(0, 0, 0, 1)
        edge:SetPoint(pointA, parent, pointA)
        edge:SetPoint(pointB, parent, pointB)

        if width then
            edge:SetWidth(width)
        end

        if height then
            edge:SetHeight(height)
        end
    end

    if top then
        CreateEdge("TOPLEFT", "TOPRIGHT", nil, 1)
    end

    if bottom then
        CreateEdge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    end

    if left then
        CreateEdge("TOPLEFT", "BOTTOMLEFT", 1, nil)
    end

    if right then
        CreateEdge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
    end
end

local function InitializeAuraButton(button, color, useDispelColor)
    button:SetSize(defaults.width, defaults.height)
    button:EnableMouse(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(defaults.iconSize, defaults.iconSize)
    icon:SetPoint("LEFT")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local bar = CreateFrame("StatusBar", nil, button)
    bar:SetSize(defaults.width - defaults.iconSize, defaults.height)
    bar:SetPoint("LEFT", icon, "RIGHT", 0, 0)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(color[1], color[2], color[3], 1)

    local statusTexture = bar:GetStatusBarTexture()
    statusTexture:SetAlpha(defaults.barAlpha)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(
        defaults.backgroundColor[1],
        defaults.backgroundColor[2],
        defaults.backgroundColor[3],
        defaults.backgroundAlpha
    )

    -- Keep text regions outside the duration StatusBar. Once a region is
    -- registered with the AuraContainer API it receives secret/forbidden
    -- aspects, so all visual children must exist before those bindings.
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(bar:GetFrameLevel() + 10)
    overlay:EnableMouse(false)

    local nameText = overlay:CreateFontString(nil, "OVERLAY")
    nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
    nameText:SetPoint("RIGHT", bar, "RIGHT", -42, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetTextColor(1, 1, 1)
    nameText:SetShadowColor(0, 0, 0, 1)
    nameText:SetShadowOffset(1, -1)

    local timeText = overlay:CreateFontString(nil, "OVERLAY")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    timeText:SetJustifyH("RIGHT")
    timeText:SetTextColor(1, 1, 1)
    timeText:SetShadowColor(0, 0, 0, 1)
    timeText:SetShadowOffset(1, -1)

    local stackText = overlay:CreateFontString(nil, "OVERLAY")
    stackText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    stackText:SetJustifyH("RIGHT")
    stackText:SetTextColor(1, 1, 1)
    stackText:SetShadowColor(0, 0, 0, 1)
    stackText:SetShadowOffset(1, -1)

    local fontPath, _, fontFlags = GameFontNormalSmall:GetFont()
    nameText:SetFont(fontPath, defaults.fontSize, fontFlags)
    timeText:SetFont(fontPath, defaults.fontSize, fontFlags)
    stackText:SetFont(fontPath, defaults.fontSize, "OUTLINE")

    -- Shared 1 px separator between stacked rows.
    CreateBorder(overlay, false, true, false, false)

    -- Bind only after the complete visual tree exists. Blizzard applies
    -- access restrictions to these objects as part of the binding calls.
    button:SetIcon(icon)
    button:SetDurationBar(bar, {
        direction = Enum.StatusBarTimerDirection.RemainingTime,
        interpolation = Enum.StatusBarInterpolation.Immediate,
    })

    if useDispelColor then
        -- Let Blizzard color the existing duration-bar texture from the aura's
        -- dispel type. This works with secret aura data in combat and gives us
        -- the standard Magic/Curse/Disease/Poison/Bleed/None colors.
        button:AddDispelTypeTexture(statusTexture, {
            showAlways = true,
            style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        })
    end

    button:SetSpellName(nameText)
    button:SetDurationText(timeText)
    button:SetApplicationCount(stackText)
    button:SetCancelAuraButtons("RightButtonUp")
end

local function CreateAuraContainer()
    local auraContainer = CreateFrame(
        "AuraContainer",
        "KamiUIAuraContainer",
        UIParent,
        "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate"
    )

    auraContainer:SetPoint(
        "BOTTOMRIGHT",
        UIParent,
        "BOTTOMRIGHT",
        defaults.x,
        defaults.y + UI:GetBottomInset()
    )

    auraContainer:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Vertical)
    auraContainer:SetFlowLayoutAnchorPoint("BOTTOMRIGHT")
    auraContainer:SetFlowLayoutGrowthDirection(
        AnchorUtil.FlowDirection.Left,
        AnchorUtil.FlowDirection.Up
    )
    auraContainer:SetFlowLayoutMaximumLineSize(math.huge)

    -- Outer border. Child anchors are established before aura groups make the
    -- container layout-restricted in combat.
    CreateBorder(auraContainer, true, true, true, true)

    auraContainer:AddAuraGroup("helpful", "HELPFUL", {
        maxFrameCount = 40,
        sortMethod = AuraContainerSortMethod.ExpirationOnly,
        sortDirection = AuraContainerSortDirection.Reverse,
        initializeFrame = function(button)
            InitializeAuraButton(button, defaults.helpfulColor, false)
        end,
        layout = {
            elementWidth = defaults.width,
            elementHeight = defaults.height,
            layoutIndex = 1,
        },
    })

    auraContainer:AddAuraGroup("harmful", "HARMFUL", {
        maxFrameCount = 40,
        sortMethod = AuraContainerSortMethod.Expiration,
        sortDirection = AuraContainerSortDirection.Reverse,
        initializeFrame = function(button)
            InitializeAuraButton(button, defaults.harmfulColor, true)
        end,
        layout = {
            elementWidth = defaults.width,
            elementHeight = defaults.height,
            groupSpacing = defaults.groupGap,
            layoutIndex = 2,
        },
    })

    -- Match the initialization order used by working 12.1 AuraContainer
    -- implementations: configure groups first, then enable and assign unit.
    auraContainer:SetEnabled(true)
    auraContainer:SetUnit("player")
    auraContainer:UpdateAllAuras()

    return auraContainer
end

local function UpdatePosition()
    if not container then
        return
    end

    container:ClearAllPoints()
    container:SetPoint(
        "BOTTOMRIGHT",
        UIParent,
        "BOTTOMRIGHT",
        defaults.x,
        defaults.y + UI:GetBottomInset()
    )
end

function Module:Initialize()
    HideBlizzardAuras()
    container = CreateAuraContainer()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            HideBlizzardAuras()
            UpdatePosition()
        end)
    end)

    UI:RegisterBottomInsetCallback(UpdatePosition)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_BuffFrame" then
            C_Timer.After(0, HideBlizzardAuras)
        end
    end)
end

Module:Initialize()
