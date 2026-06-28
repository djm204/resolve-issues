# Lessons

## Don't create an orphan base branch for a PR
**Pattern:** To open a PR on a fresh repo I made `main` an orphan empty commit, then tried
to `git rebase main` the feature branch. The feature branch's first commit was itself a
root commit (no parent, because `master` had no commits), so it shared **no history** with
`main` → GitHub refused the PR ("no history in common"), and the rebase/cherry-pick hit
spurious conflicts on a file I'd amended.

**Why it happened:** First commit on a repo with zero prior commits is a root commit.
Branching/rebasing two independent root histories together is messy.

**How to apply next time:** On a brand-new repo, make the FIRST commit on `main` (or the
intended base) *first*, then branch the feature off it so they share history from the
start. If you must reconcile two roots, `git cherry-pick` the work commit onto the base
branch (one shared ancestor) rather than rebasing unrelated histories — and never
force-push while still mid-rebase/mid-cherry-pick.

## Resolve conflicts before continuing a cherry-pick/rebase, never push mid-operation
I force-pushed while a rebase was still stopped on a conflict. The branch ref hadn't
advanced so no harm done, but it's a footgun. Always finish (`--continue`) or `--abort`
first, verify `git status` is clean, then push.
