local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components

local Module = UI:NewModule("DamageMeter", "KamiUI_DamageMeter")


local defaults = {
    width = 400,
    height = 240,
    headerHeight = 20,
    columnHeaderHeight = 17,
    rowHeight = 18,
    maxRows = 11,
    fontSize = 10,
    backgroundAlpha = 0.82,
    rowAlpha = 0.32,
    barAlpha = 0.55,
    popupWidth = 150,
    popupRowHeight = 20,
}

local DamageMeterType = Enum.DamageMeterType
local DamageMeterSessionType = Enum.DamageMeterSessionType

local VIEW_ORDER = {
    "absorbs",
    "taken",
    "avoidable",
    "enemyTaken",
    "interrupts",
    "dispels",
    "deaths",
    "healing",
    "damage",
}

local VIEWS = {
    damage = {
        label = "Damage / DPS",
        primaryType = DamageMeterType.DamageDone,
        nameWidth = 238,
        columns = {
            {
                label = "Damage",
                tooltip = DAMAGE_METER_TYPE_DAMAGE_DONE or "Damage Done",
                width = 80,
                kind = "total",
            },
            {
                label = "DPS",
                tooltip = DAMAGE_METER_TYPE_DPS or "DPS",
                width = 80,
                kind = "rate",
            },
        },
    },
    healing = {
        label = "Healing / HPS",
        primaryType = DamageMeterType.HealingDone,
        nameWidth = 238,
        columns = {
            {
                label = "Healing",
                tooltip = DAMAGE_METER_TYPE_HEALING_DONE or "Healing Done",
                width = 80,
                kind = "total",
            },
            {
                label = "HPS",
                tooltip = DAMAGE_METER_TYPE_HPS or "HPS",
                width = 80,
                kind = "rate",
            },
        },
    },
    absorbs = {
        label = DAMAGE_METER_TYPE_ABSORBS or "Absorbs",
        primaryType = DamageMeterType.Absorbs,
        nameWidth = 318,
        columns = {
            {
                label = "Absorb",
                tooltip = DAMAGE_METER_TYPE_ABSORBS or "Absorbs",
                width = 80,
                kind = "total",
            },
        },
    },
    taken = {
        label = DAMAGE_METER_TYPE_DAMAGE_TAKEN or "Damage Taken",
        primaryType = DamageMeterType.DamageTaken,
        nameWidth = 318,
        columns = {
            {
                label = "Taken",
                tooltip = DAMAGE_METER_TYPE_DAMAGE_TAKEN or "Damage Taken",
                width = 80,
                kind = "total",
            },
        },
    },
    avoidable = {
        label = DAMAGE_METER_TYPE_AVOIDABLE_DAMAGE_TAKEN
            or "Avoidable Damage Taken",
        primaryType = DamageMeterType.AvoidableDamageTaken,
        nameWidth = 318,
        columns = {
            {
                label = "Avoid",
                tooltip = DAMAGE_METER_TYPE_AVOIDABLE_DAMAGE_TAKEN
                    or "Avoidable Damage Taken",
                width = 80,
                kind = "total",
            },
        },
    },
    enemyTaken = {
        label = DAMAGE_METER_TYPE_ENEMY_DAMAGE_TAKEN
            or "Enemy Damage Taken",
        primaryType = DamageMeterType.EnemyDamageTaken,
        nameWidth = 318,
        columns = {
            {
                label = "Enemy",
                tooltip = DAMAGE_METER_TYPE_ENEMY_DAMAGE_TAKEN
                    or "Enemy Damage Taken",
                width = 80,
                kind = "total",
            },
        },
    },
    interrupts = {
        label = DAMAGE_METER_TYPE_INTERRUPTS or "Interrupts",
        primaryType = DamageMeterType.Interrupts,
        nameWidth = 318,
        columns = {
            {
                label = "Interrupt",
                tooltip = DAMAGE_METER_TYPE_INTERRUPTS or "Interrupts",
                width = 80,
                kind = "total",
            },
        },
    },
    dispels = {
        label = DAMAGE_METER_TYPE_DISPELS or "Dispels",
        primaryType = DamageMeterType.Dispels,
        nameWidth = 318,
        columns = {
            {
                label = "Dispel",
                tooltip = DAMAGE_METER_TYPE_DISPELS or "Dispels",
                width = 80,
                kind = "total",
            },
        },
    },
    deaths = {
        label = DAMAGE_METER_TYPE_DEATHS or "Deaths",
        primaryType = DamageMeterType.Deaths,
        nameWidth = 318,
        columns = {
            {
                label = "Deaths",
                tooltip = DAMAGE_METER_TYPE_DEATHS or "Deaths",
                width = 80,
                kind = "total",
            },
        },
    },
}

