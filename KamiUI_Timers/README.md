# KamiUI_Timers

Compact 200 × 15px timer bars styled after the swing timers. The stack is
anchored above/left of `KamiUIPetFrame` and grows upwards. Layout settings
are in `UI.Layout.Timers`.

Each **visible** aura button carries its unit name in a **right-aligned,
golden `sectionTitle` label immediately to the left** of the 200px bar.
Inside the bar: aura icon, spell name and remaining time. Totem rows use
the same external label, displaying "Totem".

- Unit labels use `UNIT_WIDTH=90`, `UNIT_GAP=5`.
- No separate section headers: a unit without matching auras does not show
  a title, and there are no "first visible button" assumptions.
- Blizzard owns native aura sorting and secure countdowns; the labels follow
  the buttons when the aura order changes.
- The per-unit `AuraContainer` frames are still chained to grow upwards.

## Sources and duplicate policy

The safe, deterministic way to avoid duplicate effects across unit tokens is
to give each effect type **one unit family**:

- Player + party1–4: **HELPFUL|PLAYER** (self buffs such as Battle Shout,
  HoTs cast by the player or pet).
- nameplate1–8: **HARMFUL|PLAYER** (DoTs on separate visible nameplate units).
- Totems: up to four independent totem slots using Blizzard DurationObject
  where available, with readable `GetTotemInfo` fallback.

Target, focus and boss tokens are **not** also scanned. A unit targeted and
represented by a nameplate therefore does not appear a second time; no GUID
comparisons or secret aura inspection are performed in combat.

## Important limitations

- Enemy nameplates must be enabled. Enemy effects without a nameplate (for
  example, an off-screen enemy or a boss without a nameplate) are not covered.
  The tracker does not persist vanished units by GUID.
- Unit names are forwarded directly to FontStrings, without attempting to
  inspect or compare potentially secret unit names.
- The name is intentionally repeated alongside every visible aura row of a
  unit; a group with no active auras has no displayed name, although the
  1px native container baseline may leave a small residual gap.
- Aura duration is capped at 180s by the native `maxDuration` candidate
  filter. Up to six helpful or harmful aura bars per unit are allocated.
- This implementation has not been tested inside the WoW Forever client.
  Validate label placement, combat updates, native unit visibility, stacking,
  and totem durations in game before considering it stable.
