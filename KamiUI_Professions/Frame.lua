local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components
local Module = UI:GetModule("Professions")

if not Module then
    return
end

local FRAME_WIDTH = 790
local FRAME_HEIGHT = 520
local HEADER_HEIGHT = 40
local RECIPE_PANEL_WIDTH = 300
local CONTENT_PADDING = 8
local ROW_HEIGHT = 22
local REAGENT_ROW_HEIGHT = 42

local function GetDatabase()
    return Module:GetDatabase()
end

local function GetCharactersModule()
    return Module:GetCharactersModule()
end

local function GetViewedCharacter()
    return Module:GetViewedCharacter()
end

local function GetLiveProfessionInfo()
    if not C_TradeSkillUI
        or not C_TradeSkillUI.GetBaseProfessionInfo
    then
        return nil
    end

    local baseInfo = UI:SafeCall(
        C_TradeSkillUI.GetBaseProfessionInfo
    )

    if not baseInfo
        or not baseInfo.professionID
        or baseInfo.professionID == 0
    then
        return nil
    end

    local childInfo = C_TradeSkillUI.GetChildProfessionInfo
        and UI:SafeCall(C_TradeSkillUI.GetChildProfessionInfo)
        or nil

    if childInfo
        and childInfo.professionID
        and childInfo.professionID ~= 0
    then
        return childInfo, baseInfo
    end

    return baseInfo, baseInfo
end

local function IsLiveProfessionOpen()
    return GetLiveProfessionInfo() ~= nil
end

local secondaryProfessionIDs = {
    [129] = true, -- First Aid
    [185] = true, -- Cooking
    [356] = true, -- Fishing
    [794] = true, -- Archaeology
}

local secondaryProfessionNames = {
    ["first aid"] = true,
    ["cooking"] = true,
    ["fishing"] = true,
    ["archaeology"] = true,
}

local function IsPrimaryProfession(profession)
    if not profession then
        return false
    end

    if profession.isPrimaryProfession ~= nil then
        return profession.isPrimaryProfession == true
    end

    if C_TradeSkillUI
        and C_TradeSkillUI.GetProfessionInfoBySkillLineID
        and profession.professionID
    then
        local info = UI:SafeCall(
            C_TradeSkillUI.GetProfessionInfoBySkillLineID,
            profession.professionID
        )

        if info and info.isPrimaryProfession ~= nil then
            return info.isPrimaryProfession == true
        end
    end

    if secondaryProfessionIDs[profession.professionID] then
        return false
    end

    local name = string.lower(
        profession.professionName or ""
    )

    return not secondaryProfessionNames[name]
end

local function GetCachedProfessions(character)
    local primary = {}
    local secondary = {}

    for _, profession in pairs(
        character and character.professions or {}
    ) do
        if profession.professionName then
            local target = IsPrimaryProfession(profession)
                and primary
                or secondary

            target[#target + 1] = profession
        end
    end

    table.sort(primary, function(left, right)
        local leftSlot = left.professionSlot or 99
        local rightSlot = right.professionSlot or 99

        if leftSlot ~= rightSlot then
            return leftSlot < rightSlot
        end

        return (left.professionName or "")
            < (right.professionName or "")
    end)

    table.sort(secondary, function(left, right)
        return (left.professionName or "")
            < (right.professionName or "")
    end)

    return primary, secondary
end

local function GetCachedRecipes(profession)
    local recipes = {}

    for recipeID, recipe in pairs(
        profession and profession.recipes or {}
    ) do
        recipes[#recipes + 1] = {
            recipeID = recipeID,
            name = type(recipe) == "table"
                and recipe.name
                or ("Recipe " .. tostring(recipeID)),
            icon = type(recipe) == "table"
                and recipe.icon
                or nil,
        }
    end

    table.sort(recipes, function(left, right)
        return (left.name or "") < (right.name or "")
    end)

    return recipes
end

local function GetItemCount(itemID)
    if not itemID then
        return 0
    end

    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(
            itemID,
            false,
            false,
            true
        ) or 0
    end

    if _G.GetItemCount then
        return _G.GetItemCount(
            itemID,
            false,
            false,
            true
        ) or 0
    end

    return 0
end

local function GetItemDisplayData(itemID, link, fallbackIcon)
    local name
    local itemLink = link
    local quality
    local icon = fallbackIcon

    if GetItemInfo and (itemID or link) then
        local infoName,
            infoLink,
            infoQuality,
            _itemLevel,
            _requiredLevel,
            _className,
            _subclassName,
            _stackCount,
            _equipLocation,
            infoIcon = GetItemInfo(itemID or link)

        name = infoName
        itemLink = itemLink or infoLink
        quality = infoQuality
        icon = icon or infoIcon
    end

    if itemID and C_Item then
        if not name and C_Item.GetItemNameByID then
            name = C_Item.GetItemNameByID(itemID)
        end

        if not icon and C_Item.GetItemIconByID then
            icon = C_Item.GetItemIconByID(itemID)
        end
    end

    return {
        itemID = itemID,
        name = name or (itemID and ("Item " .. itemID) or "Unknown"),
        link = itemLink,
        quality = quality,
        icon = icon,
    }
end

local function GetDifficultyColor(difficulty)
    if not Enum
        or not Enum.TradeskillRelativeDifficulty
        or difficulty == nil
    then
        return Palette.difficulty.trivial
    end

    local values = Enum.TradeskillRelativeDifficulty

    if difficulty == values.Optimal then
        return Palette.difficulty.hard
    elseif difficulty == values.Medium then
        return Palette.difficulty.normal
    elseif difficulty == values.Easy then
        return Palette.difficulty.easy
    end

    return Palette.difficulty.trivial
end

local function SetScrollHeight(scroll, content, height)
    content:SetHeight(math.max(height, scroll:GetHeight()))
    local maxScroll = math.max(
        0,
        content:GetHeight() - scroll:GetHeight()
    )
    local value = math.min(
        scroll:GetVerticalScroll(),
        maxScroll
    )

    scroll:SetVerticalScroll(value)

    local scrollbar = scroll.KamiScrollBar

    if scrollbar then
        scrollbar:SetMinMaxValues(0, maxScroll)
        scrollbar:SetValue(value)
        scrollbar:SetShown(maxScroll > 0)
    end
end

local function ConfigureMouseWheelScroll(scroll, content, step)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(
            0,
            content:GetHeight() - self:GetHeight()
        )
        local nextScroll =
            self:GetVerticalScroll() - delta * (step or 32)

        local value =
            math.max(0, math.min(maxScroll, nextScroll))

        self:SetVerticalScroll(value)

        if self.KamiScrollBar then
            self.KamiScrollBar:SetValue(value)
        end
    end)
