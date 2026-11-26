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
Keep window and slot fills, text, opacity and rarity/quest glows independent.
Raised text-button faces inherit a gentler tint from their frames.
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

### Raised text buttons

Keep thin chamfered rims, but give text buttons a brighter upper face,
a darker lower face and a stronger bevel so they look physically raised.
Hover brightens the face; pressed reverses the vertical lighting to look
recessed. Preserve the geometry and alpha. Apply the frame's RGB tint
also to the face, blended 70% toward that tint from white via
`Palette.buttonFillTintStrength`. Neutral controls remain neutral.
Use the shared metallic button style for the Characters close button;
the character selector uses the existing masked icon frame. Leave
checkboxes unchanged.

### Inventory, bank and account rollout

Reuse the approved metallic panel, raised text buttons, close button,
icon mask, item slot and tab components without new textures. Inventory
and Bank keep their semantic purple/green backgrounds and frame tints;
special bag families override the normal slot tint using normalized
versions of the existing family colors. Account uses neutral outer
window, tab and close-button frames with a neutral translucent fill.
Only individual character rows use class tints. Preserve native item
interactions, cached snapshots, search dimming, XP bars and
checkboxes. Search inputs, popup surfaces and native bank purchases are
outside this first rollout.

### Professions rollout

Use a neutral metallic window and recipe-list panel. Preserve the gold
primary-profession card hierarchy with the existing gold palette, reuse
masked slot artwork for profession icons, abilities, reagents and recipe
results, and use shared raised buttons. Keep existing recipe row behavior,
progress bars and tracking checkbox unchanged.

Text buttons use fixed-size nine-slice caps on the existing 128 x 32
artwork, rather than scaling the rim with control height. A three-pixel
source bevel is approximately 1.31 UI pixels at the shared 7/16 scale.
Keep the frame and fill slice geometry identical; tabs retain their
separate three-slice renderer. Preserve the existing button lighting,
state textures and tint behavior. Inset unlearn buttons four UI pixels
from the overview card's top-right corner.

Metallic edit boxes reuse the exact normal text-button rim and fixed
nine-slice geometry, with a separate flat interior mask tinted using
the existing dark input background color and alpha. Do not apply the
raised face or hover/pressed states to inputs. The Professions search
and quantity fields opt in first. Header controls use equal top and
side insets, with matching 22 x 22 character and close buttons.

### InfoPanel rollout

The top-screen InfoPanel is a wide downward-facing metallic tab. Keep
its existing height, approximately the same total width, text layout
and dark translucent fill. Replace the full-height 60-degree sloping
sides with larger 45-degree chamfers on the lower corners and straight
sides above them. Use a warm gold runtime frame tint and independent
flat fill. Derive the neutral artwork from the existing tab bevel;
stretch only the center. Leave the screen-facing top edge open: the
metal rim covers only the sides, chamfers and lower edge, while the
translucent fill extends to the screen boundary.

### Shared window header controls

Keep header height independent of action size. Use 22 x 22 UI-unit
icon/close buttons, text buttons of the same height, 3 units inset
from the header (4 from the default outer window edge), and 4 units
between actions. Anchor actions at the upper corners rather than
centering vertically in tall headers. Use the same small clock glyph
with a tooltip to identify cached character views, including the
current character's offline bank. Keep Characters level/class subtitle;
Professions uses one title line and removes redundant overview labels.
Preserve the skill rank and character name in the crafting title.

### Compact and native windows

Use the metallic style for Targets, meter controls, objective tracker
buttons, chat tabs, loot slots, tooltips and map/quest chrome. Keep compact
HUD control sizes and existing meter bar geometry. Preserve native map
and quest actions, anchors, resize grips, and pooled navigation. Use
mouse-transparent art for native map close/maximize/minimize controls;
apply new native skin layout outside combat. The owner deferred the
Minimap, action bars, unit frames, XP bar, timers, auras, nameplates and
radial menu until a separate design round.

