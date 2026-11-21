local UI = KamiUI
local Module = UI:GetModule("ItemRating")
local Components = UI.Components
local Palette = UI.Palette
local Styles = UI.Styles

local ROW_HEIGHT = 19
local SOURCE_WIDTH = 96
local SOURCE_X = 238
local ROW_BASE_WIDTH = 242

local FIELDS = {
    { "ITEM_MOD_STRENGTH_SHORT", "Strength" },
    { "ITEM_MOD_AGILITY_SHORT", "Agility" },
    { "ITEM_MOD_STAMINA_SHORT", "Stamina" },
    { "RESISTANCE0_NAME", "Armor" },
    { "ITEM_MOD_INTELLECT_SHORT", "Intellect" },
    { "ITEM_MOD_SPIRIT_SHORT", "Spirit" },
    { "ITEM_MOD_ATTACK_POWER_SHORT", "Attack Power" },
    { "ITEM_MOD_FERAL_ATTACK_POWER_SHORT", "Feral Attack Power" },
    { "ITEM_MOD_CRIT_RATING_SHORT", "Crit Rating" },
    { "ITEM_MOD_HIT_RATING_SHORT", "Hit Rating" },
    { "ITEM_MOD_HASTE_RATING_SHORT", "Haste Rating" },
    { "ITEM_MOD_EXPERTISE_RATING_SHORT", "Expertise Rating" },
    { "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT", "Armor Pen. Rating" },
    { "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "Weapon DPS" },
    { "ITEM_MOD_WEAPON_DAMAGE_SHORT", "Weapon Damage" },
    { "ITEM_MOD_SPELL_POWER_SHORT", "Spell Power" },
    { "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "Spell Damage" },
    { "ITEM_MOD_SPELL_HEALING_DONE_SHORT", "Spell Healing" },
    { "ITEM_MOD_DODGE_RATING_SHORT", "Dodge Rating" },
    { "ITEM_MOD_PARRY_RATING_SHORT", "Parry Rating" },
    { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "Defense Skill" },
    { "ITEM_MOD_BLOCK_RATING_SHORT", "Block Rating" },
    { "ITEM_MOD_BLOCK_VALUE_SHORT", "Block Value" },
    { "ITEM_MOD_MANA_REGENERATION_SHORT", "Mana Regen" },
}

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
    return Module:GetActiveProfile()
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

    local value = tonumber(inputText:gsub(",", "."))
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
    for _, input in ipairs(frame.weightInputs) do
        input:SetText(FormatWeight(profile.weights[input.statKey]))
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

    if key == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
        or key == "ITEM_MOD_WEAPON_DAMAGE_SHORT" then
        GameTooltip:AddLine("Local weapon-damage approximation, "
            .. "not a published SixtySim weight.",
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

local function CreateSettingsWindow()
    local profile = Profile()
    if not profile then return nil end
    local references = profile.references
    local rowWidth = ROW_BASE_WIDTH + SOURCE_WIDTH * #references
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

    Components:CreateWindowCloseButton(frame, {
        point = "TOPRIGHT",
        x = -6, y = -6,
        onClick = function() frame:Hide() end,
    })
    Components:RegisterEscapeClose(frame)

    local profileTitle = frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormal"
    )
    profileTitle:SetPoint("TOPLEFT", 17, -45)
    profileTitle:SetText("Druid - " .. profile.label)

    local assumptions = frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )
    assumptions:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, -66)
    assumptions:SetText("Lv 60  |  Raid buffs + standard talents")
    Styles:ApplyText(assumptions, "muted", Palette.muted)

    local currentHeader = frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )
    currentHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 167, -95)
    currentHeader:SetText("Current")

    for index, reference in ipairs(references) do
        local x = SOURCE_X + (index - 1) * SOURCE_WIDTH + 13
        local label = frame:CreateFontString(
            nil, "OVERLAY", "GameFontNormalSmall"
        )
        label:SetSize(90, 18)
        label:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -94)
        label:SetJustifyH("CENTER")
        label:SetText(reference.label)

        local copy = CreateFrame("Button", nil, frame)
        copy:SetSize(76, 20)
        copy:SetPoint("TOPLEFT", frame, "TOPLEFT", x + 7, -111)
        Components:StyleButton(copy, { text = "Use" })
        copy:SetScript("OnClick", function()
            for _, input in ipairs(frame.weightInputs) do
                if input:HasFocus() then input:ClearFocus() end
            end
            Module:ApplyReferenceWeights(
                profile.classFile, profile.spec, reference.id
            )
            RefreshInputs(frame)
        end)
        copy:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(reference.label, 1, 0.82, 0.28)
            GameTooltip:AddLine(reference.description,
                0.85, 0.85, 0.85, true)
            GameTooltip:AddLine("Reference: " .. reference.date,
                0.7, 0.75, 0.82, true)
            GameTooltip:AddLine("Copies published weights only; "
                .. "missing stats stay unchanged.",
                0.7, 0.85, 0.72, true)
            GameTooltip:AddLine(reference.url,
                0.6, 0.7, 0.85, true)
            GameTooltip:Show()
        end)
        copy:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
            self:SetText(FormatWeight(
                profile.weights[self.statKey]
            ))
            self:ClearFocus()
        end)
        input:SetScript("OnEditFocusLost", CommitInput)
        frame.weightInputs[#frame.weightInputs + 1] = input

        for sourceIndex, reference in ipairs(references) do
            local weight = row:CreateFontString(
                nil, "OVERLAY", "GameFontNormalSmall"
            )
            weight:SetPoint("LEFT", row, "LEFT",
                SOURCE_X + (sourceIndex - 1) * SOURCE_WIDTH, 0)
            weight:SetWidth(88)
            weight:SetJustifyH("RIGHT")
            weight:SetTextColor(0.73, 0.89, 0.77)
            weight:SetText(FormatWeight(reference.weights[key]))
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
        for _, input in ipairs(frame.weightInputs) do
            if input:HasFocus() then input:ClearFocus() end
        end
        Module:ResetWeights(profile.classFile, profile.spec)
        RefreshInputs(frame)
    end)

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(79, 23)
    close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 14)
    Components:StyleButton(close, { text = "Close" })
    close:SetScript("OnClick", function() frame:Hide() end)

    frame:HookScript("OnShow", RefreshInputs)
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
    Components:StyleButton(button, { text = "Item Rating" })
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
