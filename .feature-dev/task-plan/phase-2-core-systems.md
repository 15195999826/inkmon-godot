# Phase 2 — Core Systems（M1 期间核心玩法支柱）

> **状态**：进行中（P2.1 + P2.2 + P2.3 + P2.4 + P2.5 + P2.6 已完成 2026-05-01；P2.7-P2.8 待启动）
> **进入条件**：Phase 1 收口条件全过 ✓
> **退出条件**：本文档 §收口条件 全过 → 切换到 Phase 3

---

## Phase 目标

在 Phase 1 修好的架构骨架上，搭建**城堡战争的核心玩法支柱**：Activity 行为系统 / 完整避障管线 / 生产系统 / 玩家命令 / 流式 frontend。

**核心承诺**：Phase 2 完成后，城堡战争最小可玩 demo 跑通 — 玩家放置兵营 → 兵营周期 spawn 单位 → 单位走 navmesh / 互避障 / 找最近敌人 / 攻击建筑 → 水晶塔被毁判胜负。

---

## 进入条件

- Phase 1 acceptance 9/9 全过
- LGF 73/73 PASS（不退化）
- RTS 4v4 主 smoke 仍跑到 winner（不退化）
- light determinism smoke PASS

---

## Sub-tasks

### P2.1 — Activity 系统（OpenRA 风）

**目标**：用 `Activity` 链 + `ChildActivity` 嵌套替代 Phase 1 残留的字符串 FSM（"approach / attack / idle"），让"追击 → 接敌 → 攻击 → 换目标 → 再追击"这类组合行为天然组合。

**改动范围**：
- 新增：`logic/activity/activity.gd`（基类，OpenRA `Activity.cs` 同构）
  - 字段：`child_activity / next_activity / state (Queued/Active/Canceling/Done)`
  - 钩子：`on_first_run() / tick(dt) -> bool / on_last_run() / cancel()`
- 新增 activity 子类：
  - `logic/activity/move_to_activity.gd`（沿 path 移动到 target_pos）
  - `logic/activity/attack_activity.gd`（attack 一次 + cooldown wait）
  - `logic/activity/attack_move_activity.gd`（移动中遇敌优先打 — child = AttackActivity）
  - `logic/activity/idle_activity.gd`
- 修改：`RtsUnitController` 持 `current_activity: Activity`，每 tick 推进
- 修改：`RtsAIStrategy.decide` 返回 Activity（不再返回 string Intent）

**验证**：
- 新 smoke `tests/battle/smoke_activity_chain.tscn`：单位 `[MoveTo(A) → MoveTo(B) → AttackActivity]`，验证按顺序执行；途中 cancel 整条链应停止
- 主 smoke 不退化

---

### P2.2 — Spatial Hash + Steering（避障 1+2 层）

**目标**：让单位互相避让，不再卡在一起或穿过彼此。

**改动范围**：
- 新增：`logic/movement/rts_spatial_hash.gd`（cell_size = 64 的桶索引）
  - `update_actor(id, old_pos, new_pos)` 增量更新桶
  - `query_radius(center, radius) -> Array[String]`
- 新增：`logic/movement/rts_unit_steering.gd`（separation + deflection）
  - `compute_velocity(unit, desired_dir, hash, dt) -> Vector2`
  - 决定性：迎面偏转方向用 `actor_id` hash 决定（不能用 randf）
- 修改：procedure 主循环 P1.3 的 step 1 加 `spatial_hash.update_all_dirty()`，step 6 加 `steering.compute(actor, dt)`
- 修改：单位移动公式 `position += velocity * dt`，velocity 来自 steering（不直接朝 waypoint）

**实现要点**：
- 跨 layer 不互相挤（地面 vs 飞行）
- 静态建筑用寻路躲，**不进** steering（A* 已经把路径绕开）
- separation 力度参数化（可调）

**验证**：
- 新 smoke `tests/battle/smoke_steering.tscn`：8 个单位同时朝同点移动，验证最终散开（无两个单位距离 < collision_radius * 2）
- 4v4 主 smoke 不退化

