# Radial Menu

**Q:** Hearthstone, mounts, food, drinks, buff food, elixirs.

**E:** Healing, mana, rage and utility potions, bandages.

## Controls

- **Outside combat:** Hold Q or E to open the corresponding menu at the
  cursor; releasing the key closes it immediately without selecting anything.
  Clicking an item also closes the wheel.
- **In combat (both Q and E):** The secure binding opens or closes the menu.
  Because WoW doesn't allow ordinary key-up handlers to hide protected
  frames in combat, this is a secure click-to-toggle fallback instead of
  true hold-to-show. The consumable buttons remain protected and usable.
- **Left click:** Use the default item/spell (closes menu).
- **Right click a main icon:** Open its variants (no hover or delay).
- **Left click a variant:** Use it (closes menu).
- **Right click a variant:** Save per-character favorite; only out of combat.
- **Click outside:** Close and reset all submenus.

Only available variants are arranged; there are no preallocated empty
positions. Spacing and ring radius adjust automatically to the number
of variants (up to 16 visible in this first version; paging for more
items is not yet implemented).

WoW requires protected action attributes and layout changes to be
performed out of combat. Inventory changes during combat are applied
after combat. The last safe menu position is retained during combat.
The Q/E bindings are overrides and don't appear in the Key Bindings UI.

The click bindings in combat may follow the client's
ActionButtonUseKeyDown setting. The out-of-combat hold mode uses
OnKeyDown and IsKeyDown instead, so it does not depend on that setting.

## Commands

- /kami radial refresh
- /kami radial reset

Item detection uses inventory subclasses and tooltip text; Forever
custom consumables may need specific classification rules.
