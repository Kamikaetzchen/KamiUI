local UI = KamiUI
local Module = UI:GetModule("ItemRating")
local Components = UI.Components
local Palette = UI.Palette
local Styles = UI.Styles

local ROW_HEIGHT = 19
local SOURCE_WIDTH = 96
local SOURCE_X = 238
local ROW_BASE_WIDTH = 242

local FIELDS = Module.statFields

local CAP_INFO = {
    ITEM_MOD_HIT_RATING_SHORT = {
        "Melee Hit cap: 8% against a level 63 raid boss.",
        "Already-capped stats are not discounted.",
    },
    ITEM_MOD_EXPERTISE_RATING_SHORT = {
        "Expertise: 10 rating removes 1% dodge; 6.5% boss dodge.",
        "Attacking from behind avoids parries.",
    },
}

local function Profile()
    return Module:GetSelectedProfile()
end

local function ClassLabel()
    local name = UnitClass and UnitClass("player")
    return (UI:CanAccessValue(name) and type(name) == "string")
        and name or "Class"
end

local function FormatWeight(value)
    return type(value) == "number"
        and string.format("%.4f", value) or "--"
end

local function CommitInput(input)
    local profile = Profile()
    if not profile then return end
    local inputText = input:GetText()
    if not UI:CanAccessValue(inputText)
        or type(inputText) ~= "string" then return end

    local value = tonumber((inputText:gsub(",", ".")))
    if not value or value ~= value or value < 0 or value > 100000 then
        UI:Print("Invalid Item Rating weight for " .. input.statLabel)
    elseif math.abs(value - (profile.weights[input.statKey] or 0))
        > 0.0000001 then
        Module:SetWeight(profile.classFile, profile.spec,
            input.statKey, value)
    end
    input:SetText(FormatWeight(profile.weights[input.statKey]))
end

local function RefreshInputs(frame)
    local profile = Profile()
    if not profile then return end

    if frame.profileDropdown then
        Components:RefreshDropdown(frame.profileDropdown)
    end
    frame.assumptions:SetText(profile.assumptions or "")
    for _, input in ipairs(frame.weightInputs) do
        input:SetText(FormatWeight(profile.weights[input.statKey]))
    end

    for index, heading in ipairs(frame.sourceHeadings) do
        local source = profile.references[index]
        heading:SetText(source and source.label or "")
        frame.sourceButtons[index]:SetShown(source ~= nil)
    end
    for key, cells in pairs(frame.sourceCells) do
        for index, cell in ipairs(cells) do
            local source = profile.references[index]
            cell:SetText(FormatWeight(
                source and source.weights[key] or nil
            ))
        end
    end
end

local function ShowStatTooltip(button)
    local profile = Profile()
    if not profile then return end
    local key = button.statKey

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.statLabel, 1, 0.82, 0.28)
    GameTooltip:AddDoubleLine(
        "Current", FormatWeight(profile.weights[key]),
        0.8, 0.8, 0.85, 1, 0.82, 0.31
    )
    for _, reference in ipairs(profile.references) do
        GameTooltip:AddDoubleLine(
            reference.label, FormatWeight(reference.weights[key]),
            0.7, 0.8, 0.9, 0.73, 0.89, 0.77
        )
    end

    if (key == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
        or key == "ITEM_MOD_WEAPON_DAMAGE_SHORT")
        and profile.references[1]
        and profile.references[1].weights[key] == nil
        and (profile.weights[key] or 0) ~= 0 then
        GameTooltip:AddLine("Local weapon-damage approximation; "
            .. "not supplied by this source.",
            0.72, 0.74, 0.80, true)
    end

    local cap = CAP_INFO[key]
    if cap then
        GameTooltip:AddLine(" ")
        for _, line in ipairs(cap) do
            GameTooltip:AddLine(line, 0.68, 0.75, 0.82, true)
        end
    end
    GameTooltip:AddLine(
        "Weights are per raw stat point; -- means not published.",
        0.62, 0.66, 0.73, true
    )
    GameTooltip:Show()
end

local function CreateScroll(frame, rowWidth)
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 13, -137)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -25, 54)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(rowWidth, ROW_HEIGHT * #FIELDS)
    scroll:SetScrollChild(content)

    local bar = CreateFrame("Slider", nil, frame)
    bar:SetOrientation("VERTICAL")
    bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 11, -1)
    bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 11, 1)
    bar:SetWidth(6)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(ROW_HEIGHT)
    Components:StyleScrollBar(bar)

    bar:SetScript("OnValueChanged", function(_, value)
        scroll:SetVerticalScroll(value or 0)
    end)

    local function UpdateRange()
        local maxScroll = math.max(
            0, ROW_HEIGHT * #FIELDS - (scroll:GetHeight() or 0)
        )
        bar:SetMinMaxValues(0, maxScroll)
        bar:SetShown(maxScroll > 0)
        bar:SetValue(math.min(bar:GetValue() or 0, maxScroll))
    end

    scroll:SetScript("OnMouseWheel", function(_, direction)
        local maxScroll = math.max(
            0, ROW_HEIGHT * #FIELDS - (scroll:GetHeight() or 0)
        )
        local nextValue = (bar:GetValue() or 0)
            - direction * ROW_HEIGHT * 3
        bar:SetValue(math.max(0, math.min(nextValue, maxScroll)))
    end)
    scroll:SetScript("OnSizeChanged", UpdateRange)
    frame:HookScript("OnShow", UpdateRange)
    return content
