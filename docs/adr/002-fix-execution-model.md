# ADR-002: Fix execution model — one PR per issue, sequential or parallel worktrees

## Status
Accepted

## Context
Fix mode resolves multiple issues in one invocation. Two pressures conflict: strict
separation of concerns (each issue's change must be reviewable in isolation) and
throughput (many issues should not have to be fixed strictly one-after-another). Running
multiple fixes in the same working tree at once would interleave unrelated changes and
break isolation.

## Decision
- **One PR per issue.** Each issue gets its own branch, commit(s), and pull request,
  linked back to the issue. No issue's changes leak into another's PR.
- **Two execution modes:**
  - `sequential` (default): resolve issues one at a time in the main working tree.
    Simplest, easiest to follow, safest.
  - `parallel` (`--parallel [N]`): dispatch one subagent per issue, each operating in
    its **own git worktree** so concurrent edits never collide. Concurrency is capped at
    N, **default 10**.
- Branch naming: `resolve/issue-<number>-<slug>`.
- After a PR is opened, control passes to the codex review loop (see ADR-003).

## Consequences
- Easier: isolated, independently reviewable/mergeable PRs; parallel mode scales
  throughput without sacrificing isolation (worktrees give each agent a clean checkout).
- Easier: sequential default keeps the common case legible and low-risk.
- Harder: worktree lifecycle (create, run, prune) and per-agent branch hygiene must be
  managed; failures in one parallel agent must not abort the others.
- Trade-off: parallel mode consumes more compute and local disk (one worktree per
  concurrent issue) — acceptable and bounded by N.
