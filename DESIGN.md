# KamiUI design direction

## Goals

A coherent dark-metallic fantasy MMORPG interface: polished dark gunmetal,
thin silver bevels, crisp angular/chamfered corners, restrained highlights.
Avoid chunky sci-fi outlines, flat blue panels, heavy neon glow and opaque
windows. Optimize for actual in-game sizes rather than an enlarged concept.

Use the same material language throughout the UI, but preserve visual
hierarchy. Window outlines may be a little stronger than inner panels;
slot borders should not overpower item icons. Active states should be
clear without thicker geometry.

The first in-game Characters preview had visibly heavy 8–9 px borders
(measured by the owner on the screenshot) and lost panel transparency.
The revised thin-border assets look substantially more elegant to the
owner. Aim for about 4–5 visible screen pixels at the tested scale, with
lighter inner borders; this is a visual target, not a fixed source-pixel
width or a guarantee at every UI scale.

## Color and alpha

Keep material textures neutral grayscale/gunmetal wherever practical.
Colors belong in `Palette.lua` and are applied with `SetVertexColor()`
or `SetStatusBarColor()`, not separate baked-color variants for every
window. Preserve the existing semantic palette: neutral windows, purple
inventory, green bank, and existing item-quality/quest colors.

Use independent neutral grayscale frame and translucent fill layers.
Tint the metal itself with RGB multiplication at full alpha; source pixel
luminance determines the visible brightness, including tinted reflections.
The owner found separate accent overlays too subtle and inconsistent.
Do not add a colored bevel overlay on top of the base metal. Retain the
old assets for rollback, but leave them unused in the current renderer.
Characters uses the viewed character's class color on all metallic
frames: outer window, model, equipment slots, all tabs and text buttons.
Keep the neutral fill, text, opacity and rarity/quest glows independent.
Use one central class tint strength (RGB blend with white, not alpha).

## Modular assets and rendering

The shared kit lives in `KamiUI/Media/dark-metallic/`. See its README
and atlas metadata for dimensions, UVs and alpha conventions.

- Use reusable nine-slice panels and three-slice horizontal controls.
  Keep corner/cap geometry fixed and stretch or tile only suitable edges.
  Do not sample transparent padding beyond the logical asset bounds.
- Use dedicated thin, chamfered three-slice text-button artwork for all
  button states; do not stretch square item slots or full window frames.
  Reuse suitable controls for dropdowns and inputs before adding assets.
  Keep checkbox/radio styling unchanged for now. Keep ornaments separate.
- Keep all states of an asset geometrically consistent. Vary lighting,
  tint and opacity, not dimensions.
- Separate empty statusbar borders, neutral backgrounds and rectangular
  grayscale fills; use runtime colors and values. No baked progress,
  text, icons or cooldown overlays.
- Keep icon masks and rarity/quest overlays congruent with chamfered
  slot interiors. Icons should fill the usable interior rather than
  leaving excessive empty padding. Preserve the square legacy slot
  assets and behavior while the metallic variant is being tested.
- Keep original artwork and existing rendering paths available for
  rollback. Add distinct metallic assets when their geometry differs.

## Design iteration

Use existing style references and actual in-game screenshots. First
discuss a focused change and agree on technical constraints. Generate
art only where useful; use deterministic processing for exact pixel
geometry, alpha masks, slice boundaries and TGA export. Validate assets
and update their metadata together. A generated presentation sheet
alone is not a production atlas.

Integrate a small set at a time using shared Components, Styles, Media
and Palette. Test at the real UI scale; expand only once the preview
works. Avoid removing potentially redundant files until actual usage
and visual quality are established. Track current implementation and
open questions in [ROADMAP.md](ROADMAP.md).