end

local function ClearInputFocus(frame)
    for _, input in ipairs(frame.weightInputs) do
        if input:HasFocus() then input:ClearFocus() end
    end
end

local function CreateSettingsWindow()
    local profile = Profile()
    if not profile then return nil end

    local profiles = Module:GetClassProfiles()
    local maxSources = 1
    for _, entry in ipairs(profiles) do
        maxSources = math.max(maxSources, #entry.references)
    end
    local rowWidth = ROW_BASE_WIDTH + SOURCE_WIDTH * maxSources
    local frame = Components:CreateWindow(
        "KamiUIItemRatingSettings", {
            width = rowWidth + 44,
            height = 510,
            strata = "DIALOG",
            header = { title = "Item Rating", height = 34 },
        }
    )
    frame:SetPoint("CENTER", UIParent, "CENTER", 140, 0)
    frame.weightInputs = {}
    frame.sourceButtons = {}
    frame.sourceHeadings = {}
    frame.sourceCells = {}

    Components:CreateWindowCloseButton(frame, {
        point = "TOPRIGHT",
        x = -6, y = -6,
        onClick = function() frame:Hide() end,
    })
    Components:RegisterEscapeClose(frame)

    local dropdown = Components:CreateDropdown(frame, {
        buttonWidth = math.min(300, rowWidth - 18),
        buttonHeight = 22,
        menuParent = UIParent,
        menuFrameStrata = "DIALOG",
        minWidth = math.min(300, rowWidth - 18),
        getEntries = function()
            return Module:GetClassProfiles()
        end,
        getText = function(entry)
            return ClassLabel() .. " - " .. entry.label
        end,
        getButtonText = function()
            local current = Profile()
            return current and (ClassLabel() .. " - " .. current.label) or "Profile"
        end,
        isSelected = function(entry)
            local current = Profile()
            return current and entry.spec == current.spec
        end,
        onSelect = function(entry)
            -- Save any edited value to the old profile first.
            ClearInputFocus(frame)
            Module:SetSelectedProfile(entry.classFile, entry.spec)
            RefreshInputs(frame)
        end,
    })
    dropdown.button:SetPoint(
        "TOPLEFT", frame, "TOPLEFT", 17, -42
    )
    frame.profileDropdown = dropdown

    local assumptions = frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )
    assumptions:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, -70)
    Styles:ApplyText(assumptions, "muted", Palette.muted)
    frame.assumptions = assumptions

    local currentHeader = frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )
    currentHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 167, -99)
    currentHeader:SetText("Current")

    for index = 1, maxSources do
        local x = SOURCE_X + (index - 1) * SOURCE_WIDTH + 13
        local heading = frame:CreateFontString(
            nil, "OVERLAY", "GameFontNormalSmall"
        )
        heading:SetSize(90, 18)
        heading:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -97)
        heading:SetJustifyH("CENTER")
        frame.sourceHeadings[index] = heading

        local copy = CreateFrame("Button", nil, frame)
        copy:SetSize(76, 20)
        copy:SetPoint("TOPLEFT", frame, "TOPLEFT", x + 7, -114)
        Components:StyleButton(copy, { text = "Use" })
        copy:SetScript("OnClick", function()
            local selected = Profile()
            local reference = selected and selected.references[index]
            if not reference then return end

            ClearInputFocus(frame)
            Module:ApplyReferenceWeights(
                selected.classFile, selected.spec, reference.id
            )
            RefreshInputs(frame)
        end)
        copy:SetScript("OnEnter", function(self)
            local selected = Profile()
            local reference = selected and selected.references[index]
            if not reference then return end

            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(reference.label, 1, 0.82, 0.28)
            GameTooltip:AddLine(reference.description or "",
                0.85, 0.85, 0.85, true)
            GameTooltip:AddLine("Reference: " .. (reference.date or ""),
                0.7, 0.75, 0.82, true)
            GameTooltip:AddLine("Copies published weights only; "
                .. "missing stats stay unchanged.",
                0.7, 0.85, 0.72, true)
            if reference.url then
                GameTooltip:AddLine(reference.url,
                    0.6, 0.7, 0.85, true)
            end
            GameTooltip:Show()
        end)
        copy:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.sourceButtons[index] = copy
    end

    local content = CreateScroll(frame, rowWidth)
    for index, field in ipairs(FIELDS) do
        local key, label = field[1], field[2]
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(rowWidth, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", content, "TOPLEFT",
            0, -(index - 1) * ROW_HEIGHT)

        local labelButton = CreateFrame("Button", nil, row)
        labelButton:SetSize(147, ROW_HEIGHT)
        labelButton:SetPoint("LEFT", row, "LEFT", 0, 0)
        labelButton.statKey = key
        labelButton.statLabel = label

        local name = labelButton:CreateFontString(
            nil, "OVERLAY", "GameFontNormalSmall"
        )
        name:SetPoint("LEFT", 2, 0)
        name:SetJustifyH("LEFT")
        name:SetText(label)
        labelButton:SetScript("OnEnter", ShowStatTooltip)
        labelButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        local input = CreateFrame(
            "EditBox", nil, row, "InputBoxTemplate"
        )
        input:SetSize(74, 18)
        input:SetPoint("LEFT", row, "LEFT", 152, 0)
        input:SetAutoFocus(false)
        input:SetMaxLetters(12)
        input.statKey = key
        input.statLabel = label
        Components:StyleInput(input)
        if input.SetTextInsets then
            input:SetTextInsets(6, 3, 0, 0)
        end
        input:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
        input:SetScript("OnEscapePressed", function(self)
            local current = Profile()
            if current then
                self:SetText(FormatWeight(
                    current.weights[self.statKey]
                ))
            end
            self:ClearFocus()
        end)
        input:SetScript("OnEditFocusLost", CommitInput)
        frame.weightInputs[#frame.weightInputs + 1] = input

        frame.sourceCells[key] = {}
        for sourceIndex = 1, maxSources do
            local weight = row:CreateFontString(
                nil, "OVERLAY", "GameFontNormalSmall"
            )
            weight:SetPoint("LEFT", row, "LEFT",
                SOURCE_X + (sourceIndex - 1) * SOURCE_WIDTH, 0)
            weight:SetWidth(88)
            weight:SetJustifyH("RIGHT")
            weight:SetTextColor(0.73, 0.89, 0.77)
            frame.sourceCells[key][sourceIndex] = weight
        end
    end

    local note = frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )
    note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 17, 48)
    Styles:ApplyText(note, "muted", Palette.muted)
    note:SetText("Per raw stat point. -- = source has no weight.")

    local reset = CreateFrame("Button", nil, frame)
    reset:SetSize(115, 23)
    reset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 17, 14)
    Components:StyleButton(reset, { text = "Reset Defaults" })
    reset:SetScript("OnClick", function()
        ClearInputFocus(frame)
        local current = Profile()
        if current then
            Module:ResetWeights(current.classFile, current.spec)
            RefreshInputs(frame)
        end
    end)

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(79, 23)
    close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 14)
    Components:StyleButton(close, { text = "Close" })
    close:SetScript("OnClick", function() frame:Hide() end)

    frame:HookScript("OnShow", RefreshInputs)
    RefreshInputs(frame)
    frame:SetScript("OnHide", function(self)
        for _, input in ipairs(self.weightInputs) do
            if input:HasFocus() then input:ClearFocus() end
        end
    end)

    Module.settingsWindow = frame
    return frame
