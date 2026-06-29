# Agent Ramp-Up — resolve-issues

A Claude Code **plugin** that iterates open GitHub issues priority-first and triages,
plans, or fixes them.

## Layout
- `.claude-plugin/plugin.json` — plugin manifest.
- `.claude-plugin/marketplace.json` — marketplace manifest (single-plugin marketplace).
- `commands/resolve-issues.md` — the `/resolve-issues` slash command (orchestration prompt).
- `scripts/select-issues.sh` — fetch + priority-order open issues (JSON out). `--input` for tests.
- Codex review loop — **not in this repo**. Provided by the `codex-review` plugin (declared
  as a dependency in `plugin.json`, auto-installed). Fix mode invokes its `codex-review-loop`
  skill. See ADR-004.
- `tests/run.sh` + `tests/fixtures/` — dependency-free tests for the script logic.
- `docs/adr/` — architecture decision records.

## How it fits together
`/resolve-issues [triage|plan|fix]` → runs `select-issues.sh` → processes each issue in
priority order. In `fix` mode: one branch + PR per issue (sequential, or parallel via
worktree subagents, `--parallel [N]`, N default 10), then the codex review loop per PR.

## Run the tests
```bash
bash tests/run.sh
```

## Active Decisions
- [ADR-001](adr/001-command-surface.md) — single command with a mode argument.
- [ADR-002](adr/002-fix-execution-model.md) — one PR per issue; sequential or parallel worktrees.
- [ADR-003](adr/003-codex-review-loop.md) — codex review loop integration (3-channel polling, terminal clean signal).
- [ADR-004](adr/004-consume-codex-review-plugin.md) — consume the loop from the `codex-review` plugin dependency (kills the duplicate script).

## Conventions / gotchas
- The Codex loop mechanics and their gotchas (bot login `chatgpt-codex-connector`, the
  terminal top-level "no major issues" issue-comment signal, three-channel polling,
  tri-state availability detection) now live in the `codex-review` plugin's
  `codex-review-loop` skill — see that skill, not this repo.
- `select-issues.sh` priority labels are case-insensitive: critical/p0, high/p1,
  medium/p2, low/p3; unlabeled sorts last (rank 99). Ties break by newest issue number.
