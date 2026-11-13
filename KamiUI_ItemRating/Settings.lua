local UI = KamiUI
local Module = UI:GetModule("ItemRating")
local Components = UI.Components
local Palette = UI.Palette
local Styles = UI.Styles

-- The v0.1 editor exposes the Cat profile only. Additional profiles can
-- later reuse the same window without changing the Characters addon.
local CLASS, SPEC = "DRUID", "cat"

local FIELDS = {
    { "ITEM_MOD_STRENGTH_SHORT", "Strength" },
    { "ITEM_MOD_AGILITY_SHORT", "Agility" },
    { "ITEM_MOD_ATTACK_POWER_SHORT", "Attack Power" },
    { "ITEM_MOD_FERAL_ATTACK_POWER_SHORT", "Feral Attack Power" },
    { "ITEM_MOD_CRIT_RATING_SHORT", "Crit Rating" },
    { "ITEM_MOD_HIT_RATING_SHORT", "Hit Rating" },
    { "ITEM_MOD_HASTE_RATING_SHORT", "Haste Rating" },
    { "ITEM_MOD_EXPERTISE_RATING_SHORT", "Expertise Rating" },
    { "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT", "Armor Pen. Rating" },
    { "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "Weapon DPS" },
}

local function Profile()
    return Module.profiles[CLASS] and Module.profiles[CLASS][SPEC]
end

local function FormatWeight(value)
    return string.format("%.4f", value or 0)
end

local function CommitInput(input)
    local profile = Profile()
    if not profile then
        return
    end

    local current = profile.weights[input.statKey]
    local text = input:GetText()
    if not UI:CanAccessValue(text) or type(text) ~= "string" then
        return
    end

    -- German decimal commas are accepted, but display normalized decimals.
    local value = tonumber((text:gsub(",", ".")))
    if not value or value ~= value or value < 0 or value > 100000 then
        UI:Print("Invalid Item Rating weight for " .. input.statLabel)
    elseif math.abs(value - current) > 0.00005 then
        Module:SetWeight(CLASS, SPEC, input.statKey, value)
    end

    input:SetText(FormatWeight(profile.weights[input.statKey]))
end

local function RefreshInputs(frame)
    local profile = Profile()
    if not profile then
        return
    end

    for _, input in ipairs(frame.weightInputs) do
        input:SetText(FormatWeight(profile.weights[input.statKey]))
    end
end

local function CreateSettingsWindow()
    local frame = Components:CreateWindow("KamiUIItemRatingSettings", {
        width = 430,
        height = 450,
        strata = "DIALOG",
        header = {
            title = "Item Rating",
            height = 34,
        },
    })
    frame:SetPoint("CENTER", UIParent, "CENTER", 140, 0)
    frame.weightInputs = {}

    Components:CreateWindowCloseButton(frame, {
        point = "TOPRIGHT",
        x = -6,
        y = -6,
        onClick = function() frame:Hide() end,
    })
    Components:RegisterEscapeClose(frame)

    local profileTitle = frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormal"
    )
    profileTitle:SetPoint("TOPLEFT", 17, -48)
    profileTitle:SetText("Druid - Feral Cat")

    local hint = frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )
    hint:SetPoint("TOPLEFT", 17, -71)
    Styles:ApplyText(hint, "muted", Palette.muted)
    hint:SetText("AP equivalents per 1 stat / rating point")

    for index, field in ipairs(FIELDS) do
        local key, label = field[1], field[2]
        local row = CreateFrame("Frame", nil, frame)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 17,
            -99 - (index - 1) * 27)
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -17,
            -99 - (index - 1) * 27)
        row:SetHeight(24)

        local name = row:CreateFontString(
            nil, "OVERLAY", "GameFontNormalSmall"
        )
        name:SetPoint("LEFT", 2, 0)
        name:SetText(label)

        local input = CreateFrame(
            "EditBox", nil, row, "InputBoxTemplate"
        )
        input:SetSize(96, 22)
        input:SetPoint("RIGHT", -3, 0)
        input:SetAutoFocus(false)
        input:SetMaxLetters(12)
        input.statKey = key
        input.statLabel = label
        Components:StyleInput(input)

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
    end

    local note = frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormalSmall"
    )
    note:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, -377)
    Styles:ApplyText(note, "muted", Palette.muted)
    note:SetText("Fixed weights; caps and talent changes not applied.")

    local reset = CreateFrame("Button", nil, frame)
    reset:SetSize(124, 24)
    reset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 17, 15)
    Components:StyleButton(reset, { text = "Reset Defaults" })
    reset:SetScript("OnClick", function()
        -- Lose focus first so pending edits don't overwrite the reset.
        for _, input in ipairs(frame.weightInputs) do
            if input:HasFocus() then
                input:ClearFocus()
            end
        end
        Module:ResetWeights(CLASS, SPEC)
        RefreshInputs(frame)
    end)

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(82, 24)
    close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 15)
    Components:StyleButton(close, { text = "Close" })
    close:SetScript("OnClick", function() frame:Hide() end)

    frame:SetScript("OnShow", function(self)
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

    -- Anchor to the character pane's bottom-right corner, keeping equal
    -- right/bottom margins. At 74px wide the button clears the ammo slot.
    -- Its parent hides on non-character pages; Characters stays untouched.
    local button = CreateFrame("Button", nil, frame.characterPane)
    button:SetSize(74, 20)
    button:SetPoint("BOTTOMRIGHT", frame.characterPane, "BOTTOMRIGHT", -6, 6)
    button:SetFrameLevel(trinket:GetFrameLevel() + 2)
    Components:StyleButton(button, { text = "Item Rating" })
    button:SetScript("OnClick", function()
        Module:ToggleSettings()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
        GameTooltip:SetText("Item Rating")
        GameTooltip:AddLine("Edit Feral Cat stat weights", 0.75, 0.75, 0.75)
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
