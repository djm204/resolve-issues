# Installing resolve-issues

`resolve-issues` is a [Claude Code](https://claude.com/claude-code) plugin. It depends on
the [`codex-review`](https://github.com/djm204/codex-review) plugin (for the Codex review
loop), which Claude Code **auto-installs** — you just need its marketplace configured first.

## Prerequisites

| Requirement | Why | Check |
|-------------|-----|-------|
| Claude Code **v2.1.110+** | plugin dependency resolution | `claude --version` |
| [`gh`](https://cli.github.com/), authenticated | the command drives GitHub | `gh auth status` |
| `jq` | `select-issues.sh` JSON processing | `jq --version` |
| GitHub **Codex connector** (`@codex`) on target repos | fix-mode review loop (optional) | repo's GitHub App settings |

## Install

Add **both** marketplaces (the dependency's first so it resolves), then install:

```
/plugin marketplace add djm204/codex-review
/plugin marketplace add djm204/resolve-issues
/plugin install resolve-issues
```

Claude Code installs `resolve-issues` and automatically pulls in its `codex-review`
dependency. The install output lists which dependencies were added.

> Order matters: if `djm204/codex-review` is not a configured marketplace, the dependency is
> left unresolved (see Troubleshooting). Adding it later and re-running
> `/plugin install resolve-issues` resolves it.

## Verify

```
/plugin list
```

Both `resolve-issues` and `codex-review` should be listed and enabled, with no errors.
Then try the command:

```
/resolve-issues triage
```

(`triage` is read-mostly and safe to run first.)

## Update

Updates arrive when the plugin's `version` is bumped (pinned installs only move on a version
change). Force a refresh with:

```
/plugin marketplace update djm204/resolve-issues
/reload-plugins
```

## Uninstall

```
/plugin uninstall resolve-issues
```

To also remove the auto-installed `codex-review` dependency if nothing else needs it:

```
claude plugin uninstall resolve-issues --prune
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `dependency-unsatisfied` / `codex-review` missing | Add its marketplace: `/plugin marketplace add djm204/codex-review`, then re-run `/plugin install resolve-issues`. |
| Dependency stays unresolved after adding the marketplace | `/reload-plugins`, or re-run the install command. |
| `cross-marketplace` error | Expected only if the consumer's `marketplace.json` lacks `allowCrossMarketplaceDependenciesOn: ["codex-review"]` — this repo already sets it. |
| Codex loop reports "unavailable, manual review" | The `@codex` connector isn't installed/active on the target repo; install it or review the PR manually. |
| `gh` permission/auth errors | `gh auth login` and ensure repo scope. |

For architecture and how the dependency is wired, see `AGENTS.md` and `docs/adr/`.
