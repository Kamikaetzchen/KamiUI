local Module = KamiUI:GetModule("ItemRating")

-- SixtySim: Feral Bear Threat, 17 Nov 2026, level 60, raid buffs,
-- 9/32/10, one boss / one minute. Raw points, Agility = 1.
-- Avoidance stats have slightly negative simulated threat value;
-- our non-negative scoring engine deliberately leaves them at zero.
local THREAT = {
    ITEM_MOD_EXPERTISE_RATING_SHORT = 5.72,
    ITEM_MOD_STRENGTH_SHORT = 1.68,
    ITEM_MOD_HIT_RATING_SHORT = 1.43,
    ITEM_MOD_CRIT_RATING_SHORT = 1.41,
    ITEM_MOD_AGILITY_SHORT = 1.00,
    ITEM_MOD_HASTE_RATING_SHORT = 0.91,
    ITEM_MOD_ATTACK_POWER_SHORT = 0.76,
    ITEM_MOD_FERAL_ATTACK_POWER_SHORT = 0.76,
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.33,
}

-- A provisional weapon-DPS approximation, not a SixtySim result.
-- One DPS ~ 14 AP, calibrated with Threat's AP weight of 0.76.
local threatDefaults = Module:NewWeightTable(THREAT, {
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 14 * 0.76,
    ITEM_MOD_WEAPON_DAMAGE_SHORT = 14 * 0.76,
})

Module:RegisterProfile("DRUID", "bearThreat", {
    label = "Bear Threat",
    shortLabel = "Bear Threat",
    order = 2,
    assumptions = "Level 60 / raid buffs / boss threat (TPS)",
    weights = threatDefaults,
    references = {
        {
            id = "sixtysim",
            label = "SixtySim",
            date = "2026-11-17",
            description = "Threat, 1 boss / 1 min, raid buffs",
            url = "https://sixtysim.com/guides/druid/feral-tank/stats/",
            weights = THREAT,
        },
    },
})

-- Pawn Forever's Bear endgame ("max") scale, sourced from
-- GearQuest Forever. Pawn stores Crit/Hit/Haste/Expertise/Dodge
-- per 1% and uses 14/10/10/10/12 raw rating per 1% on Forever.
-- DefenseRating is already per raw defense point.
-- Survival-biased mixed tank score, NOT a dedicated mitigation sim.
local SURVIVAL = {
    ITEM_MOD_STAMINA_SHORT = 1.00,
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 0.85,
    ITEM_MOD_DODGE_RATING_SHORT = 8.4 / 12,
    ITEM_MOD_AGILITY_SHORT = 0.55,
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 4.90,
    ITEM_MOD_EXPERTISE_RATING_SHORT = 6 / 10,
    ITEM_MOD_HIT_RATING_SHORT = 4 / 10,
    ITEM_MOD_STRENGTH_SHORT = 0.35,
    RESISTANCE0_NAME = 0.10,
    ITEM_MOD_CRIT_RATING_SHORT = 3.5 / 14,
    ITEM_MOD_HASTE_RATING_SHORT = 1 / 10,
    ITEM_MOD_ATTACK_POWER_SHORT = 0.18,
    ITEM_MOD_FERAL_ATTACK_POWER_SHORT = 0.18,
    ITEM_MOD_INTELLECT_SHORT = 0.05,
    ITEM_MOD_SPIRIT_SHORT = 0.02,
    ITEM_MOD_MANA_REGENERATION_SHORT = 0.05,
}

Module:RegisterProfile("DRUID", "bearSurvival", {
    label = "Bear Survival",
    shortLabel = "Bear Survival",
    order = 3,
    assumptions = "Level 60 / endgame tank / survival + threat",
    weights = Module:NewWeightTable(SURVIVAL, {
        -- Pawn Forever maps flat weapon damage to melee weapon DPS.
        ITEM_MOD_WEAPON_DAMAGE_SHORT = 4.90,
    }),
    references = {
        {
            id = "pawn",
            label = "Pawn Forever",
            date = "2026-11-13",
            description = "Endgame Bear (max), mixed tank weights",
            url = "https://github.com/turlockmike/pawn-forever",
            weights = SURVIVAL,
        },
    },
})
