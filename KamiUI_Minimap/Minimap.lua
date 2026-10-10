local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles

local Module = UI:NewModule("Minimap", "KamiUI_Minimap")


local Layout = UI.Layout.Minimap

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
    border:SetBackdropBorderColor(unpack(Palette.minimapBorder))

    Minimap.KamiBorder = border

    return border
end

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
    -- The quest-area highlight is drawn by the minimap renderer, not as a
    -- separate texture. On a square minimap its default ring is still
    -- shaped for Blizzard's round mask, causing bright circular wedges.
    -- Zero the ring width as well as its alpha; alpha alone does not
    -- reliably suppress the artifact on Forever.
    if Minimap.SetQuestBlobRingAlpha then
        Minimap:SetQuestBlobRingAlpha(0)
    end
    if Minimap.SetQuestBlobRingScalar then
        Minimap:SetQuestBlobRingScalar(0)
    end

    if Minimap.SetTaskBlobRingAlpha then
        Minimap:SetTaskBlobRingAlpha(0)
    end
    if Minimap.SetTaskBlobRingScalar then
        Minimap:SetTaskBlobRingScalar(0)
    end

    if Minimap.SetArchBlobRingAlpha then
        Minimap:SetArchBlobRingAlpha(0)
    end
    if Minimap.SetArchBlobRingScalar then
        Minimap:SetArchBlobRingScalar(0)
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

    -- Keep the map square. The Blizzard ring/chrome is hidden separately.
    Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")

    HideRoundBlobRings()
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
        elseif cvar == "minimapShowQuestBlobs" then
            HideRoundBlobRings()
        end
    end)

    UI:RegisterEvent("PLAYER_DIFFICULTY_CHANGED", HideBlizzardChrome)
    UI:RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
        HideBlizzardChrome()
        HideRoundBlobRings()
    end)

    -- Quest tracking can rebuild native map blobs after our initial style.
    -- Reapply only the ring settings so the useful quest-area fill remains.
    UI:RegisterEvent("QUEST_LOG_UPDATE", HideRoundBlobRings)
    UI:RegisterEvent("QUEST_POI_UPDATE", HideRoundBlobRings)
    UI:RegisterEvent("QUEST_WATCH_LIST_CHANGED", HideRoundBlobRings)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_Minimap"
            or addonName == "Blizzard_TimeManager"
        then
            HideBlizzardChrome()
            HideRoundBlobRings()
            PositionHeaderIndicators()
        end
    end)
end

Module:Initialize()