end

local function AcquireRecipeRow(frame, index)
    local row = frame.recipeRows[index]

    if row then
        return row
    end

    row = CreateFrame("Button", nil, frame.recipeContent)
    row:SetHeight(ROW_HEIGHT)

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    row.background = background

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", row, "LEFT", 7, 0)
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
    Styles:ApplyText(text, 9, Palette.text)
    row.text = text

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    Styles:SetColor(
        highlight,
        Palette.white,
        Styles.State.hoverAlpha
    )

    row:SetScript("OnClick", function(self)
        if self.categoryID then
            frame.collapsedCategories[self.categoryID] =
                not frame.collapsedCategories[self.categoryID]
            Module:RefreshRecipeList()
            return
        end

        if self.recipeID then
            Module.selectedRecipeID = self.recipeID
            Module:RefreshRecipeList()
            Module:RefreshRecipeDetails()
        end
    end)

    frame.recipeRows[index] = row
    return row
end

local function AcquireOverviewCard(frame, index)
    local card = frame.overviewCards[index]

    if card then
        return card
    end

    card = CreateFrame("Button", nil, frame.overviewPage)
    card:RegisterForClicks("LeftButtonUp")

    local background = Styles:EnsureBackground(
        card,
        "KamiBackground",
        Palette.panelStrong
    )
    card.background = background
    card.KamiBorders = Styles:CreateBorder(card)

    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", card, "LEFT", 8, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    card.icon = icon

    local name = card:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
    name:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    name:SetJustifyH("LEFT")
    card.name = name

    local rank = card:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    rank:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    rank:SetJustifyH("LEFT")
    card.rank = rank

    local bar = CreateFrame("StatusBar", nil, card)
    bar:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(0.24, 0.42, 0.72, 0.65)
    Styles:EnsureBackground(
        bar,
        "KamiBackground",
        { 0, 0, 0, 0.55 }
    )
    Styles:CreateBorder(bar)
    card.rankBar = bar

    local highlight = card:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    Styles:SetColor(
        highlight,
        Palette.white,
        Styles.State.hoverAlpha
    )

    card:SetScript("OnClick", function(self)
        if self.profession then
            Module:OpenProfession(self.profession)
        end
    end)

    frame.overviewCards[index] = card
    return card
end

local function StyleOverviewCard(card, isPrimary)
    if isPrimary then
        card:SetHeight(68)
        card.icon:SetSize(46, 46)
        Styles:SetColor(
            card.background,
            { 0.035, 0.028, 0.008, 0.56 }
        )
        Styles:SetBorderColor(
            card.KamiBorders,
            { 0.42, 0.32, 0.08, 0.95 }
        )
        Styles:ApplyText(card.name, 12, Palette.gold)
        Styles:ApplyText(card.rank, 9, Palette.text)
        card.rankBar:SetHeight(10)
        card.rankBar:ClearAllPoints()
        card.rankBar:SetPoint(
            "BOTTOMLEFT",
            card,
            "BOTTOMLEFT",
            62,
            8
        )
        card.rankBar:SetPoint(
            "BOTTOMRIGHT",
            card,
            "BOTTOMRIGHT",
            -8,
            8
        )
    else
        card:SetHeight(46)
        card.icon:SetSize(30, 30)
        Styles:SetColor(
            card.background,
            Palette.panelStrong
        )
        Styles:SetBorderColor(
            card.KamiBorders,
            Palette.border
        )
        Styles:ApplyText(card.name, 10, Palette.text)
        Styles:ApplyText(card.rank, 8, Palette.muted)
        card.rankBar:SetHeight(6)
        card.rankBar:ClearAllPoints()
        card.rankBar:SetPoint(
            "BOTTOMLEFT",
            card,
            "BOTTOMLEFT",
            46,
            7
        )
        card.rankBar:SetPoint(
            "BOTTOMRIGHT",
            card,
            "BOTTOMRIGHT",
            -8,
            7
        )
    end
end

local function AcquireReagentRow(frame, index)
    local row = frame.reagentRows[index]

    if row then
        return row
    end

    row = CreateFrame("Frame", nil, frame.detailContent)
    row:SetHeight(REAGENT_ROW_HEIGHT)

    local slot = Components:CreateCachedItemButton(row, {
        size = 34,
        count = true,
        countFontSize = 8,
        corners = true,
    })
    slot:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.slot = slot

    local name = row:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    name:SetPoint("TOPLEFT", slot, "TOPRIGHT", 8, -2)
    name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    name:SetJustifyH("LEFT")
    Styles:ApplyText(name, 9, Palette.text)
    row.name = name

    local status = row:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    status:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    status:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    status:SetJustifyH("LEFT")
    Styles:ApplyText(status, 8, Palette.muted)
    row.status = status

    frame.reagentRows[index] = row
    return row
end

local function CreateCharacterMenu(frame, header)
    local characterButton = CreateFrame("Button", nil, header)
    characterButton:SetSize(22, 22)
    characterButton:SetPoint("TOPLEFT", header, "TOPLEFT", 4, -8)

    local icon = characterButton:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    characterButton.icon = icon
    frame.characterButton = characterButton

    local menu = Components:CreatePopupMenu(
        frame,
        characterButton,
        {
            width = 210,
            frameLevel = frame:GetFrameLevel() + 30,
            backgroundColor = { 0, 0, 0, 0.96 },
            borderColor = Palette.border,
            fontSize = 9,
        }
    )
    frame.characterMenu = menu

    local function Rebuild()
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

        for index, entry in ipairs(entries) do
            local button = Components:AcquirePopupMenuButton(
                menu,
                index
            )

            button.text:SetText(
                Components:FormatCharacterLabel(
                    entry.character,
                    {
                        selected = entry.key == viewedKey,
                    }
                )
            )
            button.characterKey = entry.key
            button:SetScript("OnClick", function(self)
                Module:SetViewedCharacter(self.characterKey)
            end)
            button:Show()
        end

        Components:FinishPopupMenu(menu, #entries)
    end

    characterButton:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
        else
            Rebuild()
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

local function CreateOverviewPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        CONTENT_PADDING,
        -HEADER_HEIGHT - CONTENT_PADDING
    )
    page:SetPoint(
        "BOTTOMRIGHT",
        frame,
        "BOTTOMRIGHT",
        -CONTENT_PADDING,
        CONTENT_PADDING
    )
    page:Hide()
    frame.overviewPage = page

    local title = page:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    title:SetPoint("TOPLEFT", 4, -2)
    Styles:ApplyText(title, 12, Palette.text)
    title:SetText("Professions")
    page.title = title

    local subtitle = page:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    Styles:ApplyText(subtitle, 9, Palette.muted)
    page.subtitle = subtitle

    local primaryLabel = page:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    Styles:ApplyText(primaryLabel, 9, Palette.gold)
    primaryLabel:SetText("Primary Professions")
    page.primaryLabel = primaryLabel

    local secondaryLabel = page:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    Styles:ApplyText(secondaryLabel, 9, Palette.muted)
    secondaryLabel:SetText("Secondary Professions")
    page.secondaryLabel = secondaryLabel

    frame.overviewCards = {}
