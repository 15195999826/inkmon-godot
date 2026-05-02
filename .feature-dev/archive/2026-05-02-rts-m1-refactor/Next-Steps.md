# Next Steps — 2026-05-02 (RTS M1 Phase 3 启动 — P3.2 + P3.3 + 寻路验证 demo)

## 当前目标

**RTS Auto-Battle M1 架构重构 — Phase 3 (Advanced) — 本轮选 P3.2 + P3.3 + 新增寻路验证 demo**

Phase 3 子任务独立可选;本轮经用户授权选定的 scope:

- ✅ **P3.2** Group Formation + 玩家选单位 / 拖框 / 右键移动命令 (扩展原 phase-3 设计 — 用户明确要做"玩家操作单位移动"功能,formation 不再是伪需求)
- ✅ **P3.3** RtsScenarioHarness (声明式 scenario 框架,**不重构**现有 4v4 主 smoke;仅服务新的寻路验证 scenario + 未来 P3.x)
- ➕ **新增交付物**: 寻路验证 demo + 4 个寻路 scenario (P3.2 + P3.3 合体应用)
- ❌ **P3.1** Terrain Height + LOS — 本轮 deferred (用户未选)
- ❌ **P3.4** Fog of War + Vision — 本轮 deferred (依赖 P3.1)

> 完整决策与架构总图: [`task-plan/architecture-baseline.md`](task-plan/architecture-baseline.md)
> Phase 3 详细子任务: [`task-plan/phase-3-advanced.md`](task-plan/phase-3-advanced.md) (本轮 P3.2 scope 已扩展, P3.3 scope 已收窄)
> 实施 plan (按批准的 plan 文件): `C:\Users\Administrator\.claude\plans\spicy-enchanting-map.md`

## 设计要点 (用户已确认)

- **独立 scene** `frontend/demo_rts_pathfinding.{gd,tscn}` — 不动 castle-war demo,避免双 mode flag
- **不重构** 现有 4v4 主 smoke `smoke_rts_auto_battle.tscn` — RtsScenarioHarness 仅服务新 scenario
- **选中限制 team_id=0** — 玩家方单位才能选/下令
- **双轨验证**: F6 可交互 demo + headless smoke
- **4 个寻路验证点**:
  - (a) 绕 building footprint
  - (b) 8 单位互避障不卡 (pairwise_min_distance ≥ 2r-0.5)
  - (c) Formation 保形 (offset 阈值内)
  - (d) 动态 obstacle 重新规划 (stuck detector + local repath)

## Phase 3 acceptance criteria (本轮 9 条)

- [ ] **AC1** RtsScenarioHarness 框架 minimal scenario 跑通 (基类契约 + harness runner + assert context API 可用)
- [ ] **AC2** RtsGroupFormation.assign_offsets 对 1/4/8/16 unit 给合法 formation (non-overlap + 围绕 centroid)
- [ ] **AC3** smoke_move_units_command PASS — MoveUnitsCommand 走 player_command_queue + override_strategy 链路
- [ ] **AC4** scenario_pathfind_around_building PASS — 单 unit 绕 barracks footprint 抵达
- [ ] **AC5** scenario_8_units_no_overlap PASS — 8 单位同令抵达后 pairwise_min_distance ≥ 2r-0.5
- [ ] **AC6** scenario_formation_preserved PASS — 4 单位长距移动后 formation offset 阈值内
- [ ] **AC7** scenario_dynamic_obstacle_repath PASS — 中段动态障碍触发 stuck recovery
- [ ] **AC8** LGF 73/73 + 现有所有 RTS smoke 不退化 (rts_auto_battle / castle_war_minimal / flying_units / replay_bit_identical 仍 bit-equal)
- [ ] **AC9** F6 demo_rts_pathfinding 用户手动视觉验证: 拖框 → 右键 → 4 个寻路验证点眼见为实

## 下一步

按 plan 文件 `spicy-enchanting-map.md` 实施步骤逐步推进:

**Step 2** — P3.3 RtsScenarioHarness 框架 (P3.2 验证依赖它,先做)
- 新增 `addons/logic-game-framework/example/rts-auto-battle/logic/scenario/{rts_scenario, rts_scenario_harness, rts_scenario_assert_context}.gd`
- 同构 hex `skill_scenario_harness` API,但用 RTS 类型重写 (不复用 hex CharacterActor / HexCoord / ATB)

(后续 Step 3-7 见 plan 文件)

## 非目标 (本轮 Phase 3 不做)

- ❌ P3.1 Terrain Height + LOS (Phase 3 第二批,需用户再次确认启动)
- ❌ P3.4 Fog of War (依赖 P3.1)
- ❌ 重构现有 4v4 主 smoke 为 unit-level scenario (原 phase-3-advanced.md 计划,已收窄)
- ❌ 其他玩家命令 (Patrol / AttackMove unit-targeted / Stop) — 本轮仅 MoveUnitsCommand
- ❌ formation 形状选择 (line / circle / wedge) — 本轮仅 square 方阵

## F6 视觉验证 (AC9 user sign-off)

Phase 3 收口前用户应在编辑器中 F6 跑 `frontend/demo_rts_pathfinding.tscn`:
- 鼠标左键拖框选 8 unit (selection_ring 黄色圈应亮)
- 右键点远端目标 → 8 unit 排成方阵走过去,**不重叠 + 绕 barracks footprint + 抵达后保持 formation 间距**
- (可选) 选中 1 unit 命令到远端,中途按 K 在 path 中段下兵营 → unit 应触发 local repath 绕过去

如视觉链路有 bug (而 headless smoke 没捕获), hotfix 后再收口本轮 Phase 3。

## 启动后续 Phase 3 子任务 / 新 feature

本轮 P3.2 + P3.3 + 寻路 demo 完成后:

- 用户可选: 启动 P3.1 (terrain height) / P3.4 (fog of war) — 走类似流程,在 Next-Steps.md 切到 active
- 用户可选: 整体收尾 RTS M1 重构 → 归档至 `.feature-dev/archive/<YYYY-MM-DD>-rts-m1-refactor/`,切回"等待新 feature"状态

要在 RTS M1 重构整体完成后开新的非延续 feature,调 `/next-feature-planner`。
