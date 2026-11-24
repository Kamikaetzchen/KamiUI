# KamiUI - Item Rating

WoW Forever equipment comparisons with fixed, editable stat weights.
**v0.7.0** includes four independent profiles for Druids:

1. **Feral Cat** — SixtySim DPS reference (one boss, one minute).
2. **Bear Threat** — SixtySim TPS reference (one boss, one minute).
3. **Bear Survival** — Pawn Forever endgame Bear scale, mixing defense
   with some threat; NOT a dedicated mitigation simulation.
4. **Restoration (3 min)** — DoubleZug's Mobalytics three-minute
   fully raid-buffed healing simulation.

On a Druid, an equipment tooltip shows **all four Item Rating lines**
in that order, even if a different profile is selected in the editor.
Each line shows its own score and the difference from the equipped slot;
rings and trinkets include both alternative slots. A two-handed weapon
comparison includes the worn offhand.

## Profile editor

Open **Item Rating** in the Character pane, or type
`/kami rating settings`. Classes without registered profiles now show
an explicit unavailable-profile dialog instead of silently doing nothing.
No new class weights are implied by the dialog.

* The dropdown selects the profile whose values you are editing. The
  choice is stored account-wide in `KamiUIDB.itemRating.editorSpec.DRUID`.
  The dropdown does **not** restrict which ratings appear in tooltips.
* **Current** contains the actual editable weights. Each profile stores
  independent overrides under
  `KamiUIDB.itemRating.profiles.DRUID.<profileID>`.
* The read-only source column (SixtySim, Pawn Forever or Mobalytics)
  displays reference values. **Use** copies only published weights to
  Current; reference cells shown as `--` stay unchanged.
* **Reset Defaults** resets only the selected profile.
* Every value is **per raw stat point** from `C_Item.GetItemStats`.
  Combat ratings are not displayed-percentage units.
* More sources can be added to a profile's `references` array; the
  editor creates a source column and Use button for each.
* Feral Cat's old v0.5.x override migration remains intact.

## Sources and assumptions

### Feral Cat

SixtySim, 17 Nov 2026, raid-buffed level 60, tuned 9/32/10,
one boss / one minute, **1 Agility = 1 point**.

https://sixtysim.com/guides/druid/feral/stats/

Source weights: Agility 1.00, Strength 0.99, Hit 0.89, Expertise 0.87,
Crit 0.72, Haste 0.46, AP/Feral AP 0.41, Armor Pen 0.13.
Cat's **Weapon DPS and flat Weapon Damage = 5.74** are a separate
provisional approximation (14 AP x 0.41), not SixtySim values.

### Bear Threat

SixtySim, 17 Nov 2026, raid-buffed level 60, one boss / one minute,
**1 Agility = 1 point**. Threat (TPS) only; not a survival metric.

https://sixtysim.com/guides/druid/feral-tank/stats/

Source weights: Expertise 5.72, Strength 1.68, Hit 1.43, Crit 1.41,
Agility 1.00, Haste 0.91, AP/Feral AP 0.76, Armor Pen 0.33.
The source produces slightly negative Dodge and Defense threat weights;
this addon intentionally uses zero for those, and zero for Stamina.
**Weapon DPS and flat Weapon Damage = 10.64** use a provisional
14 AP x 0.76 estimate; they are not published SixtySim coefficients.

### Bear Survival

Pawn Forever, endgame Bear (`max` scale), generated from GearQuest
Forever. This mixes mitigation and threat, so the numbers cannot be
compared directly against the SixtySim Threat score.

https://github.com/turlockmike/pawn-forever/blob/main/PawnForever/Weights.lua

Source weights: Stamina 1.00, Defense 0.85, Dodge Rating 0.70,
Agility 0.55, Weapon DPS 4.90, Expertise 0.60, Hit 0.40,
Strength 0.35, Armor 0.10, Crit 0.25, Haste 0.10,
AP/Feral AP 0.18, Intellect 0.05, Spirit 0.02 and MP5 0.05.
Pawn's percentages were converted to raw Forever ratings
(Dodge /12, Expertise /10, Hit /10, Crit /14, Haste /10).
Flat Weapon Damage defaults to a provisional 4.90, but is not
an explicit Pawn source column value.

### Restoration (3 min)

DoubleZug, Mobalytics, 15 Nov 2026, three-minute fully raid-buffed
level-60 Restoration simulation in approximately Phase 1 gear.
**1 Healing Power = 1 point**.

https://mobalytics.gg/wow-forever/classes/restoration-druid-guide-doublezug

Source normalized values: Healing Power 1.00, Spirit 2.53,
MP5 2.81, Intellect 1.65, Crit **11.43 per 1%**, Haste
**4.26 per 1%**. Forever raw rating conversion gives
Crit **11.43 / 14 = 0.8164 per rating** and Haste
**4.26 / 10 = 0.426 per rating**.

General Spell Power (bonus to damage and healing) is mapped to
Healing Power at weight 1. If WoW's item API supplies both general
Spell Power and a separate Healing value for the same item, we count
only the stronger weighted amount, not both. Pure Spell Damage is not
automatically assigned a Healing weight.

## Limitations

* **These are heuristic, benchmark-based scores, not guaranteed DPS,
  TPS, mitigation or HPS increases.** They do not consider stat caps,
  current equipment, real fight length, talent deviations, procs or
  set-bonus effects.
* The four profile scores have different units; compare items **within**
  the same profile only, never Cat against Resto.
* Items whose important value is an unscored effect show
  `Unscored effect` when there are no recognised numeric stats.
* Native `C_Item.GetItemStats` must expose a stat for it to be scored,
  except the preserved English/German flat-weapon-damage tooltip fallback.
* Item Rating does not use dynamic talents, forms, Kings aura reads,
  live Crit/AP proxies, or a rotation model. The assumed raid setup
  is already reflected in each source.
* Support for additional classes requires registering profiles and
  their weights. The editor automatically includes the new profile.
