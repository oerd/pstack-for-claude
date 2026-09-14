# Updating from upstream

This port tracks [pstack](https://github.com/cursor/plugins/tree/main/pstack)
by Lauren Tan. Upstream writes for Cursor; this repo is the same skills
converted for Claude Code. [CONVERSION.md](./CONVERSION.md) lists every
difference.

The conversion is a substitution rule set, not a fork. That is what makes an
upstream release cheap to take: merge it, re-apply the rules, review the few
places where upstream rewrote a sentence the port had also changed.

## Layout

Two branches share one root commit.

```
upstream:  0.14.8 ──── 0.15.2 ──── (next release)
                 \                       \
main:             port ──────── merge ──── merge
```

`upstream` holds the plain upstream subtree, one commit per release, with no
conversion applied. Nothing is ever edited there by hand.

`main` is the converted port. Its first commit is a child of the first
`upstream` commit, which is the tree the port was originally cut from. That
shared ancestry is the whole point: it gives git a real merge base, so a new
release merges instead of arriving as 150 unrelated files.

Upstream lives inside the `cursor/plugins` monorepo, so there is no remote to
add. The vendor commits are built by extracting the `pstack/` subtree, and each
one is verified to match upstream's tree hash exactly.

## Taking a new release

```bash
tools/merge-upstream.sh          # or: tools/merge-upstream.sh <ref>
```

It refreshes the upstream checkout, adds a vendor commit for the new release,
merges it, and resolves every conflict it can. Then:

```bash
# resolve whatever it listed
tools/convert.sh                 # convert what merged in verbatim
tools/check-conversion.sh        # must print "conversion clean"
```

Bump `version` in `.claude-plugin/plugin.json` to the new upstream version with
a fresh `-cc.1` suffix (`0.15.2` upstream becomes `0.15.2-cc.1`), record
anything new in CONVERSION.md, and commit the merge.

To pick up the result locally, `claude plugin update pstack`. The install is a
copy, not a link, and the update is version-gated, so the bump is what makes it
land.

## Resolving a conflict

One rule covers almost every case:

> Take upstream's prose. Keep the port's platform adaptation.

Upstream rewrites sentences constantly (prose-density passes, pronoun passes,
removing semicolons). Those are content decisions and the port follows them.
The port only diverges where Claude Code cannot do what Cursor does, and
CONVERSION.md is the list of those places. When a hunk mixes both, write the
merged line by hand.

`merge-upstream.sh` already removes the purely mechanical differences before
you see anything. It converts the base and upstream sides of each conflict
first, so a hunk that differs only because upstream says `grok-4.6-fast-xhigh`
where the port says `sonnet` disappears on its own. What reaches you is a real
disagreement.

**If a resolution will recur, add it to `tools/convert.sh` instead of fixing it
by hand.** Every rule there is one you never resolve again.

Two kinds of rule do not belong in the script:

- Anything where the correct Claude Code text is not derivable from upstream's.
  Upstream's cache-cleanup advice names Cursor's Application Support files;
  mapping the path leaves the filenames wrong. The checker flags these instead.
- Anything upstream states that is false here. Upstream says the system prompt
  names the transcript directory. It does not, so the port derives the path
  from the working directory.

## The two scripts

`tools/convert.sh` applies every rule in CONVERSION.md: model names, `.cursor/`
paths, tool and parameter renames, the `/pstack:` namespace on skill
cross-references, and the phrase-level rewrites for features Claude Code lacks.
It is idempotent, so running it twice changes nothing.

`tools/check-conversion.sh` fails on anything that survived. Run it before
every release. Errors block; warnings want a human to read the line, because
some prose about Cursor is correct — the README credits upstream, and that
should stay.

Both skip `CONVERSION.md`, `UPDATING.md`, `LICENSE` and `tools/`, which
describe the mapping rather than use it.

## Watch for

- **A new skill.** It arrives unconverted. `tools/convert.sh` handles the
  mechanical part; read it for Cursor-specific behavior the rules cannot see.
- **A feature with no Claude Code equivalent.** Record it under "Cursor
  features with no equivalent" in CONVERSION.md and say what the port does
  instead.
- **Upstream deleting something.** Follow it. If the deletion strips a role or
  a reference file, check for config entries and cross-references that die with
  it.
- **Model panels.** Upstream builds them from several vendors and sometimes
  repeats a model. Claude Code has four names, so panels are three distinct
  models, and `haiku` never sits in a review lane.
