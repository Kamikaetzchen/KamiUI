local UI = KamiUI
local Module = UI:NewModule("ItemRating", "KamiUI_ItemRating")

Module.profiles = {}

-- Shared account-wide SavedVariables (KamiUIDB.itemRating), independent of
-- KamiUI_Characters and KamiUI_Tooltips. Only deviations are persisted.
local function GetOverrides(classFile, spec, create)
    local database = UI:GetDatabase("itemRating", { profiles = {} })
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

function Module:ApplySavedWeights(classFile, spec)
    local profile = self.profiles[classFile]
        and self.profiles[classFile][spec]
    if not profile then
        return
    end

    local overrides = GetOverrides(classFile, spec)
    for key, defaultValue in pairs(profile.defaultWeights) do
        local stored = overrides and overrides[key]
        profile.weights[key] = ValidWeight(stored) and stored
            or defaultValue
    end
end

function Module:RegisterProfile(classFile, spec, profile)
    if not classFile or not spec or type(profile) ~= "table"
        or type(profile.weights) ~= "table" then
        return
    end

    -- Preserve immutable defaults, so Reset does not depend on saved data.
    profile.defaultWeights = {}
    for key, weight in pairs(profile.weights) do
        profile.defaultWeights[key] = weight
    end

    self.profiles[classFile] = self.profiles[classFile] or {}
    self.profiles[classFile][spec] = profile
    self:ApplySavedWeights(classFile, spec)
end

function Module:SetWeight(classFile, spec, key, value)
    local profile = self.profiles[classFile]
        and self.profiles[classFile][spec]
    if not profile or profile.defaultWeights[key] == nil
        or not ValidWeight(value) then
        return false
    end

    local overrides, specs, classes = GetOverrides(
        classFile, spec, true
    )
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
    if not profile then
        return
    end

    local _, specs, classes = GetOverrides(classFile, spec)
    if specs then
        specs[spec] = nil
        if not next(specs) then
            classes[classFile] = nil
        end
    end

    self:ApplySavedWeights(classFile, spec)
end

function Module:GetActiveProfile()
    local _, classFile = UnitClass("player")

    if not UI:CanAccessValue(classFile) or classFile ~= "DRUID" then
        return nil
    end

    -- V1 intentionally always rates Cat DPS, regardless of current form.
    -- Other classes/specs and talent-specific weighting come later.
    return self.profiles.DRUID and self.profiles.DRUID.cat
end
