## Progress — RTS Auto-Battle M1 架构重构

**Status**: ✅ **Phase 2 acceptance 全过 (10/10)** — P2.1-P2.8 全部完成 (8/8 sub-tasks); 不退化

最近更新: 2026-05-02 (P2.8 完成 + Phase 2 收口)

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
- [x] **AC4 — Production**: `smoke_production` 兵营周期 spawn PASS (P2.5)
  - 命令: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_production.tscn > /tmp/p2_5_smoke_production.txt 2>&1`
  - Evidence: `rts production smoke: ticks=600 left_spawned=7 right_spawned=7 max_left_eastward=118.51 px`; PASS
    - 左 / 右各 1 个 barracks (production_period_ms=4000) → 30s @ 50ms 跑 600 ticks 后各 spawn 7 个 melee (理论 7-8, 阈值 ≥ 5)
    - footprint blocking 验证: 起手 `_verify_footprint_blocking` 检查左 / 右 barracks 4 个 cell 全 `is_tile_blocking=true`
    - SpawnLane 进军证据: 左队最大 x 偏移 118.51 px (从 spawn x≈140 到最远 x≈258); strategy + AutoTargetSystem 接管后 AttackActivity 驱动 unit 朝中场敌人移动
- [x] **AC5 — Player Command + Crystal Tower**: `smoke_player_command` ✅ + `smoke_crystal_tower_win` ✅ + `smoke_player_command_production` ✅ PASS (P2.6 完成 2026-05-01)
  - 命令 A: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_player_command.tscn > /tmp/p2_6_player_command.txt 2>&1`
  - Evidence A: `rts player_command smoke: ticks=30 log_entries=3 resources_remaining=100 placed_id=rts_world_0:Building_4`; PASS
    - 3 条 player_command_log entries: entry0 (PlaceBuildingCommand barracks @ (150, 200)) success → actor_id=Building_4 + footprint cells (4, 5)/(5, 5)/(4, 6)/(5, 6) blocking + 扣 100 resources;
      entry1 (同位置二次放置) fail reason=cells_blocked (验证占用拒绝);
      entry2 (build_zone 之外 (50, 400)) fail reason=out_of_build_zone (验证建造区合法性);
      仅 entry0 扣资源, 200 → 100 (cost=100)
  - 命令 B: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_crystal_tower_win.tscn > /tmp/p2_6_crystal_tower.txt 2>&1`
  - Evidence B: `rts crystal_tower_win smoke: ticks=2 result=left_win left_ct_dead=false right_ct_dead=true`; PASS
    - 起手 procedure.start() 自动绑定双方 crystal_tower_id (smoke 不需要手动 set);
    - tick 1 双 ct 都活 → procedure 不结束;
    - 手动 mark_dead 右方 ct + tick 2 → `_check_battle_end` 走 crystal-tower 模式 → result=left_win (取代 fallback 全灭判定)
  - 命令 C: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_player_command_production.tscn > /tmp/p2_6_pc_production.txt 2>&1`
  - Evidence C: `rts player_command_production smoke: ticks=600 placed_id=rts_world_0:Building_4 left_spawned=7 max_eastward=254.74 resources=100`; PASS
    - tick 30 placement 成功 → 后 570 ticks (28.5s) 内累积 7 个 melee spawn (理论 7-8, 阈值 ≥ 3);
    - SpawnLane override_strategy=true 让 RtsAttackMoveActivity 不被 strategy.decide 替换 → 单位最远朝东偏移 254.74 px (验证 P2.6 override flag);
    - 双方 crystal_tower 占位让战斗不自然结束 (AutoTarget 不打 buildings, 当前 limitation; 战斗保持 in_progress)
- [x] **AC6 — Frontend Director 流式**: `smoke_director_streaming` ✅ PASS (P2.7 完成 2026-05-01); frontend 0 处 `actor.position_2d` 直读 (visualizer / world_view 完全不读 actor; Director 在 tick boundary 单次 snapshot 是合规 state projection)
  - 命令 A: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/frontend/smoke_director_streaming.tscn > /tmp/p27_streaming.txt 2>&1`
  - Evidence A: `visualizers=8 render_emits=648 attack_emits=16 death_emits=0 moved=8 ticks=80`; PASS - 4s 战斗 8 单位移动了, 16 次 attack events 经 director 信号路径流到 visualizer
  - 命令 B (frontend smoke 升级走 director): `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/frontend/smoke_frontend_main.tscn > /tmp/p27_rts_fe.txt 2>&1` → `visualizers=8 alive_after_3.0s=8 SMOKE_TEST_RESULT: PASS`
  - 命令 C (AC6 主断言 grep): `grep -rn 'actor\.position_2d' addons/logic-game-framework/example/rts-auto-battle/frontend/visualizers/ addons/logic-game-framework/example/rts-auto-battle/frontend/world_view.gd` → 0 处直读 (visualizer 完全 0 处 actor.* 字段读)
  - Evidence: visualizer 走 push 模式 — `update_render_state(prev_pos, curr_pos, hp, max_hp, is_dead)` 由 RtsWorldView 路由 director.actor_render_state_updated signal 进来; visualizer `_process(delta)` 走 director.get_alpha() 在 prev_pos / curr_pos 之间 lerp, 60FPS 渲染插值 30Hz logic tick
- [x] **AC7 — AIR layer + 飞行单位**: `smoke_flying_units` ✅ PASS (P2.8 完成 2026-05-02)
  - 命令: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_flying_units.tscn > /tmp/p28_flying.txt 2>&1`
  - Evidence: `/tmp/p28_flying.txt` → `ticks=200 scout_hp=15.0 scout_pos=(50.0,100.0) archer_hits=3 melee_hits_scout=0 ground_melee_x=53.5`; PASS
    - **AIR-only 防空塔命中飞行**: archer_tower (target_layer_mask=MASK_AIR) 命中 flying_scout 3 次 → scout HP 90 → 15
    - **GROUND-only 近战不能命中飞行**: melee (mask=MASK_GROUND) hits_scout = 0 (mask 过滤生效, 即使距离近也不写 _cached_target_id 给 scout)
    - **飞行穿过地面建筑 footprint**: scout 从 (450, 100) → (50, 100) 直线飞过 barracks @ (300, 200), x=50.0 抵达; RtsPathfinding AIR 层早 return _direct_path 跳过 A*
- [x] **AC8 — 城堡战争最小可玩 demo**: `smoke_castle_war_minimal` ✅ PASS (P2.8 完成 2026-05-02); demo_rts_frontend.tscn F6 视觉验证留给用户
  - 命令 A (headless 等价 smoke): `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_castle_war_minimal.tscn > /tmp/p28_castle.txt 2>&1`
  - Evidence A: `/tmp/p28_castle.txt` → `ticks=193 result=left_win left_ct_dead=false right_ct_dead=true scout_dead=false unit_to_building_attacks=4 archer_anti_air=1 spawn_count=2`; PASS
    - **玩家命令放兵营**: tick 1 enqueue PlaceBuildingCommand barracks @ (160, 250) → 成功; team0_resources 100 → 0
    - **production 周期 spawn**: 2 melee 在 ~9.6s 内 spawn (period 4s, 起步 + 第二轮)
    - **单位攻击建筑**: 4 unit→building 攻击事件; right_ct (hp=100) 在 ticks=193 死亡 → result=left_win (走 P2.6 crystal-tower 模式判定)
    - **AC7 联动**: left_archer 命中 right_scout 1 次 (anti-air); scout 仍存活 hp=65 (近距离擦肩, 没充足时间击落; AC7 击落已有 smoke_flying_units 验证)
  - 命令 B (frontend 上下文 sanity): `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/frontend/smoke_frontend_main.tscn` → visualizers=10 (4 ground + 1 flying / 方) alive=10
  - F6 视觉留给用户在编辑器中确认: 玩家点击放兵营 + 飞行单位 8px 上空 + anti-air 击退飞行 + 单位攻击 ct → 战斗结束 流程
