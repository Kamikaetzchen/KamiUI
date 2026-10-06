local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components
local function GetItemSlotIcon(button)
    return button and (button.icon or button.Icon) or nil
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

    local size = options.size or 36
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
        local rarityGlow = button:CreateTexture(
            nil,
            "OVERLAY",
            nil,
            1
        )
        rarityGlow:SetPoint("CENTER", button, "CENTER", 1, 0)
        rarityGlow:SetSize(size + 26, size + 26)
        rarityGlow:SetTexture(
            "Interface\\Buttons\\UI-ActionButton-Border"
        )
        rarityGlow:SetBlendMode("ADD")
        rarityGlow:SetAlpha(options.rarityAlpha or 0.45)
        rarityGlow:Hide()
        button.KamiRarityGlow = rarityGlow
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

    self:StyleItemSlot(button, options)

    return button
end

function Components:CreateCachedItemButton(parent, options)
    options = options or {}
    options.count = options.count ~= false
    options.createIcon = true

    local button = self:CreateItemSlot(parent, options)

    button:SetScript("OnEnter", function(self)
        if not self.itemLink then
            return
        end

        GameTooltip:SetOwner(
            self,
            options.tooltipAnchor or "ANCHOR_RIGHT"
        )
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()
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

    button.itemLink = data.link
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

    self:SetItemSlotQuality(button, data.quality)
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

