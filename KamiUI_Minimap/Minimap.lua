local UI = KamiUI

local Module = UI:NewModule("Minimap")

Module.name = "KamiUI_Minimap"
Module.version = "0.1.0"

local defaults = {
    size = 180,
    position = {
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 20,
    },
    border = { 0.2, 0.2, 0.2, 1 },
}

local function CreateBorder()
    local border = CreateFrame("Frame", nil, Minimap, "BackdropTemplate")
    border:SetFrameLevel(Minimap:GetFrameLevel() + 1)
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(unpack(defaults.border))

    return border
end

local function StyleMinimap()
    Minimap:SetSize(defaults.size, defaults.size)
    Minimap:SetPoint(
        defaults.position.point,
        UIParent,
        defaults.position.relativePoint,
        defaults.position.x,
        defaults.position.y
    )

    Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")

    if MinimapBorder then
        MinimapBorder:Hide()
    end

    if MinimapZoomIn then
        MinimapZoomIn:Hide()
    end

    if MinimapZoomOut then
        MinimapZoomOut:Hide()
    end

    Minimap.KamiBorder = CreateBorder()
end

function Module:Initialize()
    StyleMinimap()
end

Module:Initialize()
