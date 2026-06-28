---
description: Iterate open GitHub issues priority-first and triage, plan, or fix them — one PR per issue, optional parallel worktrees, codex review loop.
argument-hint: "[triage|plan|fix] [--parallel [N]] [--issue N] [--label L] [--max N] [--repo OWNER/NAME]"
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Task, TodoWrite
---

# Resolve Issues

You are resolving open GitHub issues for the current repository, **highest priority
first**. Arguments: `$ARGUMENTS`

## 0. Parse arguments

- **mode** = first positional word: `triage` | `plan` | `fix`. Default `triage`.
- **--parallel [N]** = fix mode only. Enables parallel worktree execution; `N` is max
  concurrency, **default 10** when `--parallel` is given without a number. Absent ⇒
  sequential.
- Selection passthrough → forwarded verbatim to the selection script: `--issue N`,
  `--label L`, `--max N`, `--repo OWNER/NAME`.

If the mode word is unrecognized, stop and show the usage from `argument-hint`.

## 1. Select issues (all modes)

Run the selection helper and read its JSON (priority-ordered, highest first):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/select-issues.sh" [selection passthrough flags]
```

Each element has the gh issue fields plus `priorityRank` (0=critical … 3=low,
99=unprioritized). Process in array order. If empty, report "no open issues" and stop.

Create a TodoWrite list with one item per selected issue so progress is visible.

## 2. Mode behavior

### `triage` (default, read-mostly)
For each issue: classify it. Determine type (bug/feature/question/docs), severity, and a
priority label if missing. Propose (do not force) label changes and routing. Summarize as
a table: `#`, title, current labels, suggested labels, one-line rationale. Apply label
changes with `gh issue edit` **only after** presenting the table — batch, then confirm.

### `plan`
For each issue: investigate the relevant code and write a concise implementation approach
(affected files, steps, risks, test strategy). Do **not** modify code. Output one plan
per issue. Offer to post each plan as an issue comment (`gh issue comment`) — ask first.

### `fix`
Implement and ship a fix per issue. **Strict separation of concerns: exactly one PR per
issue.** See section 3.

## 3. Fix orchestration

Invariants for every issue:
- Branch off the default branch: `resolve/issue-<number>-<short-slug>`.
- Only changes for *that* issue go in *that* branch/PR. Never mix issues.
- Use TDD where practical: a failing test that captures the bug, then the fix.
- Open a PR with `gh pr create`, body containing `Closes #<number>` and a summary.
- Then run the **codex review loop** (section 4) for that PR.
- Update the TodoWrite item to completed only after the PR is open and the codex loop has
  reached a terminal state (clean, or reported-for-manual-review).

### Sequential (default)
Resolve issues one at a time in the main working tree. After each PR + codex loop, return
the tree to the default branch before the next issue.

### Parallel (`--parallel [N]`)
Dispatch up to **N** issues concurrently (default 10), **one subagent per issue**, each in
its **own git worktree** so concurrent edits never collide.

1. For each issue create a worktree on its branch:
   `git worktree add ../resolve-wt/issue-<number> -b resolve/issue-<number>-<slug>`
2. Launch a `Task` subagent per issue. Give each subagent: the issue JSON, its worktree
   path, the one-PR-per-issue invariants above, and instructions to run the codex loop
   (section 4) itself and report back {issue, branch, prUrl, codexStatus, notes}.
3. Cap in-flight subagents at N; as one finishes, start the next.
4. When a worktree's PR is open and its codex loop is terminal, prune it:
   `git worktree remove ../resolve-wt/issue-<number>`.
5. If a subagent fails, record it and continue the others; never let one failure abort
   the batch.

Finally, print a table: issue, branch, PR URL, codex status, notes.

## 4. Codex review loop (fix mode, per PR)

**Delegate to the `codex-review-loop` skill.** This plugin depends on the `codex-review`
plugin (auto-installed), which provides the loop's mechanics and gotchas — detection,
three-channel polling, the terminal "no major issues" signal, finding classification, and
thread resolution. Invoke that skill to drive the review on each PR; do not re-implement
the mechanics here.

What you own (judgement, per the skill's "Addressing findings" section): for each finding,
first decide whether it is a real issue. If not, reply explaining why and resolve the
thread. If real, fix it, push, reply with a detailed explanation, and resolve the thread.
Repeat rounds until the skill reports the PR clean (or the connector is unavailable, in
which case report the PR for manual review).

If the `codex-review-loop` skill is somehow unavailable, fall back to commenting
`@codex review` on the PR, watching all three GitHub channels for the
`chatgpt-codex-connector` bot, addressing findings, and repeating until it reports no
major issues. **Bound this fallback:** cap the wait at the normal review window (~8 polls /
~6–8 min). If the connector never responds (no bot activity in that window) or is not
installed, stop and report the PR as "created — codex review loop unavailable, ready for
manual review" rather than leaving the issue/PR stuck indefinitely.

## 5. Report

End with a concise summary table across all processed issues and the action taken. Never
claim a fix is complete unless its PR is open and its codex loop reached `clean` (or codex
was unavailable and you said so).
