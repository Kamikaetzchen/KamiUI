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

    -- MinimapBackdrop may be part of Blizzard's minimap hierarchy.
    -- Moving the entire frame into our hidden sink can also make the
    -- map disappear. Only hide its chrome; keep the frame alive.
    if MinimapBackdrop then
        MinimapBackdrop:SetAlpha(0)
        if MinimapBackdrop.EnableMouse then
            MinimapBackdrop:EnableMouse(false)
        end
    end

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

local function CreateMinimapAnchor()
    if Module.anchor then
        return Module.anchor
    end

    local anchor = CreateFrame("Frame", "KamiUIMinimapAnchor", UIParent)
    anchor:SetFrameStrata("LOW")
    anchor:SetFrameLevel(9)
    anchor:EnableMouse(false)

    Module.anchor = anchor
    return anchor
end

local function StyleMinimap()
    -- Give the real map an independent, visible parent. The Blizzard
    -- cluster/backdrop may be hidden without affecting map rendering.
    local anchor = CreateMinimapAnchor()
    anchor:SetSize(Layout.SIZE, Layout.SIZE)
    anchor:ClearAllPoints()
    anchor:SetPoint(
        Layout.POINT,
        UIParent,
        Layout.RELATIVE_POINT,
        Layout.X,
        Layout.Y + UI:GetBottomInset()
    )

    if Minimap:GetParent() ~= anchor then
        Minimap:SetParent(anchor)
    end

    Minimap:ClearAllPoints()
    Minimap:SetAllPoints(anchor)
    Minimap:SetFrameStrata("LOW")
    Minimap:SetFrameLevel(anchor:GetFrameLevel() + 1)
    Minimap:SetScale(1)
    Minimap:SetAlpha(1)
    Minimap:Show()
    Minimap:EnableMouse(true)

    -- Keep the native circular mask and all map interactions intact.
    Minimap:SetMaskTexture("Textures\\MinimapMask")

    HideRoundBlobRings()
    HideBlizzardChrome()
    PositionHeaderIndicators()
end

-- The texture crops include the curved joining arms, avoiding visible seams.
-- The top parts now belong to their UnitFrames and hide with them.
local PARTS = {
    { key = "center", section = "CENTER", side = 0 },
    { key = "bottomLeft", section = "BOTTOM", side = -1 },
    { key = "bottomRight", section = "BOTTOM", side = 1, mirror = true },
}

local function CreateHUD()
    if Module.hud then
        return Module.hud
    end

    -- Draw above the world, but below interactive action buttons.
    local hud = CreateFrame("Frame", "KamiUIHUD", UIParent)
    hud:SetFrameStrata("LOW")
    hud:SetFrameLevel(1)
    hud:SetSize(1, 1)
    hud:EnableMouse(false)
    hud.parts = {}

    for _, part in ipairs(PARTS) do
        local base = hud:CreateTexture(nil, "ARTWORK")
        base:SetDrawLayer("ARTWORK", 0)
        local accent = hud:CreateTexture(nil, "ARTWORK")
        accent:SetDrawLayer("ARTWORK", 1)

        if part.mirror then
            base:SetTexCoord(1, 0, 0, 1)
            accent:SetTexCoord(1, 0, 0, 1)
        end

        hud.parts[part.key] = { base = base, accent = accent }
    end

    Module.hud = hud
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
    hud:ClearAllPoints()
    hud:SetPoint("CENTER", Minimap, "CENTER", HUDLayout.X, HUDLayout.Y)

    local r, g, b = Palette:GetHUDAccentColor()

    for _, part in ipairs(PARTS) do
        local layout = HUDLayout[part.section]
        local textures = hud.parts[part.key]
        local x = part.side == 0 and layout.X or part.side * layout.X

        for _, texture in ipairs({ textures.base, textures.accent }) do
            texture:SetSize(layout.WIDTH, layout.HEIGHT)
            texture:ClearAllPoints()
            texture:SetPoint("CENTER", hud, "CENTER", x, layout.Y)
        end

        textures.base:SetTexture(layout.BASE_TEXTURE)
        textures.base:SetAlpha(HUDLayout.BASE_ALPHA)
        textures.accent:SetTexture(layout.ACCENT_TEXTURE)
        textures.accent:SetVertexColor(r, g, b)
        textures.accent:SetAlpha(HUDLayout.ACCENT_ALPHA)
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
