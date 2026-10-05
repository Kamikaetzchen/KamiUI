local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components

local Module = UI:NewModule("Professions", "KamiUI_Professions")

Module.version = "0.2.0"

local RECIPE_CACHE_VERSION = 3

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

local function GetDatabase()
    return UI:GetDatabase("professions")
end

local function GetCharactersModule()
    local characters = UI:GetModule("Characters")

    if characters
        and characters.GetCurrentCharacterKey
        and characters.GetCharacter
        and characters.GetSortedCharacters
    then
        return characters
    end
end

local function GetCurrentCharacterData()
    local characters = GetCharactersModule()

    if not characters then
        return nil, nil
    end

    if characters.UpdateCurrentCharacter then
        characters:UpdateCurrentCharacter()
    end

    local key = characters:GetCurrentCharacterKey()
    return key, characters:GetCharacter(key)
end

local function GetViewedCharacter()
    local characters = GetCharactersModule()

    if not characters then
        return nil, nil, true
    end

    local currentKey = characters:GetCurrentCharacterKey()
    local key = Module.viewCharacterKey or currentKey

    return key, characters:GetCharacter(key), key == currentKey
end

local function EnsureCharacterProfessions(character)
    if not character then
        return nil
    end

    character.professions = character.professions or {}
    return character.professions
end

function Module:SnapshotProfessionSkills()
    local _, character = GetCurrentCharacterData()
    local professions = EnsureCharacterProfessions(character)

    if not professions
        or not GetProfessions
        or not GetProfessionInfo
    then
        return
    end

    local professionIndexes = { GetProfessions() }

    for slot = 1, 5 do
        local professionIndex = professionIndexes[slot]

        if professionIndex then
            local name,
                icon,
                rank,
                maxRank,
                _numSpells,
                _spellOffset,
                skillLineID,
                rankModifier,
                _specializationIndex,
                _specializationOffset,
                skillLineName =
                GetProfessionInfo(professionIndex)

            if skillLineID then
                local saved = professions[skillLineID] or {}

                saved.professionID = skillLineID
                saved.professionName =
                    name or skillLineName or saved.professionName
                saved.icon = icon or saved.icon
                saved.skillLevel = rank or saved.skillLevel or 0
                saved.maxSkillLevel =
                    maxRank or saved.maxSkillLevel or 0
                saved.skillModifier =
                    rankModifier or saved.skillModifier or 0
                if saved.recipeCacheVersion ~= RECIPE_CACHE_VERSION then
                    saved.recipes = {}
                    saved.recipesCached = false
                    saved.recipeCacheVersion = nil
                else
                    saved.recipes = saved.recipes or {}
                end

                saved.updated = time and time() or 0

                professions[skillLineID] = saved
            end
        end
    end
end

