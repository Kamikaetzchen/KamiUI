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

local function StyleRankBar(bar)
    if not bar then
        return
    end

    if bar.Background then
        bar.Background:ClearAllPoints()
        bar.Background:SetAllPoints()
        SetColor(bar.Background, { 0, 0, 0, 0.62 })
    end

    HideRegion(bar.Border)
    HideRegion(bar.Flare)

    CreateBorder(bar, "KamiRankBorder")

    local rankText = bar.Rank and bar.Rank.Text

    if rankText then
        StyleFont(rankText, 9, colors.text)
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

    StyleRankBar(card.StatusBar)

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
        button:GetNormalTexture(),
        button:GetPushedTexture(),
        button:GetHighlightTexture(),
        button:GetDisabledTexture(),
    }

    for _, texture in ipairs(textures) do
        HideRegion(texture)
    end
end

function Module:ApplyRecipeCategoryVisual(row)
    if not row then
        return
    end

    EnsureBackground(
        row,
        "KamiCategoryBackground",
        { 1, 1, 1, 0.055 }
    )

    HideButtonTextures(row)

    local collapse = row.GetCollapseButton
        and row:GetCollapseButton()
        or row.CollapseButton

    HideButtonTextures(collapse)

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

    Module:ApplyRecipeCategoryVisual(row)
end

function Module:StyleRecipeRow(row)
    if not row then
        return
    end

    StyleFont(row.Label, 9, colors.text)
    StyleFont(row.Count, 9, colors.muted)

    if row.SelectedOverlay then
        row.SelectedOverlay:SetColorTexture(1, 1, 1, 0.09)
    end

    if row.HighlightOverlay then
        row.HighlightOverlay:SetColorTexture(1, 1, 1, 0.05)
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
    StyleRankBar(page.RankBar)

    if page.TutorialButton then
        page.TutorialButton:Hide()
    end
end

local function StyleRightTab(tab)
    if not tab or tab.KamiStyled then
        return
    end

    tab.KamiStyled = true

    EnsureBackground(
        tab,
        "KamiBackground",
        { 0, 0, 0, 0.55 }
    )
    CreateBorder(tab, "KamiTabBorder")

    if tab.Icon then
        tab.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    HideButtonTextures(tab)
end

local function StyleRightTabs(frame)
    if not frame then
        return
    end

    StyleRightTab(frame.ProfessionsOverviewTab)

    for _, tab in ipairs(frame.rightProfessionTabs or {}) do
        StyleRightTab(tab)
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

local function StyleFrameChrome(frame)
    if not frame then
        return
    end

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
                function(row)
                    Module:StyleRecipeRow(row)
                end
            )
        end

        self.recipeHooksInstalled = true
    end

    if not self.frameHooksInstalled then
        self.frameHooksInstalled = true

        frame:HookScript("OnShow", function()
            C_Timer.After(0, function()
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
