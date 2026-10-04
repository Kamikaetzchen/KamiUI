local UI = KamiUI
local Palette = UI.Palette
local Styles = UI.Styles
local Components = UI.Components

local Module = UI:NewModule("DamageMeter")

Module.name = "KamiUI_DamageMeter"
Module.version = "0.2.0"

local defaults = {
    width = 400,
    height = 240,
    headerHeight = 20,
    rowHeight = 20,
    maxRows = 11,
    fontSize = 10,
    backgroundAlpha = 0.82,
    rowAlpha = 0.32,
    barAlpha = 0.55,
    popupWidth = 230,
    popupRowHeight = 20,
}

local DamageMeterType = Enum.DamageMeterType
local DamageMeterSessionType = Enum.DamageMeterSessionType

local TYPE_LABELS = {
    [DamageMeterType.DamageDone] =
        DAMAGE_METER_TYPE_DAMAGE_DONE or "Damage Done",
    [DamageMeterType.Dps] =
        DAMAGE_METER_TYPE_DPS or "DPS",
    [DamageMeterType.HealingDone] =
        DAMAGE_METER_TYPE_HEALING_DONE or "Healing Done",
    [DamageMeterType.Hps] =
        DAMAGE_METER_TYPE_HPS or "HPS",
    [DamageMeterType.Absorbs] =
        DAMAGE_METER_TYPE_ABSORBS or "Absorbs",
    [DamageMeterType.Interrupts] =
        DAMAGE_METER_TYPE_INTERRUPTS or "Interrupts",
    [DamageMeterType.Dispels] =
        DAMAGE_METER_TYPE_DISPELS or "Dispels",
    [DamageMeterType.DamageTaken] =
        DAMAGE_METER_TYPE_DAMAGE_TAKEN or "Damage Taken",
    [DamageMeterType.AvoidableDamageTaken] =
        DAMAGE_METER_TYPE_AVOIDABLE_DAMAGE_TAKEN
        or "Avoidable Damage Taken",
    [DamageMeterType.Deaths] =
        DAMAGE_METER_TYPE_DEATHS or "Deaths",
    [DamageMeterType.EnemyDamageTaken] =
        DAMAGE_METER_TYPE_ENEMY_DAMAGE_TAKEN
        or "Enemy Damage Taken",
}

local TYPE_GROUPS = {
    {
        name = DAMAGE_METER_CATEGORY_DAMAGE or "Damage",
        types = {
            DamageMeterType.DamageDone,
            DamageMeterType.Dps,
            DamageMeterType.DamageTaken,
            DamageMeterType.AvoidableDamageTaken,
            DamageMeterType.EnemyDamageTaken,
        },
    },
    {
        name = DAMAGE_METER_CATEGORY_HEALING or "Healing",
        types = {
            DamageMeterType.HealingDone,
            DamageMeterType.Hps,
            DamageMeterType.Absorbs,
        },
    },
    {
        name = DAMAGE_METER_CATEGORY_ACTIONS or "Actions",
        types = {
            DamageMeterType.Interrupts,
            DamageMeterType.Dispels,
            DamageMeterType.Deaths,
        },
    },
}

local frame
local rows = {}
local viewPopup
local sessionPopup
local updateQueued = false

local state = {
    damageType = DamageMeterType.DamageDone,
    sessionType = DamageMeterSessionType.Overall,
    sessionID = nil,
    minimized = false,
}

local function CreateBackground(parent, alpha)
    local background = parent:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.02, 0.02, 0.025, alpha)
    return background
end

local function CreateFlatButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, defaults.headerHeight - 2)

    Components:StyleButton(button, {
        text = text,
        backgroundColor = Palette.panelStrong,
        textRole = "normal",
    })

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

local function SetButtonText(button, text)
    if button.SetText and button:GetFontString() then
        button:SetText(text)
        return
    end

    if button.KamiButtonText then
        button.KamiButtonText:SetText(text)
    end
end

local function SetPopupButtonState(button, active)
    if not button or not button.KamiButtonBackground then
        return
    end

    if active then
        Styles:SetColor(
            button.KamiButtonBackground,
            Palette.panelStrong,
            0.85
        )
    else
        Styles:SetColor(
            button.KamiButtonBackground,
            Palette.panel,
            0.55
        )
    end
end

local function HidePopups()
    if viewPopup then
        viewPopup:Hide()
    end

    if sessionPopup then
        sessionPopup:Hide()
    end
end

local function CreatePopup(parent, width)
    local popup = CreateFrame("Frame", nil, parent)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(parent:GetFrameLevel() + 100)
    popup:SetWidth(width)
    popup:EnableMouse(true)

    CreateBackground(popup, 0.96)
    Styles:CreateBorder(popup, Palette.border)

    popup.buttons = {}
    popup.labels = {}

    return popup
end

local function CreatePopupLabel(parent)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetJustifyH("LEFT")
    Styles:ApplyText(label, "sectionTitle")
    return label
end