local frame
local rows = {}
local viewDropdown
local sessionDropdown
local updateQueued = false

local state = {
    view = "damage",
    sessionType = DamageMeterSessionType.Overall,
    sessionID = nil,
    minimized = false,
}

local meterFontPath, _, meterFontFlags =
    GameFontNormalSmall:GetFont()

local function ApplyMeterText(fontString, size, color)
    if not fontString then
        return
    end

    fontString:SetFont(
        meterFontPath,
        size or defaults.fontSize,
        meterFontFlags
    )
    Styles:SetTextColor(fontString, color or Palette.text)
    fontString:SetShadowColor(0, 0, 0, 1)
    fontString:SetShadowOffset(1, -1)
end

local function CreateBackground(parent, alpha)
    local background = parent:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.02, 0.02, 0.025, alpha)
    return background
end

local function CreateVerticalSeparator(parent)
    local separator = parent:CreateTexture(nil, "OVERLAY")
    separator:SetWidth(1)
    separator:SetColorTexture(0.16, 0.16, 0.18, 0.85)
    return separator
end

local function CreateFlatButton(parent, text, width, options)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, defaults.headerHeight - 2)

    options = options or {}

    Components:StyleButton(button, {
        text = text,
        backgroundColor =
            options.backgroundColor or Palette.panelStrong,
        backgroundAlpha = options.backgroundAlpha,
        borderColor = options.borderColor,
        textColor = options.textColor,
        textRole = "normal",
    })

    ApplyMeterText(
        button:GetFontString() or button.KamiButtonText,
        defaults.fontSize,
        options.textColor or Palette.text
    )

    return button
end

local function GetClassColor(classFile)
    local color = Palette:GetClassColor(classFile)

    if not color then
        return 0.24, 0.24, 0.26
    end

    return (color.r or color[1]) * 0.60,
        (color.g or color[2]) * 0.60,
        (color.b or color[3]) * 0.60
end

local function HidePopups()
    Components:CloseDropdown(viewDropdown)
    Components:CloseDropdown(sessionDropdown)
end

local function GetView()
    return VIEWS[state.view] or VIEWS.damage
end

local function UpdateViewButton()
    Components:RefreshDropdown(viewDropdown)
end

local function GetSessionLabel()
    if state.sessionID then
        local sessions = C_DamageMeter.GetAvailableCombatSessions()

        for _, session in ipairs(sessions or {}) do
            if session.sessionID == state.sessionID then
                return session.name
            end
        end

        return tostring(state.sessionID)
    end

    if state.sessionType == DamageMeterSessionType.Current then
        return DAMAGE_METER_CURRENT_SESSION or "Current"
    end

    return DAMAGE_METER_OVERALL_SESSION or "Overall"
end

local function UpdateSessionButton()
    Components:RefreshDropdown(sessionDropdown)
end

local function GetCombatSession(damageType)
    if state.sessionID then
        return C_DamageMeter.GetCombatSessionFromID(
            state.sessionID,
            damageType
        )
    end

    return C_DamageMeter.GetCombatSessionFromType(
        state.sessionType,
        damageType
    )
end

local function CreateColumnText(parent)
    local text = parent:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    text:SetJustifyH("RIGHT")
    text:SetWordWrap(false)
    ApplyMeterText(text, defaults.fontSize, Palette.text)
    return text