---

### P2.3 — Stuck Detection + Local Repath（避障第 3 层）

**目标**：单位 1 秒内未位移则触发 local repath；连续失败 N 次降级命令。

**改动范围**：
- 新增：`logic/movement/rts_stuck_detector.gd`
  - 跟踪 `_stuck_ticks / _last_pos / _repath_failures` per actor
  - stuck → 重跑 A*（5x5 cells 范围）
  - 失败 ≥ 3 次 → controller.abandon_command()（attack-move 降级为"原地攻击"）
- 修改：`RtsUnitController` 接 stuck signal，处理降级

**验证**：
- 新 smoke `tests/battle/smoke_stuck_recovery.tscn`：3 个单位被建筑包围，验证至少 2 个最终 abandon 命令并停在原地
- 4v4 主 smoke 不退化

---

### P2.4 — AutoTargetSystem（Mindustry + OpenRA 合璧）

**目标**：把"找敌人"从每个单位每帧 O(N²) 扫描改为 system 集中扫描 + 缓存（`targetInterval` 默认 20 tick），并支持 priority 标签 + Stance（HoldFire / Defensive / Aggressive）。

**改动范围**：
- 新增：`logic/ai/rts_auto_target_system.gd`
  - 每 20 tick 扫一次全场 enemy
  - 按 unit 的 `target_priorities: Array[{tag: weight}]` 排序
  - 缓存到 `actor._cached_target_id`
- 修改：`RtsAIStrategy.decide` 直接读 `actor._cached_target_id`（不自己扫描）
- 新增：unit_class config 的 `target_priorities` 字段
- 新增：unit 的 `stance: enum { HoldFire, Defensive, Aggressive }` 字段（默认 Aggressive）

**验证**：
- 新 smoke `tests/battle/smoke_auto_target.tscn`：弓手 + 远程怪同场，验证 弓手优先打远程怪（high threat priority）
- 4v4 主 smoke 不退化（性能改善但行为等价）

---

### P2.5 — Production System + Building Factory

**目标**：建筑周期 spawn 单位；玩家放置/升级建筑命令落地。

**改动范围**：
- 新增：`logic/buildings/rts_buildings.gd`（工厂 module）
  - `create_crystal_tower() / create_barracks() / create_archer_tower()`（building_kind 字符串区分）
- 新增：`logic/config/rts_building_config.gd`（建筑数值表：hp / footprint / production_period / spawn_unit_kind）
- 新增：`logic/production/rts_production_system.gd`
  - `tick(dt)`：每个生产建筑累积 progress，到点 spawn unit + 设 `SpawnLane intent`（去打对方水晶塔）
- 新增：`logic/buildings/rts_building_attribute_set.gd`（hp / max_hp + 可能的 production_speed_multiplier）
- 修改：`RtsBuildingActor` override `writes_to_pathing_map() = true`、`get_footprint_cells()` 返回 AABB cells

**验证**：
- 新 smoke `tests/battle/smoke_production.tscn`：**用 scripted `world.add_actor(barracks)` 直接放置**（P2.5 时玩家命令系统还没 P2.6 落地，scripted 是合理做法 — hex 也是这套）；跑 30 秒，验证至少生成 N 个单位（按 production_period 计算）
- 单位 spawn 后立即向对方水晶塔进发（验证 SpawnLane intent）
- P2.6 落地后再加 `smoke_player_command_production.tscn` 验证"玩家命令 → placement → production"完整链路

---

### P2.6 — Player Command + Building Placement + 胜负判定改写 ✅ 已完成 2026-05-01

**目标**：玩家放置建筑命令进 simulation；胜负判定从"team 全灭"改为"水晶塔 hp = 0"。

