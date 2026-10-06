local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components

local function ResolveValue(value, ...)
    if type(value) == "function" then
        return value(...)
    end

    return value
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
    menu:SetWidth(
        options.width
        or options.minWidth
        or 50
    )

    if options.frameStrata then
        menu:SetFrameStrata(options.frameStrata)
    end

    if options.frameLevel then
        menu:SetFrameLevel(options.frameLevel)
    elseif parent and parent.GetFrameLevel then
        menu:SetFrameLevel(parent:GetFrameLevel() + 20)
    end

    if menu.SetClampedToScreen then
        menu:SetClampedToScreen(options.clampedToScreen ~= false)
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

    local background = button:CreateTexture(
        nil,
        "BACKGROUND",
        nil,
        -7
    )
    background:SetAllPoints()
    button.KamiPopupBackground = background

    Styles:SetColor(
        background,
        options.rowBackgroundColor or Palette.panel,
        options.rowBackgroundAlpha or 0
    )

    if options.rowBorder then
        Styles:CreateBorder(button, {
            key = "KamiPopupBorder",
            color = options.rowBorderColor or Palette.border,
        })
    end

    local label = button:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    label:SetPoint("LEFT", options.textInset or 3, 0)
    label:SetPoint("RIGHT", -(options.textInset or 3), 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
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

function Components:SetPopupMenuButtonSelected(
    button,
    selected,
    options
)
    if not button then
        return
    end

    options = options or {}

    local background = button.KamiPopupBackground

    if background then
        Styles:SetColor(
            background,
            selected
                and (options.selectedBackgroundColor
                    or Palette.panelStrong)
                or (options.rowBackgroundColor or Palette.panel),
            selected
                and (options.selectedBackgroundAlpha or 0)
                or (options.rowBackgroundAlpha or 0)
        )
    end

    if button.text then
        Styles:SetTextColor(
            button.text,
            selected
                and (options.selectedTextColor
                    or options.textColor
                    or Palette.text)
                or (options.textColor or Palette.text)
        )
    end
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

local function GetDropdownAnchor(direction, align)
    direction = direction == "up" and "up" or "down"
    align = align == "right" and "right" or "left"

    if direction == "up" then
        if align == "right" then
            return "BOTTOMRIGHT", "TOPRIGHT", 2
        end

        return "BOTTOMLEFT", "TOPLEFT", 2
    end

    if align == "right" then
        return "TOPRIGHT", "BOTTOMRIGHT", -2
    end

    return "TOPLEFT", "BOTTOMLEFT", -2
end

function Components:SetDropdownText(dropdown, text)
    if not dropdown or not dropdown.button then
        return
    end

    local options = dropdown.options or {}
    local suffix = ""

    if options.showArrow ~= false then
        suffix = options.arrowText

        if suffix == nil then
            suffix = options.direction == "up"
                and "  ^"
                or "  v"
        end
    end

    self:SetButtonText(
        dropdown.button,
        (text or "") .. suffix
    )
end

function Components:RefreshDropdown(dropdown)
    if not dropdown then
        return
    end

    local options = dropdown.options or {}

    if options.getButtonText then
        self:SetDropdownText(
            dropdown,
            options.getButtonText(dropdown)
        )
    elseif options.text ~= nil then
        self:SetDropdownText(dropdown, options.text)
    end

    local icon = dropdown.button
        and dropdown.button.icon

    if icon and options.getButtonIcon then
        icon:SetTexture(options.getButtonIcon(dropdown))
    end
end

function Components:CloseDropdown(dropdown)
    if not dropdown then
        return
    end

    if dropdown.menu then
        dropdown.menu:Hide()
    end

    if self.ActiveDropdown == dropdown then
        self.ActiveDropdown = nil
    end
end

function Components:CloseActiveDropdown(except)
    local dropdown = self.ActiveDropdown

    if dropdown and dropdown ~= except then
        self:CloseDropdown(dropdown)
    end
end

function Components:BuildDropdownMenu(dropdown)
    if not dropdown or not dropdown.menu then
        return 0
    end

    local options = dropdown.options or {}
    local entries = ResolveValue(
        options.getEntries,
        dropdown
    ) or options.entries or {}
    local count = 0
    local maxLabelWidth = 0
    local inset = options.inset or 4
    local textInset = options.textInset or 3
    local horizontalPadding =
        inset * 2 + textInset * 2 + 8

    for index, entry in ipairs(entries) do
        if not options.filter
            or options.filter(entry, index, dropdown)
        then
            count = count + 1

            local selected = options.isSelected
                and options.isSelected(entry, index, dropdown)
                or entry.selected == true
            local button = self:AcquirePopupMenuButton(
                dropdown.menu,
                count,
                options
            )

            local label

            if options.getText then
                label = options.getText(
                    entry,
                    index,
                    selected,
                    dropdown
                )
            else
                label = entry.text
                    or entry.label
                    or tostring(entry.value or entry)
            end

            button.text:SetText(label or "")
            self:SetPopupMenuButtonSelected(
                button,
                selected,
                options
            )

            if options.styleRow then
                options.styleRow(
                    button,
                    entry,
                    index,
                    selected,
                    dropdown
                )
            end

            local disabled = options.isDisabled
                and options.isDisabled(
                    entry,
                    index,
                    dropdown
                )
                or entry.disabled == true

            button:SetEnabled(not disabled)
            button:SetAlpha(
                disabled
                    and (options.disabledAlpha
                        or Styles.State.disabledAlpha)
                    or 1
            )

            button.dropdownEntry = entry
            button.dropdownIndex = index
            button:SetScript("OnClick", function(self)
                if not self:IsEnabled() then
                    return
                end

                Components:CloseDropdown(dropdown)

                if options.onSelect then
                    options.onSelect(
                        self.dropdownEntry,
                        self.dropdownIndex,
                        dropdown
                    )
                end

                Components:RefreshDropdown(dropdown)
            end)
            button:Show()

            local textWidth

            if button.text.GetUnboundedStringWidth then
                textWidth =
                    button.text:GetUnboundedStringWidth()
            elseif button.text.GetStringWidth then
                textWidth = button.text:GetStringWidth()
            end

            maxLabelWidth = math.max(
                maxLabelWidth,
                textWidth or 0
            )
        end
    end

    if options.menuWidth then
        dropdown.menu:SetWidth(options.menuWidth)
    else
        dropdown.menu:SetWidth(math.max(
            options.minWidth or 50,
            math.ceil(maxLabelWidth + horizontalPadding)
        ))
    end

    self:FinishPopupMenu(dropdown.menu, count)

    return count
end

function Components:ToggleDropdown(dropdown)
    if not dropdown or not dropdown.menu then
        return
    end

    if dropdown.menu:IsShown() then
        self:CloseDropdown(dropdown)
        return
    end

    self:CloseActiveDropdown(dropdown)

    local options = dropdown.options or {}

    if options.prepare then
        options.prepare(dropdown)
    end

    self:RefreshDropdown(dropdown)

    local count = self:BuildDropdownMenu(dropdown)

    if count == 0 and options.showWhenEmpty ~= true then
        return
    end

    dropdown.menu:Show()
    self.ActiveDropdown = dropdown
end

function Components:CreateDropdown(parent, options)
    options = options or {}

    local button = options.button

    if not button then
        button = CreateFrame(
            "Button",
            options.buttonName,
            options.buttonParent or parent
        )
        button:SetSize(
            options.buttonWidth or options.width or 80,
            options.buttonHeight or options.height or 20
        )

        if options.styleButton ~= false then
            self:StyleButton(button, {
                text = options.text or " ",
                backgroundColor = options.buttonBackgroundColor,
                backgroundAlpha = options.buttonBackgroundAlpha,
                borderColor = options.buttonBorderColor,
                textColor = options.buttonTextColor,
                textRole = options.buttonTextRole or "normal",
            })
        end
    end

    if options.icon or options.getButtonIcon then
        local icon = button.icon

        if not icon then
            icon = button:CreateTexture(nil, "ARTWORK")
            button.icon = icon
        end

        local iconInset = options.iconInset or 0
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

        if options.icon then
            icon:SetTexture(options.icon)
        end

        local texCoord = options.iconTexCoord

        if texCoord then
            icon:SetTexCoord(
                texCoord[1],
                texCoord[2],
                texCoord[3],
                texCoord[4]
            )
        end
    end

    local point, relativePoint, defaultY =
        GetDropdownAnchor(
            options.direction,
            options.align
        )
    local menu = self:CreatePopupMenu(
        options.menuParent or parent,
        options.anchor or button,
        {
            name = options.menuName,
            point = options.menuPoint or point,
            relativePoint =
                options.menuRelativePoint or relativePoint,
            x = options.menuX or 0,
            y = options.menuY or defaultY,
            width = options.menuWidth,
            minWidth = options.minWidth,
            rowHeight = options.rowHeight,
            inset = options.inset,
            textInset = options.textInset,
            heightPadding = options.heightPadding,
            minHeight = options.minHeight,
            frameStrata = options.menuFrameStrata,
            frameLevel = options.menuFrameLevel,
            backgroundColor = options.backgroundColor,
            borderColor = options.borderColor,
            fontSize = options.fontSize,
            textColor = options.textColor,
            highlightAlpha = options.highlightAlpha,
            clampedToScreen = options.clampedToScreen,
        }
    )

    local dropdown = {
        parent = parent,
        button = button,
        menu = menu,
        options = options,
    }

    button.KamiDropdown = dropdown
    menu.KamiDropdown = dropdown

    button:SetScript("OnClick", function()
        Components:ToggleDropdown(dropdown)
    end)

    menu:HookScript("OnHide", function()
        if Components.ActiveDropdown == dropdown then
            Components.ActiveDropdown = nil
        end
    end)

    local closeWith = options.closeWith or parent

    if closeWith and closeWith.HookScript then
        closeWith:HookScript("OnHide", function()
            Components:CloseDropdown(dropdown)
        end)
    end

    self:RefreshDropdown(dropdown)

    return dropdown
end

function Components:CreateCharacterDropdown(parent, options)
    options = options or {}

    local config = {}

    for key, value in pairs(options) do
        config[key] = value
    end

    local getCharacter = options.getCharacter
    local selectedKey = options.selectedKey
    local onSelect = options.onSelect

    config.icon = config.icon
        or "Interface\\Icons\\INV_Misc_GroupLooking"
    config.showArrow = false

    config.isSelected = function(entry)
        local key = ResolveValue(selectedKey)

        return entry
            and entry.key ~= nil
            and entry.key == key
    end

    config.getText = function(entry, _, selected)
        local character

        if getCharacter then
            character = getCharacter(entry)
        else
            character = entry.character
                or entry.profile
                or {}
        end

        return Components:FormatCharacterLabel(
            character,
            {
                selected =
                    options.showSelected ~= false
                    and selected,
                selectedPrefix = options.selectedPrefix,
                showRealm = options.showRealm,
            }
        )
    end

    config.onSelect = function(entry)
        if onSelect then
            onSelect(entry.key, entry)
        end
    end

    return self:CreateDropdown(parent, config)
end