- [x] **AC9 — 不退化** (P2.8 重新验证, 全部 P1 + P2.1-P2.8 smokes 仍 PASS):
  - 命令 A: `godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn > /tmp/p28f_lgf.txt 2>&1` → `73/73 PASS`
  - 命令 B: `godot --headless --path . addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn > /tmp/p28f_hex.txt 2>&1` → exit 0 (hex demo 非确定性: 不同跑次返回 left_win / right_win 都正常, 与 P2.7 末态一致)
  - 命令 C (主 smoke): `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn > /tmp/p28f_main.txt 2>&1` → `result=left_win ticks=347 attacks=74 (melee=32 ranged=42) deaths=6 melee_max_dist=24.00 ranged_max_dist=125.75 detoured=4`; PASS — **与 P2.7 末态完全一致** (P2.8 在 4v4 主 smoke 无 building 场景下 0 行为差; layer mask 默认 MASK_GROUND/MASK_BOTH 覆盖既有兵种行为)
  - 命令 D (determinism): `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/replay/smoke_determinism.tscn > /tmp/p28f_det.txt 2>&1` → `seed=12345, run1=run2=(left_win, 347), tick_diff=0`; **bit-equal** (light determinism 仍达成)
  - 全部 P1 + P2.1-P2.8 smokes: skeleton / nav / ai / attack / grid_pathfinding / minimal_push_out / activity_chain / steering / stuck_recovery / auto_target / production / player_command / crystal_tower_win / player_command_production / frontend_main (P2.8 升级 EXPECTED_VISUALIZERS=10) / director_streaming / replay_bit_identical / **flying_units** (P2.8 新) / **castle_war_minimal** (P2.8 新): all PASS
    - 命令: `godot --headless --path . <smoke>.tscn > /tmp/p28_<name>.txt 2>&1`
