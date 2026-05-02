# Next Steps — 2026-05-02 (RTS M2.1 Economy — Phase A + B ✅ 收口; Phase C 启动等待用户确认)

## 当前目标

**RTS Auto-Battle M2.1 — Economy (Worker Harvest, gold + wood) — Phase B ✅ 收口**

Phase A + B 已收口 (multi-resource cost dict 化 + RtsResourceNode actor + UnitClass.WORKER + idle 行为 + smoke_resource_nodes), 13/13 AC PASS, 11/11 validation 全套 PASS, 0 行为漂移。等待用户确认是否启动 **Phase C — Harvest Activity + Drop-off Loop** (经济闭环核心: HarvestActivity / ReturnAndDropActivity / HarvestStrategy / smoke_harvest_loop)。

> M2.1 完整规划: [`task-plan/m2-1-economy/README.md`](task-plan/m2-1-economy/README.md)
> Phase B 收口归档: [`task-plan/m2-1-economy/phase-b-resource-nodes.md`](task-plan/m2-1-economy/phase-b-resource-nodes.md) (AC 全部 [x]) + `Progress.md` §Phase B
> Phase A 收口归档: [`task-plan/m2-1-economy/phase-a-multi-resource.md`](task-plan/m2-1-economy/phase-a-multi-resource.md) + `Progress.md` §Phase A
> M2 整体路线图: [`task-plan/m2-roadmap.md`](task-plan/m2-roadmap.md)

## Phase B 收口结论 (2026-05-02)

- ✅ AC1-AC6 全过 (RtsResourceNodeConfig + RtsResourceNode actor + RtsResourceNodes 工厂 + UnitClass.WORKER + RtsAIStrategyFactory worker 路径 + smoke_resource_nodes)
- ✅ 11/11 validation 全套 PASS (LGF 73/73 + 既有 6 smoke + 新 smoke_resource_nodes + 2 replay smoke + frontend smoke)
- ✅ bit-identical replay 0 漂移 (frames=9 events=20 deep-equal); det tick_diff=0; 4v4 main smoke ticks=347 与 Phase A 末态完全一致
- ✅ smoke_resource_nodes: ticks=200 alive_workers=5 gold_amount=1500 wood_amount=1500 max_drift=0.00 (worker 完全不动 — 因 mask=NONE → AutoTargetSystem skip → cached_target_id 始终空 → IdleActivity)

## 下一步 — 等待用户确认

Phase B 已收口, 不在 `/autonomous-feature-runner` 自治范围内继续推进。等待用户:

1. **直接启动 Phase C** — 用户调 `/autonomous-feature-runner` 时如果 Next-Steps.md 已切到 Phase C 的 active goal + 写好 `phase-c-harvest-activity.md` 文档, 自治可继续
2. **暂停 / 切其它 sub-feature** — 用户可调 `/next-feature-planner` 重写当前目标, 或在外部 commit / push 后再启动 Phase C

> **Phase C 启动前要求** (用户确认后, 由 planner / 手动写入):
> - 在 `task-plan/m2-1-economy/` 写 `phase-c-harvest-activity.md` (子任务清单 + AC + 设计决策 + 风险表)
> - 更新本 `Next-Steps.md` 当前目标 → Phase C, 子任务 Step 1
> - 更新 `Progress.md` 切到 Phase C 子任务 checklist

Phase C 设计要点 (起草, 由 planner 在启动前细化):
- 新 `RtsHarvestActivity` (worker → 资源节点 → harvest_progress 累积 → carrying = capacity → 切 ReturnAndDrop)
- 新 `RtsReturnAndDropActivity` (worker → 最近 drop-off → 加 team_resources → 切回 Harvest)
- 新 `RtsHarvestStrategy` (worker autonomous 行为, idle 时找最近 ResourceNode)
- Drop-off 建筑: 倾向复用 crystal_tower (双 ct 起手就有, 不新加 town_hall)
- 新 smoke_harvest_loop (5 worker + 1 gold + 1 wood + 跑 N tick → team_resources gold + wood 双增长 ≥ X)

## 非目标 (本轮 M2.1 后续 phase 仍不做)

- ❌ AI 对手 (computer player) 启动 (M2.2 sub-feature, deferred)
- ❌ Build Panel UI / 多 building_kind 选择 (M2.3 sub-feature, deferred)
- ❌ Headscale / 网络多人 (远期 M3+)

## F6 视觉验证

Phase B 仅 logic 层 + headless smoke 验证; demo 不动 (worker 不出现在 demo_rts_frontend 起手 spawn 列表)。Phase D 启动 smoke_economy_demo 时再加视觉验证。

## 启动后续 Phase / 新 sub-feature

本轮 Phase B 已收口:

- 下一轮 (用户确认): 启动 **Phase C** (Harvest Activity + Drop-off Loop) — 在 Next-Steps.md 切到 active, 写 `phase-c-harvest-activity.md`
- Phase C/D 完成后: M2.1 Economy 整体收口 → 归档至 `.feature-dev/archive/<YYYY-MM-DD>-rts-m2-1-economy/`
- 整个 RTS M2.1 完成后用户决定是否启动 M2.2 (AI 对手) 或 M2.3 (UI HUD)

要在 RTS M2.1 完成后开新的非延续 feature, 调 `/next-feature-planner`。
