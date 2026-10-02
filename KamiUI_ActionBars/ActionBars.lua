local UI = KamiUI

local Module = UI:NewModule("ActionBars")

Module.name = "KamiUI_ActionBars"
Module.version = "0.1.0"

local defaults = {
    buttonSize = 40,
    buttonSpacing = 0,
    iconZoom = 0.08,
    petButtonSize = 30,
    secondaryButtonSize = 30,
    alpha = 1,
    offsetX = -400,
    offsetY = 0,
}

Module.bottomInset = UI:GetBottomInset()

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

local function HideObject(object)
    if not object then
        return
    end

    object:SetAlpha(0)

    if object.EnableMouse then
        object:EnableMouse(false)
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

local function HideMainActionBarArt()
    if not MainActionBar then
        return
    end

    HideTexture(MainActionBar.BorderArt)

    -- Do not touch Blizzard's divider pools or action-bar state here.
    -- Mutating those objects taints protected action-bar execution.
    if MainActionBar.EndCaps then
        MainActionBar.EndCaps:SetAlpha(0)
    end

    if MainActionBar.ActionBarPageNumber then
        MainActionBar.ActionBarPageNumber:SetAlpha(0)
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

local function RefreshButtonVisuals(button)
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

    local icon = GetButtonIcon(button)

    if icon then
        icon:SetTexCoord(
            defaults.iconZoom,
            1 - defaults.iconZoom,
            defaults.iconZoom,
            1 - defaults.iconZoom
        )
    end
end

local function StyleCooldown(cooldown, button)
    if not cooldown then
        return
    end

    cooldown:ClearAllPoints()
    cooldown:SetAllPoints(button)
end

local function GetButtonSize(button, size)
    if size then
        return size
    end

    local name = button:GetName() or ""

    if name:match("^PetActionButton")
        or name:match("^StanceButton")
        or name:match("^MultiBarLeftButton")
        or name:match("^MultiBar5Button")
    then
        return defaults.secondaryButtonSize
    end

    return defaults.buttonSize
end

local function StyleButton(button, size)
    if not button then
        return
    end

    size = GetButtonSize(button, size)

    button:SetSize(size, size)
    button:SetAlpha(defaults.alpha)

    if button.container then
        button.container:SetScale(1)
        button.container:SetSize(size, size)
    end

    StyleCooldown(button.cooldown, button)
    StyleCooldown(button.lossOfControlCooldown, button)
    StyleCooldown(button.chargeCooldown, button)

    RefreshButtonVisuals(button)
    MakeIconSquare(button, GetButtonIcon(button))
end

local function LayoutBarButtons(config, rowIndex)
    if not _G[config.frameName] then
        return
    end

    local nextButton
    local y = defaults.offsetY
        + Module.bottomInset
        + ((rowIndex - 1) * defaults.buttonSize)

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

local StyleCheckedState

local function GetBar4Edges()
    return _G["MultiBarRightButton1"], _G["MultiBarRightButton12"]
end

local function SetButtonVisible(button, visible)
    if not button then
        return
    end

    button:SetAlpha(visible and defaults.alpha or 0)

    if button.EnableMouse then
        button:EnableMouse(visible)
    end

    if button.container then
        button.container:SetAlpha(visible and 1 or 0)

        if button.container.EnableMouse then
            button.container:EnableMouse(visible)
        end
    end
end

local function LayoutActionBar5()
    local bar4Left, bar4Right = GetBar4Edges()

    if not MultiBarLeft or not bar4Left or not bar4Right then
        return
    end

    for row = 1, 2 do
        local rightIndex = row * 6
        local nextButton

        for index = rightIndex, rightIndex - 5, -1 do
            local button = _G["MultiBarLeftButton" .. index]

            if button then
                SetButtonVisible(button, true)
                StyleButton(button, defaults.secondaryButtonSize)
                button:ClearAllPoints()

                if nextButton then
                    button:SetPoint(
                        "RIGHT",
                        nextButton,
                        "LEFT",
                        0,
                        0
                    )
                elseif row == 1 then
                    button:SetPoint(
                        "BOTTOMRIGHT",
                        bar4Right,
                        "TOPRIGHT",
                        0,
                        0
                    )
                else
                    button:SetPoint(
                        "BOTTOMRIGHT",
                        _G["MultiBarLeftButton6"],
                        "TOPRIGHT",
                        0,
                        0
                    )
                end

                nextButton = button
            end
        end
    end