- [x] **AC10 — Bit-identical replay**: `smoke_replay_bit_identical` ✅ PASS (P2.7 完成 2026-05-01)
  - 命令: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/replay/smoke_replay_bit_identical.tscn > /tmp/p27_replay.txt 2>&1`
  - Evidence: `seed=42, commands=2, frames=10, events=20`; PASS - 同 seed (42) + 同 player_commands (tick 5 / tick 10 各放 barracks) 跑 2 次, 100 ticks 截断, **timeline events 逐字段 deep equal** (10 帧含 events + 共 20 events; HexCoord 字段走 q/r 比对); player_commands_log 长度+entry-by-entry deep equal; rng_seed 一致
  - 实现: procedure.finish() RTS-only wrap — 在 super.finish() 返回 dict 上注 `player_commands` (副本) + `rng_seed` (回放 player commands replay 用); IdGenerator.reset_id_counter() 让两次跑 actor id 一致
  - 决定性已 P2.6 验证 (smoke_determinism tick_diff=0); P2.7 进一步固化为完整 event timeline level bit-identical

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
- [x] **P2.6 — Player Command + Building Placement + 胜负判定改写**
  - 改动:
    - 新增 `logic/config/rts_team_config.gd` (RtsTeamConfig: team_id / faction_id / starting_resources / build_zone Rect2 / crystal_tower_id; 工厂 `unconfigured(team_id)` + `create(team_id, faction, resources, zone)`; 查询 `has_build_zone / contains_position / has_crystal_tower`)
    - 新增 `logic/commands/rts_player_command.gd` (基类: tick_stamp / team_id / `apply(procedure, world) -> Dictionary` 钩子 / `command_type / serialize` 录像支持)
    - 新增 `logic/commands/rts_place_building_command.gd` (PlaceBuildingCommand: building_kind + position_2d; apply 走 RtsBuildingPlacement.validate → RtsBuildings.create_<kind> → add_actor + set position + place_building 写 pathing map + spend_team_resources + add_unit_to_team + 自动绑 crystal_tower_id)
    - 新增 `logic/commands/rts_player_command_queue.gd` (RtsPlayerCommandQueue: enqueue / apply_due (按 tick_stamp 升序, 同 tick 保 insertion-order, 决定性) / history append / get_failed_history / pending_count)
    - 新增 `logic/commands/rts_building_placement.gd` (静态校验: build_zone / 地图边界 / cells 阻挡 / cells 占用 / 资源充足; 返回 result dict 含 reason 枚举 + footprint + cost)
    - 新增 `logic/commands/README.md` (commands/ 目录使用说明 + 添加新命令类型指南)
    - 修改 `logic/config/rts_building_config.gd` (StatBlock 加 `cost: int` 字段; barracks=100 / archer_tower=50 / crystal_tower=0; get_stats 拷贝 cost 到 block)
    - 修改 `logic/controller/rts_unit_controller.gd` (加 `_player_command_active: bool` flag + `set_activity_chain(chain, override_strategy=false)` 第 2 参数 + `clear_player_command_override` / `is_player_command_active` API; tick 在 override 时跳过 strategy.decide, 仅推进 current_activity, 链跑完自动清 flag; override=true 时也清 abandoned 状态让玩家命令复活 stuck 单位)
    - 修改 `core/rts_auto_battle_procedure.gd`:
      - 字段加 `_team_configs / _team_resources / _player_command_queue / _player_commands_log`;
      - opts 新增 `team_configs: Dictionary[int, RtsTeamConfig]` + `player_command_queue: RtsPlayerCommandQueue` (旧 smoke 不传时按需 unconfigured + lazy create);
      - `_init` 调 `_install_team_configs(opts.team_configs)` 装配占位 (旧 smoke 行为不破);
      - `start()` 在 footprint 写入循环里加自动绑 crystal_tower_id (smoke 不需手动 set);
      - tick_once step 1.5 (1 之后, 2 之前): `_player_command_queue.apply_due` + log append;
      - `_check_battle_end` 重写: 走 `_is_team_lost(team_id, team_actors)` — `team_config.has_crystal_tower()` 优先 (找 actor_id == crystal_tower_id 死亡判败), 否则 fallback team-wipeout (Phase 1 行为兼容);
      - 公共 API: `enqueue_player_command(cmd)` / `get_team_config(team_id)` / `get_team_resources(team_id)` / `spend_team_resources(team_id, amount)` / `get_player_commands_log()`;
      - 内部 `_install_team_configs` (装配占位让 0/1 必有 entry)
    - 新增 `tests/battle/smoke_player_command.{gd,tscn}` (3 phase: 放置 OK + 同位置二次失败 + 建造区外失败; 验证 player_commands_log 3 条 entry, resources 200→100, footprint cells blocking, 建筑 in left_team)
    - 新增 `tests/battle/smoke_crystal_tower_win.{gd,tscn}` (双 crystal_tower 起手, procedure.start() 自动绑 crystal_tower_id; tick 1 双活 → not finished; mark_dead 右方 + tick 2 → result=left_win)
    - 新增 `tests/battle/smoke_player_command_production.{gd,tscn}` (P2.5+P2.6 联动: tick 30 player command 放兵营 → 600 ticks 后 left_spawned=7 + max_eastward=254.74 px + override_strategy=true 让 SpawnLane 不被 strategy.decide 替换)
  - Evidence: 见 AC5 + AC9 上方
- [x] **P2.8 — AIR layer + target_layer_mask + 飞行单位** (Phase 2 收口)
  - 改动:
    - **MovementLayer 扩 mask 常量 + helpers**: `MASK_NONE/MASK_GROUND/MASK_AIR/MASK_BOTH` (与 Layer enum 同源, bit i = 1 << layer); `mask_for_layer(layer)` + `mask_matches(mask, layer)` static helpers
    - **新增 `logic/weapons/rts_weapon_config.gd`** (RtsWeaponConfig — 转发 mask 常量 + `matches(mask, candidate_layer)` + `can_hit(attacker, target)` static helpers; attacker.target_layer_mask 命中候选 layer 的统一查询入口)
    - **`RtsBattleActor` 共享攻击协议**: 把 `current_target_id / target_layer_mask / unit_tags / target_priorities / _cached_target_id / ATTACK_COOLDOWN_TAG` 上推; 加 virtual `get_atk/def/attack_range/attack_speed`; 加 `is_attack_on_cooldown / can_attack / start_attack_cooldown` 共用基类 — 单位 + 建筑共用攻击循环
    - **`RtsUnitActor`** 删去重复字段 (改基类继承); override `get_atk/def/attack_range/attack_speed` 走 `attribute_set.atk` 等; `_init` 拷 `default_movement_layer` + `target_layer_mask` 自 stats
    - **`RtsBuildingActor`** 加 plain float 字段 `atk_value / def_value / attack_range_value / attack_speed_value` (建筑没 attribute_set.atk 路径); override 同名 accessor 走这些字段; `RtsBuildings._create_from_kind` 工厂从 stats 注入这些字段 + target_layer_mask + unit_tags
    - **`RtsUnitClassConfig`** StatBlock 加 `default_movement_layer` + `target_layer_mask`; 默认 MELEE → MASK_GROUND, RANGED → MASK_BOTH (anti-air); 新增 `UnitClass.FLYING_SCOUT` (Layer.AIR + MASK_GROUND, hp=90 / atk=15 / move_speed=100 / attack_range=80 / attack_speed=0.8 / unit_tags=["flying","air"])
    - **`RtsBuildingConfig`** StatBlock 加 `atk / def / attack_range / attack_speed / target_layer_mask / unit_tags`; archer_tower 升级 anti-air (atk=25, attack_range=140, attack_speed=0.7, mask=MASK_AIR, unit_tags=["building","tower","anti_air"]); barracks / crystal_tower mask=MASK_NONE 不参战
    - **`RtsPathfinding.find_path`** AIR 层早 return → `_direct_path(to_world)` 不调 A* (穿地面建筑 footprint, 浮点直线决定性)
    - **`RtsAutoTargetSystem`** 重写: tick 入参从 `units` 改为 `actors` (alive_actors 含建筑); movers = 任何 `target_layer_mask != 0` 的 RtsBattleActor (单位 + 建筑都可作 mover); 候选过滤加 `RtsWeaponConfig.matches(mover.mask, candidate.movement_layer)`; stance HOLD_FIRE/DEFENSIVE 仅对 RtsUnitActor 生效 (建筑永远参战); `by_team` 字典聚合所有 RtsBattleActor 候选
    - **`RtsBasicAttackAction`** 重写: attacker / target 类型放宽到 RtsBattleActor; 数值通过 `attacker.get_atk()` 等 virtual accessor 取 (兼容 unit + building); `target_attrs.get_raw().get_current_value("hp")` 兼容两种 attribute_set; 加 `RtsWeaponConfig.can_hit` 防御性 layer mask 检查; attacker_unit_class 字段对 building 设 -1 (logger 兼容)
    - **`RtsAttackActivity` / `RtsBasicAttackStrategy._resolve_cached_target`** target 类型放宽到 RtsBattleActor — 单位可以选 building (e.g. crystal_tower) 当目标; AC8 单位攻击建筑链路打通
    - **`RtsTargetSelectors.CurrentUnitTarget`** attacker / target cast 都放宽到 RtsBattleActor (建筑也走此 selector 拿 target)
    - **`RtsAutoBattleProcedure.tick_once` step 3** 加建筑攻击循环 — 没 controller / activity, 直接读 building._cached_target_id, 范围内 (1.05 × attack_range) + cooldown ready → 触发 `_invoke_basic_attack(building, world)` (signature 放宽到 RtsBattleActor); building.current_target_id = cached_id 给 CurrentUnitTarget selector 用
    - **frontend visualizer 飞行渲染**: `RtsUnitVisualizer.bind` 加 `p_render_height` 参数 (RtsWorldView spawn 时一次性 hydrate 自 `actor.get_render_height()` — AIR 单位 8.0, ground 0.0); _process 内 `position = lerp(prev, curr, alpha) - Vector2(0, render_height)` 让 AIR 单位上抬 8px (Godot 2D y 向下)
    - **`demo_rts_frontend.gd` 升级城堡战争最小可玩 demo**:
      - 起手布局: 双方 crystal_tower (left @ (80, 350), right @ (420, 350) hp=400) + archer_tower (left @ (80, 200), right @ (420, 200), 防空 mask=MASK_AIR) + 4 ground 单位 / 方 (2 melee + 2 ranged 用既有 sample_team_spawn) + 1 flying_scout / 方 (override-strategy AttackMove 朝对方 ct 飞)
      - HUD Label: 实时显示 left team_resources + 双方 ct hp + 玩家操作提示
      - 玩家输入: `_unhandled_input` 接 InputEventMouseButton; 左键点击落在 LEFT_BUILD_ZONE (50,50)~(250,450) 内 → enqueue `RtsPlaceBuildingCommand barracks` tick_stamp=current_tick
      - team config: 左方 starting_resources=300 (够 3 barracks @ 100 each); 右方 starting_resources=0 (AI 不放)
      - spawner: barracks 周期 spawn melee 朝对方 ct 进军; 不 set_activity_chain — 让 strategy.decide / AutoTargetSystem 自然驱动 (单位选最近 enemy ct)
    - **新 smoke `tests/battle/smoke_flying_units.{gd,tscn}`** (AC7): archer_tower (T0, mask=AIR) + melee (T0, HOLD_FIRE, mask=GROUND) + barracks 障碍; flying_scout (T1, AIR, override-AttackMove (50,100)) + ground_melee (T1, override-AttackMove (50,200)); 200 ticks @ 50ms; 验证 archer→scout 命中 ≥1 + melee→scout 0 命中 + scout 飞越 barracks 直达 (50, 100)
    - **新 smoke `tests/battle/smoke_castle_war_minimal.{gd,tscn}`** (AC8 headless 等价): 起手左 archer + ct, 右 archer + ct (hp=100) + flying_scout; 玩家 tick 1 enqueue PlaceBuildingCommand barracks @ (160, 250); 600 ticks 主循环验证 result=left_win + unit→building 攻击事件 ≥1 + archer→scout 命中 ≥1
    - **frontend smoke `tests/frontend/smoke_frontend_main.gd`** EXPECTED_VISUALIZERS 8 → 10 (P2.8 demo 加 1 flying_scout / 方)
  - Evidence: 见 AC7 + AC8 + AC9 上方
- [x] **P2.7 — Frontend BattleDirector 接入流式 events**
  - 改动:
    - 新增 `frontend/core/rts_battle_director.gd` (RtsBattleDirector — Node; SIM_DT_MS = procedure.get_tick_interval; _process(delta) 累加 dt 到 SIM_DT 推 procedure.tick_once; tick boundary _capture_prev / _capture_curr_and_emit; 4 个 signal: frame_advanced / actor_render_state_updated / attack_resolved / actor_died / battle_ended; 接管 procedure._event_sink 转发 attack/died events; 维护 _render_states dict {prev_pos / curr_pos / hp / max_hp / is_dead}; 暴露 attach(world, procedure) / detach / get_alpha / get_render_state / is_running / is_ended)
    - 新增 `frontend/world_view.gd` (RtsWorldView — Node2D; bind(world, director) 监听 world.actor_added/removed → 自动 spawn/despawn visualizer; 路由 director.actor_render_state_updated 到对应 visualizer.update_render_state; 路由 director.actor_died 到 visualizer.on_died; RtsUnitActor → RtsUnitVisualizer / RtsBuildingActor → RtsBuildingVisualizer 分发)
    - 升级 `frontend/visualizers/rts_unit_visualizer.gd` (push 模式: 不再持 actor 引用, 改持 actor_id + WeakRef director; bind(actor_id, team_id, director) 起手从 director.get_render_state 拉一次; update_render_state(prev_pos, curr_pos, hp, max_hp, is_dead) 由 WorldView 路由信号写; _process(delta) 走 director.get_alpha() 在 prev_pos / curr_pos 之间 lerp 给 60FPS 渲染插值; on_died() 调暗 polygon + label "DEAD"; 删 sync() polling 入口)
    - 新增 `frontend/visualizers/rts_building_visualizer.gd` (RtsBuildingVisualizer — Node2D; AABB footprint 矩形 + hp bar + 水晶塔金色边框区分; 不需要插值; queue_redraw 由 update_render_state 触发)
    - 改写 `frontend/demo_rts_frontend.gd` (新顺序: world / battle_map / director / world_view → world_view.bind → spawn 4v4 → start_rts_battle → director.attach; demo._process 逻辑全删, 全自动由 director 驱动; battle_ended → procedure.finish + print 结果)
    - 升级 `tests/frontend/smoke_frontend_main.gd` (visualizer.actor 删除后改用 vis.actor_id != "" + vis.get_render_is_dead())
    - 修改 `core/rts_auto_battle_procedure.gd` (finish() override: 在 super.finish() 返回 dict 上注 RTS 专属字段 — `player_commands` 副本 + `rng_seed`; bit-identical replay smoke 用此入口拿完整 record)
    - 新增 `tests/frontend/smoke_director_streaming.{gd,tscn}` (4v4 走 director path 跑 4s; 验证 render_emits > 0 + attack_emits > 0 + 至少 1 visualizer moved 离 spawn x; 信号链路完整)
    - 新增 `tests/replay/smoke_replay_bit_identical.{gd,tscn}` (AC10: 同 seed=42 + 同 2 commands tick 5/10 跑 2 次 100 ticks; IdGenerator.reset_id_counter 之间, 验证 timeline events 逐字段 deep equal — Dictionary / Array / HexCoord(q,r) 递归; player_commands_log entry-by-entry deep equal; rng_seed 一致)
  - Evidence: 见 AC6 + AC9 + AC10 上方
- [x] **P2.5 — Production System + Building Factory**
  - 改动:
    - 新增 `logic/buildings/rts_building_attribute_set.gd` (hp / max_hp / production_speed_multiplier; cross-clamp hp ≤ max_hp; 与 `RtsUnitAttributeSet` 同构 apply_config 路径)
    - 新增 `logic/config/rts_building_config.gd` (3 个 building_kind: crystal_tower / barracks / archer_tower; StatBlock = name + max_hp + footprint_size + is_crystal_tower + production_period_ms + spawn_unit_kind + spawn_unit_stance)
    - 重写 `logic/rts_building_actor.gd` (从 stub 升级到完整 actor: 加 attribute_set / footprint_size / is_crystal_tower / production_period_ms / spawn_unit_kind / spawn_unit_stance / `_production_progress_ms`; `get_footprint_cells(grid)` 按 footprint_size AABB 算 cells, 偶数尺寸左上偏置, 奇数居中)
    - 新增 `logic/buildings/rts_buildings.gd` (工厂 module — `create_crystal_tower / create_barracks / create_archer_tower`; 共用 `_create_from_kind` 配齐 attribute_set + ability_set + max_hp/hp + footprint + 生产字段; collision_radius 估算为 footprint 半边长)
    - 新增 `logic/production/rts_production_system.gd` (纯 RefCounted; `tick(dt_ms, world, spawner)` 走全部 alive RtsBuildingActor, 累加 `_production_progress_ms` × `production_speed_multiplier`, 满周期触发 `spawner.call(building)`; spawner 返回非 null 则减一周期, null 视为 spawn 失败下次重试; 不调 randf 决定性安全)
    - 修改 `core/rts_auto_battle_procedure.gd`:
      - opts 新增 `unit_spawner: Callable(building) -> RtsUnitActor`; 字段 `_production_system: RtsProductionSystem`(lazy) + `_unit_spawner: Callable`
      - 新 `start()` override: 在 `super.start()` 之后走 `get_all_actors()` 找 RtsBuildingActor, 调 `world.rts_grid.place_building(id, get_footprint_cells(grid))` 把 footprint 写入 pathing map (单位寻路自动绕开建筑)
      - tick_once step 4e: `if _unit_spawner.is_valid(): _production_system.tick(_tick_interval, world, _unit_spawner)` (在 stuck_detector 之后, event_sink 之前)
      - 新 `add_unit_to_team(unit, team_id)` 公共 API: 让 spawner 把新单位加入 left_team / right_team 对应阵营 (procedure 内部 `_check_battle_end` / `get_alive_actors` 立即可见; 仅支持 team_id ∈ {0, 1})
    - 新增 `tests/battle/smoke_production.{gd,tscn}` (左 / 右各 1 barracks 对称布置; 自管 spawner 创建 unit + RtsNavAgent + RtsUnitController + `add_unit_to_team` + 初始 `RtsAttackMoveActivity` SpawnLane chain; 600 ticks @ 50ms = 30s 跑完 assert ≥ 5 spawn / team + 至少 1 left spawn 朝东 ≥ 50px)
  - Evidence: 见 AC4 + AC9 上方

---

## 顺序依赖

```
P2.1 (Activity) ✓ ─────────────────┐
                                   ├──> P2.4 (AutoTarget) ✓ ──> P2.5 (Production) ✓ ──> P2.6 (Player Command) ✓ ──> P2.7 (Frontend Director) ✓ ──> P2.8 (AIR layer + 单位攻击建筑) ✓
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
| Building factory (P2.5) | `…/logic/buildings/rts_buildings.gd` (`create_crystal_tower / create_barracks / create_archer_tower`) |
| Building actor (P2.5) | `…/logic/rts_building_actor.gd` (footprint_size / attribute_set / production fields; AABB get_footprint_cells) |
| Building attribute set (P2.5) | `…/logic/buildings/rts_building_attribute_set.gd` (hp / max_hp / production_speed_multiplier) |
| Building config (P2.5) | `…/logic/config/rts_building_config.gd` (KIND_* 常量 + StatBlock 表; 3 种建筑) |
| Production system (P2.5) | `…/logic/production/rts_production_system.gd` (`tick(dt_ms, world, spawner)`) |
| Procedure production wiring (P2.5) | `…/core/rts_auto_battle_procedure.gd` (`start()` override 注册 footprint; `_production_system` lazy + step 4e tick; `add_unit_to_team` API) |
| Production smoke (P2.5) | `…/tests/battle/smoke_production.{gd,tscn}` (双 barracks 对称, 30s 跑 600 ticks 验证 ≥ 5 spawn / team + 朝东 ≥ 50px) |
| Team config (P2.6) | `…/logic/config/rts_team_config.gd` (faction_id / starting_resources / build_zone / crystal_tower_id; `unconfigured(team_id)` + `create(...)` 工厂) |
| Player command 基类 (P2.6) | `…/logic/commands/rts_player_command.gd` (tick_stamp + team_id + apply 钩子 + serialize) |
| PlaceBuildingCommand (P2.6) | `…/logic/commands/rts_place_building_command.gd` (apply 走 placement.validate → factory → add_actor → place_building → spend_team_resources → add_unit_to_team → 自动绑 ct_id) |
| Player command queue (P2.6) | `…/logic/commands/rts_player_command_queue.gd` (enqueue + apply_due 按 tick_stamp 升序, 同 tick 保 insertion-order, 决定性) |
| Building placement validator (P2.6) | `…/logic/commands/rts_building_placement.gd` (build_zone / 地图边界 / cells / 资源 全校验, 返回 reason 枚举) |
| Controller override-strategy (P2.6) | `…/logic/controller/rts_unit_controller.gd` (`set_activity_chain(chain, override=false)` + `_player_command_active` flag + `clear_player_command_override`) |
| Procedure 玩家命令 wiring (P2.6) | `…/core/rts_auto_battle_procedure.gd` (`_team_configs / _team_resources / _player_command_queue / _player_commands_log`; tick_once step 1.5 apply_due; `_check_battle_end` 走 `_is_team_lost`) |
| Player command smoke (P2.6) | `…/tests/battle/smoke_player_command.{gd,tscn}` (3 phase: ok/dup/out-of-zone, log 3 entries, resources 扣减) |
| Crystal tower win smoke (P2.6) | `…/tests/battle/smoke_crystal_tower_win.{gd,tscn}` (双 ct + auto-bind ct_id + mark_dead → left_win) |
| Player command + production smoke (P2.6) | `…/tests/battle/smoke_player_command_production.{gd,tscn}` (P2.5+P2.6 联动: 玩家 tick 30 放兵营 → 7 spawns + override-strategy SpawnLane) |
| Battle director (P2.7) | `…/frontend/core/rts_battle_director.gd` (Node, _process tick 推 procedure; tick boundary _capture_prev/curr; 接管 procedure._event_sink; 4 个 signal 给 visualizer) |
| World view (P2.7) | `…/frontend/world_view.gd` (Node2D, 监听 world.actor_added/removed; 路由 director.actor_render_state_updated → visualizer.update_render_state; RtsUnitActor → RtsUnitVisualizer / RtsBuildingActor → RtsBuildingVisualizer 分发) |
| Unit visualizer push (P2.7) | `…/frontend/visualizers/rts_unit_visualizer.gd` (持 actor_id + WeakRef director, 0 处 actor 直读; _process 走 director.get_alpha() 插值 lerp(prev_pos, curr_pos, alpha)) |
| Building visualizer (P2.7) | `…/frontend/visualizers/rts_building_visualizer.gd` (AABB footprint + hp bar + 水晶塔金色边框) |
| Demo wire (P2.7) | `…/frontend/demo_rts_frontend.gd` (改写: world/battle_map/director/world_view 创建 + bind + spawn → start → director.attach; demo._process 逻辑全删) |
| Procedure finish wrap (P2.7) | `…/core/rts_auto_battle_procedure.gd` (finish override: 在 super.finish 返回 dict 上注 player_commands + rng_seed) |
| Director streaming smoke (P2.7) | `…/tests/frontend/smoke_director_streaming.{gd,tscn}` (4v4 走 director path 跑 4s, 验证 render/attack emit + visualizer moved 离 spawn) |
| Replay bit-identical smoke (P2.7) | `…/tests/replay/smoke_replay_bit_identical.{gd,tscn}` (AC10: 同 seed + 同 commands → timeline + commands_log deep equal; HexCoord 字段 q/r 比对) |
| MovementLayer mask 常量 (P2.8) | `…/logic/movement_layer.gd` (`MASK_NONE/GROUND/AIR/BOTH` + `mask_for_layer/mask_matches`) |
| Weapon config (P2.8) | `…/logic/weapons/rts_weapon_config.gd` (`matches/can_hit` static helpers, attacker mask 命中候选 layer 的统一查询) |
| BattleActor 共享攻击协议 (P2.8) | `…/logic/rts_battle_actor.gd` (`current_target_id/target_layer_mask/unit_tags/target_priorities/_cached_target_id/ATTACK_COOLDOWN_TAG` 上推; virtual `get_atk/def/attack_range/attack_speed/can_attack/start_attack_cooldown`) |
| Building 武器字段 (P2.8) | `…/logic/rts_building_actor.gd` (`atk_value/def_value/attack_range_value/attack_speed_value` plain float; override `get_atk/def/attack_range/attack_speed`) |
| Flying scout (P2.8) | `…/logic/config/rts_unit_class_config.gd` (`UnitClass.FLYING_SCOUT` + StatBlock 加 `default_movement_layer/target_layer_mask`; melee=MASK_GROUND, ranged=MASK_BOTH, scout=Layer.AIR+MASK_GROUND) |
| Anti-air tower (P2.8) | `…/logic/config/rts_building_config.gd` (StatBlock 加 atk/def/attack_range/attack_speed/target_layer_mask/unit_tags; archer_tower mask=MASK_AIR, atk=25, range=140) |
| AIR pathfinding (P2.8) | `…/logic/grid/rts_pathfinding.gd` (AIR 层早 return _direct_path) |
| AutoTargetSystem 含建筑 (P2.8) | `…/logic/ai/rts_auto_target_system.gd` (movers + candidates 都是 RtsBattleActor; layer mask 过滤; stance 仅 RtsUnitActor) |
| BasicAttackAction 兼容 building (P2.8) | `…/logic/actions/rts_basic_attack_action.gd` (attacker/target = RtsBattleActor; virtual accessor 取数值; `RtsWeaponConfig.can_hit` 防御性检查) |
| Procedure 建筑攻击循环 (P2.8) | `…/core/rts_auto_battle_procedure.gd` (step 3 building 分支; alive_actors 含建筑给 AutoTargetSystem; `_invoke_basic_attack(RtsBattleActor)`) |
| Visualizer 飞行渲染 (P2.8) | `…/frontend/visualizers/rts_unit_visualizer.gd` (bind 加 p_render_height; _process 减 Vector2(0, render_height)) + `world_view.gd` (spawn 时 hydrate 自 actor.get_render_height()) |
| Demo 城堡战争升级 (P2.8) | `…/frontend/demo_rts_frontend.gd` (双方 ct + archer_tower + 4 ground + 1 flying / 方; HUD Label; 鼠标点击 build_zone → PlaceBuildingCommand) |
| Flying units smoke (P2.8) | `…/tests/battle/smoke_flying_units.{gd,tscn}` (AC7: anti-air 命中 / GROUND 命不到 AIR / 飞行直线穿建筑) |
| Castle war minimal smoke (P2.8) | `…/tests/battle/smoke_castle_war_minimal.{gd,tscn}` (AC8 headless: 玩家放兵营 → 单位攻 ct → result=left_win + AC7 联动) |

