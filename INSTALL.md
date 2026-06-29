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

## Installing on other agents

The instructions above are for Claude Code, but nothing here is Claude-specific at its core.
The logic lives in **plain bash scripts** and **markdown procedures**, so any agent
(Codex, Gemini CLI, Copilot CLI, Cursor, a custom harness, …) can adopt and adapt it.

### Key files to point your agent at

| File | What it is | How another agent uses it |
|------|------------|---------------------------|
| `commands/resolve-issues.md` | The command procedure, written as a prompt. The body (below the YAML frontmatter) is the step-by-step the agent follows. | Load it as your agent's equivalent of a command/skill, or paste the body as a task prompt. Ignore the Claude-specific frontmatter. |
| `scripts/select-issues.sh` | Pure logic: fetch + priority-order open issues as JSON. Bash + `jq` + `gh`. | Call it directly. `--input FILE` runs the ranking on canned JSON with no network — use it in tests. |
| `.claude-plugin/plugin.json` | Manifest: name, version, and the `codex-review` dependency. | Read for metadata and to know it needs the codex-review loop. |
| `AGENTS.md` | This repo's agent-agnostic guide (layout, conventions, working agreement). | Start here for orientation. |
| `docs/adr/` | Why the design is the way it is. | Read before changing behavior. |
| Codex loop: the `codex-review` plugin's `skills/codex-review-loop/SKILL.md` + `codex-review-loop.sh` | The reusable review-loop procedure + script. | Vendor or reference it the same way — the script is standalone bash; the SKILL.md is the procedure. |

### Generic adaptation steps

1. **Ensure the runtime deps exist:** authenticated `gh` and `jq` on `PATH`.
2. **Expose the procedure.** Read `commands/resolve-issues.md` (skip the frontmatter) and
   register its body as a command/skill/prompt in your agent's own mechanism:
   - Claude Code: `commands/*.md` and `skills/*/SKILL.md` are auto-discovered.
   - Codex: surface it via `AGENTS.md` / a `.codex` prompt.
   - Gemini CLI: expose as a skill activated by `activate_skill`.
   - Copilot CLI: register as a `skill`.
   - Custom harness: feed the markdown body as the system/task prompt.
3. **Wire the scripts.** Wherever the procedure references
   `${CLAUDE_PLUGIN_ROOT}/scripts/...`, substitute the absolute path where you placed the
   scripts.
4. **Provide the Codex loop.** Either vendor `codex-review-loop.sh` + its SKILL.md alongside,
   or have your procedure call the script directly. It is plain bash and agent-independent.
5. **Keep the pure cores testable.** Both scripts expose `--input` for network-free runs;
   reuse `tests/run.sh` (and the codex-review plugin's tests) as your regression suite.

The intent is portability: the command markdown is the spec, the bash scripts are the
engine, and the manifests are just packaging. Swap the packaging for your agent's and the
behavior carries over unchanged.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `dependency-unsatisfied` / `codex-review` missing | Add its marketplace: `/plugin marketplace add djm204/codex-review`, then re-run `/plugin install resolve-issues`. |
| Dependency stays unresolved after adding the marketplace | `/reload-plugins`, or re-run the install command. |
| `cross-marketplace` error | Expected only if the consumer's `marketplace.json` lacks `allowCrossMarketplaceDependenciesOn: ["codex-review"]` — this repo already sets it. |
| Codex loop reports "unavailable, manual review" | The `@codex` connector isn't installed/active on the target repo; install it or review the PR manually. |
| `gh` permission/auth errors | `gh auth login` and ensure repo scope. |

For architecture and how the dependency is wired, see `AGENTS.md` and `docs/adr/`.
