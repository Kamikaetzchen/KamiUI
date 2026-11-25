local Module = KamiUI:GetModule("ItemRating")

-- SixtySim WoW Forever, 2026-11-22.
-- Attack Power = 1. Main Hand Speed is per second, not haste rating.
local WEIGHTS = {
    KAMI_MAIN_HAND_SPEED = 74.1,
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 13.3,
    ITEM_MOD_EXPERTISE_RATING_SHORT = 4.29,
    ITEM_MOD_CRIT_RATING_SHORT = 2.45,
    ITEM_MOD_HASTE_RATING_SHORT = 2.41,
    ITEM_MOD_STRENGTH_SHORT = 2.2,
    ITEM_MOD_INTELLECT_SHORT = 2.01,
    ITEM_MOD_HIT_RATING_SHORT = 1.73,
    ITEM_MOD_AGILITY_SHORT = 1.36,
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 1.22,
    ITEM_MOD_SPELL_POWER_SHORT = 1.22,
    ITEM_MOD_ATTACK_POWER_SHORT = 1,
    ITEM_MOD_NATURE_DAMAGE_DONE_SHORT = 0.51,
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.36,
    ITEM_MOD_MANA_REGENERATION_SHORT = 0.09,
}

Module:RegisterProfile("SHAMAN", "enhancement", {
    label = "Enhancement",
    shortLabel = "Enhance",
    order = 2,
    assumptions = "Level 60 / raid buffs / 1-minute boss DPS",
    weights = Module:NewWeightTable(WEIGHTS),
    exclusiveSpellDamage = true,
    references = {
        {
            id = "sixtysim",
            label = "SixtySim",
            date = "2026-11-22",
            description = "Level 60 / 1 boss / 1 min / Horde",
            url = "https://sixtysim.com/guides/shaman/enhancement/stats/",
            weights = WEIGHTS,
        },
    },
})