---

## 决策记录(P2.8 期间新增)

- **layer mask 用 bitmask 而非 enum 集合**: `target_layer_mask: int` (bit i = 1 << layer); 允许 `MASK_BOTH = MASK_GROUND | MASK_AIR` 一行表达"防空 + 防地", 比 Array[int] 更紧凑 + 更快查询 (单 `&` op)。代价: 调方需用 `MovementLayer.MASK_*` 常量, 不能用 `[Layer.GROUND, Layer.AIR]`; 走 `RtsWeaponConfig.build_mask([...])` helper 兼容 list 风格输入
- **target_layer_mask=0 (MASK_NONE) 表示"不参战"**: 兵营 / 水晶塔 mask=0 → AutoTargetSystem 第 1 遍跳过, BasicAttackAction.can_hit 也返 false。让 worker / non-combatant 类型未来可直接复用此机制 (M1 暂无此类 actor); 也让 building procedure 攻击循环少一道 if 分支 (统一走 mask != 0 = mover 检查)
- **AIR 单位完全 skip A***: RtsPathfinding.find_path 早 return _direct_path. 决定: AIR 层永远 is_passable_for_layer=true, 跑 A* 也是退化为直线最短路径; skip A* 直接 _direct_path 省 N²×log(N) 计算 + 更直观 (飞行单位本就该穿障碍)。代价: 飞行单位无地形避让 (M1 没"高地"概念, Phase 3 P3.1 加 height 后再考虑)
- **Building 用 plain float 字段不扩 RtsBuildingAttributeSet**: archer_tower 需要 atk / attack_range / attack_speed, 但 RtsBuildingAttributeSet 走 LGF apply_config 路径加字段成本高 (要加 `_raw.apply_config` + setter + 视图)。改加 plain float on RtsBuildingActor (atk_value 等); BasicAttackAction 通过 virtual `get_atk()` 走 unit attribute_set 或 building plain float 二选一 — 同 attacker 接口, 不同实现源。trade-off: 建筑攻击数值不能被 buff 系统调整 (P3 经济/buff 真要做时再扩 attribute_set)
- **AutoTargetSystem 全量统一 movers + candidates 为 RtsBattleActor**: 没保留 "units only" 分支 — 决策: 单位 + 建筑共用一套评分 / mask 过滤 / stance 处理 (stance 仅 RtsUnitActor 生效, 建筑无 stance 永远参战)。让 P3 加 worker / 资源采集 / 中立单位类型时不需要再扩另一套 system。代价: 旧 "units only" 调用者(若有) 需转用 alive_actors; 但 P2.7 起 procedure 是唯一调用方, 改一处即可
- **BasicAttackAction attacker_unit_class 字段 -1 兼容 building**: attack_resolved event 的 attacker_unit_class 字段 P2.7 之前 hardcode 为 unit_class enum; building 没这个 enum, 设 -1。logger / replay 消费方应在解析 unit_class 时 == -1 fallback (M1 范围内 hex 例子 logger 不消费此字段, RTS logger 也不强 case; AC3 melee_max_dist / ranged_max_dist 断言只看 unit, 不看 building, 所以 -1 不破断言)。Phase 3 加更复杂 attack visualizer 时考虑用 attacker_id + attacker_kind ("unit" / "building" string) 替代
- **单位攻击建筑通过 AutoTargetSystem 自然驱动 (不显式扩 strategy)**: RtsBasicAttackStrategy 仍读 `actor._cached_target_id`, AutoTargetSystem 现在写的可能是 building id; AttackActivity 接受 RtsBattleActor 当 target → 单位自动追击 building 直至打死。决策: 不需要为"单位攻击建筑"单独写 strategy 子类 (那会是 over-engineering — strategy 本质是"谁打谁", building target 复用既有路径)
- **demo 鼠标点击放兵营走 _unhandled_input**: 不用 InputEvent 信号(无 Control 节点 root);  `_unhandled_input` 接 InputEventMouseButton MOUSE_BUTTON_LEFT pressed; build_zone Rect2.has_point 校验 + enqueue PlaceBuildingCommand tick_stamp=current_tick 即时应用。代价: 没 UI 反馈失败原因 (cells_blocked / out_of_build_zone) — Phase 3 RtsScenarioHarness 时再加 toast 反馈
- **flying_scout collision_radius=10 与 ranged 同**: AIR 层独立 steering (P2.2 已 cross-layer skip), 与地面单位无 sep 干扰; 同层 (AIR) 飞行单位间 sep 半径 = 2r=20 px, 适合空中编队; 不与 melee 12 同 — 飞行单位较小是常识 (combat aircraft 比 ground vehicle 小)


