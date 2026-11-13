local Module = KamiUI:GetModule("ItemRating")

-- AP-equivalent weights from SixtySim's WoW Forever level-60 Cat benchmark
-- (2026-11-04): Agi 1.00, Str 0.93, AP 0.38, Crit% 10.6,
-- Hit% 6.57, Haste% 4.24, Expertise rating 0.75, ArP rating 0.13.
-- Dividing each by 0.38 makes one AP equal one score point.
--
-- Forever item APIs return COMBAT RATINGS, not percentages:
-- 14 Crit / 10 Hit / 10 Haste = 1% at level 60.
-- The weighting is a provisional LEVEL-60 reference at all levels;
-- caps, talents, special effects and gear dependencies are NOT applied.
-- Weapon DPS: preliminary estimate of 14 AP-equivalent per DPS.
Module:RegisterProfile("DRUID", "cat", {
    label = "Feral Cat",
    source = "SixtySim 2026-11-04 (level 60)",
    weights = {
        ITEM_MOD_STRENGTH_SHORT = 0.93 / 0.38,
        ITEM_MOD_AGILITY_SHORT = 1 / 0.38,
        ITEM_MOD_ATTACK_POWER_SHORT = 1,
        ITEM_MOD_FERAL_ATTACK_POWER_SHORT = 1,
        ITEM_MOD_CRIT_RATING_SHORT = (10.6 / 14) / 0.38,
        ITEM_MOD_HIT_RATING_SHORT = (6.57 / 10) / 0.38,
        ITEM_MOD_HASTE_RATING_SHORT = (4.24 / 10) / 0.38,
        ITEM_MOD_EXPERTISE_RATING_SHORT = 0.75 / 0.38,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.13 / 0.38,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 14,
    },
})
