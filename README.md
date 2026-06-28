# resolve-issues

A [Claude Code](https://claude.com/claude-code) plugin that iterates open GitHub issues
**priority-first** and triages, plans, or fixes them — one PR per issue.

## Install

Add the marketplace, then install the plugin:

```
/plugin marketplace add djm204/resolve-issues
/plugin install resolve-issues
```

Requires [`gh`](https://cli.github.com/) (authenticated) and `jq`. The codex review loop
additionally requires the GitHub Codex connector (`@codex`) installed on the repo.

## Usage

```
/resolve-issues [triage|plan|fix] [--parallel [N]] [--issue N] [--label L] [--max N] [--repo OWNER/NAME]
```

| Mode | What it does |
|------|--------------|
| `triage` (default) | Classify each issue, suggest labels/routing, apply after you confirm. Read-mostly. |
| `plan` | Investigate and write an implementation approach per issue. No code changes. |
| `fix` | Implement + ship a fix per issue: one branch + PR each, then the codex review loop. |

Selection flags (`--issue`, `--label`, `--max`, `--repo`) are forwarded to issue
selection. Issues are always processed highest priority first.

### Fix mode

- **One PR per issue** — changes are never mixed across issues.
- **Sequential by default**; pass `--parallel [N]` to fan out one worktree subagent per
  issue (max concurrency `N`, default **10**).
- After each PR opens, the **codex review loop** runs: trigger `@codex review`, poll for
  its response, address findings (verify each is real, fix, explain, resolve the thread),
  and repeat until Codex reports no major issues. If the connector isn't available, the PR
  is reported for manual review instead.

## Priority labels

Case-insensitive, in order: `priority: critical`/`p0`/`critical` → `priority: high`/`p1`/
`high` → `priority: medium`/`p2`/`medium` → `priority: low`/`p3`/`low`. Unlabeled issues
sort last. Ties break by newest issue number.

## Development

```bash
bash tests/run.sh   # dependency-free tests for the helper scripts
```

See [`docs/AGENT_RAMP_UP.md`](docs/AGENT_RAMP_UP.md) and [`docs/adr/`](docs/adr/) for
architecture.

## License

MIT
