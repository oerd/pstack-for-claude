---
name: setup-pstack
description: Configure which models pstack uses per role and at what reasoning budget. Writes a config file and the worker agent that carries the budget. Use for /pstack:setup-pstack, "configure pstack models", "pstack budget", or changing pstack's model choices.
---

# Setup pstack

Write two files. `~/.claude/pstack-models.md` sets pstack's model per role; the skills read it and fall back to their inline defaults when a line is absent, so it is an override layer, not a requirement. `~/.claude/agents/pstack-worker.md` is the subagent every pstack skill spawns, and it carries the reasoning budget.

## Steps

### 1. Know the available models

Claude Code's `Agent` tool takes a fixed set of model names, not per-account slugs:

| Name | Use it for |
|------|------------|
| `opus` | Strongest reasoning. Judgment-heavy review, cross-cutting design. |
| `fable` | Strong judgment and the best prose. Writing, synthesis, hard code. |
| `sonnet` | Capable and fast. The default for code delegation. |
| `haiku` | Cheapest and fastest. Mechanical edits, generation-bound arms. |

`inherit` is also valid and means the role runs on the parent session's model; a role set to `inherit` spawns with `model` omitted.

There is nothing to detect. If a `model` value is ever rejected, the `Agent` tool's error names the valid set — use that and update this table.

### 2. Load current state

The default role-to-model mapping is the shape shown in step 4 below. Read the `# budget` line too when the file exists. If `~/.claude/pstack-models.md` already exists, read it and treat its values as the current choices. Otherwise start from those defaults.

### 3. Budget, map, and confirm

**(a) Ask for a budget.** Prefer AskUserQuestion over free text. Offer these four options with these exact labels, and name the current budget when the config records one.

- `unlimited — keep max`
- `large — xhigh reasoning`
- `medium — high reasoning`
- `small — medium reasoning`

**(b) Apply it.** The budget is one `effort` value on the worker agent, written in step 5. Map the label straight across: `unlimited` to `max`, `large` to `xhigh`, `medium` to `high`, `small` to `medium`. It applies to every subagent pstack spawns, panel entries included, because they all spawn as `pstack-worker`. Model and budget are separate choices here: the budget never changes which model a role uses.

**(c) Show the roles and confirm.** Show every role with its current model. Ask whether to accept as-is or change specific roles, offering the four models plus `inherit` as the options. Prefer AskUserQuestion over free text.

For panel roles (arena runners, architect runners, interrogate reviewers) the value is a list, and one subagent runs per entry, `inherit` entries included, so the list length sets the count. `arena cross-judge pool` is also a list, but Arena selects one value from it that differs from the parent's model when possible. `swarm workers` is the default model for every worker unless a race or comparison assigns another model per arm.

Claude Code subagents run Claude models only, so a panel gets its independence from model differences rather than from vendor differences. Keep `haiku` out of judgment lanes; it belongs in generation-bound and mechanical roles.

### 4. Write the config

Write `~/.claude/pstack-models.md` with one line per role, using the same labels poteto-mode uses. Overwrite the whole file so re-runs stay idempotent. Shape:

```
# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit` as a value: the role runs on the parent session's model (omit Agent `model`).
# Panel roles take a comma-separated list; one subagent runs per entry.
# budget: unlimited (max)
feature, refactoring: sonnet
bug-fix: sonnet
perf-issue: sonnet
hillclimb: sonnet
judgment and prose: fable
hardest tasks: opus
how explorer: sonnet
how explainer: fable
why investigators: sonnet
why synthesizer: fable
reflect tooling: opus
reflect judgment, divergent, synthesizer: fable
arena runners: opus, fable, sonnet
arena cross-judge pool: opus, fable, sonnet
swarm workers: sonnet
architect runners: opus, fable, sonnet
interrogate reviewers: opus, fable, sonnet
```

### 5. Write the worker agent

Write `~/.claude/agents/pstack-worker.md`, overwriting it so re-runs stay idempotent. This is the only place the budget takes effect, because the `Agent` tool has no per-call effort setting.

```markdown
---
name: pstack-worker
description: Routing target for pstack's skills. Carries the reasoning budget chosen in /pstack:setup-pstack. Not for direct invocation.
effort: xhigh
---

A pstack worker. Follow the prompt you are given; it carries the whole brief.
```

Set `effort` to the value step 3(b) mapped. Leave out `model`, because the spawning skill passes the role's model and a call-level `model` overrides anything written here. Leave out `tools`, because omitting it inherits every tool, and the investigator and reviewer roles need MCP access.

### 6. Confirm

Tell the user both files were written, name the budget, and say the skills pick them up on their next run. Re-running this skill updates both.

### 7. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `verify-*` skill, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can generate one with /pstack:create-verification-skill." On yes, invoke `/pstack:create-verification-skill` (resolves wherever pstack is installed: workspace, user, or plugin). On no, move on without pushing.
