local UI = KamiUI

local Module = UI:NewModule("ActionBars")

Module.name = "KamiUI_ActionBars"
Module.version = "0.1.0"

local defaults = {
    buttonSize = 40,
    buttonSpacing = 0,
    iconZoom = 0.08,
    petButtonSize = 30,
    statusBarHeight = 10,
    alpha = 1,
    offsetX = -400,
    offsetY = 10,
}

local barConfigs = {
    {
        frameName = "MainActionBar",
        prefix = "ActionButton",
    },
    {
        frameName = "MultiBarBottomLeft",
        prefix = "MultiBarBottomLeftButton",
    },
    {
        frameName = "MultiBarBottomRight",
        prefix = "MultiBarBottomRightButton",
    },
    {
        frameName = "MultiBarRight",
        prefix = "MultiBarRightButton",
    },
}

local extraButtonPrefixes = {
    "MultiBarLeftButton",
}

local hiddenObjects = setmetatable({}, { __mode = "k" })

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

local function HideBlizzardMenuAndBags()
    HideObject(MicroButtonAndBagsBar)
    HideObject(MicroMenuContainer)
    HideObject(MicroMenu)
    HideObject(BagsBar)
end

local function HideTexture(texture)
    if texture then
        texture:SetAlpha(0)
    end
end

local function GetButtonIcon(button)
    if not button then
        return
    end

    return button.icon
        or button.Icon
        or _G[button:GetName() .. "Icon"]
end

local function MakeIconSquare(button, icon)
    if not icon then
        return
    end

    local mask = button.IconMask

    if mask then
        if icon.RemoveMaskTexture then
            icon:RemoveMaskTexture(mask)
        else
            mask:SetTexture("Interface\\Buttons\\WHITE8X8")
            mask:ClearAllPoints()
            mask:SetAllPoints(button)
        end
    end

    icon:ClearAllPoints()
    icon:SetAllPoints(button)
    icon:SetTexCoord(
        defaults.iconZoom,
        1 - defaults.iconZoom,
        defaults.iconZoom,
        1 - defaults.iconZoom
    )
end

local function StripButtonArt(button)
    if not button then
        return
    end

    HideTexture(button.NormalTexture or button:GetNormalTexture())
    HideTexture(button.SlotBackground)
    HideTexture(button.SlotArt)
    HideTexture(button.Border)
    HideTexture(button.IconBorder)
    HideTexture(button.NewActionTexture)
    HideTexture(button.SpellHighlightTexture)
    HideTexture(button.Flash)

    HideTexture(button.PushedTexture or button:GetPushedTexture())
    HideTexture(button.HighlightTexture or button:GetHighlightTexture())
    HideTexture(button.CheckedTexture or button:GetCheckedTexture())

    MakeIconSquare(button, GetButtonIcon(button))
end

local function StyleCooldown(cooldown, button)
    if not cooldown then
        return
    end

    cooldown:ClearAllPoints()
    cooldown:SetAllPoints(button)
end

local function StyleButton(button, size)
    if not button then
        return
    end

    size = size or defaults.buttonSize

    if button.KamiButtonSize ~= size then
        button:SetSize(size, size)
        button.KamiButtonSize = size
    end

    button:SetAlpha(defaults.alpha)

    StyleCooldown(button.cooldown, button)
    StyleCooldown(button.lossOfControlCooldown, button)
    StyleCooldown(button.chargeCooldown, button)

    StripButtonArt(button)
end

local function GetBarFrame(config)
    return _G[config.frameName]
end

local function LayoutBarButtons(config, rowIndex)
    if not GetBarFrame(config) then
        return
    end

    local nextButton
    local y = defaults.offsetY + ((rowIndex - 1) * defaults.buttonSize)

    for index = 12, 1, -1 do
        local button = _G[config.prefix .. index]

        if button then
            StyleButton(button)
            button:ClearAllPoints()

            if nextButton then
                button:SetPoint(
                    "RIGHT",
                    nextButton,
                    "LEFT",
                    -defaults.buttonSpacing,
                    0
                )
            else
                button:SetPoint(
                    "BOTTOMRIGHT",
                    UIParent,
                    "BOTTOMRIGHT",
                    defaults.offsetX,
                    y
                )
            end

            nextButton = button
        end
    end