**已落地范围**（详细 evidence 见 `../Progress.md` AC5）：
- 新增 `logic/config/rts_team_config.gd`（RtsTeamConfig：team_id / faction_id / starting_resources / build_zone Rect2 / crystal_tower_id；`unconfigured(team_id)` + `create(...)` 工厂）
- 新增 `logic/commands/rts_player_command.gd`（基类：tick_stamp + team_id + apply 钩子 + serialize 录像支持）
- 新增 `logic/commands/rts_place_building_command.gd`（PlaceBuildingCommand：building_kind + position_2d；apply 走 RtsBuildingPlacement.validate → RtsBuildings.create_<kind> → add_actor → place_building 写 pathing map → spend_team_resources → add_unit_to_team → 自动绑 ct_id）
- 新增 `logic/commands/rts_player_command_queue.gd`（RtsPlayerCommandQueue：enqueue / apply_due 按 tick_stamp 升序，同 tick 保 insertion-order；history 持续 append 含 success / fail entries）
- 新增 `logic/commands/rts_building_placement.gd`（静态校验：build_zone / 地图边界 / cells 阻挡 / cells 占用 / 资源充足；返回 reason 枚举字符串）
- 新增 `logic/commands/README.md`（commands/ 目录使用说明 + 添加新命令类型指南）
- 修改 `logic/config/rts_building_config.gd`（StatBlock 加 cost 字段：barracks=100 / archer_tower=50 / crystal_tower=0）
- 修改 `logic/controller/rts_unit_controller.gd`（加 `_player_command_active` flag + `set_activity_chain(chain, override_strategy=false)` 第 2 参数 + `clear_player_command_override` / `is_player_command_active` API；tick 在 override 时跳过 strategy.decide，仅推进 current_activity，链跑完自动清 flag；override=true 时也清 abandoned 状态让玩家命令复活 stuck 单位）
- 修改 `core/rts_auto_battle_procedure.gd`：
  - 字段 `_team_configs / _team_resources / _player_command_queue / _player_commands_log`
  - opts 新增 `team_configs: Dictionary[int, RtsTeamConfig]` + `player_command_queue: RtsPlayerCommandQueue`（旧 smoke 不传时按需 unconfigured + lazy create）
  - `_init` 调 `_install_team_configs(opts.team_configs)` 装配占位
  - `start()` 在 footprint 写入循环里加自动绑 crystal_tower_id
  - `tick_once` step 1.5（1 之后，2 之前）：`_player_command_queue.apply_due` + log append
  - `_check_battle_end` 重写：走 `_is_team_lost(team_id, team_actors)` — `team_config.has_crystal_tower()` 优先（找 actor_id == crystal_tower_id 死亡判败），否则 fallback team-wipeout（Phase 1 行为兼容）
  - 公共 API：`enqueue_player_command(cmd)` / `get_team_config(team_id)` / `get_team_resources(team_id)` / `spend_team_resources(team_id, amount)` / `get_player_commands_log()`
- **未做 / 留 P2.7+**：UpgradeBuildingCommand / SellBuildingCommand 子类未落地（P2.6 acceptance 不需要；留 RtsPlayerCommand 基类接口预留）；单位攻击建筑未做（AutoTargetSystem + BasicAttackAction 仍只看 RtsUnitActor）

**验证**（已通过）：
- 新 smoke `tests/battle/smoke_player_command.tscn`：3 phase（放置 ok + 同位置 dup fail + build_zone 外 fail）；log 3 entries; resources 200→100; placed_id=Building_4; ticks=30
- 新 smoke `tests/battle/smoke_crystal_tower_win.tscn`：双 ct 起手 + procedure.start() 自动绑 ct_id；手动 mark_dead 右方 ct + tick 2 → result=left_win；ticks=2
- 新 smoke `tests/battle/smoke_player_command_production.tscn`：tick 30 玩家命令放兵营 → 后 570 ticks 累积 7 个 melee spawn + override-strategy SpawnLane 让最远朝东 254.74 px；resources=100
- 主 smoke `tests/battle/smoke_rts_auto_battle.tscn` 不退化：仍 left_win, ticks=347, melee_max_dist=24.00, ranged_max_dist=125.75, detoured=4（不传 team_configs → fallback 全灭判定 0 行为差）
- 决定性 smoke 仍 bit-equal（seed=12345, run1=run2=(left_win, 347), tick_diff=0）
- LGF 73/73 + 全部 P1/P2 子 smoke 仍 PASS

