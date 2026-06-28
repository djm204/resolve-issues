# ADR-003: Codex review loop integration

## Status
Accepted

## Context
After fix mode opens a PR, the work is not done until it has been reviewed. The user's
environment uses the GitHub Codex connector (`chatgpt-codex-connector[bot]`) as an
automated reviewer triggered by an `@codex review` comment. Codex reviews asynchronously
(~2–6 min) and signals its outcome across three different GitHub channels, with a
non-obvious terminal signal for a clean pass. A naive poller that watches only inline
review comments will hang on clean passes and miss the "done" signal.

## Decision
Introduce `scripts/codex-review-loop.sh` and wire it into fix mode only.

- **Detection:** the loop is "available" if the Codex connector can review the repo.
  Detect by checking for prior `chatgpt-codex-connector` activity / app installation;
  if undetectable, treat as unavailable and **report the PR for manual review** rather
  than blocking.
- **Trigger:** post an `@codex review` issue comment on the PR; record the trigger
  timestamp.
- **Poll all three channels** for bot activity newer than the trigger:
  1. `issues/{pr}/comments` — terminal clean signal: body contains
     `"Didn't find any major issues"` (also accept "no issues"/"looks good"/👍 reaction).
     This **ends the loop** for that PR.
  2. `pulls/{pr}/reviews` — a submitted review with findings.
  3. `pulls/{pr}/comments` — inline findings.
- **Address findings:** for each finding, first **determine whether it is a real issue**.
  - If real → implement the fix, push, reply to the thread with a detailed explanation of
    the fix, and mark the thread resolved.
  - If not a real issue → reply explaining why it is a non-issue and resolve the thread.
- **Iterate:** after addressing a round, re-trigger and re-poll until the terminal clean
  signal arrives (bounded by a max-round cap to avoid infinite loops).
- The script is the mechanical part (detect/trigger/poll/classify, JSON out, `--input`
  for tests). The judgement part (is-it-real, how-to-fix) stays in the agent/command.

## Consequences
- Easier: clean passes are detected correctly instead of timing out; findings are
  addressed and resolved with an auditable comment trail.
- Easier: graceful degradation — no connector means a clear "PR ready for manual review"
  report, not a hang.
- Harder: three-channel polling and thread-resolution via the GitHub API are more code
  than a single endpoint; the terminal-signal text is a brittle string match that may
  need updating if Codex changes its wording.
- Trade-off: a max-round cap can stop before a truly clean pass on pathological PRs; the
  loop reports unresolved state rather than claiming success.

## References
- Memory: "Codex review 'no issues' arrives as issue comment" (three-channel polling).
- Memory: "codex-clean-pass-signal" (clean = explicit no-issues/👍, not silence).
- `agent-workflow:task-end` mandatory Codex review loop.
