# KamiUI - Item Rating

**WoW Forever** equipment comparison using fixed stat weights, not an
in-game DPS simulator. Each class/spec can register a table of editable
weights plus any number of independent reference sources.

The initial profile is **Druid - Feral Cat**, rated for a level-60 raid
with standard raid buffs and a tuned Feral talent build. It is selected
regardless of the player's current Druid form or active talents.
Additional profiles can be added under `Profiles/`.

## What appears on item tooltips

* One line: `Item Rating (Cat) 23.7 (+5.2)`, with green/red deltas.
* Rings and trinkets compare both equipped slots.
* Two-handed weapon comparisons also include the equipped offhand.
* Ratings are weighted sums of the raw values from
  `C_Item.GetItemStats(itemLink)`. No talent lookup, aura lookup, rotation
  simulation or live calculation is performed.
* Unknown proc effects, active effects and set bonuses are not modelled.
  A piece with no recognised stat shows `Unscored effect`.
* Caps are not applied. A weight is a rough reference around the source's
  benchmark gear, not a prediction of actual DPS changes on the player's
  equipment.

## Editor

Open the **Item Rating** button in the Character pane, or type
`/kami rating settings`.

* **Current** is the one authoritative, editable weight used by tooltip
  scoring. Enter decimals (including decimal commas), press Enter or
  click elsewhere to save.
* Each source, currently **SixtySim**, has a read-only column plus a
  **Use** button. Clicking it copies every *published* stat weight from
  that source into Current; stats missing from the source remain
  untouched. Existing user edits can then be changed individually.
* **Reset Defaults** restores the bundled Current weights, which start
  from SixtySim and include the explicitly documented legacy weapon
  estimate. The weights are saved account-wide at
  `KamiUIDB.itemRating.profiles.DRUID.cat`, only where changed.
* All values are **per raw stat point** (including raw combat rating), not
  per displayed percentage. A dash in the reference column means the
  source did not provide a number. It does **not** mean zero.

### SixtySim source and assumptions

* Feral Cat: <https://sixtysim.com/guides/druid/feral/stats/>
* Values published **2026-11-17**, Alliance, level 60,
  tuned **9/32/10**, fully raid-buffed, **one boss / one minute**.
* Normalised so that one Agility point = one rating point.
* Source values: Agility 1.00, Strength 0.99, Hit rating 0.89,
  Expertise 0.87, Crit rating 0.72, Haste rating 0.46,
  AP/Feral AP 0.41, Armor Pen rating 0.13.
* **Weapon DPS and flat Weapon Damage are not in SixtySim's stat table.**
  To avoid scoring weapons as zero, Current defaults each to a
  *provisional* legacy approximation of **5.74 Agility equivalents**
  (the older 14 AP estimate scaled by 0.41). These fields show
  `--` in the source column and are **not** overwritten by Use.
* Other stats that SixtySim does not publish remain editable in Current
  and initially default to zero. The editor does not invent reference
  values for them.

### Migrating from v0.5.x

The first v0.6.0 load converts existing custom Cat weights from their old
AP-equivalent values into Agility equivalents (factor 0.41). The old
per-percent combat-rating weights are also divided by the corresponding
Forever rating-points-per-percent factor, so they match the new per-raw-
point editor. The conversion runs once. Because talent and Kings runtime
modifiers no longer exist, the result is an approximate preservation of
old user edits, **not** an exact match to the old dynamic item scores.

The obsolete Kings checkbox, live-Crit panel, talent readers, Shred/Rip
rotation model, Blood Frenzy estimators, Base/Effective split and
SpellMetrics dependency have been removed.

## Adding a reference source

A profile lives in `Profiles/` and declares:

* `weights`: editable Current defaults for recognised item stat keys;
* `references`: an array with `id`, `label`, `date`, `description`,
  `url` and `weights` (values per raw point).

The editor renders a new column and **Use** button for every entry.
New specs also register through `Module:RegisterProfile(classFile, spec,
profile)`. Selecting profiles beyond the shipped Cat profile is future
work; no speculative weights are bundled for other specs.
