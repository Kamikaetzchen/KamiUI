local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles

local Module = UI:NewModule("Auras", "KamiUI_Auras")

local Layout = UI.Layout.Auras

local container

local function HideBlizzardAuras()
    UI:KeepFrameHidden(BuffFrame)
    UI:KeepFrameHidden(DebuffFrame)
end

local function InitializeAuraButton(button, color, useDispelColor)
    button:SetSize(Layout.WIDTH, Layout.HEIGHT)
    button:EnableMouse(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(Layout.ICON_SIZE, Layout.ICON_SIZE)
    icon:SetPoint("LEFT")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Put the duration bar in its own alpha container. The AuraContainer's
    -- dispel-type binding recolors the status texture with SetVertexColor(),
    -- including an opaque alpha value, so applying alpha directly to the
    -- texture is not stable. Parent alpha survives those secure color updates.
    local barContainer = CreateFrame("Frame", nil, button)
    barContainer:SetSize(Layout.WIDTH - Layout.ICON_SIZE, Layout.HEIGHT)
    barContainer:SetPoint("LEFT", icon, "RIGHT", 0, 0)
    barContainer:SetAlpha(Styles.State.aurasBarAlpha)

    local bar = CreateFrame("StatusBar", nil, barContainer)
    bar:SetAllPoints()
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(color[1], color[2], color[3], 1)

    local statusTexture = bar:GetStatusBarTexture()

    -- Keep the dark row background outside the alpha container so only the
    -- colored duration fill gets the same transparency as normal buff bars.
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", barContainer, "TOPLEFT")
    background:SetPoint("BOTTOMRIGHT", barContainer, "BOTTOMRIGHT")
    background:SetColorTexture(
        Palette.auras.background[1],
        Palette.auras.background[2],
        Palette.auras.background[3],
        Styles.State.aurasBackgroundAlpha
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
    nameText:SetFont(fontPath, Styles.FontSize.Auras, fontFlags)
    timeText:SetFont(fontPath, Styles.FontSize.Auras, fontFlags)
    stackText:SetFont(fontPath, Styles.FontSize.Auras, "OUTLINE")

    -- Shared 1 px separator between stacked rows.
    Styles:CreateBorder(overlay, {
        color = { 0, 0, 0, 1 },
        top = false,
        left = false,
        right = false,
    })

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
        Layout.X,
        Layout.Y + UI:GetBottomInset()
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
    Styles:CreateBorder(auraContainer, {
        color = { 0, 0, 0, 1 },
    })

    auraContainer:AddAuraGroup("helpful", "HELPFUL", {
        maxFrameCount = 40,
        sortMethod = AuraContainerSortMethod.ExpirationOnly,
        sortDirection = AuraContainerSortDirection.Reverse,
        initializeFrame = function(button)
            InitializeAuraButton(button, Palette.auras.helpful, false)
        end,
        layout = {
            elementWidth = Layout.WIDTH,
            elementHeight = Layout.HEIGHT,
            layoutIndex = 1,
        },
    })

    auraContainer:AddAuraGroup("harmful", "HARMFUL", {
        maxFrameCount = 40,
        sortMethod = AuraContainerSortMethod.Expiration,
        sortDirection = AuraContainerSortDirection.Reverse,
        initializeFrame = function(button)
            InitializeAuraButton(button, Palette.auras.harmful, true)
        end,
        layout = {
            elementWidth = Layout.WIDTH,
            elementHeight = Layout.HEIGHT,
            groupSpacing = Layout.GROUP_GAP,
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
        Layout.X,
        Layout.Y + UI:GetBottomInset()
    )
end

function Module:Initialize()
    HideBlizzardAuras()
    container = CreateAuraContainer()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        HideBlizzardAuras()
        UpdatePosition()
    end)

    UI:RegisterBottomInsetCallback(UpdatePosition)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_BuffFrame" then
            HideBlizzardAuras()
        end
    end)
end

Module:Initialize()
