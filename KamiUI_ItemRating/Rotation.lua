local UI = KamiUI
local Module = UI:GetModule("ItemRating")

-- A level-aware Shred/Rip boss model, not a full encounter simulator.
-- SpellMetrics supplies the current ranks' damage and Energy costs.
local WHITE_SHARE = 0.27
local spellIDs
local cached
local status = "not initialized"

local function Number(value)
    if not UI:CanAccessValue(value) or type(value) ~= "number"
        or value ~= value or value == math.huge
        or value == -math.huge then return nil end
    return value
end

local function SpellName(id, fallback)
    if C_Spell and C_Spell.GetSpellName then
        local name = UI:SafeCall(C_Spell.GetSpellName, id)
        if UI:CanAccessValue(name) and type(name) == "string" then
            return name
        end
    end
    return fallback
end

local function ReadSpellbook()
    if InCombatLockdown and InCombatLockdown() then return nil end
    local book = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank
        and Enum.SpellBookSpellBank.Player
    if not book or bank == nil
        or not book.GetNumSpellBookSkillLines
        or not book.GetSpellBookSkillLineInfo
        or not book.GetSpellBookItemInfo then return nil end

    local labels = {
        shred = SpellName(5221, "Shred"),
        rip = SpellName(1079, "Rip"),
        shifting = SpellName(1322605, "Shifting Power"),
    }
    local found = {}
    local count = Number(UI:SafeCall(book.GetNumSpellBookSkillLines))
    if not count then return nil end

    for index = 1, count do
        local line = UI:SafeCall(book.GetSpellBookSkillLineInfo, index)
        if line and UI:CanAccessValue(line) then
            local offset = Number(line.itemIndexOffset)
            local items = Number(line.numSpellBookItems)
            if offset and items then
                for slot = offset + 1, offset + items do
                    local info = UI:SafeCall(
                        book.GetSpellBookItemInfo, slot, bank
                    )
                    if info and UI:CanAccessValue(info)
                        and not info.isPassive then
                        local id = Number(info.spellID)
                        local name = info.name
                        if id and UI:CanAccessValue(name)
                            and type(name) == "string" then
                            for key, expected in pairs(labels) do
                                if name == expected then
                                    found[key] = id
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return found
end

local function ExpectedShreds(crit, frenzyRank)
    -- E[n] expected Shred casts to collect n CP. A 2-CP proc at
    -- 4 CP wastes the overflowing CP rather than reaching six.
    local extra = math.max(0, math.min(1, crit * frenzyRank / 2))
    local e = { [0] = 0 }
    for n = 1, 5 do
        e[n] = 1 + (1 - extra) * e[n - 1]
            + extra * e[math.max(0, n - 2)]
    end
    return e[5]
end

local function DPS(model, crit, frenzyRank)
    local shreds = ExpectedShreds(crit, frenzyRank)
    local energy = shreds * model.shredEnergy + model.ripEnergy
    local time = math.max(model.ripDuration, energy / model.regen)
    local bleedUptime = math.min(1, model.ripDuration / time)
    local critBonus = 1 + 0.10 * model.naturalRank

    local shredDamage = model.shredBase * (1 + crit * critBonus)
        * (1 + 0.03 * model.rendRank * bleedUptime)
    local ripDamage = model.ripBase * (1 + crit * critBonus)
    return (shreds * shredDamage + ripDamage) / time
        + model.whiteBaseDPS * (1 + crit),
        shreds, time, bleedUptime
end

local function ReadModel()
    local spellMetrics = UI:GetModule("SpellMetrics")
    if not spellMetrics or not spellMetrics.GetSpellAnalysis then
        return nil, "SpellMetrics addon not loaded"
    end
    spellIDs = spellIDs or ReadSpellbook()
    if not spellIDs or not spellIDs.shred or not spellIDs.rip then
        return nil, "trained Shred / Rip not found in spellbook"
    end

    local frenzy = Module:GetRotationTalentRank("bloodFrenzy")
    if frenzy == nil then
        return nil, "Blood Frenzy talent rank unavailable"
    end
    local shredding = Module:GetRotationTalentRank("shreddingAttacks")
    local rend = Module:GetRotationTalentRank("rendAndTear")
    local natural = Module:GetNaturalInstinctRank()

    local shred = spellMetrics:GetSpellAnalysis(spellIDs.shred)
    local rip = spellMetrics:GetSpellAnalysis(spellIDs.rip)
    local variant = rip and rip.comboVariants
        and rip.comboVariants[5]
    local shredDamage = shred and Number(shred.direct)
    local ripDamage = variant and Number(variant.amount)
    if not shredDamage or shredDamage <= 0
        or not ripDamage or ripDamage <= 0 then
        return nil, "SpellMetrics missing Shred or 5-CP Rip damage"
    end

    -- The default spell tooltip shows 60 Energy before talent
    -- reductions; prefer the active Shredding Attacks rank.
    local shredCost = shredding ~= nil and (60 - 6 * shredding)
        or (shred and Number(shred.resourceCost))
    local ripCost = rip and Number(rip.resourceCost)
    if not shredCost or shredCost <= 0 or not ripCost
        or ripCost <= 0 then
        return nil, "Shred / Rip Energy cost unavailable"
    end

    local ripDuration = (variant and Number(variant.duration))
        or (rip and Number(rip.periodicDuration)) or 12
    local regen = 10
    if spellIDs.shifting then
        regen = regen + 40 / 8 -- ideal Shifting Power on cooldown
    end

    return {
        shredBase = shredDamage, ripBase = ripDamage,
        shredEnergy = shredCost, ripEnergy = ripCost,
        ripDuration = ripDuration, regen = regen,
        naturalRank = natural or 0, rendRank = rend or 0,
        frenzyRank = frenzy, shreddingRank = shredding,
        shifting = spellIDs.shifting ~= nil,
        whiteBaseDPS = 0,
    }
