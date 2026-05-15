---
name: codex-claude-code-multi-agent-collab
description: Coordinate Codex with Claude Code through a shared filesystem protocol for low-overhead multi-agent software work. Use when the user asks Codex to work with Claude Code, mentions Codex and Claude Code collaboration, asks for multi-agent cooperation, or says requests such as "和 Claude Code 协作完成", "让你们俩协作", "Codex 和 Claude Code 多智能体协作", or "让 Claude 出方案你来实现".
---

# Codex 和 Claude Code 多智能体协作

Use this skill to coordinate Codex and Claude Code through a shared project directory without copying long messages through the user.

The default protocol uses one Markdown thread per task, lightweight signal files, explicit kickoff after task splitting, latest-round reading, and mandatory closing rounds.

## Quick Start

When the user asks to collaborate with Claude Code:

1. Confirm the shared collaboration root before creating files. Ask the user where `.ai-collab` should live unless the path is already explicit or an existing `.ai-collab/` is present in the active project.
2. Locate or create the collaboration root, usually `<project>/.ai-collab/`.
3. Ensure these directories exist: `threads/`, `signal/`, `shared/`, `tasks/`.
4. Create one thread file for the task: `.ai-collab/threads/YYYYMMDD-HHMMSS-topic.md`.
5. Append only one new round for your turn.
6. Write a signal file for Claude: `.ai-collab/signal/codex-ready`.
7. Wait for `.ai-collab/signal/claude-ready` only during the current active turn.
8. Read the signal's thread and round, process the newest round by default, then delete `claude-ready`.
9. When done, append a closing round and signal Claude so it does not keep waiting.

Detailed templates are in [references/protocol.md](references/protocol.md). Read it when creating or updating the collaboration protocol, recovering from a broken round, or handling ambiguous multi-round coordination.

Claude Code setup details are in [references/claude-code-setup.md](references/claude-code-setup.md). Read it when the user wants the workflow to work from Claude Code's side too, when packaging this skill for GitHub, or when setting up hooks/scripts in a project.

## Directory Layout

Use this layout inside the project being coordinated:

```text
.ai-collab/
├── COLLAB.md
├── threads/
├── signal/
│   ├── codex-ready
│   └── claude-ready
├── shared/
├── tasks/
├── inbox/      # legacy compatibility only
└── outbox/     # legacy compatibility only
```

Use `inbox/` and `outbox/` only for compatibility with old workflows or urgent pointers. New tasks should use `threads/`.

When setting up Claude Code hooks, copy [scripts/wait-cycle.sh](scripts/wait-cycle.sh) into the target project's `.ai-collab/wait-cycle.sh` and copy [scripts/settings.local.json](scripts/settings.local.json) into `.claude/settings.local.json` if that project does not already have a Claude Code settings file.

If the user wants `.ai-collab` somewhere other than the project root, use that explicit directory as the shared collaboration root and configure Claude Code with `AI_COLLAB_ROOT=<project-or-shared-root>` when running `wait-cycle.sh`.

## Thread Rules

Use one thread file per collaboration task. Do not create a new message file for every exchange.

Every thread must have frontmatter:

```markdown
---
conv_id: short-stable-id
topic: short human-readable task
status: active | waiting_claude | waiting_codex | done | blocked
created_at: YYYY-MM-DD HH:mm:ss
updated_at: YYYY-MM-DD HH:mm:ss
---
```

Append rounds at the end:

```markdown
## Round 1 - Codex - task

...

## Round 2 - Claude - plan

...
```

Round heading format is mandatory:

```text
## Round N - Codex|Claude - type
```

## Signal Rules

After appending a round that needs Claude, write `.ai-collab/signal/codex-ready`:

```text
Thread updated: .ai-collab/threads/YYYYMMDD-HHMMSS-topic.md
Next reader: claude
Round: N
Status: waiting_claude
```

After Claude replies, it should write `.ai-collab/signal/claude-ready` in the same format.

When reading a signal:

- Follow the thread path in the signal.
- Process the signal's `Round` or the latest round by default.
- Read older rounds only when the latest round explicitly requires context, when there is ambiguity, or when reviewing the whole task.
- Delete the consumed ready signal after processing it.

## Division Of Labor

After Claude proposes a split, do not start implementation immediately. Append a kickoff round first.

The kickoff must state:

- Whether Codex accepts the split.
- Which items Codex owns.
- Which items Claude owns.
- That Codex is starting now.
- That Codex will report results when finished.

Do not implement work assigned to Claude. If the split would cause file conflicts or blocked dependencies, append a coordination round and ask to renegotiate before changing ownership.

## Completion Rule

Never finish only by telling the user. Also append a closing round to the thread and signal Claude.

The closing round must include:

- What changed.
- What validation ran.
- Remaining risks or "none known".
- `status: done`.
- A clear sentence that Claude does not need to keep waiting.

## Practical Defaults

- Prefer Claude for planning, alternative analysis, and review.
- Prefer Codex for implementation, local edits, local validation, and final integration.
- For small tasks, tell the user collaboration may be overhead and offer to do it directly.
- During the current turn, local file waiting for `claude-ready` is acceptable. Do not create background polling unless the user explicitly asks.
- Keep collaboration messages concise. Put detailed artifacts in `shared/` only when needed.
