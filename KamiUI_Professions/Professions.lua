local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components

local Module = UI:NewModule("Professions")

Module.name = "KamiUI_Professions"
Module.version = "0.1.0"

local CRAFTING_RANK_X = 110
local CRAFTING_RANK_Y = -38
local CRAFTING_LINK_GAP = 10

-- The crafting bar and the overview bars use different Blizzard anchors,
-- so keep their fill offsets separate.
local CRAFTING_FILL_X_OFFSET = -5
local CRAFTING_FILL_Y_OFFSET = 3
local OVERVIEW_FILL_X_OFFSET = -2
local OVERVIEW_FILL_Y_OFFSET = 3

local RECIPE_CATEGORY_INSET = 2
local RECIPE_ROW_INSET = 8

local function EnsureDatabase()
    KamiUIDB = KamiUIDB or {}
    KamiUIDB.professions = KamiUIDB.professions or {}

    return KamiUIDB.professions
end

local function SavePosition(frame)
    local frameX, frameY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()

    if not frameX or not frameY or not parentX or not parentY then
        return
    end

    EnsureDatabase().position = {
        x = frameX - parentX,
        y = frameY - parentY,
    }

    frame:ClearAllPoints()
    frame:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        EnsureDatabase().position.x,
        EnsureDatabase().position.y
    )
end

local function ApplySavedPosition(frame)
    local position = EnsureDatabase().position

    if not position then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        position.x or 0,
        position.y or 0
    )
end

local function StyleRankBar(
    bar,
    fillXOffset,
    fillYOffset,
    rankTextYOffset,
    rankFontSize
)
    if not bar then
        return
    end

    fillXOffset = fillXOffset or 0
    fillYOffset = fillYOffset or 0
    rankTextYOffset = rankTextYOffset or 0
    rankFontSize = rankFontSize or 9

    if bar.Background then
        bar.Background:ClearAllPoints()
        bar.Background:SetAllPoints(bar)
        Styles:SetColor(bar.Background, { 0, 0, 0, 0.62 })
    end

    if bar.Fill then
        if not bar.KamiOriginalFillAnchor then
            local point, relativeTo, relativePoint, x, y =
                bar.Fill:GetPoint(1)

            if point then
                bar.KamiOriginalFillAnchor = {
                    point = point,
                    relativeTo = relativeTo or bar,
                    relativePoint = relativePoint,
                    x = x or 0,
                    y = y or 0,
                }
            end
        end

        local anchor = bar.KamiOriginalFillAnchor

        if anchor then
            bar.Fill:ClearAllPoints()
            bar.Fill:SetPoint(
                anchor.point,
                anchor.relativeTo,
                anchor.relativePoint,
                anchor.x + fillXOffset,
                anchor.y + fillYOffset
            )
        end
    end

    Styles:HideRegion(bar.Border)
    Styles:HideRegion(bar.Flare)

    Styles:CreateBorder(bar, "KamiRankBorder")

    local rankText = bar.Rank and bar.Rank.Text

    if bar.Rank then
        bar.Rank:ClearAllPoints()
        bar.Rank:SetPoint("LEFT", bar, "LEFT", 0, -3)
        bar.Rank:SetPoint("RIGHT", bar, "RIGHT", 0, -3)
    end

    if rankText then
        rankText:ClearAllPoints()
        rankText:SetPoint(
            "CENTER",
            bar.Rank,
            "CENTER",
            0,
            rankTextYOffset
        )
        rankText:SetHeight(rankFontSize + 2)
        Styles:ApplyText(rankText, rankFontSize, Palette.text)
        rankText:Show()
    end
end

local function StyleCategoryRankBar(bar)
    if not bar then
        return
    end

    if bar.SetStatusBarTexture then
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    end

    if bar.SetStatusBarColor then
        bar:SetStatusBarColor(0.24, 0.42, 0.72, 0.55)
    end

    Styles:HideRegion(bar.BorderLeft)
    Styles:HideRegion(bar.BorderMid)
    Styles:HideRegion(bar.BorderRight)

    Styles:EnsureBackground(
        bar,
        "KamiCategoryRankBackground",
        Palette.panelStrong,
        "BACKGROUND",
        -7
    )
    Styles:CreateBorder(bar, "KamiCategoryRankBorder")

    if bar.Rank then
        Styles:ApplyText(bar.Rank, 8, Palette.text)
    end
