# KamiUI - Item Rating

WoW Forever: preliminary **Feral Cat** DPS-oriented item scoring in
**Attack Power equivalents** (1 AP = 1 point). The AddOns list name is
**KamiUI - Item Rating**.

* Displays the rating on equipment tooltips, including item links and
  Blizzard shopping tooltips, using TooltipDataProcessor (no dependency
  on KamiUI_Tooltips).
* Displays one compact tooltip line: `Item Rating (Cat) 23.7 (-27.9)`;
  the delta is red/green and the `pts` suffix is omitted.
* Rings and trinkets show both equipped-slot deltas in order, separated
  by `/` inside the same parentheses.
* Uses C_Item.GetItemStats, including passive equip stats and weapon DPS.
  Forever's combat rating values are **not percentages**: Crit /14,
  Hit /10 and Haste /10 at level 60 are used in the weights.
* No inspections or queries against other players.

## Deliberate limitations

* Primary-stat bases use Cat mechanics: Strength **2 AP** and Agility
  **1 AP + (27.89 / 20) crit AP equivalents = 2.3945** before any buffs.
  The 27.89 AP value per 1% crit comes from the provisional SixtySim
  benchmark (10.6 / 0.38), not a universal conversion.
* Heart of the Wild is added at **+2% Strength per talent rank**.
  The rank is read from the player's C_Traits config. If unavailable,
  no bonus is applied and the hover tooltip explicitly says so.
* Other weights (Crit, Hit, etc.) remain level-60 simulation estimates,
  not adjusted for level, gear, procs or complex talents.
* Blessing of Kings is an opt-in **saved checkbox**, not an automatic
  aura read. Kings adds +10% to Strength, Agility, Stamina, Intellect and
  Spirit; direct AP, Hit/Crit/Haste/etc. do not get that multiplier.
* Hover any stat label to see the exact Base, talent/buff factors, and
  Effective weight. The item tooltip and comparisons use Effective weights.
* No caps are subtracted. Hit/Expertise remain linear and scores don't
  depend on currently equipped equipment.
* Procs, active effects and set bonuses are **not** valued; items with
  no scored stats show "Unscored effect".
* Weapon DPS is approximated as 14 AP per 1 weapon DPS. Flat **Weapon
  Damage** (such as Knucklebone Ring's +2 Weapon Damage) is separately
  included at a provisional 14 AP per +1 damage. Native item stats are
  preferred; if necessary the original item's C_TooltipInfo text is
  scanned for that effect. The fallback currently supports English and
  German phrasing, and is unverified in the live Forever client.
* Enchant/gem stat resolution depends on C_Item.GetItemStats and may not
  include every enchant/gem. Two-handed comparisons include the worn
  offhand; one-handed comparisons only compare the mainhand.
* Other classes and Bear-specific profiles intentionally have no score.

Source: https://sixtysim.com/guides/druid/feral/stats/

## Editing weights

Use the **Item Rating** button in the bottom-right below the trinket slots in
KamiUI's Character screen, or type `/kami rating settings`.

* Base fields are AP equivalents **per one stat/rating point** (not per
  1% Crit/Hit). Press Enter or leave a field to save; decimal commas work.
* Effective values show the result of any applicable multiplicative
  modifiers; they are read-only and never overwrite the saved bases.
* The compact window scrolls to expose all 23 stats, including healing,
  spell damage, stamina, avoidance, defense, block and mana regen.
  For Cat DPS their new default weights are 0, but editable.
* Overrides live account-wide in `KamiUIDB.itemRating.profiles.DRUID.cat`.
  Missing/cleared values use the built-in defaults. The Reset Defaults
  button clears this profile's overrides.
* Item scores use the effective weights immediately on the next tooltip
  display. No caps are applied. Kings is stored under
  `KamiUIDB.itemRating.buffs.DRUID.cat.kings`.
* The Character button is optional: only Item Rating reads the Characters
  frame's `equipmentByKey.Trinket1Slot`; neither Characters nor Tooltips
  depends on Item Rating.

