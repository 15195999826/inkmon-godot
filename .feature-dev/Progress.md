## Progress — RTS Auto-Battle M1 架构重构

**Status**: Phase 2 in progress — **P2.1 + P2.2 + P2.3 + P2.4 done (4/8 sub-tasks)**, 不退化

最近更新: 2026-05-01 (P2.4 完成)

---

## Phase 2 验收准则 checklist

详见 [`task-plan/phase-2-core-systems.md`](task-plan/phase-2-core-systems.md) §收口条件 (10 AC)。

- [x] **AC1 — Activity 系统**: `smoke_activity_chain` PASS; UnitController 内已无 string FSM
  - 命令: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_activity_chain.tscn > /tmp/p2_1_chain.txt 2>&1`
  - Evidence: `/tmp/p2_1_chain.txt` → `phase1_ticks=26, pre_cancel=(144.83, 73.69), settled=(144.83, 73.69), drift=0.00`; PASS - chain order + cancel propagation + nav cleanup
  - 命令: `grep -rn '_last_intent_action\|_make_idle_intent\|_make_attack_intent\|_make_approach_intent' addons/logic-game-framework/example/rts-auto-battle/` → 仅命中 design note 注释 (Progress.md 之外 0 处代码引用)
  - Evidence: `RtsUnitController` 字段从 `_last_intent_action: String` → `current_activity: RtsActivity`; `RtsAIStrategy.decide` 返回 `RtsActivity` (不再 Dictionary Intent)
- [x] **AC2 — 避障四层(前 3 层)**: `smoke_steering` 8 单位散开 ✅ PASS (P2.2); `smoke_stuck_recovery` 包围降级 ✅ PASS (P2.3)
  - 命令 A (steering): `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_steering.tscn > /tmp/p2_2_steering.txt 2>&1`
  - Evidence: `/tmp/p2_2_steering.txt` → `min_pair_dist OK; movers=8/8; total_traveled=2746.7 px; final_spread=(54.0, 75.6); buckets=3`; PASS - 8 单位 ≥ 2r-0.5
  - 命令 B (stuck): `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_stuck_recovery.tscn > /tmp/p2_3_stuck.txt 2>&1`
  - Evidence: `/tmp/p2_3_stuck.txt` → `abandoned=3/3 units; positions stable; intents=idle`; PASS - 3/3 包围单位 abandon command (>= 2 主断言达成); 位置漂移 < 5 px; controller.get_intent_action() == "idle"; wants_to_attack == false
  - 命令 C: `grep -rn 'RtsMinimalPushOut.resolve' addons/logic-game-framework/example/rts-auto-battle/{core,logic}/` → 0 处 (procedure 已切到 spatial_hash + steering); smoke_minimal_push_out 仍存自测算法 (Phase 1 baseline 不破)
- [x] **AC3 — AutoTargetSystem**: `smoke_auto_target` priority 标签生效 ✅ PASS (P2.4); 4v4 主 smoke 行为等价 (left_win 仍达成, 兵种行为 AC3 全过)
  - 命令 A: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_auto_target.tscn > /tmp/p2_4_auto_target.txt 2>&1`
  - Evidence: `/tmp/p2_4_auto_target.txt` → 5 子测试 PASS:
    1. **priority overrides distance**: archer (target_priorities=[{ranged:100},{melee:10}]) → 选远距 ranged (200px) 而非近距 melee (70px)
    2. **HOLD_FIRE**: stance=HOLD_FIRE 时 _cached_target_id 始终空 (即使预设 stale 也清掉)
    3. **DEFENSIVE**: 仅候选距离 ≤ 1.5×attack_range (180px for RANGED) 内的敌人; 250px 外敌人不被选, 加近敌后立即切换
    4. **no-priority fallback**: 默认 target_priorities=[] → 退化为最近 (与 _select_nearest 同序, P1.5 行为兼容)
    5. **dead-cache immediate rescan**: cache 命中目标 mark_dead 后 1 个 tick 内 cache 切到其他敌人 (不等下个 RESCAN 周期)
  - 命令 B (4v4 行为): `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn > /tmp/p2_4_smoke_rts.txt 2>&1`
  - Evidence: `result=left_win ticks=347 attacks=74 (melee=32 ranged=42) deaths=6 melee_max_dist=24.00 ranged_max_dist=125.75 detoured=4`; PASS - 因 AutoTarget 让单位每 20 tick 重评目标, 战斗时长从 P2.3 的 239 → 347 ticks (合理: 之前 strategy 锁定首个 target, 现在会切换到威胁更高/更近的); AC3 (melee_max=24.00 / ranged 至少 1 长程) 仍全过, AC2 detour=4 仍存在
