# KamiUI - Characters: Automatic Riding Equipment

The Characters module automatically swaps owned riding-speed equipment
from your bags when `IsMounted()` becomes true. No equipment sets are
required. The feature works while the character pane is closed.

A per-character **Mount Gear** checkbox sits at the bottom-left of the
character pane (6 px inset, left of Main Hand), opposite the Item Rating
button. It is enabled by default. Unchecking stops future automatic
equips and safely restores any gear previously replaced by this module,
including when still mounted. Restoration waits until combat ends.
Manual equipment changes are still respected. The preference is saved
as `KamiUIDB.characters.data[characterKey].mountGearEnabled`.

Supported Classic/Forever bonuses:

| Equipment | Identification | Slot |
| --- | --- | --- |
| Carrot on a Stick (+3%) | Item ID 11122 | second trinket (Trinket1Slot) |
| Riding Skill gloves (+2%) | Permanent enchant ID 930 | hands |
| Mithril Spurs boots (+4%) | Permanent enchant ID 464 | feet |

The glove and boot bonuses are recognized on **enchanted equipment
item links**, not on loose recipes or loose Mithril Spurs items.
An already-equipped riding piece is left untouched. For Carrot on a
Stick, either trinket slot counts as already equipped.

On mounting, the addon records the **exact previously equipped item
link** for each slot it changes, then equips matching riding gear from
the bags. On dismount, it restores only the slots it changed and only
if they still contain the item placed by the automation; manual
equipment changes win. If the original slot was empty, it is emptied
again when bag space permits.

These temporary snapshots are saved with the current character under
`KamiUIDB.characters.data[characterKey].mountEquipment`, surviving
`/reload` or relog while mounted. A delayed swap is confirmed against
the actual worn gear before the next action is considered complete.

Equipment operations never run during combat. The existing keyed
`UI:RunOutOfCombat()` scheduler rechecks **the latest** `IsMounted()`
state when combat ends, so a stale mount action cannot replay after
dismounting. When an item is missing, a bag is full, the cursor is
occupied, or an equip operation cannot complete, the swap is skipped
or retried on a subsequent inventory event; the addon does not force
a manual gear change.

Classic +3%/+4%/+2% bonuses can stack. Riding Crop (TBC) is
intentionally not included. No changes to ActionBars or RadialMenu.

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
