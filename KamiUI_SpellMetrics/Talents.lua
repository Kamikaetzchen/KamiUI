local UI = KamiUI
local Module = UI:GetModule("SpellMetrics")

-- Forever talent-aware estimates. This is deliberately independent of
-- ItemRating, so SpellMetrics works when ItemRating is disabled.
-- Use the player's committed C_Traits config, never inspect a target.
local TALENTS = {
    savageFury = { id = 16998, ranks = 2 },
    genesis = { id = 1223081, ranks = 5 },
    naturalist = { id = 17069, ranks = 5 },
    naturalInstinct = { id = 1223242, ranks = 2 },
    shreddingAttacks = { id = 16966, ranks = 3 },
}
local SAVAGE_SPELLS = {
    ["claw"] = true,
    ["rake"] = true,
    ["shred"] = true,
    ["maul"] = true,
    ["swipe"] = true,
}
local cachedRanks
local cachedNames = {}

local function ReadableNumber(value)
    return UI:CanAccessValue(value)
        and type(value) == "number"
        and value == value and value > -math.huge
        and value < math.huge and value or nil
end

local function SpellName(spellID)
    local name = cachedNames[spellID]
    if name then return name end
    if C_Spell and C_Spell.GetSpellName then
        name = UI:SafeCall(C_Spell.GetSpellName, spellID)
    end
    if UI:CanAccessValue(name) and type(name) == "string" then
        cachedNames[spellID] = name
        return name
    end
    return nil
end

local function ReadTalentRanks()
    local _, classFile = UI:SafeCall(UnitClass, "player")
    if not UI:CanAccessValue(classFile)
        or classFile ~= "DRUID" then return nil end

    local traits = C_Traits
    if not traits or not traits.GetConfigInfo
        or not traits.GetTreeNodes or not traits.GetNodeInfo
        or not traits.GetEntryInfo
        or not traits.GetDefinitionInfo then return nil end

    local configID = C_ClassTalents
        and C_ClassTalents.GetActiveConfigID
        and ReadableNumber(UI:SafeCall(
            C_ClassTalents.GetActiveConfigID
        ))
    if not configID or configID <= 0 then
        local group = C_SpecializationInfo
            and C_SpecializationInfo.GetActiveSpecGroup
            and ReadableNumber(UI:SafeCall(
                C_SpecializationInfo.GetActiveSpecGroup
            ))
        if group and C_SpecializationInfo
            and C_SpecializationInfo.GetCombatConfigIDForSpecGroup then
            configID = ReadableNumber(UI:SafeCall(
                C_SpecializationInfo.GetCombatConfigIDForSpecGroup,
                group
            ))
        end
    end
    if not configID or configID <= 0 then return nil end

    local config = UI:SafeCall(traits.GetConfigInfo, configID)
    if not config or not UI:CanAccessValue(config)
        or not config.treeIDs
        or not UI:CanAccessValue(config.treeIDs) then return nil end

    local ranks = {}
    local names = {}
    for key, item in pairs(TALENTS) do
        ranks[key] = 0
        names[key] = SpellName(item.id)
    end

    for _, treeID in ipairs(config.treeIDs) do
        if UI:CanAccessValue(treeID) then
            local nodes = UI:SafeCall(traits.GetTreeNodes, treeID)
            if nodes and UI:CanAccessValue(nodes) then
                for _, nodeID in ipairs(nodes) do
                    if UI:CanAccessValue(nodeID) then
                        local node = UI:SafeCall(
                            traits.GetNodeInfo, configID, nodeID
                        )
                        if node and UI:CanAccessValue(node)
                            and node.entryIDs
                            and UI:CanAccessValue(node.entryIDs) then
                            for _, entryID in ipairs(node.entryIDs) do
                                if UI:CanAccessValue(entryID) then
                                    local entry = UI:SafeCall(
                                        traits.GetEntryInfo,
                                        configID, entryID
                                    )
                                    local definitionID = entry
                                        and UI:CanAccessValue(entry)
                                        and ReadableNumber(entry.definitionID)
                                    local definition = definitionID
                                        and UI:SafeCall(
                                            traits.GetDefinitionInfo,
                                            definitionID
                                        )
                                    local spellID = definition
                                        and UI:CanAccessValue(definition)
                                        and ReadableNumber(definition.spellID)
                                    if spellID then
                                        local candidateName = SpellName(spellID)
                                        for key, talent in pairs(TALENTS) do
                                            if spellID == talent.id
                                                or (candidateName
                                                    and names[key]
                                                    and candidateName
                                                        == names[key]) then
                                                local rank = ReadableNumber(
                                                    node.activeRank
                                                ) or ReadableNumber(
                                                    node.currentRank
                                                )
                                                if rank then
                                                    ranks[key] = math.max(
                                                        0, math.min(
                                                            talent.ranks, rank
                                                        )
                                                    )
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return ranks
end

