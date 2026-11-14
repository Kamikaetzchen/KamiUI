local UI = KamiUI
local Module = UI:NewModule("WorldMap", "KamiUI_WorldMap")

local Styles = UI.Styles
local Palette = UI.Palette
local Components = UI.Components

-- Styling only: OpenMap owns map position, scale, size, resize grips,
-- canvas, zoom, pins and the quest log's docked width.
local hooks = {}
local mapFrame

local function StyleBreadcrumbs()
    local nav = mapFrame and mapFrame.NavBar
    if not nav then return end

    -- The native navbar already provides a working clickable path,
    -- including its overflow menu. Do not create competing buttons.
    Styles:EnsureBackground(
        nav, "KamiMapBreadcrumbBackground", Palette.header
    )
    Styles:CreateBorder(nav, {
        color = Palette.windowBorder.neutral,
        size = 1,
        key = "KamiMapBreadcrumbBorder",
        top = false,
        left = false,
        right = false,
    })

    local buttons = nav.navList
    if type(buttons) ~= "table" then return end

    for index, button in ipairs(buttons) do
        if button.text then
            if not button.KamiMapBreadcrumbStyled then
                button.KamiMapBreadcrumbStyled = true
                Styles:ApplyText(button.text, "normal")
            end

            -- Native button callbacks, parent paths, dropdowns and
            -- widths stay intact. Only the text color is ours.
            Styles:SetTextColor(
                button.text,
                index == #buttons and Palette.gold or Palette.muted
            )
        end
    end
end

local function SkinWorldMap()
    local map = _G.WorldMapFrame
    local border = map and map.BorderFrame
    if not map or not border then return end

    mapFrame = map

    if not hooks.map then
        hooks.map = true

        -- Keep the native Blizzard frame and OpenMap's size/anchors.
        Styles:EnsureBackground(
            map, "KamiWorldMapBackground", Palette.window.neutral
        )

        -- Hide only decorative chrome, not the map, buttons or
        -- OpenMap's interactive resize grips.
        if border.NineSlice then
            border.NineSlice:SetAlpha(0)
        end
        if border.Bg then
            border.Bg:SetAlpha(0)
        end

        Styles:CreateBorder(border, {
            color = Palette.windowBorder.neutral,
            size = 1,
            key = "KamiWorldMapBorder",
        })

        local header = Components:CreateWindowHeader(border, {
            title = MAP_AND_QUEST_LOG or WORLD_MAP or "World Map",
            height = 24,
            inset = 1,
            draggable = false,
        })
        Styles:EnsureBackground(
            header, "KamiWorldMapHeaderBackground", Palette.header
        )
        Styles:CreateBorder(header, {
            color = Palette.windowBorder.neutral,
            size = 1,
            key = "KamiWorldMapHeaderDivider",
            top = false,
            left = false,
            right = false,
        })

        -- The KamiUI header replaces the native title lettering, not
        -- its close/maximize controls or the frame's drag handler.
        local title = border.TitleContainer
            and border.TitleContainer.TitleText
            or border.TitleText
        if title then
            title:SetAlpha(0)
        end

        map:HookScript("OnShow", StyleBreadcrumbs)
    end

    StyleBreadcrumbs()
end

local function InstallHooks()
    if _G.WorldMapFrame then
        SkinWorldMap()
    end

    -- NavBar buttons are pooled and rebuilt as players navigate.
    -- Apply colors after Blizzard updates its own button list.
    if not hooks.navAdd and hooksecurefunc
        and type(NavBar_AddButton) == "function" then
        hooks.navAdd = true
        hooksecurefunc("NavBar_AddButton", function(nav)
            if mapFrame and nav == mapFrame.NavBar then
                StyleBreadcrumbs()
            end
        end)
    end

    if not hooks.navReset and hooksecurefunc
        and type(NavBar_Reset) == "function" then
        hooks.navReset = true
        hooksecurefunc("NavBar_Reset", function(nav)
            if mapFrame and nav == mapFrame.NavBar then
                StyleBreadcrumbs()
            end
        end)
    end
end

InstallHooks()
UI:RegisterEvent("ADDON_LOADED", InstallHooks)
