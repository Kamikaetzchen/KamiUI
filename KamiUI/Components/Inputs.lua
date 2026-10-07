local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components
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
            Components:_NeutralizeTexture(input[key])
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

local function CreateToggleControl(parent, kind, options)
    options = options or {}

    local button = CreateFrame("CheckButton", nil, parent)
    local size = options.size or 14
    local labelSide = options.labelSide or "RIGHT"
    local labelGap = options.labelGap or 6

    button:SetSize(
        options.width or size,
        options.height or size
    )
    button.KamiToggleKind = kind
    button.KamiToggleOptions = options

    local art = CreateFrame("Frame", nil, button)
    art:SetSize(size, size)
    art:EnableMouse(false)

    if options.label then
        if labelSide == "LEFT" then
            art:SetPoint("RIGHT", button, "RIGHT", 0, 0)
        else
            art:SetPoint("LEFT", button, "LEFT", 0, 0)
        end
    else
        art:SetPoint("CENTER", button, "CENTER", 0, 0)
    end

    button.KamiToggleArt = art

    local checked

    if kind == "radio" then
        local normal = art:CreateTexture(nil, "BACKGROUND")
        normal:SetAllPoints()
        normal:SetTexture("Interface\\Buttons\\UI-RadioButton")
        normal:SetTexCoord(0, 0.25, 0, 1)

        checked = art:CreateTexture(nil, "ARTWORK")
        checked:SetAllPoints()
        checked:SetTexture("Interface\\Buttons\\UI-RadioButton")
        checked:SetTexCoord(0.25, 0.5, 0, 1)

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(art)
        highlight:SetTexture("Interface\\Buttons\\UI-RadioButton")
        highlight:SetTexCoord(0.5, 0.75, 0, 1)
        highlight:SetBlendMode("ADD")
    else
        local background = art:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        Styles:SetColor(
            background,
            options.backgroundColor or Palette.panelStrong
        )

        Styles:CreateBorder(art, {
            key = "KamiToggleBorder",
            color = options.borderColor or Palette.border,
        })

        checked = art:CreateTexture(nil, "ARTWORK")
        checked:SetPoint("TOPLEFT", art, "TOPLEFT", 1, -1)
        checked:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", -1, 1)
        checked:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        Styles:SetColor(
            checked,
            options.checkedColor or Palette.highlight
        )

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(art)
        Styles:SetColor(
            highlight,
            Palette.white,
            options.hoverAlpha or Styles.State.hoverAlpha
        )
    end

    checked:Hide()
    button.KamiToggleChecked = checked

    if options.label then
        local label = button:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormalSmall"
        )

        if labelSide == "LEFT" then
            label:SetPoint(
                "RIGHT",
                art,
                "LEFT",
                -labelGap,
                0
            )
            label:SetPoint("LEFT", button, "LEFT", 0, 0)
            label:SetJustifyH("RIGHT")
        else
            label:SetPoint(
                "LEFT",
                art,
                "RIGHT",
                labelGap,
                0
            )
            label:SetPoint("RIGHT", button, "RIGHT", 0, 0)
            label:SetJustifyH("LEFT")
        end

        Styles:ApplyText(
            label,
            options.textRole or "normal",
            options.textColor or Palette.muted
        )
        label:SetText(options.label)
        button.KamiToggleLabel = label
        button.label = label
    end

    function button:RefreshKamiToggleStyle()
        local config = self.KamiToggleOptions or {}
        local isChecked = self.GetChecked and self:GetChecked()
        local enabled = not self.IsEnabled or self:IsEnabled()

        self.KamiToggleChecked:SetShown(isChecked == true)
        self:SetAlpha(
            enabled
                and 1
                or Styles.State.disabledAlpha
        )

        if self.KamiToggleLabel then
            Styles:ApplyText(
                self.KamiToggleLabel,
                config.textRole or "normal",
                enabled
                    and (config.textColor or Palette.muted)
                    or (config.disabledTextColor or Palette.muted)
            )
        end
    end

    button:HookScript("OnClick", function(self)
        self:RefreshKamiToggleStyle()
    end)
    button:HookScript("OnEnable", function(self)
        self:RefreshKamiToggleStyle()
    end)
    button:HookScript("OnDisable", function(self)
        self:RefreshKamiToggleStyle()
    end)
    button:HookScript("OnShow", function(self)
        self:RefreshKamiToggleStyle()
    end)

    button:RefreshKamiToggleStyle()

    return button
end

function Components:CreateCheckbox(parent, options)
    return CreateToggleControl(parent, "checkbox", options)
end

function Components:CreateRadioButton(parent, options)
    return CreateToggleControl(parent, "radio", options)
end

function Components:SetToggleState(button, checked, enabled)
    if not button then
        return
    end

    if button.SetChecked then
        button:SetChecked(checked == true)
    end

    if enabled == false then
        button:Disable()
    else
        button:Enable()
    end

    if button.RefreshKamiToggleStyle then
        button:RefreshKamiToggleStyle()
    end
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

