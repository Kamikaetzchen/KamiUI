# Radial Menu

**Q:** Hearthstone, mounts, food, drinks, buff food, elixirs.

**E:** Healing, mana, rage and utility potions, bandages.

## Controls — identical in and out of combat

- **Q or E once:** Open the corresponding radial menu.
- **Q or E again:** Close that menu.
- **Switch from Q to E:** The previous wheel closes automatically.
- **Left-click a main icon:** Use the default item/spell and close.
- **Right-click a main icon:** Show its variants (no hover or delay).
- **Left-click a variant:** Use that variant and close.
- **Right-click a variant:** Set a per-character favorite (out of combat).
- **Click unused space inside the main wheel:** Close the menu.
- **Click or mouse-look elsewhere:** Interact with the world normally;
  the menu stays open until Q/E or an item action closes it.

WoW's secure override key bindings operate on a hardware key click, not
an unprotected Lua keyboard listener. Both Q and E now use the same
SecureHandlerClickTemplate regardless of combat status. No polling, no
press-and-hold behavior, and no state driver are used.

Both menus use permanent, screen-relative positions (the same during
and outside combat): Q is 200 screen pixels inward from the left-quarter
position and E is 200 pixels inward from the right-quarter position.
Both remain at 58% of the screen height. UI scale is accounted for;
display/scale changes are repositioned outside combat or deferred until
combat ends. Item actions remain secure in both modes.

The smaller main wheel and central Q/E disc leave more room around the
menu. Variant wheels extend outward in the exact direction of their parent
icon. Their distance increases when necessary to avoid overlapping the
main icon. Only the primary wheel's bounding area intercepts mouse clicks;
there is no full-screen click catcher.

Closing a wheel also hides its variant menus via the root's secure OnHide
handler. Variants are arranged based on available inventory; up to 16
are shown at once (paging is not implemented yet). Updates to secure
buttons are delayed until after combat.

Q/E are override bindings and do not appear in the Key Bindings UI.

## Commands

- /kami radial refresh
- /kami radial reset

Item detection uses inventory subclasses and tooltip text; Forever
custom consumables may need specific classification rules.
