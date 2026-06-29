# AGENTS.md

Guidance for any AI agent working in this repository. (Claude Code reads `CLAUDE.md`, which
imports this file.)

## What this is

`resolve-issues` is a **Claude Code plugin**. It provides one slash command,
`/resolve-issues [triage|plan|fix]`, that iterates a repo's open GitHub issues
**highest-priority first** and triages, plans, or fixes them.

This repo is a plugin definition (manifests + a command + a script), **not** an application.
There is no build step and no runtime server.

Packaged for Claude Code, but portable: the logic is plain bash + markdown procedures. To
run it under a different agent, see **"Installing on other agents"** in `INSTALL.md`.

## Layout

| Path | Purpose |
|------|---------|
| `.claude-plugin/plugin.json` | Plugin manifest (incl. the `codex-review` dependency). |
| `.claude-plugin/marketplace.json` | Single-plugin marketplace + cross-marketplace allowlist. |
| `commands/resolve-issues.md` | The `/resolve-issues` command (orchestration prompt). |
| `scripts/select-issues.sh` | Fetch + priority-order open issues as JSON. `--input` for tests. |
| `tests/run.sh` + `tests/fixtures/` | Dependency-free tests for the script. |
| `docs/adr/` | Architecture Decision Records (read these before changing behavior). |
| `docs/AGENT_RAMP_UP.md` | Fuller onboarding / key-file map / active decisions. |
| `tasks/todo.md`, `tasks/lessons.md` | Working plan and accumulated lessons. |

## How it works

`/resolve-issues` runs `select-issues.sh` to get priority-ordered issues, then per mode:
- **triage** (default, read-mostly): classify, suggest labels/routing, apply after confirm.
- **plan**: investigate and write an approach per issue; no code changes.
- **fix**: implement + ship per issue — **one branch + PR per issue** (sequential by
  default; `--parallel [N]` runs one worktree subagent per issue, N=10). After each PR, the
  Codex review loop runs.

The Codex review loop is **not in this repo**. It lives in the separate
[`codex-review`](https://github.com/djm204/codex-review) plugin, declared as a dependency
and auto-installed. Fix mode invokes its `codex-review:codex-review-loop` skill. See ADR-004.

## Build / test / run

```bash
bash tests/run.sh                 # the only test suite (dependency-free; needs jq)
claude plugin validate ./ --strict   # validate the manifests (if the claude CLI is present)
```

Runtime requirements for the command itself: authenticated [`gh`](https://cli.github.com/),
`jq`, and (for the Codex loop) the GitHub Codex connector on the target repo.

## Conventions

- **Priority labels** (`select-issues.sh`, case-insensitive): critical/p0 → high/p1 →
  medium/p2 → low/p3; unlabeled sorts last (rank 99); ties break by newest issue number.
- **One PR per issue** is an invariant in fix mode — never mix issues in a branch/PR.
- **Bump the plugin version** in `plugin.json` for any behavior change (pinned installs only
  update when the version field changes).
- **Reference bundled scripts** from the command via `${CLAUDE_PLUGIN_ROOT}/...`.
- **Shell**: scripts are `bash`, `set -euo pipefail`, and keep a pure (network-free) core
  reachable via `--input` so it stays testable. Add a test in `tests/` for any logic change.

## Working agreement

- Read the relevant `docs/adr/NNN-*.md` before changing behavior; record any new
  architectural decision as a new ADR and link it from `docs/AGENT_RAMP_UP.md`.
- Keep `docs/AGENT_RAMP_UP.md` current after structural changes.
- Branch for changes (don't commit to the default branch); open a PR.
- Run `bash tests/run.sh` and `claude plugin validate ./ --strict` before declaring done.
