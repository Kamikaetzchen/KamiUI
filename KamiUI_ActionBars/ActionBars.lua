local UI = KamiUI

local Module = UI:NewModule("ActionBars")

Module.name = "KamiUI_ActionBars"
Module.version = "0.1.0"

local defaults = {
    buttonSize = 36,
    buttonSpacing = 0,
    iconZoom = 0.08,
    petBarWidth = 404,
    petButtonSize = 40.4,
    alpha = 1,
    offsetX = -20,
    offsetY = 20,
}

local barConfigs = {
    {
        frame = MainMenuBar,
        prefix = "ActionButton",
    },
    {
        frame = MultiBarBottomLeft,
        prefix = "MultiBarBottomLeftButton",
    },
    {
        frame = MultiBarBottomRight,
        prefix = "MultiBarBottomRightButton",
    },
    {
        frame = MultiBarRight,
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

    if not button.KamiStyled then
        button:SetAlpha(defaults.alpha)

        StyleCooldown(button.cooldown, button)
        StyleCooldown(button.lossOfControlCooldown, button)
        StyleCooldown(button.chargeCooldown, button)

        button.KamiStyled = true
    end

    StripButtonArt(button)
end

local function LayoutBarButtons(config)
    if not config.frame then
        return
    end

    local previous

    for index = 1, 12 do
        local button = _G[config.prefix .. index]

        if button then
            StyleButton(button)
            button:ClearAllPoints()

            if previous then
                button:SetPoint(
                    "LEFT",
                    previous,
                    "RIGHT",
                    defaults.buttonSpacing,
                    0
                )
            else
                button:SetPoint("BOTTOMLEFT", config.frame, "BOTTOMLEFT", 0, 0)
            end

            previous = button
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

            if button.AutoCastOverlay then
                button.AutoCastOverlay:ClearAllPoints()
                button.AutoCastOverlay:SetAllPoints(button)
                button.AutoCastOverlay:SetSize(
                    defaults.petButtonSize,
                    defaults.petButtonSize
                )
            end
        end
    end

    PetActionBar.oldGridSettings = nil

    if PetActionBar.UpdateShownButtons then
        PetActionBar:UpdateShownButtons()
    end

    if PetActionBar.UpdateGridLayout then
        PetActionBar:UpdateGridLayout()
    end

    PetActionBar:ClearAllPoints()

    if KamiUIPlayerFrame and KamiUITargetFrame then
        -- PetActionBar inherits ResizeLayoutFrame, so its width is calculated
        -- from the ten button containers. 10 * 40.4 = 404, matching the full
        -- outer span of the two 200px unit frames plus their 4px center gap.
        PetActionBar:SetPoint(
            "TOPLEFT",
            KamiUIPlayerFrame,
            "BOTTOMLEFT",
            0,
            0
        )
    else
        PetActionBar:SetPoint(
            "TOP",
            UIParent,
            "CENTER",
            0,
            -260
        )
    end
end

local function LayoutBars()
    for index, config in ipairs(barConfigs) do
        local bar = config.frame

        if bar then
            bar:SetScale(1)
            bar:ClearAllPoints()
            bar:SetPoint(
                "BOTTOMRIGHT",
                UIParent,
                "BOTTOMRIGHT",
                defaults.offsetX,
                defaults.offsetY + ((index - 1) * defaults.buttonSize)
            )
        end

        LayoutBarButtons(config)
    end
end

function Module:Apply()
    HideBlizzardMenuAndBags()

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
        if addonName == "Blizzard_MicroMenu"
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
