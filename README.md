# Codex Claude Code Multi-Agent Collaboration

通过共享文件系统，让 Codex 和 Claude Code 在同一个项目里低成本协作。

这个仓库是一个给 Codex 和 Claude Code 共同使用的协作 skill 包，同时也包含 Claude Code 端需要复制到目标项目的 hook 配置和轮询脚本。核心协议放在 `SKILL.md`，更详细的协作模板和 Claude Code 端配置放在 `references/`。它适合在用户希望“Codex 和 Claude Code 协作完成某个软件任务”时使用。

## 解决什么问题

Codex 和 Claude Code 通常运行在不同会话里，直接靠用户来回复制上下文会很累，也容易丢信息。这个 skill 用一个共享的 `.ai-collab/` 目录做中转：

- 一个任务对应一个 thread Markdown 文件。
- 双方只在 thread 末尾追加 round。
- `signal/` 文件负责提示对方有新消息。
- 分工后必须先 kickoff 确认，避免抢同一份代码。
- 完成后必须 closing，明确对方不用继续等待。

## 仓库结构

```text
.
├── SKILL.md                         # Codex skill 主说明
├── agents/
│   └── openai.yaml                  # Codex app 中的展示信息
├── references/
│   ├── protocol.md                  # thread、signal、kickoff、closing 模板
│   └── claude-code-setup.md         # Claude Code 端 hook / cron 配置说明
└── scripts/
    ├── settings.local.json          # Claude Code hook 配置示例
    └── wait-cycle.sh                # Claude Code 端轮询/读取 signal 脚本
```

## 需要装在哪里

推荐同时装到 Codex 和 Claude Code 的 skill 目录里，并让两边读同一套协议：

1. Codex 侧：把本目录作为 Codex skill 安装或注册，让 Codex 知道如何创建 thread、写 signal、等待 Claude、kickoff 和 closing。
2. Claude Code 侧：把同一个 skill 安装或注册到 Claude Code 可读取的 skill 位置，让 Claude Code 知道同一套 thread/signal 协议、round 格式和分工规则。
3. 目标项目侧：复制 `scripts/wait-cycle.sh` 和 Claude Code hook 配置，让 Claude Code 能发现 Codex 写入的 signal，并读写同一个 `.ai-collab/` 协作目录。

换句话说：skill 应该两边都装，用来统一“怎么协作”；hook/script 是 Claude Code 侧额外需要的唤醒和轮询机制，用来解决“怎么知道对方发了新 round”。

## 快速使用

在需要协作的目标项目里创建共享目录：

```text
<project>/.ai-collab/
├── COLLAB.md
├── threads/
├── signal/
├── shared/
├── tasks/
├── inbox/
└── outbox/
```

然后把本仓库的 Claude Code 端脚本复制到目标项目：

```text
scripts/wait-cycle.sh      -> <project>/.ai-collab/wait-cycle.sh
scripts/settings.local.json -> <project>/.claude/settings.local.json
```

如果目标项目已经有 `.claude/settings.local.json`，不要直接覆盖；把其中的 hook 配置合并进去。

## 协作流程

1. 用户提出需要 Codex 和 Claude Code 协作的任务。
2. Codex 确认 `.ai-collab` 的共享位置。
3. Codex 创建 `.ai-collab/threads/YYYYMMDD-HHMMSS-topic.md`。
4. Codex 写入任务 round，并创建 `.ai-collab/signal/codex-ready`。
5. Claude Code 读取 signal 指向的 thread 和 round，追加计划或审查 round。
6. Claude Code 创建 `.ai-collab/signal/claude-ready`。
7. Codex 读取 Claude 最新 round，确认分工后 kickoff，再开始实现自己负责的部分。
8. 任务结束时，Codex 追加 closing round，更新状态为 `done`，并通知 Claude 不用继续等待。

详细模板见 [`references/protocol.md`](references/protocol.md)。

## Claude Code 端配置

Claude Code 可以通过 `UserPromptSubmit` hook 或 cron 定期运行：

```bash
bash .ai-collab/wait-cycle.sh
```

如果 `.ai-collab` 不在 Claude Code 当前项目根目录，需要显式设置 `AI_COLLAB_ROOT`：

```bash
AI_COLLAB_ROOT=/d/claude_code/my-project bash /d/claude_code/my-project/.ai-collab/wait-cycle.sh
```

Windows Git Bash 中，`D:\claude_code` 通常写作 `/d/claude_code`。

完整说明见 [`references/claude-code-setup.md`](references/claude-code-setup.md)。

## 关键约定

- 新任务优先使用 `threads/`，`inbox/` 和 `outbox/` 只保留给旧流程兼容。
- signal 文件必须写清楚 thread 路径、下一位 reader、round 号和状态。
- 接收方默认只处理 signal 指定的最新 round，除非任务需要才回看历史。
- Claude 提出分工后，Codex 不能直接实现，必须先追加 kickoff round。
- 不要实现已经明确分给对方的工作；需要调整分工时先追加 coordination round。
- 完成时不能只告诉用户，还要追加 closing round 并 signal 对方。

## 安装 Skill

把本目录作为 skill 分别放到 Codex 和 Claude Code 的 skills 目录中，或按各自的本地 skill 管理方式注册。注册后，当用户提到 “和 Claude Code 协作完成” 或类似需求时，双方都能读取 `SKILL.md` 中的协议并按同一套规则协作。

安装 skill 只解决协议理解。Claude Code 仍然需要在每个要协作的目标项目里配置 hook 或 cron，否则它不会自动发现 Codex 写入的 signal。

## 注意

这个仓库本身不包含目标项目代码，也不会自动启动 Claude Code。它提供的是一套共享文件协议、模板和辅助脚本。真正的协作目录 `.ai-collab/` 应该创建在双方都能读写的目标项目或共享路径中。