end

local function CreateCraftingPage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        CONTENT_PADDING,
        -HEADER_HEIGHT - CONTENT_PADDING
    )
    page:SetPoint(
        "BOTTOMRIGHT",
        frame,
        "BOTTOMRIGHT",
        -CONTENT_PADDING,
        CONTENT_PADDING
    )
    page:Hide()
    frame.craftingPage = page

    local left = CreateFrame("Frame", nil, page)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(RECIPE_PANEL_WIDTH)
    Styles:EnsureBackground(
        left,
        "KamiBackground",
        { 0, 0, 0, 0.28 }
    )
    Styles:CreateBorder(left)
    frame.recipePanel = left

    local search = CreateFrame(
        "EditBox",
        nil,
        left,
        "InputBoxTemplate"
    )
    search:SetAutoFocus(false)
    search:SetHeight(24)
    search:SetPoint("TOPLEFT", left, "TOPLEFT", 5, -5)
    search:SetPoint("TOPRIGHT", left, "TOPRIGHT", -5, -5)
    search:SetTextInsets(6, 6, 0, 0)
    Components:StyleInput(search, {
        backgroundColor = Palette.panelStrong,
    })
    search.Instructions = search.Instructions
        or search:CreateFontString(nil, "OVERLAY")
    Styles:ApplyText(search.Instructions, 9, Palette.muted)
    search.Instructions:SetPoint("LEFT", search, "LEFT", 7, 0)
    search.Instructions:SetText("Search recipes")
    search:SetScript("OnTextChanged", function(self)
        if self.Instructions then
            self.Instructions:SetShown(self:GetText() == "")
        end

        Module:RefreshRecipeList()
    end)
    frame.searchBox = search

    local recipeScroll = CreateFrame("ScrollFrame", nil, left)
    recipeScroll:SetPoint(
        "TOPLEFT",
        search,
        "BOTTOMLEFT",
        0,
        -5
    )
    recipeScroll:SetPoint(
        "BOTTOMRIGHT",
        left,
        "BOTTOMRIGHT",
        -10,
        1
    )
    frame.recipeScroll = recipeScroll

    local recipeScrollBar = CreateFrame(
        "Slider",
        nil,
        left
    )
    recipeScrollBar:SetOrientation("VERTICAL")
    recipeScrollBar:SetPoint(
        "TOPRIGHT",
        recipeScroll,
        "TOPRIGHT",
        8,
        0
    )
    recipeScrollBar:SetPoint(
        "BOTTOMRIGHT",
        recipeScroll,
        "BOTTOMRIGHT",
        8,
        0
    )
    recipeScrollBar:SetMinMaxValues(0, 0)
    recipeScrollBar:SetValue(0)
    recipeScrollBar:SetValueStep(1)

    if recipeScrollBar.SetObeyStepOnDrag then
        recipeScrollBar:SetObeyStepOnDrag(false)
    end

    local _, recipeThumb =
        Components:StyleScrollBar(
            recipeScrollBar,
            { width = 6 }
        )

    if recipeThumb then
        recipeThumb:SetHeight(28)
    end

    recipeScrollBar:SetScript(
        "OnValueChanged",
        function(_, value)
            recipeScroll:SetVerticalScroll(value)
        end
    )

    recipeScroll.KamiScrollBar = recipeScrollBar
    frame.recipeScrollBar = recipeScrollBar

    local recipeContent = CreateFrame("Frame", nil, recipeScroll)
    recipeContent:SetSize(RECIPE_PANEL_WIDTH - 12, 1)
    recipeScroll:SetScrollChild(recipeContent)
    frame.recipeContent = recipeContent
    frame.recipeRows = {}
    frame.collapsedCategories = {}

    ConfigureMouseWheelScroll(
        recipeScroll,
        recipeContent,
        ROW_HEIGHT * 2
    )

    local divider = page:CreateTexture(nil, "OVERLAY")
    divider:SetPoint("TOPLEFT", left, "TOPRIGHT", 5, 0)
    divider:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 5, 0)
    divider:SetWidth(1)
    Styles:SetColor(divider, Palette.border)

    local right = CreateFrame("Frame", nil, page)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 11, 0)
    right:SetPoint("BOTTOMRIGHT")
    frame.detailPanel = right

    local recipeTitle = right:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    recipeTitle:SetPoint("TOPLEFT", 0, -1)
    recipeTitle:SetPoint("RIGHT", right, "RIGHT", -2, 0)
    recipeTitle:SetJustifyH("LEFT")
    Styles:ApplyText(recipeTitle, 13, Palette.text)
    frame.recipeTitle = recipeTitle

    local recipeSubTitle = right:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    recipeSubTitle:SetPoint(
        "TOPLEFT",
        recipeTitle,
        "BOTTOMLEFT",
        0,
        -3
    )
    recipeSubTitle:SetPoint("RIGHT", right, "RIGHT", -2, 0)
    recipeSubTitle:SetJustifyH("LEFT")
    Styles:ApplyText(recipeSubTitle, 9, Palette.muted)
    frame.recipeSubTitle = recipeSubTitle

    local detailScroll = CreateFrame("ScrollFrame", nil, right)
    detailScroll:SetPoint(
        "TOPLEFT",
        recipeSubTitle,
        "BOTTOMLEFT",
        0,
        -9
    )
    detailScroll:SetPoint(
        "BOTTOMRIGHT",
        right,
        "BOTTOMRIGHT",
        0,
        48
    )
    frame.detailScroll = detailScroll

    local detailContent = CreateFrame("Frame", nil, detailScroll)
    detailContent:SetSize(1, 1)
    detailScroll:SetScrollChild(detailContent)
    frame.detailContent = detailContent
    frame.reagentRows = {}

    ConfigureMouseWheelScroll(
        detailScroll,
        detailContent,
        REAGENT_ROW_HEIGHT
    )

    local outputSlot = Components:CreateCachedItemButton(
        detailContent,
        {
            size = 44,
            count = true,
            countFontSize = 9,
            corners = true,
        }
    )
    outputSlot:SetPoint("TOPLEFT", detailContent, "TOPLEFT", 0, 0)
    frame.outputSlot = outputSlot

    local outputName = detailContent:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    outputName:SetPoint("TOPLEFT", outputSlot, "TOPRIGHT", 9, -2)
    outputName:SetPoint(
        "RIGHT",
        detailContent,
        "RIGHT",
        -4,
        0
    )
    outputName:SetJustifyH("LEFT")
    Styles:ApplyText(outputName, 11, Palette.text)
    frame.outputName = outputName

    local description = detailContent:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    description:SetPoint(
        "TOPLEFT",
        outputSlot,
        "BOTTOMLEFT",
        0,
        -10
    )
    description:SetPoint(
        "RIGHT",
        detailContent,
        "RIGHT",
        -4,
        0
    )
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    description:SetWordWrap(true)
    Styles:ApplyText(description, 9, Palette.muted)
    frame.description = description

    local reagentsTitle = detailContent:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    reagentsTitle:SetPoint(
        "TOPLEFT",
        description,
        "BOTTOMLEFT",
        0,
        -12
    )
    Styles:ApplyText(reagentsTitle, 10, Palette.gold)
    reagentsTitle:SetText("Reagents")
    frame.reagentsTitle = reagentsTitle

    local minus = CreateFrame("Button", nil, right)
    minus:SetSize(24, 24)
    minus:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 0)
    Components:StyleButton(minus, { text = "-" })
    frame.quantityMinus = minus

    local quantity = CreateFrame(
        "EditBox",
        nil,
        right,
        "InputBoxTemplate"
    )
    quantity:SetSize(42, 24)
    quantity:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    quantity:SetAutoFocus(false)
    quantity:SetJustifyH("CENTER")
    quantity:SetNumeric(true)
    Components:StyleInput(quantity, {
        backgroundColor = Palette.panelStrong,
    })
    frame.quantity = quantity

    local plus = CreateFrame("Button", nil, right)
    plus:SetSize(24, 24)
    plus:SetPoint("LEFT", quantity, "RIGHT", 4, 0)
    Components:StyleButton(plus, { text = "+" })
    frame.quantityPlus = plus

    local craft = CreateFrame("Button", nil, right)
    craft:SetHeight(24)
    craft:SetPoint("LEFT", plus, "RIGHT", 10, 0)
    craft:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    Components:StyleButton(craft, { text = "Craft" })
    frame.craftButton = craft

    minus:SetScript("OnClick", function()
        Module:SetCraftQuantity(
            (tonumber(quantity:GetText()) or 1) - 1
        )
    end)
    plus:SetScript("OnClick", function()
        Module:SetCraftQuantity(
            (tonumber(quantity:GetText()) or 1) + 1
        )
    end)
    quantity:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        Module:SetCraftQuantity(tonumber(self:GetText()) or 1)
    end)

    craft:SetScript("OnClick", function()
        Module:CraftSelectedRecipe()
    end)
