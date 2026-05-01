# Phase 1 — Foundation（M1 启动前不可妥协修复 + 基础设施）

> **状态**：当前 active phase
> **进入条件**：M0 已验收（`.feature-dev/archive/2026-04-30-rts-auto-battle/`）
> **退出条件**：本文档 §收口条件 全过 → 切换到 Phase 2

---

## Phase 目标

修复 RTS M0 架构审查报告中**对 LGF 根原则的硬偏离**（S1/S2/S3/M4），并铺好 M1 后续工作的基础设施（fixed tick + grid wrapper + actor 三层基类）。

**核心承诺**：Phase 1 完成后，RTS 4v4 仍能跑到 winner，且代码骨架支持 Phase 2 平滑加入 Activity / Steering / Production / Player Command。

---

## 进入条件

- M0 acceptance 5/5（半通过 AC5 已记录残余风险，不阻塞）
- `archive/2026-04-30-rts-auto-battle/` 已生成（已存在）
- `task-plan/architecture-baseline.md` 已落盘（同轮生成）
- LGF 73/73 PASS

---

## Sub-tasks

### P1.1 — RtsBattleActor 三层基类落地

**目标**：用 `RtsBattleActor` 基类 + `RtsUnitActor` / `RtsBuildingActor` 子类替换现有的 `RtsBattleActor + RtsCharacterActor` 二元结构，为 Phase 2 building production 铺路。

**改动范围**：
- 修改：`logic/rts_battle_actor.gd`（变成基类）、`logic/rts_character_actor.gd`（重命名为 `rts_unit_actor.gd`，extends RtsBattleActor）
- 新增：`logic/rts_building_actor.gd`（基类，暂时空 fields 但骨架到位）
- 新增：`logic/buildings/`（目录，Phase 2 才填工厂；本 phase 只建空目录 + README）
- 新增：`logic/movement_layer.gd`（enum: GROUND, AIR）
- 修改：所有 `RtsCharacterActor` 引用 → `RtsUnitActor`

**实现要点**：
- 字段对齐 `architecture-baseline.md §4`：`position_2d / velocity / collision_radius / movement_layer / team_id`
- 默认 `collision_radius = 14.0`（D3-G）
- 默认 `movement_layer = GROUND`
- `writes_to_pathing_map()` Unit 默认 false，Building override true
- 照抄 hex `_on_id_assigned` / `check_death` / `is_pre_event_responsive` 模式

**验证**：
- `godot --headless --path . --import > /tmp/import.txt 2>&1` exit 0
- `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_skeleton.tscn > /tmp/p1_1_skeleton.txt 2>&1` 末尾 `SMOKE_TEST_RESULT: PASS`
- LGF 73/73 PASS

---

### P1.2 — RtsBattleGrid wrapper + ultra-grid-map 集成

**目标**：用 `RtsBattleGrid`（wrapper 包 `GridMapModel`）取代现有 `NavigationServer2D / NavigationAgent2D`。Phase 1 做"简单 A* 路径跟随 + 最简圆形 push-out"，**不加** Phase 2 的完整 steering / stuck recovery / spatial hash。

> **为什么需要 push-out**：M0 用 NavigationAgent2D 自带 `avoidance_enabled` 让单位互相避开。本 phase 替换为纯 A* 后**没有任何单位互避机制**，4v4 短兵相接时单位会重叠（`collision_radius` 不被尊重），导致主 smoke 的 `melee_max_dist=24` 断言假阳。**最简 push-out 不是完整 steering**，只是 O(N²) 双重循环：每 tick 检查所有单位对，距离 < 两半径之和则按差向量按比例推开。Phase 2 P2.2 用 spatial hash + steering 完整替换。

