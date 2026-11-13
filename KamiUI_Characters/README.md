# KamiUI - Characters: Automatic Riding Equipment

The Characters module automatically swaps owned riding-speed equipment
from your bags when `IsMounted()` becomes true. No equipment sets or
additional UI are required. The feature works while the character pane
is closed.

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
