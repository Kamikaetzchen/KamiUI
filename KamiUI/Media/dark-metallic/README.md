# Dark metallic UI textures

32-bit straight-alpha RGBA, top-left origin. Atlas: 1024 x 512 with 54
regions. See atlas.json for exact rectangles, UVs and standalone textures.
Button and tab states share alpha geometry; button, bar and portrait
interiors are transparent. Grayscale fills are rectangular and horizontally
uniform. Use standalone bar fills for SetStatusBarTexture and
SetStatusBarColor. Bar cap slices are 32 pixels wide.

Panel, tooltip and action_outer are 96 x 96 logical frames divided into
equal 32 x 32 tiles; standalone complete frames are padded to 128 x 128
(UV 0..0.75). Slice boundaries are 0, 0.25, 0.5, 0.75. Keep corners fixed
and stretch or tile edges and center separately. Use separate ornament
overlays. Clamp atlas UVs; use standalone textures for tiling.

The revised panel and tooltip center regions are semi-transparent (alpha
140 and 184 respectively per atlas.json); action_outer has a transparent
center. Keep legacy assets available during the metallic preview.

atlas.lua is metadata only, not loaded by the addon. The current opt-in
renderer uses standalone textures via KamiUI/Media.lua and
KamiUI/Components/Metallic.lua. The Characters preview has been tested
visually by the owner, including the thinner-border revision; other
module integrations are not yet verified. See [DESIGN.md](../../../DESIGN.md)
and [ROADMAP.md](../../../ROADMAP.md) for design rules and open tasks.

## Neutral runtime derivatives

The original 54-region atlas and original standalone artwork remain intact.
The preview now uses additional standalone derivatives (not atlas regions):
`neutral_button_normal` and `neutral_tab_*` preserve the original alpha
and geometry, with luminance-only RGB. `neutral_panel_frame`, `panel_fill`
and `panel_accent` are 128 x 128, with the same 96 x 96 logical area and
32px slices as the original panel. The fill is a white alpha silhouette of
the opening; its color and opacity come from the palette. The accent is
an independent inner-bevel mask. The metal frame remains neutral.

The revised normal button has a 4px straight border and 56 x 56 opening
with 6px inner chamfers (source coordinates). `item_mask.tga` and
`item_rarity_glow.tga` are 64 x 64 standalone RGBA textures aligned to
that opening, scaled to the icon bounds. The glow fades inward and is
white for runtime rarity/quest tint. The original square glow remains
for legacy slots and for clients without the mask API. In-game validation
of mask sampling, layering and tint is pending.

## Text buttons and class accents

The dedicated `text_button_{normal,hovered,pressed,disabled}.tga` textures
are 128 x 32 with 16px caps and matching alpha geometry. The 3px source
bevel and 6px chamfers are deliberately thinner/smaller than window art.
`text_button_accent.tga` and `tab_accent.tga` are separate 128 x 32
white alpha masks, using the same three-slice UVs as their base art.
They tint only bevels, not text, fill, or the original metal highlights.
These standalone additions are not part of the original atlas.

## Direct frame tint (current renderer)

The previous panel, tab and text-button accent masks are retained but no
longer rendered. Panel and slot frame art is tinted directly. Each tab
and text-button state now has a matching `*_frame_*` and `*_fill_*`
standalone 128 x 32 TGA derived from the existing state by separating its
interior pixels from the bevel pixels using the original alpha values.
The two textures preserve original pixel RGB and alpha at source-pixel
centers, with the same cap/UV geometry; only the frame receives the tint.
The fill stays neutral. Check filtering at actual UI scale in game.

The text-button frame/fill derivatives now use stronger raised lighting:
bright top, dark lower face, increased rim contrast, and inverted pressed
lighting. Their source alpha partition and 128 x 32 geometry are unchanged.
The original text-button textures remain available for rollback.

Text-button frame/fill derivatives use horizontal UV boundaries
0, 0.125, 0.875, 1 and vertical boundaries 0, 0.25, 0.75, 1 in the
fixed-size nine-slice renderer. The 16 x 8 source caps map to 7 x 3.5
UI units, preserving the thin rim at different control heights.
No asset pixels or alpha are changed by this renderer update.