**改动范围**：
- 新增：`logic/grid/rts_battle_grid.gd`（wrapper，持 `GridMapModel`）
- 新增：`logic/grid/rts_pathfinding.gd`（包 `GridPathfinding.astar`，提供 `find_path(from_world, to_world, layer) -> Array[Vector2]`）
- 新增：`logic/movement/rts_minimal_push_out.gd`（Phase 1 最简版，Phase 2 被 `rts_unit_steering.gd` 替换）
- 修改：`frontend/scene/rts_battle_map.gd`（去掉 `NavigationRegion2D` 编程式构造，改为 grid + 矩形障碍配置）
- 修改：`logic/components/rts_nav_agent.gd`（**删除 NavigationAgent2D 依赖**；改成"持当前路径 + 当前 waypoint index + 前进 to next"的纯 GDScript）
- 修改：`core/rts_world_gameplay_instance.gd`（持 `grid: RtsBattleGrid` 字段，replace `navigation_region`）

**实现要点**：
- `RtsBattleGrid` 内部走 `ultra-grid-map` 的 `GridMapModel`（grid_type = SQUARE, cell_size = 32）
- **不修改 ultra-grid-map plugin**（D3-F 硬约束）
- ultra-grid-map plugin 用 `HexCoord` 类作为通用 cell 坐标，**即使 SQUARE grid 也是**；RTS 代码遵循此约定（cell 坐标变量类型 = `HexCoord`，世界坐标变量类型 = `Vector2`）
- 维护 **footprint 反向索引**（不是 spatial 索引 — spatial hash 是 Phase 2 P2.2）：
  - `_actor_footprint: Dictionary[String, Array[HexCoord]]`：每个 actor 当前 footprint cell 列表
  - `_cell_occupants: Dictionary[String, Dictionary[String, bool]]`：每个 cell 知道有哪些 actor footprint 包含它（用作 Set<actor_id> — Godot 用 Dictionary 模拟 Set）
  - 之所以需要这个反向索引：hex `tile.occupant: Variant` 是单值（一格一单位），RTS 一格可能多单位（`collision_radius < cell_size/2` 时）
- **Pathing map 写入语义**：
  - 建筑 `place_building(actor_id, footprint_cells)` → 设 `tile.is_blocking = true`（**写入 pathing map**，A* 永远绕开）
  - 单位 `register_actor` → **不写 pathing map**（WC3 风），只更新 `_actor_footprint / _cell_occupants` 反向索引
- `find_path(from_world, to_world, layer)` 调 `GridPathfinding.astar(model, from_cell, to_cell, is_passable_for_layer(layer))`，返回路径的 world 坐标 array
- 飞行单位 layer = AIR：**Phase 1 接口预留**（`is_passable` callback 对 AIR 直接 return true），但 AIR unit_class / weapon target_layer_mask 等完整功能在 Phase 2 P2.8 才落地
- **最简 push-out 算法（仅 Phase 1 用）**：
  ```
  for each pair (a, b) in alive_units:
      dist = a.position_2d.distance_to(b.position_2d)
      min_dist = a.collision_radius + b.collision_radius
      if dist < min_dist and dist > 0.001:
          push_dir = (a.position_2d - b.position_2d) / dist
          overlap = min_dist - dist
          a.position_2d += push_dir * overlap * 0.5
          b.position_2d -= push_dir * overlap * 0.5
  ```
  - O(N²)，4v4 = 28 对完全可接受；Phase 2 spatial hash 替换为 O(N·k)
  - 决定性：迭代顺序 = `world.get_alive_actors()` 顺序（GameWorld 保证插入顺序），不用 randf
  - 跨 layer 不互相挤（Phase 1 GROUND only，无所谓；Phase 2 P2.8 加 AIR 时这里需扩展 layer check）

**验证**：
- 新 smoke `tests/battle/smoke_grid_pathfinding.tscn`：放 1 个 unit 在 (50, 250)，目标 (450, 250)，中央 grid cell 标 blocking；跑 5 秒 tick；最终位置 ≈ target 且中途 max_y_deviation ≥ 30（绕路证据）
- 新 smoke `tests/battle/smoke_minimal_push_out.tscn`：4 个单位同时朝同点移动，验证最终任意两单位距离 ≥ `collision_radius * 2 - 0.5`（容差 0.5px）
- 现有 `smoke_navigation.tscn` 适配新 API 后仍 PASS
- 验证 RTS 例子代码中 **0 处** `NavigationServer2D` / `NavigationAgent2D` 引用：`grep -r "NavigationServer2D\|NavigationAgent2D" addons/logic-game-framework/example/rts-auto-battle/` 应返回空
- LGF 73/73 PASS

