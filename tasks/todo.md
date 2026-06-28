# Plan — `/resolve-issues` command

## Goal
Implement the core slash command for the `resolve-issues` plugin: iterate open GitHub
issues priority-first and **triage**, **plan**, or **fix** them.

## Spec (from brainstorm)
- **Surface:** one command `/resolve-issues [triage|plan|fix]`, mode arg. Default `triage`.
- **Issue selection:** reuse `scripts/select-issues.sh` (priority-ordered, highest first).
- **Fix mode:**
  - Strict separation of concerns — **1 PR per issue**, iterate until all done.
  - Two execution modes:
    - `sequential` — one issue at a time (default for safety/clarity).
    - `parallel` — one subagent per issue in its own git worktree.
      Configurable max concurrency, **default 10**.
  - Each issue → branch + commit + PR (via `gh`), PR linked to the issue.
  - After PR open: **detect codex review loop**.
    - If available → trigger `@codex review`, poll, address findings, resolve, repeat
      until codex posts terminal "Didn't find any major issues".
    - If not available → report PR created so user can review manually.
  - Codex finding handling: for each comment, first **determine if it is a real issue**.
    If real → fix, push, leave a detailed comment explaining the fix, mark thread resolved.

## Phases

### Phase 0 — Decisions (ADRs)
- [x] ADR-001: command surface (single command + mode arg)
- [x] ADR-002: fix execution model (sequential vs parallel worktree subagents, 1 PR/issue)
- [x] ADR-003: codex review loop integration (detect / trigger / poll 3 channels / address / terminal signal)

### Phase 1 — Codex review loop helper (scripts)
- [x] `scripts/codex-review-loop.sh` — detect/trigger/poll/classify, `--input` for tests.
- [x] Tests + fixtures for the classifier (clean, findings, working, clean-wins, stdin)

### Phase 2 — The command
- [x] `commands/resolve-issues.md` — select → per-mode → fix orchestration → codex loop.

### Phase 3 — Tests for select-issues.sh
- [x] `tests/run.sh` + fixtures: priority order, ranks, --max, open-only.

### Phase 4 — Docs
- [x] `docs/AGENT_RAMP_UP.md` with Active Decisions linking ADRs
- [x] `README.md` — install + usage

### Phase 5 — Verify + baseline commit
- [x] tests 10/10, `bash -n` clean, all JSON valid
- [ ] Initial git commit (branch first — on default branch)

## Review
_(filled at task-end)_