- [ ] **AC4 — Production**: `smoke_production` 兵营周期 spawn PASS
- [ ] **AC5 — Player Command + Crystal Tower**: `smoke_player_command` PASS; `smoke_crystal_tower_win` PASS
- [ ] **AC6 — Frontend Director 流式**: `smoke_director_streaming` PASS; frontend 0 处 `actor.position_2d` 直读
- [ ] **AC7 — AIR layer + 飞行单位**: `smoke_flying_units` PASS
- [ ] **AC8 — 城堡战争最小可玩 demo**: 编辑器 F6 跑 `demo_rts_frontend.tscn`, 玩家可放置建筑、塔被毁判胜负
- [x] **AC9 — 不退化** (P2.4 重新验证, 全部 P1 + P2.1-P2.4 smokes 仍 PASS):
  - 命令 A: `godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn > /tmp/p2_4_lgf.txt 2>&1` → `73/73 PASS`
  - 命令 B: `godot --headless --path . addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn > /tmp/p2_4_hex.txt 2>&1` → `结果: right_win` (exit 0; hex 不强制 winner 一致)
  - 命令 C: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn > /tmp/p2_4_smoke_rts.txt 2>&1` → `result=left_win ticks=347 attacks=74 (melee=32 ranged=42) deaths=6 melee_max_dist=24.00 ranged_max_dist=125.75 detoured=4`; PASS
    - 注: AutoTarget 每 20 tick 重评目标, 战斗时长从 P2.3 的 239 → 347 ticks (合理变化, 仍在 MAX_TICKS=1200 内分胜负); melee_max_dist=24.00 不变 (兵种行为 AC3 仍过)
  - 命令 D: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/replay/smoke_determinism.tscn > /tmp/p2_4_det.txt 2>&1` → `seed=12345, run1=run2=(left_win, 347), tick_diff=0`; **bit-equal** (P2.4 决定性顺序保证: AutoTargetSystem 内部不调 randf, 按 units 入参顺序 iterate, by_team 字典靠 Godot 4 insertion-order 语义保等价于 _get_enemies)
  - 全部 P1 + P2.1-P2.4 smokes: skeleton / nav / ai / attack / grid_pathfinding / minimal_push_out / activity_chain / steering / stuck_recovery / **auto_target** / frontend: all PASS
    - 命令: `godot --headless --path . <smoke>.tscn > /tmp/p2_4_<name>.txt 2>&1`
    - 关键 evidence: smoke_steering `8/8 movers, total_traveled=2746.7`; smoke_stuck_recovery `3/3 surrounded units abandoned`; smoke_activity_chain `phase1_ticks=26, drift=0.00`; smoke_grid_pathfinding `traveled=552.00 straight=400.00 max_y_dev=74.00`
- [ ] **AC10 — Bit-identical replay** (Phase 2 新增, P2.6+P2.7 落地)

---

## Phase 2 子任务进度

详见 [`task-plan/phase-2-core-systems.md`](task-plan/phase-2-core-systems.md) §Sub-tasks。

