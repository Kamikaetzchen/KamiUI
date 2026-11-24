# KamiUI roadmap and handoff

Last reviewed: 2026-11-24, after the second metallic Characters preview.
This is the current working state, not a commitment to implement every idea.

## Current focus: dark-metallic design

- [x] Build a modular atlas and standalone TGA assets
  (`573a92d`).
- [x] Add opt-in shared nine-slice / three-slice rendering and preview
  metallic window, model frame, tabs and equipment slots in Characters
  (`688eb61`, Core 0.2.6, Characters 0.3.19).
- [x] Revise assets with thinner borders and translucent panel interiors
  (`73c4261`). Owner tested the revised Characters appearance and
  considers it more elegant. No claim of testing other modules.
- [ ] Next: fit icons to metallic slots. Current
  `Styles.DarkMetallic.slotInsetRatio = 12 / 64` is used by
  `Components:StyleItemSlot()`, leaving excessive padding after the
  border revision. Inspect actual revised artwork, measure the inner
  opening, and match the inset/mask to it. Do not guess dimensions.
- [ ] Add a dedicated chamfered icon mask and matching neutral rarity/
  quest glow in the metallic texture directory (proposed names:
  `item_mask.tga`, `item_rarity_glow.tga`). The current glow uses
  `KamiUI/Media/ItemRarityGlow_16x16.tga` and a square slice renderer
  in ItemSlots.lua. Retain the original path and behavior for legacy
  slots; preserve quality colors, gold quest glow, search dimming,
  cooldowns, and item interactions. Test empty and populated slots.
- [ ] Evaluate neutral metal textures plus runtime palette tint and a
  separate accent/background layer. The current metallic window uses
  ApplyMetallicPanel rather than the legacy colored backdrop, so
  verify inventory purple and bank green before expanding.
- [ ] Test the next Characters revision in game (icon size, corners,
  common/uncommon/rare/epic quality, quests, transparency, tab states).
- [ ] Expand to other modules incrementally: inventory/bank, ActionBars,
  tooltips, unitframes/statusbars/castbars and remaining controls.
  The exact rollout order is not fixed.
- [ ] Review asset redundancy after integration. For example, mirrored
  header decorations may share one texture via UV flipping; generic
  frames may serve multiple control types. Do not delete files yet.

### Current texture contract

Atlas 1024 x 512, 54 regions; standalone TGA files are used by the
current renderer. Complete nine-slice frames have a 96 x 96 logical
area within 128 x 128 padded files; UV boundaries 0, .25, .5, .75.
The revised metadata lists panel center alpha 140 and tooltip center
alpha 184; action_outer center is transparent. See atlas.json for
the precise current contract. Atlas Lua metadata is not loaded by
the addon; actual shared rendering is in Components/Metallic.lua.

## Other open checks

- [ ] Rested XP: owner observed offline predictions of 150% while live
  values were about 120% at Well Rested 0/5. GUID migration / stale
  name-realm snapshots are a possible explanation, not a proven cause.
  Log into each alt once, then compare fresh offline predictions with
  live values. Current formula assumes 5% per 8h resting or 32h outside;
  do not change it without measurements or reliable evidence.
- [ ] RadialMenu: newly received Conjured Water was missing until a
  dungeon loading screen triggered a rescan. Item/tooltip availability
  or event timing is suspected; inspect before fixing. Known drink
  fallback IDs currently do not cover all conjured drinks.
- [ ] Chat: investigate local channel numbering starting at 5 and
  unexpected French trade channels using the owner's in-game output
  of `/dump {GetChannelList()}`. No confirmed KamiUI bug.
- [ ] Verify recently added Account XP bars and exact XP hover tooltips
  in game. Account 0.2.2; offline values use character cache. No runtime
  verification recorded here.

## Maintenance

Update this file after confirmed decisions and in-game feedback. Keep
the durable design rules in DESIGN.md and agent workflow in AGENTS.md.
Use the current source and Git history for exact implementation details.
