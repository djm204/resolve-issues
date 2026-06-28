# Agent Ramp-Up — resolve-issues

A Claude Code **plugin** that iterates open GitHub issues priority-first and triages,
plans, or fixes them.

## Layout
- `.claude-plugin/plugin.json` — plugin manifest.
- `.claude-plugin/marketplace.json` — marketplace manifest (single-plugin marketplace).
- `commands/resolve-issues.md` — the `/resolve-issues` slash command (orchestration prompt).
- `scripts/select-issues.sh` — fetch + priority-order open issues (JSON out). `--input` for tests.
- `scripts/codex-review-loop.sh` — detect/trigger/poll/classify the GitHub `@codex` loop. `--input` classify for tests.
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

## Conventions / gotchas
- Codex bot login is `chatgpt-codex-connector` (`[bot]` suffix tolerated). A clean pass is
  a **top-level issue comment** ("Didn't find any major issues"), not silence and not only
  inline comments — poll all three channels.
- `select-issues.sh` priority labels are case-insensitive: critical/p0, high/p1,
  medium/p2, low/p3; unlabeled sorts last (rank 99). Ties break by newest issue number.
