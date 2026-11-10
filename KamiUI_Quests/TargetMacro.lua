local UI = KamiUI
local Module = UI:GetModule("Quests")
if not Module then return end

local Components = UI.Components
local Palette = UI.Palette
local Styles = UI.Styles

local MACRO_NAME = "KamiTargets"
local MACRO_ICON = "Ability_eyeoftheowl"
local MAX_MACRO_BYTES = 255
-- Triangle, moon, square, star, circle. Skull, cross and diamond
-- are intentionally reserved for normal group target markers.
local MARKERS = { 4, 5, 6, 1, 2 }
local MIN_VISIBLE_SLOTS = 3
local ROW_STEP = 20
local AUTO_UPDATE_DELAY = 0.7

-- English client spell names. The optional cast runs after targeting.
-- Ice Lance is a Frost talent in Forever, so Fire Blast works for all mages.
-- The former Curse of Agony is named Bane of Agony in Forever.
local AUTO_CAST_SPELLS = {
    DRUID = "Faerie Fire",
    PRIEST = "Shadow Word: Pain",
    MAGE = "Fire Blast",
    SHAMAN = "Earth Shock",
    WARRIOR = "Charge",
    WARLOCK = "Bane of Agony",
    HUNTER = "Arcane Shot",
    PALADIN = "Judgement",
    ROGUE = "Throw",
}

-- Cache the spell choice outside combat; spellbook information can
-- change when talents are learned or unlearned.
local resolvedAutoCastSpell
local pendingSpellRefresh = false

local function PlayerHasSpellInBook(spellName)
    local book = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank
        and Enum.SpellBookSpellBank.Player
    if not book or bank == nil
        or not book.GetNumSpellBookSkillLines
        or not book.GetSpellBookSkillLineInfo
        or not book.GetSpellBookItemName
    then
        return false
    end

    local numLines = book.GetNumSpellBookSkillLines()
    if not UI:CanAccessValue(numLines)
        or type(numLines) ~= "number" then
        return false
    end

    for lineIndex = 1, numLines do
        local line = book.GetSpellBookSkillLineInfo(lineIndex)
        if line and line.itemIndexOffset and line.numSpellBookItems then
            local first = line.itemIndexOffset + 1
            local last = line.itemIndexOffset + line.numSpellBookItems
            for slot = first, last do
                local name = book.GetSpellBookItemName(slot, bank)
                if UI:CanAccessValue(name) and name == spellName then
                    return true
                end
            end
        end
    end

    return false
end

local function RefreshAutoCastSpell()
    if InCombatLockdown and InCombatLockdown() then
        pendingSpellRefresh = true
        return
    end

    pendingSpellRefresh = false
    if not UnitClass then return end
    local _, class = UnitClass("player")
    resolvedAutoCastSpell = AUTO_CAST_SPELLS[class]

    -- Ice Lance is a Frost talent with several spell ranks. Check the
    -- actual player spellbook rather than only the rank-1 spell ID.
    if class == "MAGE" and PlayerHasSpellInBook("Ice Lance") then
        resolvedAutoCastSpell = "Ice Lance"
    end
end

local function GetAutoCastSpell()
    if resolvedAutoCastSpell then return resolvedAutoCastSpell end
    if not UnitClass then return nil end
    local _, class = UnitClass("player")
    return AUTO_CAST_SPELLS[class]
end

-- Desaturated gold shades for the two swap directions.
local SWAP_DOWN_COLOR = { 200 / 255, 163 / 255, 77 / 255, 1 } -- #C8A34D
local SWAP_UP_COLOR = { 143 / 255, 108 / 255, 44 / 255, 1 } -- #8F6C2C

