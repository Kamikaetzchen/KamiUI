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
