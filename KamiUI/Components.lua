local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles

local Components = {}
UI.Components = Components

local function SetTabBackground(tab, color, alpha)
    for _, texture in ipairs(tab.backgrounds or {}) do
        Styles:SetColor(texture, color, alpha)
    end
end

local function CreateChamferedTabVisual(tab, orientation, chamfer, borderColor)
    local backgrounds = {}

    if orientation == "top" then
        local lower = tab:CreateTexture(nil, "BACKGROUND")
        lower:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
        lower:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
        lower:SetPoint("TOP", tab, "TOP", 0, -chamfer)
        backgrounds[#backgrounds + 1] = lower

        for row = 0, chamfer - 1 do
            local inset = chamfer - row
            local strip = tab:CreateTexture(nil, "BACKGROUND")
            strip:SetPoint("TOPLEFT", tab, "TOPLEFT", inset, -row)
            strip:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -inset, -row)
            strip:SetHeight(1)
            backgrounds[#backgrounds + 1] = strip
        end
    else
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
    end

    tab.backgrounds = backgrounds

    local borders = {}

    local top = tab:CreateTexture(nil, "OVERLAY")
    local bottom = tab:CreateTexture(nil, "OVERLAY")
    local left = tab:CreateTexture(nil, "OVERLAY")
    local right = tab:CreateTexture(nil, "OVERLAY")

    if orientation == "top" then
        top:SetPoint("TOPLEFT", tab, "TOPLEFT", chamfer, 0)
        top:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -chamfer, 0)
        bottom:SetPoint("BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT")
        left:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, -chamfer)
        left:SetPoint("BOTTOMLEFT")
        right:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, -chamfer)
        right:SetPoint("BOTTOMRIGHT")
    else
        top:SetPoint("TOPLEFT")
        top:SetPoint("TOPRIGHT")
        bottom:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", chamfer, 0)
        bottom:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -chamfer, 0)
        left:SetPoint("TOPLEFT")
        left:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, chamfer)
        right:SetPoint("TOPRIGHT")
        right:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, chamfer)
    end

    top:SetHeight(1)
    bottom:SetHeight(1)
    left:SetWidth(1)
    right:SetWidth(1)

    Styles:SetColor(top, borderColor)
    Styles:SetColor(bottom, borderColor)
    Styles:SetColor(left, borderColor)
    Styles:SetColor(right, borderColor)

    borders[1] = top
    borders[2] = bottom
    borders[3] = left
    borders[4] = right

    for step = 1, chamfer do
        local first = tab:CreateTexture(nil, "OVERLAY")
        local second = tab:CreateTexture(nil, "OVERLAY")

        if orientation == "top" then
            first:SetPoint(
                "TOPLEFT",
                tab,
                "TOPLEFT",
                step - 1,
                -(chamfer - step)
            )
            second:SetPoint(
                "TOPRIGHT",
                tab,
                "TOPRIGHT",
                -(step - 1),
                -(chamfer - step)
            )
        else
            first:SetPoint(
                "BOTTOMLEFT",
                tab,
                "BOTTOMLEFT",
                step - 1,
                chamfer - step
            )
            second:SetPoint(
                "BOTTOMRIGHT",
                tab,
                "BOTTOMRIGHT",
                -(step - 1),
                chamfer - step
            )
        end

        first:SetSize(1, 1)
        second:SetSize(1, 1)
        Styles:SetColor(first, borderColor)
        Styles:SetColor(second, borderColor)
    end

    tab.borders = borders
end

function Components:StyleTab(tab, options)
    if not tab then
        return nil
    end

    options = options or {}

    local orientation = options.orientation == "top"
        and "top"
        or "bottom"
    local chamfer = options.chamfer or Styles.Metrics.chamfer
    local borderColor = options.borderColor or Palette.border

    if not tab.KamiTabStyled then
        tab.KamiTabStyled = true
        tab.KamiTabOrientation = orientation
        CreateChamferedTabVisual(
            tab,
            orientation,
            chamfer,
            borderColor
        )
    end

    tab.KamiTabOptions = options
    tab:SetNormalFontObject(
        options.normalFontObject or "GameFontNormalSmall"
    )
    tab:SetHighlightFontObject(
        options.highlightFontObject or "GameFontHighlightSmall"
    )

    if options.text then
        tab:SetText(options.text)
    end

    if options.joinLeft
        and tab.borders
        and tab.borders[3]
    then
        tab.borders[3]:Hide()
    end

    self:SetTabState(
        tab,
        options.active == true,
        options.enabled ~= false
    )

    return tab
