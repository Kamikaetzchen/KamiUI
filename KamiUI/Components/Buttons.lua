local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components
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
        self:_NeutralizeTexture(button[key])
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
                self:_NeutralizeTexture(texture)
            end
        end
    end
end

function Components:SetButtonText(button, text)
    if not button then
        return
    end

    if button.KamiButtonText then
        button.KamiButtonText:SetText(text or "")
    elseif button.SetText then
        button:SetText(text or "")
    elseif button.Text and button.Text.SetText then
        button.Text:SetText(text or "")
    end

    if button.RefreshKamiButtonStyle then
        button:RefreshKamiButtonStyle()
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

function Components:StyleCloseButton(button, options)
    if not button then
        return nil
    end

    options = options or {}
    self:ClearButtonArt(button)

    local label = button.GetFontString
        and button:GetFontString()
        or button.Text

    if label then
        label:SetText("")
        label:Hide()
    end

    local art = button.KamiCloseButtonArt

    if not art then
        art = CreateFrame("Frame", nil, button)
        art:EnableMouse(false)
        button.KamiCloseButtonArt = art
    end

    local artSize = options.artSize or 14
    art:ClearAllPoints()
    art:SetPoint("CENTER")
    art:SetSize(artSize, artSize)

    local background = button.KamiCloseButtonBackground

    if not background then
        background = art:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        button.KamiCloseButtonBackground = background
    end

    background:SetColorTexture(0, 0, 0, 0.55)

    Styles:CreateBorder(art, {
        key = "KamiCloseButtonBorder",
        color = options.borderColor
            or { 0.22, 0.22, 0.24, 1 },
    })

    local crossSize = options.crossSize or 8
    local crossThickness = options.crossThickness or 1.5
    local crossInset = math.max(0, (artSize - crossSize) / 2)
    local crossA = button.KamiCloseButtonCrossA
    local crossB = button.KamiCloseButtonCrossB

    if not crossA then
        crossA = art:CreateLine(nil, "ARTWORK")
        button.KamiCloseButtonCrossA = crossA
    end

    if not crossB then
        crossB = art:CreateLine(nil, "ARTWORK")
        button.KamiCloseButtonCrossB = crossB
    end

    crossA:ClearAllPoints()
    crossA:SetStartPoint(
        "TOPLEFT",
        art,
        "TOPLEFT",
        crossInset,
        -crossInset
    )
    crossA:SetEndPoint(
        "BOTTOMRIGHT",
        art,
        "BOTTOMRIGHT",
        -crossInset,
        crossInset
    )
    crossA:SetThickness(crossThickness)

    crossB:ClearAllPoints()
    crossB:SetStartPoint(
        "TOPRIGHT",
        art,
        "TOPRIGHT",
        -crossInset,
        -crossInset
    )
    crossB:SetEndPoint(
        "BOTTOMLEFT",
        art,
        "BOTTOMLEFT",
        crossInset,
        crossInset
    )
    crossB:SetThickness(crossThickness)

    local highlight = button.KamiCloseButtonHighlight

    if not highlight then
        highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(art)
        button.KamiCloseButtonHighlight = highlight
    end

    Styles:SetColor(
        highlight,
        Palette.white,
        options.hoverAlpha or 0.08
    )

    button.KamiCloseButtonOptions = options

    function button:RefreshKamiCloseButtonStyle()
        local config = self.KamiCloseButtonOptions or {}
        local enabled = not self.IsEnabled or self:IsEnabled()
        local color = enabled
            and (
                config.crossColor
                or Palette.difficulty.veryHard
            )
            or (
                config.disabledCrossColor
                or Palette.difficulty.veryHard
            )

        Styles:SetColor(self.KamiCloseButtonCrossA, color)
        Styles:SetColor(self.KamiCloseButtonCrossB, color)
        self:SetAlpha(
            enabled
                and 1
                or Styles.State.disabledAlpha
        )
    end

    if not button.KamiCloseButtonStateHooked then
        button.KamiCloseButtonStateHooked = true

        button:HookScript("OnEnable", function(self)
            self:RefreshKamiCloseButtonStyle()
        end)

        button:HookScript("OnDisable", function(self)
            self:RefreshKamiCloseButtonStyle()
        end)

        button:HookScript("OnShow", function(self)
            self:RefreshKamiCloseButtonStyle()
        end)
    end

    button:RefreshKamiCloseButtonStyle()

    return button
end