---

### P2.7 — Frontend BattleDirector 接入流式 events

**目标**：把 frontend 从"`_process` 拉 actor.position_2d"（state polling）改为消费 event_timeline 流式 events，复用 hex 已有的 BattleDirector + Visualizer 四层管线。

**改动范围**：
- 新增：`frontend/visualizers/rts_unit_visualizer.gd` 升级
  - 不再 `sync()` 拉 position；改为订阅 `MoveCompleteEvent / DamageEvent / DeathEvent`
- 新增：`frontend/visualizers/rts_building_visualizer.gd`（建筑 view）
- 新增：`frontend/core/rts_battle_director.gd`（参照 hex `battle_director.gd`）
  - 流式消费 procedure 当前 tick events
  - `_tick(delta)` 累积 logic_accumulator，按 SIM_DT 推进
- 新增：`frontend/world_view.gd`（响应 `actor_added / actor_removed / position_changed` signal）
- 新增：插值层 — 每个 visualizer 持 prev_pos / curr_pos，`_process(alpha)` 插值

**验证**：
- 新 smoke `tests/frontend/smoke_director_streaming.tscn`：跑 5 秒战斗，verify visualizer 收到 N 个 events 并表演
- 编辑器 F6 验证 `demo_rts_frontend.tscn` 视觉流畅（用户肉眼）

---

### P2.8 — AIR layer + target_layer_mask + 飞行单位（前移自原 P3.2）

**目标**：城堡战争玩法天然需要"防空塔 vs 飞龙"等飞行 vs 地面对位（用户明确"一定会有飞行单位"）。本 phase 把 AIR layer 与 target_layer_mask 落地为城堡战争最小可玩 demo 的一等公民功能 — **不是可选高级特性**。

**改动范围**：
- 新增：`logic/units/flying/`（飞行 unit_class 配置位置）
- 修改：`RtsUnitController` movement 分支
  - layer == AIR：**不调 A***；直线朝目标飞 + 同层飞行单位间软排斥（boids-lite，跨 layer 不互相挤）
  - layer == AIR：不写 pathing map，is_passable callback 对 ground 阻挡直接 return true
- 新增：`logic/weapons/rts_weapon_config.gd`
  - 字段 `target_layer_mask: int`（GROUND / AIR / BOTH 的 bitmask）
- 修改：`RtsAutoTargetSystem`：扫描时按 `mover.weapon.target_layer_mask` 过滤候选敌人（防空塔只挑 AIR；普通弓兵 BOTH；纯地面武器 GROUND-only）
- 修改：`RtsBasicAttackAction.can_hit(attacker, defender)`：检查 layer mask；不匹配 → 直接 invalid target（AI 决策时已过滤，但 action 层做防御性检查）
- 修改：单位 spawn 配置加 `default_movement_layer` + `weapon.target_layer_mask`
- 新增：至少 1 个 AIR 单位 unit_class（如 `flying_scout`）+ 1 个 anti-air weapon 配置

**验证**：
- 新 smoke `tests/battle/smoke_flying_units.tscn`：地面单位 + 防空塔 + 飞龙
  - 防空塔（`target_layer_mask = AIR`）只打飞龙
  - 普通地面单位（`target_layer_mask = GROUND`）打不到飞龙（攻击 invalid target → 跳过）
  - 飞龙穿过地面建筑 footprint（`is_passable_for_layer(AIR)` return true）
- 4v4 主 smoke 不退化

---

## 顺序依赖

```
P2.1 (Activity) ───────────────────┐
                                   ├──> P2.4 (AutoTarget) ──> P2.5 (Production) ──> P2.6 (Player Command) ──> P2.7 (Frontend Director) ──> P2.8 (AIR layer)
P2.2 (Hash + Steering) ──> P2.3 (Stuck) ─┘
```

