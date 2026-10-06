local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components
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


function Components:CreateWindow(name, options)
    options = options or {}

    local parent = options.parent or UIParent
    local frame = CreateFrame(
        options.frameType or "Frame",
        name,
        parent,
        options.template or "BackdropTemplate"
    )

    if options.size then
        frame:SetSize(options.size[1], options.size[2])
    elseif options.width and options.height then
        frame:SetSize(options.width, options.height)
    end

    frame:SetFrameStrata(options.strata or "HIGH")

    if options.toplevel ~= nil then
        frame:SetToplevel(options.toplevel)
    end

    frame:SetMovable(options.movable ~= false)
    frame:SetClampedToScreen(options.clamped ~= false)
    frame:EnableMouse(options.mouse ~= false)

    Styles:ApplyBackdrop(
        frame,
        options.backgroundColor or Palette.window.neutral,
        options.borderColor or Palette.border
    )

    local onDragStop = options.onDragStop
    frame.KamiWindowOnDragStop = onDragStop

    local header
    if options.header ~= false then
        local source = options.header or {}
        local headerOptions = {}

        for key, value in pairs(source) do
            headerOptions[key] = value
        end

        if headerOptions.draggable == nil then
            headerOptions.draggable = options.movable ~= false
        end

        if headerOptions.dragTarget == nil then
            headerOptions.dragTarget = frame
        end

        if headerOptions.onDragStop == nil then
            headerOptions.onDragStop = onDragStop
        end

        header = self:CreateWindowHeader(frame, headerOptions)
        frame.header = header
    end

    if options.hidden ~= false then
        frame:Hide()
    end

    return frame, header
end

function Components:AttachHeaderSearch(frame, header, options)
    if not frame or not header then
        return nil
    end

    options = options or {}

    local title = options.title or header.Title
    local inset = options.inset or 90
    local titleButton = CreateFrame("Button", nil, header)

    titleButton:SetPoint(
        "TOPLEFT",
        header,
        "TOPLEFT",
        inset,
        options.y or -1
    )
    titleButton:SetPoint(
        "TOPRIGHT",
        header,
        "TOPRIGHT",
        -inset,
        options.y or -1
    )
    titleButton:SetHeight(options.buttonHeight or 24)

    local onDragStop = options.onDragStop
        or frame.KamiWindowOnDragStop

    if options.draggable ~= false then
        titleButton:RegisterForDrag("LeftButton")
        titleButton:SetScript("OnDragStart", function()
            frame:StartMoving()
        end)
        titleButton:SetScript("OnDragStop", function()
            frame:StopMovingOrSizing()

            if onDragStop then
                onDragStop(frame)
            end
        end)
    end

    local search = CreateFrame(
        "EditBox",
        nil,
        header,
        options.template or "InputBoxTemplate"
    )

    search:SetPoint("TOPLEFT", titleButton, "TOPLEFT", 0, -1)
    search:SetPoint("TOPRIGHT", titleButton, "TOPRIGHT", 0, -1)
    search:SetHeight(options.height or 22)
    search:SetAutoFocus(false)
    search:SetTextInsets(6, 6, 0, 0)

    if search.SetPropagateKeyboardInput then
        search:SetPropagateKeyboardInput(false)
    end

    search:Hide()

    local control = {
        button = titleButton,
        editBox = search,
    }

    function control:Open()
        if title then
            title:Hide()
        end

        search:Show()
        search:SetFocus()
        search:HighlightText()
    end

    function control:Close(clear)
        if clear then
            search:SetText("")
        end

        search:ClearFocus()
        search:Hide()

        if title then
            title:Show()
        end
    end

    titleButton:SetScript("OnDoubleClick", function()
        control:Open()
    end)

    search:SetScript("OnTextChanged", function(self, userInput)
        if options.onTextChanged then
            options.onTextChanged(self:GetText() or "", userInput, self)
        end
    end)

    search:SetScript("OnEscapePressed", function()
        control:Close(true)

        if options.onEscape then
            options.onEscape(search)
        end
    end)

    search:SetScript("OnEnterPressed", function()
        search:ClearFocus()
        control:Close(false)

        if options.onEnter then
            options.onEnter(search)
        end
    end)

    if options.closeOnFocusLost then
        search:SetScript("OnEditFocusLost", function()
            if search:IsShown() then
                control:Close(false)
            end
        end)
    end

    frame.titleButton = titleButton
    frame.search = search
    frame.KamiHeaderSearch = control

    return control
end