function Module:SnapshotCurrentProfession()
    self:SnapshotProfessionSkills()

    if not C_TradeSkillUI
        or not C_TradeSkillUI.GetBaseProfessionInfo
        or not C_TradeSkillUI.GetChildProfessionInfo
        or not C_TradeSkillUI.GetFilteredRecipeIDs
        or not C_TradeSkillUI.GetRecipeInfo
    then
        return
    end

    local _, character = GetCurrentCharacterData()
    local professions = EnsureCharacterProfessions(character)

    if not professions then
        return
    end

    local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    local childInfo = C_TradeSkillUI.GetChildProfessionInfo()

    if not baseInfo
        or not baseInfo.professionID
        or baseInfo.professionID == 0
    then
        return
    end

    local professionInfo = childInfo
    if not professionInfo
        or not professionInfo.professionID
        or professionInfo.professionID == 0
    then
        professionInfo = baseInfo
    end

    local professionID = professionInfo.professionID
    local saved = professions[professionID] or {}

    saved.professionID = professionID
    saved.parentProfessionID =
        professionInfo.parentProfessionID
        or (
            baseInfo.professionID ~= professionID
            and baseInfo.professionID
            or nil
        )
    saved.professionName =
        professionInfo.professionName
        or baseInfo.professionName
        or saved.professionName
    saved.skillLevel =
        professionInfo.skillLevel or saved.skillLevel or 0
    saved.maxSkillLevel =
        professionInfo.maxSkillLevel or saved.maxSkillLevel or 0
    saved.skillModifier =
        professionInfo.skillModifier or saved.skillModifier or 0
    saved.updated = time and time() or 0

    local ok, filteredRecipeIDs = pcall(
        C_TradeSkillUI.GetFilteredRecipeIDs
    )

    if not ok or type(filteredRecipeIDs) ~= "table" then
        professions[professionID] = saved
        return
    end

    local discoveredRecipes = {}

    for _, recipeID in ipairs(filteredRecipeIDs) do
        local belongsToSkillLine = true

        if C_TradeSkillUI.IsRecipeInSkillLine then
            belongsToSkillLine =
                C_TradeSkillUI.IsRecipeInSkillLine(
                    recipeID,
                    professionID
                )
        end

        if belongsToSkillLine then
            local recipeInfo =
                C_TradeSkillUI.GetRecipeInfo(recipeID)

            if recipeInfo
                and Professions
                and Professions.GetFirstRecipe
            then
                recipeInfo =
                    Professions.GetFirstRecipe(recipeInfo)
            end

            if recipeInfo and recipeInfo.learned then
                local learnedRecipeID =
                    recipeInfo.recipeID or recipeID

                discoveredRecipes[learnedRecipeID] = {
                    name = recipeInfo.name,
                    icon = recipeInfo.icon,
                }
            end
        end
    end

    local frame = _G.ProfessionsFrame
    local recipeList = frame
        and frame.CraftingPage
        and frame.CraftingPage.RecipeList
    local searchBox = recipeList and recipeList.SearchBox
    local searching =
        searchBox
        and searchBox.HasText
        and searchBox:HasText()
        or false

    local function GetBooleanResult(func)
        if type(func) ~= "function" then
            return nil
        end

        local okResult, result = pcall(func)

        if not okResult then
            return nil
        end

        return result == true
    end

    -- We only cache learned recipes, so Blizzard hiding unlearned
    -- recipes is not a reason to reject an otherwise complete scan.
    -- Professions.IsUsingDefaultFilters() requires both learned and
    -- unlearned recipes to be visible, which is too strict for Forever.
    local learnedRecipesVisible =
        GetBooleanResult(C_TradeSkillUI.GetShowLearned)
    local makeableOnly =
        GetBooleanResult(C_TradeSkillUI.GetOnlyShowMakeableRecipes)
    local skillUpOnly =
        GetBooleanResult(C_TradeSkillUI.GetOnlyShowSkillUpRecipes)
    local firstCraftOnly =
        GetBooleanResult(C_TradeSkillUI.GetOnlyShowFirstCraftRecipes)
    local inventorySlotsFiltered =
        GetBooleanResult(C_TradeSkillUI.AreAnyInventorySlotsFiltered)
    local categoriesFiltered =
        GetBooleanResult(C_TradeSkillUI.AnyRecipeCategoriesFiltered)
    local sourcesUnfiltered =
        Professions
        and GetBooleanResult(Professions.AreAllSourcesUnfiltered)
        or nil

    local completeSnapshot =
        not searching
        and learnedRecipesVisible == true
        and makeableOnly == false
        and skillUpOnly == false
        and firstCraftOnly == false
        and inventorySlotsFiltered == false
        and categoriesFiltered == false
        and sourcesUnfiltered == true

    if completeSnapshot then
        saved.recipes = discoveredRecipes
        saved.recipesCached = true
        saved.recipeCacheVersion = RECIPE_CACHE_VERSION
    else
        saved.recipes = saved.recipes or {}

        for recipeID, recipe in pairs(discoveredRecipes) do
            saved.recipes[recipeID] = recipe
        end

        if saved.recipeCacheVersion ~= RECIPE_CACHE_VERSION then
            saved.recipesCached = false
        end
    end

    professions[professionID] = saved
end

local function SavePosition(frame)
    UI:SaveFramePosition(
        frame,
        GetDatabase(),
        "position",
        nil,
        true
    )
end