end

function Components:CreateTab(parent, options)
    options = options or {}

    local tab = CreateFrame(
        "Button",
        options.name,
        parent
    )

    tab:SetSize(
        options.width or 76,
        options.height or Styles.Metrics.tabHeight
    )

    if options.frameLevel then
        tab:SetFrameLevel(options.frameLevel)
    end

    return self:StyleTab(tab, options)
end

function Components:SetTabState(tab, active, enabled)
    if not tab then
        return
    end

    enabled = enabled ~= false

    SetTabBackground(
        tab,
        active and { 0.04, 0.04, 0.05, 1.00 } or Palette.black,
        active and Styles.State.activeAlpha
            or Styles.State.normalAlpha
    )

    local connectedBorder = tab.KamiTabOrientation == "top"
        and tab.borders
        and tab.borders[2]
        or tab.borders
        and tab.borders[1]

    if connectedBorder then
        connectedBorder:SetShown(not active)
    end

    local text = tab:GetFontString()

    if text then
        Styles:ApplyText(
            text,
            active and "tabActive" or "tabInactive"
        )
    end

    tab:SetEnabled(enabled)
    tab:SetAlpha(enabled and 1 or Styles.State.disabledAlpha)
end

local function NeutralizeTexture(texture)
    if not texture then
        return
    end

    if texture.SetColorTexture then
        pcall(
            texture.SetColorTexture,
            texture,
            0,
            0,
            0,
            0
        )
    end

    if texture.SetAlpha then
        texture:SetAlpha(0)
    end

    if texture.Hide then
        texture:Hide()
    end
end

function Components:ClearButtonArt(button)
    if not button then
        return
    end

    for _, key in ipairs({
        "Left",
        "Middle",
        "Center",
        "Right",
        "Top",
        "Bottom",
        "TopLeft",
        "TopRight",
        "BottomLeft",
        "BottomRight",
        "Background",
        "Border",
        "NormalTexture",
        "PushedTexture",
        "HighlightTexture",
        "DisabledTexture",
    }) do
        NeutralizeTexture(button[key])
    end

    local textureMethods = {
        { "SetNormalTexture", "GetNormalTexture" },
        { "SetPushedTexture", "GetPushedTexture" },
        { "SetHighlightTexture", "GetHighlightTexture" },
        { "SetDisabledTexture", "GetDisabledTexture" },
    }

    for _, methods in ipairs(textureMethods) do
        local setter = button[methods[1]]
        local getter = button[methods[2]]

        if setter then
            pcall(
                setter,
                button,
                "Interface\\Buttons\\WHITE8X8"
            )
        end

        if getter then
            local ok, texture = pcall(getter, button)

            if ok then
                NeutralizeTexture(texture)
            end
        end
    end
end

function Components:StyleButton(button, options)
    if not button then
        return nil
    end

    options = options or {}
    self:ClearButtonArt(button)

    local background = button.KamiButtonBackground

    if not background then
        background = button:CreateTexture(
            nil,
            "BACKGROUND",
            nil,
            -7
        )
        background:SetAllPoints()
        button.KamiButtonBackground = background
    end

    Styles:SetColor(
        background,
        options.backgroundColor or Palette.panelStrong,
        options.backgroundAlpha
    )

    Styles:CreateBorder(button, {
        key = "KamiButtonBorder",
        color = options.borderColor or Palette.border,
    })

    local highlight = button.KamiButtonHighlight

    if not highlight then
        highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        button.KamiButtonHighlight = highlight
    end

    Styles:SetColor(
        highlight,
        Palette.white,
        options.hoverAlpha or Styles.State.hoverAlpha
    )

    local text = button.GetFontString
        and button:GetFontString()
        or button.Text

    if options.text then
        if text and button.SetText then
            button:SetText(options.text)
        elseif not button.KamiButtonText then
            local customText = button:CreateFontString(
                nil,
                "OVERLAY",
                "GameFontNormalSmall"
            )
            customText:SetPoint("CENTER")
            Styles:ApplyText(
                customText,
                options.textRole or "normal",
                options.textColor or Palette.text
            )
            customText:SetText(options.text)
            button.KamiButtonText = customText
        else
            button.KamiButtonText:SetText(options.text)
        end
    end

    button.KamiButtonOptions = options

    function button:RefreshKamiButtonStyle()
        Components:ClearButtonArt(self)

        local config = self.KamiButtonOptions or {}
        local enabled = not self.IsEnabled or self:IsEnabled()
        local label = self.GetFontString
            and self:GetFontString()
            or self.Text
            or self.KamiButtonText

        if label then
            Styles:ApplyText(
                label,
                config.textRole or "normal",
                enabled
                    and (config.textColor or Palette.text)
                    or (config.disabledTextColor or Palette.muted)
            )
        end

        self:SetAlpha(
            enabled
                and 1
                or Styles.State.disabledAlpha
        )
    end

    if not button.KamiButtonStateHooked then
        button.KamiButtonStateHooked = true

        button:HookScript("OnEnable", function(self)
            self:RefreshKamiButtonStyle()
        end)

        button:HookScript("OnDisable", function(self)
            self:RefreshKamiButtonStyle()
        end)

        button:HookScript("OnShow", function(self)
            self:RefreshKamiButtonStyle()
        end)

        button:HookScript("OnMouseDown", function(self)
            self:RefreshKamiButtonStyle()
        end)

        button:HookScript("OnMouseUp", function(self)
            self:RefreshKamiButtonStyle()
        end)
    end

    button:RefreshKamiButtonStyle()

    return button