- [x] **P2.1 — Activity 系统 (OpenRA 风)**
  - 改动:
    - 新增 `logic/activity/activity.gd` (RtsActivity 基类: child + next + state QUEUED/ACTIVE/CANCELING/DONE; static advance driver — 父 supervisor 模式)
    - 新增 `logic/activity/idle_activity.gd` (RtsIdleActivity)
    - 新增 `logic/activity/move_to_activity.gd` (RtsMoveToActivity, 走 nav agent 抵达 target_pos)
    - 新增 `logic/activity/attack_activity.gd` (RtsAttackActivity, 自带 in-range/out-of-range 切换 + nav 接敌)
    - 新增 `logic/activity/attack_move_activity.gd` (RtsAttackMoveActivity 雏形, P2.4 AutoTarget 完整集成)
    - 重写 `logic/ai/rts_ai_strategy.gd` (decide 返回 RtsActivity, 删 _make_*_intent helpers)
    - 重写 `logic/ai/rts_basic_attack_strategy.gd` (返回 RtsAttackActivity 或 RtsIdleActivity)
    - 重写 `logic/controller/rts_unit_controller.gd` (current_activity 替代 _last_intent_action; reconcile + advance + bind_runtime)
    - 更新 `core/rts_auto_battle_procedure.gd` 注释 (Phase 2 P2.1 已落地, 不再是 forward-looking)
    - 新增 `tests/battle/smoke_activity_chain.{gd,tscn}` (chain primitive 单元测试 + cancel 传播 + nav cleanup)
  - Evidence: 见 AC1 + AC9 上方
- [x] **P2.2 — Spatial Hash + Steering(避障 1+2 层)**
  - 改动:
    - 重写 `logic/components/rts_nav_agent.gd` (P2.2 拆 movement: `compute_desired_velocity(dt)` 写 actor.velocity 不动 position; `integrate(dt)` 写 position += velocity * dt + 推进 waypoint, 含 steering 推过头时跳号; `tick(dt)` 保留作 backwards-compat full-step, 仅 smoke_navigation / smoke_grid_pathfinding 用)
    - 新增 `logic/movement/rts_spatial_hash.gd` (cell_size=64 桶索引; `update(actor_id, pos)` 增量更新 / `update_all(actors)` 批量同步 + 自动 unregister 死亡; `query_radius(center, radius)` 返回排序的候选 actor_id, 决定性 by id sort)
    - 新增 `logic/movement/rts_unit_steering.gd` (separation + deflection; SEPARATION_BUFFER=0 严格 r+r 阈值保 atk_range 接战; MAX_SEP_FRACTION=0.7 防 cluster 后侧单位被推完全反向; 静止单位也施 sep — 让抵达后 cluster 不重叠; deflection 仅作用于 moving units, 方向由 actor_id parity 决定 — 不调 randf)
    - 修改 `core/rts_auto_battle_procedure.gd` step 4 (P2.2 movement 三段管线): `_spatial_hash.update_all` → 4a 全单位 `compute_desired_velocity` → 4b 全单位 `RtsUnitSteering.apply` → 4c 全单位 `integrate`; **删除** `RtsMinimalPushOut.resolve` 调用 (steering 已包含 separation, 不再需要 fallback)
    - 修改 `logic/activity/move_to_activity.gd` + `attack_activity.gd` (tick 不再调 `_nav_agent.tick(dt)` — 移动归 procedure step 4; 仅维护 nav target / wants_to_attack)
    - 修改 `tests/battle/smoke_activity_chain.gd` (`_drive_nav` helper 模拟 procedure step 4 三段, 替代 activity 内的 nav.tick)
    - 新增 `tests/battle/smoke_steering.{gd,tscn}` (8 单位 converging on (400, 100) → 200 ticks 后任意 pair dist ≥ 2r-0.5; 不接 procedure / strategy / controller, 直接驱动 P2.2 三模块)
  - Evidence: 见 AC2 + AC9 上方