local window
local fields = {}
local rows = {}
local swapButtons = {}
local updateTimer
local pendingUpdate = false
local RefreshLayout

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

    -- Migrate the original druid-only checkbox preference per character.
    if type(settings.autoCast) ~= "boolean" then
        settings.autoCast = settings.faerieFire == true
    end
    settings.faerieFire = nil

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

    -- Optionally cast a class-specific opener after the targeting commands.
    local autoCastSpell = GetAutoCastSpell()
    if settings.autoCast and autoCastSpell then
        lines[#lines + 1] = "/cast " .. autoCastSpell
    end

    -- Preserve the action-bar macro when every field is cleared.
    local body = #lines > 0 and table.concat(lines, "\n")
        or "/stopmacro"

    if #body > MAX_MACRO_BYTES then
        return nil, string.format(
            "Macro too long (%d/%d bytes). Shorten a target name.",
            #body, MAX_MACRO_BYTES
        ), #body
    end

    return body, nil, #body
end

local function CancelScheduledUpdate()
    if updateTimer then
        updateTimer:Cancel()
        updateTimer = nil
    end
end

-- All changes, including combat-deferred updates, report from here.
local function UpdateMacro()
    CancelScheduledUpdate()

    local body, errorMessage = BuildMacro()
    if not body then
        SetStatus(errorMessage)
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        if not pendingUpdate then
            SetStatus("Macro update queued until combat ends.")
        end
        pendingUpdate = true
        return
    end

    if not GetMacroInfo or not CreateMacro or not EditMacro then
        SetStatus("Macro API unavailable.")
        return
    end

    local macroName, _, currentBody = GetMacroInfo(MACRO_NAME)
    local exists = macroName ~= nil

    -- Only announce a successful change if the macro actually changed.
    if exists and currentBody == body then
        pendingUpdate = false
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
    if exists then
        SetStatus("Macro updated: " .. MACRO_NAME)
    else
        SetStatus("Macro created: " .. MACRO_NAME
            .. " - drag it to an action bar once")
    end
end

local function ScheduleUpdate()
    CancelScheduledUpdate()
    updateTimer = C_Timer.NewTimer(AUTO_UPDATE_DELAY, function()
        updateTimer = nil
        UpdateMacro()
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
            RefreshLayout()
            UpdateMacro()
            return
        end
    end

    SetStatus("All five slots are filled.")
end

-- Keep raid markers in their fixed slots; only reorder target names.
local function SwapTargets(firstIndex)
    local settings = GetSettings()
    local secondIndex = firstIndex + 1

    settings.names[firstIndex], settings.names[secondIndex] =
        settings.names[secondIndex], settings.names[firstIndex]

    fields[firstIndex]:SetText(settings.names[firstIndex])
    fields[secondIndex]:SetText(settings.names[secondIndex])
    RefreshLayout()
    UpdateMacro()
end

local EXPANDED_WIDTH = 205
local EXPANDED_HEIGHT = 93
local COLLAPSED_WIDTH = EXPANDED_WIDTH
local COLLAPSED_HEIGHT = 30

local function CreateWideButton(parent, label, y, onClick,
    rightInset, leftInset)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(20)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT",
        leftInset or 8, y)
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT",
        -(rightInset or 8), y)
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

    -- Reposition the arrow segments when extra rows make the
    -- swap buttons shorter; 3-slot appearance stays identical.
    local arrowLines = {}
    local function DrawArrow(color, segments)
        local r, g, b, a = Styles:GetColorChannels(color)
        for _, segment in ipairs(segments) do
            local line = button:CreateLine(nil, "OVERLAY")
            line:SetThickness(1.5)
            line:SetColorTexture(r, g, b, a)
            arrowLines[#arrowLines + 1] = {
                line = line, segment = segment,
            }
        end
    end

    -- Down: warm light gold; up: darker gold.
    DrawArrow(SWAP_DOWN_COLOR, {
        { 11, 4, 8, 4 }, { 8, 4, 5, 7 },
        { 5, 7, 5, 20 }, { 2, 17, 5, 20 },
        { 8, 17, 5, 20 },
    })
    DrawArrow(SWAP_UP_COLOR, {
        { 5, 24, 8, 24 }, { 8, 24, 11, 21 },
        { 11, 21, 11, 8 }, { 8, 11, 11, 8 },
        { 14, 11, 11, 8 },
    })

    function button:RefreshArrows()
        local height = self:GetHeight()
        local scale = 0.8 * height / 28

        local function Position(x, y)
            return 8 + (x - 8) * scale,
                height / 2 + (y - 14) * scale
        end

        for _, entry in ipairs(arrowLines) do
            local segment = entry.segment
            local x1, y1 = Position(segment[1], segment[2])
            local x2, y2 = Position(segment[3], segment[4])
            entry.line:SetStartPoint("TOPLEFT", self, x1, -y1)
            entry.line:SetEndPoint("TOPLEFT", self, x2, -y2)
        end
    end

    button:RefreshArrows()

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

