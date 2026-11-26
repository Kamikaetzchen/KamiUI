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

## Character identity

WoW Forever can hide the realm name returned by `GetRealmName()`. KamiUI
uses the complete player GUID as canonical identity and caches the last
readable GUID during temporary API restrictions. The existing initial
realm/name fallback remains for the period before the first readable GUID.

The one-time legacy conversion introduced in Core 0.2.5 was retired in
Core 0.2.23 after the owner logged into every character. No automatic
merge of realm/name records runs anymore. Existing GUID records and
`KamiUIDB.characterIdentity.legacyBackup` are retained unchanged.

Character names are displayed without realm suffixes. Realm metadata
is retained, but does not affect shared roster ordering. Bank characters
remain at the bottom and the current character is first within its group.
No realm-based roster filtering is applied.

## Equipped item level and equipment sets

The character cache stores the second return of GetAverageItemLevel as
`equippedItemLevel`. The existing equipment snapshot path schedules a
coalesced capture after equipment changes, set changes, login and refresh;
combat-restricted reads are deferred through the core scheduler. The
`equipmentSetItemLevels` table uses Blizzard's per-character set IDs.
Only a set reporting isEquipped=true receives a new measured item level;
mixed equipment changes only the current item level. Unmeasured sets have
no rating. The name naked (case-insensitive) is excluded from the set
roster, not the current item level. A fully readable enumeration removes
deleted sets and refreshes names. Editing an unequipped set retains its
last measured value until it is next equipped. No full set gear snapshots
are stored. Account uses these values for the sortable iLvl column and
its equipment-set tooltip.
