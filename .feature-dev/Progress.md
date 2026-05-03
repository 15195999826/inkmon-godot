# Progress — RTS Pathfinding M3 Epic / M0 sub-feature

**Status**: 🟡 active(M0.1 + M0.2 + M0.3 done,M0.4 下一步 — `RtsBuildingActor` 加字段 + 改 get_footprint_cells)

**Active feature**: M0 — Footprint / Obstruction shape 拆分 + Bug 1 修复
**完整 spec**: [`task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md)

---

## 0. Step A + Step B(规划阶段,已完成)

| 阶段 | 产出 | 状态 |
|---|---|---|
| **Step A**(2026-05-03 晚) | README + data-structures + M0 范本 + Handoff-2026-05-03-0ad-migration-planning.md(383 行) | ✅ done |
| **Step B**(2026-05-03 晚) | interfaces.md + validation-strategy.md + risks-and-rollback.md + M1-M8(8 个 milestone, M4/M6/M7 拆 sub-phase)+ deferred/0ad-formation-design.md | ✅ done |
| **Step B 配套**(Agent 后台落地) | path_trace_v2.gd + smoke_pathfinding_baseline + tests/baselines/0ad-baseline-master.csv (882 KB / 6155 行,byte-identical 跨 run) | ✅ done(M0.1 已落地) |
| **0 A.D. 源码本地副本**(顺手) | sparse checkout `source/simulation2/`(9.2 MB),供后续 milestone 对照参考 | ✅ done(addons submodule .gitignore 屏蔽) |

### Codex 审查闭环记录

| Round | 结论 | 反馈 | 我的修订 |
|---|---|---|---|
| **R1** | REQUEST CHANGES | 4 P1 + 7 项审查意见 | RegionID packed int64 / M0 sync 时机 / 字段命名 / §12 determinism contract — 全闭环 |
| **R2** | REQUEST CHANGES (P2 only) | 真实 API 名(RtsRng / RtsPlayerCommandQueue / RtsMatchPreset)+ §12.5 motion tick 顺序显式 + M0.5 sync 6 call sites | 全闭环 |
| **R3** | REQUEST CHANGES (1 P1 + 3 P2) | Q4 闭环风格 + RtsRandomSeq 残留 + RtsRng.next_* 不存在 + §11 缺 R2 记录 | 全闭环 |
| **R4** | ✅ APPROVE for Step B | (无 P1)| (进 Step B)|
| **R5** | REQUEST CHANGES (3 P1 + 1 P2) | actor.get_id 字典序 ≥ 10 unit 漂 / dirty bits 在 hierarchical update 前清 / isolated region 不进 GlobalRegionID / tick API 名 flush 不存在 | 全闭环 |
| **R6** | REQUEST CHANGES (1 P1 + 2 P2) | interfaces §6.3 仍 actor.get_id / Handoff 旧疑虑 / validation §3.2 wall_clock 主句 | 全闭环 |
| **R7** | REQUEST CHANGES (1 P1) | interfaces §10.2 仍按 actor.get_id 字典序 | 全闭环 |
| **R8** | ✅ APPROVE for Step C | (无 P1)| 启动 Step C(本轮)|

R1-R8 完整反馈记录见 `Handoff-2026-05-03-0ad-migration-planning.md` §11.6 / §11.7 + `Handoff-2026-05-03-step-b-codex-review.md` §10 / §11 / §12。

---

## 1. M0 子任务 checklist (M0.1 → M0.7)

完整定义见 [`task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md) §2。

- [x] **M0.1** — Trace utility + baseline replay 准备(Step C 之前由 Agent 落地)
  - **Evidence**: `addons/.../tools/path_trace_v2.gd`(7910 B)+ `smoke_pathfinding_baseline.{tscn,gd}` + `tests/baselines/0ad-baseline-master.csv`(882 KB / 6155 行) + `0ad-baseline-master.replay.json`(34 KB)
  - **Smoke**: PASS — 900 ticks / 6155 trace rows / 111 replay events / exit code 0 / baseline CSV byte-identical 跨 run
  - **Regress**: `smoke_rts_auto_battle` 0 漂移(left_win ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 完全对齐 CLAUDE.md baseline)
- [x] **M0.2** — 引入 3 个 data class(`RtsObstructionShape` 基类 + `Static` + `Footprint`,纯 data,不挂逻辑) ✅ **2026-05-03 done**
  - **Evidence**: 3 文件落地
    - `addons/.../logic/obstruction/rts_obstruction_shape.gd` (基类 RefCounted + enum Type{UNIT,STATIC} + entity_id/center/flags/control_group/control_group_2/tag)
    - `addons/.../logic/obstruction/rts_obstruction_shape_static.gd` (extends RtsObstructionShape + width/height/rotation_rad + get_corners 4 角 (+u+v→+u-v→-u-v→-u+v) + get_axes [u,v])
    - `addons/.../logic/obstruction/rts_footprint_shape.gd` (RefCounted + enum Type{CIRCLE,SQUARE} + center_offset/size + contains + get_world_aabb)
  - **Import**: `godot --headless --path . --import` exit=0,update_scripts_classes 注册 3 个新 class_name(RtsFootprintShape / RtsObstructionShape / RtsObstructionShapeStatic),无 type error
  - **Regress**: LGF 73/73 PASS;`smoke_rts_auto_battle` ticks=347 attacks=74 (melee=32 ranged=42) melee_max=24.00 deaths=6 detoured=4 — **完全对齐 baseline,0 漂移**
  - **F2 决策落地**: 不引入 RtsObstructionFlags 完整枚举,M0 阶段 flags 字段注释里说明 `1<<3 = BLOCK_PATHFINDING` 单 bit,M2 引入完整枚举
