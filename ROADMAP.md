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
- [x] Replace the separate accent overlay with direct grayscale frame
  tinting after the owner found the Hunter accents too subtle. Split
  tab/button frame and fill without changing the original pixel values.
  Apply the same class tint to all metallic Characters frames, including
  empty equipment slots and inactive tabs. Keep old assets for rollback.
  Core 0.2.9 / Characters 0.3.22 / ItemRating 0.7.2.
- [x] Owner approved direct class tint on the Hunter screenshot.
- [x] Add raised text-button lighting, metallic class-tinted close button
  and chamfered character dropdown icon. Report missing rating profiles
  explicitly instead of silently ignoring Item Rating on unsupported
  classes. Core 0.2.10 / Characters 0.3.23 / ItemRating 0.7.3.
- [x] Owner approved raised text buttons, close button and character
  selector in the Characters preview.
- [x] Extend metallic windows, controls and slots to Bags, Bank and Account.
  Inventory uses purple, bank green, account neutral. Keep bag-family
  distinctions using normalized RGB frame tints; preserve native actions,
  search dimming, sorting, cached data and checkbox styling.
  Core 0.2.11 / Bags 0.2.2 / Account 0.2.3.
- [x] Refine inventory after the first screenshot: tint raised button
  faces at 70% of the frame tint (shared, no new artwork) and reduce
  Bags/Bank slot spacing from 3 to 2 UI pixels, including bag bars.
  Core 0.2.12 / Bags 0.2.3 / Characters 0.3.24 / ItemRating 0.7.4.
- [x] Anchor inventory and bank to their top edge so opening/closing
  the bag bar does not move the header. Migrate existing center offsets
  after the first real layout; preserve drag and reset behavior.
  Core 0.2.13 / Bags 0.2.4. Owner confirmed cached bank and inventory
  after moving the inventory once. The later clamp/reanchor change and
  combat deferral (0273921) caused a reported combat toggle regression
  and were reverted at the owner's request. Keep the original TOP anchor
  and full-window clamping; Core 0.2.15 / Bags 0.2.6. Retest combat
  toggling, dragging, reload and screen-edge behavior.
- [ ] Test Bags/Bank live and cached, including drag/drop, sorting, search,
  bag-family colors, quest/rarity glow, cooldowns and combat updates.
  Test both Account tabs and existing XP bars. The native bank purchase
  button, search inputs and popup menu surfaces remain unchanged for now.
- [ ] Test Item Rating on Hunter and Druid, class tint on cached alts,
  and additional item quality and quest glow states in Characters.
- [x] Extend the metallic theme to Professions overview and crafting:
  neutral window, gold primary profession cards, framed profession
  icons/abilities and recipe output/reagent slots, raised buttons,
  character selector and close/unlearn buttons. Professions 0.3.2.
- [x] Guard native ProfessionsFrame closing after the owner reported
  ADDON_ACTION_BLOCKED in combat. Defer only the native backend close,
  keep custom window closing immediate, and cancel stale close requests
  when reopening. Professions 0.3.3.
- [x] Owner approved the Professions preview but noted thick raised
  button rims compared with the character selector. Use fixed-size
  nine-slice caps for shared text/close buttons and increase unlearn
  insets from two to four UI pixels. Core 0.2.16 / Professions 0.3.4.
- [x] Owner approved the thinner button rims. Add matching metallic
  input frames with flat dark fill for Professions search and quantity,
  and equalize header control insets. Core 0.2.17 / Professions 0.3.5.
- [ ] Test current and cached profession overview, ability use/drag,
  recipe selection, quantities, craft actions and unlearn confirmation.
  Verify closing via X/Escape in combat and reopening before combat ends.
  Keep progress bars, list rows and checkbox styling. Test input focus.
- [x] Owner approved Professions metallic inputs and header alignment.
- [x] Replace InfoPanel's old line/strip trapezoid with a gold metallic
  downward-facing tab: larger 45-degree chamfers and straight sides,
  preserving the height, transparency and content. Core 0.2.18 /
  InfoPanel 0.1.6. Owner approved the shape and requested an open top
  edge. Remove only the screen-facing rim and extend the fill to the
  screen boundary (Core 0.2.19 / InfoPanel 0.1.7).
- [x] Standardize header controls in Bags/Bank, Characters, Professions
  and Account: fixed 22px height, equal top/side inset, shared cached
  snapshot clock indicator for character-specific windows. Compact
  Professions overview and preserve crafting skill rank in one title.
  Metallic header search in Bags/Bank. Core 0.2.20 / Bags 0.2.7 /
  Characters 0.3.25 / Professions 0.3.6 / Account 0.2.4.
- [x] Reset Professions to the current character on window close, like
  Bags/Characters. Clear cached profession and selected recipe state;
  preserve the protected backend close handling. Professions 0.3.7.
- [x] Extend metallic controls to Targets macro panel, DamageMeter
  and details, ThreatMeter title, ObjectiveTracker buttons, and Chat
  tabs. Preserve meter bar colors, row geometry and macro behavior.
- [x] Extend metallic artwork to loot, tooltip, map breadcrumbs and
  native map controls, quest list/detail and NPC quest panels. Keep
  native map geometry and callbacks; verify pooled navigation and
  maximize/minimize in Forever. Reward icon styling remains a separate
  native-control check.
- [x] Trial the current player's class tint on the newly converted
  modules instead of neutral gray. Preserve semantic meter/reset/item
  colors, existing alpha and inventory/bank tints; await visual feedback.
- [ ] Owner deferred ActionBars, Minimap, UnitFrames, XPBar, Timers,
  SwingTimer, Auras, Cooldowns, Nameplates and RadialMenu pending a
  separate design pass. Preserve current appearance.
- [ ] Expand to other modules incrementally: ActionBars, tooltips,
  unitframes/statusbars/castbars and remaining controls.
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

## Character identity cleanup

- [x] Owner reports all characters logged in after GUID migration.
  Retire automatic legacy merges, retain existing backups and GUID cache.
  Hide realm suffixes in character dropdowns and InfoPanel rested/gold
  tooltips; shared roster sort no longer groups by realm. No realm filter.
  Core 0.2.23 / InfoPanel 0.1.8.

- [x] Context-sensitive tooltip rims: displayed player class, NPC
  reaction, item quality; separate dark fill and reset on clear/hide.
  Core 0.2.24 / Tooltips 0.2.29.