local function ApplySavedPosition(frame)
    UI:ApplyFramePosition(
        frame,
        GetDatabase(),
        "position",
        nil,
        nil,
        nil,
        true
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

    Styles:HideRegion(card.Background)
    Styles:EnsureBackground(
        card,
        "KamiBackground",
        Palette.panel
    )

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
    local backgroundAlpha = 0.30

    if Enum
        and Enum.TradeskillRelativeDifficulty
        and difficulty
    then
        local difficulties = Enum.TradeskillRelativeDifficulty

        if difficulty == difficulties.Optimal then
            backgroundColor = Palette.difficulty.hard
            backgroundAlpha = 0.36
        elseif difficulty == difficulties.Medium then
            backgroundColor = Palette.difficulty.normal
            backgroundAlpha = 0.34
        elseif difficulty == difficulties.Easy then
            backgroundColor = Palette.difficulty.easy
            backgroundAlpha = 0.33
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

local function StyleVisibleRecipeRows(recipeList)
    local scrollBox = recipeList and recipeList.ScrollBox

    if not scrollBox or not scrollBox.ForEachFrame then
        return
    end

    scrollBox:ForEachFrame(function(row, node)
        local data = node and node.GetData and node:GetData()

        if data and data.categoryInfo then
            Module:StyleRecipeCategory(row, node)
        elseif data and data.recipeInfo then
            Module:StyleRecipeRow(row, node)
        end
    end)
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
        { 0, 0, 0, 0.44 }
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
    StyleVisibleRecipeRows(recipeList)
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
        { 0, 0, 0, 0.44 }
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



local function HasCompleteRecipeCache(profession)
    return profession
        and profession.recipesCached == true
        and profession.recipeCacheVersion == RECIPE_CACHE_VERSION
end

local function FindCachedProfession(character, professionInfo)
    if not character or not professionInfo then
        return nil
    end

    local professions = character.professions or {}
    local exact = professions[professionInfo.professionID]

    if exact then
        return exact
    end

    local parentProfessionID = professionInfo.parentProfessionID
    if not parentProfessionID then
        return nil
    end

    local parent = professions[parentProfessionID]
    if parent then
        return parent
    end

    local bestMatch

    for _, profession in pairs(professions) do
        if profession.parentProfessionID == parentProfessionID then
            if not bestMatch
                or (profession.skillLevel or 0)
                    > (bestMatch.skillLevel or 0)
            then
                bestMatch = profession
            end
        end
    end

    return bestMatch
end

local function NormalizeRecipeName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")

    return string.lower(name)
end

local function GetRecipeNameFromItem(itemID)
    if not itemID
        or not C_Item
        or not C_Item.GetItemNameByID
    then
        return nil
    end

    local itemName = C_Item.GetItemNameByID(itemID)

    if not itemName then
        return nil
    end

    local recipeName = string.match(
        itemName,
        "^[^:]+:%s*(.+)$"
    )

    return recipeName
end

local function IsRecipeLearningItem(itemID)
    if not itemID
        or not TooltipUtil
        or not TooltipUtil.FindLinesFromGetter
        or not Enum.TooltipDataLineType
        or not Enum.TooltipDataLineType.ItemSpellTriggerLearn
    then
        return false
    end

    local lines = TooltipUtil.FindLinesFromGetter(
        { Enum.TooltipDataLineType.ItemSpellTriggerLearn },
        "GetItemByID",
        itemID
    )

    return lines and #lines > 0 or false
end

local function GetRecipeItemInfo(itemID)
    if not itemID
        or not IsRecipeLearningItem(itemID)
    then
        return nil
    end

    return GetRecipeNameFromItem(itemID)
end

local function GetRecipeRequirementInfo(itemID)
    if not TooltipUtil
        or not TooltipUtil.FindLinesFromGetter
        or not Enum.TooltipDataLineType
        or not Enum.TooltipDataUsageRequirementType
    then
        return nil
    end

    local lines = TooltipUtil.FindLinesFromGetter(
        { Enum.TooltipDataLineType.UsageRequirement },
        "GetItemByID",
        itemID
    )

    for _, line in ipairs(lines or {}) do
        if line.requirementType
                == Enum.TooltipDataUsageRequirementType.Skill
            and line.leftText
        then
            local required = string.match(
                line.leftText,
                "(%d+)%D*$"
            )

            return required and tonumber(required) or nil,
                line.leftText
        end
    end
end

local function FindCachedProfessionByRequirement(
    character,
    requirementText
)
    if not character or type(requirementText) ~= "string" then
        return nil
    end

    local requirement =
        string.lower(requirementText)

    for _, profession in pairs(character.professions or {}) do
        local professionName = profession.professionName

        if professionName
            and string.find(
                requirement,
                string.lower(professionName),
                1,
                true
            )
        then
            return profession
        end
    end
end

local function FindCachedRecipeByName(profession, recipeName)
    local normalizedName = NormalizeRecipeName(recipeName)

    if not profession or not normalizedName then
        return nil
    end

    for _, recipe in pairs(profession.recipes or {}) do
        if type(recipe) == "table"
            and NormalizeRecipeName(recipe.name)
                == normalizedName
        then
            return recipe
        end
    end
end

local function JoinCharacterNames(entries)
    local names = {}

    for _, entry in ipairs(entries) do
        names[#names + 1] = entry
    end

    return table.concat(names, ", ")
end

function Module:AddRecipeCharacterTooltip(tooltip, tooltipData)
    local itemID = tooltipData and tooltipData.id

    if not itemID and tooltip and tooltip.GetItem then
        local _, itemLink = tooltip:GetItem()

        if itemLink then
            itemID = C_Item.GetItemInfoInstant(itemLink)
        end
    end

    local recipeName = GetRecipeItemInfo(itemID)

    if not recipeName then
        return
    end

    local characters = GetCharactersModule()
    if not characters then
        return
    end

    local requiredSkill, requirementText =
        GetRecipeRequirementInfo(itemID)
    local known = {}
    local canLearn = {}
    local needsSkill = {}

    for _, entry in ipairs(characters:GetSortedCharacters()) do
        local character = entry.character
        local profession

        if requirementText then
            profession =
                FindCachedProfessionByRequirement(
                    character,
                    requirementText
                )
        end

        if HasCompleteRecipeCache(profession) then
            local name = character.name or "Unknown"
            local skill = profession.skillLevel or 0
            local nameWithSkill = string.format(
                "%s (%d)",
                name,
                skill
            )
            local recipe =
                FindCachedRecipeByName(
                    profession,
                    recipeName
                )

            if recipe then
                known[#known + 1] = nameWithSkill
            else
                if requiredSkill and skill < requiredSkill then
                    needsSkill[#needsSkill + 1] = nameWithSkill
                else
                    canLearn[#canLearn + 1] = nameWithSkill
                end
            end
        end
    end

    if #known == 0
        and #canLearn == 0
        and #needsSkill == 0
    then
        return
    end

    tooltip:AddLine(" ")

    if #known > 0 then
        tooltip:AddLine(
            "Known: " .. JoinCharacterNames(known),
            0.35,
            0.90,
            0.45,
            true
        )
    end

    if #canLearn > 0 then
        tooltip:AddLine(
            "Can learn: " .. JoinCharacterNames(canLearn),
            1.00,
            0.82,
            0.00,
            true
        )
    end

    if #needsSkill > 0 then
        tooltip:AddLine(
            "Higher skill: " .. JoinCharacterNames(needsSkill),
            1.00,
            0.20,
            0.20,
            true
        )
    end
end

function Module:InstallRecipeTooltipHook()
    if self.recipeTooltipHookInstalled
        or not TooltipDataProcessor
        or not TooltipDataProcessor.AddTooltipPostCall
        or not Enum.TooltipDataType
    then
        return
    end

    self.recipeTooltipHookInstalled = true

    TooltipDataProcessor.AddTooltipPostCall(
        Enum.TooltipDataType.Item,
        function(tooltip, tooltipData)
            Module:AddRecipeCharacterTooltip(
                tooltip,
                tooltipData
            )
        end
    )
end

local function CreateCachedProfessionRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(20)

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0)
    row.background = background

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.icon = icon

    local text = row:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    row.text = text

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.05)
    row.highlight = highlight

    return row
end

local function GetCachedProfessions(character)
    local result = {}

    for _, profession in pairs(
        character and character.professions or {}
    ) do
        if profession.professionName then
            result[#result + 1] = profession
        end
    end

    table.sort(result, function(left, right)
        local leftName = left.professionName or ""
        local rightName = right.professionName or ""

        if leftName == rightName then
            return (left.professionID or 0)
                < (right.professionID or 0)
        end

        return leftName < rightName
    end)

    return result
end

local function GetCachedRecipes(profession)
    local result = {}

    for recipeID, recipe in pairs(profession.recipes or {}) do
        result[#result + 1] = {
            recipeID = recipeID,
            name = type(recipe) == "table"
                and recipe.name
                or nil,
            icon = type(recipe) == "table"
                and recipe.icon
                or nil,
        }
    end

    table.sort(result, function(left, right)
        return (left.name or tostring(left.recipeID))
            < (right.name or tostring(right.recipeID))
    end)

    return result
end

local function RebuildCachedProfessionPane(frame)
    local pane = frame.KamiCachedProfessionPane

    if not pane then
        return
    end

    pane.expandedProfessions =
        pane.expandedProfessions or {}

    local _, character = GetViewedCharacter()

    pane.title:SetText(
        (character and character.name or "Unknown")
        .. " - Professions"
    )

    for _, row in ipairs(pane.rows) do
        row:Hide()
        row:SetScript("OnClick", nil)
        row:EnableMouse(false)
    end

    local professions = GetCachedProfessions(character)
    local rowIndex = 0
    local y = 0

    local function AcquireRow()
        rowIndex = rowIndex + 1

        local row = pane.rows[rowIndex]
        if not row then
            row = CreateCachedProfessionRow(pane.content)
            pane.rows[rowIndex] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", pane.content, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", pane.content, "TOPRIGHT", 0, -y)
        row:SetScript("OnClick", nil)
        row:EnableMouse(false)
        row:Show()

        return row
    end

    if #professions == 0 then
        local row = AcquireRow()

        row:SetHeight(30)
        row.icon:Hide()
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.text:SetText(
            "No cached profession data. Open a profession on "
            .. "this character once."
        )
        Styles:ApplyText(row.text, 10, Palette.muted)
        y = y + 30
    else
        for _, profession in ipairs(professions) do
            local recipes = GetCachedRecipes(profession)
            local professionKey =
                profession.professionID
                or profession.professionName
            local recipesCached =
                HasCompleteRecipeCache(profession)
            local canExpand =
                recipesCached and #recipes > 0
            local expanded =
                canExpand
                and pane.expandedProfessions[professionKey] == true
            local header = AcquireRow()

            header:SetHeight(24)
            header.icon:Hide()
            header.text:ClearAllPoints()
            header.text:SetPoint("LEFT", header, "LEFT", 8, 0)
            header.text:SetPoint("RIGHT", header, "RIGHT", -8, 0)

            local label = profession.professionName or "Profession"
            local suffix

            if recipesCached then
                suffix = string.format(
                    "%d recipes",
                    #recipes
                )
            else
                suffix = "recipes not cached"
            end

            local prefix = ""
            if canExpand then
                prefix = expanded and "- " or "+ "
            end

            label = string.format(
                "%s%s  %d/%d  (%s)",
                prefix,
                label,
                profession.skillLevel or 0,
                profession.maxSkillLevel or 0,
                suffix
            )

            header.text:SetText(label)
            Styles:ApplyText(header.text, 10, Palette.gold)
            header.background:SetColorTexture(
                0.08,
                0.08,
                0.10,
                0.92
            )

            if canExpand then
                header:EnableMouse(true)
                header:SetScript("OnClick", function()
                    pane.expandedProfessions[professionKey] =
                        not pane.expandedProfessions[professionKey]
                    RebuildCachedProfessionPane(frame)
                end)
            end

            y = y + 24

            if expanded then
                for _, recipe in ipairs(recipes) do
                    local row = AcquireRow()

                    row:SetHeight(19)
                    row.background:SetColorTexture(0, 0, 0, 0)

                    if recipe.icon and recipe.icon ~= 0 then
                        row.icon:SetTexture(recipe.icon)
                        row.icon:Show()
                    else
                        row.icon:SetTexture(nil)
                        row.icon:Hide()
                    end

                    row.text:ClearAllPoints()
                    if row.icon:IsShown() then
                        row.text:SetPoint(
                            "LEFT",
                            row.icon,
                            "RIGHT",
                            6,
                            0
                        )
                    else
                        row.text:SetPoint(
                            "LEFT",
                            row,
                            "LEFT",
                            28,
                            0
                        )
                    end

                    row.text:SetPoint(
                        "RIGHT",
                        row,
                        "RIGHT",
                        -8,
                        0
                    )
                    row.text:SetText(
                        recipe.name
                        or ("Recipe " .. recipe.recipeID)
                    )
                    Styles:ApplyText(
                        row.text,
                        9,
                        Palette.text
                    )

                    y = y + 19
                end
            end

            y = y + 5
        end
    end

    for index = rowIndex + 1, #pane.rows do
        pane.rows[index]:Hide()
    end

    pane.content:SetWidth(math.max(1, pane.scroll:GetWidth()))
    pane.content:SetHeight(math.max(y, pane.scroll:GetHeight()))
    pane.scroll:SetVerticalScroll(0)
end

function Module:UpdateCharacterView(frame)
    frame = frame or _G.ProfessionsFrame

    if not frame or not frame.KamiCachedProfessionPane then
        return
    end

    local _, _, isCurrent = GetViewedCharacter()

    if isCurrent then
        frame.KamiCachedProfessionPane:Hide()
        StyleRightTabs(frame)
        return
    end

    for _, tab in ipairs(frame.KamiProfessionTabs or {}) do
        tab:Hide()
    end

    RebuildCachedProfessionPane(frame)
    frame.KamiCachedProfessionPane:Show()
end

function Module:SetViewedCharacter(key)
    local characters = GetCharactersModule()

    if not characters then
        return
    end

    local currentKey = characters:GetCurrentCharacterKey()

    self.viewCharacterKey =
        key == currentKey and nil or key

    local frame = _G.ProfessionsFrame
    if frame and frame.KamiCharacterMenu then
        frame.KamiCharacterMenu:Hide()
    end

    self:UpdateCharacterView(frame)
end

local function CreateCharacterBrowser(frame)
    if frame.KamiCharacterButton then
        return
    end

    local characterButton = CreateFrame("Button", nil, frame)
    characterButton:SetSize(22, 22)
    characterButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    characterButton:SetFrameLevel(frame:GetFrameLevel() + 30)

    local icon = characterButton:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    characterButton.icon = icon
    frame.KamiCharacterButton = characterButton

    local menu = Components:CreatePopupMenu(
        frame,
        characterButton,
        {
            x = -2,
            y = -2,
            width = 210,
            frameStrata = "TOOLTIP",
            frameLevel = 200,
            backgroundColor = { 0, 0, 0, 0.96 },
            borderColor = Palette.border,
            fontSize = 10,
        }
    )
    frame.KamiCharacterMenu = menu

    local pane = CreateFrame(
        "Frame",
        nil,
        frame,
        "BackdropTemplate"
    )
    pane:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -33)
    pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    pane:SetFrameStrata("DIALOG")
    pane:SetFrameLevel(100)
    pane:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    pane:SetBackdropColor(0.015, 0.018, 0.025, 1.00)
    pane:EnableMouse(true)
    pane:Hide()
    frame.KamiCachedProfessionPane = pane

    local title = pane:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    title:SetPoint("TOPLEFT", pane, "TOPLEFT", 10, -8)
    title:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -10, -8)
    title:SetJustifyH("LEFT")
    Styles:ApplyText(title, 11, Palette.text)
    pane.title = title

    local subtitle = pane:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetText("Cached character data")
    Styles:ApplyText(subtitle, 9, Palette.muted)

    local scroll = CreateFrame("ScrollFrame", nil, pane)
    scroll:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -10, 8)
    scroll:EnableMouseWheel(true)
    pane.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    pane.content = content
    pane.rows = {}

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(
            0,
            content:GetHeight() - self:GetHeight()
        )
        local nextScroll = self:GetVerticalScroll() - delta * 38

        self:SetVerticalScroll(
            math.max(0, math.min(maxScroll, nextScroll))
        )
    end)

    local function RebuildMenu()
        local characters = GetCharactersModule()

        if not characters then
            menu:Hide()
            return
        end

        if characters.UpdateCurrentCharacter then
            characters:UpdateCurrentCharacter()
        end

        local entries = characters:GetSortedCharacters()
        local viewedKey = select(1, GetViewedCharacter())
        local height = 8

        for index, entry in ipairs(entries) do
            local button = Components:AcquirePopupMenuButton(
                menu,
                index
            )

            local character = entry.character
            button.text:SetText(
                Components:FormatCharacterLabel(character, {
                    selected = entry.key == viewedKey,
                    showRealm = false,
                })
            )
            button.characterKey = entry.key
            button:SetScript("OnClick", function(self)
                Module:SetViewedCharacter(self.characterKey)
            end)
            button:Show()

            height = height + 20
        end

        Components:FinishPopupMenu(menu, #entries)
    end

    characterButton:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
        else
            RebuildMenu()
            menu:Show()
        end
    end)

    characterButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Characters")
        GameTooltip:Show()
    end)

    characterButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
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
    CreateCharacterBrowser(frame)

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
    self:UpdateCharacterView(frame)
