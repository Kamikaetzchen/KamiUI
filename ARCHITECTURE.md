# KamiUI architecture

KamiUI targets WoW Forever (current TOC interface 16001; level cap 60).
It consists of a shared core and separate `KamiUI_*` addons. Consult
[MODULES.md](MODULES.md) and the actual TOC files for dependencies and load order.

## Core responsibilities

| Path under KamiUI/ | Responsibility |
| --- | --- |
| Core.lua | Shared utilities, safe API access, character profiles and databases |
| CharacterIdentity.lua | Player GUID lookup and legacy identity migration |
| Media.lua | Shared texture paths and media helpers |
| Palette.lua | Central semantic colors and opacity values |
| Styles.lua | Shared styling, dimensions and visual state metrics |
| Layout.lua | Central layout constants |
| Components/ | Reusable windows, tabs, buttons, inputs, item slots and other UI elements |
| Components/Metallic.lua | Opt-in metallic textures and anchored nine-/three-slice rendering |
| Events.lua | Shared event dispatch |
| Scheduler.lua | Deferred work and combat-safe scheduling |
| Modules.lua, Commands.lua | Module registration and command handling |

Feature addons should use the existing core APIs rather than reproduce them.
Read current implementations before extending them. Keep style, content,
layout and secure behavior separate.

## Character data

`KamiUIDB` is the shared SavedVariables database. Canonical per-character
identity is the complete player GUID, not realm/name. Forever can temporarily
hide realm names and restrict API values.

- Use `UI:GetCurrentCharacterKey()`; do not construct legacy keys manually.
- Legacy records migrate when their character logs in. Original records are
  backed up; ambiguity is deliberately not guessed. See
  [Characters README](KamiUI_Characters/README.md#character-identity-migration-core-025).
- Preserve valid bank snapshots separately from live bag snapshots.
- Read existing character/equipment/XP caches rather than duplicating them.
- Offline data are snapshots, not live server data. Rested XP is an estimate;
  do not present estimated values as authoritative.
- Unknown or inaccessible data must not silently overwrite valid snapshots.

## WoW Forever runtime constraints

- Forever uses modern client APIs (including C_Item, C_Container and
  C_TooltipInfo), but verify the actual supported signatures and events.
- Check `UI:CanAccessValue()` / `UI:SafeCall()` as appropriate before
  comparing, formatting or calculating with potentially secret API values.
- Respect combat lockdown, protected actions and taint restrictions.
  Use the existing keyed `UI:RunOutOfCombat()` scheduler for deferred changes;
  re-evaluate current state rather than replay stale requests.
- Preserve secure button actions, bindings, native cooldowns and existing
  gameplay interactions when changing visuals.
- Avoid frequent full rescans or texture allocation in hot paths; reuse
  cached data and widgets, and refresh on appropriate events.
- Keep account-wide and character-specific settings separate.

## Validation

Check changed Lua and TOC load order, dependencies, saved-data compatibility,
and relevant normal/combat/offline cases. Use available syntax/static checks
and tests; explicitly distinguish those from actual in-game verification.
The owner tests the addon in the Forever client. Retain existing behavior
unless changing it is the requested task.
