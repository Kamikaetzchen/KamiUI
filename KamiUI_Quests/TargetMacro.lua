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

local window
local fields = {}
local statusText
local pendingUpdate = false

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

local function SetStatus(message, color)
    if not statusText then return end
    statusText:SetText(message or "")
    Styles:SetTextColor(statusText, color or Palette.muted)
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

local function UpdateMacro()
    local body, errorMessage = BuildMacro()
    if not body then
        SetStatus(errorMessage, Palette.difficulty.veryHard)
        UI:Print(errorMessage)
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        pendingUpdate = true
        SetStatus("Update queued until combat ends.", Palette.gold)
        return
    end

    if not GetMacroInfo or not CreateMacro or not EditMacro then
        SetStatus("Macro API unavailable.", Palette.difficulty.veryHard)
        return
    end

    local exists = GetMacroInfo(MACRO_NAME) ~= nil
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
        SetStatus("Could not update macro (macro slots full?).",
            Palette.difficulty.veryHard)
        UI:Print("Could not create/update " .. MACRO_NAME)
        return
    end

    pendingUpdate = false
    SetStatus(exists and "Macro updated: " .. MACRO_NAME
        or "Macro created: " .. MACRO_NAME, Palette.success)

    UI:Print(exists and "Updated " .. MACRO_NAME
        or "Created " .. MACRO_NAME
            .. " - drag it to an action bar once")
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
            return
        end
    end

    SetStatus("All three slots are filled.", Palette.gold)
end

local function CreateButton(parent, label, width, x, y, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 25)
    button:SetPoint("TOP", parent, "TOP", x, y)
    Components:StyleButton(button, { text = label })
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateWindow()
    if window then return end

    local settings = GetSettings()
    window = Components:CreateWindow("KamiUITargetMacroWindow", {
        width = 350,
        height = 274,
        header = { title = "Target Macro" },
        onDragStop = function(frame)
            UI:SaveFramePosition(frame, settings)
        end,
    })

    UI:ApplyFramePosition(window, settings, "position", 0, 0)
    Components:RegisterEscapeClose(window)
    Components:CreateWindowCloseButton(window.header, {
        onClick = function() window:Hide() end,
    })

    CreateButton(window, "Current Target", 150, 0, -42,
        AddCurrentTarget)

    local descriptions = {
        "4 - Triangle",
        "5 - Moon",
        "6 - Square",
    }

    for index = 1, #MARKERS do
        local y = -86 - (index - 1) * 37
        local label = window:CreateFontString(nil, "OVERLAY")
        Styles:ApplyText(label, "normal", Palette.text)
        label:SetPoint("TOPLEFT", window, "TOPLEFT", 16, y - 4)
        label:SetWidth(100)
        label:SetJustifyH("LEFT")
        label:SetText(descriptions[index])

        local field = CreateFrame("EditBox", nil, window,
            "InputBoxTemplate")
        field:SetAutoFocus(false)
        field:SetSize(208, 24)
        field:SetPoint("TOPRIGHT", window, "TOPRIGHT", -16, y)
        field:SetTextInsets(7, 7, 0, 0)
        field:SetMaxLetters(80)
        Components:StyleInput(field)

        field:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
        field:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        field:SetScript("OnTextChanged", function(self)
            settings.names[index] = self:GetText() or ""
            SetStatus("Click Generate / Update Macro to apply.")
        end)
        field:SetText(settings.names[index])
        fields[index] = field
    end

    CreateButton(window, "Generate / Update Macro", 225, 0, -208,
        UpdateMacro)

    statusText = window:CreateFontString(nil, "OVERLAY")
    Styles:ApplyText(statusText, "small", Palette.muted)
    statusText:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 12, 12)
    statusText:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -12, 12)
    statusText:SetJustifyH("CENTER")
    statusText:SetText("Macro: " .. MACRO_NAME)
end

local function ToggleWindow()
    if not window then CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
    end
end

UI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if pendingUpdate then UpdateMacro() end
end)

UI:RegisterCommand("targets", "toggle", ToggleWindow,
    "Open the three-slot target macro editor")

SLASH_KAMIUITARGET1 = "/kuitarget"
SlashCmdList.KAMIUITARGET = ToggleWindow
