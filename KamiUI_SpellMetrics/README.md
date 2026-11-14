# KamiUI - Spell Metrics (v0.1.1)

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