end

local function StyleProfessionSpellButton(button)
    if not button then
        return
    end

    if button.IconTexture then
        button.IconTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    Styles:HideRegion(button.IconTextureOverlay)

    if not button.KamiIconBorder then
        local border = CreateFrame("Frame", nil, button)
        border:SetPoint("TOPLEFT", 1, -1)
        border:SetPoint("BOTTOMRIGHT", -1, 1)
        border:SetFrameLevel(button:GetFrameLevel() + 1)
        Styles:CreateBorder(border)
        button.KamiIconBorder = border
    end

    Styles:ApplyText(button.spellString, 9, Palette.text)
    Styles:ApplyText(button.subSpellString, 8, Palette.muted)
end

local function StyleProfessionCard(card)
    if not card then
        return
    end

    if card.Background then
        Styles:SetColor(card.Background, Palette.panel)
    else
        Styles:EnsureBackground(card, "KamiBackground", Palette.panel)
    end

    Styles:CreateBorder(card, "KamiCardBorder")

    Styles:ApplyText(card.ProfessionName, 10, Palette.gold)
    Styles:ApplyText(card.specialization, 8, Palette.muted)
    Styles:ApplyText(card.Rank, 8, Palette.muted)
    Styles:ApplyText(card.missingHeader, 10, Palette.gold)
    Styles:ApplyText(card.missingText, 8, Palette.muted)

    StyleRankBar(
        card.StatusBar,
        OVERVIEW_FILL_X_OFFSET,
        OVERVIEW_FILL_Y_OFFSET,
        2,
        10
    )

    if card.StatusBar then
        card.StatusBar:ClearAllPoints()

        if card.isPrimary then
            card.StatusBar:SetPoint(
                "RIGHT",
                card,
                "RIGHT",
                -41,
                2
            )
        else
            card.StatusBar:SetPoint(
                "TOP",
                card,
                "TOP",
                -1,
                -45
            )
        end
    end

    for _, button in ipairs(card.spellButtons or {}) do
        StyleProfessionSpellButton(button)
    end

    if card.UnlearnButton and card.UnlearnButton.Icon then
        card.UnlearnButton.Icon:SetAlpha(0.65)
    end
end

local function StyleBookPage(frame)
    local book = frame and frame.BookPage
    local content = book and book.ProfessionsContentFrame

    if not content then
        return
    end

    StyleProfessionCard(content.PrimaryProfession1)
    StyleProfessionCard(content.PrimaryProfession2)
    StyleProfessionCard(content.SecondaryProfession1)
    StyleProfessionCard(content.SecondaryProfession2)
    StyleProfessionCard(content.SecondaryProfession3)
end

local function GetHeaderText(row)
    if not row then
        return nil
    end

    if row.GetTitleRegion then
        return row:GetTitleRegion()
    end

    return row.ButtonText or row.Text or row.Label
end

local function HideNativeRegion(region)
    if not region then
        return
    end

    if region.SetColorTexture then
        pcall(
            region.SetColorTexture,
            region,
            0,
            0,
            0,
            0
        )
    end

    if region.SetAlpha then
        region:SetAlpha(0)
    end

    if region.Hide then
        region:Hide()
    end

    if region.HookScript and not region.KamiProfessionsHideHooked then
        region.KamiProfessionsHideHooked = true

        region:HookScript("OnShow", function(self)
            self:SetAlpha(0)
            self:Hide()
        end)
    end
end

local function HideButtonTextures(button)
    Components:ClearButtonArt(button)
end

local function HideFrameArt(frame)
    if not frame then
        return
    end

    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            HideNativeRegion(region)
        end
    end

    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            HideFrameArt(child)
        end
    end

    HideNativeRegion(frame)
