local Module = KamiUI:GetModule("ItemRating")

-- AP-equivalent weights from SixtySim's WoW Forever level-60 Cat benchmark
-- (2026-11-04): Agi 1.00, Str 0.93, AP 0.38, Crit% 10.6,
-- Hit% 6.57, Haste% 4.24, Expertise rating 0.75, ArP rating 0.13.
-- Dividing each by 0.38 makes one AP equal one score point.
-- Primary-stat bases are NOT the sim's already-buffed marginal weights:
-- 1 Strength = 2 AP; 1 Agility = 1 AP + 1/20 of 1% crit.
-- Kings and Heart of the Wild apply as separate runtime multipliers.
-- 1% crit = ~27.89 AP equivalents is still simulation-derived.
-- Secondary combat weights below are AP-equivalents per 1% (not per
-- raw rating point); Core maps GetItemStats ratings to item tooltip
-- percentages before each score contribution.
--
-- Forever item APIs return raw COMBAT RATINGS even though tooltips
-- show percent: 14 Crit / 10 Hit / 10 Haste = +1%.
-- The weighting is a provisional LEVEL-60 reference at all levels;
-- caps, complex talents, procs and gear dependencies are NOT applied.
-- Weapon DPS and flat Weapon Damage: provisional 14 AP equivalents.
Module:RegisterProfile("DRUID", "cat", {
    label = "Feral Cat",
    source = "SixtySim 2026-11-04 (level 60)",
    weights = {
        ITEM_MOD_STRENGTH_SHORT = 2,
        ITEM_MOD_AGILITY_SHORT = 1 + 27.89 / 20,
        ITEM_MOD_ATTACK_POWER_SHORT = 1,
        ITEM_MOD_FERAL_ATTACK_POWER_SHORT = 1,
        ITEM_MOD_CRIT_RATING_SHORT = 10.6 / 0.38,
        ITEM_MOD_HIT_RATING_SHORT = 6.57 / 0.38,
        ITEM_MOD_HASTE_RATING_SHORT = 4.24 / 0.38,
        ITEM_MOD_EXPERTISE_RATING_SHORT = 0.75 * 10 / 0.38,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.13 * 10 / 0.38,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 14,
        ITEM_MOD_WEAPON_DAMAGE_SHORT = 14, -- flat +1 Weapon Damage

        -- Future class/spec profiles can assign nonzero values. The Cat
        -- profile intentionally gives no Cat-DPS credit to these stats.
        ITEM_MOD_STAMINA_SHORT = 0,
        ITEM_MOD_INTELLECT_SHORT = 0,
        ITEM_MOD_SPIRIT_SHORT = 0,
        ITEM_MOD_SPELL_POWER_SHORT = 0,
        ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 0,
        ITEM_MOD_SPELL_HEALING_DONE_SHORT = 0,
        ITEM_MOD_DODGE_RATING_SHORT = 0,
        ITEM_MOD_PARRY_RATING_SHORT = 0,
        ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 0,
        ITEM_MOD_BLOCK_RATING_SHORT = 0,
        ITEM_MOD_BLOCK_VALUE_SHORT = 0,
        ITEM_MOD_MANA_REGENERATION_SHORT = 0,
    },
})