function Module:InvalidateDruidTalentCache()
    cachedRanks = nil
end

function Module:GetDruidTalentRank(key)
    if not TALENTS[key] then return nil end
    if cachedRanks then return cachedRanks[key] end
    if InCombatLockdown and InCombatLockdown() then return nil end
    cachedRanks = ReadTalentRanks()
    return cachedRanks and cachedRanks[key] or nil
end

-- The Shred/Claw/Swipe weapon component is derived from UnitDamage.
-- Naturalist's generic % damage may already affect that value, so
-- NEVER apply it again there. Spell tooltip numbers for non-weapon
-- spells are treated as unmodified base estimates.
-- Blizzard confirmed that Savage Fury is already reflected in the
-- FLAT Shred tooltip bonus; apply Savage only to its weapon portion.
function Module:ApplyDruidTalentModifiers(data)
    if not data or data.outputType ~= "damage" then return data end
    local savage = self:GetDruidTalentRank("savageFury")
    local genesis = self:GetDruidTalentRank("genesis")
    local naturalist = self:GetDruidTalentRank("naturalist")
    local shredding = self:GetDruidTalentRank("shreddingAttacks")
    local name = data.name and type(data.name) == "string"
        and data.name:lower() or ""

    data.talentModifiers = {
        savageFury = savage,
        genesis = genesis,
        naturalist = naturalist,
        shreddingAttacks = shredding,
    }

    if name == "shred" and shredding and shredding > 0
        and data.resourceType == "Energy" then
        -- Forever's native spell tooltip can still show 60 Energy.
        data.resourceCost = 60 - 6 * shredding
    end

    local savageFactor = 1 + 0.05 * (savage or 0)
    local periodicFactor = 1 + 0.02 * (genesis or 0)
    local naturalistFactor = 1 + 0.02 * (naturalist or 0)
    local isSavage = SAVAGE_SPELLS[name] == true

    if data.weaponEstimate and data.weaponBase
        and data.weaponMultiplier then
        if isSavage and savage then
            -- Base weapon portion only. The flat tooltip bonus already
            -- incorporates Savage Fury on current Forever clients.
            data.direct = data.weaponBase * data.weaponMultiplier
                * savageFactor + (data.weaponBonus or 0)
        end
        -- Do not multiply weapon-derived damage by Naturalist again.
    elseif data.direct then
        -- Fixed-damage attacks (not built from UnitDamage) have no
        -- automatic melee-base multiplier to inherit.
        local factor = naturalistFactor
        if isSavage and savage then
            factor = factor * savageFactor
        end
        data.direct = data.direct * factor
    end

    if data.periodic then
        local factor = periodicFactor
        if isSavage and savage then
            -- Rake bleed benefits from Savage Fury as well.
            factor = factor * savageFactor
        end
        if not data.weaponEstimate and naturalist then
            factor = factor * naturalistFactor
        end
        data.periodic = data.periodic * factor
    end

    if data.comboVariants then
        local comboFactor = (name == "rip")
            and periodicFactor or 1
        if naturalist then
            comboFactor = comboFactor * naturalistFactor
        end
        for _, variant in pairs(data.comboVariants) do
            if variant.amount then
                variant.amount = variant.amount * comboFactor
            end
        end
    end

    return data
end

-- Natural Instinct raises the critical DAMAGE BONUS of Feral melee
-- abilities, including bleed ticks that can crit on Forever.
-- 2x base -> 2.1x or 2.2x at ranks 1/2 and 2/2.
Module:RegisterCritModifier("natural-instinct", function(data, _part, profile)
    if profile.source ~= "melee"
        or (data.resourceType ~= "Energy"
            and data.resourceType ~= "Rage") then
        return nil
    end
    local rank = Module:GetDruidTalentRank("naturalInstinct")
    if not rank or rank <= 0 then return nil end
    return { critMultiplier = 2 + 0.10 * rank }
end)

for _, event in ipairs({
    "TRAIT_CONFIG_UPDATED", "PLAYER_ENTERING_WORLD",
    "PLAYER_LEVEL_UP", "SPELLS_CHANGED",
}) do
    UI:RegisterEvent(event, function()
        Module:InvalidateDruidTalentCache()
        Module:InvalidateCache()
        if Module.ScheduleActionButtonRefresh then
            Module:ScheduleActionButtonRefresh(true)
        end
    end)
end
