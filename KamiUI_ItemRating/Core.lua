local UI = KamiUI
local Module = UI:NewModule("ItemRating", "KamiUI_ItemRating")

Module.profiles = {}

-- Shared stat list: new class/spec profiles need only supply weights.
-- Values not present in a source default to zero but remain editable.
Module.statFields = {
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

function Module:NewWeightTable(source, extra)
    local weights = {}
    for _, field in ipairs(self.statFields) do
        local key = field[1]
        weights[key] = (extra and extra[key])
            or (source and source[key]) or 0
    end
    return weights
end

-- Old Cat weights were AP equivalents. The editor also treated combat
-- ratings as percentages, while GetItemStats returns raw rating points.
-- Convert saved user overrides once into raw-rating Agility equivalents.
local LEGACY_RATING_PER_PERCENT = {
    ITEM_MOD_CRIT_RATING_SHORT = 14,
    ITEM_MOD_HIT_RATING_SHORT = 10,
    ITEM_MOD_HASTE_RATING_SHORT = 10,
    ITEM_MOD_EXPERTISE_RATING_SHORT = 10,
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 10,
    ITEM_MOD_DODGE_RATING_SHORT = 12,
    ITEM_MOD_PARRY_RATING_SHORT = 15,
    ITEM_MOD_BLOCK_RATING_SHORT = 5,
}
local LEGACY_AP_TO_AGILITY = 0.41

local function Database()
    return UI:GetDatabase("itemRating", { profiles = {} })
end

local function GetOverrides(classFile, spec, create)
    local database = Database()
    local classes = database.profiles
    local specs = classes[classFile]

    if not specs and create then
        specs = {}
        classes[classFile] = specs
    end

    local overrides = specs and specs[spec]
    if not overrides and create then
        overrides = {}
        specs[spec] = overrides
    end

    return overrides, specs, classes
end

local function ValidWeight(value)
    return type(value) == "number"
        and value == value
        and value >= 0
        and value <= 100000
end

function Module:MigrateLegacyCatWeights()
    local database = Database()
    if database.rawRatingWeightsVersion == 1 then return end

    local druid = database.profiles.DRUID
    local overrides = druid and druid.cat
    local percentWeights = database.catWeightUnitsVersion == 2

    if overrides then
        for key, value in pairs(overrides) do
            if ValidWeight(value) then
                local divisor = percentWeights
                    and LEGACY_RATING_PER_PERCENT[key] or nil
                overrides[key] = value * LEGACY_AP_TO_AGILITY
                    / (divisor or 1)
            else
                overrides[key] = nil
            end
        end
    end

    -- Removed settings should not survive as unused saved variables.
    database.buffs = nil
    database.catWeightUnitsVersion = nil
    database.rawRatingWeightsVersion = 1
end

function Module:ApplySavedWeights(classFile, spec)
    local profile = self.profiles[classFile]
        and self.profiles[classFile][spec]
    if not profile then return end

    local overrides = GetOverrides(classFile, spec)
    for key, defaultValue in pairs(profile.defaultWeights) do
        local stored = overrides and overrides[key]
        profile.weights[key] = ValidWeight(stored)
            and stored or defaultValue
    end
end

function Module:RegisterProfile(classFile, spec, profile)
    if not classFile or not spec or type(profile) ~= "table"
        or type(profile.weights) ~= "table" then
        return
    end

    profile.defaultWeights = {}
    for key, weight in pairs(profile.weights) do
        profile.defaultWeights[key] = weight
    end
    profile.references = profile.references or {}
    profile.classFile = classFile
    profile.spec = spec

    self.profiles[classFile] = self.profiles[classFile] or {}
    self.profiles[classFile][spec] = profile
    if classFile == "DRUID" and spec == "cat" then
        self:MigrateLegacyCatWeights()
    end
    self:ApplySavedWeights(classFile, spec)
end

function Module:SetWeight(classFile, spec, key, value)
    local profile = self.profiles[classFile]
        and self.profiles[classFile][spec]
    if not profile or profile.defaultWeights[key] == nil
        or not ValidWeight(value) then
        return false
    end

    local overrides, specs, classes = GetOverrides(classFile, spec, true)
    local defaultValue = profile.defaultWeights[key]
    if math.abs(value - defaultValue) < 0.0000001 then
        overrides[key] = nil
    else
        overrides[key] = value
    end

    if not next(overrides) then
        specs[spec] = nil
        if not next(specs) then
            classes[classFile] = nil
        end
    end
    self:ApplySavedWeights(classFile, spec)
    return true
end

function Module:ResetWeights(classFile, spec)
    local profile = self.profiles[classFile]
        and self.profiles[classFile][spec]
    if not profile then return end

    local _, specs, classes = GetOverrides(classFile, spec)
    if specs then
        specs[spec] = nil
        if not next(specs) then classes[classFile] = nil end
    end
    self:ApplySavedWeights(classFile, spec)
end

-- Copy only stats the chosen source actually publishes. Missing values
-- must remain untouched (not silently become zero). User edits are saved.
function Module:ApplyReferenceWeights(classFile, spec, sourceID)
    local profile = self.profiles[classFile]
        and self.profiles[classFile][spec]
    if not profile then return false end

    local reference
    for _, entry in ipairs(profile.references) do
        if entry.id == sourceID then
            reference = entry
            break
        end
    end
    if not reference then return false end

    local overrides, specs, classes = GetOverrides(classFile, spec, true)
    for key, value in pairs(reference.weights) do
        if profile.defaultWeights[key] ~= nil and ValidWeight(value) then
            local defaultValue = profile.defaultWeights[key]
            if math.abs(value - defaultValue) < 0.0000001 then
                overrides[key] = nil
            else
                overrides[key] = value
            end
        end
    end
    if not next(overrides) then
        specs[spec] = nil
        if not next(specs) then classes[classFile] = nil end
    end
    self:ApplySavedWeights(classFile, spec)
    return true
end

function Module:GetClassProfiles(classFile)
    if not classFile then
        local _, unitClass = UnitClass("player")
        if not UI:CanAccessValue(unitClass) then return {} end
        classFile = unitClass
    end

    local profiles = {}
    for _, profile in pairs(self.profiles[classFile] or {}) do
        profiles[#profiles + 1] = profile
    end
    table.sort(profiles, function(a, b)
        if (a.order or 99) ~= (b.order or 99) then
            return (a.order or 99) < (b.order or 99)
        end
        return (a.label or "") < (b.label or "")
    end)
    return profiles
end

function Module:GetSelectedProfile()
    local _, classFile = UnitClass("player")
    if not UI:CanAccessValue(classFile) then return nil end
    local db = Database()
    local selected = db.editorSpec and db.editorSpec[classFile]
    local profiles = self.profiles[classFile]
    if profiles and selected and profiles[selected] then
        return profiles[selected]
    end
    local sorted = self:GetClassProfiles(classFile)
    return sorted[1]
end

function Module:SetSelectedProfile(classFile, spec)
    if not (self.profiles[classFile]
        and self.profiles[classFile][spec]) then return false end

    local db = Database()
    db.editorSpec = db.editorSpec or {}
    db.editorSpec[classFile] = spec
    return true
end

-- Kept for compatibility with other callers. Tooltip uses every
-- profile for the current class, independently of the editor selection.
function Module:GetActiveProfile()
    return self:GetSelectedProfile()
end
