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

local function DisableMouseTree(frame)
    if not frame then
        return
    end

    if frame.EnableMouse then
        frame:EnableMouse(false)
    end

    if frame.GetChildren then
        local children = { frame:GetChildren() }

        for _, child in ipairs(children) do
            DisableMouseTree(child)
        end
    end
end

local function HideObject(object)
    if not object then
        return
    end

    object:SetAlpha(0)
    DisableMouseTree(object)
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

local function HideDividerPool(pool)
    if not pool or not pool.EnumerateActive then
        return
    end

    for divider in pool:EnumerateActive() do
        if NineSliceUtil and NineSliceUtil.HideLayout then
            NineSliceUtil.HideLayout(divider)
        else
            divider:SetAlpha(0)
        end
    end
end

local function HideMainActionBarDividers()
    if not MainActionBar then
        return
    end

    HideDividerPool(MainActionBar.HorizontalDividersPool)
    HideDividerPool(MainActionBar.VerticalDividersPool)
end

local function HideMainActionBarArt()
    if not MainActionBar then
        return
    end

    HideTexture(MainActionBar.BorderArt)
    HideObject(MainActionBar.EndCaps)
    HideObject(MainActionBar.ActionBarPageNumber)
    HideMainActionBarDividers()
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

local function StripButtonArt(button)
    if not button then
        return
    end

    RefreshButtonVisuals(button)
    MakeIconSquare(button, GetButtonIcon(button))
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

    button:SetScale(1)
    button:SetSize(size, size)
    button.KamiButtonSize = size

    if button.container then
        button.container:SetScale(1)
        button.container:SetSize(size, size)
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

local function SetBarButtonCount(bar, count)
    if not bar then
        return
    end

    bar.numButtonsShowable = count

    if bar.UpdateShownButtons then
        bar:UpdateShownButtons()
    end
end

local function LayoutActionBar5()
    local bar = MultiBarLeft
    local bar4Left, bar4Right = GetBar4Edges()

    if not bar or not bar4Left or not bar4Right then
        return
    end

    bar:SetScale(1)
    SetBarButtonCount(bar, 12)

    for row = 1, 2 do
        local rightIndex = row * 6
        local nextButton

        for index = rightIndex, rightIndex - 5, -1 do
            local button = _G["MultiBarLeftButton" .. index]

            if button then
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
    local bar = MultiBar5
    local bar4Left = _G["MultiBarRightButton1"]

    if not bar or not bar4Left then
        return
    end

    bar:SetScale(1)
    SetBarButtonCount(bar, 8)

    local previous

    for index = 1, 8 do
        local button = _G["MultiBar5Button" .. index]

        if button then
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

local function LayoutStanceBar()
    local bar4Left = _G["MultiBarRightButton1"]

    if not StanceBar or not bar4Left then
        return
    end

    StanceBar:SetScale(1)
    StanceBar.minButtonPadding = 0
    StanceBar.buttonPadding = 0

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
        SetBarButtonCount(MultiBar5, 0)
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

local function RestylePetButtons()
    for index = 1, 10 do
        local button = _G["PetActionButton" .. index]

        if button then
            StripButtonArt(button)
            StylePetAutoCastOverlay(button)
            StyleCheckedState(button)
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
            StyleCheckedState(button)
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

local function NormalizeBarScale(bar)
    if bar then
        bar:SetScale(1)
    end
end

local function NormalizeManagedScales()
    for _, config in ipairs(barConfigs) do
        NormalizeBarScale(GetBarFrame(config))
    end

    NormalizeBarScale(MultiBarLeft)
    NormalizeBarScale(MultiBar5)
    NormalizeBarScale(StanceBar)
    NormalizeBarScale(PetActionBar)
end

local function LayoutBars()
    NormalizeManagedScales()

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

    NormalizeManagedScales()
    LayoutBars()
    LayoutUpperBars()
    StylePetBar()
end

function Module:Initialize()
    self:Apply()

    if StanceBar and StanceBar.UpdateState and not StanceBar.KamiUpdateHooked then
        StanceBar.KamiUpdateHooked = true

        hooksecurefunc(StanceBar, "UpdateState", function()
            C_Timer.After(0, function()
                if not InCombatLockdown or not InCombatLockdown() then
                    LayoutStanceBar()
                end
            end)
        end)
    end

    hooksecurefunc("ActionButton_Update", function(button)
        RefreshButtonVisuals(button)
    end)

    local function InstallMainActionBarHooks()
        if not MainActionBar then
            return
        end

        if MainActionBar.UpdateEndCaps
            and not MainActionBar.KamiEndCapsHooked
        then
            MainActionBar.KamiEndCapsHooked = true

            hooksecurefunc(MainActionBar, "UpdateEndCaps", function()
                C_Timer.After(0, function()
                    if not InCombatLockdown
                        or not InCombatLockdown()
                    then
                        HideMainActionBarArt()
                    else
                        Module.layoutPending = true
                    end
                end)
            end)
        end

        if MainActionBar.UpdateDividers
            and not MainActionBar.KamiDividersHooked
        then
            MainActionBar.KamiDividersHooked = true

            hooksecurefunc(MainActionBar, "UpdateDividers", function()
                HideMainActionBarDividers()
            end)
        end
    end

    InstallMainActionBarHooks()

    local function InstallScaleHook(bar)
        if not bar
            or bar.KamiScaleHooked
            or not bar.UpdateSystemSettingIconSize
        then
            return
        end

        bar.KamiScaleHooked = true

        hooksecurefunc(bar, "UpdateSystemSettingIconSize", function()
            C_Timer.After(0, function()
                if not InCombatLockdown or not InCombatLockdown() then
                    Module:Apply()
                else
                    Module.layoutPending = true
                end
            end)
        end)
    end

    local function InstallScaleHooks()
        for _, config in ipairs(barConfigs) do
            InstallScaleHook(GetBarFrame(config))
        end

        InstallScaleHook(MultiBarLeft)
        InstallScaleHook(MultiBar5)
        InstallScaleHook(StanceBar)
        InstallScaleHook(PetActionBar)
    end

    InstallScaleHooks()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, function()
            InstallMainActionBarHooks()
            InstallScaleHooks()
            Module:Apply()
        end)
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_ActionBar"
            or addonName == "Blizzard_EditMode"
        then
            C_Timer.After(0, function()
                InstallMainActionBarHooks()
                InstallScaleHooks()
                Module:Apply()
            end)
        elseif addonName == "Blizzard_MicroMenu"
            or addonName == "Blizzard_MainMenuBarBagButtons"
        then
            C_Timer.After(0, HideBlizzardMenuAndBags)
        end
    end)

    UI:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", function()
        C_Timer.After(0, function()
            if not InCombatLockdown or not InCombatLockdown() then
                LayoutUpperBars()
            else
                Module.layoutPending = true
            end
        end)
    end)

    UI:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function()
        C_Timer.After(0, function()
            if not InCombatLockdown or not InCombatLockdown() then
                LayoutUpperBars()
            else
                Module.layoutPending = true
            end
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
