# Phase 3 — Advanced（M2+ 高级特性）

> **状态**：未启动（Phase 2 完成后启用，且需要用户明确启动）
> **进入条件**：Phase 2 收口条件全过
> **退出条件**：本文档 §收口条件 全过 → 整个 RTS M1 重构归档

---

## Phase 目标

在 Phase 1+2 已完成的"功能可玩"城堡战争之上，**加入高级 RTS 特性**：高低地形 / 群体队形 / 声明式 scenario 测试 / fog of war。

> 这些特性是**可选的**。Phase 2 完成后已经是个完整可玩 demo（含飞行 vs 防空）；Phase 3 是"做大做深"的方向，由用户判断哪些必要、哪些跳过。
>
> **注意**：飞行单位（AIR layer + target_layer_mask）已**前移到 Phase 2 P2.8** — 用户明确"一定会有飞行单位"，是城堡战争玩法的一等公民。

---

## 进入条件

- Phase 2 acceptance 全过
- 用户明确启动 Phase 3（不像 Phase 1→2 那样自动衔接）
- LGF 73/73 PASS（不退化）

---

## Sub-tasks

### P3.1 — 离散 tile.height + LOS 命中修正（D3-E）

**目标**：地图 grid cell 带 `tile.height` 离散等级（LOW=0/MID=1/HIGH=2），命中 / 视野 resolver 读这个标签做修正。

**改动范围**：
- 新增：`logic/grid/rts_terrain_height_resolver.gd`
  - `resolve_hit_chance(attacker, defender) -> float`：低打高 -25% 命中
  - `resolve_vision_modifier(observer, target) -> float`：高打低视野 +20%
- 修改：`RtsBasicAttackAction` 的 PreDamageEvent handler 链加入 `TerrainHeightHandler`
- 修改：`frontend/scene/rts_battle_map.gd`：地图配置加 height 数据
- 加 LOS 检查：weapon `requires_los: bool`；attack 命中前调 `GridPathfinding.get_line` 扫一遍中间 cells，max(intermediate height) > max(attacker, defender) → 被挡

**验证**：
- 新 smoke `tests/battle/smoke_terrain_height.tscn`：低地单位打高地单位，统计 N 次 attack 命中率 ≈ 75%
- LOS smoke：弓手 vs 山丘后单位，验证 0 次命中

---

### P3.2 — Group Formation Movement（避障第 4 层）

**目标**：多单位收到同一 move 命令时，自动形成 formation 不挤一团。

**改动范围**：
- 新增：`logic/movement/rts_group_formation.gd`
  - `assign_formation(units: Array, target_pos: Vector2) -> Dictionary[unit_id, formation_offset: Vector2]`
  - 领头单位走标准 A*，跟随单位带 offset
- 修改：`RtsPlayerCommand` 的 `MoveGroupCommand`（如果 Phase 3 要加玩家选单位编队功能）
- 注意：城堡战争**单位是建筑 spawn 出来的**，可能 Phase 3 不一定需要这个 — 看是否做"玩家选中多个单位下命令"功能

**验证**：
- 新 smoke `tests/battle/smoke_group_formation.tscn`：8 单位同令到目标，验证抵达后保持 formation 偏移、无两单位重叠

---

### P3.3 — RtsScenarioHarness（破 L2）

**目标**：声明式 scenario 测试框架（hex 同构），把端到端 4v4 aggregate 断言细化为 unit-level 行为契约。

**改动范围**：
- 新增：`logic/scenario/rts_scenario_harness.gd`（hex `skill_scenario_harness.gd` 同构）
- 新增：`tests/battle/scenarios/`（具体 scenario `.gd` 文件 — 可执行 spec）
- 重构：现有 4v4 端到端 smoke 拆分为 N 个具体 scenario：
  - `scenario_melee_engages_at_range_24.gd`
  - `scenario_ranged_kites_attacker.gd`
  - `scenario_unit_retargets_after_kill.gd`

**验证**：
- 新 smoke `tests/battle/smoke_scenarios_main.tscn`：跑所有 scenario，全 PASS

---

### P3.4 — Fog of War / Vision System（破 L3）

**目标**：World 加 `add_system()` 挂点，接入 `VisionSystem` 计算每队的可见区域；FogOfWarRenderer 在 frontend 涂雾。

**改动范围**：
- 修改：`RtsWorldGameplayInstance` 加 `add_system(...)` API（与 hex demo 同构）
- 新增：`logic/systems/rts_vision_system.gd`
  - 每 tick 用 `GridPathfinding.field_of_view_optimized` 计算每队可见 cells
  - 暴露 `is_visible_to_team(team_id, cell) -> bool`
- 修改：`RtsAutoTargetSystem` 按 vision 过滤敌人
- 新增：`frontend/fog_of_war_overlay.gd`（在 grid 上涂半透明黑）

**验证**：
- 新 smoke `tests/battle/smoke_fog_of_war.tscn`：A 队单位与 B 队单位距离远，验证 A 看不到 B 的位置（actor cache_target_id 不更新到 B）
- 编辑器 F6 验证 fog 视觉

---

## 顺序依赖

```
P3.1 (Height) ─────────> P3.4 (Fog) (依赖 height resolver 成熟)
P3.2 (Formation) ──── (独立, 可任意时间)
P3.3 (Scenario) ───── (独立, 推荐尽早做以加固后续 phase 的回归保护)
```

> 飞行单位 / AIR layer 已前移到 Phase 2 P2.8 — Phase 3 不再涉及。

---

## 收口条件（Phase 3 acceptance — 可选项各自评估）

每个子任务有自己的 acceptance；Phase 3 全过条件 = 用户认可的子任务集全过即可（不要求 P3.1-P3.4 全部强制完成）。

- [ ] **P3.1**：`smoke_terrain_height` PASS（含命中率统计 + LOS 阻挡）
- [ ] **P3.2**：`smoke_group_formation` PASS（编队移动）
- [ ] **P3.3**：`smoke_scenarios_main` PASS（声明式 scenario 框架替代 aggregate 断言）
- [ ] **P3.4**：`smoke_fog_of_war` PASS（vision 过滤敌人 + frontend fog 视觉）
- [ ] **不退化**：LGF 73/73 + Phase 2 所有 smoke（含 P2.8 飞行）+ light/full determinism 都 PASS

---

## 退出条件（整个 RTS M1 重构归档）

Phase 3 完成（或用户决定不做完所有 P3.x）后：
- 创建 `archive/<YYYY-MM-DD>-rts-m1-refactor/` 归档（含 Phase 1+2+3 全部 progress + 最终 task-plan/）
- 主 `Next-Steps.md` 切回"等待用户确认下一个 feature"
- 主 `Current-State.md` 更新为 RTS M1 重构后的 baseline

---

## 已知风险

- **P3.5 fog of war 性能**：若地图 grid 大于 200x200 cells，每 tick 算 FOV 可能成为瓶颈。可考虑每 N tick 算一次 + 缓存
- **P3.3 group formation 仅对玩家选中编队有意义**：城堡战争单位是 spawn 的，可能不需要 — 看用户是否要加"选中多单位下命令"的玩家功能
- **P3.4 scenario harness 重构现有 smoke**：可能改动 Phase 1/2 的 smoke 入口，要确保平滑迁移不退化