end

local function IsKamiInputTexture(input, region)
    if region == input.KamiInputBackground then
        return true
    end

    for _, edge in ipairs(input.KamiInputBorder or {}) do
        if region == edge then
            return true
        end
    end

    return false
end

local function HideNativeInputTextures(input)
    if not input or not input.GetRegions then
        return
    end

    for _, region in ipairs({ input:GetRegions() }) do
        if region
            and region.IsObjectType
            and region:IsObjectType("Texture")
            and not IsKamiInputTexture(input, region)
        then
            HideNativeRegion(region)
        end
    end
end

local function HideTextureByAtlas(frame, atlasName)
    if not frame or not frame.GetRegions then
        return
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region
            and region.GetAtlas
            and region:GetAtlas() == atlasName
        then
            HideNativeRegion(region)
        end
    end
end

function Module:ApplyRecipeCategoryVisual(row)
    if not row then
        return
    end

    local background = row.KamiCategoryBackground

    if not background then
        background = row:CreateTexture(nil, "BACKGROUND", nil, -7)
        row.KamiCategoryBackground = background
    end

    background:ClearAllPoints()
    background:SetPoint(
        "TOPLEFT",
        row,
        "TOPLEFT",
        RECIPE_CATEGORY_INSET,
        0
    )
    background:SetPoint(
        "BOTTOMRIGHT",
        row,
        "BOTTOMRIGHT",
        -RECIPE_CATEGORY_INSET,
        0
    )
    Styles:SetColor(
        background,
        Palette.white,
        Styles.State.sectionAlpha
    )

    HideButtonTextures(row)

    HideNativeRegion(row.LeftPiece)
    HideNativeRegion(row.CenterPiece)
    HideNativeRegion(row.RightPiece)
    HideNativeRegion(row.CollapseIcon)
    HideNativeRegion(row.CollapseIconAlphaAdd)

    local collapse = row.GetCollapseButton
        and row:GetCollapseButton()
        or row.CollapseButton

    HideNativeRegion(collapse)

    if row.SetHighlightTexture and row.GetHighlightTexture then
        pcall(
            row.SetHighlightTexture,
            row,
            "Interface\\Buttons\\WHITE8X8"
        )
        row.KamiCategoryHighlight = row:GetHighlightTexture()
    end

    if not row.KamiCategoryHighlight then
        row.KamiCategoryHighlight =
            row:CreateTexture(nil, "HIGHLIGHT")
    end

    row.KamiCategoryHighlight:SetAlpha(1)
    row.KamiCategoryHighlight:ClearAllPoints()
    row.KamiCategoryHighlight:SetPoint(
        "TOPLEFT",
        row,
        "TOPLEFT",
        RECIPE_CATEGORY_INSET,
        0
    )
    row.KamiCategoryHighlight:SetPoint(
        "BOTTOMRIGHT",
        row,
        "BOTTOMRIGHT",
        -RECIPE_CATEGORY_INSET,
        0
    )
    Styles:SetColor(
        row.KamiCategoryHighlight,
        Palette.white,
        Styles.State.hoverAlpha
    )

    local text = GetHeaderText(row)

    if text then
        text:ClearAllPoints()
        text:SetPoint("LEFT", row, "LEFT", 6, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        text:SetJustifyH("LEFT")
        Styles:ApplyText(text, 9, Palette.gold)
        text:SetText(
            string.format(
                "%s %s",
                row.KamiCollapsed and "+" or "-",
                row.KamiCategoryName or ""
            )
        )
    end

    if row.RankBar then
        StyleCategoryRankBar(row.RankBar)
    end
end

function Module:StyleRecipeCategory(row, node)
    if not row or not node then
        return
    end

    local data = node:GetData()
    local categoryInfo = data and data.categoryInfo

    if not categoryInfo then
        return
    end

    row.KamiCategoryName = categoryInfo.name or ""
    row.KamiCollapsed = node:IsCollapsed()

    if not row.KamiHoverRestyleHooked then
        row.KamiHoverRestyleHooked = true

        row:HookScript("OnEnter", function(self)
            C_Timer.After(0, function()
                Module:ApplyRecipeCategoryVisual(self)
            end)
        end)

        row:HookScript("OnLeave", function(self)
            C_Timer.After(0, function()
                Module:ApplyRecipeCategoryVisual(self)
            end)
        end)
    end

    Module:ApplyRecipeCategoryVisual(row)
end

function Module:StyleRecipeRow(row, node)
    if not row then
        return
    end

    local data = node and node.GetData and node:GetData()
    local recipeInfo = data and data.recipeInfo
    local difficulty = recipeInfo and recipeInfo.relativeDifficulty
    local backgroundColor = Palette.difficulty.trivial
    local backgroundAlpha = 0.10

    if Enum
        and Enum.TradeskillRelativeDifficulty
        and difficulty
    then
        local difficulties = Enum.TradeskillRelativeDifficulty

        if difficulty == difficulties.Optimal then
            backgroundColor = Palette.difficulty.hard
            backgroundAlpha = 0.16
        elseif difficulty == difficulties.Medium then
            backgroundColor = Palette.difficulty.normal
            backgroundAlpha = 0.14
        elseif difficulty == difficulties.Easy then
            backgroundColor = Palette.difficulty.easy
            backgroundAlpha = 0.13
        end
    end

    local background = row.KamiDifficultyBackground

    if not background then
        background = row:CreateTexture(nil, "BACKGROUND", nil, -6)
        row.KamiDifficultyBackground = background
    end

    background:ClearAllPoints()
    background:SetPoint(
        "TOPLEFT",
        row,
        "TOPLEFT",
        RECIPE_ROW_INSET,
        0
    )
    background:SetPoint(
        "BOTTOMRIGHT",
        row,
        "BOTTOMRIGHT",
        -RECIPE_ROW_INSET,
        0
    )

    Styles:SetColor(background, backgroundColor, backgroundAlpha)

    if row.SkillUps then
        row.SkillUps:Hide()
    end

    if row.Label then
        row.Label:ClearAllPoints()
        row.Label:SetPoint("LEFT", row, "LEFT", 10, 0)
        row.Label:SetPoint("RIGHT", row, "RIGHT", -44, 0)
        row.Label:SetJustifyH("LEFT")
        row.Label:SetText(recipeInfo and recipeInfo.name or "")
        row.Label:Show()
        Styles:ApplyText(row.Label, 9)

        if row.GetLabelColor then
            local color = row:GetLabelColor()

            if color then
                row.Label:SetVertexColor(color:GetRGB())
            end
        end
    end

    if row.Count then
        row.Count:ClearAllPoints()
        row.Count:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.Count:SetJustifyH("RIGHT")
        row.Count:SetWidth(38)
        Styles:ApplyText(row.Count, 9, Palette.muted)
    end

    if row.SelectedOverlay then
        row.SelectedOverlay:ClearAllPoints()
        row.SelectedOverlay:SetPoint(
            "TOPLEFT",
            row,
            "TOPLEFT",
            RECIPE_ROW_INSET,
            0
        )
        row.SelectedOverlay:SetPoint(
            "BOTTOMRIGHT",
            row,
            "BOTTOMRIGHT",
            -RECIPE_ROW_INSET,
            0
        )
        row.SelectedOverlay:SetColorTexture(
            1,
            1,
            1,
            Styles.State.selectedAlpha
        )
    end

    if row.HighlightOverlay then
        row.HighlightOverlay:ClearAllPoints()
        row.HighlightOverlay:SetPoint(
            "TOPLEFT",
            row,
            "TOPLEFT",
            RECIPE_ROW_INSET,
            0
        )
        row.HighlightOverlay:SetPoint(
            "BOTTOMRIGHT",
            row,
            "BOTTOMRIGHT",
            -RECIPE_ROW_INSET,
            0
        )
        row.HighlightOverlay:SetColorTexture(
            1,
            1,
            1,
            Styles.State.hoverAlpha
        )
    end
end

local function StyleRecipeList(recipeList)
    if not recipeList then
        return
    end

    HideNativeRegion(recipeList.Background)
    HideNativeRegion(recipeList.BackgroundNineSlice)

    Styles:EnsureBackground(
        recipeList,
        "KamiRecipeListBackground",
        Palette.panel
    )
    Styles:CreateBorder(recipeList, "KamiRecipeListBorder")
    Components:StyleScrollBar(recipeList.ScrollBar)

    if recipeList.SearchBox then
        Components:StyleInput(recipeList.SearchBox, {
            backgroundColor = Palette.panelStrong,
        })

        Styles:ApplyText(
            recipeList.SearchBox.Instructions,
            9,
            Palette.muted
        )
    end

    if recipeList.FilterDropdown then
        Components:StyleButton(recipeList.FilterDropdown, {
            backgroundColor = Palette.panelStrong,
        })
    end

    Styles:ApplyText(recipeList.NoResultsText, 9, Palette.muted)
end

local function StyleOutputButton(button)
    if not button then
        return
    end

    Components:ClearButtonArt(button)

    for _, key in ipairs({
        "Background",
        "Border",
        "IconBorder",
        "IconOverlay",
        "IconOverlay2",
        "CountShadow",
        "SlotBackground",
    }) do
        HideNativeRegion(button[key])
    end

    local icon = button.Icon
        or button.icon
        or button.IconTexture

    if icon then
        if icon.RemoveMaskTexture then
            if button.IconMask then
                pcall(
                    icon.RemoveMaskTexture,
                    icon,
                    button.IconMask
                )
            end

            if button.CircleMask then
                pcall(
                    icon.RemoveMaskTexture,
                    icon,
                    button.CircleMask
                )
            end
        end

        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    Styles:EnsureBackground(
        button,
        "KamiOutputBackground",
        Palette.panelStrong,
        "BACKGROUND",
        -7
    )
    Styles:CreateBorder(button, "KamiOutputBorder")

    if not button.KamiOutputHighlight then
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        highlight:SetPoint(
            "BOTTOMRIGHT",
            button,
            "BOTTOMRIGHT",
            -1,
            1
        )
        Styles:SetColor(
            highlight,
            Palette.white,
            Styles.State.hoverAlpha
        )
        button.KamiOutputHighlight = highlight
    end
end

local function StyleSchematicForm(form)
    if not form then
        return
    end

    if form.NineSlice then
        form.NineSlice:ClearAllPoints()
    end

    HideFrameArt(form.NineSlice)
    HideTextureByAtlas(form, "common-insideframe")
    HideNativeRegion(form.Background)
    HideNativeRegion(form.MinimalBackground)
    HideNativeRegion(form.Bg)

    Styles:EnsureBackground(
        form,
        "KamiSchematicBackground",
        Palette.panel
    )
    Styles:CreateBorder(form, "KamiSchematicBorder")

    Styles:ApplyText(form.OutputText, 13, Palette.text)
    Styles:ApplyText(form.OutputSubText, 9, Palette.muted)
    Styles:ApplyText(form.Description, 9, Palette.text)
    Styles:ApplyText(form.RequiredTools, 8, Palette.muted)
    Styles:ApplyText(form.RecraftingRequiredTools, 8, Palette.muted)
    Styles:ApplyText(form.Cooldown, 8)
    Styles:ApplyText(form.MinimizedCooldown, 8)

    for _, container in ipairs({
        form.Reagents,
        form.OptionalReagents,
        form.FinishingReagents,
    }) do
        if container then
            Styles:ApplyText(
                container.Label,
                "sectionTitle",
                Palette.gold
            )
        end
    end

    StyleOutputButton(form.OutputIcon)

    Components:StyleCheckbox(form.TrackRecipeCheckbox, {
        textColor = Palette.muted,
    })
    Components:StyleCheckbox(form.AllocateBestQualityCheckbox, {
        textColor = Palette.muted,
    })
end

local function StyleQuantityInput(input)
    if not input then
        return
    end

    HideNativeInputTextures(input)

    Components:StyleInput(input, {
        backgroundColor = Palette.panelStrong,
    })

    HideNativeInputTextures(input)

    if input.DecrementButton then
        Components:StyleButton(input.DecrementButton, {
            text = "-",
            backgroundColor = Palette.panelStrong,
        })
    end

    if input.IncrementButton then
        Components:StyleButton(input.IncrementButton, {
            text = "+",
            backgroundColor = Palette.panelStrong,
        })
    end
end

local function StyleCraftingPage(frame)
    local page = frame and frame.CraftingPage

    if not page then
        return
    end

    HideTextureByAtlas(
        page,
        "Profession-Background-Template2"
    )

    StyleRecipeList(page.RecipeList)
    StyleSchematicForm(page.SchematicForm)

    Components:StyleButton(page.CreateButton, {
        backgroundColor = Palette.panelStrong,
    })
    Components:StyleButton(page.CreateAllButton, {
        backgroundColor = Palette.panelStrong,
    })
    Components:StyleButton(page.ViewGuildCraftersButton, {
        backgroundColor = Palette.panelStrong,
    })
    StyleQuantityInput(page.CreateMultipleInputBox)

    StyleRankBar(
        page.RankBar,
        CRAFTING_FILL_X_OFFSET,
        CRAFTING_FILL_Y_OFFSET,
        2,
        10
    )

    if page.RankBar then
        page.RankBar:ClearAllPoints()
        page.RankBar:SetPoint(
            "TOPLEFT",
            page,
            "TOPLEFT",
            CRAFTING_RANK_X,
            CRAFTING_RANK_Y
        )
    end

    if page.LinkButton and page.RankBar then
        page.LinkButton:ClearAllPoints()
        page.LinkButton:SetPoint(
            "LEFT",
            page.RankBar,
            "RIGHT",
            CRAFTING_LINK_GAP,
            -2
        )
    end

    if page.TutorialButton then
        page.TutorialButton:Hide()
    end
end

local function HideNativeProfessionTab(tab)
    if not tab then
        return
    end

    tab:SetAlpha(0)

    if tab.EnableMouse then
        tab:EnableMouse(false)
    end
end

local function CreateProfessionBottomTabs(frame)
    if frame.KamiProfessionTabs then
        return
    end

    frame.KamiProfessionTabs = {}

    for index = 1, 8 do
        local tab = CreateFrame("Button", nil, frame)
        tab:SetSize(76, 22)
        tab:SetFrameLevel(frame:GetFrameLevel() + 20)
        tab:SetNormalFontObject("GameFontNormalSmall")
        tab:SetHighlightFontObject("GameFontHighlightSmall")
        tab:SetPoint(
            "TOPLEFT",
            frame,
            "BOTTOMLEFT",
            20 + (index - 1) * 76,
            1
        )

        Components:StyleTab(tab, {
            orientation = "bottom",
            joinLeft = index > 1,
        })

        tab:SetScript("OnClick", function(self)
            local source = self.sourceTab

            if not source then
                return
            end

            if self.isOverview then
                if frame.SelectBookPage then
                    frame:SelectBookPage()
                end
                return
            end

            if frame.RightTabSelected then
                frame:RightTabSelected(source)
            end

            local alreadySelected = Professions
                and Professions.IsSelectedProfession
                and Professions.IsSelectedProfession(source.skillLine)

            if alreadySelected
                and EventRegistry
                and EventRegistry.TriggerEvent
            then
                EventRegistry:TriggerEvent(
                    "Professions.ShowSelectedCraftingPage"
                )
            elseif source.CastProfessionSpell then
                source:CastProfessionSpell()
            end
        end)

        tab:Hide()
        frame.KamiProfessionTabs[index] = tab
    end
end

local function StyleRightTabs(frame)
    if not frame then
        return
    end

    CreateProfessionBottomTabs(frame)
    HideNativeProfessionTab(frame.ProfessionsOverviewTab)

    local sources = { frame.ProfessionsOverviewTab }

    for _, source in ipairs(frame.rightProfessionTabs or {}) do
        HideNativeProfessionTab(source)
        sources[#sources + 1] = source
    end

    for index, tab in ipairs(frame.KamiProfessionTabs or {}) do
        local source = sources[index]
        local visible = source
            and (index == 1 or source:IsShown())

        if visible then
            tab.sourceTab = source
            tab.isOverview = index == 1
            tab:SetText(
                index == 1
                    and "Professions"
                    or source.tooltipText
                    or "Profession"
            )

            local active

            if index == 1 then
                active = frame.BookPage
                    and frame.BookPage:IsShown()
            else
                active = not (
                    frame.BookPage
                    and frame.BookPage:IsShown()
                ) and frame.selectedSkillLine == source.skillLine
            end

            Components:SetTabState(tab, active == true, true)
            tab:Show()
        else
            tab.sourceTab = nil
            tab:Hide()
        end
    end
end

local function StyleCloseButton(button)
    if not button then
        return
    end

    HideButtonTextures(button)
    button:SetSize(22, 22)
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", button:GetParent(), "TOPRIGHT", -3, -3)

    if not button.KamiText then
        local text = button:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormal"
        )
        text:SetPoint("CENTER", 0, 0)
        text:SetText("x")
        button.KamiText = text
    end

    Styles:ApplyText(button.KamiText, 12, Palette.text)
end

local function ConfigureFrameDragging(frame)
    if not frame or frame.KamiDraggingConfigured then
        return
    end

    frame.KamiDraggingConfigured = true
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local dragHandle = frame.TitleContainer or frame
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")

    dragHandle:HookScript("OnDragStart", function()
        frame:StartMoving()
    end)

    dragHandle:HookScript("OnDragStop", function()
        frame:StopMovingOrSizing()

        if frame.SetUserPlaced then
            frame:SetUserPlaced(true)
        end

        SavePosition(frame)
    end)
end

local function StyleFrameChrome(frame)
    if not frame then
        return
    end

    ConfigureFrameDragging(frame)

    Styles:EnsureBackground(
        frame,
        "KamiBackground",
        Palette.background
    )
    Styles:CreateBorder(frame, "KamiFrameBorder")

    if not frame.KamiHeader then
        local header = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        header:SetHeight(32)
        Styles:SetColor(header, Palette.header)
        frame.KamiHeader = header
    end

    Styles:HideRegion(frame.Bg)
    Styles:HideRegion(frame.TopTileStreaks)

    if frame.NineSlice then
        frame.NineSlice:Hide()
    end

    if frame.PortraitContainer then
        frame.PortraitContainer:Hide()
    end

    local title = frame.TitleContainer
        and frame.TitleContainer.TitleText

    if title then
        title:ClearAllPoints()
        title:SetPoint("TOP", frame, "TOP", 0, -8)
        Styles:ApplyText(title, "windowTitle")
    end

    StyleCloseButton(frame.CloseButton)
end

function Module:RefreshStyle()
    local frame = _G.ProfessionsFrame

    if not frame then
        return
    end

    StyleFrameChrome(frame)
    StyleBookPage(frame)
    StyleCraftingPage(frame)
    StyleRightTabs(frame)
end

function Module:Attach()
    local frame = _G.ProfessionsFrame

    if not frame then
        return
    end

    if not self.recipeHooksInstalled then
        if ProfessionsRecipeListCategoryMixin
            and ProfessionsRecipeListCategoryMixin.Init
        then
            hooksecurefunc(
                ProfessionsRecipeListCategoryMixin,
                "Init",
                function(row, node)
                    Module:StyleRecipeCategory(row, node)
                end
            )
        end

        if ProfessionsRecipeListRecipeMixin
            and ProfessionsRecipeListRecipeMixin.Init
        then
            hooksecurefunc(
                ProfessionsRecipeListRecipeMixin,
                "Init",
                function(row, node)
                    Module:StyleRecipeRow(row, node)
                end
            )
        end

        if ProfessionsRecipeListCategoryMixin then
            for _, method in ipairs({
                "OnEnter",
                "OnLeave",
                "SetCollapseState",
                "UpdateCollapsedState",
            }) do
                if ProfessionsRecipeListCategoryMixin[method] then
                    hooksecurefunc(
                        ProfessionsRecipeListCategoryMixin,
                        method,
                        function(row, collapsed)
                            if type(collapsed) == "boolean" then
                                row.KamiCollapsed = collapsed
                            end

                            C_Timer.After(0, function()
                                Module:ApplyRecipeCategoryVisual(row)
                            end)
                        end
                    )
                end
            end
        end

        self.recipeHooksInstalled = true
    end

    if not self.craftingPageHooksInstalled
        and ProfessionsCraftingPageMixin
    then
        self.craftingPageHooksInstalled = true

        for _, method in ipairs({
            "Refresh",
            "OnShow",
            "ValidateControls",
        }) do
            if ProfessionsCraftingPageMixin[method] then
                hooksecurefunc(
                    ProfessionsCraftingPageMixin,
                    method,
                    function()
                        C_Timer.After(0, function()
                            local professionsFrame =
                                _G.ProfessionsFrame

                            if professionsFrame then
                                StyleCraftingPage(
                                    professionsFrame
                                )
                            end
                        end)
                    end
                )
            end
        end
    end

    if not self.schematicHooksInstalled
        and ProfessionsRecipeSchematicFormMixin
    then
        self.schematicHooksInstalled = true

        for _, method in ipairs({
            "Init",
            "Refresh",
            "Update",
            "OnShow",
        }) do
            if ProfessionsRecipeSchematicFormMixin[method] then
                hooksecurefunc(
                    ProfessionsRecipeSchematicFormMixin,
                    method,
                    function(form)
                        C_Timer.After(0, function()
                            StyleSchematicForm(form)
                        end)
                    end
                )
            end
        end
    end

    if not self.frameHooksInstalled then
        self.frameHooksInstalled = true

        frame:HookScript("OnShow", function()
            C_Timer.After(0, function()
                ApplySavedPosition(frame)
                Module:RefreshStyle()
            end)
        end)

        if frame.Refresh then
            hooksecurefunc(frame, "Refresh", function()
                C_Timer.After(0, function()
                    Module:RefreshStyle()
                end)
            end)
        end

        if frame.RefreshRightTabs then
            hooksecurefunc(frame, "RefreshRightTabs", function()
                C_Timer.After(0, function()
                    StyleRightTabs(frame)
                end)
            end)
        end

        if frame.RightTabSelected then
            hooksecurefunc(frame, "RightTabSelected", function()
                C_Timer.After(0, function()
                    StyleRightTabs(frame)
                end)
            end)
        end

        if frame.SelectBookPage then
            hooksecurefunc(frame, "SelectBookPage", function()
                C_Timer.After(0, function()
                    Module:RefreshStyle()
                end)
            end)
        end

        local book = frame.BookPage

        if book and book.Update then
            hooksecurefunc(book, "Update", function()
                C_Timer.After(0, function()
                    StyleBookPage(frame)
                end)
            end)
        end
    end

    ApplySavedPosition(frame)
    self:RefreshStyle()
end

function Module:Initialize()
    if _G.ProfessionsFrame then
        self:Attach()
    end

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_Professions" then
            C_Timer.After(0, function()
                Module:Attach()
            end)
        end
    end)

    for _, event in ipairs({
        "TRADE_SKILL_LIST_UPDATE",
        "SKILL_LINES_CHANGED",
        "SPELLS_CHANGED",
    }) do
        UI:RegisterEvent(event, function()
            local frame = _G.ProfessionsFrame

            if frame and frame:IsShown() then
                C_Timer.After(0, function()
                    Module:RefreshStyle()
                end)
            end
        end)
    end
end

Module:Initialize()