end

local function StyleExtraButtons()
    for _, prefix in ipairs(extraButtonPrefixes) do
        for index = 1, 12 do
            StyleButton(_G[prefix .. index])
        end
    end
end

local function StylePetAutoCastOverlay(button)
    local overlay = button.AutoCastOverlay

    if not overlay then
        return
    end

    overlay:ClearAllPoints()
    overlay:SetAllPoints(button)
    overlay:SetSize(defaults.petButtonSize, defaults.petButtonSize)

    if overlay.Shine then
        local overflow = defaults.petButtonSize * 0.175

        overlay.Shine:ClearAllPoints()
        overlay.Shine:SetPoint(
            "TOPLEFT",
            overlay,
            "TOPLEFT",
            -overflow,
            overflow
        )
        overlay.Shine:SetPoint(
            "BOTTOMRIGHT",
            overlay,
            "BOTTOMRIGHT",
            overflow,
            -overflow
        )
    end

    if overlay.Mask then
        overlay.Mask:ClearAllPoints()
        overlay.Mask:SetPoint("TOPLEFT", overlay, "TOPLEFT", 1, -1)
        overlay.Mask:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -1, 1)
    end

    if overlay.Corners then
        overlay.Corners:ClearAllPoints()
        overlay.Corners:SetAllPoints(overlay)
    end
end

local function StylePetCheckedState(button)
    local checked = button.CheckedTexture or button:GetCheckedTexture()

    if not checked then
        return
    end

    checked:ClearAllPoints()
    checked:SetAllPoints(button)
    checked:SetAlpha(button:GetChecked() and 1 or 0)
end

local function RestylePetButtons()
    for index = 1, 10 do
        local button = _G["PetActionButton" .. index]

        if button then
            StripButtonArt(button)
            StylePetAutoCastOverlay(button)
            StylePetCheckedState(button)
        end
    end
end

local function LayoutPetButtons()
    if InCombatLockdown and InCombatLockdown() then
        Module.layoutPending = true
        return
    end

    local previousContainer

    for index = 1, 10 do
        local button = _G["PetActionButton" .. index]
        local container = button and button.container

        if container then
            container:ClearAllPoints()
            container:SetSize(
                defaults.petButtonSize,
                defaults.petButtonSize
            )

            if previousContainer then
                container:SetPoint(
                    "LEFT",
                    previousContainer,
                    "RIGHT",
                    0,
                    0
                )
            elseif KamiUIPlayerFrame then
                -- 10 * 30 = 300px. Player + target span 402px with
                -- the 2px center gap, so 51px inset centers the pet bar.
                container:SetPoint(
                    "TOPLEFT",
                    KamiUIPlayerFrame,
                    "BOTTOMLEFT",
                    51,
                    -2
                )
            else
                container:SetPoint(
                    "TOP",
                    UIParent,
                    "CENTER",
                    -(defaults.petButtonSize * 4.5),
                    -260
                )
            end

            previousContainer = container
        end
    end
end

local function StylePetBar()
    if not PetActionBar then
        return
    end

    PetActionBar:SetScale(1)
    PetActionBar.minButtonPadding = 0
    PetActionBar.buttonPadding = 0
    PetActionBar.numRows = 1
    PetActionBar.isHorizontal = true
    PetActionBar.addButtonsToRight = true
    PetActionBar.addButtonsToTop = true

    for index = 1, 10 do
        local button = _G["PetActionButton" .. index]

        if button then
            StyleButton(button, defaults.petButtonSize)

            if button.container then
                button.container:SetSize(
                    defaults.petButtonSize,
                    defaults.petButtonSize
                )
            end

            StylePetAutoCastOverlay(button)
            StylePetCheckedState(button)
        end
    end

    PetActionBar.oldGridSettings = nil

    if PetActionBar.UpdateShownButtons then
        PetActionBar:UpdateShownButtons()
    end

    if PetActionBar.UpdateGridLayout then
        PetActionBar:UpdateGridLayout()
    end

    LayoutPetButtons()
    RestylePetButtons()

    if not PetActionBar.KamiGridHooked and PetActionBar.UpdateGridLayout then
        PetActionBar.KamiGridHooked = true

        hooksecurefunc(PetActionBar, "UpdateGridLayout", function()
            C_Timer.After(0, LayoutPetButtons)
        end)
    end

    if not PetActionBar.KamiUpdateHooked and PetActionBar.Update then
        PetActionBar.KamiUpdateHooked = true

        hooksecurefunc(PetActionBar, "Update", function()
            RestylePetButtons()
        end)
    end