- [x] **P2.3 — Stuck Detection + Local Repath(避障第 3 层)**
  - 改动:
    - 新增 `logic/movement/rts_stuck_detector.gd` (per-actor `_State`: last_pos / stuck_ticks / repath_failures; STUCK_TICK_THRESHOLD=20 (≈1s @ 50ms) / MAX_REPATH_FAILURES=3; tick(units, controllers) 在 procedure step 4d 调用)
    - 修改 `logic/components/rts_nav_agent.gd` (加 4 个 public 访问器: `has_target` / `is_at_final_target` / `get_final_target` / `has_empty_path` — stuck detector 用 `has_target + !is_at_final_target` 判"想动但没到目标")
    - 修改 `logic/controller/rts_unit_controller.gd` (加 `_command_abandoned` flag + `abandon_command()` / `is_command_abandoned()` / `clear_command_abandon()` API; tick 检查 abandoned, 若 true 跳过 strategy.decide 仅推进 current_activity = Idle)
    - 修改 `core/rts_auto_battle_procedure.gd` (加 `_stuck_detector: RtsStuckDetector` lazy 字段; tick_once 在 step 4c integrate 之后插 step 4d `_stuck_detector.tick(alive_units, _unit_runtimes)`)
    - 新增 `tests/battle/smoke_stuck_recovery.{gd,tscn}` (3 单位塞在中央障碍内 — 起点+所有相邻 cell 全 blocking → A* 永远找不到路径; 远端放 dummy enemy 触发 basic_attack_strategy 不停 set_target; 200 ticks 后验证 ≥ 2/3 abandon + 漂移 < 5 px + intent="idle" + wants_to_attack=false)
  - Evidence: 见 AC2 + AC9 上方
- [x] **P2.4 — AutoTargetSystem(Mindustry + OpenRA 合璧)**
  - 改动:
    - 新增 `logic/ai/rts_auto_target_system.gd` (RESCAN_INTERVAL_TICKS=20 全量 + cache 失效单位本 tick 立即单独重扫; 评分公式 `score = max_priority_weight × 1e5 - dsq` 让 weight 主导但 weight=0 时退化到最近; stance HOLD_FIRE 清空 / DEFENSIVE 仅 1.5×atk_range 内候选 / AGGRESSIVE 全场)
    - 修改 `logic/config/rts_unit_class_config.gd` (StatBlock 加 unit_tags + target_priorities; MELEE 默认 unit_tags=["melee","ground"], RANGED 默认 ["ranged","ground"], 两者 target_priorities=[] 保持 Phase 1 行为)
    - 修改 `logic/rts_unit_actor.gd` (新 Stance enum + DEFENSIVE_ENGAGE_RANGE_FACTOR=1.5; 加字段 unit_tags / target_priorities / stance / _cached_target_id; _init 拷 stats.unit_tags / target_priorities 给 actor 独立副本)
    - 重写 `logic/ai/rts_basic_attack_strategy.gd` (decide 不再扫描 — 直接读 actor._cached_target_id; 失效则 IdleActivity 让下个 tick 的 AutoTargetSystem 重 scan)
    - 修改 `core/rts_auto_battle_procedure.gd` (加 _auto_target_system: RtsAutoTargetSystem lazy 字段; tick_once step 2.5 在 controller.tick 之前调 _auto_target_system.tick(world, alive_units))
    - 新增 `tests/battle/smoke_auto_target.{gd,tscn}` (5 子测试: priority over distance / HOLD_FIRE / DEFENSIVE / no-priority fallback / dead-cache immediate rescan; 直接驱动 RtsAutoTargetSystem 不接 procedure)
  - Evidence: 见 AC3 + AC9 上方
- [ ] **P2.5 — Production System + Building Factory**
- [ ] **P2.6 — Player Command + Building Placement + 胜负判定改写**
- [ ] **P2.7 — Frontend BattleDirector 接入流式 events**
- [ ] **P2.8 — AIR layer + target_layer_mask + 飞行单位**

---

## 顺序依赖