end

function Module:InvalidateRotationCache(reloadSpells)
    cached = nil
    if reloadSpells then spellIDs = nil end
end

-- Ratio of marginal DPS gains from +1% Crit with vs without
-- Blood Frenzy. This scales the existing Crit-AP proxy without
-- inventing a Rip AP coefficient. White DPS is calibrated to 27%.
function Module:GetBloodFrenzyCritFactor(critPct)
    local value = Number(critPct)
    if not value or value < 0 or value > 100 then
        return nil, { status = "Crit unavailable" }
    end
    if cached and cached.crit == value then
        return cached.factor, cached.details
    end

    local model, reason = ReadModel()
    if not model then
        status = reason
        return nil, { status = reason }
    end
    if model.frenzyRank == 0 then
        local details = { rank = 0, status = "No Blood Frenzy" }
        cached = { crit = value, factor = 1, details = details }
        return 1, details
    end

    local crit = value / 100
    local c0, c1 = crit, math.min(1, crit + 0.01)
    if c0 == c1 then c0 = math.max(0, crit - 0.01) end

    -- Fix white DPS to a 27% share at the current active rotation.
    local activeAbilityDPS = DPS(model, crit, model.frenzyRank)
    model.whiteBaseDPS = activeAbilityDPS
        * WHITE_SHARE / (1 - WHITE_SHARE) / (1 + crit)

    local no0 = DPS(model, c0, 0)
    local no1 = DPS(model, c1, 0)
    local with0, shreds, duration, uptime =
        DPS(model, c0, model.frenzyRank)
    local with1 = DPS(model, c1, model.frenzyRank)
    local noGain, frenzyGain = no1 - no0, with1 - with0
    if noGain <= 0 or frenzyGain < 0 then
        status = "Rotation produced unstable marginal Crit values"
        return nil, { status = status }
    end

    local factor = frenzyGain / noGain
    if not Number(factor) or factor > 10 then
        status = "Blood Frenzy factor outside model bounds"
        return nil, { status = status }
    end

    local details = {
        status = "estimated", rank = model.frenzyRank,
        factor = factor, shredsPerRip = shreds,
        secondsPerRip = duration, ripUptime = uptime,
        shredEnergy = model.shredEnergy,
        ripEnergy = model.ripEnergy, regen = model.regen,
        rendRank = Module:GetRotationTalentRank("rendAndTear"),
        shreddingRank = model.shreddingRank,
        shifting = model.shifting,
    }
    cached = { crit = value, factor = factor, details = details }
    status = "estimated"
    return factor, details
end

function Module:GetBloodFrenzyRotationStatus()
    return status
end

-- No combat-log reading and no protected Blizzard API calls.
for _, event in ipairs({
    "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD",
    "PLAYER_LEVEL_UP", "TRAIT_CONFIG_UPDATED",
}) do
    UI:RegisterEvent(event, function()
        Module:InvalidateRotationCache(true)
    end)
end
for _, event in ipairs({
    "UNIT_DAMAGE", "UNIT_ATTACK_POWER", "UNIT_STATS", "UNIT_AURA",
}) do
    UI:RegisterEvent(event, function(_, unit)
        if unit == "player" then
            Module:InvalidateRotationCache(false)
        end
    end)
end
for _, event in ipairs({
    "COMBAT_RATING_UPDATE", "PLAYER_EQUIPMENT_CHANGED",
    "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_ENABLED",
}) do
    UI:RegisterEvent(event, function()
        Module:InvalidateRotationCache(false)
    end)
end
