# ADR-004: Consume the codex review loop from the codex-review plugin

## Status
Accepted (supersedes the implementation half of ADR-003)

## Context
ADR-003 introduced a codex review loop, implemented as a `scripts/codex-review-loop.sh`
helper bundled in this plugin. The same loop is useful well beyond resolving issues, so it
was extracted into a standalone, reusable Claude Code plugin, `codex-review`, exposing a
`codex-review-loop` skill plus the script. That left two byte-identical copies of the
script (here and in `codex-review`) kept in sync by hand — guaranteed drift.

## Decision
Delete this plugin's copy of the codex loop and **consume the `codex-review` plugin as a
dependency** instead.

- `.claude-plugin/plugin.json` declares a dependency:
  `"dependencies": [{ "name": "codex-review", "marketplace": "codex-review" }]`.
  Installing `resolve-issues` auto-installs `codex-review`.
- Because the two plugins live in different marketplaces, the root marketplace
  (`.claude-plugin/marketplace.json`) opts in with
  `"allowCrossMarketplaceDependenciesOn": ["codex-review"]` — Claude Code blocks
  cross-marketplace dependencies otherwise.
- The `/resolve-issues` command no longer shells out to a local script for the loop; in fix
  mode it **invokes the `codex-review-loop` skill** to drive the review on each PR, and
  retains only the judgement (is a finding real, how to fix it) and a brief fallback for
  when the skill is absent.
- `scripts/codex-review-loop.sh` and its tests/fixtures are removed from this repo; that
  logic and its tests now live in `codex-review`.

## Consequences
- Easier: one source of truth for the loop mechanics — no more hand-syncing two copies;
  fixes/updates to the loop reach every consumer through normal plugin updates.
- Easier: other projects can use the same loop by depending on `codex-review`.
- Harder: `resolve-issues` now has an install-time dependency and a cross-marketplace trust
  opt-in; the loop only runs where `codex-review` resolves (its marketplace must be
  reachable). The command keeps an inline `@codex review` fallback to degrade gracefully.
- Trade-off: a version was intentionally left unpinned (tracks the marketplace's latest)
  until `codex-review` tags releases (`{name}--v{version}`); pin with a semver range then.