```
P2.1 (Activity) ✓ ─────────────────┐
                                   ├──> P2.4 (AutoTarget) ✓ ──> P2.5 (Production) ──> P2.6 (Player Command) ──> P2.7 (Frontend Director) ──> P2.8 (AIR layer)
P2.2 (Hash + Steering) ✓ ──> P2.3 (Stuck) ✓ ─┘
```

---

## 关键 artifact 路径(Phase 2)

| 类型 | 路径 |
|---|---|
| Activity 基类 + driver | `addons/.../rts-auto-battle/logic/activity/activity.gd` |
| Activity 子类 | `…/logic/activity/{idle,move_to,attack,attack_move}_activity.gd` |
| 重写 strategy | `…/logic/ai/rts_ai_strategy.gd` + `rts_basic_attack_strategy.gd` |
| 重写 controller | `…/logic/controller/rts_unit_controller.gd` |
| Activity primitive smoke | `…/tests/battle/smoke_activity_chain.{gd,tscn}` |
| Nav 拆 movement (P2.2) | `…/logic/components/rts_nav_agent.gd` (`compute_desired_velocity` / `integrate`) |
| Spatial hash (P2.2) | `…/logic/movement/rts_spatial_hash.gd` (cell_size=64 桶 + sorted query_radius) |
| Unit steering (P2.2) | `…/logic/movement/rts_unit_steering.gd` (separation + deflection 决定性) |
| Steering smoke (P2.2) | `…/tests/battle/smoke_steering.{gd,tscn}` (8 单位 converging) |
| Stuck detector (P2.3) | `…/logic/movement/rts_stuck_detector.gd` (per-actor `_State`, local repath + abandon_command 升级) |
| Controller abandon API (P2.3) | `…/logic/controller/rts_unit_controller.gd` (`abandon_command` / `is_command_abandoned` / `clear_command_abandon`) |
| Stuck recovery smoke (P2.3) | `…/tests/battle/smoke_stuck_recovery.{gd,tscn}` (3 围困单位 abandon) |
| AutoTarget system (P2.4) | `…/logic/ai/rts_auto_target_system.gd` (RESCAN_INTERVAL_TICKS=20, score=weight×1e5-dsq, stance 处理) |
| Stance + tags 字段 (P2.4) | `…/logic/rts_unit_actor.gd` (Stance enum + unit_tags + target_priorities + _cached_target_id) |
| Unit class tags 默认 (P2.4) | `…/logic/config/rts_unit_class_config.gd` (StatBlock.unit_tags / target_priorities) |
| Strategy 简化 (P2.4) | `…/logic/ai/rts_basic_attack_strategy.gd` (读 _cached_target_id, 不再扫描) |
| Auto target smoke (P2.4) | `…/tests/battle/smoke_auto_target.{gd,tscn}` (5 子测试: priority/HOLD_FIRE/DEFENSIVE/fallback/dead-cache) |

---

## 残余风险(从 Phase 1 继承; 跨 phase 不变)

- **AC9 hex demo segfault on shutdown**(`archive/2026-04-30-rts-auto-battle/Summary.md`): 本轮 hex demo headless 跑出 `结果: left_win` 且退出码 0 — segfault 没复现, 不阻塞 Phase 2 P2.1 验收。
- **30Hz default tick 与 50ms M0 smoke 兼容**: smokes 仍 explicitly 传 `tick_interval_ms = 50.0`; 30Hz 默认仅在 demo / 新调方启用。Phase 2 P2.7 流式 frontend 接入后再统一切到 30Hz。
- **录像 still no-op**: P1.7 仅写 `world_snapshot.rng_seed` 给 light determinism 用; 完整流式 event_timeline + bit-identical replay 在 Phase 2 P2.6+P2.7。

---

## 决策记录(Phase 2 期间新增)