end

function Components:StyleInput(input, options)
    if not input then
        return nil
    end

    options = options or {}

    local function ClearNativeInputArt()
        for _, key in ipairs({
            "Left",
            "Middle",
            "Right",
            "FocusLeft",
            "FocusMiddle",
            "FocusMid",
            "FocusRight",
        }) do
            NeutralizeTexture(input[key])
        end
    end

    ClearNativeInputArt()

    Styles:EnsureBackground(
        input,
        "KamiInputBackground",
        options.backgroundColor or Palette.panelStrong,
        "BACKGROUND",
        -7
    )

    Styles:CreateBorder(input, {
        key = "KamiInputBorder",
        color = options.borderColor or Palette.border,
    })

    Styles:ApplyText(
        input,
        options.textRole or "normal",
        options.textColor or Palette.text
    )

    if input.Instructions then
        Styles:ApplyText(
            input.Instructions,
            "muted",
            Palette.muted
        )
    end

    if not input.KamiInputStyleHooked then
        input.KamiInputStyleHooked = true

        for _, script in ipairs({
            "OnShow",
            "OnEnable",
            "OnDisable",
            "OnEditFocusGained",
            "OnEditFocusLost",
        }) do
            input:HookScript(script, function()
                ClearNativeInputArt()
            end)
        end
    end

    return input
end

function Components:StyleScrollBar(scrollbar, options)
    if not scrollbar then
        return nil
    end

    options = options or {}

    local width = options.width or 6
    local trackColor = options.trackColor
        or Palette.scrollbar.track
    local thumbColor = options.thumbColor
        or Palette.scrollbar.thumb
    local thumb

    if scrollbar.SetWidth then
        scrollbar:SetWidth(width)
    end

    local nativeTrack = scrollbar.Track
    local nativeThumb = nativeTrack and nativeTrack.Thumb

    if nativeTrack and nativeThumb then
        -- MinimalScrollBar's thumb mixin reads the current atlas in
        -- OnSizeChanged(). Do not replace these textures with color
        -- textures; keeping the atlases intact avoids breaking Blizzard's
        -- size calculations while alpha 0 removes the native art.
        for _, texture in pairs({
            nativeTrack.Begin,
            nativeTrack.Middle,
            nativeTrack.End,
            nativeThumb.Begin,
            nativeThumb.Middle,
            nativeThumb.End,
            scrollbar.Back and scrollbar.Back.Texture,
            scrollbar.Forward and scrollbar.Forward.Texture,
        }) do
            if texture and texture.SetAlpha then
                texture:SetAlpha(0)
            end
        end

        nativeTrack:ClearAllPoints()
        nativeTrack:SetPoint("TOP", scrollbar, "TOP", 0, 0)
        nativeTrack:SetPoint("BOTTOM", scrollbar, "BOTTOM", 0, 0)
        nativeTrack:SetWidth(width)

        local track = scrollbar.KamiScrollTrack

        if not track then
            track = nativeTrack:CreateTexture(nil, "BACKGROUND")
            track:SetAllPoints(nativeTrack)
            scrollbar.KamiScrollTrack = track
        end

        Styles:SetColor(track, trackColor)

        nativeThumb:SetWidth(width)

        thumb = scrollbar.KamiScrollThumb

        if not thumb then
            thumb = nativeThumb:CreateTexture(nil, "ARTWORK")
            thumb:SetAllPoints(nativeThumb)
            scrollbar.KamiScrollThumb = thumb
        end

        Styles:SetColor(thumb, thumbColor)
    elseif scrollbar.SetThumbTexture then
        local track = scrollbar.KamiScrollTrack

        if not track then
            track = scrollbar:CreateTexture(nil, "BACKGROUND")
            track:SetAllPoints(scrollbar)
            scrollbar.KamiScrollTrack = track
        end

        Styles:SetColor(track, trackColor)

        scrollbar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        thumb = scrollbar:GetThumbTexture()

        if thumb then
            thumb:SetWidth(width)
            Styles:SetColor(thumb, thumbColor)
        end
    end

    if not scrollbar.KamiScrollBarStyleHooked
        and scrollbar.HookScript
    then
        scrollbar.KamiScrollBarStyleHooked = true

        scrollbar:HookScript("OnShow", function(self)
            Components:StyleScrollBar(
                self,
                self.KamiScrollBarOptions
            )
        end)
    end

    scrollbar.KamiScrollBarOptions = options

    return scrollbar, thumb
