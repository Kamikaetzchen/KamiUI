local UI = KamiUI
local Styles = UI.Styles

local Module = UI:NewModule("Minimap", "KamiUI_Minimap")


local Layout = UI.Layout.Minimap

local function HideObject(object)
    if not object then
        return
    end

    if object:IsObjectType("Frame") then
        UI:KeepFrameHidden(object)
    else
        Styles:HideRegion(object)
        object:Hide()
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

    if MinimapCluster then
        HideObject(MinimapCluster.InstanceDifficulty)
    end

    HideObject(MinimapZoneTextButton)
    HideObject(MinimapZoneText)

    if MinimapCluster and MinimapCluster.ZoneTextButton then
        HideObject(MinimapCluster.ZoneTextButton)
    end

    HideObject(MinimapZoomIn)
    HideObject(MinimapZoomOut)
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

local function HideRoundBlobRings()
    if Minimap.SetQuestBlobRingAlpha then
        Minimap:SetQuestBlobRingAlpha(0)
    end

    if Minimap.SetTaskBlobRingAlpha then
        Minimap:SetTaskBlobRingAlpha(0)
    end
end

local function StyleMinimap()
    Minimap:SetSize(Layout.SIZE, Layout.SIZE)

    Minimap:ClearAllPoints()
    Minimap:SetPoint(
        Layout.POINT,
        UIParent,
        Layout.RELATIVE_POINT,
        Layout.X,
        Layout.Y + UI:GetBottomInset()
    )

    -- Circular map; the matching artwork rim can be added separately.
    Minimap:SetMaskTexture("Textures\\MinimapMask")

    HideRoundBlobRings()
    HideBlizzardChrome()
    PositionHeaderIndicators()
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
            HideBlizzardChrome()
            PositionHeaderIndicators()
        end
    end)
end

Module:Initialize()
