local UI = KamiUI
local Module = UI:NewModule("ItemRating", "KamiUI_ItemRating")

Module.profiles = {}

-- Forever shows percentages on item tooltips, but C_Item.GetItemStats
-- returns the underlying raw combat rating. All editable combat
-- weights are AP equivalents per +1 percentage point of the stat.
-- Defense Skill is *not* a percentage and stays in skill points.
Module.ratingPerPercent = {
    ITEM_MOD_CRIT_RATING_SHORT = 14,
    ITEM_MOD_HIT_RATING_SHORT = 10,
    ITEM_MOD_HASTE_RATING_SHORT = 10,
    ITEM_MOD_EXPERTISE_RATING_SHORT = 10,
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 10,
    ITEM_MOD_DODGE_RATING_SHORT = 12,
    ITEM_MOD_PARRY_RATING_SHORT = 15,
    ITEM_MOD_BLOCK_RATING_SHORT = 5,
}

function Module:GetDisplayStatAmount(key, rawAmount)
    local perPercent = self.ratingPerPercent[key]
    if perPercent then
        return rawAmount / perPercent
    end
    return rawAmount
end

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

-- Older versions saved these eight combat weights per *rating point*.
-- Migrate the account-wide Cat overrides once, preserving the same item
-- scores for existing custom settings after the change to percent units.
function Module:MigrateCatWeightsToPercent()
    local database = UI:GetDatabase("itemRating", { profiles = {} })
    if database.catWeightUnitsVersion == 2 then
        return
    end

    local druid = database.profiles and database.profiles.DRUID
    local overrides = druid and druid.cat
    if overrides then
        for key, perPercent in pairs(self.ratingPerPercent) do
            local saved = overrides[key]
            if ValidWeight(saved) then
                overrides[key] = saved * perPercent
            end
        end
    end

    database.catWeightUnitsVersion = 2
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
    profile.classFile = classFile
    profile.spec = spec
    if classFile == "DRUID" and spec == "cat" then
        self:MigrateCatWeightsToPercent()
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


-- Buff choices are stored separately from base-weight overrides.
-- This deliberately does not follow short-lived in-game auras.
function Module:IsKingsEnabled(classFile, spec)
    classFile, spec = classFile or "DRUID", spec or "cat"
    local database = UI:GetDatabase("itemRating", { buffs = {} })
    return database.buffs[classFile]
        and database.buffs[classFile][spec]
        and database.buffs[classFile][spec].kings == true or false
end

function Module:SetKingsEnabled(classFile, spec, enabled)
    local database = UI:GetDatabase("itemRating", { buffs = {} })
    database.buffs[classFile] = database.buffs[classFile] or {}
    database.buffs[classFile][spec] =
        database.buffs[classFile][spec] or {}
    database.buffs[classFile][spec].kings = enabled == true
end

local PRIMARY_STATS = {
    ITEM_MOD_STRENGTH_SHORT = true,
    ITEM_MOD_AGILITY_SHORT = true,
    ITEM_MOD_STAMINA_SHORT = true,
    ITEM_MOD_INTELLECT_SHORT = true,
    ITEM_MOD_SPIRIT_SHORT = true,
}

local HEART_OF_THE_WILD_SPELL = 17003
local NATURAL_INSTINCT_SPELL = 1223242 -- Forever: max 2 ranks

local function SafeNumeric(value)
    return UI:CanAccessValue(value) and type(value) == "number"
        and value or nil
end

-- Forever uses Retail-style C_Traits, not the removed Classic talent UI.
-- Read only the local player's committed/active configuration; never inspect.
-- A failed lookup returns nil (unknown), NOT zero talent points.
local function ReadTalentRank(talentSpellID, maxRank)
    if not C_Traits or not C_Traits.GetConfigInfo
        or not C_Traits.GetTreeNodes or not C_Traits.GetNodeInfo
        or not C_Traits.GetEntryInfo
        or not C_Traits.GetDefinitionInfo then
        return nil
    end

    local configID
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        configID = SafeNumeric(
            UI:SafeCall(C_ClassTalents.GetActiveConfigID)
        )
    end
    if not configID or configID <= 0 then
        local group
        if C_SpecializationInfo
            and C_SpecializationInfo.GetActiveSpecGroup then
            group = SafeNumeric(UI:SafeCall(
                C_SpecializationInfo.GetActiveSpecGroup
            ))
        end
        if group and C_SpecializationInfo
            and C_SpecializationInfo.GetCombatConfigIDForSpecGroup then
            configID = SafeNumeric(UI:SafeCall(
                C_SpecializationInfo.GetCombatConfigIDForSpecGroup, group
            ))
        end
    end
    if not configID or configID <= 0 then
        return nil
    end

    local config = UI:SafeCall(C_Traits.GetConfigInfo, configID)
    if not config or not UI:CanAccessValue(config)
        or not config.treeIDs
        or not UI:CanAccessValue(config.treeIDs) then
        return nil
    end

    for _, treeID in ipairs(config.treeIDs) do
        if UI:CanAccessValue(treeID) then
            local nodes = UI:SafeCall(C_Traits.GetTreeNodes, treeID)
            if nodes and UI:CanAccessValue(nodes) then
                for _, nodeID in ipairs(nodes) do
                    if UI:CanAccessValue(nodeID) then
                        local node = UI:SafeCall(
                            C_Traits.GetNodeInfo, configID, nodeID
                        )
                        if node and UI:CanAccessValue(node)
                            and node.entryIDs
                            and UI:CanAccessValue(node.entryIDs) then
                            for _, entryID in ipairs(node.entryIDs) do
                                if UI:CanAccessValue(entryID) then
                                    local entry = UI:SafeCall(
                                        C_Traits.GetEntryInfo,
                                        configID, entryID
                                    )
                                    local definitionID = entry
                                        and UI:CanAccessValue(entry)
                                        and SafeNumeric(entry.definitionID)
                                    local definition = definitionID
                                        and UI:SafeCall(
                                            C_Traits.GetDefinitionInfo,
                                            definitionID
                                        )
                                    local spellID = definition
                                        and UI:CanAccessValue(definition)
                                        and SafeNumeric(definition.spellID)
                                    if spellID == talentSpellID then
                                        local rank = SafeNumeric(
                                            node.activeRank
                                        ) or SafeNumeric(node.currentRank)
                                        if rank then
                                            return math.max(
                                                0, math.min(maxRank, rank)
                                            )
                                        end
                                        return nil
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