end

local function LayoutActionBar6()
    local bar4Left = _G["MultiBarRightButton1"]

    if not MultiBar5 or not bar4Left then
        return
    end

    local previous

    for index = 1, 12 do
        local button = _G["MultiBar5Button" .. index]

        if button then
            local visible = index <= 8
            SetButtonVisible(button, visible)

            if visible then
                StyleButton(button, defaults.secondaryButtonSize)
                button:ClearAllPoints()

                if previous then
                    button:SetPoint(
                        "LEFT",
                        previous,
                        "RIGHT",
                        0,
                        0
                    )
                else
                    button:SetPoint(
                        "BOTTOMLEFT",
                        bar4Left,
                        "TOPLEFT",
                        0,
                        0
                    )
                end

                previous = button
            end
        end
    end
end

local function LayoutStanceBar()
    local bar4Left = _G["MultiBarRightButton1"]

    if not StanceBar or not bar4Left then
        return
    end

    local previous

    for index = 1, 10 do
        local button = _G["StanceButton" .. index]

        if button then
            StyleButton(button, defaults.secondaryButtonSize)
            StyleCheckedState(button)
            button:ClearAllPoints()

            if previous then
                button:SetPoint(
                    "LEFT",
                    previous,
                    "RIGHT",
                    0,
                    0
                )
            else
                button:SetPoint(
                    "BOTTOMLEFT",
                    bar4Left,
                    "TOPLEFT",
                    0,
                    0
                )
            end

            previous = button
        end
    end
end

local function HasStanceBar()
    return GetNumShapeshiftForms
        and GetNumShapeshiftForms() > 0
end

local function LayoutUpperBars()
    LayoutActionBar5()

    if HasStanceBar() then
        for index = 1, 12 do
            SetButtonVisible(_G["MultiBar5Button" .. index], false)
        end

        LayoutStanceBar()
    else
        LayoutActionBar6()
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

StyleCheckedState = function(button)
    local checked = button.CheckedTexture or button:GetCheckedTexture()

    if not checked then
        return
    end

    checked:ClearAllPoints()
    checked:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    checked:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    checked:SetAlpha(button:GetChecked() and 1 or 0)
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

        if button then
            StyleButton(button, defaults.petButtonSize)
            StylePetAutoCastOverlay(button)
            StyleCheckedState(button)
        end

        if container then
            container:ClearAllPoints()
            container:SetScale(1)
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

local function LayoutBars()
    for index, config in ipairs(barConfigs) do
        LayoutBarButtons(config, index)
    end
end

function Module:Apply()
    if InCombatLockdown and InCombatLockdown() then
        self.layoutPending = true
        return
    end

    self.layoutPending = false

    HideBlizzardMenuAndBags()
    HideMainActionBarArt()
    LayoutBars()
    LayoutUpperBars()
    LayoutPetButtons()
end

function Module:Initialize()
    self:Apply()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            Module:Apply()
        end)
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_ActionBar"
            or addonName == "Blizzard_EditMode"
            or addonName == "Blizzard_MicroMenu"
            or addonName == "Blizzard_MainMenuBarBagButtons"
        then
            C_Timer.After(0, function()
                Module:Apply()
            end)
        end
    end)

    UI:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", function()
        if InCombatLockdown and InCombatLockdown() then
            Module.layoutPending = true
            return
        end

        C_Timer.After(0, function()
            LayoutUpperBars()
        end)
    end)

    UI:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function()
        if InCombatLockdown and InCombatLockdown() then
            Module.layoutPending = true
            return
        end

        C_Timer.After(0, function()
            LayoutUpperBars()
        end)
    end)

    UI:RegisterBottomInsetCallback(function(inset)
        Module.bottomInset = inset

        if InCombatLockdown and InCombatLockdown() then
            Module.layoutPending = true
            return
        end

        C_Timer.After(0, function()
            LayoutBars()
            LayoutUpperBars()
        end)
    end)

    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if Module.layoutPending then
            Module:Apply()
        end
    end)
end

Module:Initialize()
