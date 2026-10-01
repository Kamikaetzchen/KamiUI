local UI = KamiUI

local Module = UI:NewModule("ActionBars")

Module.name = "KamiUI_ActionBars"
Module.version = "0.1.0"

local defaults = {
    buttonSize = 36,
    buttonSpacing = 0,
    alpha = 1,
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

local function StyleBars()
    for _, button in ipairs(GetButtons()) do
        StyleButton(button)
    end
end

function Module:Initialize()
    StyleBars()

    hooksecurefunc("ActionButton_Update", function(button)
        StyleButton(button)
    end)
end

Module:Initialize()
