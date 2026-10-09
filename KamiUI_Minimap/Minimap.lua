local UI = KamiUI
local Styles = UI.Styles
local Palette = UI.Palette

local Module = UI:NewModule("Minimap", "KamiUI_Minimap")


local Layout = UI.Layout.Minimap
local HUDLayout = UI.Layout.HUD

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

local function CreateHUD()
    if Module.hud then
        return Module.hud
    end

    -- Artwork is purely visual; it never blocks minimap or button clicks.
    local hud = CreateFrame("Frame", "KamiUIHUD", UIParent)
    hud:SetFrameStrata("BACKGROUND")
    hud:SetFrameLevel(1)
    hud:EnableMouse(false)

    local base = hud:CreateTexture(nil, "BACKGROUND")
    base:SetAllPoints()
    base:SetTexture(HUDLayout.BASE_TEXTURE)

    local accent = hud:CreateTexture(nil, "ARTWORK")
    accent:SetAllPoints()
    accent:SetTexture(HUDLayout.ACCENT_TEXTURE)

    Module.hud = hud
    Module.hudBase = base
    Module.hudAccent = accent

    return hud
end

local function StyleHUD()
    if not HUDLayout.ENABLED then
        if Module.hud then
            Module.hud:Hide()
        end
        return
    end

    local hud = CreateHUD()
    hud:SetSize(HUDLayout.WIDTH, HUDLayout.HEIGHT)
    hud:ClearAllPoints()
    hud:SetPoint("CENTER", Minimap, "CENTER", HUDLayout.X, HUDLayout.Y)

    Module.hudBase:SetTexture(HUDLayout.BASE_TEXTURE)
    Module.hudBase:SetAlpha(HUDLayout.BASE_ALPHA)
    Module.hudAccent:SetTexture(HUDLayout.ACCENT_TEXTURE)
    Module.hudAccent:SetAlpha(HUDLayout.ACCENT_ALPHA)

    local _, class = UnitClass("player")
    local color = Palette:GetClassColor(class)

    if color then
        local r = color.r or color[1] or 1
        local g = color.g or color[2] or 1
        local b = color.b or color[3] or 1
        local gray = (r + g + b) / 3
        local saturation = HUDLayout.CLASS_COLOR_SATURATION

        Module.hudAccent:SetVertexColor(
            gray + (r - gray) * saturation,
            gray + (g - gray) * saturation,
            gray + (b - gray) * saturation
        )
    else
        Module.hudAccent:SetVertexColor(1, 1, 1)
    end

    hud:Show()
end

function Module:Apply()
    StyleMinimap()
    StyleHUD()
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