end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, frame.body)
    row:SetHeight(defaults.rowHeight)
    row:SetPoint("LEFT", frame.body, "LEFT", 1, 0)
    row:SetPoint("RIGHT", frame.body, "RIGHT", -1, 0)

    if index == 1 then
        row:SetPoint(
            "TOP",
            frame.columnHeader,
            "BOTTOM",
            0,
            0
        )
    else
        row:SetPoint("TOP", rows[index - 1], "BOTTOM", 0, 0)
    end

    local background = CreateBackground(row, defaults.rowAlpha)

    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")

    local barTexture = bar:GetStatusBarTexture()
    if barTexture then
        barTexture:SetAlpha(defaults.barAlpha)
    end

    local overlay = CreateFrame("Frame", nil, row)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(bar:GetFrameLevel() + 2)

    local indexText = overlay:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    indexText:SetPoint("LEFT", row, "LEFT", 4, 0)
    indexText:SetWidth(17)
    indexText:SetJustifyH("RIGHT")
    indexText:SetText(index .. ".")
    ApplyMeterText(indexText, defaults.fontSize, Palette.muted)

    local icon = overlay:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", indexText, "RIGHT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local name = overlay:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    name:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    ApplyMeterText(name, defaults.fontSize, Palette.text)

    row.background = background
    row.bar = bar
    row.icon = icon
    row.name = name
    row.values = {}
    row.separators = {}

    for columnIndex = 1, 5 do
        row.values[columnIndex] = CreateColumnText(overlay)
        row.separators[columnIndex] = CreateVerticalSeparator(overlay)
    end

    local bottom = row:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)
    bottom:SetColorTexture(0, 0, 0, 0.75)

    row:Hide()
    rows[index] = row
end

local function LayoutColumns()
    local view = GetView()
    local nameWidth = view.nameWidth

    frame.columnHeader.name:ClearAllPoints()
    frame.columnHeader.name:SetPoint(
        "LEFT",
        frame.columnHeader,
        "LEFT",
        5,
        0
    )
    frame.columnHeader.name:SetWidth(nameWidth - 5)
    frame.columnHeader.name:SetJustifyH("LEFT")

    local x = nameWidth

    for columnIndex = 1, 5 do
        local column = view.columns[columnIndex]
        local headerText = frame.columnHeader.values[columnIndex]
        local headerHitbox =
            frame.columnHeader.hitboxes[columnIndex]
        local headerSeparator =
            frame.columnHeader.separators[columnIndex]

        if column then
            headerSeparator:ClearAllPoints()
            headerSeparator:SetPoint(
                "TOPLEFT",
                frame.columnHeader,
                "TOPLEFT",
                x,
                0
            )
            headerSeparator:SetPoint(
                "BOTTOMLEFT",
                frame.columnHeader,
                "BOTTOMLEFT",
                x,
                0
            )
            headerSeparator:Show()

            headerText:ClearAllPoints()
            headerText:SetPoint(
                "TOPLEFT",
                frame.columnHeader,
                "TOPLEFT",
                x + 3,
                0
            )
            headerText:SetPoint(
                "BOTTOMLEFT",
                frame.columnHeader,
                "BOTTOMLEFT",
                x + 3,
                0
            )
            headerText:SetWidth(column.width - 6)
            headerText:SetText(column.label)
            headerText:Show()

            headerHitbox:ClearAllPoints()
            headerHitbox:SetPoint(
                "TOPLEFT",
                frame.columnHeader,
                "TOPLEFT",
                x,
                0
            )
            headerHitbox:SetPoint(
                "BOTTOMLEFT",
                frame.columnHeader,
                "BOTTOMLEFT",
                x,
                0
            )
            headerHitbox:SetWidth(column.width)
            headerHitbox.tooltipText =
                column.tooltip or column.label
            headerHitbox:Show()

            x = x + column.width
        else
            headerSeparator:Hide()
            headerText:Hide()
            headerHitbox.tooltipText = nil
            headerHitbox:Hide()
        end
    end

    for _, row in ipairs(rows) do
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
        row.name:SetWidth(nameWidth - 45)

        local rowX = nameWidth

        for columnIndex = 1, 5 do
            local column = view.columns[columnIndex]
            local value = row.values[columnIndex]
            local separator = row.separators[columnIndex]

            if column then
                separator:ClearAllPoints()
                separator:SetPoint(
                    "TOPLEFT",
                    row,
                    "TOPLEFT",
                    rowX,
                    0
                )
                separator:SetPoint(
                    "BOTTOMLEFT",
                    row,
                    "BOTTOMLEFT",
                    rowX,
                    0
                )
                separator:Show()

                value:ClearAllPoints()
                value:SetPoint(
                    "TOPLEFT",
                    row,
                    "TOPLEFT",
                    rowX + 3,
                    0
                )
                value:SetPoint(
                    "BOTTOMLEFT",
                    row,
                    "BOTTOMLEFT",
                    rowX + 3,
                    0
                )
                value:SetWidth(column.width - 6)
                value:Show()

                rowX = rowX + column.width
            else
                separator:Hide()
                value:SetText("")
                value:Hide()
            end
        end
    end
