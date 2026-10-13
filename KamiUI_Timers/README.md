# KamiUI_Timers

Compact 15px timer bars styled like the swing timers. Anchored above and to
the left of `KamiUIPetFrame`, growing upwards. Layout parameters are in
`KamiUI/Layout.lua` under `Timers`.

## Data sources

- **Totems:** Four totem slots via `GetTotemDuration` (native secret-safe
  DurationObject) where available, with readable `GetTotemInfo` fallback.
  The native duration drives the bar and its cooldown text.
- **Auras:** Blizzard 12.1 `AuraContainer` / `AuraButton` APIs. Each unit
  has its own group with up to six `HARMFUL|PLAYER` and six
  `HELPFUL|PLAYER` effects, filtered natively to 180 seconds or less.
  This includes player-applied DoTs/HoTs and short self buffs such as
  Battle Shout. The native client owns the bar progress and countdown text.

Affected unit name, effect name and remaining time appear on every aura bar.
The unit blocks are adjacent and automatically grow upwards with the bars.

Units monitored: player, target, focus, party1–4, nameplate1–8, boss1–5.

## Limitations

- These are **live unit-token bindings**, not a historical per-GUID combat-log
  tracker. Targets that leave all monitored unit tokens cannot retain an
  independently verified countdown. A mob appearing as both target and
  nameplate may be duplicated; GUID de-duplication under secret identity
  restrictions needs an ingame-tested solution.
- Only player/pet-applied auras with native filter-compatible durations are
  displayed. There is no attempt to parse secret aura payloads in combat or
  predict expiration from an assumed spell duration.
- Auras longer than 180 seconds are deliberately excluded. The cap, bar
  width and offset can be adjusted in `Layout.Timers`.
- No WoW client is available in the repository environment. Test addon loading,
  combat behavior and native duration text in WoW Forever before considering
  this production-ready.
