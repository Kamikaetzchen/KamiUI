local UI = KamiUI
local Palette = UI.Palette

local Styles = {}
UI.Styles = Styles

Styles.Metrics = {
    borderSize = 1,
    chamfer = 4,
    sectionHeight = 17,
    tabHeight = 22,
    sectionInset = 6,
}

Styles.State = {
    normalAlpha = 0.40,
    activeAlpha = 0.55,
    hoverAlpha = 0.06,
    selectedAlpha = 0.10,
    disabledAlpha = 0.45,
    sectionAlpha = 0.055,
}

Styles.Text = {
    windowTitle = {
        size = 13,
        color = Palette.gold,
    },
    windowSubtitle = {
        size = 10,
        color = Palette.muted,
    },
    panelTitle = {
        size = 11,
        color = Palette.gold,
    },
    sectionTitle = {
        size = 9,
        color = Palette.gold,
    },
    normal = {
        size = 9,
        color = Palette.text,
    },
    small = {
        size = 8,
        color = Palette.muted,
    },
    muted = {
        size = 8,
        color = Palette.muted,
    },
    tabActive = {
        size = 9,
        color = Palette.gold,
    },
    tabInactive = {
        size = 9,
        color = Palette.tabInactive,
    },
}

local function GetColorChannels(color)
    if not color then
        return 1, 1, 1, 1
    end

    return color.r or color[1] or 1,
        color.g or color[2] or 1,
        color.b or color[3] or 1,
        color.a or color[4] or 1
end

function Styles:GetColorChannels(color)
    return GetColorChannels(color)
end

function Styles:SetColor(region, color, alpha)
    if not region or not region.SetColorTexture then
        return
    end

    local r, g, b, a = GetColorChannels(color)
    region:SetColorTexture(r, g, b, alpha or a)
end

function Styles:SetTextColor(fontString, color, alpha)
    if not fontString or not fontString.SetTextColor then
        return
    end

    local r, g, b, a = GetColorChannels(color)
    fontString:SetTextColor(r, g, b, alpha or a)
end

function Styles:ApplyText(fontString, roleOrSize, color, flags)
    if not fontString then
        return
    end

    local role
    local size

    if type(roleOrSize) == "string" then
        role = self.Text[roleOrSize]
    elseif type(roleOrSize) == "table" then
        role = roleOrSize
    elseif type(roleOrSize) == "number" then
        size = roleOrSize
    end

    role = role or self.Text.normal
    size = size or role.size or 9

    fontString:SetFont(
        role.font or "Fonts\\FRIZQT__.TTF",
        size,
        flags or role.flags or "OUTLINE"
    )

    self:SetTextColor(fontString, color or role.color)
end

function Styles:HideRegion(region)
    if region and region.SetAlpha then
        region:SetAlpha(0)
    end
end

function Styles:EnsureBackground(
    parent,
    key,
    color,
    drawLayer,
    subLevel
)
    if not parent then
        return nil
    end

    key = key or "KamiBackground"

    local background = parent[key]

    if not background then
        background = parent:CreateTexture(
            nil,
            drawLayer or "BACKGROUND",
            nil,
            subLevel or -7
        )
        background:SetAllPoints()
        parent[key] = background
    end

    self:SetColor(background, color or Palette.panel)

    return background
end

function Styles:CreateBorder(parent, colorOrOptions, key)
    if not parent then
        return nil
    end

    local options = {}
    local color = colorOrOptions

    if type(colorOrOptions) == "string" then
        key = colorOrOptions
        color = nil
    elseif type(colorOrOptions) == "table"
        and (
            colorOrOptions.color
            or colorOrOptions.size
            or colorOrOptions.key
            or colorOrOptions.top ~= nil
            or colorOrOptions.bottom ~= nil
            or colorOrOptions.left ~= nil
            or colorOrOptions.right ~= nil
        )
    then
        options = colorOrOptions
        color = options.color
        key = options.key or key
    end

    color = color or Palette.border
    local size = options.size or self.Metrics.borderSize

    if key and parent[key] then
        self:SetBorderColor(parent[key], color)
        return parent[key]
    end

    local edges = {}

    local function CreateEdge(pointA, pointB, width, height)
        local edge = parent:CreateTexture(nil, "OVERLAY")
        edge:SetPoint(pointA)
        edge:SetPoint(pointB)

        if width then
            edge:SetWidth(width)
        end

        if height then
            edge:SetHeight(height)
        end

        self:SetColor(edge, color)
        edges[#edges + 1] = edge
    end

    if options.top ~= false then
        CreateEdge("TOPLEFT", "TOPRIGHT", nil, size)
    end

    if options.bottom ~= false then
        CreateEdge("BOTTOMLEFT", "BOTTOMRIGHT", nil, size)
    end

    if options.left ~= false then
        CreateEdge("TOPLEFT", "BOTTOMLEFT", size, nil)
    end

    if options.right ~= false then
        CreateEdge("TOPRIGHT", "BOTTOMRIGHT", size, nil)
    end

    if key then
        parent[key] = edges
    end

    return edges
end

function Styles:SetBorderColor(edges, colorOrR, g, b, a)
    if not edges then
        return
    end

    local r

    if type(colorOrR) == "table" then
        r, g, b, a = GetColorChannels(colorOrR)
    else
        r = colorOrR or 1
        g = g or 1
        b = b or 1
        a = a or 1
    end

    for _, edge in ipairs(edges) do
        if edge and edge.SetColorTexture then
            edge:SetColorTexture(r, g, b, a)
        end
    end
end

function Styles:ApplyBackdrop(frame, backgroundColor, borderColor)
    if not frame or not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = self.Metrics.borderSize,
    })
    frame:SetBackdropColor(GetColorChannels(
        backgroundColor or Palette.window.neutral
    ))
    frame:SetBackdropBorderColor(GetColorChannels(
        borderColor or Palette.border
    ))
end
