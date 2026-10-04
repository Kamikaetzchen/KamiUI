local UI = KamiUI

local Module = UI:NewModule("Professions")

Module.name = "KamiUI_Professions"
Module.version = "0.1.0"

local colors = {
    background = { 0.00, 0.00, 0.00, 0.40 },
    panel = { 0.00, 0.00, 0.00, 0.24 },
    panelStrong = { 0.00, 0.00, 0.00, 0.40 },
    header = { 0.00, 0.00, 0.00, 0.48 },
    border = { 0.16, 0.16, 0.18, 1.00 },
    gold = { 0.88, 0.72, 0.16, 1.00 },
    text = { 0.92, 0.92, 0.94, 1.00 },
    muted = { 0.62, 0.62, 0.66, 1.00 },
}

local CRAFTING_RANK_X = 110
local CRAFTING_RANK_Y = -38
local CRAFTING_LINK_GAP = 10

-- The crafting bar and the overview bars use different Blizzard anchors,
-- so keep their fill offsets separate.
local CRAFTING_FILL_X_OFFSET = -5
local CRAFTING_FILL_Y_OFFSET = 3
local OVERVIEW_FILL_X_OFFSET = -2
local OVERVIEW_FILL_Y_OFFSET = 3

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

local function SetColor(texture, color)
    if texture and texture.SetColorTexture then
        texture:SetColorTexture(
            color[1],
            color[2],
            color[3],
            color[4] or 1
        )
    end
end

local function HideRegion(region)
    if region and region.SetAlpha then
        region:SetAlpha(0)
    end
end

