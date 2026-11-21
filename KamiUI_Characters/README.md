# KamiUI - Characters: Auto Equip

The per-character **Auto Equip** checkbox at the bottom-left of the
character pane enables context-sensitive equipment swapping. The setting
is saved as `autoEquipEnabled`, and the logic lives in
`AutoEquipment.lua`.

## Priorities

Slot **14** (`Trinket1Slot`) is managed by ONE shared priority system:

1. While mounted, equip **Carrot on a Stick** (11122), if available.
2. Otherwise, in Western/Eastern Plaguelands, Scholomance or Stratholme,
   equip the highest-priority owned Argent Dawn trinket.
3. Outside those conditions (or when Auto Equip is turned off), restore
   the original item only if Auto Equip is still wearing its last swap.

The Argent Dawn priority is: **Mark of the Champion (AP, 23206)**,
**Seal of the Dawn (AP, 13209)**, **Mark of the Champion (spell power,
23207)**, **Rune of the Dawn (spell power, 19812)**, and
**Argent Dawn Commission (12846)**. These all enable Scourgestone drops.
The priority favors Feral's physical damage; an existing Argent Dawn
trinket in slot 13 also counts as satisfying the zone requirement.

The zone check recognizes UI maps **22/23**, Scholomance floors
**306-309** (also **476-479**) and Stratholme floors **317/318**.
It also checks physical instance IDs **289** (Scholomance) and **329**
(Stratholme), and the localized/English zone names as a fallback.
Unrelated dungeons and raids are excluded.

While mounted, the usual glove/boot riding equipment still works:

| Equipment | Identification | Slot |
| --- | --- | --- |
| Carrot on a Stick (+3%) | Item ID 11122 | Trinket 14 |
| Riding Skill gloves (+2%) | Permanent enchant ID 930 | Hands |
| Mithril Spurs boots (+4%) | Permanent enchant ID 464 | Feet |

Gloves and boots are detected through their **equipped item links**,
not through loose enchant materials. If Carrot is already equipped
in slot 13, no second copy is sought for slot 14.

## Safety and restoration

Equipment swaps **never run in combat**. The existing keyed
`UI:RunOutOfCombat()` scheduler rechecks the current zone/mount state
after combat, rather than replaying a stale request.

Auto Equip saves the exact original item link in
`KamiUIDB.characters.data[characterKey].autoEquipment` and tracks
temporary swaps. Transitions between Plaguelands, mounted, dismounted
and outside preserve that original, preventing the Argent badge or
Carrot from becoming the permanent restoration target.

After dismounting, Auto Equip checks whether the global cooldown is
active, using the Forever-compatible GCD detection in KamiUI_ActionBars.
After the initial 0.1-second dismount delay, it checks every 0.05
seconds while a GCD is detected and attempts the equipment swap
as soon as the GCD is no longer observed, without an additional
clearance margin. This applies uniformly to all shapeshift forms.

Equipment swaps are also deferred for the full duration of ongoing
spellcasts or channels, including long crafting casts. A GCD may end
long before a 10-second cast ends; Auto Equip waits for the cast to
finish without consuming any of its five swap attempts.

Manual equipment changes are respected. Auto Equip verifies each
swap against the equipped item, and retries transient failures up to
five times at 0.8-second intervals. Early retries may fall within
the 1.5-second shapeshift GCD; subsequent retries can succeed afterward.
A change to a different item is never overwritten. Druid form changes
also trigger an immediate refresh.
The original saved link survives `/reload` and relog while swapping.

## Character equipment slot actions and cooldowns

Equipment slots show their equipped item's cooldown as a native dark swipe
with a visible countdown, including trinkets with on-use or on-equip
cooldowns. Cooldowns refresh after equipment changes, cooldown events, and
combat unlock. Restricted combat timestamps do not trigger arithmetic on
secret values.

Right-click invokes the current equipment slot's native item action through
Blizzard's `InsecureActionButtonTemplate` **outside combat**, rather than
calling the protected `UseInventoryItem()` from addon Lua. This deliberately
keeps the character window unprotected and its navigation operational in
combat. **Use combat trinkets via the action bar or a `/use 13` / `/use 14`
macro**. Left-click pickup, modifier-link and middle-click equipment-set
ignore controls are unchanged. Right-click is disabled when viewing an
alt's cached gear.

## Character identity migration (Core 0.2.5)

WoW Forever can hide the realm name returned by `GetRealmName()`. KamiUI
now keys per-character SavedVariables by the complete `UnitGUID("player")`
(e.g. `Player-6947-003DB3DC`), not by `realm::name`.

* On the first login with each character, Core migrates that character's
  old `realm::name` and `::name` records into its GUID. **Log into
  every alt once** to complete the roster conversion. Unvisited alts keep
  their readable old keys and cached data until then.
* Migration covers Characters (including equipment, professions and Auto
  Equip), Bags/Bank, RestedXP, quest-header state, Target Macro settings
  and RadialMenu favorites. Bank snapshots are chosen separately from bag
  snapshots, so a recent bag update without an open bank does not erase
  previously cached bank contents.
* Original legacy entries are backed up in
  `KamiUIDB.characterIdentity.legacyBackup`, grouped by module and old key,
  before their active records are merged/removed. The backups are retained
  until explicitly cleared; they use additional SavedVariables space.
* If a character name occurs under multiple distinct old realm names,
  migration skips that name rather than guessing which realm belongs to
  the current GUID. Old data remains intact for manual reconciliation.
* During temporary player-GUID API restrictions the last readable GUID
  is reused. This prevents creating new empty-realm duplicates in combat.
* Realm suffixes are not shown in the dropdown when the realm API is
  unavailable. Previously known nonempty realm metadata is preserved.

Before updating, copy the existing `WTF/Account/.../SavedVariables/KamiUI.lua`
file with the WoW client closed. To verify the logged-in character after
updating, run `/run print(KamiUI:GetCurrentCharacterKey())` and check that
it prints the same `Player-...` GUID on every login.
