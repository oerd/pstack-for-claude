# Conversion notes

This is [pstack](https://github.com/cursor/plugins/tree/main/pstack) v0.15.2 by Lauren Tan, ported from the Cursor plugin format to the Claude Code plugin format. Upstream is MIT licensed and the skill content is otherwise unchanged.

## Packaging

| Upstream | Here |
|---|---|
| `.cursor-plugin/plugin.json` | `.claude-plugin/plugin.json` |
| `displayName`, `logo`, `category`, `tags` | dropped — not in Claude's manifest schema |
| `skills: "./skills/"`, `agents: "./agents/"` | dropped — Claude discovers `skills/` and `agents/` by convention. Declaring `agents` as a string fails validation; it must be a `.md` path or absent. |
| installed with `/add-plugin pstack` | `claude plugin marketplace add oerd/pstack-for-claude`, then `claude plugin install pstack@pstack-for-claude`. The repo carries its own `.claude-plugin/marketplace.json` serving the plugin from the repo root. |

Skills are invoked as `/pstack:<skill>` — Claude Code namespaces plugin skills by plugin — so all 200-odd cross-references were rewritten.

## Subagents

`is_background: true` is not a Claude Code agent field; removed from `poteto-agent`. `Comment Sicko` was renamed `comment-sicko` so `subagent_type` addresses it cleanly.

## Tool and parameter mapping

| Cursor | Claude Code |
|---|---|
| `Task` tool | `Agent` tool |
| `AskQuestion` | `AskUserQuestion` |
| `subagent_type: generalPurpose` | `subagent_type: "general-purpose"` |
| `readonly: true` | no equivalent — the prompt forbids writes instead |
| `readonly: false` ("agent mode", needed so MCPs aren't stripped) | no equivalent; `"Explore"` is the read-only agent and has no MCP tools, so panels that need MCP access stay on `"general-purpose"` |
| `run_in_background: true` | no equivalent — subagents already run in the background |
| `environment: "cloud"` / `"local"` | `isolation: "remote"` (gated per account) / `isolation: "worktree"` / omitted |
| `cloud_base_branch` | no equivalent — the worker checks the branch out itself |
| resume an agent | `SendMessage` addressed by name |
| Cursor dashboard for agent status | `/tasks`, `ListAgents`, `TaskOutput` |

## Paths

| Cursor | Claude Code |
|---|---|
| `~/.cursor/rules/pstack-models.mdc` (`alwaysApply: true`) | `~/.claude/pstack-models.md`, a plain config file. Claude Code has no always-applied rule format, and every skill already reads the file explicitly. |
| `~/.cursor/projects/<slug>/agent-transcripts/<uuid>/<uuid>.jsonl` | `~/.claude/projects/<slug>/<uuid>.jsonl`, with subagents under `<uuid>/subagents/`. The slug keeps the leading slash as a leading dash: `/Users/you/proj` → `-Users-you-proj`. |
| "the system prompt names the `agent-transcripts/` directory" | it does not; skills now derive the path from the working directory |
| `.cursor/skills/`, `~/.cursor/plugins/`, `.cursor/worktrees/` | `.claude/` equivalents |

## Models

Cursor lets a subagent run any vendor's model. Claude Code's `Agent` tool takes `opus`, `sonnet`, `haiku`, or `fable`. Mapping by role:

| Upstream | Here |
|---|---|
| `claude-fable-5-1-thinking-max` | `fable` |
| `claude-opus-5-thinking-xhigh` | `opus` |
| `gpt-5.6-sol-max` | `opus` |
| `grok-4.6-fast-xhigh` | `sonnet` |
| `inherit-parent` / `auto` | `inherit` |

Upstream's four-model review panels (interrogate reviewers, arena runners, architect runners) existed for cross-vendor diversity, which isn't available here. They are now three distinct models — `opus`, `fable`, `sonnet` — rather than four with a duplicate. `haiku` is left for generation-bound and mechanical roles; it is too weak for a review lane.

`setup-pstack` was rewritten: there is no model set to detect and no rule file to write, so it presents the fixed four and writes plain config.

## Cursor features with no equivalent

- **`/goal`** (a standing objective that survives turns) — the autopilot playbooks now write the objective to `GOAL.md` in the run directory and re-read it each tick.
- **Cursor's built-in `create-skill`** — routed to `skill-creator` (`claude plugin install skill-creator@claude-plugins-official`), which is not bundled.
- **Cursor's built-in `babysit`** — doesn't exist here, so the disambiguation warnings against it were removed. The babysit playbook itself is unchanged.
- **`/loop`** — Claude Code has one, so these references stand.
- **The reasoning budget** (`setup-pstack`'s `unlimited`/`large`/`medium`/`small` ask, added upstream in 0.15.2) — it works by rewriting the effort token inside a model slug, as in `grok-4.6-fast-xhigh`. Claude Code's model names carry no effort token and the `Agent` tool takes no budget parameter, so there is nothing to ask about and nothing to write. `setup-pstack` keeps asking only about models.

## Bundled from `cursor-team-kit`

Upstream pstack makes 23 hard references to `deslop`, `control-ui`, and `control-cli`, which ship in Cursor's separate `cursor-team-kit` plugin. Those three skills are vendored into `skills/` here so the playbooks work as written.

## Dropped

- **`automations/benny/`** — a pack of Cursor Automations for triaging Slack issue reports. It depends on Cursor's routines/webhook product and `.cursor/automations/` layout, neither of which Claude Code has.
- **`skills/make-bot-ui/`** — builds a UI that wakes a bot through `https://api2.cursor.sh/automations/webhook/<id>`, driven by Cursor's `update_state` tool. Same reason.

Both are recoverable from upstream if Claude Code grows a webhook-routine equivalent.

## Known cosmetic leftovers

`skills/poteto-mode/scripts/package.json` still declares `"name": "@cursor-skill/poteto-mode-tools"`. It's a private package name for the bundled bun scripts and nothing resolves it.

## Updating the installed copy

`claude plugin install` copies the tree into `~/.claude/plugins/cache/<marketplace>/pstack/<version>/` rather than linking it, and `claude plugin update` is version-gated. So a change is only picked up after the version moves:

```bash
# edit, then bump "version" in .claude-plugin/plugin.json
git commit -am "..." && git push     # the marketplace resolves from GitHub
claude plugin update pstack
```

The push matters. Both marketplaces that serve this plugin resolve it from
`github.com/oerd/pstack-for-claude`, so an unpushed local edit is invisible to
the installed copy.

The port carries a `-cc.N` prerelease suffix on the upstream version, so `0.14.8-cc.1` is the first Claude Code build of upstream 0.14.8.

## Keeping up with upstream

`tools/convert.sh` applies every rule on this page, and `tools/check-conversion.sh`
fails on anything that survived. The `upstream` branch carries the unconverted
upstream subtree so a new release is a merge rather than a re-port. See
[UPDATING.md](./UPDATING.md).
