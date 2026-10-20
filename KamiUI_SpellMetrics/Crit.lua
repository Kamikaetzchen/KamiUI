local UI = KamiUI
local Module = UI:GetModule("SpellMetrics")

-- Spell-specific profiles can override these defaults once the individual
-- Forever spell mechanics (including periodic crit rules) are verified.
-- Without a verified spell school, do not guess a spell crit chance.
local MELEE = { source = "melee", multiplier = 2.0 }
local PHYSICAL_PROFILE = {
    direct = MELEE,
    periodic = MELEE,
    combo = MELEE,
}

Module.critProfiles = {}
Module.critModifiers = {}
Module.critSnapshot = {
    melee = nil,
    ranged = nil,
    spell = {},
}
Module.critSnapshotFresh = {
    melee = false,
    ranged = false,
    spell = {},
}

-- A profile has optional direct, periodic and combo components.
-- Each component specifies source ("melee", "ranged" or "spell"),
-- multiplier (e.g. 2.0 physical / 1.5 spell), and for spell the
-- explicit school index (2 Holy ... 7 Arcane).
-- Omitted components do not get crit, so non-critting periodic effects
-- can be modeled without making assumptions about their tooltips.
function Module:RegisterCritProfile(spellID, profile)
    if type(spellID) ~= "number"
        or type(profile) ~= "table" then
        return
    end

    self.critProfiles[spellID] = profile
    self:InvalidateCache()
end

-- Future talent/racial/effect handlers return optional numeric changes:
-- { chanceBonus = percentagePoints, critMultiplier = newMultiplier }.
-- Handlers should use only already-readable or cached values, not secrets.
-- They receive (spellData, componentName, componentProfile).
function Module:RegisterCritModifier(id, handler)
    if type(id) ~= "string"
        or type(handler) ~= "function" then
        return
    end

    self.critModifiers[id] = handler
    self:InvalidateCache()
end

local function ReadChance(func, arg)
    if type(func) ~= "function" then
        return nil
    end

    local value = UI:SafeCall(func, arg)

    -- GetCritChance / GetSpellCritChance become secret in combat.
    -- Never test, convert or calculate with an unreadable number.
    if not UI:CanAccessValue(value)
        or type(value) ~= "number"
        or value < 0
    then
        return nil
    end

    return math.min(100, value)
end

-- Read all categories in one pass, so every spell calculation in a
-- refresh uses the same snapshot. Keep earlier values when Blizzard
-- temporarily marks a category secret; never replace with zero.
function Module:UpdateCritSnapshot()
    local values = self.critSnapshot
    local fresh = self.critSnapshotFresh

    local melee = ReadChance(GetCritChance)
    fresh.melee = melee ~= nil
    if melee then
        values.melee = melee
    end

    local ranged = ReadChance(GetRangedCritChance)
    fresh.ranged = ranged ~= nil
    if ranged then
        values.ranged = ranged
    end

    for school = 2, 7 do
        local spell = ReadChance(GetSpellCritChance, school)
        fresh.spell[school] = spell ~= nil
        if spell then
            values.spell[school] = spell
        end
    end
end

local function GetProfile(data, component)
    local explicit = Module.critProfiles[data.spellID]

    if explicit then
        return explicit[component]
    end

    if data.outputType == "damage"
        and (data.resourceType == "Energy"
            or data.resourceType == "Rage"
            or data.weaponEstimate)
    then
        return PHYSICAL_PROFILE[component]
    end

    -- Spell damage/healing and ambiguous attacks require an explicit
    -- school/crit rule before we can reliably include crit.
    return nil
end

local function GetSnapshot(profile)
    local source = profile.source

    if source == "melee" or source == "ranged" then
        return Module.critSnapshot[source],
            Module.critSnapshotFresh[source]
    end

    if source == "spell" then
        local school = profile.school
        if type(school) == "number"
            and school >= 2 and school <= 7 then
            return Module.critSnapshot.spell[school],
                Module.critSnapshotFresh.spell[school]
        end
    end

    return nil, false
end

local function ReadModifierNumber(value)
    if not UI:CanAccessValue(value)
        or type(value) ~= "number" then
        return nil
    end
    return value
end

function Module:GetExpectedCritFactor(data, component)
    local profile = GetProfile(data, component)

    if not profile then
        return 1, nil
    end

    local chance, fresh = GetSnapshot(profile)
    local result = {
        source = profile.source,
        school = profile.school,
        chance = chance,
        multiplier = profile.multiplier,
        stale = not fresh,
    }

    if chance == nil then
        -- No prior readable snapshot: do not fabricate a crit bonus.
        result.unavailable = true
        return 1, result
    end

    local critMultiplier = profile.multiplier or 2.0

    for _, handler in pairs(self.critModifiers) do
        local ok, changes = pcall(handler, data, component, profile)
        if ok and type(changes) == "table" then
            local bonus = ReadModifierNumber(changes.chanceBonus)
            if bonus then
                chance = chance + bonus
            end

            local multiplier =
                ReadModifierNumber(changes.critMultiplier)
            if multiplier and multiplier >= 1 then
                critMultiplier = multiplier
            end
        end
    end

    chance = math.max(0, math.min(100, chance))
    result.chance = chance
    result.multiplier = critMultiplier

    return 1 + (chance / 100) * (critMultiplier - 1), result
end
