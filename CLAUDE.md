# CLAUDE.md

Project guidance for Claude Code. The agent-agnostic guide is in `AGENTS.md` — read it.

@AGENTS.md

## Claude Code workflow (this repo's hooks enforce these)

- **Before implementation:** invoke the `task-start` skill (routes to dive-in, recovery, or
  a requirements interview, and writes a plan to `tasks/todo.md`).
- **Before declaring done:** invoke the `task-end` skill (quality gates, doc gates, and the
  Codex review loop on the PR).
- **Architectural decisions** get an ADR in `docs/adr/NNN-name.md`, linked from
  `docs/AGENT_RAMP_UP.md`.
- **Codex review loop:** prefer the `codex-review:codex-review-loop` skill (from the
  `codex-review` dependency); it owns the mechanics. Fall back to an inline bounded
  `@codex review` loop only if that skill is unavailable.

## Quick facts

- This is a plugin definition; there's no app to run. Tests: `bash tests/run.sh`.
- One PR per issue in fix mode. Sequential by default; `--parallel [N]` for worktrees.
- Bump `plugin.json` `version` on any behavior change.
