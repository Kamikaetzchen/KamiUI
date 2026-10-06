local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components
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

function Components:BuildCharacterMenu(menu, entries, options)
    if not menu then
        return 0
    end

    entries = entries or {}
    options = options or {}

    local selectedKey = options.selectedKey

    if type(selectedKey) == "function" then
        selectedKey = selectedKey()
    end

    local count = 0
    local popupOptions = menu.KamiPopupOptions or {}
    local minWidth = options.minWidth
        or popupOptions.minWidth
        or 50
    local maxLabelWidth = 0
    local inset = popupOptions.inset or 4
    local textInset = popupOptions.textInset or 3
    local horizontalPadding =
        inset * 2 + textInset * 2 + 8

    for _, entry in ipairs(entries) do
        if not options.filter or options.filter(entry) then
            count = count + 1

            local button = self:AcquirePopupMenuButton(
                menu,
                count
            )
            local character

            if options.getCharacter then
                character = options.getCharacter(entry)
            else
                character = entry.character
                    or entry.profile
                    or {}
            end

            button.text:SetText(
                self:FormatCharacterLabel(
                    character,
                    {
                        selected =
                            options.showSelected ~= false
                            and entry.key == selectedKey,
                        selectedPrefix =
                            options.selectedPrefix,
                        showRealm = options.showRealm,
                    }
                )
            )
            button.characterKey = entry.key
            button.characterEntry = entry
            button:SetScript("OnClick", function(self)
                menu:Hide()

                if options.onSelect then
                    options.onSelect(
                        self.characterKey,
                        self.characterEntry
                    )
                end
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

    menu:SetWidth(math.max(
        minWidth,
        math.ceil(maxLabelWidth + horizontalPadding)
    ))

    self:FinishPopupMenu(menu, count, options.menuOptions)

    return count
end

function Components:BindCharacterMenu(button, menu, options)
    if not button or not menu then
        return
    end

    options = options or {}

    button:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
            return
        end

        if options.prepare then
            options.prepare()
        end

        local entries = options.getEntries
            and options.getEntries()
            or options.entries
            or {}

        Components:BuildCharacterMenu(
            menu,
            entries,
            options
        )
        menu:Show()
    end)
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

