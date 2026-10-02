local UI = KamiUI

local Module = UI:NewModule("ActionBars")

Module.name = "KamiUI_ActionBars"
Module.version = "0.1.0"

local defaults = {
    buttonSize = 36,
    buttonSpacing = 0,
    iconZoom = 0.08,
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

local function StyleButton(button)
    if not button then
        return
    end

    if not button.KamiStyled then
        button:SetSize(defaults.buttonSize, defaults.buttonSize)
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
