# KamiUI — contributor and agent instructions

Read this file before working on the repository. The repository is the
durable project context; do not depend on a previous chat being available.

## Start here

- [ARCHITECTURE.md](ARCHITECTURE.md): implementation boundaries and invariants.
- [DESIGN.md](DESIGN.md): UI design direction and rendering rules.
- [ROADMAP.md](ROADMAP.md): current state, open tasks and test status.
- [MODULES.md](MODULES.md): module overview.
- [Texture documentation](KamiUI/Media/dark-metallic/README.md): asset contract.
- Read the actual affected code and module README before changing it.
  Current code and explicit owner instructions take precedence over stale notes.

## Workflow

- Repository: `Kamikaetzchen/KamiUI`; normal target branch: `main`.
- When the owner asks to implement or commit a change, commit directly to
  `main`. Do not create pull requests or feature branches unless explicitly
  requested.
- Discussion, diagnosis, screenshots and design feedback alone are not
  permission to change files. Respect explicit requests to leave code alone.
- Inspect the latest branch head before writing. Preserve concurrent owner
  changes; never force-push, rewrite history or revert unrelated work.
- Prefer one atomic commit per coherent change (including its version bump
  and relevant documentation). Split genuinely independent changes.
- Verify the committed files and report the commit link, what changed, and
  any limitations. Never claim an in-game test that was not performed.
- If GitHub access temporarily fails, retry the connector before reporting
  the blocker. Keep blocker reports brief; do not offer manual patches
  unless the owner asks for them.
- Work in small, testable increments. The owner pulls and tests in WoW Forever.
- Update the relevant project documentation when decisions or test results
  change; mark unverified ideas as such. Do not turn the roadmap into a
  duplicate of the Git history or record personal/account-specific data.

## Commit convention

Use English Conventional Commits for all new agent-authored commits:

```text
<type>(<scope>): <imperative description>
```

Use lowercase type and scope, a concise imperative subject, ideally at most
72 characters, and no trailing period. Add an English body when the rationale,
migration, test limitations or tradeoffs need explanation.

| Type | Use |
| --- | --- |
| feat | New functionality |
| fix | Correct existing behavior |
| refactor | Internal restructuring without intended behavior changes |
| perf | Performance improvement |
| style | Visual-only styling changes |
| docs | Documentation-only changes |
| chore | Maintenance, packaging or version-only changes |
| test | Tests or test tooling |

Scope is the affected addon name without the `KamiUI_` prefix, in lowercase
without extra separators: `account`, `actionbars`, `characters`, `infopanel`,
`itemrating`, `unitframes`, `xpbar`, etc. Use `core` for cross-cutting core
logic, `components` for shared UI components, `media` for texture assets,
and `repo` for repository-wide documentation or tooling. Use the primary
scope for coherent cross-module changes; explain other affected modules in
the commit body.

Examples:

```text
fix(core): preserve character GUID during combat
feat(account): show character XP progress bars
style(characters): reduce metallic slot border thickness
fix(components): fit item icons to metallic slot interiors
chore(unitframes): bump version to 0.4.1
docs(repo): document project conventions and design roadmap
```

Do not rewrite older commits to conform to this convention.

## Versions and coding

- Preserve each module's own `.toc` version; bump affected runtime modules
  when changing their code or shipped behavior. Use patch for fixes/small
  styling changes, minor for new significant features, major for explicitly
  planned breaking changes. Documentation-only changes need no version bump.
- Keep Lua readable, with four-space indentation and roughly 80-character
  lines where practical. Follow surrounding conventions.
- Prefer existing shared APIs/components, localized fixes and event-driven
  updates. Avoid speculative rewrites, needless dependencies or duplicate
  code.
- Preserve SavedVariables and secure actions. Read ARCHITECTURE.md before
  changing identity, equipment, protected UI or event scheduling.
