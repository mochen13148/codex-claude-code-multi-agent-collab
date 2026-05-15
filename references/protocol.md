# Protocol Reference

Use this reference when the active task needs exact templates or protocol repair.

## Create Or Update COLLAB.md

When setting up a project for Codex and Claude Code collaboration, create `.ai-collab/COLLAB.md` with the active protocol. Keep it short and project-local.

Before creating `.ai-collab`, confirm the shared location with the user unless it is already obvious from context. Ask a concise question such as:

```text
`.ai-collab` 应该建在哪个目录？我建议放在当前项目根目录：<path>
```

If Codex and Claude Code use different working directories, choose a path both can read and write. Record that path in the thread and tell Claude Code to use the same root.

Recommended core text:

```markdown
# Claude Code ↔ Codex 协作协议

版本：v2-threaded

## 核心规则

1. 一个协作任务只使用一个 `.ai-collab/threads/*.md` 文档。
2. 双方只在同一个 thread 文件末尾追加 round。
3. signal 文件必须指向 thread 和最新 round。
4. 接收方默认只处理 signal 指定/latest round，必要时才回看历史。
5. 分工后必须先 kickoff 确认开工。
6. 不抢对方已明确负责的工作。
7. 修改分工必须先协商确认。
8. 任务完成必须追加 closing round，并说明对方无需继续等待。
```

## Thread Template

```markdown
---
conv_id: collab-YYYYMMDD-NNN
topic: Task title
status: waiting_claude
created_at: YYYY-MM-DD HH:mm:ss
updated_at: YYYY-MM-DD HH:mm:ss
---

## Round 1 - Codex - task

User asked:

```text
...
```

Project context:

- ...

Please propose a plan and task split.
```

## Kickoff Template

Use this after Claude proposes a split and before implementation.

```markdown
## Round N - Codex - kickoff

确认接受分工。

Codex 负责：
- ...

Claude 负责：
- ...

Codex 现在开始实现自己负责的部分。完成后会在本 thread 追加实现结果，并写 `signal/codex-ready` 通知 Claude 审查。
```

If the split is unsafe:

```markdown
## Round N - Codex - coordination

当前分工可能导致文件冲突或依赖阻塞：

- ...

建议调整为：

- Codex 负责 ...
- Claude 负责 ...

请确认后我再开始实现。
```

## Implementation Template

```markdown
## Round N - Codex - implementation

已完成 Codex 负责项：

- ...

修改文件：

```text
path/to/file
```

验证：

- ...

请 Claude 审查最新 round 和相关 diff。重点看：

1. ...
2. ...
```

## Review Handling

When Claude reviews:

- If it says pass, append closing.
- If it requests changes, implement only Codex-owned changes unless Claude explicitly transfers ownership.
- If the requested changes touch Claude-owned work, append a coordination round first.

## Closing Template

```markdown
## Round N - Codex - closing

任务已完成，并已向用户汇报。

完成内容：

- ...

验证：

- ...

遗留风险：

- none known

状态：done。Claude 无需继续等待本任务。
```

Also update frontmatter:

```yaml
status: done
updated_at: YYYY-MM-DD HH:mm:ss
```

Then write `signal/codex-ready`:

```text
Thread updated: .ai-collab/threads/YYYYMMDD-HHMMSS-topic.md
Next reader: claude
Round: N
Status: done
```

## Signal Parsing

Signal fields are line-oriented and intentionally simple:

```text
Thread updated: .ai-collab/threads/20260515-191800-snake-upgrade.md
Next reader: codex
Round: 4
Status: review passed
```

Rules:

- Treat `Thread updated` as the canonical path.
- Treat `Round` as the default unit of context.
- Use the latest round only when `Round` is absent.
- Delete only the consumed ready signal, not the thread.
- If `.ai-collab` is not under the current project root, set `AI_COLLAB_ROOT` for helper scripts so both agents resolve the same location.

## Common Failure Recovery

If Claude writes to a second thread for the same task:

1. Read the second thread.
2. Append a closing round to it that redirects to the canonical thread.
3. Continue in the canonical thread.

If a side forgets to signal:

1. Append a reminder round or write the missing signal.
2. Keep the thread as the source of truth.

If Codex accidentally implements Claude-owned work:

1. Do not hide it.
2. Append a process note in the thread.
3. Update the protocol if needed.
4. Avoid repeating the mistake in the next task.
