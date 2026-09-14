#!/usr/bin/env bash
# Apply the Cursor -> Claude Code conversion to the working tree.
#
# The port is a deterministic transform of upstream pstack, not a fork. Every
# rule below is documented in CONVERSION.md. Run this after merging a new
# upstream release to convert whatever the merge brought in verbatim, then run
# tools/check-conversion.sh to catch what needs a human.
#
# Safe to re-run: every rule is idempotent.
#
# Usage: tools/convert.sh [path ...]      (default: repo root)

set -euo pipefail
cd "$(dirname "$0")/.."

# Files that are allowed to contain Cursor strings: they describe the mapping
# rather than using it.
EXCLUDE_RE='(^|/)(\.git/|tools/|CONVERSION\.md|UPDATING\.md|LICENSE)'

files() {
  local roots=("$@")
  [ ${#roots[@]} -eq 0 ] && roots=(.)
  find "${roots[@]}" -type f \
    \( -name '*.md' -o -name '*.json' -o -name '*.ts' -o -name '*.mjs' \
       -o -name '*.sh' -o -name '*.tsv' -o -name '*.txt' \) \
    | sed 's|^\./||' \
    | grep -Ev "$EXCLUDE_RE" \
    | sort
}

LIST=$(mktemp); trap 'rm -f "$LIST"' EXIT
files "$@" > "$LIST"
COUNT=$(wc -l < "$LIST" | tr -d ' ')
[ "$COUNT" -eq 0 ] && { echo "no files to convert"; exit 0; }

# Skill names drive the cross-reference prefixing, read live from skills/ so a
# new upstream skill is picked up without editing this script.
SKILLS=$(find skills -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort | paste -sd'|' -)

perl -0pi -e '
  # --- Models -------------------------------------------------------------
  # Claude Code'"'"'s Agent tool takes opus|sonnet|haiku|fable. Upstream names
  # specific vendor models; map by role. Exact strings only, so prose like
  # "we renamed `gpt-4` to `gpt-4o`" is left alone.
  s/\bclaude-fable-5-1-thinking-(?:max|medium)\b/fable/g;
  s/\bclaude-opus-5-thinking-xhigh\b/opus/g;
  s/\bgpt-5\.6-sol-max\b/opus/g;
  s/\bgrok-4\.6-(?:fast-xhigh|medium-fast)\b/sonnet/g;
  s/\binherit-parent\b/inherit/g;

  # --- Paths --------------------------------------------------------------
  # Claude Code has no always-applied rule format; the models config is a
  # plain file every skill reads explicitly.
  s{~/\.cursor/rules/pstack-models\.mdc}{~/.claude/pstack-models.md}g;
  s{\.cursor-plugin}{.claude-plugin}g;
  s{~/\.cursor/}{~/.claude/}g;
  s{(?<![\w.-])\.cursor/}{.claude/}g;

  # --- Tools and parameters ----------------------------------------------
  s/\bAskQuestion\b/AskUserQuestion/g;
  s/\bsubagent_type:\s*generalPurpose\b/subagent_type: "general-purpose"/g;
  s/\bgeneralPurpose\b/general-purpose/g;
  s/\bTask tool\b/Agent tool/g;
  s/`Task` tool/`Agent` tool/g;

  # --- Prose --------------------------------------------------------------
  # Claude Code has /loop, so the reference stands; only the attribution moves.
  s/Cursor\x27s `\/loop` command/Claude Code\x27s `\/loop` skill/g;
' -- $(cat "$LIST")

# --- Platform adaptations ------------------------------------------------
# Phrase-level rewrites where Claude Code has no equivalent of a Cursor
# feature. These recur in every upstream release, so they live here rather
# than being redone by hand at each merge. CONVERSION.md explains each one.
perl -0pi -e '
  # cursor-team-kit ships deslop/control-ui/control-cli; this port vendors them.
  s/the `deslop` skill from the `cursor-team-kit` plugin/the **deslop** skill/g;
  s/ from `cursor-team-kit`//g;

  # Cursor cloud agents map onto Claude Code isolation modes.
  s/One Cursor cloud agent per PR/One isolated subagent per PR (`isolation: "remote"` where the account has it, otherwise `isolation: "worktree"`)/g;
  s/each a Cursor cloud agent/each an isolated subagent (`isolation: "remote"` where the account has it, otherwise `isolation: "worktree"`)/g;
  s/\benvironment: "cloud"/isolation: "remote"/g;
  s/\benvironment: "local"/isolation: "worktree"/g;
  s/full Task schema including `environment`/full `Agent` schema including `isolation`/g;
  s/`Task` calls/`Agent` calls/g;
  s/\bTask subagent\b/Agent subagent/g;
  s/\bone Task call\b/one `Agent` call/g;

  # Cursor'"'"'s /goal survives turns; Claude Code has no standing-goal command,
  # so the objective is written to GOAL.md and re-read every tick.
  s/arm a `\/goal` with the full program objective\. The goal continues across turns until the (queue|chain) is done\./write the full program objective to `GOAL.md` in the run directory. Claude Code has no standing-goal command, so the file is the standing order: every tick re-reads it, and it holds until the $1 is done./g;
  s/arm a `\/goal` with this exact text\./write the program goal to `GOAL.md` in the run directory with this exact text, and re-read it each tick./g;
  s/the armed `\/goal`/`GOAL.md`/g;
  s/the armed \/goal/GOAL.md/g;

  # Cursor has a cloud-sleeper wake chain; Claude Code schedules routines.
  s/(?:the existing |a )cloud-sleeper wake chain/a scheduled routine (`\/schedule`)/g;

  # Transcripts live under ~/.claude/projects/<slug>/, and no system prompt
  # names the path, so skills derive it from the working directory.
  s/the active workspace.s `agent-transcripts\/` directory \(the system prompt names (?:this|the) path\)/`~\/.claude\/projects\/\$(pwd | tr \/ -)\/`/g;

  # Cursor bundles create-skill; on Claude Code that is the skill-creator
  # plugin, installed separately.
  s/Cursor\x27s built-in `create-skill`/the `skill-creator` skill/g;
  s/`create-skill`/`skill-creator`/g;

  # Claude Code offers four models, not vendor families.
  s/different model family/different model/g;

  # Product names in prose that describe the running agent, not the origin.
  s/After a Cursor restart/After a Claude Code restart/g;
  s/restart Cursor/restart Claude Code/g;
  s/the cloud agent.s status in the Cursor dashboard/a background agent\x27s status via `\/tasks`, `ListAgents`, or `TaskOutput`/g;
' -- $(cat "$LIST")

# Cross-references: Claude Code namespaces plugin skills, so /how becomes
# /pstack:how. The negative lookbehind keeps paths like skills/how/SKILL.md
# intact and makes a second run a no-op.
perl -0pi -e "s{(?<![\\w/:-])/($SKILLS)\\b}{/pstack:\$1}g" -- $(cat "$LIST")

echo "converted $COUNT files"