- [x] **M0.3** — `RtsBuildingConfig.StatBlock` 加 4 个新字段 ✅ **2026-05-03 done**
  - **Evidence**: `addons/.../logic/config/rts_building_config.gd` StatBlock 新增 4 字段 + `_CELL_SIZE_FALLBACK = 32.0` 内部常量 + `get_stats` 加 fallback 派生 (raw 没显式时从旧 footprint_size × cell_size 派生 obstruction_size, selection 派生 = max(w,h)*0.5)
  - **三建筑 fallback 数字** (raw config 未显式新字段,全走 fallback):
    - crystal_tower (footprint=(2,2)): obstruction_size=(64,64), selection=Vector2(32,0), offset=ZERO, shape_type=0(CIRCLE)
    - barracks (footprint=(2,2)): obstruction_size=(64,64), selection=Vector2(32,0)
    - archer_tower (footprint=(1,1)): obstruction_size=(32,32), selection=Vector2(16,0)
  - **Import**: exit=0,update_scripts_classes RtsBuildingConfig + InputHelper 注册,无 type error
  - **Regress**: LGF 73/73 + smoke_rts_auto_battle ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 deaths=6 detoured=4 **0 漂移** + smoke_resource_nodes PASS (5 workers idle near spawn) + smoke_economy_demo PASS (full cycle harvest → cost → barracks → melee → attack ct) — **向后兼容验证通过**
  - **旧字段**: `footprint_size: Vector2i` 保留,M2 引入 ObstructionManager 后才删
- [ ] **M0.4** — `RtsBuildingActor` 加 `obstruction_shape` / `footprint_shape` 字段 + 改 `get_footprint_cells` 算法 + 加 `sync_obstruction_shape()` 方法
  - **Evidence**: 待 — `obstruction_offset = ZERO` 时 cells 跟旧实现 bit-identical(单元 test)
- [ ] **M0.5** — `RtsBuildings` 工厂(只填默认字段)+ 6 个 sync_obstruction_shape() call sites + `RtsBuildingPlacement` 算法同步
  - **Evidence**: 待 — 6 个 call sites 全部 grep 验证已加 sync(R2/R5 提醒列表):`rts_place_building_command.gd:81-90` / `rts_auto_battle_procedure.gd:188` / `demo_rts_frontend.gd:164,170` / `demo_rts_pathfinding.gd:115,121,269,274` / `rts_scenario_harness.gd:92,282-289,301` / `rts_match_preset.gd`
  - **额外 grep**(R5/R6 反馈): `tests/**/*.gd` 找 `create_*` 后直调 `get_footprint_cells()` 的 diagnostics/smoke 路径
- [ ] **M0.6** — Frontend 选择圈 + ghost 渲染对齐(sprite 锚点保持 `actor.position_2d` 不变 — F4 决策 A)
  - **Evidence**: 待 — F6 demo 视觉验证 sprite 位置不变 + 选择圈用 footprint_shape AABB
- [ ] **M0.7** — 新 smoke + Validation 全套 + commit
  - **Evidence**: 待 — `smoke_obstruction_footprint_split.tscn` PASS(5 项断言)+ 14 项 + LGF 73 + replay 0 漂移 + ✋1 体验点录屏

---

## 2. 体验点 ✋1(M0 完成时,stop runner)

- [ ] 用户 F6 跑 `frontend/demo_rts_frontend.tscn`
- [ ] 进 build mode,放 1 个 barracks + 1 个 archer_tower
- [ ] spawn 4-6 单位绕走
- [ ] 视觉确认:ghost cells = obstruction cells = 单位绕走 cells 三者一致
- [ ] 录屏 `0ad-migration-M0-after.mp4`(本地留底,不进 git)
- [ ] 用户反馈通过 → 启动 M0 archive + M1 sub-feature

---

## 3. 残余风险(M0 启动前预判,详见 M0.md §6)

| # | 风险 | 缓解 |
|---|---|---|
| R1 | 偶数 footprint_size 偏置方向跟旧不一致 → smoke 数字漂 | 严格保留 "上半左半" 偏置;单元测试比对旧算法 byte-identical |
| R2 | obstruction_offset = ZERO 时 cells 浮点精度 → 不 bit-identical | 用 `int(round(...))` 显式整数化 |
| R3 | sprite 锚点改逻辑后视觉错位 | 选 F4 A(锚点 = position_2d 不变),只动选择圈 |
| R5 | replay determinism 漂(M0 引入 obstruction_shape mutate)| M0.7 验证 seed=42 deep-equal |
| R6 | M0 完成后 demo 视觉差异不明显(M0 不能完整修 Bug 1)| ✋1 客观断言 ghost == placed == path,主观视觉差异留 ✋3 (M6) |
| R-EPIC-9 | M0.5 sync call sites 漏(diagnostics/smoke 路径)| Step C 进 runner 后**先** grep `tests/**/*.gd`,不依赖 R2 列的 6 个生产 sites |

---

## 4. 下一步动作(给 runner)

1. 读 [`task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md) §2 + §3 + §6
2. 读 `data-structures.md` §2 + §3
3. grep `tests/**/*.gd` 找 diagnostics/smoke 中 `create_*` 后直调 `get_footprint_cells()` 路径(补充 M0.5 第 6 个 call site 表外漏的)
4. 按 M0.2 → M0.7 顺序推进
5. 每子任务 done 时 update 本文件 (Evidence 字段填实际产出 + commit hash)
6. M0 全 AC 通过后 stop runner 等 ✋1 反馈
