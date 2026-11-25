local Module = KamiUI:GetModule("ItemRating")

-- SixtySim WoW Forever, 2026-11-22.
-- Healing Power = 1. Source does not publish a Spirit coefficient.
local WEIGHTS = {
    ITEM_MOD_INTELLECT_SHORT = 2.33,
    ITEM_MOD_MANA_REGENERATION_SHORT = 2.17,
    ITEM_MOD_CRIT_RATING_SHORT = 1.09,
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = 1,
    ITEM_MOD_SPELL_POWER_SHORT = 1,
    ITEM_MOD_HASTE_RATING_SHORT = 0.73,
}

Module:RegisterProfile("SHAMAN", "resto3m", {
    label = "Restoration (3 min)",
    shortLabel = "Resto 3m",
    order = 4,
    assumptions = "Level 60 / raid buffs / 3-minute healing",
    weights = Module:NewWeightTable(WEIGHTS),
    exclusiveHealingPower = true,
    references = {
        {
            id = "sixtysim",
            label = "SixtySim",
            date = "2026-11-22",
            description = "Level 60 / 1 boss / 3 min / single target",
            url = "https://sixtysim.com/guides/shaman/restoration/stats/",
            weights = WEIGHTS,
        },
    },
})
