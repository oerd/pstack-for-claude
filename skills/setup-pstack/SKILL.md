---
name: setup-pstack
description: Configure which models pstack uses per role. Writes a config file that overrides the skill defaults. Use for /setup-pstack, "configure pstack models", or changing pstack's model choices.
---

# Setup pstack

Write `~/.claude/pstack-models.md`, a config file that sets pstack's model per role. The skills read it and fall back to their inline defaults when a line is absent, so this is an override layer, not a requirement.

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

The default role-to-model mapping is the shape shown in step 4 below. If `~/.claude/pstack-models.md` already exists, read it and treat its values as the current choices. Otherwise start from those defaults.

### 3. Map and confirm

Show every role with its current model. Ask whether to accept as-is or change specific roles, offering the four models plus `inherit` as the options. Prefer AskUserQuestion over free text.

For panel roles (how critics, arena runners, architect runners, interrogate reviewers) the value is a list, and one subagent runs per entry, `inherit` entries included, so the list length sets the count. `arena cross-judge pool` is also a list, but Arena selects one value from it that differs from the parent's model when possible. `swarm workers` is the default model for every worker unless a race or comparison assigns another model per arm.

Claude Code subagents run Claude models only, so a panel gets its independence from model differences rather than from vendor differences. Keep `haiku` out of judgment lanes; it belongs in generation-bound and mechanical roles.

### 4. Write the config

Write `~/.claude/pstack-models.md` with one line per role, using the same labels poteto-mode uses. Overwrite the whole file so re-runs stay idempotent. Shape:

```
# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit` as a value: the role runs on the parent session's model (omit Agent `model`).
# Panel roles take a comma-separated list; one subagent runs per entry.
feature, refactoring: sonnet
bug-fix: fable
perf-issue: fable
hillclimb: fable
judgment and prose: fable
hardest tasks: opus
how explorer: sonnet
how explainer: fable
how critics: opus, fable, sonnet
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

### 5. Confirm

Tell the user the config was written and that the skills pick it up on their next run. Re-running this skill updates it.

### 6. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `verify-*` skill, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can generate one with /pstack:create-verification-skill." On yes, invoke `/pstack:create-verification-skill`. On no, move on without pushing.