---

### P1.3 — Procedure 主循环内化（修复 S1）

**目标**：消除 5 处 `_per_tick` 复制，把"AI tick + nav tick + cooldown tick + attack 触发"全部内化进 `RtsBattleProcedure.tick_once()`。所有调方走 `world.start_battle()`。

**改动范围**：
- 修改：`core/rts_auto_battle_procedure.gd`
  - 移除 `opts["per_tick"]` 接口
  - 内化主循环（参照 `architecture-baseline.md §5`）
  - procedure 持 `_unit_runtime: Dictionary[actor_id, {agent, controller}]`，构造时由 demo / smoke 注入 binding
- 新增：`core/rts_demo_world_gameplay_instance.gd`（hex 同构 — `RtsWorldGameplayInstance` 子类，承担 demo-specific 配置）
- 修改：`core/rts_world_gameplay_instance.gd`
  - override `_create_battle_procedure(participants)` 创建 `RtsBattleProcedure`
- 改 5 处调方都走 `world.start_battle()`：
  - `frontend/demo_rts_frontend.gd:110-130`
  - `tests/battle/smoke_rts_auto_battle.gd:164-184`
  - `tests/battle/smoke_attack.gd:123-144`
  - `tests/battle/smoke_ai.gd:114-123`
  - `tests/battle/smoke_navigation.gd`

**实现要点**：
- 主循环顺序锁定（参照 `architecture-baseline.md §5`）
- `dt` 永远是 `SIM_DT = 1.0/30.0`（P1.7 完成后才真正 fixed-tick；本 phase 先把内化做了，dt 仍可由参数传入但内部所有计算用 SIM_DT）
- procedure 持 `_active_battle` 状态、`battle_finished` signal 能广播（hex 同构）
- **Phase 1 期间主循环包含 P1.2 引入的 `minimal_push_out.resolve(world.get_alive_units(), grid)`**，位置在"single 6c 单位推进"之后、"录像帧写入"之前；Phase 2 P2.2 用完整 steering 替换
- **Phase 1 期间 `recorder` 是 no-op**（不接 BattleRecorder），主循环里 `recorder.record_current_frame()` 调用是占位 — 完整流式录像在 Phase 2 P2.7 接通；但 RNG seed 在 P1.7 已经写入 procedure 起始状态，便于 light determinism smoke 验证

**验证**：
- `grep -rn "per_tick" addons/logic-game-framework/example/rts-auto-battle/` 应返回空（除 design note）
- 现有 5 处 smoke 都 PASS
- 主 smoke `smoke_rts_auto_battle.tscn` 仍跑到 left_win/right_win
- LGF 73/73 PASS

---

### P1.4 — RtsBasicAttackAction → Action.BaseAction（修复 S2）

**目标**：把 `RtsBasicAttackAction extends RefCounted` 静态 helper 改造成 `extends Action.BaseAction`，复用 hex 已经验证过的 Pre/Atomic/Post 三段管线。

**改动范围**：
- 修改：`logic/actions/rts_basic_attack_action.gd`
  - `extends Action.BaseAction`
  - 实现 `_execute(ctx: ExecutionContext) -> ActionResult`
  - 接收 `target_selector: TargetSelector`（参照 hex `damage_action.gd`）
  - 走 `event_processor.process_pre_event(pre_damage_event)` → 原子操作 → `broadcast_post_damage(...)`
  - 加 `_freeze() / _verify_unchanged()` 状态校验
- 新增：`logic/target_selectors.gd`（RTS 版的 TargetSelector，提供 `CurrentTarget` 实现，从 `actor.current_target_id` 拿 target）
- 修改：调用方（procedure / unit_controller）从 `RtsBasicAttackAction.execute(attacker, target, world)` 改为 `action.execute(ctx)` 包装

