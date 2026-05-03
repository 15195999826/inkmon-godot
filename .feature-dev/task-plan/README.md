# Task Plan — 等待下一个 feature

> **Active feature**: 暂无。上一个 sub-feature **RTS Auto-Battle M2.2 — AI 对手 (Computer Player)** 已完成系统功能验收并归档。
>
> **当前状态**: 等待用户确认下一个 feature 后，由 `/next-feature-planner` 重写本目录为新的执行计划。

---

## 当前索引

| 文档 | 角色 | 状态 |
|---|---|---|
| [`m2-roadmap.md`](m2-roadmap.md) | M2 整体路线图 | 稳定 spec, 供下一轮 planning 参考 |
| [`../archive/2026-05-02-rts-m2-2-ai-opponent/`](../archive/2026-05-02-rts-m2-2-ai-opponent/) | M2.2 AI 对手完整归档 | ✅ done |
| [`../archive/2026-05-02-rts-m2-1-economy/`](../archive/2026-05-02-rts-m2-1-economy/) | M2.1 Economy 完整归档 | ✅ done |
| [`../archive/2026-05-02-rts-m1-refactor/`](../archive/2026-05-02-rts-m1-refactor/) | RTS M1 重构归档 | ✅ done |

---

## 下一步

等待用户选择下一个 feature。确定目标后，运行 `/next-feature-planner`：

1. 读取 `Current-State.md`、`Next-Steps.md`、`Progress.md` 和本目录。
2. 把本文件替换为新 feature 的 active task plan。
3. 写入新目标、非目标、验收准则、阶段拆分和 handoff prompt。

不要在本文件继续维护已完成 feature 的活跃计划；已完成内容以 `archive/` 为准。
