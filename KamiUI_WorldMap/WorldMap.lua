local UI = KamiUI
local Module = UI:NewModule("WorldMap", "KamiUI_WorldMap")

local Styles = UI.Styles
local Palette = UI.Palette
local Components = UI.Components
local Media = UI.Media.DarkMetallic

-- Styling only: OpenMap owns map position, scale, size, resize grips,
-- canvas, zoom, pins and the quest log's docked width.
local hooks = {}
local mapFrame

-- Hide artwork on native navigation objects, but never suppress
-- their FontStrings, interactive frames or click behavior.
local function HideNavigationArtwork(frame)
    if not frame or not frame.GetRegions then return end

    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region.GetObjectType
            and region:GetObjectType() == "Texture" then
            region:SetAlpha(0)
        end
    end
end

local function HideButtonArt(button)
    if not button then return end

    for _, getter in ipairs({
        "GetNormalTexture",
        "GetPushedTexture",
        "GetHighlightTexture",
    }) do
        if button[getter] then
            local region = button[getter](button)
            if region then region:SetAlpha(0) end
        end
    end

    for _, name in ipairs({
        "selected", "arrowUp", "arrowDown",
    }) do
        if button[name] then button[name]:SetAlpha(0) end
    end

    if button.MenuArrowButton then
        local arrow = button.MenuArrowButton
        HideButtonArt(arrow)
        if arrow.Art then arrow.Art:SetAlpha(0) end
        if arrow.NormalTexture then
            arrow.NormalTexture:SetAlpha(0)
        end
        if arrow.PushedTexture then
            arrow.PushedTexture:SetAlpha(0)
        end
    end
end

-- Only the little zone-selection arrow uses our dropdown. A click on
-- the location label is still handled by Blizzard's NavBar_ButtonOnClick.
-- Entries come from Blizzard's own listFunc, preserving OpenMap maps.
-- The native controls keep their hitboxes, visibility and click scripts.
-- Only add new visual regions and hide the original decoration.
local function CreateMetallicNavigationArt(button)
    if button.KamiMapMetallicFrame then return end
    button.KamiMapMetallicFill = Components:CreateMetallicButtonSlice(button, {
        asset = Media.textButtonFill .. "normal",
    })
    button.KamiMapMetallicFrame = Components:CreateMetallicButtonSlice(button, {
        asset = Media.textButtonFrame .. "normal",
        sublevel = -6,
    })
end

local function StyleMapControl(button, glyph, red)
    if not button or not button.CreateFontString then return end
    HideButtonArt(button)
    if button.KamiMapControl then return end

    -- A mouse-transparent, fixed-size visual on the existing native button.
    local art = CreateFrame("Frame", nil, button)
    art:SetSize(Styles.Metrics.headerActionSize, Styles.Metrics.headerActionSize)
    art:SetPoint("CENTER")
    art:EnableMouse(false)
    CreateMetallicNavigationArt(art)
    local label = art:CreateFontString(nil, "OVERLAY")
    Styles:ApplyText(label, 14, red and { 1, 0.15, 0.15, 1 } or Palette.text)
    label:SetPoint("CENTER")
    label:SetText(glyph)
    button.KamiMapControl = art

    local function Refresh(state)
        HideButtonArt(button)
        art.KamiMapMetallicFrame:SetAsset(Media.textButtonFrame .. state)
        art.KamiMapMetallicFill:SetAsset(Media.textButtonFill .. state)
    end
    button:HookScript("OnEnter", function() Refresh("hovered") end)
    button:HookScript("OnLeave", function() Refresh("normal") end)
    button:HookScript("OnMouseDown", function() Refresh("pressed") end)
    button:HookScript("OnMouseUp", function() Refresh("hovered") end)
    button:HookScript("OnShow", function() Refresh("normal") end)
end

local function StyleMapControls(border)
    StyleMapControl(border.CloseButton, "X", true)
    local toggle = border.MaximizeMinimizeFrame
    if toggle then
        StyleMapControl(toggle.MaximizeButton, "+")
        StyleMapControl(toggle.MinimizeButton, "-")
    end
end

local function AttachZoneDropdown(button, nav)
    if not button.listFunc or not button.MenuArrowButton
        or button.KamiMapZoneDropdown then
        return
    end

    local arrow = button.MenuArrowButton
    button.KamiMapZoneDropdown = Components:CreateDropdown(nav, {
        button = arrow,
        menuParent = UIParent,
        menuFrameStrata = "DIALOG",
        menuFrameLevel = nav:GetFrameLevel() + 100,
        closeWith = mapFrame,
        styleButton = false,
        metallicMenu = true,
        showArrow = false,
        rowHeight = 21,
        fontSize = 11,
        textColor = Palette.text,
        borderColor = Palette.windowBorder.neutral,
        minWidth = 145,
        getEntries = function()
            return button.listFunc and button:listFunc() or {}
        end,
        onSelect = function(entry)
            if not entry then return end
            if entry.func then
                entry.func(arrow, entry.id, nav)
            elseif entry.id and nav.GoToMap then
                nav:GoToMap(entry.id)
            end
        end,
    })

    local label = arrow:CreateFontString(nil, "OVERLAY")
    Styles:ApplyText(label, 11, Palette.gold)
    label:SetPoint("CENTER", arrow, "CENTER", -1, 0)
    label:SetText("v")
    arrow.KamiMapChevron = label

    -- Blizzard's arrow mouse scripts re-enable stock textures on
    -- hover. Run after those scripts and keep our flat skin visible.
    local function KeepArrowFlat()
        HideButtonArt(button)
    end
    arrow:HookScript("OnEnter", KeepArrowFlat)
    arrow:HookScript("OnLeave", KeepArrowFlat)
    arrow:HookScript("OnMouseDown", KeepArrowFlat)
    arrow:HookScript("OnMouseUp", KeepArrowFlat)
