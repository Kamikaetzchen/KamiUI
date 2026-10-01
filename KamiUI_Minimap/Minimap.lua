local UI = KamiUI

local Module = UI:NewModule("Minimap")

Module.name = "KamiUI_Minimap"
Module.version = "0.1.0"

local defaults = {
    size = 180,
    border = { 0.2, 0.2, 0.2, 1 },
}

local function StyleMinimap()
    Minimap:SetSize(defaults.size, defaults.size)
    Minimap:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 20)

    Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")

    local border = CreateFrame("Frame", nil, Minimap, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(unpack(defaults.border))

    Minimap.KamiBorder = border

    if MinimapBorder then
        MinimapBorder:Hide()
    end

    if MinimapZoomIn then
        MinimapZoomIn:Hide()
    end

    if MinimapZoomOut then
        MinimapZoomOut:Hide()
    end
end

function Module:Initialize()
    StyleMinimap()
end

Module:Initialize()
