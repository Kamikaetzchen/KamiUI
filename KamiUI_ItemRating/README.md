# KamiUI - Item Rating

WoW Forever: preliminary **Feral Cat** DPS-oriented item scoring in
**Attack Power equivalents** (1 AP = 1 point). The AddOns list name is
**KamiUI - Item Rating**.

* Displays the rating on equipment tooltips, including item links and
  Blizzard shopping tooltips, using TooltipDataProcessor (no dependency
  on KamiUI_Tooltips).
* For worn slots, shows the difference to each equipped candidate.
  Rings and trinkets compare against both slots.
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

This addon is entirely independent of KamiUI_Tooltips styling.