end

function Module:Attach()
    local frame = _G.ProfessionsFrame

    if not frame then
        return
    end

    if not self.recipeScrollCallbackInstalled then
        local recipeList = frame.CraftingPage
            and frame.CraftingPage.RecipeList
        local scrollBox = recipeList and recipeList.ScrollBox

        if scrollBox
            and scrollBox.RegisterCallback
            and ScrollBoxListMixin
            and ScrollBoxListMixin.Event
            and ScrollBoxListMixin.Event.OnInitializedFrame
        then
            self.recipeScrollCallbackInstalled = true

            scrollBox:RegisterCallback(
                ScrollBoxListMixin.Event.OnInitializedFrame,
                function(_, row, node)
                    local data =
                        node and node.GetData and node:GetData()

                    if data and data.categoryInfo then
                        Module:StyleRecipeCategory(row, node)
                    elseif data and data.recipeInfo then
                        Module:StyleRecipeRow(row, node)
                    end
                end,
                self
            )

            StyleVisibleRecipeRows(recipeList)
        end
    end

    if not self.recipeSelectionCallbackInstalled
        and EventRegistry
        and EventRegistry.RegisterCallback
    then
        self.recipeSelectionCallbackInstalled = true

        EventRegistry:RegisterCallback(
            "ProfessionsRecipeListMixin.Event.OnRecipeSelected",
            function()
                C_Timer.After(0, function()
                    local professionsFrame =
                        _G.ProfessionsFrame

                    if professionsFrame
                        and professionsFrame:IsShown()
                    then
                        StyleCraftingPage(professionsFrame)
                    end
                end)
            end,
            self
        )
    end

    if not self.frameHooksInstalled then
        self.frameHooksInstalled = true

        frame:HookScript("OnShow", function()
            C_Timer.After(0, function()
                ApplySavedPosition(frame)
                Module:RefreshStyle()
            end)
        end)

    end

    ApplySavedPosition(frame)
    self:RefreshStyle()
end

function Module:Initialize()
    self:InstallRecipeTooltipHook()

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

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        Module:InstallRecipeTooltipHook()
        Module:SnapshotProfessionSkills()
    end)

    UI:RegisterEvent("SKILL_LINES_CHANGED", function()
        Module:SnapshotProfessionSkills()
    end)

    for _, event in ipairs({
        "TRADE_SKILL_SHOW",
        "TRADE_SKILL_LIST_UPDATE",
        "NEW_RECIPE_LEARNED",
        "SPELLS_CHANGED",
    }) do
        UI:RegisterEvent(event, function()
            C_Timer.After(0, function()
                Module:SnapshotCurrentProfession()

                local frame = _G.ProfessionsFrame
                if frame and frame:IsShown() then
                    Module:RefreshStyle()
                end
            end)
        end)
    end
end

Module:Initialize()
