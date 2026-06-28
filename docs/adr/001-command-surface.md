# ADR-001: Single command with a mode argument

## Status
Accepted

## Context
The plugin needs to expose three related behaviors over a list of GitHub issues:
triage (label/classify/route), plan (produce an approach), and fix (implement and
ship). These could be three separate slash commands or one command parameterized by
a mode argument. The three behaviors share the same front half — select and
priority-order open issues via `scripts/select-issues.sh` — and differ only in what
they do per issue.

## Decision
Expose **one command**, `/resolve-issues [triage|plan|fix]`. The mode is a positional
argument; default is `triage` (the safest, read-mostly behavior). Fix mode takes
additional flags: `--parallel [N]` (worktree subagent per issue, N defaults to 10)
and standard selection passthrough (`--issue`, `--label`, `--max`, `--repo`).

## Consequences
- Easier: one entry point, one place for shared selection logic, less duplicated docs.
- Easier: a safe default (`triage`) means an argument-less invocation can't mutate code
  or open PRs.
- Harder: discoverability of the sub-modes relies on the command's `argument-hint` and
  body rather than three named commands in the palette.
- Trade-off: a single file grows larger. Mitigated by pushing the codex polling logic
  into `scripts/codex-review-loop.sh` so the command body stays orchestration-only.