end

function Module:RefreshSettings()
    if self.settingsWindow and self.settingsWindow:IsShown() then
        RefreshInputs(self.settingsWindow)
    end
end

function Module:ToggleSettings()
    local frame = self.settingsWindow or CreateSettingsWindow()
    if not frame then return end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function Module:AttachCharacterButton()
    if self.characterButton then return end

    local characters = UI:GetModule("Characters")
    local frame = characters and characters.frame
    local trinket = frame and frame.equipmentByKey
        and frame.equipmentByKey.Trinket1Slot
    if not trinket or not frame.characterPane then return end

    local button = CreateFrame("Button", nil, frame.characterPane)
    button:SetSize(74, 20)
    button:SetPoint(
        "BOTTOMRIGHT", frame.characterPane, "BOTTOMRIGHT", -6, 6
    )
    button:SetFrameLevel(trinket:GetFrameLevel() + 2)
    Components:StyleButton(button, {
        metallic = true,
        text = "Item Rating",
        frameColor = frame.KamiClassTint,
    })
    frame.KamiItemRatingButton = button
    button:SetScript("OnClick", function() Module:ToggleSettings() end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
        GameTooltip:SetText("Item Rating")
        GameTooltip:AddLine(
            "Edit current weights or apply a reference source.",
            0.75, 0.75, 0.75
        )
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.characterButton = button
end

UI:RegisterCommand(
    "rating", "settings",
    function() Module:ToggleSettings() end,
    "edit Item Rating stat weights"
)
Module:AttachCharacterButton()
UI:RegisterEvent("ADDON_LOADED", function(_, addon)
    if addon == "KamiUI_Characters" then
        Module:AttachCharacterButton()
    end
end)
