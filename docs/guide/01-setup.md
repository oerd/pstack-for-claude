# Set up pstack

In this page you install the plugin, pick which models pstack uses, and run your first task. Setup is one command plus a short conversation.

## Install the plugin

From a shell, run:

```bash
claude plugin marketplace add /Users/oerd/workbench
claude plugin install pstack@workbench
```

Restart Claude Code, or run `/reload-plugins` to load it in the current session.

## Pick your models

Run:

```text
/pstack:setup-pstack
```

[`/pstack:setup-pstack`](../../skills/setup-pstack/SKILL.md) shows you each role (code delegates, judgment, the review panels) and asks what you want. Answer the questions. It writes `~/.claude/pstack-models.md`, a small config file every pstack skill reads.

Claude Code takes four model names — `opus`, `fable`, `sonnet`, `haiku` — so there is nothing to detect and no per-account slug to look up.

You only override what you care about. A role with no line in the file keeps the skill's default. To restore a default later, delete that role's line, or just run `/pstack:setup-pstack` again.

Set a role to `inherit` and pstack omits the subagent `model` field, so the subagent runs on your parent session's model. For a panel role the value is a list, and one subagent runs per entry, so the list length sets the panel size. Setup also configures `swarm workers`, the default model for every `/pstack:swarm` worker unless a race names a model for each arm.

## Accept the verification offer, or don't

At the end of setup, `/pstack:setup-pstack` looks for a way to prove app behavior in your project, either a `verify-*` skill or an existing harness. If it finds neither, it offers once to generate one with [`/pstack:create-verification-skill`](../../skills/create-verification-skill/SKILL.md).

Say yes and it writes `.claude/skills/verify-<app>/`, a project-local skill that teaches agents to drive your app the way a user does. It proves the skill works once before handing it over. Say no and setup moves on. You can run `/pstack:create-verification-skill` yourself any time. [Verify and ship](./06-verify-and-ship.md#create-a-project-verification-skill) covers when it earns its place.

Every skill reads the config on its next run, so the choices take effect right away.

## Run your first task

Pick something real but small, and describe it the way you'd describe it to a colleague:

```text
/pstack:poteto-mode add a --json flag to this command. text output stays byte-identical. verify both.
```

Watch the todo list. Its first items are the matched playbook's steps copied in, the Feature playbook for this prompt. If `/pstack:poteto-mode` skips a step, the step stays in the list with `skip: <reason>`, so you can see what it chose not to do.

From here you can type normal follow-ups. `/pstack:poteto-mode` is sticky. It stays on for the conversation until you opt out by saying so.

Next: [Route work through `/pstack:poteto-mode`](./02-poteto-mode.md).