end

local function ConfigureCheckboxTexture(
    texture,
    button,
    size,
    color,
    alpha
)
    if not texture then
        return
    end

    texture:ClearAllPoints()
    texture:SetPoint("CENTER", button, "CENTER", 0, 0)
    texture:SetSize(size, size)
    Styles:SetColor(texture, color, alpha)
end

function Components:StyleCheckbox(button, options)
    if not button then
        return nil
    end

    options = options or {}
    local texturePath = "Interface\\Buttons\\WHITE8X8"

    local function SetTexture(setterName, getterName, size, color, alpha)
        local setter = button[setterName]
        local getter = button[getterName]

        if not setter or not getter then
            return
        end

        pcall(setter, button, texturePath)

        local ok, texture = pcall(getter, button)

        if ok then
            ConfigureCheckboxTexture(
                texture,
                button,
                size,
                color,
                alpha
            )
        end
    end

    SetTexture(
        "SetNormalTexture",
        "GetNormalTexture",
        14,
        options.backgroundColor or Palette.panelStrong
    )
    SetTexture(
        "SetPushedTexture",
        "GetPushedTexture",
        14,
        Palette.white,
        0.08
    )
    SetTexture(
        "SetHighlightTexture",
        "GetHighlightTexture",
        14,
        Palette.white,
        options.hoverAlpha or Styles.State.hoverAlpha
    )
    SetTexture(
        "SetDisabledTexture",
        "GetDisabledTexture",
        14,
        Palette.panelStrong,
        Styles.State.disabledAlpha
    )
    SetTexture(
        "SetCheckedTexture",
        "GetCheckedTexture",
        8,
        options.checkedColor or Palette.gold
    )

    if not button.KamiCheckboxBorder then
        local border = CreateFrame("Frame", nil, button)
        border:SetSize(14, 14)
        border:SetPoint("CENTER")
        border:SetFrameLevel(button:GetFrameLevel() + 1)
        border:EnableMouse(false)
        Styles:CreateBorder(border)
        button.KamiCheckboxBorder = border
    end

    local label = button.text or button.Text

    if label then
        Styles:ApplyText(
            label,
            options.textRole or "normal",
            options.textColor or Palette.muted
        )
    end

    return button
end

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

    button.KamiBorders = Styles:CreateBorder(button, {
        color = options.borderColor or Palette.slotBorder,
    })

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

        button.Count:SetText(count > 1 and count or "")
        button.Count:SetAlpha(alpha)
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

