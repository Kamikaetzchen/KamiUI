local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components
local function GetItemSlotIcon(button)
    return button and (button.icon or button.Icon) or nil
end

local RARITY_GLOW_TEXTURE =
    "Interface\\AddOns\\KamiUI\\Media\\ItemRarityGlow_16x16.tga"

-- Quest gold: the same warm golden-yellow family as Blizzard's bag quest
-- overlay. Quest highlighting takes precedence over item rarity coloring.
local QUEST_GLOW_COLOR = { 1.00, 0.80, 0.20 }

local RARITY_GLOW_TEXCOORDS = {
    topLeft = { 0.0000, 0.4375, 0.0000, 0.4375 },
    top = { 0.4375, 0.5625, 0.0000, 0.4375 },
    topRight = { 0.5625, 1.0000, 0.0000, 0.4375 },
    left = { 0.0000, 0.4375, 0.4375, 0.5625 },
    right = { 0.5625, 1.0000, 0.4375, 0.5625 },
    bottomLeft = { 0.0000, 0.4375, 0.5625, 1.0000 },
    bottom = { 0.4375, 0.5625, 0.5625, 1.0000 },
    bottomRight = { 0.5625, 1.0000, 0.5625, 1.0000 },
}

local function CreateRarityGlowController(textures)
    local glow = {
        textures = textures,
    }

    function glow:Show()
        for _, texture in ipairs(self.textures) do
            texture:Show()
        end
    end

    function glow:Hide()
        for _, texture in ipairs(self.textures) do
            texture:Hide()
        end
    end

    function glow:SetVertexColor(r, g, b, a)
        for _, texture in ipairs(self.textures) do
            texture:SetVertexColor(r, g, b, a)
        end
    end

    return glow
end

local function CreateRarityGlowSlice(button, coords, alpha)
    local texture = button:CreateTexture(
        nil,
        "OVERLAY",
        nil,
        1
    )

    texture:SetTexture(RARITY_GLOW_TEXTURE)
    texture:SetTexCoord(
        coords[1],
        coords[2],
        coords[3],
        coords[4]
    )
    texture:SetBlendMode("ADD")
    texture:SetAlpha(alpha)
    texture:Hide()

    return texture
end

