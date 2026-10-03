local UI = KamiUI

local Module = UI:NewModule("Minimap")

Module.name = "KamiUI_Minimap"
Module.version = "0.1.0"

local defaults = {
    size = 220,
    position = {
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 0,
    },
    border = { 0.2, 0.2, 0.2, 1 },
}

local function CreateBorder()
    if Minimap.KamiBorder then
        return Minimap.KamiBorder
    end

    local border = CreateFrame("Frame", nil, Minimap, "BackdropTemplate")
    border:SetFrameLevel(Minimap:GetFrameLevel() + 1)
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(unpack(defaults.border))

    Minimap.KamiBorder = border

    return border
end

local function HideObject(object)
    if not object then
        return
    end

    object:Hide()

    if object.SetAlpha then
        object:SetAlpha(0)
    end
end

local function HideBlizzardChrome()
    HideObject(MinimapBorder)
    HideObject(MinimapBorderTop)
    HideObject(MinimapBackdrop)
    HideObject(MinimapNorthTag)
    HideObject(MinimapCompassTexture)

    -- Forever re-shows this texture when Rotate Minimap changes.
    HideObject(MinimapCompassTextureUnderlay)

    if MinimapCluster then
        HideObject(MinimapCluster.BorderTop)
        HideObject(MinimapCluster.DielFrame)
    end

    HideObject(TimeManagerClockButton)
    HideObject(GameTimeFrame)

    -- Instance/dungeon difficulty badges normally sit on the minimap rim.
    HideObject(MiniMapInstanceDifficulty)
    HideObject(GuildInstanceDifficulty)
    HideObject(MiniMapChallengeMode)

    HideObject(MinimapZoneTextButton)
    HideObject(MinimapZoneText)

    if MinimapCluster and MinimapCluster.ZoneTextButton then
        HideObject(MinimapCluster.ZoneTextButton)
    end

    if MinimapZoomIn then
        MinimapZoomIn:Hide()
    end

    if MinimapZoomOut then
        MinimapZoomOut:Hide()
    end
end

local function PositionHeaderIndicators()
    local tracking = MinimapCluster and MinimapCluster.Tracking

    if tracking then
        tracking.ignoreInLayout = true
        tracking:ClearAllPoints()
        tracking:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -8, 8)
    end

    local indicatorFrame = MinimapCluster
        and MinimapCluster.IndicatorFrame

    if indicatorFrame then
        indicatorFrame.ignoreInLayout = true
    end

    local mail = indicatorFrame and indicatorFrame.MailFrame

    if mail then
        mail.ignoreInLayout = true
        mail:ClearAllPoints()
        mail:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 8, 8)
    end
end

local function StyleMinimap()
    Minimap:SetSize(defaults.size, defaults.size)

    Minimap:ClearAllPoints()
    Minimap:SetPoint(
        defaults.position.point,
        UIParent,
        defaults.position.relativePoint,
        defaults.position.x,
        defaults.position.y + UI:GetBottomInset()
    )

    -- Keep the map square. The Blizzard ring/chrome is hidden separately.
    Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")

    HideBlizzardChrome()
    PositionHeaderIndicators()
    CreateBorder()
end

function Module:Apply()
    StyleMinimap()
end

function Module:Initialize()
    self:Apply()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        Module:Apply()
    end)

    UI:RegisterBottomInsetCallback(function()
        Module:Apply()
    end)

    UI:RegisterEvent("CVAR_UPDATE", function(_, cvar)
        if cvar == "rotateMinimap" then
            HideBlizzardChrome()
        end
    end)

    UI:RegisterEvent("PLAYER_DIFFICULTY_CHANGED", HideBlizzardChrome)
    UI:RegisterEvent("ZONE_CHANGED_NEW_AREA", HideBlizzardChrome)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_Minimap"
            or addonName == "Blizzard_TimeManager"
        then
            C_Timer.After(0, function()
                HideBlizzardChrome()
                PositionHeaderIndicators()
            end)
        end
    end)
end

Module:Initialize()
