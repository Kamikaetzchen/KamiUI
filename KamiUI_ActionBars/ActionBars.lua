local UI = KamiUI

local Module = UI:NewModule("ActionBars")

Module.name = "KamiUI_ActionBars"
Module.version = "0.1.0"

local defaults = {
    buttonSize = 36,
    buttonSpacing = 0,
    alpha = 1,
    offsetX = -20,
    offsetY = 20,
}

local bars = {
    MainMenuBar,
    MultiBarBottomLeft,
    MultiBarBottomRight,
    MultiBarRight,
    MultiBarLeft,
}

local function GetButtons()
    local buttons = {}

    for i = 1, 12 do
        table.insert(buttons, _G["ActionButton" .. i])
        table.insert(buttons, _G["MultiBarBottomLeftButton" .. i])
        table.insert(buttons, _G["MultiBarBottomRightButton" .. i])
        table.insert(buttons, _G["MultiBarRightButton" .. i])
        table.insert(buttons, _G["MultiBarLeftButton" .. i])
    end

    return buttons
end

local function StyleButton(button)
    if not button or button.KamiStyled then
        return
    end

    button:SetSize(defaults.buttonSize, defaults.buttonSize)
    button:SetAlpha(defaults.alpha)

    local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
    border:SetAllPoints()
    border:SetFrameLevel(button:GetFrameLevel() + 1)
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    button.KamiBorder = border
    button.KamiStyled = true
end

local function CompactBar(bar)
    if not bar then
        return
    end

    bar:SetScale(1)
    bar:ClearAllPoints()
end

local function LayoutBars()
    local xOffset = defaults.offsetX
    local yOffset = defaults.offsetY

    local anchors = {
        MainMenuBar,
        MultiBarBottomLeft,
        MultiBarBottomRight,
        MultiBarRight,
    }

    for index, bar in ipairs(anchors) do
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint(
                "BOTTOMRIGHT",
                UIParent,
                "BOTTOMRIGHT",
                xOffset,
                yOffset + ((index - 1) * defaults.buttonSize)
            )
        end
    end
end

local function StyleBars()
    for _, button in ipairs(GetButtons()) do
        StyleButton(button)
    end

    for _, bar in ipairs(bars) do
        CompactBar(bar)
    end

    LayoutBars()
end

function Module:Initialize()
    StyleBars()

    hooksecurefunc("ActionButton_Update", function(button)
        StyleButton(button)
    end)
end

Module:Initialize()