**实现要点**：
- 完全照抄 hex `damage_action.gd:38-158` 的三段范式
- Pre handler 留 hook（M1 还没有实例化的 buff/passive，本 phase 先空着）
- on_hit / on_critical / on_kill 回调留 hook
- TargetSelector 不直接读 actor 字段，走 ExecutionContext

**验证**：
- 现有 `smoke_attack.tscn` PASS（攻击行为仍正确）
- 主 smoke `smoke_rts_auto_battle.tscn` 仍跑到 left_win/right_win
- LGF 73/73 PASS

---

### P1.5 — RtsAIStrategy + RtsUnitController 拆分（修复 S3）

**目标**：拆 `RtsBasicAI` 为两层：`RtsAIStrategy`（无状态共享，`decide(actor, world) -> Intent`）+ `RtsUnitController`（每 actor 一份，持 runtime state 如 cooldown / target / nav state）。

**改动范围**：
- 删除（或重命名）：`logic/ai/rts_basic_ai.gd`
- 新增：`logic/ai/rts_ai_strategy.gd`（基类，hex `AIStrategy` 同构）
- 新增：`logic/ai/rts_basic_attack_strategy.gd` extends `RtsAIStrategy`（无状态 `decide` 实现）
- 新增：`logic/ai/rts_ai_strategy_factory.gd`（持 static var 共享实例，照抄 hex `AIStrategyFactory`）
- 新增：`logic/controller/rts_unit_controller.gd`（每 unit 一份，持 nav_state / current_target_id / cooldown_tag_id）
- 修改：`procedure._unit_runtime` 字典从 `{ai}` 改为 `{controller}`，AI strategy 通过 factory 拿 shared instance

**实现要点**：
- **Strategy 严格无状态**：`decide(actor, world) -> Intent`，不持任何字段
- Intent 结构：`{action: "approach" | "attack" | "idle", target_id: String, target_pos: Vector2}`
- UnitController 接 Intent，决定下一帧做什么（推进 nav / 触发 attack）
- **S3 修复在 Phase 1 是部分修复**：
  - **根原则违反完全修复** — strategy 无状态共享（破"shared 必须无状态"）+ controller 持 runtime state（不再混在 strategy 里）
  - **字符串 FSM 残留**：Intent 仍是 `{action: "approach" | "attack" | "idle"}` 字符串机制，**封装在 UnitController 内**，不外露给 Strategy / Procedure；这是 Phase 1 的渐进迁移妥协
  - **完整解决在 Phase 2 P2.1**（Activity 系统）：`AIStrategy.decide()` 改返回 `Activity` 实例，UnitController 持 `current_activity: Activity`，字符串完全消失
  - 这样设计的原因：Phase 1 同时改 strategy 拆解 + Activity 替换会导致变化面太大，难以独立验证；分两步走每步验证范围小
- 实现时在 controller 内的 string 字段加注释 `# Phase 1 临时, Phase 2 P2.1 替换为 Activity`，便于下个 phase 接手者识别

**验证**：
- `grep -rn "extends.*AI" logic/ai/` 显示 strategy 无状态、factory 持 static var
- `grep -rn "last_decision" logic/ai/` 应返回空（被 UnitController 内部状态取代）
- `grep -rn "shared.*state\|self\.actor\b\|self\._agent\b" logic/ai/` 应返回空（strategy 无字段绑定 actor）
- `smoke_ai.tscn` PASS
- 主 smoke PASS
- LGF 73/73 PASS

---

### P1.6 — Cooldown 走 tag-duration（修复 M4）

**目标**：消除 `attack_cooldown_remaining: float` 裸字段，统一走 LGF 的 `ability_set.tag_container.add_auto_duration_tag(...)`，与 hex `BattleAbilitySet.start_cooldown` 同套机制。

**改动范围**：
- 修改：`logic/rts_unit_actor.gd`
  - 删除 `attack_cooldown_remaining: float`
  - 删除 `tick_attack_cooldown(dt)`
  - 加 `is_attack_on_cooldown() -> bool`（查 `tag_container.has_tag("attack_cooldown")`）