function Module:InvalidateTalentCache()
    self.heartOfTheWildChecked = false
    self.heartOfTheWildRank = nil
    self.naturalInstinctChecked = false
    self.naturalInstinctRank = nil
end

function Module:GetHeartOfTheWildRank()
    if self.heartOfTheWildChecked then
        return self.heartOfTheWildRank
    end

    -- Some trait values become inaccessible in combat; keep the last
    -- cached result and fall back to the reference if not yet available.
    if InCombatLockdown and InCombatLockdown() then
        return self.heartOfTheWildRank
    end

    local rank = ReadTalentRank(HEART_OF_THE_WILD_SPELL, 5)
    if rank ~= nil then
        self.heartOfTheWildRank = rank
        self.heartOfTheWildChecked = true
    end
    return self.heartOfTheWildRank
end

-- Active Forever Natural Instinct rank (0/2, 1/2 or 2/2), using
-- the same trait lookup and combat-safe cache as Heart of the Wild.
function Module:GetNaturalInstinctRank()
    if self.naturalInstinctChecked then
        return self.naturalInstinctRank
    end
    if InCombatLockdown and InCombatLockdown() then
        return self.naturalInstinctRank
    end

    local rank = ReadTalentRank(NATURAL_INSTINCT_SPELL, 2)
    if rank ~= nil then
        self.naturalInstinctRank = rank
        self.naturalInstinctChecked = true
    end
    return self.naturalInstinctRank
end

-- The editable Strength base is exactly 2 AP per Strength in Cat.
-- Heart of the Wild and Kings are calculated on top of that base.
-- The remaining simulation-derived secondary weights stay provisional.
function Module:GetEffectiveWeightInfo(profile, key)
    local base = profile.weights[key] or 0
    local multiplier = 1
    local effects = {}
    local classFile, spec = profile.classFile, profile.spec

    if classFile == "DRUID" and spec == "cat"
        and key == "ITEM_MOD_STRENGTH_SHORT" then
        local rank = self:GetHeartOfTheWildRank()
        if rank == nil then
            effects[#effects + 1] = {
                name = "Heart of the Wild",
                factor = 1,
                detail = "Rank unknown; no bonus applied",
            }
        else
            local factor = 1 + 0.02 * rank
            multiplier = multiplier * factor
            effects[#effects + 1] = {
                name = "Heart of the Wild",
                factor = factor,
                detail = string.format(
                    "%d/5 (+%d%% Strength)", rank, rank * 2
                ),
            }
        end
    end

    if PRIMARY_STATS[key] then
        local kings = self:IsKingsEnabled(classFile, spec)
        local factor = kings and 1.1 or 1
        multiplier = multiplier * factor
        effects[#effects + 1] = {
            name = "Blessing of Kings",
            factor = factor,
            detail = kings and "Enabled (+10% primary attributes)"
                or "Disabled (x1.00)",
        }
    end

    if #effects == 0 then
        effects[1] = {
            name = "No direct multipliers",
            factor = 1,
            detail = "Talent/crit/rotation effects not modelled",
        }
    end

    return base * multiplier, multiplier, effects
end

function Module:GetEffectiveWeights(profile)
    profile = profile or self:GetActiveProfile()
    if not profile then
        return nil
    end

    local effective = {}
    for key in pairs(profile.weights) do
        effective[key] = self:GetEffectiveWeightInfo(profile, key)
    end
    return effective
end

UI:RegisterEvent("TRAIT_CONFIG_UPDATED", function()
    Module:InvalidateTalentCache()
    if Module.RefreshSettings then
        Module:RefreshSettings()
    end
end)
UI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    Module:InvalidateTalentCache()
end)