### Class tint experiment

Try the logged-in player's class tint on the newly converted compact
HUD and native windows: Targets, DamageMeter, ThreatMeter, Objective
Tracker, Chat tabs, World Map, quest panels, loot and tooltips. Preserve
semantic action colors (red reset and close glyphs), class/quality
colors in data displays, existing background alpha, and inventory/bank
semantic tints. The existing tooltip art is combined, so its dark fill
receives the same RGB multiplier. Centralize the experimental tint
through Palette:GetPlayerClassTint for easy adjustment after feedback.

### Context-sensitive tooltip tint

Use the displayed player's class color, including opposing players;
for NPCs use reaction (friendly green, neutral yellow, hostile red).
For item tooltips use native item quality colors. If unit or item
information is unavailable, use neutral metal; other tooltip types
retain the logged-in class tint. Reset on clear/hide. Only tint the
separate grayscale rim, not the dark translucent fill. Use the existing
unit/item post-processing hooks without rebuilding Blizzard tooltips.

### Window spacing

Use six UI pixels from the outer window edge for shared header controls
and primary content, six between the header and content, and six for
nested panel padding where practical. Preserve existing slot dimensions
and gaps (Bags/Bank 2, Character/Account 3). Fixed grids, reserved footer
and scrollbar areas, equipment weapon/checkbox layout and compact HUD
layouts retain their functional geometry rather than forcing every
internal element to the outer inset.

The Account character table uses class-colored names instead of a separate
class column. Show up to two primary profession icons followed by
Cooking, First Aid and Fishing in fixed positions, with cached skill
values and direct links to the existing profession window. The wider
676 UI-pixel Account window also accommodates a 17-column item grid.
A sortable iLvl column between XP and Gold displays the last
measured equipped item level. Its tooltip lists named equipment sets
with right-aligned last measured values, equipped sets in green, and
unknown values as --. Do not repeat the equipped item level in the
tooltip; exclude the naked set.
Group parent/child skill lines to avoid duplicate icons; the professions
column is not sortable. Place Professions last, after Gold.

Account XP bars use the shared purple experience and blue rested colors,
with a 3 UI-pixel height. Reuse the InfoPanel's Well Rested-adjusted offline
projection through its optional public per-character query. Unknown or
mismatched snapshots remain unknown; the current character has a live API
fallback. Keep full rested amounts in tooltips even when the bar is capped
at the next level. The bar spans Character through Gold and ends before
Professions. Use an opaque light gray track (RGB 0.65/0.65/0.67)
so the unfilled portion is visible against the window. Center the 32-unit
profession icons vertically in their own column, with three-unit gaps,
nine units of right inset and 15 units between Gold and the first icon.
Show current/maximum skill inside each icon with an outlined,
size-adjusted label. Preserve
row height and icon geometry for max-level characters.

Account numeric columns center fixed-width number blocks (Level two
digits, XP three digits plus percent, iLvl three digits plus one decimal).
Integer portions are right aligned and suffixes have a fixed anchor.
Keep names left aligned and money right aligned. Read the current
character's equipped item level directly for rendering and sorting;
offline characters continue to use their last saved snapshot. Refresh
visible character rows on equipment events and after deferred capture.

Account character rows use individual flat metallic frames with the
displayed character's class tint at the shared class-tint strength and
a neutral translucent fill, reusing the fixed-cap text-button rim and
input fill. Refresh the tint whenever rows are populated or reused;
unknown classes fall back to neutral. Keep profession and item slots
neutral, the close glyph red and the XP/rested colors unchanged. Keep
the existing hover effect within the chamfered fill. After owner feedback, remove the header separator,
increase the row pitch to 43 units (two-unit gap) and inset the gold
amount three more units from the right. Preserve the 41-unit row height,
32-unit profession icons, shortened XP bars, window size, ten visible
rows and mouse-wheel scrolling without a scrollbar or page buttons.
The frame remains visible at max level. Revised appearance pending
in-game feedback.
