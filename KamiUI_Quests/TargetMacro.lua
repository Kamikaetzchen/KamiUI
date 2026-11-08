local UI = KamiUI
local Module = UI:GetModule("Quests")
if not Module then return end

local Components = UI.Components
local Palette = UI.Palette
local Styles = UI.Styles

local MACRO_NAME = "KamiTargets"
local MACRO_ICON = "Ability_eyeoftheowl"
local MAX_MACRO_BYTES = 255
local MARKERS = { 4, 5, 6 }
local AUTO_UPDATE_DELAY = 0.7

local window
local fields = {}
local updateTimer
local pendingUpdate = false
local pendingSilent = true

local function GetSettings()
    local root = UI:GetDatabase("quests", {
        targetMacro = { characters = {} },
    })
    local characters = root.targetMacro.characters
    local key = UI:GetCurrentCharacterKey()

    if type(characters[key]) ~= "table" then
        characters[key] = { names = { "", "", "" } }
    end

    local settings = characters[key]
    if type(settings.names) ~= "table" then
        settings.names = { "", "", "" }
    end

    for index = 1, #MARKERS do
        if type(settings.names[index]) ~= "string" then
            settings.names[index] = ""
        end
    end

    return settings
end

local function SetStatus(message)
    if message and message ~= "" then UI:Print(message) end
end

local function NormalizeName(value)
    if type(value) ~= "string" then return "" end

    return value:gsub("[\r\n]+", " "):match("^%s*(.-)%s*$")
end