function Components:FormatCharacterLabel(character, options)
    options = options or {}
    character = character or {}

    local label = character.name or "Unknown"

    if options.selected then
        label = (options.selectedPrefix or "> ") .. label
    end

    local color = Palette:GetClassColor(character.classFile)

    if color then
        local r = color.r or color[1] or 1
        local g = color.g or color[2] or 1
        local b = color.b or color[3] or 1

        label = string.format(
            "|cff%02x%02x%02x%s|r",
            math.floor(r * 255 + 0.5),
            math.floor(g * 255 + 0.5),
            math.floor(b * 255 + 0.5),
            label
        )
    end

    if options.showRealm ~= false
        and character.realm
        and character.realm ~= ""
        and character.realm ~= (GetRealmName and GetRealmName() or "")
    then
        label = label .. " - " .. character.realm
    end

    return label
end

function Components:CreatePopupMenu(parent, anchor, options)
    options = options or {}

    local menu = CreateFrame(
        "Frame",
        options.name,
        parent,
        "BackdropTemplate"
    )

    menu:SetPoint(
        options.point or "TOPLEFT",
        anchor or parent,
        options.relativePoint or "BOTTOMLEFT",
        options.x or 0,
        options.y or -2
    )
    menu:SetWidth(options.width or 170)

    if options.frameStrata then
        menu:SetFrameStrata(options.frameStrata)
    end

    if options.frameLevel then
        menu:SetFrameLevel(options.frameLevel)
    elseif parent and parent.GetFrameLevel then
        menu:SetFrameLevel(parent:GetFrameLevel() + 20)
    end

    Styles:ApplyBackdrop(
        menu,
        options.backgroundColor or { 0, 0, 0, 0.95 },
        options.borderColor or Palette.border
    )

    menu.buttons = {}
    menu.KamiPopupOptions = options
    menu:Hide()

    return menu
end

function Components:AcquirePopupMenuButton(menu, index, options)
    if not menu or not index then
        return nil
    end

    options = options or menu.KamiPopupOptions or {}

    local button = menu.buttons[index]

    if button then
        return button
    end

    local rowHeight = options.rowHeight or 20
    local inset = options.inset or 4

    button = CreateFrame("Button", nil, menu)
    button:SetHeight(rowHeight)
    button:SetPoint(
        "TOPLEFT",
        menu,
        "TOPLEFT",
        inset,
        -(inset + (index - 1) * rowHeight)
    )
    button:SetPoint(
        "TOPRIGHT",
        menu,
        "TOPRIGHT",
        -inset,
        -(inset + (index - 1) * rowHeight)
    )

    local label = button:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    label:SetPoint("LEFT", options.textInset or 3, 0)
    label:SetPoint("RIGHT", -(options.textInset or 3), 0)
    label:SetJustifyH("LEFT")
    Styles:ApplyText(
        label,
        options.fontSize or 9,
        options.textColor or Palette.text
    )
    button.text = label

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    Styles:SetColor(
        highlight,
        Palette.white,
        options.highlightAlpha or 0.08
    )

    menu.buttons[index] = button

    return button
end

function Components:FinishPopupMenu(menu, count, options)
    if not menu then
        return
    end

    options = options or menu.KamiPopupOptions or {}
    count = count or 0

    for index = count + 1, #menu.buttons do
        menu.buttons[index]:Hide()
    end

    local rowHeight = options.rowHeight or 20
    local padding = options.heightPadding
        or ((options.inset or 4) * 2)

    menu:SetHeight(math.max(
        options.minHeight or 28,
        padding + count * rowHeight
    ))
end

function Components:CreateSection(parent, options)
    options = options or {}

    local section = CreateFrame(
        options.button == false and "Frame" or "Button",
        options.name,
        parent
    )

    section:SetHeight(
        options.height or Styles.Metrics.sectionHeight
    )

    local inset = options.inset
        or Styles.Metrics.sectionInset

    local background = section:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", section, "TOPLEFT", inset, 0)
    background:SetPoint(
        "BOTTOMRIGHT",
        section,
        "BOTTOMRIGHT",
        -inset,
        0
    )
    Styles:SetColor(
        background,
        options.backgroundColor or Palette.white,
        options.backgroundAlpha or Styles.State.sectionAlpha
    )
    section.background = background

    local label = section:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", section, "LEFT", inset, 0)
    label:SetPoint("RIGHT", section, "RIGHT", -inset, 0)
    label:SetJustifyH(options.justifyH or "LEFT")
    Styles:ApplyText(
        label,
        options.textRole or "sectionTitle",
        options.textColor
    )
    section.label = label

    if options.highlight ~= false
        and options.button ~= false
    then
        local highlight = section:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetPoint("TOPLEFT", section, "TOPLEFT", inset, 0)
        highlight:SetPoint(
            "BOTTOMRIGHT",
            section,
            "BOTTOMRIGHT",
            -inset,
            0
        )
        Styles:SetColor(
            highlight,
            Palette.white,
            options.hoverAlpha or Styles.State.hoverAlpha
        )
        section.highlight = highlight
    end

    section.collapsible = options.collapsible == true
    section.sectionText = options.text or ""
    section.expanded = options.expanded ~= false
    section.collapsed = not section.expanded

    function section:SetSectionText(text)
        self.sectionText = text or ""
        self:RefreshSectionText()
    end

    function section:SetExpanded(expanded)
        self.expanded = expanded ~= false
        self.collapsed = not self.expanded
        self:RefreshSectionText()
    end

    function section:RefreshSectionText()
        local text = self.sectionText or ""

        if self.collapsible then
            text = string.format(
                "%s %s",
                self.expanded and "-" or "+",
                text
            )
        end

        self.label:SetText(text)
    end

    section:RefreshSectionText()

    return section