local function CreatePopupButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(defaults.popupRowHeight)

    Components:StyleButton(button, {
        text = " ",
        backgroundColor = Palette.panel,
        backgroundAlpha = 0.55,
        textRole = "normal",
    })

    local text = button:GetFontString() or button.KamiButtonText
    if text then
        text:ClearAllPoints()
        text:SetPoint("LEFT", button, "LEFT", 7, 0)
        text:SetPoint("RIGHT", button, "RIGHT", -7, 0)
        text:SetJustifyH("LEFT")
    end

    return button
end

local function UpdateViewButton()
    SetButtonText(
        frame.viewButton,
        (TYPE_LABELS[state.damageType] or "Damage") .. "  v"
    )
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
    SetButtonText(frame.sessionButton, GetSessionLabel() .. "  v")
end

local function GetCombatSession()
    if state.sessionID then
        return C_DamageMeter.GetCombatSessionFromID(
            state.sessionID,
            state.damageType
        )
    end

    return C_DamageMeter.GetCombatSessionFromType(
        state.sessionType,
        state.damageType
    )
end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, frame.body)
    row:SetHeight(defaults.rowHeight)
    row:SetPoint("LEFT", frame.body, "LEFT", 1, 0)
    row:SetPoint("RIGHT", frame.body, "RIGHT", -1, 0)

    if index == 1 then
        row:SetPoint("TOP", frame.body, "TOP", 0, -1)
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
    indexText:SetPoint("LEFT", row, "LEFT", 5, 0)
    indexText:SetWidth(18)
    indexText:SetJustifyH("RIGHT")
    indexText:SetText(index .. ".")

    local icon = overlay:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", indexText, "RIGHT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local name = overlay:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    name:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -142, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)

    local rate = overlay:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    rate:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    rate:SetWidth(54)
    rate:SetJustifyH("RIGHT")

    local value = overlay:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    value:SetPoint("RIGHT", rate, "LEFT", -8, 0)
    value:SetWidth(72)
    value:SetJustifyH("RIGHT")

    Styles:ApplyText(indexText, defaults.fontSize, Palette.muted)
    Styles:ApplyText(name, defaults.fontSize, Palette.text)
    Styles:ApplyText(value, defaults.fontSize, Palette.text)
    Styles:ApplyText(rate, defaults.fontSize, Palette.muted)

    local separator = row:CreateTexture(nil, "OVERLAY")
    separator:SetPoint("BOTTOMLEFT")
    separator:SetPoint("BOTTOMRIGHT")
    separator:SetHeight(1)
    separator:SetColorTexture(0, 0, 0, 0.75)

    row.background = background
    row.bar = bar
    row.icon = icon
    row.name = name
    row.value = value
    row.rate = rate
    row:Hide()

    rows[index] = row
end

local function HideRows()
    for _, row in ipairs(rows) do
        row:Hide()
    end
end

local function UpdateRows()
    local session = GetCombatSession()
    local sources = session.combatSources

    for index = 1, defaults.maxRows do
        local row = rows[index]
        local source = sources[index]

        if source then
            local r, g, b = GetClassColor(source.classFilename)
            local primaryValue
            local secondaryValue

            if state.damageType == DamageMeterType.Dps
                or state.damageType == DamageMeterType.Hps
            then
                primaryValue = source.amountPerSecond
                secondaryValue = source.totalAmount
            else
                primaryValue = source.totalAmount

                if state.damageType == DamageMeterType.DamageDone
                    or state.damageType == DamageMeterType.HealingDone
                then
                    secondaryValue = source.amountPerSecond
                end
            end

            row.bar:SetMinMaxValues(0, session.maxAmount)
            row.bar:SetValue(primaryValue)
            row.bar:SetStatusBarColor(r, g, b, 1)

            row.name:SetText(source.name)
            row.value:SetText(primaryValue)

            if secondaryValue ~= nil then
                row.rate:SetText(secondaryValue)
                row.rate:Show()
            else
                row.rate:SetText("")
                row.rate:Hide()
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

local function BuildViewPopup()
    if not viewPopup then
        viewPopup = CreatePopup(frame, defaults.popupWidth)
        viewPopup:SetPoint(
            "BOTTOMLEFT",
            frame.header,
            "TOPLEFT",
            0,
            2
        )
    end

    for _, button in ipairs(viewPopup.buttons) do
        button:Hide()
    end

    for _, label in ipairs(viewPopup.labels) do
        label:Hide()
    end

    local y = -5
    local buttonIndex = 0
    local labelIndex = 0

    for _, group in ipairs(TYPE_GROUPS) do
        labelIndex = labelIndex + 1
        local label = viewPopup.labels[labelIndex]

        if not label then
            label = CreatePopupLabel(viewPopup)
            viewPopup.labels[labelIndex] = label
        end

        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", viewPopup, "TOPLEFT", 7, y)
        label:SetText(group.name)
        label:Show()
        y = y - 17

        for _, damageType in ipairs(group.types) do
            local selectedType = damageType

            buttonIndex = buttonIndex + 1
            local button = viewPopup.buttons[buttonIndex]

            if not button then
                button = CreatePopupButton(viewPopup)
                viewPopup.buttons[buttonIndex] = button
            end

            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", viewPopup, "TOPLEFT", 4, y)
            button:SetPoint("TOPRIGHT", viewPopup, "TOPRIGHT", -4, y)
            SetButtonText(
                button,
                TYPE_LABELS[selectedType] or tostring(selectedType)
            )
            SetPopupButtonState(
                button,
                state.damageType == selectedType
            )

            button:SetScript("OnClick", function()
                state.damageType = selectedType
                viewPopup:Hide()
                QueueUpdate()
            end)

            button:Show()
            y = y - defaults.popupRowHeight
        end

        y = y - 3
    end

    viewPopup:SetHeight(-y + 3)
