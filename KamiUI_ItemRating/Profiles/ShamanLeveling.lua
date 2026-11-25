local Module = KamiUI:GetModule("ItemRating")

-- SixtySim WoW Forever, 2026-11-05.
-- Level 20 source is normalized to AP=1 from MP5=1.
-- Weapon DPS uses a local 14 AP per DPS approximation, not SixtySim.
-- No published leveling weapon-speed coefficient.
local WEIGHTS = {
    ITEM_MOD_MANA_REGENERATION_SHORT = 1 / 0.22,
    ITEM_MOD_SPELL_POWER_SHORT = 0.61 / 0.22,
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 0.61 / 0.22,
    ITEM_MOD_STRENGTH_SHORT = 0.46 / 0.22,
    ITEM_MOD_SPIRIT_SHORT = 0.29 / 0.22,
    ITEM_MOD_ATTACK_POWER_SHORT = 1,
    ITEM_MOD_INTELLECT_SHORT = 0.20 / 0.22,
    ITEM_MOD_HIT_RATING_SHORT = 0.16 / 0.22,
    ITEM_MOD_AGILITY_SHORT = 0.14 / 0.22,
    ITEM_MOD_CRIT_RATING_SHORT = 0.13 / 0.22,
}

Module:RegisterProfile("SHAMAN", "leveling", {
    label = "Enhancement Leveling",
    shortLabel = "Leveling",
    order = 1,
    hideAtLevel = 60,
    assumptions = "Level 20 / solo questing / fixed leveling reference",
    weights = Module:NewWeightTable(WEIGHTS, {
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 14,
    }),
    exclusiveSpellDamage = true,
    references = {
        {
            id = "sixtysim",
            label = "SixtySim",
            date = "2026-11-05",
            description = "Level 20 / solo / equal-level mobs",
            url = "https://sixtysim.com/guides/shaman/leveling/stats/",
            weights = WEIGHTS,
        },
    },
})
