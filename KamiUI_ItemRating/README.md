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
  Forever's API reports raw combat ratings although item tooltips
  display percentages. The scoring pipeline converts raw rating to
  displayed percentage before applying editable weights.
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

* Base fields are AP equivalents **per one visible stat unit**:
  Strength/AP/etc. per 1 point; Crit, Hit, Haste, Expertise, Armor Pen,
  Dodge, Parry and Block **per +1 percentage point**. Defense Skill
  remains per skill point, not percent. Press Enter or leave a field
  to save; decimal commas work.
* Effective values show the result of any applicable multiplicative
  modifiers; they are read-only and never overwrite the saved bases.
* The compact window scrolls to expose all 23 stats, including healing,
  spell damage, stamina, avoidance, defense, block and mana regen.
  For Cat DPS their new default weights are 0, but editable.
* Overrides live account-wide in `KamiUIDB.itemRating.profiles.DRUID.cat`.
  Missing/cleared values use the built-in defaults. The Reset Defaults
  button clears this profile's overrides. v0.5.0 automatically migrates
  existing Cat combat-rating overrides to per-percent units once, keeping
  their previous item-score contributions intact.
* Item scores use the effective weights immediately on the next tooltip
  display. No caps are applied. Kings is stored under
  `KamiUIDB.itemRating.buffs.DRUID.cat.kings`.
* The Character button is optional: only Item Rating reads the Characters
  frame's `equipmentByKey.Trinket1Slot`; neither Characters nor Tooltips
  depends on Item Rating.



## Live Crit/AP reference (v0.5.0)

The editor header shows **1% Crit = X AP**, right aligned next to
"Druid - Feral Cat". This is a **read-only approximation**, separate
from the saved Cat item weights.

* Works in **all druid forms and other classes**, using the *current*
  player's UnitAttackPower, UnitDamage, UnitAttackSpeed, GetMeleeHaste
  and GetCritChance. Unavailable combat data shows "n/a".
* Convert average normal main-hand hit to unhasted DPS with
  baseSwing = currentSwing * (1 + meleeHaste/100).
  The approximation for +1% Crit is then
  14 * (averageHit / baseSwing) / (100 + Crit%).
  Crit chance is expressed in percent (10, not 0.10).
* Hover the live estimate for current AP, Crit%, average swing damage,
  speeds, haste, calculation, and **suggested Crit (%) Base**.
  This number may be copied manually into the Crit (%) input because
  both now use AP equivalents **per 1 percentage point**.
* Updates on opening the window, changes to melee stats, equipment,
  combat rating, form and auras; no polling or saved live value.
* Uses simplified 200% melee-crit damage and main-hand auto-attacks,
  ignoring other abilities, offhands, class talents, glancing blows,
  misses, armor and rotations.

## Level-aware suggested Agility Base (v0.5.1)

The live Crit/AP tooltip also suggests an **Agility Base** for the
Cat DPS profile, without changing stored weights:

* Uses `GetCritChanceFromStat(2, 1)` on WoW Forever to read the
  **current level's Crit fraction per 1 Agility**, multiplies it by 100
  to get percentage points (matching Blizzard's character sheet),
  without assuming the level-60 20-Agility-per-1%-Crit conversion.
* The **Cat** base formula is `1 AP + critPerAgility * liveCritApEquivalent`.
  It always assumes Cat Form grants 1 AP per Agility, even when the
  current Crit/AP reference is read in humanoid or Bear Form.
* Hover details include the level, Crit % per Agility, and the exact
  suggested four-decimal Base. This is read-only and can be manually
  entered into the existing Agility Base input.
* If Forever does not expose the Crit-from-stat API at runtime, only
  the Agility suggestion shows unavailable; the live Crit/AP reference
  continues working. No guessed level-60 fallback is applied.
* The estimate is a simplified melee auto-attack reference using the
  **current** combat state; it does not include skill rotations or
  stat caps. Blessing of Kings remains an optional modifier on saved
  item weights, not part of this unbuffed Cat base.

* **v0.5.2 bug fix:** The API returns a fraction, not a percentage.
  v0.5.1 omitted the factor of 100 and understated the suggested
  Agility base (e.g. ~1.007 instead of ~1.70 with 11.10 AP/Crit-%).

## Natural Instinct rotation proxy (v0.5.3)

* Observed damage-meter auto-attacks were **26.0% in Maraudon** and
  **27.7% in Alcaz Prison**. The live Crit/AP tooltip provisionally
  assumes **27% white / 73% other damage** for a Cat rotation.
* The local player's active `C_Traits` rank for **Natural Instinct**
  (Forever spell ID 1223242, 0–2 points) is read with the same
  combat-safe caching approach as Heart of the Wild.
* For a known rank, the read-only suggested Crit (%) Base and suggested
  Agility Base use a talent-aware estimate. Let `c = Crit% / 100`,
  `b = 1 + 0.10 * rank`, then
  `factor = 0.27 + 0.73 * b * (1 + c) / (1 + c * b)`.
  Multiply the existing auto-attack Crit/AP reference by this factor.
  The header displays the adjusted estimate; the hover shows the auto
  reference, talent rank, measured share and factor.
* **Upper-bound estimate, not exact:** 73% includes damage such as
  Windfury, Hurricane and periodic effects that may not get Natural
  Instinct's crit bonus. Does not model the hit table, talent effects
  on combo points, or full ability AP scaling.
* Unknown rank means **no bonus is guessed**. No saved weights or
  actual item scores are changed automatically; use the suggested
  values manually if desired.

## Armor stat and reference caps (v0.5.4)

* Added **Armor** (`RESISTANCE0_NAME`, the key returned by
  `C_Item.GetItemStats`) to the editable weight list. Its default Cat
  DPS weight is **0** AP equivalents per point of Armor; users may set
  a custom weight. Existing Cat DPS scores do not change by default.
* Hovering **Hit**, **Expertise**, **Armor**, or **Defense Skill** shows
  reference caps for a level-60 character versus a level-63 raid boss:
  * Melee Hit: **8%** (single-weapon melee abilities and auto-attacks).
  * Expertise: **6.5%** boss Dodge soft cap, **14%** boss Parry hard cap;
    attacks from behind cannot be parried.
  * Armor: **75%** maximum physical damage reduction. Under the
    level-63 boss formula, approximately **17,265** total Armor is
    needed; forms, buffs and target level matter.
  * Defense: **440** total skill to remove boss crits, absent other
    crit-immunity effects; above this, avoidance still benefits.
* These are **informational only**, not calculations of remaining cap
  from current equipment. Base and Effective weights remain uncapped;
  item scores do not automatically subtract over-cap stats.
* Other stats without a reliable universal cap (such as Haste or Armor
  Penetration) deliberately show no fixed numeric cap.
