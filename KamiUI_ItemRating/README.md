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

## Deliberate v0.1 limitations

* Static **level-60 reference weights** from SixtySim (2026-11-04),
  including common Cat talents; **not** automatically adjusted for level,
  talents, buffs or gear. Score is a guide, not a DPS prediction.
* No caps are subtracted. Hit/Expertise remain linear and scores don't
  depend on currently equipped equipment.
* Procs, active effects and set bonuses are **not** valued; items with
  no scored stats show "Unscored effect".
* Weapon DPS is approximated as 14 AP per 1 weapon DPS.
* Enchant/gem stat resolution depends on C_Item.GetItemStats and may not
  include every enchant/gem. Two-handed comparisons include the worn
  offhand; one-handed comparisons only compare the mainhand.
* Other classes and Bear-specific profiles intentionally have no score.

Source: https://sixtysim.com/guides/druid/feral/stats/

## Editing weights

Use the **Item Rating** button directly below the two trinket slots in
KamiUI's Character screen, or type `/kami rating settings`.

* Input fields are AP equivalents **per one stat/rating point** (not per
  1% Crit/Hit). Press Enter or leave a field to save; decimal commas work.
* Overrides live account-wide in `KamiUIDB.itemRating.profiles.DRUID.cat`.
  Missing/cleared values use the built-in defaults. The Reset Defaults
  button clears this profile's overrides.
* Item scores use the effective weights immediately on the next tooltip
  display. No caps are applied.
* The Character button is optional: only Item Rating reads the Characters
  frame's `equipmentByKey.Trinket1Slot`; neither Characters nor Tooltips
  depends on Item Rating.

