local Module = KamiUI:GetModule("ItemRating")

-- One boss / one minute, level 60, raid-buffed Alliance Feral Cat
-- with SixtySim's tuned 9/32/10 build and normal boss rotation.
-- Source numbers are per RAW rating point, in Agility equivalents.
-- The published table does not contain a weapon-DPS weight.
local SIM_WEIGHTS = {
    ITEM_MOD_AGILITY_SHORT = 1.00,
    ITEM_MOD_STRENGTH_SHORT = 0.99,
    ITEM_MOD_HIT_RATING_SHORT = 0.89,
    ITEM_MOD_EXPERTISE_RATING_SHORT = 0.87,
    ITEM_MOD_CRIT_RATING_SHORT = 0.72,
    ITEM_MOD_HASTE_RATING_SHORT = 0.46,
    ITEM_MOD_ATTACK_POWER_SHORT = 0.41,
    ITEM_MOD_FERAL_ATTACK_POWER_SHORT = 0.41,
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.13,
}

-- Keep the explicit local weapon estimate when SixtySim has no DPS
-- coefficient. It is not a measured SixtySim stat weight.
local defaults = Module:NewWeightTable(SIM_WEIGHTS, {
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 14 * 0.41,
    ITEM_MOD_WEAPON_DAMAGE_SHORT = 14 * 0.41,
})

Module:RegisterProfile("DRUID", "cat", {
    label = "Feral Cat",
    order = 1,
    assumptions = "Level 60 / raid buffs / boss DPS",
    shortLabel = "Cat",
    weights = defaults,
    references = {
        {
            id = "sixtysim",
            label = "SixtySim",
            date = "2026-11-17",
            description = "Level 60, raid buffs, 1 boss / 1 min",
            url = "https://sixtysim.com/guides/druid/feral/stats/",
            weights = SIM_WEIGHTS,
        },
    },
})