end

local function HideRows()
    for _, row in ipairs(rows) do
        row:Hide()
    end
end

local function SetSourceColumnValue(row, columnIndex, source, column)
    local value = row.values[columnIndex]

    if column.kind == "rate" then
        value:SetFormattedText("%.1f", source.amountPerSecond)
    else
        value:SetText(source.totalAmount)
    end
end

local function UpdateRows()
    local view = GetView()
    local session = GetCombatSession(view.primaryType)
    local sources = session.combatSources

    for index = 1, defaults.maxRows do
        local row = rows[index]
        local source = sources[index]

        if source then
            local r, g, b = GetClassColor(source.classFilename)

            row.bar:SetMinMaxValues(0, session.maxAmount)
            row.bar:SetValue(source.totalAmount)
            row.bar:SetStatusBarColor(r, g, b, 1)

            row.name:SetText(source.name)

            for columnIndex, column in ipairs(view.columns) do
                SetSourceColumnValue(
                    row,
                    columnIndex,
                    source,
                    column
                )
            end

            local iconID = source.specIconID
            if iconID and iconID ~= 0 then
                row.icon:SetTexture(iconID)
                row.icon:Show()
            else
                row.icon:SetTexture(nil)
                row.icon:Hide()
            end

            row:Show()
        else
            row:Hide()
        end
    end
end

local function Update()
    if not frame or not C_DamageMeter then
        return
    end

    local available = C_DamageMeter.IsDamageMeterAvailable()
    if not available then
        HideRows()
        frame:Hide()
        return
    end

    UpdateViewButton()
    UpdateSessionButton()
    LayoutColumns()

    if not state.minimized then
        UpdateRows()
    end

    frame:Show()
end

local function QueueUpdate()
    if updateQueued then
        return
    end

    updateQueued = true

    C_Timer.After(0, function()
        updateQueued = false
        Update()
    end)
end

local function GetViewDropdownEntries()
    local entries = {}

    for _, viewKey in ipairs(VIEW_ORDER) do
        entries[#entries + 1] = {
            text = VIEWS[viewKey].label,
            viewKey = viewKey,
        }
    end

    return entries
end

local function GetSessionDropdownEntries()
    local entries = {}

    for _, session in ipairs(
        C_DamageMeter.GetAvailableCombatSessions() or {}
    ) do
        entries[#entries + 1] = {
            text = session.name,
            sessionID = session.sessionID,
        }

        if #entries >= 8 then
            break
        end
    end

    entries[#entries + 1] = {
        text = DAMAGE_METER_OVERALL_SESSION or "Overall",
        sessionType = DamageMeterSessionType.Overall,
    }

    entries[#entries + 1] = {
        text = DAMAGE_METER_CURRENT_SESSION or "Current Segment",
        sessionType = DamageMeterSessionType.Current,
    }

    return entries
end