local function BuildMacro()
    local settings = GetSettings()
    local lines = {}

    for index, marker in ipairs(MARKERS) do
        local name = NormalizeName(settings.names[index])

        if name ~= "" then
            lines[#lines + 1] = "/cleartarget"
            lines[#lines + 1] = "/tar " .. name
            lines[#lines + 1] = "/tm [exists,nodead] !" .. marker
        end
    end

    -- Restore the most recently selected target when the final
    -- search finds nothing. Keep the last successful marked target.
    if #lines > 0 then
        lines[#lines + 1] = "/targetlasttarget [noexists]"
    end

    -- Preserve the action-bar macro when every field is cleared.
    local body = #lines > 0 and table.concat(lines, "\n")
        or "/stopmacro"

    if #body > MAX_MACRO_BYTES then
        return nil, string.format(
            "Macro too long (%d/%d bytes). Shorten a target name.",
            #body, MAX_MACRO_BYTES
        )
    end

    return body
end

local function CancelScheduledUpdate()
    if updateTimer then
        updateTimer:Cancel()
        updateTimer = nil
    end
end

local function UpdateMacro(silent)
    CancelScheduledUpdate()

    local body, errorMessage = BuildMacro()
    if not body then
        SetStatus(errorMessage)
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        if not pendingUpdate then
            pendingSilent = silent == true
        else
            pendingSilent = pendingSilent and silent == true
        end
        pendingUpdate = true
        if not silent then
            SetStatus("Update queued until combat ends.")
        end
        return
    end

    if not GetMacroInfo or not CreateMacro or not EditMacro then
        SetStatus("Macro API unavailable.")
        return
    end

    local macroName, _, currentBody = GetMacroInfo(MACRO_NAME)
    local exists = macroName ~= nil

    -- No API call or chat spam if the generated macro is unchanged.
    if exists and currentBody == body then
        pendingUpdate = false
        pendingSilent = true
        if not silent then SetStatus("Macro already up to date.") end
        return
    end

    local ok, result
    if exists then
        ok, result = pcall(EditMacro,
            MACRO_NAME, MACRO_NAME, nil, body)
    else
        -- Character-specific macro, matching character-specific target lists.
        ok, result = pcall(CreateMacro,
            MACRO_NAME, MACRO_ICON, body, true)
    end

    if not ok or not result then
        SetStatus("Could not update macro (macro slots full?).")
        return
    end

    pendingUpdate = false
    pendingSilent = true

    if not exists then
        SetStatus("Macro created: " .. MACRO_NAME
            .. " - drag it to an action bar once")
    elseif not silent then
        SetStatus("Macro updated: " .. MACRO_NAME)
    end
end

local function ScheduleUpdate()
    CancelScheduledUpdate()
    updateTimer = C_Timer.NewTimer(AUTO_UPDATE_DELAY, function()
        updateTimer = nil
        UpdateMacro(true)
    end)
end

local function AddCurrentTarget()
    if not UnitExists or not UnitName then return end

    local exists = UnitExists("target")
    if not UI:CanAccessValue(exists) or not exists then
        SetStatus("Select an NPC first.", Palette.gold)
        return
    end

    local name = UnitName("target")
    if not UI:CanAccessValue(name)
        or type(name) ~= "string" or name == "" then
        SetStatus("Target name unavailable.", Palette.gold)
        return
    end

    local settings = GetSettings()
    for index = 1, #MARKERS do
        if NormalizeName(settings.names[index]) == "" then
            settings.names[index] = name
            fields[index]:SetText(name)
            SetStatus("Added " .. name .. " to slot " .. index .. ".")
            UpdateMacro(true)
            return
        end
    end

    SetStatus("All three slots are filled.", Palette.gold)
end

-- Keep raid markers in their fixed slots; only reorder target names.
local function SwapTargets(firstIndex)
    local settings = GetSettings()
    local secondIndex = firstIndex + 1

    settings.names[firstIndex], settings.names[secondIndex] =
        settings.names[secondIndex], settings.names[firstIndex]

    fields[firstIndex]:SetText(settings.names[firstIndex])
    fields[secondIndex]:SetText(settings.names[secondIndex])
    UpdateMacro(true)
end

local EXPANDED_WIDTH = 205
local EXPANDED_HEIGHT = 146
local COLLAPSED_WIDTH = EXPANDED_WIDTH
local COLLAPSED_HEIGHT = 23

local function CreateWideButton(parent, label, y, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(20)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, y)
    Components:StyleButton(button, { text = label })
    button:SetScript("OnClick", onClick)
    return button
end

-- Swap buttons bridge adjacent rows, with a 2px vertical gap.
-- Their opposing hooked arrows are drawn in-game, no texture needed.
local function CreateSwapButton(parent, firstIndex)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(16, 28)
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -27,
        -31 - (firstIndex - 1) * 30)
    Components:StyleButton(button, {
        backgroundColor = { 0, 0, 0, 0.35 },
        hoverAlpha = 0.16,
    })

    -- Left arrow hooks downward, right arrow hooks upward.
    -- Coordinates are relative to the 16x28 button.
    local arrows = {
        {
            color = Palette.text,
            segments = {
                { 11, 4, 8, 4 }, { 8, 4, 6, 6 },
                { 6, 6, 5, 8 }, { 5, 8, 5, 16 },
                { 2, 13, 5, 17 }, { 8, 13, 5, 17 },
            },
        },
        {
            color = Palette.muted,
            segments = {
                { 5, 24, 8, 24 }, { 8, 24, 10, 22 },
                { 10, 22, 11, 20 }, { 11, 20, 11, 12 },
                { 8, 15, 11, 11 }, { 14, 15, 11, 11 },
            },
        },
    }
    for _, arrow in ipairs(arrows) do
        for _, segment in ipairs(arrow.segments) do
            local line = button:CreateLine(nil, "ARTWORK")
            line:SetStartPoint("TOPLEFT", button, "TOPLEFT",
                segment[1], -segment[2])
            line:SetEndPoint("TOPLEFT", button, "TOPLEFT",
                segment[3], -segment[4])
            line:SetThickness(1.5)
            Styles:SetColor(line, arrow.color)
        end
    end

    button:SetScript("OnClick", function()
        SwapTargets(firstIndex)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Swap targets " .. firstIndex
            .. " and " .. (firstIndex + 1))
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return button
end

local function CreateMarkerIcon(parent, marker, y)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y - 1)
    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")

    if SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(icon, marker)
    else
        local index = marker - 1
        local left = (index % 4) * 0.25
        local top = math.floor(index / 4) * 0.25
        icon:SetTexCoord(left, left + 0.25, top, top + 0.25)
    end

    return icon
end

-- Anchor the panel by its top-left corner so changing its height
-- never moves the title. Keep the legacy center position as a one-time
-- fallback for existing saved layouts.
local function AnchorTopLeft(frame, settings)
    local left, top = frame:GetLeft(), frame:GetTop()
    local parentLeft, parentTop = UIParent:GetLeft(), UIParent:GetTop()
    if not left or not top or not parentLeft or not parentTop then
        return
    end

    local x, y = left - parentLeft, top - parentTop
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
    settings.topLeft = { x = x, y = y }
end

local function ApplyCollapsed()
    if not window then return end

    local collapsed = GetSettings().collapsed == true
    window.content:SetShown(not collapsed)
    window:SetSize(
        collapsed and COLLAPSED_WIDTH or EXPANDED_WIDTH,
        collapsed and COLLAPSED_HEIGHT or EXPANDED_HEIGHT
    )
    window.header.title:SetText(
        collapsed and "+ Target Macro" or "- Target Macro"
    )
end

local function CreateWindow()
    if window then return end

    local settings = GetSettings()
    window = Components:CreateWindow("KamiUITargetMacroWindow", {
        width = EXPANDED_WIDTH,
        height = EXPANDED_HEIGHT,
        header = false,
        strata = "MEDIUM",
        backgroundColor = { 0, 0, 0, 0.28 },
        borderColor = { 0.18, 0.18, 0.20, 0.45 },
        onDragStop = function(frame)
            AnchorTopLeft(frame, settings)
        end,
    })

    local topLeft = settings.topLeft
    if type(topLeft) == "table"
        and type(topLeft.x) == "number"
        and type(topLeft.y) == "number" then
        window:SetPoint(
            "TOPLEFT", UIParent, "TOPLEFT", topLeft.x, topLeft.y
        )
    elseif not UI:ApplyFramePosition(
        window, settings, "position", 0, 0, UIParent, true
    ) then
        window:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -160)
    end

    -- The same click-to-collapse and drag-to-move interaction as the
    -- objective tracker, without a close button or Escape registration.
    local header = CreateFrame("Button", nil, window)
    header:SetPoint("TOPLEFT", window, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", window, "TOPRIGHT", -1, -1)
    header:SetHeight(21)
    header:RegisterForClicks("LeftButtonUp")
    header:RegisterForDrag("LeftButton")

    local title = header:CreateFontString(nil, "OVERLAY")
    Styles:ApplyText(title, "panelTitle", Palette.gold)
    title:SetPoint("CENTER", header, "CENTER", 0, 0)
    header.title = title

    header:SetScript("OnDragStart", function(self)
        self.dragging = true
        if InCombatLockdown and InCombatLockdown() then return end
        window:StartMoving()
        self.moving = true
    end)
    header:SetScript("OnDragStop", function(self)
        if self.moving then
            window:StopMovingOrSizing()
            AnchorTopLeft(window, settings)
            self.moving = nil
        end

        C_Timer.After(0, function()
            self.dragging = false
        end)
    end)
    header:SetScript("OnClick", function(self)
        if self.dragging then return end
        settings.collapsed = not settings.collapsed
        ApplyCollapsed()
    end)
    window.header = header

    local content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -23)
    content:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, -23)
    content:SetHeight(EXPANDED_HEIGHT - COLLAPSED_HEIGHT)
    window.content = content

    CreateWideButton(content, "Current Target", -5, AddCurrentTarget)

    for index, marker in ipairs(MARKERS) do
        -- 18px high controls; only 2px between rows.
        local y = -31 - (index - 1) * 20
        CreateMarkerIcon(content, marker, y)

        local field = CreateFrame("EditBox", nil, content,
            "InputBoxTemplate")
        field:SetAutoFocus(false)
        field:SetHeight(18)
        field:SetPoint("TOPLEFT", content, "TOPLEFT", 28, y)
        field:SetPoint("TOPRIGHT", content, "TOPRIGHT", -45, y)
        field:SetTextInsets(5, 5, 0, 0)
        field:SetMaxLetters(80)
        Components:StyleInput(field)

        field:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
        field:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        field:SetScript("OnTextChanged", function(self, userInput)
            settings.names[index] = self:GetText() or ""
            if userInput then ScheduleUpdate() end
        end)
        field:SetScript("OnEditFocusLost", function()
            if updateTimer then UpdateMacro(true) end
        end)
        field:SetText(settings.names[index])
        fields[index] = field

        local clear = CreateFrame("Button", nil, content)
        clear:SetSize(18, 18)
        clear:SetPoint("TOPRIGHT", content, "TOPRIGHT", -7, y)
        Components:StyleCloseButton(clear, {
            artSize = 15,
            crossSize = 7,
        })
        clear:SetScript("OnClick", function()
            field:SetText("")
            field:ClearFocus()
            UpdateMacro(true)
        end)
    end

    CreateSwapButton(content, 1)
    CreateSwapButton(content, 2)

    CreateWideButton(content, "Update Macro", -96, function()
        UpdateMacro(false)
    end)

    -- Show at full size once to migrate any existing center position.
    -- Future resizing uses the saved top-left anchor.
    window:Show()
    if not settings.topLeft then
        AnchorTopLeft(window, settings)
    end
    ApplyCollapsed()
end

local function ExpandWindow()
    if not window then CreateWindow() end
    local settings = GetSettings()
    if settings.collapsed then
        settings.collapsed = false
        ApplyCollapsed()
    end
end

UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if pendingUpdate then UpdateMacro(pendingSilent) end
end)

-- Keep the panel present after login and across reloads.
UI:RegisterEvent("PLAYER_LOGIN", CreateWindow)

UI:RegisterCommand("targets", "show", ExpandWindow,
    "Expand the always-visible target macro panel")

SLASH_KAMIUITARGET1 = "/kuitarget"
SlashCmdList.KAMIUITARGET = ExpandWindow