## 残余风险(从 Phase 1 继承; 跨 phase 不变)

- **AC9 hex demo segfault on shutdown**(`archive/2026-04-30-rts-auto-battle/Summary.md`): 本轮 hex demo headless 跑出 `结果: left_win` 且退出码 0 — segfault 没复现, 不阻塞 Phase 2 P2.7 验收。
- **30Hz default tick 与 50ms M0 smoke 兼容**: smokes 仍 explicitly 传 `tick_interval_ms = 50.0`; 30Hz 默认仅在 demo / 新调方启用。P2.7 director SIM_DT 走 procedure.get_tick_interval, smoke 传 50ms 时 director 也按 50ms 推 — 不破。
- **录像 still partial**: P1.7 仅写 `world_snapshot.rng_seed` 给 light determinism; P2.6 加 `_player_commands_log` 字段; **P2.7 procedure.finish 把两者注入 record dict** (基础 BattleRecorder 的 timeline + RTS 专属 player_commands + rng_seed); 完整 RtsRecording 类型 + ReplayPlayer 仍未落地 (smoke 直接走 dict 比对; 实际 replay player UI 在 RTS 范围外).
- ~~**单位不能攻击建筑** (P2.7 仍未解, 留 P2.8 解决)~~: ✅ P2.8 解决 (AutoTargetSystem 候选含 RtsBattleActor; BasicAttackAction attacker/target 都放宽; AttackActivity target 类型放宽 RtsBattleActor; smoke_castle_war_minimal unit_to_building_attacks=4 验证)。
- **building 攻击数值不可被 buff 调整 (P2.8 引入 plain float 字段)**: archer_tower atk_value/attack_range_value 是 plain float, 不走 LGF attribute_set / buff 调整路径. P3 经济或 building upgrade 系统真要做时, 把这些字段挪进扩展版 RtsBuildingAttributeSet (类似 RtsUnitAttributeSet)。
- **flying 单位无 stuck detection (走 _direct_path 不调 A*)**: AIR 单位起手就走 _direct_path, 永远不会 path 空 → stuck detector 的 `has_target() && !is_at_final_target()` 仍触发? 实际看: AIR 单位的 nav_agent 路径只有 1 个 waypoint (to_world), 抵达后 _waypoint_index 推进; 不会"卡 path 中间"。stuck_detector.tick 仍执行但不会 trigger abandon (因为单位每 tick 都有位移)。Phase 3 P3.2 group formation 时若有飞行单位 cluster 卡在目标点, 再考虑加 AIR 专属 stuck handling。
- **demo F6 流程 user 视觉验证**: AC8 acceptance 写明 "F6 跑 demo_rts_frontend.tscn ... 玩家可放置建筑 ... 塔被毁判胜负" 这部分 headless 不能验证 (鼠标点击 + 视觉 + 渲染插值 + HUD label) — 必须用户在编辑器里 F6 实际走流程。smoke_castle_war_minimal 只验 logic 等价路径; demo 视觉链由用户 sign-off。
- **P2.6 UpgradeBuildingCommand / SellBuildingCommand 子类未落地**: 仅留 `RtsPlayerCommand` 基类 + apply 钩子接口预留; Phase 2 acceptance 不需要这两个子类。Phase 3 经济系统改造时再补全。
- **P2.7 视觉特效 stub**: visualizer 当前仅圆圈 + hp 文本 + 死亡调暗; 没有攻击特效 / 飘字 / 投射物 (hex 例子有 BattleAnimator 完整管线; M1 范围内 RTS 简化 — 对应 hex BattleAnimator / RenderWorld / ActionScheduler 的全套表演层架构留 P3+ 或后续 milestone)。AC6 主断言只关心"streaming events 链路工作 + 0 处 polling actor",视觉特效不在 acceptance 内。
- **P2.7 player_commands_log 暴露在 procedure.finish**: 扩字段直接挂在 dict 上, 不是新建 RtsRecording 类型。如果 P3+ 出现"加更多 RTS 专属字段" (如 deaths log / 资源采集事件流), 可考虑封一层 RtsRecord helper 或 wrap stdlib BattleRecorder; 当前 deferred — 只 2 字段时直接 dict 注入更轻。