local function CreateRarityGlow(
    button,
    size,
    iconInset,
    options
)
    local innerSize = math.max(1, size - iconInset * 2)
    local glowDepth = math.max(
        3,
        math.floor(size * 0.17 + 0.5)
    )
    glowDepth = math.min(
        glowDepth,
        math.max(1, math.floor(innerSize / 2))
    )

    local alpha = options.rarityAlpha or 1
    local parts = {}

    local function AddSlice(key)
        local texture = CreateRarityGlowSlice(
            button,
            RARITY_GLOW_TEXCOORDS[key],
            alpha
        )
        parts[#parts + 1] = texture
        return texture
    end

    local topLeft = AddSlice("topLeft")
    topLeft:SetPoint(
        "TOPLEFT",
        button,
        "TOPLEFT",
        iconInset,
        -iconInset
    )
    topLeft:SetSize(glowDepth, glowDepth)

    local topRight = AddSlice("topRight")
    topRight:SetPoint(
        "TOPRIGHT",
        button,
        "TOPRIGHT",
        -iconInset,
        -iconInset
    )
    topRight:SetSize(glowDepth, glowDepth)

    local bottomLeft = AddSlice("bottomLeft")
    bottomLeft:SetPoint(
        "BOTTOMLEFT",
        button,
        "BOTTOMLEFT",
        iconInset,
        iconInset
    )
    bottomLeft:SetSize(glowDepth, glowDepth)

    local bottomRight = AddSlice("bottomRight")
    bottomRight:SetPoint(
        "BOTTOMRIGHT",
        button,
        "BOTTOMRIGHT",
        -iconInset,
        iconInset
    )
    bottomRight:SetSize(glowDepth, glowDepth)

    local top = AddSlice("top")
    top:SetPoint(
        "TOPLEFT",
        button,
        "TOPLEFT",
        iconInset + glowDepth,
        -iconInset
    )
    top:SetPoint(
        "TOPRIGHT",
        button,
        "TOPRIGHT",
        -iconInset - glowDepth,
        -iconInset
    )
    top:SetHeight(glowDepth)

    local bottom = AddSlice("bottom")
    bottom:SetPoint(
        "BOTTOMLEFT",
        button,
        "BOTTOMLEFT",
        iconInset + glowDepth,
        iconInset
    )
    bottom:SetPoint(
        "BOTTOMRIGHT",
        button,
        "BOTTOMRIGHT",
        -iconInset - glowDepth,
        iconInset
    )
    bottom:SetHeight(glowDepth)

    local left = AddSlice("left")
    left:SetPoint(
        "TOPLEFT",
        button,
        "TOPLEFT",
        iconInset,
        -iconInset - glowDepth
    )
    left:SetPoint(
        "BOTTOMLEFT",
        button,
        "BOTTOMLEFT",
        iconInset,
        iconInset + glowDepth
    )
    left:SetWidth(glowDepth)

    local right = AddSlice("right")
    right:SetPoint(
        "TOPRIGHT",
        button,
        "TOPRIGHT",
        -iconInset,
        -iconInset - glowDepth
    )
    right:SetPoint(
        "BOTTOMRIGHT",
        button,
        "BOTTOMRIGHT",
        -iconInset,
        iconInset + glowDepth
    )
    right:SetWidth(glowDepth)

    return CreateRarityGlowController(parts)
end

function Components:SetItemSlotBorderColor(button, color)
    if not button then
        return
    end

    Styles:SetBorderColor(button.KamiBorders, color or Palette.slotBorder)

    for _, corner in ipairs(button.KamiBorderCorners or {}) do
        Styles:SetColor(corner, color or Palette.slotBorder)
    end
end

function Components:SetItemSlotQuality(button, quality)
    local glow = button and button.KamiRarityGlow

    if not glow then
        return
    end

    if button.KamiQuestItem then
        glow:SetVertexColor(
            QUEST_GLOW_COLOR[1],
            QUEST_GLOW_COLOR[2],
            QUEST_GLOW_COLOR[3],
            1
        )
        glow:Show()
        return
    end

    if quality == nil or quality <= 1 then
        glow:Hide()
        return
    end

    local color = ITEM_QUALITY_COLORS
        and ITEM_QUALITY_COLORS[quality]

    if color then
        glow:SetVertexColor(color.r, color.g, color.b, 1)
        glow:Show()
    else
        glow:Hide()
    end
end

-- These textures belong to Blizzard's ContainerFrameItemButtonTemplate.
-- A quest starter shows the ! overlay; other quest items show the native
-- quest border. Both are independent of the item's quality.
local function UpdateQuestItemDecoration(button, data)
    local questID = data.questID
    local isQuestItem = data.isQuestItem == true
        or (questID ~= nil and questID ~= 0)

    button.KamiQuestItem = isQuestItem

    local marker = button.IconQuestTexture

    if not marker then
        return
    end

    if not button.KamiQuestMarkerAnchored then
        button.KamiQuestMarkerAnchored = true
        marker:ClearAllPoints()
        marker:SetAllPoints(button)
    end

    if questID and questID ~= 0 and not data.questActive then
        marker:SetTexture(TEXTURE_ITEM_QUEST_BANG)
        marker:Show()
    elseif isQuestItem then
        marker:SetTexture(TEXTURE_ITEM_QUEST_BORDER)
        marker:Show()
    else
        marker:Hide()
    end
end

local function GetItemSlotQuality(data)
    if data.quality ~= nil then
        return data.quality
    end

    local item = data.itemID or data.link

    if item
        and C_Item
        and C_Item.GetItemQualityByID
    then
        return UI:SafeCall(
            C_Item.GetItemQualityByID,
            item
        )
    end

    return nil
end

function Components:RefreshItemSlotQuality(button, data)
    if not button then
        return
    end

    data = data or {}

    button.KamiQualityLoadToken =
        (button.KamiQualityLoadToken or 0) + 1

    local loadToken = button.KamiQualityLoadToken
    local quality = GetItemSlotQuality(data)

    self:SetItemSlotQuality(button, quality)

    if quality ~= nil
        or not data.itemID
        or not Item
        or not Item.CreateFromItemID
    then
        return
    end

    local item = data.link
        and Item.CreateFromItemLink
        and Item:CreateFromItemLink(data.link)
        or Item:CreateFromItemID(data.itemID)

    if not item or not item.ContinueOnItemLoad then
        return
    end

    item:ContinueOnItemLoad(function()
        if button.KamiQualityLoadToken ~= loadToken
            or button.itemID ~= data.itemID
        then
            return
        end

        local loadedQuality = item.GetItemQuality
            and item:GetItemQuality()
            or GetItemSlotQuality(data)

        Components:SetItemSlotQuality(
            button,
            loadedQuality
        )
    end)
end

function Components:SuppressItemButtonFlash(button)
    if not button then
        return
    end

    if button.NewItemTexture then
        button.NewItemTexture:Hide()
    end

    if button.BattlepayItemTexture then
        button.BattlepayItemTexture:Hide()
    end

    if button.flashAnim and button.flashAnim:IsPlaying() then
        button.flashAnim:Stop()
    end

    if button.newitemglowAnim
        and button.newitemglowAnim:IsPlaying()
    then
        button.newitemglowAnim:Stop()
    end
end

function Components:StyleItemSlot(button, options)
    if not button then
        return nil
    end

    options = options or {}

    if button.KamiItemSlotStyled then
        if options.borderColor then
            self:SetItemSlotBorderColor(button, options.borderColor)
        end

        return button
    end

    button.KamiItemSlotStyled = true

    local size = options.size or Styles.Metrics.itemSlotSize
    local iconInset = options.iconInset or 1

    button:SetSize(size, size)

    for _, texture in ipairs({
        button.NormalTexture,
        button.IconBorder,
        button.NewItemTexture,
        button.BattlepayItemTexture,
    }) do
        if texture then
            if texture.SetAlpha then
                texture:SetAlpha(0)
            end

            if texture.Hide then
                texture:Hide()
            end
        end
    end

    local background = button.KamiBackground or button.background

    if not background then
        background = button:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
    end

    Styles:SetColor(
        background,
        options.backgroundColor or Palette.slot
    )
    button.KamiBackground = background
    button.background = background

    if options.border ~= false then
        button.KamiBorders = Styles:CreateBorder(button, {
            color = options.borderColor or Palette.slotBorder,
        })
    end

    if options.corners then
        local corners = {}

        for _, point in ipairs({
            "TOPLEFT",
            "TOPRIGHT",
            "BOTTOMLEFT",
            "BOTTOMRIGHT",
        }) do
            local corner = button:CreateTexture(
                nil,
                "OVERLAY",
                nil,
                2
            )
            corner:SetSize(1, 1)
            corner:SetPoint(point)
            Styles:SetColor(
                corner,
                options.borderColor or Palette.slotBorder
            )
            corners[#corners + 1] = corner
        end

        button.KamiBorderCorners = corners
    end

    if options.rarityGlow ~= false then
        button.KamiRarityGlow = CreateRarityGlow(
            button,
            size,
            iconInset,
            options
        )
    end

    local icon = GetItemSlotIcon(button)

    if not icon and options.createIcon ~= false then
        icon = button:CreateTexture(nil, "ARTWORK")
        button.icon = icon
    end

    if icon then
        icon:ClearAllPoints()
        icon:SetPoint(
            "TOPLEFT",
            button,
            "TOPLEFT",
            iconInset,
            -iconInset
        )
        icon:SetPoint(
            "BOTTOMRIGHT",
            button,
            "BOTTOMRIGHT",
            -iconInset,
            iconInset
        )
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    if options.highlight ~= false then
        local highlight = button.GetHighlightTexture
            and button:GetHighlightTexture()
            or nil

        if not highlight then
            highlight = button:CreateTexture(nil, "HIGHLIGHT")
            button.KamiItemHighlight = highlight
        end

        highlight:SetAllPoints()
        Styles:SetColor(
            highlight,
            Palette.white,
            options.highlightAlpha or 0.12
        )
    end

    local count = button.Count

    if not count and options.count then
        count = button:CreateFontString(nil, "OVERLAY")
        button.Count = count
    end

    if count then
        count:SetFont(
            "Fonts\\FRIZQT__.TTF",
            options.countFontSize or 10,
            "OUTLINE"
        )
        count:ClearAllPoints()
        count:SetPoint(
            "BOTTOMRIGHT",
            button,
            "BOTTOMRIGHT",
            -2,
            2
        )
        button.count = count
    end

    if options.label ~= nil then
        local label = button.KamiItemLabel

        if not label then
            label = button:CreateFontString(nil, "OVERLAY")
            label:SetPoint("CENTER")
            button.KamiItemLabel = label
            button.label = label
        end

        Styles:ApplyText(
            label,
            options.labelFontSize or 8,
            options.labelColor or Palette.muted
        )
        label:SetText(options.label or "")
    end

    return button
end

function Components:CreateItemSlot(parent, options)
    options = options or {}

    local button = CreateFrame(
        options.frameType or "Button",
        options.name,
        parent,
        options.template
    )

    self:StyleItemSlot(button, options)

    return button
end

function Components:CreateContainerItemButton(parent, options)
    options = options or {}

    local button = CreateFrame(
        "ItemButton",
        options.name,
        parent,
        options.template or "ContainerFrameItemButtonTemplate"
    )

    button:UnregisterAllEvents()

    if options.draggable ~= false then
        button:RegisterForDrag("LeftButton")
    end

    if options.onDragStart then
        button:HookScript("OnDragStart", options.onDragStart)
    end

    button.KamiContainerTooltipAnchor =
        options.tooltipAnchor or "ANCHOR_CURSOR_RIGHT"

    if not Components.containerTooltipAnchorHookInstalled
        and hooksecurefunc
        and ContainerFrameItemButton_CalculateItemTooltipAnchors
    then
        Components.containerTooltipAnchorHookInstalled = true

        hooksecurefunc(
            "ContainerFrameItemButton_CalculateItemTooltipAnchors",
            function(itemButton, mainTooltip)
                local anchor = itemButton
                    and itemButton.KamiContainerTooltipAnchor

                if not anchor
                    or not mainTooltip
                    or mainTooltip ~= GameTooltip
                then
                    return
                end

                mainTooltip:SetOwner(itemButton, anchor)
            end
        )
    end

    self:StyleItemSlot(button, options)

    return button
end

function Components:CreateItemDisplayButton(parent, options)
    options = options or {}
    options.count = options.count ~= false
    options.createIcon = true

    local button = self:CreateItemSlot(parent, options)

    button:SetScript("OnEnter", function(self)
        if not self.itemTooltip
            and not self.itemLink
            and not self.itemID
        then
            return
        end

        GameTooltip:SetOwner(
            self,
            options.tooltipAnchor or "ANCHOR_CURSOR_RIGHT"
        )

        local handled = false

        if self.itemTooltip then
            local ok, result = pcall(
                self.itemTooltip,
                GameTooltip,
                self
            )

            handled = ok and result ~= false
        end

        if not handled and self.itemLink then
            GameTooltip:SetHyperlink(self.itemLink)
            handled = true
        elseif not handled and self.itemID then
            if GameTooltip.SetItemByID then
                GameTooltip:SetItemByID(self.itemID)
            else
                GameTooltip:SetHyperlink(
                    "item:" .. tostring(self.itemID)
                )
            end

            handled = true
        end

        if handled then
            GameTooltip:Show()
        end
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

function Components:SetItemSlotData(button, data)
    if not button then
        return
    end

    data = data or {}

    local icon = GetItemSlotIcon(button)
    local alpha = data.alpha or 1

    button.itemID = data.itemID
    button.itemLink = data.link
    button.itemTooltip = data.tooltip
    button:SetAlpha(alpha)

    if icon then
        icon:SetTexture(data.icon)
        icon:SetAlpha(alpha)

        if icon.SetDesaturated then
            icon:SetDesaturated(data.desaturated == true)
        end
    end

    if button.Count then
        local count = data.count or 0
        local countText = data.countText

        if countText == nil then
            countText = count > 1 and tostring(count) or ""
        end

        button.Count:SetText(countText)
        button.Count:SetAlpha(alpha)

        if data.countColor then
            Styles:SetTextColor(button.Count, data.countColor)
        else
            Styles:SetTextColor(button.Count, Palette.text)
        end

        button.Count:Show()
    end

    if button.label then
        button.label:SetShown(not data.icon)
    end

    if data.borderColor then
        self:SetItemSlotBorderColor(button, data.borderColor)
    end

    UpdateQuestItemDecoration(button, data)
    self:RefreshItemSlotQuality(button, data)
end

function Components:CreateCarrier(parent, id, shown)
    local carrier = CreateFrame("Frame", nil, parent)

    carrier:SetAllPoints(parent)

    if id ~= nil then
        carrier:SetID(id)
    end

    carrier:SetShown(shown ~= false)

    return carrier
end

function Components:SetContainerItemSlotData(
    button,
    bagID,
    slotID,
    options
)
    if not button then
        return nil
    end

    options = options or {}

    if button.SetBagID then
        button:SetBagID(bagID)
    elseif button.SetAttribute then
        button:SetAttribute("bagid", bagID)
    end

    button:SetID(slotID)

    if ContainerFrameItemButton_Update then
        ContainerFrameItemButton_Update(button)
    end

    self:SuppressItemButtonFlash(button)

    local info = UI:GetContainerItemInfo(bagID, slotID)
    local questInfo

    if info
        and C_Container
        and C_Container.GetContainerItemQuestInfo
    then
        questInfo = UI:SafeCall(
            C_Container.GetContainerItemQuestInfo,
            bagID,
            slotID
        )
    end

    local search = options.search or ""
    local filtered = info and info.isFiltered == true or false

    if info and search ~= "" then
        local itemName = info.itemName

        if not itemName and info.hyperlink and GetItemInfo then
            itemName = GetItemInfo(info.hyperlink)
        end

        local haystack = string.lower(
            itemName or info.hyperlink or ""
        )

        filtered = not string.find(
            haystack,
            string.lower(search),
            1,
            true
        )
    end

    self:SetItemSlotData(button, {
        link = info and info.hyperlink or nil,
        icon = info and info.iconFileID or nil,
        count = info and (info.stackCount or 1) or 0,
        quality = info and info.quality or nil,
        isQuestItem = questInfo and questInfo.isQuestItem,
        questID = questInfo and questInfo.questID,
        questActive = questInfo and questInfo.isActive,
        borderColor = options.borderColor,
        alpha = filtered and 0.20 or 1.00,
        desaturated = info and info.isLocked == true or false,
    })

    if button.Cooldown then
        if info
            and C_Container
            and C_Container.GetContainerItemCooldown
        then
            local start, duration, enable =
                C_Container.GetContainerItemCooldown(bagID, slotID)

            CooldownFrame_Set(
                button.Cooldown,
                start or 0,
                duration or 0,
                enable or 0
            )
        else
            button.Cooldown:Clear()
        end
    end

    return info
end

function Components:SetContainerSlotHighlight(
    buttons,
    bagID,
    shown
)
    for _, button in ipairs(buttons or {}) do
        if not button.KamiBagHighlight then
            local highlight = button:CreateTexture(
                nil,
                "ARTWORK",
                nil,
                7
            )
            highlight:SetPoint(
                "TOPLEFT",
                button,
                "TOPLEFT",
                1,
                -1
            )
            highlight:SetPoint(
                "BOTTOMRIGHT",
                button,
                "BOTTOMRIGHT",
                -1,
                1
            )
            highlight:SetColorTexture(1, 1, 1, 0.14)
            highlight:Hide()
            button.KamiBagHighlight = highlight
        end

        local buttonBagID = button.GetBagID
            and button:GetBagID()
            or button.bagID

        button.KamiBagHighlight:SetShown(
            shown and buttonBagID == bagID
        )
    end
end

function Components:LayoutItemGrid(buttons, parent, options)
    options = options or {}
    buttons = buttons or {}

    local columns = options.columns or 1
    local slotSize = options.slotSize or Styles.Metrics.itemSlotSize
    local spacing = options.spacing or 0
    local rows = math.max(1, math.ceil(#buttons / columns))

    for index, button in ipairs(buttons) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)

        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT",
            parent,
            "TOPLEFT",
            column * (slotSize + spacing),
            -row * (slotSize + spacing)
        )
    end

    local width = columns * slotSize
        + (columns - 1) * spacing
    local height = rows * slotSize
        + (rows - 1) * spacing

    return width, height, rows
end

