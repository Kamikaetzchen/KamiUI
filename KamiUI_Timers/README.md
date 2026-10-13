# KamiUI_Timers

Compact 200 × 12px visible timer bars styled after the swing timers. Each
native timer row is 14px tall, with 1px of transparent padding above and
below the bar and icon. The stack is anchored above/left of
`KamiUIPetFrame` and grows upwards. Layout settings are in
`UI.Layout.Timers`.

Each **visible** aura button carries its unit name in a **right-aligned,
golden `sectionTitle` label immediately to the left** of the 200px bar.
Inside the bar: aura icon, spell name and remaining time. Totem rows use
the same external label, displaying "Totem".

- Unit labels use `UNIT_WIDTH=90`, `UNIT_GAP=5`.
- Within-unit element spacing is 0px (the row padding makes a visible 2px
  gap). Between native unit containers there is an extra 2px gap, resulting
  in a nominal 4px separation between visible groups. Empty native groups
  still occupy space, but their additional gap is halved.
- No separate section headers: a unit without matching auras does not show
  a title, and there are no "first visible button" assumptions.
- Blizzard owns native aura sorting and secure countdowns; the labels follow
  the buttons when the aura order changes.
- The per-unit `AuraContainer` frames are still chained to grow upwards.
- The number of pre-created enemy slots is controlled by
  `UI.Layout.Timers.MAX_NAMEPLATES` (currently 40).

## Sources and duplicate policy

The safe, deterministic way to avoid duplicate effects across unit tokens is
to give each effect type **one unit family**:

- Player + party1–4: **HELPFUL|PLAYER** (self buffs such as Battle Shout,
  HoTs cast by the player or pet).
- nameplate1–40: **HARMFUL|PLAYER** (DoTs on separate visible nameplate units).
- Totems: up to four independent totem slots using Blizzard DurationObject
  where available, with readable `GetTotemInfo` fallback.

Target, focus and boss tokens are **not** also scanned. A unit targeted and
represented by a nameplate therefore does not appear a second time; no GUID
comparisons or secret aura inspection are performed in combat.

## Important limitations

- Enemy nameplates must be enabled. Enemy effects without a nameplate (for
  example, an off-screen enemy or a boss without a nameplate) are not covered.
  The tracker does not persist vanished units by GUID.
- Unit names are forwarded directly to FontStrings without inspecting or
  comparing potentially secret names. Some aura-owned FontStrings may become
  forbidden in combat; best-effort updates skip rejected writes.
- The name is intentionally repeated alongside every visible aura row of a
  unit. Empty native containers still contribute their 2px group gap
  even without visible bars; raising the slot limit can increase blank space.
  The 1px native baseline is compensated in the anchor chain.
- Aura duration is capped at 180s by the native `maxDuration` candidate
  filter. Up to six helpful or harmful aura bars per unit are allocated.
- Basic self-buff and multi-nameplate combat display has been tested ingame;
  high-count add spawns, unit-token reuse, group HoTs and totems still require
  dedicated testing.
