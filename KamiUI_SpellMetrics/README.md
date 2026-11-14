# KamiUI - Spell Metrics (v0.1.3)

Tooltip and action-bar estimates, based on the client's spell descriptions,
current weapon damage from `UnitDamage("player")`, and readable combat
stats. **Not a combat log or a full damage simulator.**

## Forever Druid talent handling

The module reads active committed Druid talent ranks through `C_Traits`.
Talent lookups are cached; a missing or unreadable talent/configuration
does not cause a guessed bonus. In combat, unreadable values reuse
existing valid SpellMetrics analyses.

* **Shredding Attacks:** Shred Energy cost is `60 - 6 x rank` (up to 3).
* **Savage Fury:** 5% per rank (maximum 10%) for Claw, Rake, Shred,
  Maul and Swipe. For weapon-formula spells (especially Shred),
  modifiers apply to the weapon component only. Blizzard's 15 Oct
  Forever notes explicitly say the **flat Shred bonus shown in the
  native tooltip already includes Savage Fury**. Multiplying the
  entire combined value would double count that flat bonus. For
  other direct/periodic spell amounts, the estimated multiplier is
  applied to parsed base values.
* **Genesis:** 2% per rank (maximum 10%) to parsed periodic effects,
  including five-Combo-Point Rip variants.
* **Naturalist:** 2% per rank (maximum 10%) to parsed damage that
  is not weapon-derived. The current auto-attack damage returned
  by `UnitDamage` may already contain the global damage bonus:
  it is **not applied again** to weapon-derived components. This
  is a conservative approximation pending a live test of how
  `UnitDamage` and native spell tooltips expose generic modifiers.
* **Natural Instinct:** 10% additional crit-damage bonus per rank
  for eligible Feral melee ability direct/periodic components.
  The expected crit damage multiplier changes from 2.0 to 2.1/2.2
  at 1/2 and 2/2, provided melee crit is readable.
* **Rend and Tear:** Not applied automatically because a spell
  tooltip does not establish whether the target is bleeding.
  ItemRating's boss-rotation estimator models its Rip uptime.

**Unverified edge cases:** The retail-derived tooltip API may already
include some talent modifiers on certain non-weapon spells, and
actual target armor/avoidance is not modeled. These numbers remain
estimates rather than verified post-mitigation damage. Inspect with
`/kami spellmetrics debug <spellID>` (prints parsed values, current
talent ranks and `UnitDamage` percentage modifier). A client-side
damage-meter or training-target comparison can help validate it.

Omen of Clarity procs, misses, dodges, mana sustain and the
Hit/Expertise caps are not applied in SpellMetrics.

## Macro tooltips and Ferocious Bite (v0.1.2)

* The action-bar overlay can already resolve spells from macros using
  LibActionButton's `GetSpellId()`. The native `SetAction` tooltip is a
  separate Macro data type, not necessarily a Spell tooltip. We register
  a guarded Macro post-callback and resolve the spell from the owning
  **KamiUI** action button, leaving the native tooltip intact. The
  ordinary Spell callback remains unchanged.
* Ferocious Bite on Forever lists its 1–5 CP damage as **ranges**
  (e.g. `5 points: 612-662 damage`). The parser now accepts ranges and
  uses their midpoint for direct, combo-breakdown, and per-Energy metrics.
* When its tooltip says AP increases damage, estimates add the classic
  coefficient of **0.07 x attack power x combo points** to the
  currently learned Bite rank. The exact Forever implementation of
  this coefficient requires in-game validation. This estimate excludes
  additional damage from excess Energy: assume a 35-Energy Bite.
* If attack power is unreadable during combat, the last valid estimate
  is used rather than silently reporting an AP-free Bite as complete.
  `/kami spellmetrics debug 22828` shows all parsed combo values for
  the level-48 Bite rank, including the estimated AP contribution.

## Ferocious Bite reference versus real hits (v0.1.3)

* The 612–662 rank-4 tooltip range is a fixed **base** range; it matches
  the Forever spell database even with a player's gear changing. The
  earlier assumption that the tooltip had already included AP was wrong.
* Classic Bite scales by 7% AP per Combo Point. Forever's November
  tuning notes say AP scaling was increased by **about 25%**, so this
  version assumes **8.75% AP per CP**. This still needs direct client
  validation; it is not an exact extracted coefficient.
* The displayed Combo Damage and 1-second DPS are **expected damage
  before armor**, including averaged critical strikes and available
  talent multipliers. They are *not* the typical non-critical hit in a
  combat log. Physical Bite is reduced by enemy armor, whereas Rip's
  bleed bypasses armor. A new 5-CP noncrit (before armor) line makes
  this distinction visible and avoids misleading Bite/Rip comparisons.
* **Poised** is a one-use, out-of-combat 10-Energy discount. When the
  player's native Bite tooltip shows 25 Energy, the DPE estimate still
  uses its normal **35 Energy** for sustained rotation comparisons;
  the temporary discounted cost is shown separately.
* Predatory Discipline can add bonus damage from remaining Energy;
  this bonus is still **excluded** from these estimates.