-- Always show at least three rows and one blank row after the
-- last populated slot, up to the five available raid markers.
local function GetVisibleSlotCount()
    local count = MIN_VISIBLE_SLOTS
    local names = GetSettings().names

    for index = 1, #MARKERS do
        if NormalizeName(names[index]) ~= "" then
            count = math.max(count, math.min(#MARKERS, index + 1))
        end
    end

    return count
end

RefreshLayout = function()
    if not window or not window.rowsReady then return end

    local count = GetVisibleSlotCount()
    window.visibleSlots = count

    for index, row in ipairs(rows) do
        local visible = index <= count
        row.icon:SetShown(visible)
        row.field:SetShown(visible)
        row.clear:SetShown(visible)
    end

    -- The swap buttons collectively span the target rows, with 2px
    -- between buttons, regardless of whether 3, 4 or 5 are visible.
    local buttonHeight = (
        ROW_STEP * count - 2 - (count - 2) * 2
    ) / (count - 1)
    local top = 31
    for index, button in ipairs(swapButtons) do
        local visible = index < count
        button:SetShown(visible)
        if visible then
            button:SetHeight(buttonHeight)
            button:ClearAllPoints()
            button:SetPoint("TOPRIGHT", window.content,
                "TOPRIGHT", -27, -top)
            button:RefreshArrows()
            top = top + buttonHeight + 2
        end
    end

    -- Show oversized macro errors inside the panel immediately, not
    -- just in chat after the delayed update has already failed.
    local _, errorMessage, bytes = BuildMacro()
    local tooLong = errorMessage ~= nil
    local rowHeight = EXPANDED_HEIGHT
        + (count - MIN_VISIBLE_SLOTS) * ROW_STEP
    window.limitWarning:ClearAllPoints()
    window.limitWarning:SetPoint("TOPLEFT", window, "TOPLEFT",
        8, -rowHeight)
    window.limitWarning:SetText(tooLong and string.format(
        "Macro too long: %d/%d bytes", bytes, MAX_MACRO_BYTES
    ) or "")
    window.limitWarning:SetShown(
        tooLong and GetSettings().collapsed ~= true
    )

    window.expandedHeight = rowHeight + (tooLong and 16 or 0)
    window.content:SetHeight(window.expandedHeight)
    if GetSettings().collapsed ~= true then
        window:SetSize(EXPANDED_WIDTH, window.expandedHeight)
    end
end

local function ApplyCollapsed()
    if not window then return end

    RefreshLayout()
    local collapsed = GetSettings().collapsed == true
    window.content:SetShown(not collapsed)
    window.targetButton:SetShown(not collapsed)
    window.autoCastCheckbox:SetShown(not collapsed)
    window.collapsedLabel:SetShown(collapsed)
    window.limitWarning:SetShown(
        not collapsed and window.limitWarning:GetText() ~= ""
    )
    Components:SetButtonText(window.collapseButton,
        collapsed and "+" or "-")
    window:SetSize(
        collapsed and COLLAPSED_WIDTH or EXPANDED_WIDTH,
        collapsed and COLLAPSED_HEIGHT or window.expandedHeight
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

    -- The window itself is the drag surface. There is no title bar.
    -- The raid-marker textures and free spaces keep their normal
    -- drag behavior; only the top-right button toggles collapse.
    local content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    content:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
    content:SetHeight(EXPANDED_HEIGHT)
    window.content = content

    -- Reuse the same checkbox styling as Track Recipe.
    local autoCast = Components:CreateCheckbox(window, {
        size = 14,
        width = 20,
        height = 20,
    })
    autoCast:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -5)
    Components:SetToggleState(autoCast, settings.autoCast)
    autoCast:SetScript("OnClick", function(self)
        settings.autoCast = self:GetChecked() == true
        self:RefreshKamiToggleStyle()
        RefreshLayout()
        UpdateMacro()
    end)
    autoCast:SetScript("OnEnter", function(self)
        local spell = GetAutoCastSpell()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(spell and ("Auto-cast: " .. spell)
            or "Auto-cast unavailable")
        if spell then
            GameTooltip:AddLine(
                "Append /cast " .. spell .. " to KamiTargets.",
                1, 1, 1
            )
        end
        GameTooltip:Show()
    end)
    autoCast:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    window.autoCastCheckbox = autoCast

    window.targetButton = CreateWideButton(
        window, "Current Target", -5, AddCurrentTarget, 32, 30
    )

    local collapseButton = CreateFrame("Button", nil, window)
    collapseButton:SetSize(22, 20)
    collapseButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -8, -5)
    Components:StyleButton(collapseButton, { text = "-" })
    collapseButton:SetScript("OnClick", function()
        settings.collapsed = not settings.collapsed
        ApplyCollapsed()
    end)
    window.collapseButton = collapseButton

    local collapsedLabel = window:CreateFontString(nil, "OVERLAY")
    Styles:ApplyText(collapsedLabel, "panelTitle", Palette.gold)
    collapsedLabel:SetPoint("CENTER", window.targetButton,
        "CENTER", 0, 0)
    collapsedLabel:SetText("Targets")
    window.collapsedLabel = collapsedLabel

    for index, marker in ipairs(MARKERS) do
        -- 18px high controls; only 2px between rows.
        local y = -31 - (index - 1) * ROW_STEP
        local markerIcon = CreateMarkerIcon(content, marker, y)

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
            if window and window.rowsReady then RefreshLayout() end
            if userInput then ScheduleUpdate() end
        end)
        field:SetScript("OnEditFocusLost", function()
            if updateTimer then UpdateMacro() end
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
            -- Programmatic SetText() does not count as user input. Update
            -- the saved slot explicitly instead of relying on the edit
            -- box's OnTextChanged event to synchronize it.
            settings.names[index] = ""
            field:SetText("")
            field:ClearFocus()
            RefreshLayout()
            UpdateMacro()
        end)

        rows[index] = {
            icon = markerIcon, field = field, clear = clear,
        }
    end

    for index = 1, #MARKERS - 1 do
        swapButtons[index] = CreateSwapButton(content, index)
    end

    local warning = window:CreateFontString(nil, "OVERLAY")
    Styles:ApplyText(warning, 9, Palette.difficulty.veryHard)
    warning:SetJustifyH("LEFT")
    warning:SetHeight(14)
    window.limitWarning = warning
    window.rowsReady = true

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
    if pendingSpellRefresh then
        RefreshAutoCastSpell()
        UpdateMacro()
    elseif pendingUpdate then
        UpdateMacro()
    end
end)

UI:RegisterEvent("SPELLS_CHANGED", function()
    if InCombatLockdown and InCombatLockdown() then
        pendingSpellRefresh = true
        return
    end

    local previous = GetAutoCastSpell()
    RefreshAutoCastSpell()
    if previous ~= GetAutoCastSpell() then
        UpdateMacro()
    end
end)

-- Keep the panel present after login and across reloads.
UI:RegisterEvent("PLAYER_LOGIN", function()
    RefreshAutoCastSpell()
    CreateWindow()
    UpdateMacro()
end)

UI:RegisterCommand("targets", "show", ExpandWindow,
    "Expand the always-visible target macro panel")

SLASH_KAMIUITARGET1 = "/kuitarget"
SlashCmdList.KAMIUITARGET = ExpandWindow