- 修改：attack action 触发后调 `ability_set.tag_container.add_auto_duration_tag("attack_cooldown", 1.0/atk_speed)`
- 修改：UnitController 检查 `actor.is_attack_on_cooldown()`，不再读 `attack_cooldown_remaining`
- 删除：procedure 主循环的 `tick_attack_cooldown` 调用（tag duration 由 `ability_set.tick(dt)` 自动推进）

**实现要点**：
- 利用 LGF 现成的 `tag_container.add_auto_duration_tag` API
- attack speed (atk/s) → cooldown duration = 1.0 / atk_speed
- Phase 2 加 buff "加速 cooldown 50%" 时直接走 modifier 系统，零特例代码

**验证**：
- `grep -rn "attack_cooldown_remaining" addons/logic-game-framework/example/rts-auto-battle/` 应返回空
- `smoke_attack.tscn` PASS（攻击节奏不变）
- 主 smoke PASS
- LGF 73/73 PASS

---

### P1.7 — Fixed 30Hz tick + RtsRng autoload + light determinism

**目标**：把 procedure 推进改为 fixed 30Hz tick（不依赖 wall-clock delta），引入 `RtsRng` autoload 持种子，验证 light determinism（同 seed → 同 winner + 同 final hash）。

> bit-identical event_timeline 验证留到 Phase 2（player commands 接入后）。

**改动范围**：
- 新增：`logic/rts_rng.gd`（autoload script）
  - 持 seed + `RandomNumberGenerator` 实例
  - 提供 `randf() / randi() / randf_range(min, max)`
  - `set_seed(seed: int)` 重置 RNG
- 修改：`project.godot` autoload 列表加 `RtsRng`（**需要用户授权**——硬约束 #5 中"修改 project.godot autoload"要先确认）
- 修改：procedure 内 wall-clock 推进 → `accumulator += real_dt; while accumulator >= SIM_DT: tick_once(); accumulator -= SIM_DT`
- 全代码 grep `randf\b\|randi\b\|RandomNumberGenerator` 替换为 `RtsRng.*`（除现有 ultra-grid-map / LGF core 内代码）
- 新增：`tests/replay/smoke_determinism.tscn`
  - 跑 4v4 战斗 2 次，相同 seed
  - 收尾比对：同一 winner + 同一总 ticks ± 1（容许 1 帧漂移因 floating point order，但战略结果不变）
  - 失败 → `SMOKE_TEST_RESULT: FAIL - <reason>`

**实现要点**：
- Frontend 渲染层不改 — 它仍用 `_process(delta)` 拉 actor.position_2d（Phase 1 末仍是 state polling，Phase 2 P2.7 才接 BattleDirector 流式）
- accumulator 模式：每个 frontend frame 推 N 个 logic tick（N 取决于实际 fps）
- RtsRng 必须在 procedure 构造时显式 reset 到 seed（不依赖 autoload init 顺序）
- **录像状态明确**：
  - Phase 1 **不接通完整 BattleRecorder**（流式录像在 Phase 2 P2.7 落地）
  - Phase 1 P1.7 落地的最小录像基础：在 procedure 起始构造一个 `world_snapshot: Dictionary` 含 `rng_seed`，便于 light determinism smoke 验证（不需要事件流，只需要 winner + total_ticks 比对）
  - `event_timeline / player_commands` 字段在 Phase 2 P2.6+P2.7 接通；本 phase 主循环里如果调 `recorder.record_current_frame()` 它是 no-op（接口占位）
  - bit-identical event_timeline 验证留到 Phase 2 P2.6+P2.7 之后做 — 那时 player_commands 接入 + recorder 真正流式输出，才是完整 replay 路径

**验证**：
- `grep -rnE "\brandf\(|\brandi\(|RandomNumberGenerator" addons/logic-game-framework/example/rts-auto-battle/` 应只返回 RtsRng 内部
- `smoke_determinism.tscn` PASS（同 seed 跑 2 次结果一致）
- 主 smoke `smoke_rts_auto_battle.tscn` PASS
- LGF 73/73 PASS
- hex demo 不退化（半通过状态保持）

