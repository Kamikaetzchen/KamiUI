# KamiUI roadmap and handoff

Last reviewed: 2026-11-24, after the slot and palette preview feedback.
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
- [x] Measure the revised 64px button: 4px straight border, 56px
  opening and 6px inner chamfers. Fit the icon to that opening.
- [x] Add standalone chamfered icon mask and neutral rarity/quest glow.
  Use shared ItemSlots rendering, retain the square legacy glow, and
  fall back to a conservative inset when mask APIs are unavailable.
- [x] Add neutral runtime metal derivatives and independent panel fill
  and accent layers. Forward window palette colors through CreateWindow.
  Core 0.2.7 / Characters 0.3.20. Owner approved the icon fit,
  restrained rarity glow and transparency in the Hunter screenshot.
  Other qualities, quest glow and broader module coverage remain untested.
- [x] Add dedicated metallic text buttons and class-colored bevel accents
  for Characters (outer/model frames, active tabs and Item Rating).
  Keep the neutral window fill and existing checkbox/radio visuals.
  Core 0.2.8 / Characters 0.3.21 / ItemRating 0.7.1.
- [ ] Test button states, class accents when switching live/cached alts,
  and common/uncommon/rare/epic quality and quest glow in game.
  Inventory and bank remain on the legacy renderer; verify their palette
  colors before broader rollout.
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
