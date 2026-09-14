#!/usr/bin/env bash
# Fail if any Cursor-ism survived the conversion.
#
# Run this before tagging a release. It is the guard that stops an upstream
# merge from shipping a `grok-4.6-fast-xhigh` default or a ~/.cursor path that
# nothing in Claude Code will ever read.
#
# Errors block a release. Warnings need a human to read the line and decide:
# some prose about Cursor is correct, because the port genuinely came from there.
#
# Matching is done with perl, the same engine tools/convert.sh uses, so
# anything reported here is something convert.sh can actually see.
#
# Usage: tools/check-conversion.sh

set -uo pipefail
cd "$(dirname "$0")/.."

EXCLUDE_RE='(^|/)(\.git/|tools/|CONVERSION\.md|UPDATING\.md|LICENSE)'
LIST=$(mktemp); trap 'rm -f "$LIST"' EXIT
find . -type f \
  \( -name '*.md' -o -name '*.json' -o -name '*.ts' -o -name '*.mjs' \
     -o -name '*.sh' -o -name '*.tsv' -o -name '*.txt' \) \
  | sed 's|^\./||' | grep -Ev "$EXCLUDE_RE" | sort > "$LIST"

status=0

report() {
  local label="$1" pattern="$2" tier="$3"
  local hits n
  hits=$(perl -ne 'print "$ARGV:$.:$_" if /'"$pattern"'/; close ARGV if eof' -- $(cat "$LIST") 2>/dev/null)
  [ -z "$hits" ] && return 0
  n=$(printf '%s\n' "$hits" | wc -l | tr -d ' ')
  if [ "$tier" = error ]; then
    printf '\n\033[31mERROR\033[0m  %s (%s)\n' "$label" "$n"; status=1
  else
    printf '\n\033[33mWARN \033[0m  %s (%s)\n' "$label" "$n"
  fi
  printf '%s\n' "$hits" | head -6 | cut -c1-150 | sed 's/^/       /'
  [ "$n" -gt 6 ] && printf '       ... and %s more\n' "$((n - 6))"
}

# Upstream model names. Claude Code's Agent tool only takes opus|sonnet|haiku|fable.
report "upstream model names" \
  '\bgrok-4\.6-(?:fast-xhigh|medium-fast)\b|\bgpt-5\.6-sol-max\b|\bclaude-fable-5-1-thinking-(?:max|medium)\b|\bclaude-opus-5-thinking-xhigh\b|\binherit-parent\b' error

# Paths Claude Code never reads.
report "cursor paths" '(?<![\w.-])\.cursor/|\.cursor-plugin|pstack-models\.mdc' error
report "cursor transcript layout" '\bagent-transcripts\b' error

# Tool and parameter names with no Claude Code equivalent.
report "cursor tool names" '\bAskQuestion\b|\bgeneralPurpose\b|`Task` tool|\bTask tool\b' error
report "cursor-only agent params" \
  '\bis_background\b|\brun_in_background\b|\bcloud_base_branch\b|\breadonly:|environment:\s*"(?:cloud|local)"' error

# Cross-references must carry the plugin namespace. Same pattern convert.sh
# applies, so a hit here is always fixable by re-running it.
SKILLS=$(find skills -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort | paste -sd'|' -)
report "unprefixed skill cross-refs" "(?<![\\w/:-])/(?:$SKILLS)\\b" error

# Prose the port may legitimately keep: the README explains where pstack came
# from, and which team-kit skills this port vendors. Read, then decide.
report "cursor-team-kit references" '\bcursor-team-kit\b' warn
report "prose mentions Cursor" '\bCursor\b' warn

echo
if [ $status -eq 0 ]; then echo "conversion clean"
else echo "conversion INCOMPLETE - run tools/convert.sh, then fix what is left by hand"; fi
exit $status