---

## 顺序依赖

```
P1.1 (Actor 基类) ──┐
                    ├──> P1.3 (Procedure 内化) ──> P1.4 (Action) ──> P1.5 (AI 拆) ──> P1.6 (cooldown) ──> P1.7 (fixed tick + determinism)
P1.2 (Grid) ────────┘
```

P1.1 与 P1.2 可并行（独立改动），但都是 P1.3 的前置（procedure 内化要拿到新基类与 grid）。

---

## 收口条件（Phase 1 acceptance）

- [ ] **AC1 — S1 修复**：`grep "per_tick" rts-auto-battle/` 返回空（除 design note）；procedure.tick_once 内化所有推进
- [ ] **AC2 — S2 修复**：`RtsBasicAttackAction extends Action.BaseAction`；走 ExecutionContext + TargetSelector + Pre/Atomic/Post 三段
- [ ] **AC3 — S3 修复**：`RtsAIStrategy` 无状态共享 + factory；`RtsUnitController` 持 runtime state；`grep "last_decision"` 返回空
- [ ] **AC4 — M4 修复**：`grep "attack_cooldown_remaining"` 返回空；走 `tag_container.add_auto_duration_tag("attack_cooldown", ...)`
- [ ] **AC5 — Fixed tick + RNG 收敛**：30Hz fixed-tick 落地；`RtsRng` autoload；`grep` 全代码无散落 randf/randi
- [ ] **AC6 — Light determinism**：`smoke_determinism.tscn` 同 seed 跑 2 次输出 same winner + same total ticks ± 1
- [ ] **AC7 — Grid wrapper**：`RtsBattleGrid` + `RtsPathfinding` 落地；RTS 例子代码 0 处 NavigationServer2D/Agent2D 引用
- [ ] **AC8 — Actor 三层基类**：`RtsBattleActor → RtsUnitActor / RtsBuildingActor` 落地（Building 基类骨架到位，工厂 Phase 2 填）
- [ ] **AC9 — 不退化**：
  - **LGF 单元测试**：73/73 PASS（任何 fail / count 变化都阻塞）
  - **hex demo 不退化**精确门槛：`/tmp/hex_demo.txt` 末尾 100 行**含 `结果: left_win` 或 `结果: right_win` 字符串**视为通过；exit 139（shutdown segfault）是继承自 M0 的残余风险，**不阻塞**；战斗中如出现 `SCRIPT ERROR` / `ERROR:` / battle 未跑到 winner，**阻塞**
  - **RTS 4v4 主 smoke**：`/tmp/rts_smoke.txt` 末尾含 `SMOKE_TEST_RESULT: PASS - <winner>` + 退出码 0；melee_max_dist / ranged_max_dist 仍满足 M0 acceptance 阈值（melee ≤ 25.2, ranged > 24）— Phase 1 加了最简 push-out 后这些数值应继续成立

---

## 退出条件（切到 Phase 2）

Phase 1 acceptance 全过 →
- 不归档（Phase 1 是同一 feature 的早期 phase，归档放整个 RTS M1 重构完成时做）
- 更新 `Next-Steps.md` 切到 Phase 2
- 更新 `Progress.md` 切到 Phase 2 子任务清单
- `task-plan/phase-2-core-systems.md` 已经就位（无需重新规划）

---

## 已知风险

- **AC9 hex demo segfault**：继承自 M0 的残余风险（`archive/2026-04-30-rts-auto-battle/Summary.md`），不阻塞本 phase
- **P1.7 修改 project.godot autoload**：触发 Autonomous-Work-Protocol §"何时停下来问用户" 第 3 条，需要用户授权
- **P1.2 替换 NavigationServer2D 影响范围大**：5 处 smoke 都涉及 nav，可能集中暴露细节问题
- **现有 demo_rts_frontend.tscn 可能需要小重构**：去掉 NavigationRegion2D 节点，改用 grid 渲染（Phase 2 接 BattleDirector 时彻底重构，本 phase 先做最小改动跑得起来）