---

## 决策记录(P2.7 期间新增)

- **P2.7 Director 选 "实时 sim" 而非 "离线 replay"**: hex 例子 FrontendBattleDirector 是离线模式 (跑完战斗 → 加载 ReplayData → animator 离线播放); RTS Director 选实时 — 持 procedure 引用, _process(delta) 推 procedure.tick_once + 同时 push render state. 理由: RTS 是连续 sim 不是回合制 ATB, 离线播放 60s 的 replay 太重 (timeline 体积大、frontend 不需要 scrub-able replay UI); 实时模式让 frontend 跟 sim 同步, 与 SimulationManager 未来接 web 桥接的需求兼容
- **P2.7 frontend "0 处 actor 直读" 边界放在 visualizer / world_view, 不放在 director**: AC6 主断言指的是"sync()/polling 模式废除", 不是"frontend 0 处碰 actor". Director 在 tick boundary 单次 snapshot actor.position_2d / hp / is_dead 是合规的 "logic → frontend 状态投影" — 与 hex RenderWorld 的 in-memory snapshot 模式同构. visualizer / world_view 100% 0 处直读 actor (visualizer 持 actor_id 而非 actor 引用). 如果 P2.8+ 嫌 director 直读也不够纯, 可让 procedure 把 actor 状态作为 events 的一部分 emit; 当前 deferred — 边界投影模式与 30Hz tick 性能更友好 (不需要每帧 emit 8+ 个 position event)
- **P2.7 visualizer 走 push 模式 + 起手 pull**: 标准做法是纯 push (signal-driven), 但 visualizer.bind 时 director 可能还没 emit 过 (典型: world_view.bind 在 director.attach 之前 — 因为 director.attach 需要 procedure 已存在, procedure 在 spawn 完后才 start_battle). 解决: visualizer.bind 内 pull 一次 director.get_render_state(actor_id) 作起手填充, 之后 push update_render_state. director.attach 内也 broadcast 一遍 — 双 path 兜底. 不让 visualizer.bind 与 director.attach 顺序硬绑定, demo / smoke 可灵活组合
- **P2.7 alpha 插值用 director.get_alpha() 而非 visualizer 自己累 dt**: visualizer 自己累 dt 会与 director 内部 SIM_DT 计算口径不一致 → 插值锯齿 / 跳跃; 让 visualizer 走 director.get_alpha() (= clamp(_accumulator_ms / _sim_dt_ms)) 保证全部 visualizer 同 phase 同 alpha — 8 个单位每帧渲染一致前进
- **P2.7 actor.position_2d 写入 in spawn 阶段保留**: demo._spawn_unit 仍 `actor.position_2d = pos` 写入. 这是创建期 setup, 不是 polling, AC6 不禁止写入. 把 spawn 位置作为 spawn opt 传给 actor 构造 (RtsUnitActor.new(unit_class, position) 之类)是更纯的设计 — 但会改变 spawn signature 影响所有 smoke; deferred 到 Phase 3 一并整理
- **P2.7 procedure.finish dict wrap 注入 player_commands + rng_seed 不动 stdlib**: BattleRecorder 是 stdlib (硬约束 1 不动); RTS 专属字段只能在 RTS 层注入. procedure.finish override 把 super.finish() 返回的 dict 加 RTS 字段 — 简洁, 不引入 wrapper 类. AC10 smoke 直接读 finish() dict 即可比对
- **P2.7 IdGenerator.reset_id_counter() 在 smoke 两跑之间手动调**: GameWorld.destroy / re-init 不会自动 reset (IdGenerator 是全局静态计数器, 跨 GameWorld 实例累加). smoke_replay_bit_identical 显式调一次, 让两次跑产生同 actor id (Building_10 vs Building_10), source_actor_id / target_actor_id 字段 deep equal. 生产环境 replay 时 ReplayPlayer 也需要按相同顺序 spawn actor (新 GameWorld + reset id counter); smoke 验证此前提工作
- **P2.7 deep equal 对 HexCoord 走 q/r 显式比对**: Godot Dictionary.hash() 对 Object 类型走 instance id, 同结构不同实例 hash 不等 — smoke 第一次跑用 hash() 失败. 改递归 _deep_equal: Dictionary / Array 递归; HexCoord cast 后 q/r 比对; 其它走 ==. 用 JSON.stringify 也能比但 HexCoord 不是 JSON-friendly, 需先 to_dict
- **P2.7 visualizer 起手位置 fallback 不走 (0,0)**: 当 director.get_render_state 在 visualizer.bind 时返回空 (director.attach 前), visualizer 仍能从 actor_added signal 触发, 但此时位置是默认的 _curr_pos = Vector2.ZERO. 解决: bind 内 pull state 拿到 hydrate 后立即 set position (上一处也 set). 即使 pull 空, 下一次 director.attach broadcast_initial_state 会路由到 visualizer 修正 — 一帧渲染前位置最终正确
- **P2.7 不在 P2.7 范围内做表演特效 (攻击 vfx / 飘字 / 投射物)**: hex 例子有完整 BattleAnimator + ActionScheduler + RenderWorld + visualizer 4 层管线; RTS M1 P2.7 仅做最小 director 链路 + 圆圈 visualizer push. AC6 acceptance 不要求视觉特效层 — director.attack_resolved signal 已 emit, 给后续 P3+ 表演层接 hooks 用. 当前 visualizer 不订阅 attack_resolved (即使收到也只数数据流验证), 写入特效层是 P3+ 工作


