local UI = KamiUI
local Module = UI:GetModule("ItemRating")
local Components = UI.Components
local Palette = UI.Palette
local Styles = UI.Styles

-- Cat is the sole scoring profile for now. Layout/controls stay local to
-- Item Rating: neither Characters nor Tooltips knows about this editor.
local CLASS, SPEC = "DRUID", "cat"
local ROW_HEIGHT = 19

local FIELDS = {
    { "ITEM_MOD_STRENGTH_SHORT", "Strength" },
    { "ITEM_MOD_AGILITY_SHORT", "Agility" },
    { "ITEM_MOD_STAMINA_SHORT", "Stamina" },
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
    { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "Defense Rating" },
    { "ITEM_MOD_BLOCK_RATING_SHORT", "Block Rating" },
    { "ITEM_MOD_BLOCK_VALUE_SHORT", "Block Value" },
    { "ITEM_MOD_MANA_REGENERATION_SHORT", "Mana Regen" },
}

local function Profile()
    return Module.profiles[CLASS] and Module.profiles[CLASS][SPEC]
end

local function FormatWeight(value)
    return string.format("%.4f", value or 0)
end

local function RefreshEffective(frame)
    if not frame or not frame.effectiveByKey then
        return
    end

    local profile = Profile()
    if not profile then
        return
    end

    for key, label in pairs(frame.effectiveByKey) do
        local effective = Module:GetEffectiveWeightInfo(profile, key)
        label:SetText(FormatWeight(effective))
    end
end

local function CommitInput(input)
    local profile = Profile()
    if not profile then
        return
    end

    local text = input:GetText()
    if not UI:CanAccessValue(text) or type(text) ~= "string" then
        return
    end

    local value = tonumber((text:gsub(",", ".")))
    if not value or value ~= value or value < 0 or value > 100000 then
        UI:Print("Invalid Item Rating weight for " .. input.statLabel)
    elseif math.abs(value - profile.weights[input.statKey]) > 0.00005 then
        Module:SetWeight(CLASS, SPEC, input.statKey, value)
    end

    input:SetText(FormatWeight(profile.weights[input.statKey]))
    RefreshEffective(Module.settingsWindow)
end

local function RefreshInputs(frame)
    local profile = Profile()
    if not profile then
        return
    end

    for _, input in ipairs(frame.weightInputs) do
        input:SetText(FormatWeight(profile.weights[input.statKey]))
    end

    Components:SetToggleState(
        frame.kingsCheckbox,
        Module:IsKingsEnabled(CLASS, SPEC)
    )
    RefreshEffective(frame)
end

local function ShowStatTooltip(button)
    local profile = Profile()
    if not profile then
        return
    end

    local base = profile.weights[button.statKey] or 0
    local effective, multiplier, effects =
        Module:GetEffectiveWeightInfo(profile, button.statKey)

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.statLabel, 1, 0.82, 0.28)
    GameTooltip:AddDoubleLine(
        "Base weight", FormatWeight(base),
        0.8, 0.8, 0.85, 1, 0.85, 0.4
    )

    for _, effect in ipairs(effects) do
        GameTooltip:AddDoubleLine(
            effect.name, string.format("x%.4f", effect.factor),
            0.76, 0.81, 0.91, 0.6, 0.95, 0.68
        )
        GameTooltip:AddLine(
            effect.detail, 0.62, 0.66, 0.73, true
        )
    end

    GameTooltip:AddDoubleLine(
        "Total multiplier", string.format("x%.4f", multiplier),
        0.78, 0.79, 0.83, 1, 0.82, 0.31
    )
    GameTooltip:AddDoubleLine(
        "Effective weight", FormatWeight(effective),
        1, 0.82, 0.31, 1, 0.82, 0.31
    )

    if base == 0 then
        GameTooltip:AddLine(
            "Cat DPS weight is 0; editable for future profiles.",
            0.63, 0.66, 0.74, true
        )
    end
    GameTooltip:Show()
end

