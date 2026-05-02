# Next Steps — 2026-05-02 (等待用户确认下一个 feature)

## 当前状态

**已完成系统功能验收, 接下来等待用户确认下一个 feature 开发。**

上一个 sub-feature: **RTS Auto-Battle M2.2 — AI 对手 (Computer Player)** ✅ done + archived (2026-05-02)
- 1 phase 4 子任务 (E.1-E.4) 全过, 6/6 AC PASS, 14/14 validation 全套 0 漂移
- bit-identical replay deep-equal M2.1 末态 (E10 决策保旧 12 项 smoke 不破)
- archive: `archive/2026-05-02-rts-m2-2-ai-opponent/`
- 实测末态: smoke_ai_vs_player_full_match 600 tick, ai_barracks=1 / ai_units_spawned=4 / ai_unit_to_ct_attacks=9

更前 sub-feature: M2.1 Economy ✅ done + archived (2026-05-02; archive `archive/2026-05-02-rts-m2-1-economy/`)

## 候选下一个 feature (用户决定)

| 候选 | 状态 | 文档入口 |
|---|---|---|
| **RTS M2.3 — UI / HUD / Build Panel / 关卡** | 🔒 deferred (M2.x 路线图末项) | [`task-plan/m2-roadmap.md`](task-plan/m2-roadmap.md) §M2.3 |
| **RTS M3 — 后续 milestone** | 待规划 | 用户可提需求, 走 `/next-feature-planner` 启动 |
| **新 milestone / 旁支 sub-feature** | 待规划 | 用户提需求, `/next-feature-planner` 写新 baseline |

## 等待动作

请用户在以下选项中选一个:
1. 启动 M2.3 (UI / HUD / build panel / 关卡): 走 `/next-feature-planner` 写 M2.3 baseline 文档, 然后 `/autonomous-feature-runner` 推进
2. 启动旁支 sub-feature (e.g. AI 难度档位 / 多兵种偏好 / 防御阵型 等 M2.2 增量): 走 `/next-feature-planner`
3. 切到新 milestone (M3 / 其他方向): 用户描述目标, 走 `/next-feature-planner`

## 文档生命周期

- `Current-State.md` 已更新到 M2.2 末态 baseline (用作下一 sub-feature 的出发点 fact 快照)
- `Progress.md` 是 M2.2 final state, 含全套 evidence 路径 / commit hash / archive 引用
- 下一 sub-feature 启动时 `/next-feature-planner` 会:
  - 创建 `task-plan/<new-slug>/README.md`
  - 重写 `Next-Steps.md` (当前目标 / 下一步 / 验收准则)
  - 重写 `Progress.md` (新 checklist)
  - 在 `Current-State.md` 内追加新 sub-feature 描述 (上一 sub-feature 的 baseline 块仍保留)