end

local function StyleStatusBar(bar, width)
    if not bar then
        return
    end

    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", bar:GetParent(), "BOTTOMLEFT", 0, 0)
    bar:SetSize(width, defaults.statusBarHeight)

    if bar.StatusBar then
        bar.StatusBar:ClearAllPoints()
        bar.StatusBar:SetAllPoints(bar)

        if bar.StatusBar.Background then
            bar.StatusBar.Background:ClearAllPoints()
            bar.StatusBar.Background:SetAllPoints(bar.StatusBar)
        end
    end

    if bar.OverlayFrame then
        bar.OverlayFrame:ClearAllPoints()
        bar.OverlayFrame:SetAllPoints(bar)
    end

    if bar.ExhaustionLevelFillBar then
        bar.ExhaustionLevelFillBar:SetHeight(defaults.statusBarHeight)
    end
end

local function StyleStatusContainer(container, y)
    if not container then
        return
    end

    local width = UIParent:GetWidth()

    container:ClearAllPoints()
    container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, y)
    container:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, y)
    container:SetHeight(defaults.statusBarHeight)

    HideTexture(container.BarFrameTexture)

    for _, bar in pairs(container.bars or {}) do
        StyleStatusBar(bar, width)
    end
end

local function StyleStatusTrackingBars()
    if not StatusTrackingBarManager then
        return
    end

    StatusTrackingBarManager:ClearAllPoints()
    StatusTrackingBarManager:SetPoint(
        "BOTTOMLEFT",
        UIParent,
        "BOTTOMLEFT",
        0,
        0
    )
    StatusTrackingBarManager:SetPoint(
        "BOTTOMRIGHT",
        UIParent,
        "BOTTOMRIGHT",
        0,
        0
    )
    StatusTrackingBarManager:SetHeight(defaults.statusBarHeight * 2)

    StyleStatusContainer(
        StatusTrackingBarManager.MainStatusTrackingBarContainer,
        0
    )
    StyleStatusContainer(
        StatusTrackingBarManager.SecondaryStatusTrackingBarContainer,
        defaults.statusBarHeight
    )

    if StatusTrackingBarManager.UpdateBarTicks then
        StatusTrackingBarManager:UpdateBarTicks()
    end

    if not StatusTrackingBarManager.KamiVisualHooked
        and StatusTrackingBarManager.UpdateBarVisuals
    then
        StatusTrackingBarManager.KamiVisualHooked = true

        hooksecurefunc(
            StatusTrackingBarManager,
            "UpdateBarVisuals",
            function()
                C_Timer.After(0, StyleStatusTrackingBars)
            end
        )
    end
end

local function LayoutBars()
    for index, config in ipairs(barConfigs) do
        local bar = GetBarFrame(config)

        if bar then
            bar:SetScale(1)
        end

        LayoutBarButtons(config, index)
    end
end

function Module:Apply()
    HideBlizzardMenuAndBags()
    StyleStatusTrackingBars()

    if InCombatLockdown and InCombatLockdown() then
        self.layoutPending = true
        return
    end

    self.layoutPending = false

    LayoutBars()
    StyleExtraButtons()
    StylePetBar()
end

function Module:Initialize()
    self:Apply()

    hooksecurefunc("ActionButton_Update", function(button)
        StyleButton(button)
    end)

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            Module:Apply()
        end)
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_ActionBar" then
            C_Timer.After(0, function()
                Module:Apply()
            end)
        elseif addonName == "Blizzard_MicroMenu"
            or addonName == "Blizzard_MainMenuBarBagButtons"
        then
            C_Timer.After(0, HideBlizzardMenuAndBags)
        end
    end)

    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if Module.layoutPending then
            Module:Apply()
        end
    end)
end

Module:Initialize()