local function IsSessionDropdownEntrySelected(entry)
    if entry.sessionID then
        return state.sessionID == entry.sessionID
    end

    return state.sessionID == nil
        and state.sessionType == entry.sessionType
end

local function ResetData()
    HidePopups()

    state.sessionID = nil
    state.sessionType = DamageMeterSessionType.Overall

    C_DamageMeter.ResetAllCombatSessions()
    QueueUpdate()
end

local function ToggleMinimized()
    state.minimized = not state.minimized
    HidePopups()

    if state.minimized then
        frame.body:Hide()
        frame.columnHeader:Hide()
        frame:SetHeight(defaults.headerHeight)
        Components:SetButtonText(frame.minimizeButton, "+")
    else
        frame.columnHeader:Show()
        frame.body:Show()
        frame:SetHeight(defaults.height)
        Components:SetButtonText(frame.minimizeButton, "-")
        QueueUpdate()
    end
end

local function ApplyPosition()
    if not frame then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        "BOTTOMRIGHT",
        UIParent,
        "BOTTOMRIGHT",
        0,
        UI:GetBottomInset()
    )
end

local function SuppressBlizzardDamageMeter()
    UI:KeepFrameHidden(DamageMeter)
end

local function CreateColumnHeader()
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint(
        "TOPLEFT",
        frame.header,
        "BOTTOMLEFT",
        0,
        0
    )
    header:SetPoint(
        "TOPRIGHT",
        frame.header,
        "BOTTOMRIGHT",
        0,
        0
    )
    header:SetHeight(defaults.columnHeaderHeight)

    local background = CreateBackground(header, 0.72)
    Styles:SetColor(background, Palette.panelStrong, 0.72)

    local name = header:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    name:SetText("Name")
    ApplyMeterText(name, defaults.fontSize, Palette.muted)

    header.name = name
    header.values = {}
    header.separators = {}
    header.hitboxes = {}

    for columnIndex = 1, 5 do
        local text = header:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormalSmall"
        )
        text:SetJustifyH("RIGHT")
        ApplyMeterText(text, defaults.fontSize, Palette.gold)

        local hitbox = CreateFrame("Button", nil, header)
        hitbox:SetFrameLevel(header:GetFrameLevel() + 5)
        hitbox:SetScript("OnEnter", function(self)
            if not self.tooltipText then
                return
            end

            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.tooltipText)
            GameTooltip:Show()
        end)
        hitbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        header.values[columnIndex] = text
        header.hitboxes[columnIndex] = hitbox
        header.separators[columnIndex] =
            CreateVerticalSeparator(header)
    end

    local bottom = header:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)
    Styles:SetColor(bottom, Palette.border)

    frame.columnHeader = header
end