- **P2.1 advance 子先父后 vs 父先子后**: 选**父 supervisor 先 tick** (AttackActivity.tick 决定是否 push/cancel MoveTo child) — 与 OpenRA Activity.cs 反过来, 但更符合 RTS 主控逻辑 (parent 决定 child 何时创建/取消)
- **P2.1 Activity 复用 vs 每 tick 重建**: controller.tick 调 `current_activity.is_equivalent_to(proposed)` (子类 override: AttackActivity 比 target_id, MoveToActivity 比 target_pos) — 等价复用, 不等价 cancel + flush + 接管。避免每 tick 重建 nav 状态导致 set_target 抖动
- **P2.1 cancel 路径下 on_first_run 可能未跑**: 子类 on_last_run 必须**幂等** (即使没 on_first_run 也安全 cleanup) — IdleActivity / MoveToActivity / AttackActivity 都验证这一点
- **P2.1 keeping legacy controller API**: `wants_to_attack()` / `get_intent_action()` 保留 — procedure / smoke_ai 不感知 Activity 实现细节, 委托给 current_activity. P2.6 player command 也走类似模式 (set_activity_chain 入口)
- **P2.2 SEPARATION_BUFFER = 0 (严格 r+r 阈值, 不留 buffer)**: 任何 buffer > 0 都会让 attackers 在 atk_range = 2r 处被 sep 推开 (strength = (sep_radius - 2r)/sep_radius > 0); buffer=0 时 attackers 在 atk_range 处 strength=0 不施力, 接战不被破坏。代价是 cluster 后侧单位需要"挤过"完全重叠才会有 sep — 但 MAX_SEP_FRACTION=0.7 保证后侧仍有 0.3*move_speed 朝目标前进, 不会被沉默卡住
- **P2.2 静止单位也施 separation, 但 deflection 只 moving**: 抵达后 cluster 不重叠是首要不变量, 必须给静止单位施 sep; deflection 是"同向移动迎面对撞时旋转避让", 静止无方向可旋, 自然跳过
- **P2.2 sep_force 总幅度 cap (MAX_SEP_FRACTION=0.7) 而不是 N 邻居 sum 后裸推**: 不 cap 时 N 邻居叠加 sum 经常远超 move_speed, clamp(combined, move_speed) 之后变成"全力反向" → cluster 后半部单位被推到 cluster 后方再也赶不上。cap sep_force.length() ≤ 0.7*move_speed 后, combined = desired + sep 在最坏情况下仍有 0.3*move_speed 朝 desired 方向, 不会反向飞
- **P2.2 决定性: spatial_hash query_radius 输出 sort by id**: 按 actor_id 字典序排序 → 多次跑同 seed 同 player_commands 输入, 邻居迭代顺序一致 → 浮点 sum 顺序一致 → bit-equal velocity → bit-equal position. 配合 actor_id parity 决定 deflection sign, 无 randf 调用. smoke_determinism (seed=12345) 跑 2 次 tick_diff=0 验证
- **P2.2 删 RtsMinimalPushOut 调用而保留代码文件**: procedure step 4 不再调 push-out (steering separation 已覆盖); 但 smoke_minimal_push_out 仍存自验证算法本身能跑 — Phase 1 baseline 不破。文件作为"备胎"留着, 未来如果 steering 出问题可临时 fallback
- **P2.3 stuck detection 触发条件 = "想动但没到目标"**: 不用 agent.is_arrived (它把 path 空也算 arrived, 漏掉"A* 找不到路"的情形); 用 `has_target() && !is_at_final_target()` + 单 tick displacement < 1 px。这样既覆盖"path 找不到 → 站着不动"也覆盖"path 有但被建筑挡住 → 走不到下一 waypoint"
- **P2.3 失败计数 reset 时机**: 单位本 tick 实际位移 ≥ 阈值 → 立即清 stuck_ticks + repath_failures (干净状态: 单位刚突围出来, 不让历史失败计数误伤)。但 stuck 触发 repath 后只 reset stuck_ticks (失败计数累加), 给 3 次 retry 机会; 第 3 次失败才 abandon — 不让暂时性 race condition 直接降级
- **P2.3 abandoned 后 controller 跳过 strategy.decide**: 不只是替换 current_activity 为 Idle, 还设 `_command_abandoned` flag, controller.tick 在 abandoned 状态下完全不调 strategy.decide。否则下 tick basic_attack_strategy 又提议 AttackActivity, reconcile 替换掉 Idle, stuck 循环重启。flag 只能由 `clear_command_abandon()` 显式解除 (P2.6 玩家命令系统接入时调)
- **P2.3 abandon 单位仍 advance current_activity**: 即使 strategy.decide 跳过, controller 仍 `current_activity.bind_runtime + RtsActivity.advance` 推进 Idle — 否则 Idle 永远 stuck 在 QUEUED 状态, 下次 cancel 时钩子串不正确; 也保 Idle 的 actor.current_target_id="" 等清理生效
- **P2.4 评分公式 score = weight × 1e5 - dsq (单一标量) 而不是 lex 排序 (weight desc, dsq asc)**: 标量等价于 lex 当 WEIGHT_SCALE 远大于战场 max dsq (500×500 战场 max dsq = 5e5, WEIGHT_SCALE = 1e5 也使 weight=1 永远胜过最远候选; 实战 priority weight 都 ≥ 10 — 100×1e5 远大于 5e5 dsq)。标量代码更简单, strict ">" 取最大同分时保留先扫到的 (与 _select_nearest 同序), 不需要 tiebreak by id
- **P2.4 weight=0 时退化到最近选择**: 默认 target_priorities=[] → priority_weight 永远返回 0 → score = -dsq → max score = min dsq → 最近敌人。这正是 P1.5 _select_nearest 行为, 让 4v4 主 smoke 不需要任何 priority 配置就能用 AutoTargetSystem (默认无变化)
- **P2.4 cache 失效当 tick 立即重扫 (而不是等下个 RESCAN 周期)**: 单 tick 重扫一个 unit 是 O(N), 全量重扫所有 needs_rescan 是 O(K×N) 其中 K = needs_rescan size。比"等 20 tick 才重扫"避免单位空窗中段, 又比"每 tick 全量重扫" O(N²) 便宜很多。代价是死亡 actor 在战斗中频繁触发 needs_rescan, 但 4v4 死 6 个单位也只有 6 次额外 O(N) 重扫
- **P2.4 决定性来自 by_team 字典 insertion-order**: AutoTargetSystem 用 Dictionary 按 team_id 分组 enemies, 然后 iterate by_team.keys() 取出非己方阵营。Godot 4 Dictionary keys() 走 insertion-order, 入参 units 顺序 = world.get_alive_units 顺序 = world.get_actors 顺序 = insertion order, 所以同 seed → 同分组 → 同评分 → 同 cache 选择 → bit-equal 战斗 (smoke_determinism tick_diff=0 验证)
- **P2.4 RtsAttackActivity 不动而靠 strategy 切换**: 没把 AutoTargetSystem 集成进 AttackActivity (那需要 Activity 持引用 to system, 跨层耦合)。改为: AutoTargetSystem 写 _cached_target_id → strategy.decide 提议新 AttackActivity(new_id) → controller.is_equivalent_to 比 target_id 不等价 → cancel 旧 activity + 接管新的。这样 Activity 保持 pure (target_id 不可变), 切换的责任全在 controller / strategy reconcile 一处
- **P2.4 默认 stance=AGGRESSIVE 而非 DEFENSIVE**: 与 OpenRA 默认相反。但 RTS M1 Phase 2 仅 AI 驱动 (P2.6 玩家命令未到), 单位需要主动找敌否则 4v4 干站。Phase 2 P2.6 玩家命令系统接入后, 玩家放新单位时可显式设 DEFENSIVE 让其 stance 行为更被动

---

## Phase 1 摘要(已完成 2026-05-01)

详见 [`task-plan/phase-1-foundation.md`](task-plan/phase-1-foundation.md)。9/9 AC 全过, 不归档(同一 feature 早期 phase, 归档放整个 RTS M1 重构完成时做)。