end

local function StyleNavigationButton(button, active, nav)
    if not button then return end

    if not button.KamiMapBreadcrumbStyled then
        button.KamiMapBreadcrumbStyled = true
        HideNavigationArtwork(button)
        HideButtonArt(button)

        CreateMetallicNavigationArt(button)

        if button.text then
            button.text:ClearAllPoints()
            button.text:SetPoint("LEFT", button, "LEFT", 10, 0)
            button.text:SetPoint("RIGHT", button, "RIGHT", -28, 0)
            button.text:SetJustifyH("LEFT")
            button.text:SetWordWrap(false)
        end

        AttachZoneDropdown(button, nav)
    end

    if button.text then
        Styles:ApplyText(
            button.text, 11, active and Palette.gold or Palette.text
        )
    end
    if button.KamiMapMetallicFrame then
        local r, g, b = Styles:GetColorChannels(
            active and Palette.gold or Palette.metallicTint.neutral
        )
        button.KamiMapMetallicFrame:SetVertexColor(r, g, b, 1)
    end

    -- A recycled native button may acquire dropdown entries later.
    AttachZoneDropdown(button, nav)
    local chevron = button.MenuArrowButton
        and button.MenuArrowButton.KamiMapChevron
    if chevron then
        Styles:SetTextColor(chevron, Palette.gold)
    end
end

local function StyleBreadcrumbs()
    if InCombatLockdown and InCombatLockdown() then
        UI:RunOutOfCombat("worldmap.breadcrumbs", StyleBreadcrumbs)
        return
    end
    local nav = mapFrame and mapFrame.NavBar
    if not nav then return end

    if not nav.KamiMapBreadcrumbStyled then
        nav.KamiMapBreadcrumbStyled = true
        HideNavigationArtwork(nav)
        HideNavigationArtwork(nav.overlay)
    end

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

    -- Blizzard offsets the "World" home button by -15 px so the
    -- original beveled breadcrumb textures overlap. Flat rectangular
    -- KamiUI buttons need a real gap instead. NavBar_CheckLength uses
    -- the *previous* button's xoffset when placing the next one.
    local gap = 3
    local spacingChanged = false
    for _, button in ipairs(buttons) do
        if button.xoffset ~= gap then
            button.xoffset = gap
            spacingChanged = true
        end
    end

    local overflow = nav.overflowButton
    if overflow and overflow.xoffset ~= gap then
        overflow.xoffset = gap
        spacingChanged = true
    end

    if spacingChanged and type(NavBar_CheckLength) == "function" then
        NavBar_CheckLength(nav)
    end

    for index, button in ipairs(buttons) do
        StyleNavigationButton(button, index == #buttons, nav)
    end

    -- Overflow remains Blizzard-controlled, so hidden ancestors can
    -- still be selected even when the map is very narrow.
    local overflow = nav.overflowButton
    if overflow and not overflow.KamiMapOverflowStyled then
        overflow.KamiMapOverflowStyled = true
        HideNavigationArtwork(overflow)
        HideButtonArt(overflow)
        CreateMetallicNavigationArt(overflow)
        local label = overflow:CreateFontString(nil, "OVERLAY")
        Styles:ApplyText(label, 11, Palette.gold)
        label:SetPoint("CENTER")
        label:SetText("...")
    end
end

local function SkinWorldMap()
    if InCombatLockdown and InCombatLockdown() then
        UI:RunOutOfCombat("worldmap.skin", SkinWorldMap)
        return
    end
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

        border.KamiMetallicFrame = Components:CreateNineSlice(border, {
            asset = Media.panelFrame,
            sliceSize = 12,
            layer = "OVERLAY",
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
            header:SetTitle(title:GetText() or WORLD_MAP)
            title:SetAlpha(0)
        end

        -- OpenMap/Blizzard change the native title when the map is
        -- maximized. Keep our header synchronized with that label.
        if hooksecurefunc and type(border.SetTitle) == "function" then
            hooksecurefunc(border, "SetTitle", function(_, text)
                header:SetTitle(text)
            end)
        end

        map:HookScript("OnShow", SkinWorldMap)
        if hooksecurefunc and type(border.SetBorder) == "function" then
            hooksecurefunc(border, "SetBorder", function()
                if not (InCombatLockdown and InCombatLockdown()) then
                    if border.NineSlice then border.NineSlice:SetAlpha(0) end
                    StyleMapControls(border)
                end
            end)
        end
    end

    StyleMapControls(border)
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
