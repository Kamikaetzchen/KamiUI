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

local defaults = {}
for key, value in pairs(SIM_WEIGHTS) do
    defaults[key] = value
end

-- Provisional legacy fallback, NOT a SixtySim result: 14 AP per weapon
-- DPS/flat damage, scaled by the source's 0.41 Agility per AP.
-- "Use SixtySim" intentionally leaves these fields alone.
defaults.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 14 * 0.41
defaults.ITEM_MOD_WEAPON_DAMAGE_SHORT = 14 * 0.41

-- Keep other stats individually editable, without inventing sim weights.
for _, key in ipairs({
    "ITEM_MOD_STAMINA_SHORT",
    "RESISTANCE0_NAME",
    "ITEM_MOD_INTELLECT_SHORT",
    "ITEM_MOD_SPIRIT_SHORT",
    "ITEM_MOD_SPELL_POWER_SHORT",
    "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
    "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    "ITEM_MOD_DODGE_RATING_SHORT",
    "ITEM_MOD_PARRY_RATING_SHORT",
    "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    "ITEM_MOD_BLOCK_RATING_SHORT",
    "ITEM_MOD_BLOCK_VALUE_SHORT",
    "ITEM_MOD_MANA_REGENERATION_SHORT",
}) do
    defaults[key] = 0
end

Module:RegisterProfile("DRUID", "cat", {
    label = "Feral Cat",
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
