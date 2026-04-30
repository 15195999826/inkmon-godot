# .feature-dev/

inkmon-godot 项目 feature 开发流的执行 checkpoint。一次只追踪一个 feature 目标。

## 文件职责

| 文件 | 角色 |
|---|---|
| `Current-State.md` | 当前 baseline 事实快照（已落地的能力、已知约束）|
| `Next-Steps.md` | 执行游标：当前目标 / 下一步 / 非目标 / 验收准则 |
| `Progress.md` | 状态 + evidence（命令、artifact 路径、smoke 结果、残余风险）|
| `task-plan/README.md` | 阶段拆分 + 收口条件 |
| `Autonomous-Work-Protocol.md` | `/autonomous-feature-runner` 自治协议补丁 |
| `archive/<YYYY-MM-DD-slug>/` | 已完成 feature 的归档快照 |

## 配套 skill

- `/next-feature-planner` — 写本目录文档（规划阶段）
- `/autonomous-feature-runner` — 按 `Next-Steps.md` 自动开发（实现阶段）

任何时刻只允许有一个 active 目标。当 `Next-Steps.md` 标记"已完成系统功能验收，等待用户确认下一个 feature"时，下一轮才能开新 feature。
