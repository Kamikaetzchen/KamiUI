# KamiUI_Timers

Compact 200 × 15px timer bars styled after the swing timers. The stack is
anchored above/left of `KamiUIPetFrame` and grows upwards. Layout settings are
under `UI.Layout.Timers`. Each **unit block** has a small
`Styles.Text.sectionTitle` heading above its native AuraContainer bars.
Spell name and countdown occupy the bar, without repeating the target name.

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
- Header visibility is based on **UnitExists**, not the number of visible
  auras: 12.1 specifically prohibits addons from extracting aura counts via
  `AuraContainer` frame sizes or show/hide hooks. A unit with no qualifying
  auras may still have an empty section heading. Newly available unit
  headings may be delayed until combat ends when they require layout changes.
- Aura duration is capped at 180s by the native `maxDuration` candidate
  filter. Up to six helpful or harmful aura bars per unit are allocated.
- Unit headers don't inspect or compare secret target names or GUIDs.
- This implementation has not been tested inside the WoW Forever client.
  Validate compact stacking, active nameplate sections, totem text, and
  combat restrictions in game before treating it as stable.