local function CreateScroll(frame)
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 13, -116)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -25, 48)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(324, ROW_HEIGHT * #FIELDS)
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
        local visibleHeight = scroll:GetHeight() or 0
        local maxScroll = math.max(
            0, ROW_HEIGHT * #FIELDS - visibleHeight
        )
        bar:SetMinMaxValues(0, maxScroll)
        if maxScroll <= 0 then
            bar:Hide()
        else
            bar:Show()
        end
        bar:SetValue(math.min(bar:GetValue() or 0, maxScroll))
    end

    scroll:SetScript("OnMouseWheel", function(_, direction)
        local nextValue = (bar:GetValue() or 0)
            - direction * ROW_HEIGHT * 3
        local maxScroll = math.max(
            0, ROW_HEIGHT * #FIELDS - (scroll:GetHeight() or 0)
        )
        bar:SetValue(math.max(0, math.min(nextValue, maxScroll)))
    end)
    scroll:SetScript("OnSizeChanged", UpdateRange)
    frame:HookScript("OnShow", UpdateRange)

    return content
end

local function CreateSettingsWindow()
    local frame = Components:CreateWindow(
        "KamiUIItemRatingSettings", {
            width = 366,
            height = 492,
            strata = "DIALOG",
            header = {
                title = "Item Rating",
                height = 34,
            },
        }
    )
    frame:SetPoint("CENTER", UIParent, "CENTER", 140, 0)
    frame.weightInputs = {}
    frame.effectiveByKey = {}

    Components:CreateWindowCloseButton(frame, {
        point = "TOPRIGHT",
        x = -6, y = -6,
        onClick = function() frame:Hide() end,
    })
    Components:RegisterEscapeClose(frame)

    local profileTitle = frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormal"
    )
    profileTitle:SetPoint("TOPLEFT", 17, -44)
    profileTitle:SetText("Druid - Feral Cat")

    local kings = Components:CreateCheckbox(frame, {
        size = 14,
        height = 16,
        width = 318,
        label = "Blessing of Kings (+10% attributes)",
    })
    kings:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, -71)
    kings:HookScript("OnClick", function(self)
        Module:SetKingsEnabled(CLASS, SPEC, self:GetChecked())
        RefreshEffective(frame)
    end)
    frame.kingsCheckbox = kings

    local baseHeader = frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )
    baseHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 169, -97)
    baseHeader:SetText("Base")

    local effHeader = frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )
    effHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 264, -97)
    effHeader:SetText("Effective")

    local content = CreateScroll(frame)
    for index, field in ipairs(FIELDS) do
        local key, label = field[1], field[2]
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(324, ROW_HEIGHT)
        row:SetPoint(
            "TOPLEFT", content, "TOPLEFT",
            0, -(index - 1) * ROW_HEIGHT
        )

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
            local profile = Profile()
            if profile then
                self:SetText(FormatWeight(
                    profile.weights[self.statKey]
                ))
            end
            self:ClearFocus()
        end)
        input:SetScript("OnEditFocusLost", CommitInput)
        frame.weightInputs[#frame.weightInputs + 1] = input

        local effective = row:CreateFontString(
            nil, "OVERLAY", "GameFontNormalSmall"
        )
        effective:SetPoint("LEFT", row, "LEFT", 245, 0)
        effective:SetWidth(69)
        effective:SetJustifyH("RIGHT")
        effective:SetTextColor(0.73, 0.89, 0.77)
        frame.effectiveByKey[key] = effective
    end

    local note = frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )
    note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 17, 47)
    Styles:ApplyText(note, "muted", Palette.muted)
    note:SetText("Hover stats for multiplier details. Scroll for more.")

    local reset = CreateFrame("Button", nil, frame)
    reset:SetSize(115, 23)
    reset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 17, 14)
    Components:StyleButton(reset, { text = "Reset Defaults" })
    reset:SetScript("OnClick", function()
        for _, input in ipairs(frame.weightInputs) do
            if input:HasFocus() then
                input:ClearFocus()
            end
        end
        Module:ResetWeights(CLASS, SPEC)
        RefreshInputs(frame)
    end)

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(79, 23)
    close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 14)
    Components:StyleButton(close, { text = "Close" })
    close:SetScript("OnClick", function() frame:Hide() end)

    frame:HookScript("OnShow", function(self)
        RefreshInputs(self)
    end)
    frame:SetScript("OnHide", function(self)
        for _, input in ipairs(self.weightInputs) do
            if input:HasFocus() then
                input:ClearFocus()
            end
        end
    end)

    Module.settingsWindow = frame
    return frame
end

function Module:RefreshSettings()
    if self.settingsWindow and self.settingsWindow:IsShown() then
        RefreshEffective(self.settingsWindow)
    end
end

function Module:ToggleSettings()
    local frame = self.settingsWindow or CreateSettingsWindow()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

function Module:AttachCharacterButton()
    if self.characterButton then
        return
    end

    local characters = UI:GetModule("Characters")
    local frame = characters and characters.frame
    local trinket = frame and frame.equipmentByKey
        and frame.equipmentByKey.Trinket1Slot

    if not trinket or not frame.characterPane then
        return
    end

    -- Independent optional attachment; hidden with the character pane.
    local button = CreateFrame("Button", nil, frame.characterPane)
    button:SetSize(74, 20)
    button:SetPoint(
        "BOTTOMRIGHT", frame.characterPane, "BOTTOMRIGHT", -6, 6
    )
    button:SetFrameLevel(trinket:GetFrameLevel() + 2)
    Components:StyleButton(button, { text = "Item Rating" })
    button:SetScript("OnClick", function()
        Module:ToggleSettings()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
        GameTooltip:SetText("Item Rating")
        GameTooltip:AddLine(
            "Edit Feral Cat stat weights", 0.75, 0.75, 0.75
        )
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

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
