local UI = KamiUI
local Components = UI.Components
local Styles = UI.Styles
local Media = UI.Media
local Palette = UI.Palette

-- Render a contiguous texture as independent anchored regions. The
-- caller supplies UV boundaries (including any power-of-two padding)
-- and fixed destination cap sizes. Only the middle regions stretch.
local function CreateSlices(parent, options, u, v, capX, capY)
    local parts = {}
    local columns = #u - 1
    local rows = #v - 1
    local holder = {}

    for row = 1, rows do
        for column = 1, columns do
            local layer = options.layer or "BACKGROUND"
            local texture = parent:CreateTexture(nil, layer, nil, options.sublevel or -7)
            texture:SetTexCoord(
                u[column], u[column + 1], v[row], v[row + 1]
            )
            parts[#parts + 1] = texture
        end
    end

    local function Layout()
        local width = parent:GetWidth()
        local height = parent:GetHeight()
        if width <= 0 or height <= 0 then return end

        -- Shrink both corner axes uniformly for undersized frames.
        local scale = math.min(1, width / (2 * capX))
        if rows == 3 then
            scale = math.min(scale, height / (2 * capY))
        else
            scale = math.min(scale, height / (2 * capX))
        end

        local x = { 0, capX * scale, width - capX * scale, width }
        local y = rows == 3
            and { 0, capY * scale, height - capY * scale, height }
            or { 0, height }

        for row = 1, rows do
            for column = 1, columns do
                local part = parts[(row - 1) * columns + column]
                part:ClearAllPoints()
                part:SetPoint(
                    "TOPLEFT", parent, "TOPLEFT", x[column], -y[row]
                )
                part:SetPoint(
                    "BOTTOMRIGHT", parent, "TOPLEFT",
                    x[column + 1], -y[row + 1]
                )
                part:SetShown(
                    x[column + 1] > x[column]
                    and y[row + 1] > y[row]
                )
            end
        end
    end

    function holder:SetAsset(asset)
        local path = Media:GetDarkMetallicTexture(asset)
        for _, part in ipairs(parts) do
            part:SetTexture(path)
        end
    end

    function holder:SetVertexColor(r, g, b, a)
        for _, part in ipairs(parts) do
            part:SetVertexColor(r, g, b, a)
        end
    end

    holder:SetAsset(options.asset)
    if options.color then
        holder:SetVertexColor(Styles:GetColorChannels(options.color))
    end
    parent:HookScript("OnSizeChanged", Layout)
    Layout()
    return holder
end

function Components:CreateNineSlice(parent, options)
    options = options or {}
    local size = options.sliceSize or Styles.DarkMetallic.panelSlice
    options.asset = options.asset or Media.DarkMetallic.panel

    -- 96 logical pixels in a 128px TGA; never sample the padding.
    local bounds = { 0, 0.25, 0.5, 0.75 }
    return CreateSlices(parent, options, bounds, bounds, size, size)
end

function Components:CreateThreeSlice(parent, options)
    local height = options.height or Styles.Metrics.tabHeight
    local cap = height * Styles.DarkMetallic.tabCapRatio
    local v = options.flipY and { 1, 0 } or { 0, 1 }

    -- Tab art is 128x32. The outer 16px contain the chamfers.
    return CreateSlices(
        parent, options, { 0, 0.125, 0.875, 1 }, v, cap, height
    )
end

-- Text-button art is 128x32, with a three-pixel bevel and chamfers.
-- Slice both axes so the rim does not grow with button height.
function Components:CreateMetallicButtonSlice(parent, options)
    local scale = Styles.DarkMetallic.buttonTextureScale
    return CreateSlices(
        parent, options,
        { 0, 0.125, 0.875, 1 },
        { 0, 0.25, 0.75, 1 },
        16 * scale, 8 * scale
    )
end

function Components:ApplyMetallicPanel(frame, options)
    if frame.SetBackdrop then
        frame:SetBackdrop(nil)
    end
    options = options or {}
    if options.asset and options.asset ~= Media.DarkMetallic.panel then
        return self:CreateNineSlice(frame, options)
    end

    local function Layer(asset, sublevel, color)
        return self:CreateNineSlice(frame, {
            asset = asset,
            sliceSize = options.sliceSize,
            layer = options.layer,
            sublevel = sublevel,
            color = color,
        })
    end

    local panel = {
        fill = Layer(Media.DarkMetallic.panelFill, -7,
            options.backgroundColor or Palette.window.neutral),
        frame = Layer(Media.DarkMetallic.panelFrame, -6,
            options.frameColor or Palette.metallicTint.neutral),
    }

    function panel:SetFrameColor(color)
        local r, g, b = Styles:GetColorChannels(color)
        self.frame:SetVertexColor(r, g, b, 1)
    end

    function panel:SetColors(background, frameColor)
        self.fill:SetVertexColor(Styles:GetColorChannels(background))
        self:SetFrameColor(frameColor)
    end

    return panel
end

function Components:CreateMetallicIconFrame(button)
    local texture = button:CreateTexture(nil, "OVERLAY", nil, 0)
    texture:SetAllPoints(button)
    texture:SetTexture(
        Media:GetDarkMetallicTexture(Media.DarkMetallic.button)
    )
    return texture
end
