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

# Cross-references: Claude Code namespaces plugin skills, so /how becomes
# /pstack:how. The negative lookbehind keeps paths like skills/how/SKILL.md
# intact and makes a second run a no-op.
perl -0pi -e "s{(?<![\\w/:-])/($SKILLS)\\b}{/pstack:\$1}g" -- $(cat "$LIST")

echo "converted $COUNT files"