local function CreateFrameUI()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "KamiUIDamageMeter", UIParent)
    frame:SetSize(defaults.width, defaults.height)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(50)
    frame:EnableMouse(true)

    CreateBackground(frame, defaults.backgroundAlpha)
    Styles:CreateBorder(frame, Palette.border)

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    header:SetHeight(defaults.headerHeight - 1)

    local headerBackground = CreateBackground(header, 0.92)
    Styles:SetColor(headerBackground, Palette.header, 0.92)

    local bottomBorder = header:CreateTexture(nil, "OVERLAY")
    bottomBorder:SetPoint("BOTTOMLEFT")
    bottomBorder:SetPoint("BOTTOMRIGHT")
    bottomBorder:SetHeight(1)
    Styles:SetColor(bottomBorder, Palette.border)

    local minimizeButton = CreateFlatButton(header, "-", 20)
    minimizeButton:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    minimizeButton:SetScript("OnClick", ToggleMinimized)

    local resetButton = CreateFlatButton(
        header,
        "Reset",
        44,
        {
            backgroundColor = { 0.30, 0.035, 0.045, 1.00 },
            backgroundAlpha = 0.90,
            borderColor = { 0.52, 0.08, 0.10, 1.00 },
            textColor = { 1.00, 0.74, 0.74, 1.00 },
        }
    )
    resetButton:SetPoint("RIGHT", minimizeButton, "LEFT", -2, 0)
    resetButton:SetScript("OnClick", ResetData)

    local sessionButton = CreateFlatButton(header, "Overall  v", 112)
    sessionButton:SetPoint("RIGHT", resetButton, "LEFT", -2, 0)

    local viewButton = CreateFlatButton(header, "Damage  v", 1)
    viewButton:SetPoint("LEFT", header, "LEFT", 0, 0)
    viewButton:SetPoint("RIGHT", sessionButton, "LEFT", -2, 0)

    frame.header = header
    frame.viewButton = viewButton
    frame.sessionButton = sessionButton

    local dropdownOptions = {
        direction = "up",
        menuParent = frame,
        anchor = header,
        menuWidth = 230,
        menuFrameStrata = "DIALOG",
        menuFrameLevel = frame:GetFrameLevel() + 100,
        rowHeight = defaults.popupRowHeight,
        inset = 4,
        textInset = 7,
        backgroundColor = { 0.02, 0.02, 0.025, 0.96 },
        borderColor = Palette.border,
        rowBackgroundColor = Palette.panel,
        rowBackgroundAlpha = 0.55,
        selectedBackgroundColor = Palette.panelStrong,
        selectedBackgroundAlpha = 0.85,
        rowBorder = true,
        rowBorderColor = Palette.border,
        fontSize = defaults.fontSize,
        textColor = Palette.text,
        arrowText = "  v",
        closeWith = frame,
        styleRow = function(button)
            ApplyMeterText(
                button.text,
                defaults.fontSize,
                Palette.text
            )
        end,
    }

    local viewOptions = {}

    for key, value in pairs(dropdownOptions) do
        viewOptions[key] = value
    end

    viewOptions.button = viewButton
    viewOptions.align = "left"
    viewOptions.getButtonText = function()
        return GetView().label
    end
    viewOptions.getEntries = GetViewDropdownEntries
    viewOptions.isSelected = function(entry)
        return state.view == entry.viewKey
    end
    viewOptions.onSelect = function(entry)
        state.view = entry.viewKey
        QueueUpdate()
    end
    viewDropdown = Components:CreateDropdown(frame, viewOptions)

    local sessionOptions = {}

    for key, value in pairs(dropdownOptions) do
        sessionOptions[key] = value
    end

    sessionOptions.button = sessionButton
    sessionOptions.align = "right"
    sessionOptions.getButtonText = GetSessionLabel
    sessionOptions.getEntries = GetSessionDropdownEntries
    sessionOptions.isSelected = IsSessionDropdownEntrySelected
    sessionOptions.onSelect = function(entry)
        state.sessionID = entry.sessionID
        state.sessionType = entry.sessionType
            or DamageMeterSessionType.Overall
        QueueUpdate()
    end
    sessionDropdown = Components:CreateDropdown(
        frame,
        sessionOptions
    )
    frame.resetButton = resetButton
    frame.minimizeButton = minimizeButton

    CreateColumnHeader()

    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint(
        "TOPLEFT",
        frame.columnHeader,
        "BOTTOMLEFT",
        0,
        0
    )
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.body = body

    for index = 1, defaults.maxRows do
        CreateRow(index)
    end

    LayoutColumns()
    ApplyPosition()
end

function Module:Initialize()
    if not C_DamageMeter
        or not DamageMeterType
        or not DamageMeterSessionType
    then
        return
    end

    CreateFrameUI()
    QueueUpdate()
    SuppressBlizzardDamageMeter()

    UI:RegisterBottomInsetCallback(function()
        ApplyPosition()
    end)

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        QueueUpdate()
        SuppressBlizzardDamageMeter()
    end)

    UI:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_DamageMeter" then
            SuppressBlizzardDamageMeter()
        end
    end)

    UI:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", QueueUpdate)
    UI:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED", QueueUpdate)

    UI:RegisterEvent("DAMAGE_METER_RESET", function()
        state.sessionID = nil
        state.sessionType = DamageMeterSessionType.Overall
        QueueUpdate()
    end)
end

Module:Initialize()