local function CreateBorder(parent, key)
    key = key or "KamiBorder"

    if parent[key] then
        return parent[key]
    end

    local edges = {}

    local top = parent:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)
    SetColor(top, colors.border)
    edges[#edges + 1] = top

    local bottom = parent:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)
    SetColor(bottom, colors.border)
    edges[#edges + 1] = bottom

    local left = parent:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)
    SetColor(left, colors.border)
    edges[#edges + 1] = left

    local right = parent:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)
    SetColor(right, colors.border)
    edges[#edges + 1] = right

    parent[key] = edges

    return edges
end

local function EnsureBackground(parent, key, color)
    key = key or "KamiBackground"

    local background = parent[key]

    if not background then
        background = parent:CreateTexture(nil, "BACKGROUND", nil, -7)
        background:SetAllPoints()
        parent[key] = background
    end

    SetColor(background, color)

    return background
end

local function StyleFont(fontString, size, color)
    if not fontString then
        return
    end

    fontString:SetFont(
        "Fonts\\FRIZQT__.TTF",
        size or 9,
        "OUTLINE"
    )

    if color then
        fontString:SetTextColor(
            color[1],
            color[2],
            color[3],
            color[4] or 1
        )
    end
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
        SetColor(bar.Background, { 0, 0, 0, 0.62 })
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

    HideRegion(bar.Border)
    HideRegion(bar.Flare)

    CreateBorder(bar, "KamiRankBorder")

    local rankText = bar.Rank and bar.Rank.Text

    if bar.Rank then
        bar.Rank:ClearAllPoints()
        bar.Rank:SetPoint("CENTER", bar, "CENTER", 0, -2)
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
        StyleFont(rankText, rankFontSize, colors.text)
    end
end

local function StyleProfessionSpellButton(button)
    if not button then
        return
    end

    if button.IconTexture then
        button.IconTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    HideRegion(button.IconTextureOverlay)

    if not button.KamiIconBorder then
        local border = CreateFrame("Frame", nil, button)
        border:SetPoint("TOPLEFT", 1, -1)
        border:SetPoint("BOTTOMRIGHT", -1, 1)
        border:SetFrameLevel(button:GetFrameLevel() + 1)
        CreateBorder(border)
        button.KamiIconBorder = border
    end

    StyleFont(button.spellString, 9, colors.text)
    StyleFont(button.subSpellString, 8, colors.muted)
end

local function StyleProfessionCard(card)
    if not card then
        return
    end

    if card.Background then
        SetColor(card.Background, colors.panel)
    else
        EnsureBackground(card, "KamiBackground", colors.panel)
    end

    CreateBorder(card, "KamiCardBorder")

    StyleFont(card.ProfessionName, 10, colors.gold)
    StyleFont(card.specialization, 8, colors.muted)
    StyleFont(card.Rank, 8, colors.muted)
    StyleFont(card.missingHeader, 10, colors.gold)
    StyleFont(card.missingText, 8, colors.muted)

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

local function HideButtonTextures(button)
    if not button then
        return
    end

    local textures = {
        button.GetNormalTexture and button:GetNormalTexture(),
        button.GetPushedTexture and button:GetPushedTexture(),
        button.GetHighlightTexture and button:GetHighlightTexture(),
        button.GetDisabledTexture and button:GetDisabledTexture(),
    }

    for _, texture in ipairs(textures) do
        HideRegion(texture)
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
    background:SetPoint("TOPLEFT", row, "TOPLEFT", 6, 0)
    background:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 0)
    SetColor(background, { 1, 1, 1, 0.055 })

    HideButtonTextures(row)

    HideRegion(row.LeftPiece)
    HideRegion(row.CenterPiece)
    HideRegion(row.RightPiece)
    HideRegion(row.CollapseIcon)
    HideRegion(row.CollapseIconAlphaAdd)

    local collapse = row.GetCollapseButton
        and row:GetCollapseButton()
        or row.CollapseButton

    if collapse then
        collapse:Hide()
    end

    if not row.KamiCategoryHighlight then
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        row.KamiCategoryHighlight = highlight
    end

    row.KamiCategoryHighlight:ClearAllPoints()
    row.KamiCategoryHighlight:SetPoint(
        "TOPLEFT",
        row,
        "TOPLEFT",
        6,
        0
    )
    row.KamiCategoryHighlight:SetPoint(
        "BOTTOMRIGHT",
        row,
        "BOTTOMRIGHT",
        -6,
        0
    )
    SetColor(row.KamiCategoryHighlight, { 1, 1, 1, 0.04 })

    local text = GetHeaderText(row)

    if text then
        text:ClearAllPoints()
        text:SetPoint("LEFT", row, "LEFT", 6, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        text:SetJustifyH("LEFT")
        StyleFont(text, 9, colors.gold)
        text:SetText(
            string.format(
                "%s %s",
                row.KamiCollapsed and "+" or "-",
                row.KamiCategoryName or ""
            )
        )
    end

    if row.RankBar then
        StyleRankBar(row.RankBar)
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

    if not row.KamiOriginalUpdateCollapsedState then
        row.KamiOriginalUpdateCollapsedState =
            row.UpdateCollapsedState

        row.UpdateCollapsedState = function(self, collapsed)
            if self.KamiOriginalUpdateCollapsedState then
                self.KamiOriginalUpdateCollapsedState(
                    self,
                    collapsed
                )
            end

            self.KamiCollapsed = collapsed
            Module:ApplyRecipeCategoryVisual(self)
        end
    end

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
    local backgroundColor = { 0.45, 0.45, 0.48, 0.10 }

    if Enum
        and Enum.TradeskillRelativeDifficulty
        and difficulty
    then
        local difficulties = Enum.TradeskillRelativeDifficulty

        if difficulty == difficulties.Optimal then
            backgroundColor = { 1.00, 0.34, 0.05, 0.16 }
        elseif difficulty == difficulties.Medium then
            backgroundColor = { 1.00, 0.82, 0.00, 0.14 }
        elseif difficulty == difficulties.Easy then
            backgroundColor = { 0.20, 0.78, 0.24, 0.13 }
        end
    end

    local background = row.KamiDifficultyBackground

    if not background then
        background = row:CreateTexture(nil, "BACKGROUND", nil, -6)
        background:SetAllPoints()
        row.KamiDifficultyBackground = background
    end

    SetColor(background, backgroundColor)

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
        StyleFont(row.Label, 9)

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
        StyleFont(row.Count, 9, colors.muted)
    end

    if row.SelectedOverlay then
        row.SelectedOverlay:ClearAllPoints()
        row.SelectedOverlay:SetAllPoints()
        row.SelectedOverlay:SetColorTexture(1, 1, 1, 0.10)
    end

    if row.HighlightOverlay then
        row.HighlightOverlay:ClearAllPoints()
        row.HighlightOverlay:SetAllPoints()
        row.HighlightOverlay:SetColorTexture(1, 1, 1, 0.06)
    end
end

local function StyleRecipeList(recipeList)
    if not recipeList then
        return
    end

    if recipeList.Background then
        SetColor(recipeList.Background, colors.panel)
    else
        EnsureBackground(
            recipeList,
            "KamiBackground",
            colors.panel
        )
    end

    if recipeList.BackgroundNineSlice then
        recipeList.BackgroundNineSlice:Hide()
    end

    CreateBorder(recipeList, "KamiRecipeListBorder")

    if recipeList.SearchBox then
        StyleFont(recipeList.SearchBox.Instructions, 9, colors.muted)
    end
end

local function StyleSchematicForm(form)
    if not form then
        return
    end

    if form.NineSlice then
        form.NineSlice:Hide()
    end

    if form.Background then
        SetColor(form.Background, colors.panel)
        form.Background:Show()
    else
        EnsureBackground(form, "KamiBackground", colors.panel)
    end

    CreateBorder(form, "KamiSchematicBorder")

    StyleFont(form.Description, 9, colors.text)
    StyleFont(form.RequiredTools, 8, colors.muted)
    StyleFont(form.RecraftingRequiredTools, 8, colors.muted)
end

local function StyleCraftingPage(frame)
    local page = frame and frame.CraftingPage

    if not page then
        return
    end

    StyleRecipeList(page.RecipeList)
    StyleSchematicForm(page.SchematicForm)
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

local function SetBottomTabBackground(tab, r, g, b, a)
    for _, texture in ipairs(tab.backgrounds or {}) do
        texture:SetColorTexture(r, g, b, a)
    end
end

local function CreateBottomTabVisual(tab)
    local chamfer = 4
    local backgrounds = {}

    local upper = tab:CreateTexture(nil, "BACKGROUND")
    upper:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    upper:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, 0)
    upper:SetPoint("BOTTOM", tab, "BOTTOM", 0, chamfer)
    backgrounds[#backgrounds + 1] = upper

    for row = 0, chamfer - 1 do
        local inset = chamfer - row
        local strip = tab:CreateTexture(nil, "BACKGROUND")
        strip:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", inset, row)
        strip:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -inset, row)
        strip:SetHeight(1)
        backgrounds[#backgrounds + 1] = strip
    end

    tab.backgrounds = backgrounds

    local borders = {}

    local top = tab:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)
    SetColor(top, colors.border)
    borders[1] = top

    local bottom = tab:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", chamfer, 0)
    bottom:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -chamfer, 0)
    bottom:SetHeight(1)
    SetColor(bottom, colors.border)
    borders[2] = bottom

    local left = tab:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, chamfer)
    left:SetWidth(1)
    SetColor(left, colors.border)
    borders[3] = left

    local right = tab:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, chamfer)
    right:SetWidth(1)
    SetColor(right, colors.border)
    borders[4] = right

    for step = 1, chamfer do
        local leftChamfer = tab:CreateTexture(nil, "OVERLAY")
        leftChamfer:SetPoint(
            "BOTTOMLEFT",
            tab,
            "BOTTOMLEFT",
            step - 1,
            chamfer - step
        )
        leftChamfer:SetSize(1, 1)
        SetColor(leftChamfer, colors.border)

        local rightChamfer = tab:CreateTexture(nil, "OVERLAY")
        rightChamfer:SetPoint(
            "BOTTOMRIGHT",
            tab,
            "BOTTOMRIGHT",
            -(step - 1),
            chamfer - step
        )
        rightChamfer:SetSize(1, 1)
        SetColor(rightChamfer, colors.border)
    end

    tab.borders = borders
end

local function SetProfessionTabVisual(tab, active)
    if not tab then
        return
    end

    SetBottomTabBackground(
        tab,
        active and 0.04 or 0.00,
        active and 0.04 or 0.00,
        active and 0.05 or 0.00,
        active and 0.55 or 0.40
    )

    if tab.borders and tab.borders[1] then
        tab.borders[1]:SetShown(not active)
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

        CreateBottomTabVisual(tab)
        SetProfessionTabVisual(tab, false)

        if index > 1 and tab.borders and tab.borders[3] then
            tab.borders[3]:Hide()
        end

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

            SetProfessionTabVisual(tab, active == true)
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

    StyleFont(button.KamiText, 12, colors.text)
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

    EnsureBackground(
        frame,
        "KamiBackground",
        colors.background
    )
    CreateBorder(frame, "KamiFrameBorder")

    if not frame.KamiHeader then
        local header = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        header:SetHeight(32)
        SetColor(header, colors.header)
        frame.KamiHeader = header
    end

    HideRegion(frame.Bg)
    HideRegion(frame.TopTileStreaks)

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
        StyleFont(title, 12, colors.gold)
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

        self.recipeHooksInstalled = true
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
