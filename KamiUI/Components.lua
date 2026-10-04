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
