# Next Steps — 2026-05-02 (RTS M2.1 Economy — Phase C ✅ 收口; 等待用户确认启动 Phase D)

## 当前状态

**RTS Auto-Battle M2.1 — Economy (Worker Harvest, gold + wood)** 进度:
- ✅ Phase A 收口 (Multi-Resource Foundation, 7/7 AC)
- ✅ Phase B 收口 (Resource Nodes + Worker Class, 6/6 AC)
- ✅ **Phase C 收口** (Harvest Activity + Drop-off Loop, 7/7 AC + 13/13 validation 全过 0 漂移 + simplify pass clean) ← 本轮完成
- 🔒 **Phase D pending** (Cost Rebalance + smoke_economy_demo, 等待用户确认启动)

> Phase C 收口结论: [`task-plan/m2-1-economy/phase-c-harvest-activity.md`](task-plan/m2-1-economy/phase-c-harvest-activity.md) (AC 全部 [x] + Simplify Pass 段) + `Progress.md` §Phase C
> Phase D skeleton: [`task-plan/m2-1-economy/phase-d-cost-rebalance.md`](task-plan/m2-1-economy/phase-d-cost-rebalance.md) (Phase C 收口时落 skeleton; D17/D18/D19 决策待用户启动时定)
> M2.1 整体规划: [`task-plan/m2-1-economy/README.md`](task-plan/m2-1-economy/README.md)
> M2 整体路线图: [`task-plan/m2-roadmap.md`](task-plan/m2-roadmap.md)

## 下一步

**等待用户确认启动 Phase D** (Cost Rebalance + smoke_economy_demo)。

Phase D scope (m2-1-economy/README.md §Phase D 已 detail):
- Building cost 重平衡 (例: barracks `{"gold": 80, "wood": 50}`; archer_tower `{"gold": 60, "wood": 100}` — 数值待 D17 用户确认)
- starting_resources 调值 (起手不够直接造, 必须 worker harvest 补)
- 新 `smoke_economy_demo` (worker harvest → 资源到达 cost → enqueue PlaceBuildingCommand barracks → barracks spawn melee → melee 攻 ct)
- 编辑器 F6 视觉验证: `demo_rts_frontend.tscn` 起手 spawn worker + node, 玩家可见经济闭环视觉链路

启动 Phase D 时:
1. 用户在 `task-plan/m2-1-economy/phase-d-cost-rebalance.md` 内 finalize D17/D18/D19 (cost 数值 / smoke 时长阈值 / demo 起手 spawn 列表)
2. Next-Steps.md 切到 "Phase D 启动 active"
3. Progress.md 切到 Phase D 子任务清单 (空)
4. 调 `/autonomous-feature-runner` 进入 Phase D Step 1

## Phase C 收口最终验证

13 项 validation 全套 0 漂移 (与 Phase B 末态完全一致除了新加 smoke_harvest_loop):

| 测试 | 结果 |
|---|---|
| LGF 73/73 unit tests | 73/73 PASS |
| smoke_rts_auto_battle 4v4 main | ticks=347 attacks=74 melee_max_dist=24.00 (bit-identical) |
| smoke_castle_war_minimal | ticks=193 left_win unit_to_building_attacks=4 archer_anti_air=1 |
| smoke_player_command | ticks=30 log_entries=3 gold=100 wood=0 |
| smoke_player_command_production | ticks=600 left_spawned=7 max_eastward=254.74 gold=100 |
| smoke_production | ticks=600 left_spawned=7 right_spawned=7 max_left_eastward=118.51 |
| smoke_crystal_tower_win | ticks=2 left_win |
| smoke_resource_nodes (Phase C 重定位) | ticks=200 alive_workers=5 max_drift=0.00 (HarvestStrategy fallback to IdleActivity) |
| **smoke_harvest_loop (新)** | ticks=600 alive_workers=5 team_gold=140 team_wood=212 cycle_workers=5 |
| smoke_replay_bit_identical | seed=42 commands=2 frames=9 events=20 deep-equal |
| smoke_determinism | run1=run2=(left_win, 347) tick_diff=0 |
| smoke_frontend_main | visualizers=10 alive_after_3.0s=10 |

Simplify pass (SKILL.md §7a-7c) 跑完后再跑 13 项仍 0 漂移 (4v4 ticks=347 / replay frames=9 events=20 / harvest_loop gold=140 wood=212 完全一致)。

## Simplify Pass 总结 (SKILL.md §7a-7c)

1. **Nav refresh helper 抽取** — `NAV_REFRESH_INTERVAL` / `_time_since_nav_refresh` / `_last_set_target` / `_should_refresh_nav` / `_refresh_nav_target` 上推到 `RtsActivity` 基类; attack/harvest/return 三 Activity 共用 (~30 行重复减除)
2. **`RtsUnitActor.get_carry_total()` helper** — harvest_strategy + harvest_activity 两处 `_carry_total` 抽到 actor (单点真相)
3. **`is_drop_off` into `RtsBuildingConfig.StatBlock`** — 与 `is_crystal_tower` 同模式; 工厂 `_create_from_kind` 统一注入
4. **`HarvestActivity` stats cache** — `_carry_capacity` / `_harvest_speed` 在 `on_first_run` 缓存 (避免 tick 每帧 `get_stats` 分配 StatBlock + Array; 5 worker × 30Hz = 150 alloc/sec → 0)
5. **Dead `_intent_arriving = true` write 删除** — ReturnAndDrop 抵达瞬间设 true 后立刻 return false → DONE → controller is_done 返 "idle", 永远不可观察

13 项 validation 全套 simplify 后再跑 0 漂移 (上面表格 evidence 即 simplify 后)。

## 启动后续 Phase / 新 sub-feature

- 下一轮 (用户确认): 启动 **Phase D** — 在 phase-d-cost-rebalance.md 内 finalize D17/D18/D19 + 调 `/autonomous-feature-runner`
- Phase D 完成后: M2.1 Economy 整体收口 → 归档至 `.feature-dev/archive/<YYYY-MM-DD>-rts-m2-1-economy/`
- 整个 RTS M2.1 完成后用户决定是否启动 M2.2 (AI 对手) 或 M2.3 (UI HUD)

要在 RTS M2.1 完成后开新的非延续 feature, 调 `/next-feature-planner`。
