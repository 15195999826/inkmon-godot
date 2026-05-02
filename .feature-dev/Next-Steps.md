# Next Steps — 2026-05-02 (RTS M2.1 Economy — Phase C 启动 active)

## 当前目标

**RTS Auto-Battle M2.1 — Economy (Worker Harvest, gold + wood) — Phase C: Harvest Activity + Drop-off Loop**

经济闭环核心: `RtsHarvestActivity` (worker 走到 ResourceNode → 累积 harvest_progress → 满 carry_capacity 切 ReturnAndDrop) + `RtsReturnAndDropActivity` (worker 走到最近己方 crystal_tower → procedure.add_team_resources → 切回 Harvest) + `RtsHarvestStrategy` (worker autonomous 行为, idle/carrying-empty 时找最近未耗尽 ResourceNode) + 新 `smoke_harvest_loop`。

> Phase C 完整 plan: [`task-plan/m2-1-economy/phase-c-harvest-activity.md`](task-plan/m2-1-economy/phase-c-harvest-activity.md)
> Phase A + B 收口归档: [`task-plan/m2-1-economy/phase-a-multi-resource.md`](task-plan/m2-1-economy/phase-a-multi-resource.md) + [`task-plan/m2-1-economy/phase-b-resource-nodes.md`](task-plan/m2-1-economy/phase-b-resource-nodes.md) + `Progress.md` §Phase A/B
> M2.1 整体规划: [`task-plan/m2-1-economy/README.md`](task-plan/m2-1-economy/README.md)
> M2 整体路线图: [`task-plan/m2-roadmap.md`](task-plan/m2-roadmap.md)

## 验收准则 (Phase C, 7 条)

详见 [`task-plan/m2-1-economy/phase-c-harvest-activity.md`](task-plan/m2-1-economy/phase-c-harvest-activity.md) §Acceptance:

- **AC1** `RtsAutoBattleProcedure.add_team_resources(team_id, delta: Dictionary)` 对称 spend
- **AC2** 新 `RtsHarvestActivity` (extends RtsActivity; nav 接敌 + 累积 harvest_progress + 满载切换)
- **AC3** 新 `RtsReturnAndDropActivity` (找己方最近 is_drop_off 建筑 + 抵达调 add_team_resources)
- **AC4** 新 `RtsHarvestStrategy` (carrying 非空 → ReturnAndDrop; 否则找最近未耗尽 ResourceNode → Harvest; 找不到 → Idle)
- **AC5** `RtsAIStrategyFactory.get_strategy(WORKER)` 切到 `_harvest_strategy`
- **AC6** 新 `smoke_harvest_loop.tscn` PASS (5 worker + 1 gold + 1 wood + 双方 ct 不死, 跑 600 tick → gold 增长 ≥ 100 + wood 增长 ≥ 100 + 至少 1 worker 完整 cycle)
- **AC7** Validation 全套不退化 (LGF 73/73 + 既有 6 RTS smoke + 2 replay smoke + frontend smoke 0 漂移; Phase B smoke_resource_nodes 因 HarvestStrategy 切换可能需要调整, 详见 phase-c §风险表第 1 行)

## 设计决策 (用户 2026-05-02 已确认)

- **D6**: Drop-off = 复用 `crystal_tower` (双方起手就有, ct 加 `is_drop_off=true` 字段)
- **D7**: Worker AI = 找最近未耗尽 `ResourceNode` (round-robin 决定性 tiebreak by actor_id)
- **D8**: Worker 出生 = hardcode smoke/demo 起手 spawn (不加 SpawnWorkerCommand)

phase-c-harvest-activity.md §设计决策 D9-D16 是实现细节决策 (Activity ↔ procedure 通信走 world.bind_procedure / 单一 Activity 自管 nav / 无锁多 worker 同 node / HARVEST_RADIUS=32px / per-tick 累积 progress 模型 等), 由 `/autonomous-feature-runner` 执行时按文档落地; 实现中若发现需偏离, 先停下来跟用户对齐再改。

## 下一步

**Step 1 — C.1**: 改 `RtsWorldGameplayInstance` + `RtsAutoBattleProcedure` 通信打通

具体动作:
1. 编辑 `addons/logic-game-framework/example/rts-auto-battle/core/rts_world_gameplay_instance.gd`
   - 加字段 `procedure: RtsAutoBattleProcedure = null`
   - 加方法 `bind_procedure(p: RtsAutoBattleProcedure) -> void`
2. 编辑 `addons/logic-game-framework/example/rts-auto-battle/core/rts_auto_battle_procedure.gd`
   - `_init` 末尾调 `world.bind_procedure(self)`
   - 加 `add_team_resources(team_id: int, delta: Dictionary) -> void` (对称 spend_team_resources; 详见 phase-c §C.1)
3. 跑 import + LGF 73/73 + Phase B smoke_resource_nodes + 4v4 main 验证 0 漂移
4. 转到 Step 2 — C.2 (RtsUnitActor.carrying 字段)

## 非目标 (本轮 Phase C 不做; 留 Phase D 或后续)

- ❌ Cost 重平衡 / starting_resources 调值 (Phase D)
- ❌ smoke_economy_demo full cycle (Phase D)
- ❌ demo_rts_frontend 加 worker spawn / 资源采集视觉 (Phase D)
- ❌ SpawnWorkerCommand 玩家可造 worker (M2.3 或 后续 phase)
- ❌ AI 对手 (M2.2 sub-feature, deferred)
- ❌ Build Panel UI / 多 building_kind 选择 (M2.3 sub-feature, deferred)

## F6 视觉验证

Phase C 仅 logic 层 + headless smoke 验证 (与 Phase B 一致); demo_rts_frontend 不动 (worker 不出现在 demo 起手 spawn 列表)。Phase D 启动 smoke_economy_demo + demo_rts_frontend worker spawn 时再加 F6 视觉验证。

## 启动后续 Phase / 新 sub-feature

Phase C 收口后:
- 下一轮 (用户确认): 启动 **Phase D** (Cost Rebalance + smoke_economy_demo) — 写 `phase-d-cost-rebalance.md` + 切 Next-Steps.md
- Phase D 完成后: M2.1 Economy 整体收口 → 归档至 `.feature-dev/archive/<YYYY-MM-DD>-rts-m2-1-economy/`
- 整个 RTS M2.1 完成后用户决定是否启动 M2.2 (AI 对手) 或 M2.3 (UI HUD)

要在 RTS M2.1 完成后开新的非延续 feature, 调 `/next-feature-planner`。