## 决策记录(P2.6 期间新增)

- **P2.6 RtsTeamConfig 不强制 crystal_tower_id 存在**: `crystal_tower_id == ""` → `has_crystal_tower()=false` → `_check_battle_end` 走 fallback team-wipeout (Phase 1 行为)。这让 4v4 主 smoke 不需要任何 team_configs 配置就能跑, 与"不破回归"硬约束对齐
- **P2.6 自动绑 crystal_tower_id 在 procedure.start() 而非 placement command**: smoke / 调方常在 add_actor 之后才 set position; start() 此时所有起手建筑 position 已就位。但 PlaceBuildingCommand 战斗中放下水晶塔时也要绑 — 故 PlaceBuildingCommand.apply 内部也有"crystal_tower_id == "" → 绑定"逻辑 (双 path 都覆盖)
- **P2.6 player_command 走 tick_stamp 而非 frame-stamp**: tick 是逻辑时间, frame 是渲染时间; replay 用 tick 保证 deterministic. 同 seed + 同 player_commands (tick_stamp 序) → 同 apply 顺序 → 同 sim 输出 (smoke_determinism 仍 bit-equal 验证)
- **P2.6 失败命令进 history.failed 而不静默丢弃**: replay / UI 反馈需要"为何失败" (玩家放兵营失败要给 UI 提示)。failed entry 含 reason 枚举字符串, 不含具体本地化文案 — UI 层映射到本地化文案
- **P2.6 placement validator 是纯函数**: `RtsBuildingPlacement.validate` 不 new actor / 不写状态; 只检查并返回 result dict。失败时不创建 building → 失败 path 干净, 不留 ghost 实例。成功时返回 footprint 给调方继续 (避免重算)
- **P2.6 `_player_command_active` 与 `_command_abandoned` 互斥优先**: stuck 单位被 abandoned 后, 玩家给新命令 (`set_activity_chain(chain, override=true)`) 应能"复活"单位 — 否则 abandoned flag 会让单位永远 idle, 玩家 UI 没法操控。set_activity_chain(override=true) 时一并清 _command_abandoned
- **P2.6 crystal_tower 默认 cost=0 而非 1000+**: 玩家不能花钱建主基地 (主基地是 scenario 起手放置的); cost=0 让 smoke / 调方在战斗中通过 PlaceBuildingCommand 放主基地也合法 — 适合 Phase 3 RtsScenarioHarness 走玩家命令 setup 路径。barracks=100 / archer_tower=50 是经济占位, P3 经济系统重做时再调
- **P2.6 不修 RtsAutoTargetSystem 让单位选 building 为目标**: AutoTargetSystem 只挑 RtsUnitActor (line 116/134); BasicAttackAction 也只 cast target as RtsUnitActor (line 59); 让单位攻击建筑是 P2.7+ 的工作 (需要 building 的 attribute_set / 受击事件等完整 wiring)。P2.6 范围内 smoke_crystal_tower_win 走"手动 mark_dead"模拟塔被打死 — 验证胜负判定逻辑就够 (P2.6 deliverable)
- **P2.6 smoke 设置双 crystal_tower 而不是单方**: 双方都有 ct 让两边都走 crystal-tower 模式 (而非一边 ct + 一边 fallback); 测试一致性更好。fallback 兼容性由 4v4 主 smoke 间接验证 (无 team_configs → unconfigured → fallback 工作良好)
- **P2.6 spawn_unit_kind 字段保持在 RtsBuildingActor**: 不挪到 RtsBuildingConfig — building 实例在 spawn 后可能改变 stats (升级建筑 buff), 让 actor 持当前实际值。config 只是"出生模板", actor 是"运行时 source of truth"

