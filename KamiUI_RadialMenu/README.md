# Radial Menu

Q: Hearthstone, mounts, food, drinks, buff food, elixirs.
E: health potions, mana potions, rage potions, utility potions, bandages.

Left-click a main icon to use the chosen item/spell and close the wheel.
Right-click the main icon to open a second radial wheel with variants.
Left-click a variant to use it; right-click a variant to save as a favorite
(out of combat only). A missing favorite falls back to automatic choice.
Click outside the wheel or press its hotkey again to close it.
Q/E are currently bound using override bindings, without Key Bindings menu entries.
The wheel opens at the cursor outside combat; WoW disallows moving protected
action buttons during combat, so their last safe position is retained.

Menus stay at screen center because protected action buttons cannot be
repositioned around the cursor in combat. The E wheel opens using a secure
handler, and consumables are cast using SecureActionButtonTemplate.
Changes in inventory are deferred while in combat and refreshed afterward.

Commands:
- /kami radial refresh
- /kami radial reset

Item detection uses inventory item subclasses and localized tooltip text.
Forever-specific items may need further classification rules.
The first 12 variants per category are shown.