end

function Module:CreateFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame(
        "Frame",
        "KamiUIProfessionFrame",
        UIParent,
        "BackdropTemplate"
    )
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()

    Styles:ApplyBackdrop(
        frame,
        Palette.window.neutral,
        Palette.border
    )

    local header = Components:CreateWindowHeader(frame, {
        height = HEADER_HEIGHT - 1,
        hasSubtitle = true,
        draggable = true,
        onDragStop = function()
            UI:SaveFramePosition(frame, GetDatabase())
        end,
    })
    frame.header = header

    CreateCharacterMenu(frame, header)

    local back = CreateFrame("Button", nil, header.LeftActions)
    back:SetSize(28, 22)
    back:SetPoint("LEFT", frame.characterButton, "RIGHT", 5, 0)
    Components:StyleButton(back, { text = "<" })
    back:Hide()
    back:SetScript("OnClick", function()
        Module.forceOverview = true
        Module.cachedProfessionID = nil
        Module.selectedRecipeID = nil
        Module:RefreshFrame()
    end)
    frame.backButton = back

    local close = CreateFrame("Button", nil, header.RightActions)
    close:SetSize(24, 22)
    close:SetPoint("RIGHT", header.RightActions, "RIGHT", -4, 0)
    Components:StyleButton(close, { text = "x" })
    close:SetScript("OnClick", function()
        Module:CloseFrame()
    end)
    frame.closeButton = close

    CreateOverviewPage(frame)
    CreateCraftingPage(frame)

    frame:SetScript("OnShow", function()
        UI:ApplyFramePosition(
            frame,
            GetDatabase(),
            "position",
            0,
            20
        )
        Module:RefreshFrame()
    end)

    frame:SetScript("OnHide", function()
        if Module.suppressBackendClose then
            return
        end

        if IsLiveProfessionOpen()
            and C_TradeSkillUI
            and C_TradeSkillUI.CloseTradeSkill
        then
            C_TradeSkillUI.CloseTradeSkill()
        elseif _G.ProfessionsFrame
            and _G.ProfessionsFrame:IsShown()
        then
            _G.ProfessionsFrame:Hide()
        end
    end)

    frame:EnableKeyboard(true)

    if frame.SetPropagateKeyboardInput then
        frame:SetPropagateKeyboardInput(true)
    end

    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            if self.SetPropagateKeyboardInput then
                self:SetPropagateKeyboardInput(false)
            end

            Module:CloseFrame()
            return
        end

        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(true)
        end
    end)

    self.frame = frame
    return frame
end

function Module:SetViewedCharacter(key)
    local characters = GetCharactersModule()

    if not characters then
        return
    end

    local currentKey = characters:GetCurrentCharacterKey()

    self.viewCharacterKey = key == currentKey and nil or key
    self.cachedProfessionID = nil
    self.selectedRecipeID = nil
    self.forceOverview = true

    if self.frame and self.frame.characterMenu then
        self.frame.characterMenu:Hide()
    end

    self:RefreshFrame()
end