end

local function BuildSessionPopup()
    if not sessionPopup then
        sessionPopup = CreatePopup(frame, defaults.popupWidth)
        sessionPopup:SetPoint(
            "BOTTOMRIGHT",
            frame.header,
            "TOPRIGHT",
            0,
            2
        )
    end

    for _, button in ipairs(sessionPopup.buttons) do
        button:Hide()
    end

    for _, label in ipairs(sessionPopup.labels) do
        label:Hide()
    end

    local entries = {
        {
            text = DAMAGE_METER_CURRENT_SESSION or "Current Segment",
            sessionType = DamageMeterSessionType.Current,
        },
        {
            text = DAMAGE_METER_OVERALL_SESSION or "Overall",
            sessionType = DamageMeterSessionType.Overall,
        },
    }

    for _, session in ipairs(
        C_DamageMeter.GetAvailableCombatSessions() or {}
    ) do
        entries[#entries + 1] = {
            text = session.name,
            sessionID = session.sessionID,
        }

        if #entries >= 10 then
            break
        end
    end

    local y = -4

    for index, entry in ipairs(entries) do
        local selectedEntry = entry
        local button = sessionPopup.buttons[index]

        if not button then
            button = CreatePopupButton(sessionPopup)
            sessionPopup.buttons[index] = button
        end

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", sessionPopup, "TOPLEFT", 4, y)
        button:SetPoint("TOPRIGHT", sessionPopup, "TOPRIGHT", -4, y)

        SetButtonText(button, selectedEntry.text)

        local active
        if selectedEntry.sessionID then
            active = state.sessionID == selectedEntry.sessionID
        else
            active =
                state.sessionID == nil
                and state.sessionType == selectedEntry.sessionType
        end

        SetPopupButtonState(button, active)

        button:SetScript("OnClick", function()
            state.sessionID = selectedEntry.sessionID
            state.sessionType = selectedEntry.sessionType
                or DamageMeterSessionType.Overall
            sessionPopup:Hide()
            QueueUpdate()
        end)

        button:Show()
        y = y - defaults.popupRowHeight
    end

    sessionPopup:SetHeight(-y + 4)
end

local function ToggleViewPopup()
    if viewPopup and viewPopup:IsShown() then
        viewPopup:Hide()
        return
    end

    if sessionPopup then
        sessionPopup:Hide()
    end

    BuildViewPopup()
    viewPopup:Show()
end

local function ToggleSessionPopup()
    if sessionPopup and sessionPopup:IsShown() then
        sessionPopup:Hide()
        return
    end

    if viewPopup then
        viewPopup:Hide()
    end

    BuildSessionPopup()
    sessionPopup:Show()
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
        frame:SetHeight(defaults.headerHeight)
        SetButtonText(frame.minimizeButton, "+")
    else
        frame.body:Show()
        frame:SetHeight(defaults.height)
        SetButtonText(frame.minimizeButton, "-")
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

    local resetButton = CreateFlatButton(header, "Reset", 44)
    resetButton:SetPoint("RIGHT", minimizeButton, "LEFT", -2, 0)
    resetButton:SetScript("OnClick", ResetData)

    local sessionButton = CreateFlatButton(header, "Overall  v", 112)
    sessionButton:SetPoint("RIGHT", resetButton, "LEFT", -2, 0)
    sessionButton:SetScript("OnClick", ToggleSessionPopup)

    local viewButton = CreateFlatButton(header, "Damage Done  v", 1)
    viewButton:SetPoint("LEFT", header, "LEFT", 0, 0)
    viewButton:SetPoint("RIGHT", sessionButton, "LEFT", -2, 0)
    viewButton:SetScript("OnClick", ToggleViewPopup)

    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    frame.header = header
    frame.body = body
    frame.viewButton = viewButton
    frame.sessionButton = sessionButton
    frame.resetButton = resetButton
    frame.minimizeButton = minimizeButton

    for index = 1, defaults.maxRows do
        CreateRow(index)
    end

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

    UI:RegisterBottomInsetCallback(function()
        ApplyPosition()
    end)

    UI:RegisterEvent("PLAYER_ENTERING_WORLD", QueueUpdate)
    UI:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", QueueUpdate)
    UI:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED", QueueUpdate)

    UI:RegisterEvent("DAMAGE_METER_RESET", function()
        state.sessionID = nil
        state.sessionType = DamageMeterSessionType.Overall
        QueueUpdate()
    end)
end

Module:Initialize()