end

function Components:CreateWindowHeader(parent, options)
    options = options or {}

    local header = CreateFrame("Frame", nil, parent)
    local inset = options.inset or 1

    header:SetPoint(
        "TOPLEFT",
        parent,
        "TOPLEFT",
        inset,
        -inset
    )
    header:SetPoint(
        "TOPRIGHT",
        parent,
        "TOPRIGHT",
        -inset,
        -inset
    )
    header:SetHeight(options.height or 32)
    header:SetFrameLevel(parent:GetFrameLevel() + 1)

    Styles:EnsureBackground(
        header,
        "KamiHeaderBackground",
        options.backgroundColor or Palette.header,
        "BACKGROUND",
        -6
    )

    local title = header:CreateFontString(nil, "OVERLAY")
    Styles:ApplyText(
        title,
        options.titleRole or "windowTitle",
        options.titleColor
    )
    title:SetText(options.title or "")
    header.Title = title

    local subtitle = header:CreateFontString(nil, "OVERLAY")
    Styles:ApplyText(
        subtitle,
        options.subtitleRole or "windowSubtitle",
        options.subtitleColor
    )
    subtitle:SetText(options.subtitle or "")
    header.Subtitle = subtitle

    local hasSubtitle = options.hasSubtitle == true
        or (options.subtitle and options.subtitle ~= "")

    if hasSubtitle then
        title:SetPoint("TOP", header, "TOP", 0, -5)
        subtitle:SetPoint("TOP", title, "BOTTOM", 0, -1)
        subtitle:Show()
    else
        title:SetPoint("CENTER", header, "CENTER", 0, 0)
        subtitle:Hide()
    end

    local leftActions = CreateFrame("Frame", nil, header)
    leftActions:SetPoint("TOPLEFT")
    leftActions:SetPoint("BOTTOMLEFT")
    leftActions:SetWidth(options.actionWidth or 96)
    header.LeftActions = leftActions

    local rightActions = CreateFrame("Frame", nil, header)
    rightActions:SetPoint("TOPRIGHT")
    rightActions:SetPoint("BOTTOMRIGHT")
    rightActions:SetWidth(options.actionWidth or 96)
    header.RightActions = rightActions

    function header:SetTitle(text)
        self.Title:SetText(text or "")
    end

    function header:SetSubtitle(text)
        local value = text or ""
        self.Subtitle:SetText(value)

        if value ~= "" then
            self.Title:ClearAllPoints()
            self.Title:SetPoint("TOP", self, "TOP", 0, -5)
            self.Subtitle:ClearAllPoints()
            self.Subtitle:SetPoint("TOP", self.Title, "BOTTOM", 0, -1)
            self.Subtitle:Show()
        else
            self.Subtitle:Hide()
            self.Title:ClearAllPoints()
            self.Title:SetPoint("CENTER", self, "CENTER", 0, 0)
        end
    end

    if options.draggable then
        local dragTarget = options.dragTarget or parent

        header:EnableMouse(true)
        header:RegisterForDrag("LeftButton")
        header:SetScript("OnDragStart", function()
            dragTarget:StartMoving()
        end)
        header:SetScript("OnDragStop", function()
            dragTarget:StopMovingOrSizing()

            if options.onDragStop then
                options.onDragStop(dragTarget)
            end
        end)
    end

    parent.KamiHeader = header

    return header
end