function Module:OpenProfession(profession)
    if not profession then
        return
    end

    local _, _, isCurrent = GetViewedCharacter()

    if not isCurrent then
        self.cachedProfessionID = profession.professionID
        self.forceOverview = false
        self.selectedRecipeID = nil
        self:RefreshFrame()
        return
    end

    local liveInfo = GetLiveProfessionInfo()

    if liveInfo
        and (
            liveInfo.professionID == profession.professionID
            or liveInfo.parentProfessionID == profession.professionID
            or profession.parentProfessionID == liveInfo.professionID
        )
    then
        self.cachedProfessionID = nil
        self.forceOverview = false
        self.selectedRecipeID = nil
        self:RefreshFrame()
        return
    end

    if not C_TradeSkillUI
        or not C_TradeSkillUI.OpenTradeSkill
    then
        return
    end

    local tradeSkillID =
        profession.parentProfessionID
        or profession.professionID

    if tradeSkillID then
        local opened = UI:SafeCall(
            C_TradeSkillUI.OpenTradeSkill,
            tradeSkillID
        )

        if not opened
            and profession.professionID ~= tradeSkillID
        then
            UI:SafeCall(
                C_TradeSkillUI.OpenTradeSkill,
                profession.professionID
            )
        end
    end
end

function Module:RefreshOverview()
    local frame = self.frame
    if not frame then
        return
    end

    local _, character, isCurrent = GetViewedCharacter()
    local primary, secondary =
        GetCachedProfessions(character)

    frame.header:SetTitle(
        Components:FormatCharacterLabel(
            character or {},
            { showRealm = false }
        ) .. " - Professions"
    )
    frame.header:SetSubtitle(
        isCurrent
            and "Current character"
            or "Cached character data"
    )

    local total = #primary + #secondary

    frame.overviewPage.subtitle:SetText(
        total > 0
            and "Select a profession"
            or "No profession data cached"
    )

    local cardIndex = 0
    local y = 44

    frame.overviewPage.primaryLabel:ClearAllPoints()
    frame.overviewPage.primaryLabel:SetPoint(
        "TOPLEFT",
        frame.overviewPage,
        "TOPLEFT",
        4,
        -y
    )
    frame.overviewPage.primaryLabel:SetShown(#primary > 0)

    if #primary > 0 then
        y = y + 18

        for _, profession in ipairs(primary) do
            cardIndex = cardIndex + 1
            local card = AcquireOverviewCard(frame, cardIndex)

            card.profession = profession
            StyleOverviewCard(card, true)
            card:ClearAllPoints()
            card:SetPoint(
                "TOPLEFT",
                frame.overviewPage,
                "TOPLEFT",
                4,
                -y
            )
            card:SetPoint(
                "TOPRIGHT",
                frame.overviewPage,
                "TOPRIGHT",
                -4,
                -y
            )

            card.icon:SetTexture(profession.icon)
            card.name:SetText(
                profession.professionName or "Profession"
            )

            local skill = profession.skillLevel or 0
            local maximum = profession.maxSkillLevel or 0
            local modifier = profession.skillModifier or 0
            local rankText =
                string.format("%d / %d", skill, maximum)

            if modifier ~= 0 then
                rankText = rankText
                    .. string.format("  %+d", modifier)
            end

            if profession.recipesCached then
                local count = 0

                for _ in pairs(profession.recipes or {}) do
                    count = count + 1
                end

                rankText = rankText
                    .. string.format("  -  %d recipes", count)
            end

            card.rank:SetText(rankText)
            card.rankBar:SetMinMaxValues(
                0,
                math.max(1, maximum)
            )
            card.rankBar:SetValue(skill)
            card:Enable()
            card:Show()

            y = y + 76
        end
    end

    if #primary > 0 and #secondary > 0 then
        y = y + 10
    end

    frame.overviewPage.secondaryLabel:ClearAllPoints()
    frame.overviewPage.secondaryLabel:SetPoint(
        "TOPLEFT",
        frame.overviewPage,
        "TOPLEFT",
        4,
        -y
    )
    frame.overviewPage.secondaryLabel:SetShown(
        #secondary > 0
    )

    if #secondary > 0 then
        y = y + 18

        for _, profession in ipairs(secondary) do
            cardIndex = cardIndex + 1
            local card = AcquireOverviewCard(frame, cardIndex)

            card.profession = profession
            StyleOverviewCard(card, false)
            card:ClearAllPoints()
            card:SetPoint(
                "TOPLEFT",
                frame.overviewPage,
                "TOPLEFT",
                4,
                -y
            )
            card:SetPoint(
                "TOPRIGHT",
                frame.overviewPage,
                "TOPRIGHT",
                -4,
                -y
            )

            card.icon:SetTexture(profession.icon)
            card.name:SetText(
                profession.professionName or "Profession"
            )

            local skill = profession.skillLevel or 0
            local maximum = profession.maxSkillLevel or 0
            local modifier = profession.skillModifier or 0
            local rankText =
                string.format("%d / %d", skill, maximum)

            if modifier ~= 0 then
                rankText = rankText
                    .. string.format("  %+d", modifier)
            end

            if profession.recipesCached then
                local count = 0

                for _ in pairs(profession.recipes or {}) do
                    count = count + 1
                end

                rankText = rankText
                    .. string.format("  -  %d recipes", count)
            end

            card.rank:SetText(rankText)
            card.rankBar:SetMinMaxValues(
                0,
                math.max(1, maximum)
            )
            card.rankBar:SetValue(skill)
            card:Enable()
            card:Show()

            y = y + 52
        end
    end

    for index = cardIndex + 1, #frame.overviewCards do
        frame.overviewCards[index]:Hide()
    end
end

local function BuildLiveRecipeEntries(frame)
    local entries = {}
    local search = string.lower(
        frame.searchBox:GetText() or ""
    )
    local ids = C_TradeSkillUI
        and C_TradeSkillUI.GetAllRecipeIDs
        and UI:SafeCall(C_TradeSkillUI.GetAllRecipeIDs)
        or {}
    local categories = {}
    local seenRecipes = {}

    if type(ids) ~= "table" then
        return entries
    end

    for _, recipeID in ipairs(ids) do
        local info = UI:SafeCall(
            C_TradeSkillUI.GetRecipeInfo,
            recipeID
        )

        if info and Professions and Professions.GetFirstRecipe then
            info = Professions.GetFirstRecipe(info)
        end

        local resolvedID = info and info.recipeID or recipeID

        if info
            and info.learned
            and not seenRecipes[resolvedID]
        then
            local name = info.name or ("Recipe " .. resolvedID)
            local matches = search == ""
                or string.find(
                    string.lower(name),
                    search,
                    1,
                    true
                )

            if matches then
                seenRecipes[resolvedID] = true
                local categoryID = info.categoryID or 0
                local category = categories[categoryID]

                if not category then
                    local categoryInfo =
                        C_TradeSkillUI.GetCategoryInfo
                        and UI:SafeCall(
                            C_TradeSkillUI.GetCategoryInfo,
                            categoryID
                        )
                        or nil

                    category = {
                        id = categoryID,
                        name = categoryInfo
                            and categoryInfo.name
                            or "Recipes",
                        recipes = {},
                    }
                    categories[categoryID] = category
                end

                category.recipes[#category.recipes + 1] = {
                    recipeID = resolvedID,
                    info = info,
                }
            end
        end
    end

    local orderedCategories = {}

    for _, category in pairs(categories) do
        table.sort(category.recipes, function(left, right)
            return (left.info.name or "")
                < (right.info.name or "")
        end)
        orderedCategories[#orderedCategories + 1] = category
    end

    table.sort(orderedCategories, function(left, right)
        return (left.name or "") < (right.name or "")
    end)

    for _, category in ipairs(orderedCategories) do
        entries[#entries + 1] = {
            kind = "category",
            categoryID = category.id,
            name = category.name,
        }

        if not frame.collapsedCategories[category.id] then
            for _, recipe in ipairs(category.recipes) do
                entries[#entries + 1] = {
                    kind = "recipe",
                    recipeID = recipe.recipeID,
                    info = recipe.info,
                }
            end
        end
    end

    return entries
end

local function BuildCachedRecipeEntries(profession, searchText)
    local entries = {
        {
            kind = "category",
            categoryID = "cached",
            name = "Cached recipes",
        },
    }
    local search = string.lower(searchText or "")

    for _, recipe in ipairs(GetCachedRecipes(profession)) do
        if search == ""
            or string.find(
                string.lower(recipe.name or ""),
                search,
                1,
                true
            )
        then
            entries[#entries + 1] = {
                kind = "recipe",
                recipeID = recipe.recipeID,
                cached = recipe,
            }
        end
    end

    return entries
end

function Module:GetDisplayedCachedProfession()
    local _, character = GetViewedCharacter()

    if not character or not self.cachedProfessionID then
        return nil
    end

    return character.professions
        and character.professions[self.cachedProfessionID]
        or nil
end

function Module:RefreshRecipeList()
    local frame = self.frame

    if not frame or not frame.craftingPage:IsShown() then
        return
    end

    local _, _, isCurrent = GetViewedCharacter()
    local liveInfo = isCurrent and GetLiveProfessionInfo() or nil
    local cachedProfession = self:GetDisplayedCachedProfession()
    local entries

    if liveInfo and not cachedProfession then
        entries = BuildLiveRecipeEntries(frame)
    else
        entries = BuildCachedRecipeEntries(
            cachedProfession,
            frame.searchBox:GetText()
        )
    end

    local rowIndex = 0
    local y = 0
    local selectedVisible = false
    local firstRecipeID

    for _, entry in ipairs(entries) do
        rowIndex = rowIndex + 1
        local row = AcquireRecipeRow(frame, rowIndex)

        row.categoryID = nil
        row.recipeID = nil
        row.cachedRecipe = nil
        row:ClearAllPoints()
        row:SetPoint(
            "TOPLEFT",
            frame.recipeContent,
            "TOPLEFT",
            0,
            -y
        )
        row:SetPoint(
            "TOPRIGHT",
            frame.recipeContent,
            "TOPRIGHT",
            0,
            -y
        )

        if entry.kind == "category" then
            row.categoryID = entry.categoryID
            row.icon:Hide()
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", row, "LEFT", 7, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)

            local collapsed =
                frame.collapsedCategories[entry.categoryID] == true
            row.text:SetText(
                (collapsed and "+ " or "- ")
                .. (entry.name or "Recipes")
            )
            Styles:ApplyText(row.text, 9, Palette.gold)
            Styles:SetColor(
                row.background,
                Palette.white,
                Styles.State.sectionAlpha
            )
        else
            row.recipeID = entry.recipeID
            row.cachedRecipe = entry.cached
            row.icon:Show()
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)

            local info = entry.info
            local name = info
                and info.name
                or entry.cached
                and entry.cached.name
                or ("Recipe " .. tostring(entry.recipeID))
            local icon = info
                and info.icon
                or entry.cached
                and entry.cached.icon

            row.icon:SetTexture(icon)
            row.text:SetText(name)
            Styles:ApplyText(row.text, 9, Palette.text)

            local color = GetDifficultyColor(
                info and info.relativeDifficulty
            )
            local selected =
                Module.selectedRecipeID == entry.recipeID

            Styles:SetColor(
                row.background,
                selected and Palette.white or color,
                selected
                    and Styles.State.selectedAlpha
                    or 0.24
            )

            if selected then
                selectedVisible = true
            end

            firstRecipeID = firstRecipeID or entry.recipeID
        end

        row:Show()
        y = y + ROW_HEIGHT
    end

    for index = rowIndex + 1, #frame.recipeRows do
        frame.recipeRows[index]:Hide()
    end

    frame.recipeContent:SetWidth(
        math.max(1, frame.recipeScroll:GetWidth())
    )
    SetScrollHeight(frame.recipeScroll, frame.recipeContent, y)

    if not Module.selectedRecipeID or not selectedVisible then
        Module.selectedRecipeID = firstRecipeID
    end
end

function Module:SetCraftQuantity(value)
    local frame = self.frame

    if not frame then
        return
    end

    local maximum = math.max(1, self.maxCraftable or 1)
    value = math.floor(tonumber(value) or 1)
    value = math.max(1, math.min(maximum, value))

    self.craftQuantity = value
    frame.quantity:SetText(tostring(value))
end

local function ClearReagentRows(frame)
    for _, row in ipairs(frame.reagentRows) do
        row:Hide()
    end
end

function Module:RefreshRecipeDetails()
    local frame = self.frame

    if not frame or not frame.craftingPage:IsShown() then
        return
    end

    local recipeID = self.selectedRecipeID
    local _, _, isCurrent = GetViewedCharacter()
    local cachedProfession = self:GetDisplayedCachedProfession()

    ClearReagentRows(frame)
    frame.outputSlot:Hide()
    frame.outputName:SetText("")
    frame.description:SetText("")
    frame.reagentsTitle:Hide()
    frame.recipeSubTitle:SetText("")
    frame.quantityMinus:Disable()
    frame.quantityPlus:Disable()
    frame.quantity:Disable()
    frame.craftButton:Disable()
    frame.craftButton:SetText("Craft")
    self.maxCraftable = 0

    if not recipeID then
        frame.recipeTitle:SetText("Select a recipe")
        SetScrollHeight(
            frame.detailScroll,
            frame.detailContent,
            frame.detailScroll:GetHeight()
        )
        return
    end

    if cachedProfession or not isCurrent then
        local cached = cachedProfession
            and cachedProfession.recipes
            and cachedProfession.recipes[recipeID]
            or nil

        frame.recipeTitle:SetText(
            cached and cached.name
            or ("Recipe " .. tostring(recipeID))
        )
        frame.recipeSubTitle:SetText("Cached recipe data")
        frame.outputName:SetText(
            "Open this profession on that character "
            .. "to view reagents and crafting details."
        )
        frame.outputName:SetTextColor(unpack(Palette.muted))
        SetScrollHeight(
            frame.detailScroll,
            frame.detailContent,
            frame.detailScroll:GetHeight()
        )
        return
    end

    local info = UI:SafeCall(
        C_TradeSkillUI.GetRecipeInfo,
        recipeID
    )

    if not info then
        frame.recipeTitle:SetText(
            "Recipe " .. tostring(recipeID)
        )
        return
    end

    frame.recipeTitle:SetText(info.name or "Recipe")

    local craftable = C_TradeSkillUI.GetCraftableCount
        and UI:SafeCall(
            C_TradeSkillUI.GetCraftableCount,
            recipeID
        )
        or 0
    craftable = math.max(0, craftable or 0)
    self.maxCraftable = info.canCreateMultiple == false
        and math.min(1, craftable)
        or craftable

    frame.recipeSubTitle:SetText(
        string.format(
            "Craftable: %d%s",
            self.maxCraftable,
            info.disabledReason
                and ("  -  " .. info.disabledReason)
                or ""
        )
    )

    local output = C_TradeSkillUI.GetRecipeOutputItemData
        and UI:SafeCall(
            C_TradeSkillUI.GetRecipeOutputItemData,
            recipeID
        )
        or nil
    local schematic = C_TradeSkillUI.GetRecipeSchematic
        and UI:SafeCall(
            C_TradeSkillUI.GetRecipeSchematic,
            recipeID,
            false
        )
        or nil

    local outputData = GetItemDisplayData(
        output and output.itemID,
        output and output.hyperlink,
        output and output.icon
            or schematic and schematic.icon
            or info.icon
    )
    local quantityText = ""

    if schematic then
        local minQuantity = schematic.quantityMin or 1
        local maxQuantity = schematic.quantityMax or minQuantity

        if maxQuantity > 1 or minQuantity > 1 then
            quantityText = minQuantity == maxQuantity
                and tostring(minQuantity)
                or string.format("%d-%d", minQuantity, maxQuantity)
        end
    end

    Components:SetItemSlotData(frame.outputSlot, {
        icon = outputData.icon,
        link = outputData.link,
        quality = outputData.quality,
        countText = quantityText,
    })
    frame.outputSlot:Show()
    frame.outputName:SetText(outputData.name)
    frame.outputName:SetTextColor(unpack(Palette.text))

    local description = C_TradeSkillUI.GetRecipeDescription
        and UI:SafeCall(
            C_TradeSkillUI.GetRecipeDescription,
            recipeID
        )
        or nil

    frame.description:SetText(description or "")
    frame.reagentsTitle:Show()

    local reagentIndex = 0
    local y = 44 + 10
    y = y + math.max(
        18,
        frame.description:GetStringHeight() or 0
    ) + 22

    local hasUnsupportedSelection = false

    for _, slot in ipairs(
        schematic and schematic.reagentSlotSchematics or {}
    ) do
        if not slot.hiddenInCraftingForm then
            reagentIndex = reagentIndex + 1
            local row = AcquireReagentRow(frame, reagentIndex)
            local reagent = slot.reagents and slot.reagents[1]
            local itemID = reagent and reagent.itemID
            local item = GetItemDisplayData(itemID)
            local required = slot.quantityRequired or 0
            local owned = itemID and GetItemCount(itemID) or 0
            local sufficient = required == 0 or owned >= required
            local countColor = sufficient
                and Palette.success
                or Palette.difficulty.veryHard

            row:ClearAllPoints()
            row:SetPoint(
                "TOPLEFT",
                frame.detailContent,
                "TOPLEFT",
                0,
                -y
            )
            row:SetPoint(
                "TOPRIGHT",
                frame.detailContent,
                "TOPRIGHT",
                0,
                -y
            )

            Components:SetItemSlotData(row.slot, {
                icon = item.icon,
                link = item.link,
                quality = item.quality,
                countText = required > 0
                    and string.format("%d/%d", owned, required)
                    or tostring(owned),
                countColor = countColor,
            })

            local slotText = slot.slotInfo
                and slot.slotInfo.slotText
            local optional = slot.required == false

            row.name:SetText(
                itemID
                    and item.name
                    or slotText
                    or "Reagent"
            )
            row.status:SetText(
                optional
                    and "Optional"
                    or sufficient
                    and "Available"
                    or "Missing"
            )
            Styles:SetTextColor(
                row.status,
                sufficient and Palette.muted
                    or Palette.difficulty.veryHard
            )

            if slot.reagents
                and #slot.reagents > 1
                and slot.required ~= false
            then
                hasUnsupportedSelection = true
                row.status:SetText("Select reagent - not yet supported")
            end

            row:Show()
            y = y + REAGENT_ROW_HEIGHT
        end
    end

    frame.reagentsTitle:ClearAllPoints()
    frame.reagentsTitle:SetPoint(
        "TOPLEFT",
        frame.description,
        "BOTTOMLEFT",
        0,
        -12
    )

    SetScrollHeight(
        frame.detailScroll,
        frame.detailContent,
        math.max(y + 10, frame.detailScroll:GetHeight())
    )

    local unsupportedRecipe =
        info.isEnchantingRecipe
        or info.isRecraft
        or info.isSalvageRecipe
        or hasUnsupportedSelection

    local canCraft =
        info.learned
        and not info.disabled
        and self.maxCraftable > 0
        and not unsupportedRecipe

    if canCraft then
        frame.quantityMinus:Enable()
        frame.quantityPlus:Enable()
        frame.quantity:Enable()
        frame.craftButton:Enable()
        frame.craftButton:SetText(
            info.alternateVerb
            or info.abilityVerb
            or "Craft"
        )
    elseif info.isEnchantingRecipe then
        frame.craftButton:SetText("Target required")
    elseif info.isRecraft then
        frame.craftButton:SetText("Recraft not supported")
    elseif info.isSalvageRecipe then
        frame.craftButton:SetText("Salvage not supported")
    elseif hasUnsupportedSelection then
        frame.craftButton:SetText("Select reagent")
    elseif self.maxCraftable <= 0 then
        frame.craftButton:SetText("Missing reagents")
    end

    self:SetCraftQuantity(
        math.min(self.craftQuantity or 1, math.max(1, self.maxCraftable))
    )
end

function Module:CraftSelectedRecipe()
    if not self.selectedRecipeID
        or not C_TradeSkillUI
        or not C_TradeSkillUI.CraftRecipe
        or (self.maxCraftable or 0) <= 0
    then
        return
    end

    local quantity = math.max(
        1,
        math.min(
            self.maxCraftable,
            tonumber(self.frame.quantity:GetText()) or 1
        )
    )

    C_TradeSkillUI.CraftRecipe(
        self.selectedRecipeID,
        quantity
    )
end

function Module:RefreshCrafting()
    local frame = self.frame

    if not frame then
        return
    end

    local _, character, isCurrent = GetViewedCharacter()
    local liveInfo, baseInfo =
        isCurrent and GetLiveProfessionInfo() or nil
    local cachedProfession = self:GetDisplayedCachedProfession()
    local profession = cachedProfession or liveInfo

    if not profession then
        self.forceOverview = true
        self:RefreshFrame()
        return
    end

    frame.header:SetTitle(
        profession.professionName or "Profession"
    )

    local skill = profession.skillLevel or 0
    local maximum = profession.maxSkillLevel or 0
    frame.header:SetSubtitle(
        string.format(
            "%s  -  %d / %d",
            Components:FormatCharacterLabel(
                character or {},
                { showRealm = false }
            ),
            skill,
            maximum
        )
    )

    frame.backButton:Show()
    self:RefreshRecipeList()
    self:RefreshRecipeDetails()
end

function Module:RefreshFrame()
    local frame = self.frame

    if not frame or not frame:IsShown() then
        return
    end

    local _, _, isCurrent = GetViewedCharacter()
    local liveInfo = isCurrent and GetLiveProfessionInfo() or nil
    local cachedProfession = self:GetDisplayedCachedProfession()
    local showCrafting =
        not self.forceOverview
        and (liveInfo or cachedProfession)

    frame.overviewPage:SetShown(not showCrafting)
    frame.craftingPage:SetShown(showCrafting)
    frame.backButton:SetShown(showCrafting)

    if showCrafting then
        self:RefreshCrafting()
    else
        self:RefreshOverview()
    end
end

function Module:ShowFrame()
    local frame = self:CreateFrame()

    UI:ApplyFramePosition(
        frame,
        GetDatabase(),
        "position",
        0,
        20
    )

    if not self.forceOverview and IsLiveProfessionOpen() then
        self.cachedProfessionID = nil
    end

    frame:Show()
    self:RefreshFrame()
end

function Module:CloseFrame()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
        return
    end

    if IsLiveProfessionOpen()
        and C_TradeSkillUI
        and C_TradeSkillUI.CloseTradeSkill
    then
        C_TradeSkillUI.CloseTradeSkill()
    elseif _G.ProfessionsFrame
        and _G.ProfessionsFrame:IsShown()
    then
        _G.ProfessionsFrame:Hide()
    end
end

local function DetachNativePanelLayout(frame)
    if not frame or not SetUIPanelAttribute then
        return
    end

    -- Keep Blizzard's hidden backend alive for C_TradeSkillUI, but stop
    -- it behaving like a left-side UIPanel that moves other windows.
    SetUIPanelAttribute(frame, "area", "center")
    SetUIPanelAttribute(frame, "pushable", 0)
    SetUIPanelAttribute(frame, "allowOtherPanels", 1)
    SetUIPanelAttribute(frame, "checkFit", 0)
end

local function DisableNativeMouse(frame)
    if not frame then
        return
    end

    if frame.EnableMouse then
        frame:EnableMouse(false)
    end

    if frame.EnableMouseWheel then
        frame:EnableMouseWheel(false)
    end

    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            DisableNativeMouse(child)
        end
    end
end

function Module:SuppressNativeFrame()
    local frame = _G.ProfessionsFrame

    if not frame then
        return
    end

    DetachNativePanelLayout(frame)
    frame:SetAlpha(0)
    DisableNativeMouse(frame)

    if not frame.KamiProfessionSuppressed then
        frame.KamiProfessionSuppressed = true

        frame:HookScript("OnShow", function(self)
            DetachNativePanelLayout(self)
            self:SetAlpha(0)
            DisableNativeMouse(self)

            C_Timer.After(0, function()
                Module:ShowFrame()
            end)
        end)

        frame:HookScript("OnHide", function()
            if not IsLiveProfessionOpen()
                and Module.frame
            then
                Module.frame:Hide()
            end
        end)
    end
end

function Module:InitializeFrame()
    if self.frameInitialized then
        return
    end

    self.frameInitialized = true
    self:CreateFrame()
    self:SuppressNativeFrame()

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_Professions" then
            Module:SuppressNativeFrame()

            if not _G.ProfessionsFrame then
                C_Timer.After(0, function()
                    Module:SuppressNativeFrame()
                end)
            end
        end
    end)

    UI:RegisterEvent("TRADE_SKILL_SHOW", function()
        Module.forceOverview = false
        Module.cachedProfessionID = nil
        Module.selectedRecipeID = nil

        C_Timer.After(0, function()
            Module:SnapshotCurrentProfession()
            Module:SuppressNativeFrame()
            Module:ShowFrame()
        end)
    end)

    UI:RegisterEvent("TRADE_SKILL_CLOSE", function()
        if Module.frame and Module.frame:IsShown() then
            Module.suppressBackendClose = true
            Module.frame:Hide()
            Module.suppressBackendClose = false
        end
    end)

    UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if Module.frame and Module.frame:IsShown() then
            Module:RefreshFrame()
        end
    end)

    for _, event in ipairs({
        "BAG_UPDATE_DELAYED",
        "CURRENCY_DISPLAY_UPDATE",
        "GET_ITEM_INFO_RECEIVED",
    }) do
        UI:RegisterEvent(event, function()
            if Module.frame and Module.frame:IsShown() then
                Module:RefreshRecipeDetails()
            end
        end)
    end
end

Module:InitializeFrame()
