local Module = KamiUI:GetModule("ItemRating")

-- DoubleZug, Mobalytics WoW Forever, 15 Nov 2026.
-- Fully raid-buffed three-minute Restoration simulation in P1 gear.
-- Original normalized weights: Healing 1, Intellect 1.65,
-- Spirit 2.53, MP5 2.81, Crit 11.43 per 1%, Haste 4.26 per 1%.
-- Forever: 14 Crit rating / 10 Haste rating = 1%.
-- Spell Power is mapped to Healing Power because it also heals.
local RESTO = {
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = 1.00,
    ITEM_MOD_SPELL_POWER_SHORT = 1.00,
    ITEM_MOD_INTELLECT_SHORT = 1.65,
    ITEM_MOD_SPIRIT_SHORT = 2.53,
    ITEM_MOD_MANA_REGENERATION_SHORT = 2.81,
    ITEM_MOD_CRIT_RATING_SHORT = 11.43 / 14,
    ITEM_MOD_HASTE_RATING_SHORT = 4.26 / 10,
}

Module:RegisterProfile("DRUID", "resto3m", {
    label = "Restoration (3 min)",
    shortLabel = "Resto 3m",
    order = 4,
    assumptions = "Level 60 / raid buffs / 3-minute healing",
    weights = Module:NewWeightTable(RESTO),
    -- If both API keys represent the same healing bonus on an item,
    -- score it only once instead of double counting.
    exclusiveHealingPower = true,
    references = {
        {
            id = "mobalytics",
            label = "Mobalytics",
            date = "2026-11-15",
            description = "DoubleZug, fully raid-buffed, P1, 3 min",
            url = "https://mobalytics.gg/wow-forever/classes/"
                .. "restoration-druid-guide-doublezug",
            weights = RESTO,
        },
    },
})
