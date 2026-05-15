# Claude Code 端配置

让 Claude Code 通过共享文件系统与 Codex 协作。

## 1. 项目级 Hook 配置

在项目根目录创建 `.claude/settings.local.json`：

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .ai-collab/wait-cycle.sh"
          }
        ]
      }
    ]
  }
}
```

`UserPromptSubmit` 在用户每次发消息时触发，运行 `wait-cycle.sh` 检查 Codex 是否有新消息。

如果 `.ai-collab` 不在 Claude Code 当前项目根目录，请显式设置 `AI_COLLAB_ROOT`。示例：

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "AI_COLLAB_ROOT=/d/claude_code bash /d/claude_code/.ai-collab/wait-cycle.sh"
          }
        ]
      }
    ]
  }
}
```

在 Windows Git Bash 中，`D:\claude_code` 通常写作 `/d/claude_code`。

## 2. wait-cycle.sh

将 `scripts/wait-cycle.sh` 复制到项目的 `.ai-collab/` 目录。脚本负责：

- 检测 `signal/codex-ready`
- 解析 signal 中指向的 thread 文件路径和 round 号
- **只提取最新 round**（不读历史 round，节省 token）
- 兜底检测：扫描 inbox/ 和 threads/ 中自上次检查后修改的文件
- 消费 signal（读后删除）

## 3. 协作启动流程

用户对 Claude Code 说"和 Codex 协作完成：xxx"后：

1. Claude 启动 CronCreate 监控（建议 `*/1 * * * *`，每分钟检查 signal）
2. Claude 读取 Codex 创建的 thread → 追加 plan/review round
3. 追加后写 `signal/claude-ready`，注明 thread 路径和 round
4. 任务完成后 `CronDelete` 停止监控

Cron 示例：
```
CronCreate cron="*/1 * * * *" recurring=true durable=true
prompt="协作监控：运行 bash .ai-collab/wait-cycle.sh。如果输出包含'Round'→ 读最新 round → 回复追加到 thread → 写 signal/claude-ready → 删 signal/codex-ready。如果输出'WAITING'→ 不做任何事。"
```

## 4. 目录结构

```
project/
├── .ai-collab/
│   ├── COLLAB.md          # 协议文档
│   ├── wait-cycle.sh      # Claude 端检测脚本
│   ├── .last-check        # 时间戳（自动生成）
│   ├── threads/           # 协作 thread 文件
│   ├── signal/            # codex-ready / claude-ready
│   ├── shared/            # 共享产物
│   ├── tasks/             # 任务追踪
│   ├── inbox/             # 旧协议兼容
│   └── outbox/            # 旧协议兼容
└── .claude/
    └── settings.local.json
```

## 5. 注意事项

- 建立协作前，先确认 `.ai-collab` 的共享位置；Codex 和 Claude Code 必须读写同一个目录
- Claude Code 无法被外部文件事件直接唤醒，依赖 `UserPromptSubmit` hook（用户发消息）或 `CronCreate`（定时轮询）
- 协作期间保持 cron 运行，结束后立即 `CronDelete`
- wait-cycle.sh 使用 `.last-check` 时间戳避免重复检测旧消息
- 默认只读 thread 中最新的 round，除非需要上下文时才回看历史
