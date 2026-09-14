---
name: swarm
description: "Fan out N parallel workers, drain them, and return one report. Use for /pstack:swarm, 'swarm this', or parallel coverage, races, gauntlets, and exploration."
disable-model-invocation: true
---

# Swarm

Fan out N parallel isolated workers. They may cover separate slices, race the same brief, or mix both. The parent waits, aggregates, and returns one report.

## Start

Open a todolist with one entry per phase before launching anything.

1. Frame
2. Fan out
3. Aggregate
4. Report

## Phase A: Frame

1. State the done predicate and the artifact or report the swarm must return.
2. Choose the shape. Partition into slices, race N workers on identical briefs, or mix both. For a race or mixed shape, declare `first pass`, `rank all`, or `best-of` before spawning.
3. Set N from the user or derive it from the shape. N is total workers, not a concurrency limit.
4. Pick the worker model from `swarm workers` in `~/.claude/pstack-models.md` when present. Otherwise use `sonnet`. For a model race, name each arm's model up front.
5. Give each worker its own writable output when it writes.

## Phase B: Fan out

Spawn all N workers in one message with `subagent_type: "general-purpose"`, `isolation: "worktree"`, and the configured model. Claude Code subagents already run in the background, so there is no flag to set for that. `isolation: "worktree"` gives each worker its own git worktree, which is what keeps N writers off each other's files. Omit `isolation` only when the worker must see the user's live checkout.

`isolation: "remote"` runs a worker in a cloud environment instead. It is gated per account, so treat it as an upgrade rather than the default: try it when the swarm is large and the work is self-contained, and fall back to `"worktree"` if it is unavailable.

A worker that must start from a non-default pushed branch checks that branch out itself as its first step; Claude Code has no base-branch parameter.

Every brief stands alone. Include the goal, scope, exact slice or race arm, how to verify, and what to report. Reports use `PASS`, `ISSUES`, or `BLOCKED` with evidence.

If a worker drops out, proceed with N-1 and note it.

## Phase C: Aggregate

Read the terminal results. For coverage, every required slice needs a result. For a race, apply the selection rule declared up front. Use first pass, rank all, or best-of. Do not paste raw worker dumps.

Keep a compact result table, one-line evidenced issues, and explicit gaps or dropouts.

## Phase D: Report

Return one consolidated in-chat report with the table, issue one-liners, gaps or dropouts, and the race rule when used.
