#!/usr/bin/env bash
# Pull a new upstream pstack release into this port.
#
# Upstream lives in a subdirectory of the cursor/plugins monorepo, and this
# repo has no remote in common with it. The `upstream` branch bridges that: it
# holds the plain, unconverted upstream subtree, one commit per release, and it
# shares a root with `main`. That shared root is what lets git do a real
# three-way merge instead of treating every file as new.
#
# Conflicts are then resolved by converting the two upstream-derived sides
# through tools/convert.sh first. Anything that differs only because the port
# renamed a model or a path collapses to nothing, leaving only the hunks where
# upstream rewrote a sentence the port had also adapted.
#
# Usage: tools/merge-upstream.sh [upstream-ref]        (default: origin/main)

set -euo pipefail
cd "$(dirname "$0")/.."
REPO=$(pwd)
REF="${1:-origin/main}"
CACHE="$HOME/.cache/checkouts/github.com/cursor/plugins"
SUBDIR="pstack"

[ -z "$(git status --porcelain)" ] || { echo "working tree is dirty; commit or stash first"; exit 1; }

# 1. Refresh the upstream checkout.
if [ -d "$CACHE/.git" ]; then
  git -C "$CACHE" fetch --all --prune --quiet
else
  mkdir -p "$(dirname "$CACHE")"
  git clone --quiet https://github.com/cursor/plugins "$CACHE"
fi
SHA=$(git -C "$CACHE" rev-parse "$REF")
VERSION=$(git -C "$CACHE" show "$SHA:$SUBDIR/.cursor-plugin/plugin.json" | sed -n 's/.*"version": *"\([^"]*\)".*/\1/p')
echo "upstream $REF = ${SHA:0:7}, version $VERSION"

TREE=$(git -C "$CACHE" rev-parse "$SHA:$SUBDIR")
if [ "$(git rev-parse upstream^{tree})" = "$TREE" ]; then
  echo "the upstream branch already holds this tree; nothing to merge"
  exit 0
fi

# 2. Add one vendor commit holding that subtree verbatim. A detached worktree
#    keeps the live checkout untouched while the branch is rewritten.
WT=$(mktemp -d)
trap 'git worktree remove --force "$WT" 2>/dev/null || true; rm -rf "$WT"' EXIT
git worktree add --quiet --detach "$WT" upstream
(
  cd "$WT"
  git checkout --quiet -B upstream
  find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  git -C "$CACHE" archive "$SHA" "$SUBDIR/" | tar -x --strip-components=1
  git add -A
  git commit --quiet -m "vendor: upstream pstack $VERSION

Pure upstream subtree from cursor/plugins@${SHA:0:7}, path $SUBDIR/."
)
# The tree must match upstream byte for byte, or the merge base is a fiction.
[ "$(git rev-parse upstream^{tree})" = "$TREE" ] || { echo "vendor tree does not match upstream"; exit 1; }
echo "vendor commit added and verified against upstream"

# 3. Merge, then re-resolve each conflict with both upstream-derived sides converted.
git merge upstream --no-commit >/dev/null 2>&1 || true
TOTAL=$(git diff --name-only --diff-filter=U | wc -l | tr -d ' ')
[ "$TOTAL" -eq 0 ] && { echo "merged with no conflicts"; exit 0; }

AUTO=0; LEFT=""
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' RETURN 2>/dev/null || true
for f in $(git diff --name-only --diff-filter=U); do
  # A file missing a stage (added or deleted on one side only) has no base to
  # merge against; leave those for a human.
  git show ":1:$f" >/dev/null 2>&1 && git show ":2:$f" >/dev/null 2>&1 && git show ":3:$f" >/dev/null 2>&1 || {
    LEFT="$LEFT $f"; continue; }
  ext="${f##*.}"; slug=$(echo "$f" | tr '/' '_')
  b="$TMP/$slug.base.$ext"; o="$TMP/$slug.ours.$ext"; t="$TMP/$slug.theirs.$ext"
  git show ":1:$f" > "$b"; git show ":2:$f" > "$o"; git show ":3:$f" > "$t"
  "$REPO/tools/convert.sh" "$b" >/dev/null 2>&1 || true
  "$REPO/tools/convert.sh" "$t" >/dev/null 2>&1 || true
  if git merge-file -q "$o" "$b" "$t" 2>/dev/null; then
    cp "$o" "$REPO/$f"; git add "$REPO/$f"; AUTO=$((AUTO + 1))
  else
    cp "$o" "$REPO/$f"; LEFT="$LEFT $f"
  fi
done

echo
echo "conflicts: $TOTAL    auto-resolved: $AUTO    left for you:$(echo $LEFT | wc -w | tr -d ' ')"
[ -n "$LEFT" ] && { echo; for f in $LEFT; do printf '  %2s hunks  %s\n' "$(grep -c '^<<<<<<<' "$f" 2>/dev/null || echo -)" "$f"; done; }
cat <<'NEXT'

Next:
  1. Resolve what is left. Take upstream's prose, keep the port's platform
     adaptation. A rule that will recur belongs in tools/convert.sh.
  2. tools/convert.sh                 convert whatever merged in verbatim
  3. tools/check-conversion.sh        must print "conversion clean"
  4. Bump version in .claude-plugin/plugin.json to <upstream>-cc.1
  5. Update CONVERSION.md, then commit the merge
NEXT