## 决策记录(P2.1-P2.5 期间新增)

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
- **P2.5 spawner: Callable opts vs procedure 自接管**: 选 Callable 注入 (与 event_sink / unit_runtimes 同模式)。spawner 由 smoke 实现 — 创建 RtsUnitActor + RtsNavAgent (Node2D, 需要场景树 parent) + RtsUnitController + 注册到 unit_runtimes + 调 `procedure.add_unit_to_team`. production_system 保持纯 RefCounted, 不感知场景树, 决定性更可控
- **P2.5 footprint 注册放 `procedure.start()` 而不是 `world.add_actor` 之时**: smoke / 调方常在 `add_actor` 之后才 set position_2d, 此时 footprint cells 还是上一次或默认; 推迟到 `start()` (`super.start()` 之后) 时所有 building 的 position 已就位。代价: 战斗中通过 spawner / 玩家命令 (P2.6) 新增建筑要 spawner 自己负责 `world.rts_grid.place_building`, 但这刚好是 P2.6 PlaceBuildingCommand 的职责
- **P2.5 production_period_ms 满周期减一周期 (而非清零)**: `_production_progress_ms -= production_period_ms` 让 dt 溢出量保留, spawn 节奏稳定; 清零会让"刚好满周期触发 spawn 时 dt 余量丢失", 长跑后单位生成数量低于理论值。50ms tick vs 4000ms 周期差 80×, 实战影响小, 但保留 (P3 高速 tick / 慢速建筑组合时差异显著)
- **P2.5 spawner 返回 null 视为 spawn 失败但 progress 不重置**: 玩家 cap 已满 / spawn 位被占等暂时性失败时下次 tick 继续重试; progress 不退也不清。代价是溢出累积 (调方负责 cap progress 或忽略); P2.6 玩家命令系统接入时若需要 strict cap 可在 spawner 内 progress 强制截断
- **P2.5 add_unit_to_team 不更新 base BattleProcedure._participant_ids**: base 用 _participant_ids 仅做 in_combat 标记; 后加入单位无 in_combat 也无 abilities 依赖此标记 (M1 范围内). P2.7 频繁加入新 actor 时若需要 in_combat 一致, 再扩 add_unit_to_team 接 base API
- **P2.5 SpawnLane 初始 activity 当前会被 strategy.decide override**: spawner 设 `RtsAttackMoveActivity(target_pos)` 但 controller.tick reconcile 规则: current=AttackMoveActivity vs proposed=IdleActivity (无敌时) / AttackActivity (有敌时), is_equivalent_to=false → cancel + 替换。P2.5 双兵营布局两边都有敌 → strategy 接管 AttackActivity 让单位向中场敌人移动, 视觉效果与 SpawnLane 一致 (units 朝 enemy 推进)。P2.6 玩家命令系统会引入"player command 优先级"机制让 SpawnLane / PlayerCommand 不被自动 override; 当前保留 set_activity_chain 调用作为 P2.6 接口预留 + 文档意图标记

---

## Phase 1 摘要(已完成 2026-05-01)

详见 [`task-plan/phase-1-foundation.md`](task-plan/phase-1-foundation.md)。9/9 AC 全过, 不归档(同一 feature 早期 phase, 归档放整个 RTS M1 重构完成时做)。
