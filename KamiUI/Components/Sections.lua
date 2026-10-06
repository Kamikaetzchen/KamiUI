local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components
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