P2.1 与 P2.2/P2.3 可并行；P2.4 依赖 P2.1（strategy 已经返回 Activity）；P2.5+P2.6 必须按顺序；P2.7 在所有 logic 稳定后接入；P2.8 在 P2.4（AutoTarget）+ P2.6（command 含 layer-aware 命中）后做最自然。

> P2.8 也可以与 P2.5/P2.6 之间见缝插针 — 取决于 P2.4 的 target_layer_mask 接口是否提前暴露。实现时由开发者按依赖关系判断。

---

## 收口条件（Phase 2 acceptance）

- [x] **AC1 — Activity 系统**：`smoke_activity_chain` PASS；UnitController 内已无 string FSM ✓ (P2.1 完成 2026-05-01; evidence in `../Progress.md` AC1)
- [x] **AC2 — 避障四层（前 3 层）**：`smoke_steering` 8 单位散开 ✅ PASS (P2.2 完成 2026-05-01)；`smoke_stuck_recovery` 包围降级 ✅ PASS (P2.3 完成 2026-05-01); evidence in `../Progress.md` AC2
- [x] **AC3 — AutoTargetSystem**：`smoke_auto_target` priority 标签生效 ✅ PASS (P2.4 完成 2026-05-01); 4v4 主 smoke 行为等价 (left_win, ticks=347); evidence in `../Progress.md` AC3
- [x] **AC4 — Production**：`smoke_production` 兵营周期 spawn ✅ PASS (P2.5 完成 2026-05-01); 双 barracks 30s 跑 600 ticks 各 spawn 7 melee, 朝东偏移 118.51 px; evidence in `../Progress.md` AC4
- [x] **AC5 — Player Command + Crystal Tower**：`smoke_player_command` ✅ + `smoke_crystal_tower_win` ✅ + `smoke_player_command_production` ✅ PASS (P2.6 完成 2026-05-01); 玩家命令 tick 30 放兵营 → 7 spawns + override-strategy SpawnLane; crystal-tower 死 → 该方败 (start() 自动绑 ct_id); evidence in `../Progress.md` AC5
- [ ] **AC6 — Frontend Director 流式**：`smoke_director_streaming` PASS；frontend 0 处 `actor.position_2d` 直读
- [ ] **AC7 — AIR layer + 飞行单位**：`smoke_flying_units` PASS（防空塔只打飞行 / 地面武器打不到飞行 / 飞行穿过地面建筑）
- [ ] **AC8 — 城堡战争最小可玩 demo**：编辑器 F6 跑 `demo_rts_frontend.tscn`，玩家可放置建筑、看到建筑生产单位、单位互打（含飞行 vs 防空）、塔被毁判胜负
- [ ] **AC9 — 不退化**：LGF 73/73 PASS；hex demo 不退化；RTS 主 smoke + Phase 1 light determinism 仍 PASS
- [ ] **AC10 — Bit-identical replay**（Phase 2 新增 acceptance）：`smoke_replay_determinism` 同 seed + 同 player_commands 跑 2 次产出 bit-identical event_timeline

---

## 退出条件（切到 Phase 3）

Phase 2 acceptance 全过 → 更新 `Next-Steps.md` + `Progress.md` 切到 Phase 3。

> Phase 2 完成意味着 RTS M1 已经"功能可玩"。是否继续 Phase 3 由用户决定 — Phase 3 是高级特性（飞行 / 高度 / 队形 / scenario harness），未必所有项目阶段都需要。

---

## 已知风险

- **P2.7 frontend 重构范围大**：BattleDirector + Visualizer 全套接入，可能涉及 hex 表演层基类的细节适配（如 hex Director 对 hex_position 的硬编码）
- **P2.6 player_command 录像**：需要决定 player_command 的 tick stamp 边界（在 tick 开头还是结尾应用）
- **P2.2 steering 决定性**：boids force 计算累积浮点误差，需要严格固定迭代顺序（actor_id 排序）才能保 bit-identical
