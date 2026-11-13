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

-- Center the player's position along the top edge, clear of the
-- tracking and mail indicators at the upper corners.
local function CreateCoordinatesLabel()
    if Module.coordinates then return end

    local label = CreateBorder():CreateFontString(nil,
        "OVERLAY", "GameFontNormalSmall")
    label:SetSize(110, 16)
    label:SetPoint("TOP", Minimap, "TOP", 0, -5)
    label:SetJustifyH("CENTER")
    local font = label:GetFont()
    if font then label:SetFont(font, 11, "OUTLINE") end
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
    label:SetTextColor(unpack(Palette.text))
    label:SetText("--, --")

    Module.coordinates = label
end

function Module:RefreshCoordinates()
    local label = self.coordinates
    if not label then return end

    if C_Map and C_Map.GetBestMapForUnit
        and C_Map.GetPlayerMapPosition then
        local mapID = C_Map.GetBestMapForUnit("player")
        if UI:CanAccessValue(mapID) and type(mapID) == "number" then
            if self.coordinateMapID ~= mapID then
                -- Never show coordinates from a different map.
                self.coordinateMapID = mapID
                self.lastCoordinates = nil
            end

            local position = C_Map.GetPlayerMapPosition(mapID, "player")
            if position and UI:CanAccessValue(position) then
                local ok, x, y = pcall(position.GetXY, position)
                if ok and UI:CanAccessValue(x) and UI:CanAccessValue(y)
                    and type(x) == "number" and type(y) == "number"
                    and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                    self.lastCoordinates = string.format(
                        "%.1f, %.1f", x * 100, y * 100)
                    label:SetText(self.lastCoordinates)
                    label:SetTextColor(unpack(Palette.text))
                    return
                end
            end
        end
    end

    -- Forever can restrict live map values in combat. Keep a same-map
    -- snapshot, visibly marked red, instead of showing stale data as live.
    if self.lastCoordinates then
        label:SetText(self.lastCoordinates)
        label:SetTextColor(1, 0.35, 0.35)
    else
        label:SetText("--, --")
        label:SetTextColor(unpack(Palette.muted))
    end
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

    -- Blizzard's AddOn Compartment (the small numbered "AddOns" button)
    -- is redundant with KamiUI's permanently visible addon icon dock.
    -- Cover the frame/button names exposed by different client versions.
    HideObject(_G.AddonCompartmentFrame)
    HideObject(_G.AddOnCompartmentFrame)
    HideObject(_G.AddonCompartmentButton)
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
    CreateCoordinatesLabel()
end

function Module:Apply()
    StyleMinimap()
end

function Module:Initialize()
    self:Apply()
    self:RefreshCoordinates()

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        Module:Apply()
        Module:RefreshCoordinates()
    end)

    -- A native map read every half second is sufficient while running
    -- through a zone; no frame-by-frame polling or map-frame dependency.
    C_Timer.NewTicker(0.5, function()
        Module:RefreshCoordinates()
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
        Module.coordinateMapID = nil
        Module.lastCoordinates = nil
        Module:RefreshCoordinates()
    end)

    -- Quest tracking can rebuild native map blobs after our initial style.
    -- Reapply only the ring settings so the useful quest-area fill remains.
    UI:RegisterEvent("QUEST_LOG_UPDATE", HideRoundBlobRings)
    UI:RegisterEvent("QUEST_POI_UPDATE", HideRoundBlobRings)
    UI:RegisterEvent("QUEST_WATCH_LIST_CHANGED", HideRoundBlobRings)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_Minimap"
            or addonName == "Blizzard_TimeManager"
            or addonName == "Blizzard_AddonCompartment"
        then
            HideBlizzardChrome()
            HideRoundBlobRings()
            PositionHeaderIndicators()
        end
    end)
end

Module:Initialize()
