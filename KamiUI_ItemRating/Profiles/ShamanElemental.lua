local Module = KamiUI:GetModule("ItemRating")

-- SixtySim WoW Forever, 2026-11-22.
-- Spell Damage = 1. Negative zero Spirit is represented as zero.
local WEIGHTS = {
    ITEM_MOD_SPELL_PENETRATION_SHORT = 2.55,
    ITEM_MOD_HIT_RATING_SHORT = 1.23,
    ITEM_MOD_HASTE_RATING_SHORT = 1.04,
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 1,
    ITEM_MOD_SPELL_POWER_SHORT = 1,
    ITEM_MOD_NATURE_DAMAGE_DONE_SHORT = 0.86,
    ITEM_MOD_CRIT_RATING_SHORT = 0.78,
    ITEM_MOD_INTELLECT_SHORT = 0.23,
    ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = 0.11,
    ITEM_MOD_MANA_REGENERATION_SHORT = 0.01,
    ITEM_MOD_SPIRIT_SHORT = 0,
}

Module:RegisterProfile("SHAMAN", "elemental", {
    label = "Elemental",
    shortLabel = "Ele",
    order = 3,
    assumptions = "Level 60 / raid buffs / 1-minute boss DPS",
    weights = Module:NewWeightTable(WEIGHTS),
    exclusiveSpellDamage = true,
    references = {
        {
            id = "sixtysim",
            label = "SixtySim",
            date = "2026-11-22",
            description = "Level 60 / 1 boss / 1 min / Horde",
            url = "https://sixtysim.com/guides/shaman/elemental/stats/",
            weights = WEIGHTS,
        },
    },
})
