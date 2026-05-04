# Progress — RTS Pathfinding M3 Epic / M6 进行中

**Status**: 🟡 M6 进行中。**M6a sub-phase done(2026-05-04)** — VertexPathfinder static-OBB only + RtsLineOfSight + RtsShortPathRequest + RtsPathfinderHeap(LongPath/Vertex 共享 heap)+ smoke_vertex_static_obb 8 sub-test + prototype scene。下一步 M6b(virtual goal + terrain edges + best-so-far)。

**Active feature**: 🚧 M6 — VertexPathfinder
**完整 spec**: [`task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md)

---

## 0. 已完成 milestones / sub-phases

✅ M0+M1+M2+M3+M4+M5 done + archived(2026-05-04)— 见 [`archive/`](archive/) 各 Summary.md
✅ **M6a done(2026-05-04)** — VertexPathfinder static-OBB only(sub-phase,不 archive,等 M6 整 milestone 末)

submodule commit: `d4eda45 feat(rts): M6a VertexPathfinder static-OBB only`

---

## 1. M6 子任务 checklist

完整定义见 [`M6-vertex-pathfinder.md §2`](task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md#2-子任务)。

### M6a — Static OBB Prototype (done 2026-05-04)

- [x] **M6a.1** Prototype scene `tests/prototype/proto_vertex_obb.{gd,tscn}` — 独立 explore scene,M6c 末删(R6 风险缓解)
- [x] **M6a.2** RtsShortPathRequest data class — `logic/pathfinding/rts_short_path_request.gd`(start/clearance/range/goal/pass_mask/avoid_moving_units/control_group)
- [x] **M6a.3** RtsVertexPathfinder static-OBB only — `logic/pathfinding/rts_vertex_pathfinder.gd`:`compute_short_path_immediate` → `_compute_search_bounds`(detail #1 toward goal shift)+ vertex 候选(start/goal/OBB corners by tag↑×corner_idx 0..3/bounds 4 角 detail #2)+ `_astar_lazy_visibility`(5 元组 deterministic key + RtsPathfinderHeap.insert / key_less)
- [x] **M6a.4** RtsLineOfSight.segment_clear / check_line_movement — `logic/pathfinding/rts_line_of_sight.gd`:segment-vs-OBB(enclose-radius 早出 + axis-aligned fast-path + t-stepping 100 sample fallback)+ segment-vs-Unit(解析公式)+ Bresenham raycast on grid
- [x] **M6a.5** smoke_vertex_static_obb — `tests/battle/smoke_vertex_static_obb.{gd,tscn}` 8 sub-test PASS:data class / segment_clear 几何 / direct line / OBB blocks / same-point 兜底 / 完全包围 / determinism / search bounds toward goal / vertex 候选顺序 deterministic
- [x] **M6a-simplify** Phase-close gate 7a-7c done:抽 RtsPathfinderHeap(LongPath/Vertex 共享 heap insert+key_less)+ 删 narrate-code 注释 + smoke helper 消重(`_path_for_obb_specs` / `_assert_paths_equal`)+ OBB enclose-radius 预判(efficiency 1b,实际 demo 大半 OBB 调用走早出路径)+ axis-aligned fast-path

### M6b — Virtual Goal + Terrain Edges + Best-So-Far(待启动)

- [ ] **M6b.1** Virtual goal vertex(detail #3)— RtsPathGoal.nearest_point_on_goal CIRCLE/SQUARE 几何 + 在搜索框内找 goal 边界离 start 最近可达点
- [ ] **M6b.2** Terrain edges(detail #4)— 沿 search box 内 grid 边界,passable / impassable 邻居对中点作 vertex
- [ ] **M6b.3** Best-so-far fallback(detail #6)— A* 跑完没到 goal_idx → 返扩展过的 vertices 中离 goal 最近的路径
- [ ] **M6b.4** smoke_vertex_virtual_goal — CIRCLE goal 边界点 + terrain 水陆交界 case
- [ ] **M6b.5** segment-vs-OBB 精确化 — t-stepping 换 Liang-Barsky / SAT(M6b 末);保留 enclose-radius 早出

### M6c — Dynamic Units + Group Filter + Facade Wire(待启动)

- [ ] **M6c.1** Moving unit square proxy(detail #7)— 圆形 obstruction 近似 AABB 4 角作 vertex
- [ ] **M6c.2** Group filter(detail #8)— 同 control_group obstruction 跳过
- [ ] **M6c.3** avoid_moving_units 开关 — false 时 MOVING flag 单位不算障碍
- [ ] **M6c.4** facade.compute_short_path_immediate wire — RtsPathfinderFacade 加 API,production 可调
- [ ] **M6c.5** smoke_vertex_corner_walking + smoke_vertex_group_filter
- [ ] **M6c.6** Prototype 退役 — 删 `tests/prototype/proto_vertex_obb.*` + 配套 prototype-only 简化代码(R6 风险:避免双实现漂移)

---

## 2. AC 验收(镜像自 [M6-vertex-pathfinder.md §3](task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md#3-验收准则-m6-总))

### M6a 已通过 AC 子集

- [x] **AC1.1** detail #1 search bounds toward goal shift — `_compute_search_bounds` lerp 中点 + min(toward/6, range/4) 偏移
- [x] **AC1.2** detail #2 range boundary — bounds 4 角作 vertex(TL/TR/BL/BR 固定枚举)
- [x] **AC1.5** detail #5 lazy visibility — `_astar_lazy_visibility` expand 时 `for nb_idx: segment_clear`
- [x] **AC1.9** detail #9 tie-break — vertex 候选按 (obstr.tag, corner_index) 字典序;A* 5 元组 (f, h, vx_int, vy_int, seq) deterministic
- [x] **AC11(部分)** Validation:LGF 73/73 + replay seed=42 deep-equal + 14 项 smoke 字段 byte-identical(M6a 不接 production → 0 baseline 漂移)
- [x] **AC12** Determinism §12.3 严格遵守 — `_test_determinism_two_runs` + `_test_vertex_candidate_order_deterministic` 两次构造同 specs 路径 byte-identical PASS

### M6b/M6c 范围 AC(待启动)

- [ ] **AC1.3** detail #3 virtual goal(M6b)
- [ ] **AC1.4** detail #4 terrain edges(M6b)
- [ ] **AC1.6** detail #6 best-so-far(M6b)
- [ ] **AC1.7** detail #7 moving unit square proxy(M6c)
- [ ] **AC1.8** detail #8 group filter(M6c)
- [ ] **AC10** ✋3 体验点 demo 单位贴墙绕角(M6c demo F6 + ✋3 用户验)
- [ ] **AC11(完整)** baseline CSV short_path_size / short_path_wp_json 字段从占位变实填(M6c facade wire 后预期 baseline 漂)
- [ ] **AC11(perf)** tick_p99 / tick_max ≤ +50% vs M5(M6c facade wire 后实测)

---

## 3. 残余风险

完整列表见 [`M6-vertex-pathfinder.md §6`](task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md#6-残余风险) + [`risks-and-rollback.md §3`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md);M6a sub-phase 末已 clear 的:

- ✅ R4 替代:vertex 候选生成顺序 deterministic — get_obstructions_in_range 按 tag 升序 + statics 维持升序 + obb.get_corners() 固定 (+u+v, +u-v, -u-v, -u+v)
- ✅ R3 替代:`_segment_to_obb_dist` t-stepping 100 sample 在 enclose-radius 早出 + axis-aligned fast-path 加持下,perf 不再是 M6a 瓶颈;M6b 末仍按 spec 换 Liang-Barsky / SAT 精确版

M6b/M6c 引入新风险待启动时再 review。

⚠️ Stop runner 9 条 [`risks-and-rollback §3`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md#3-stop-runner-触发条件) M6a 全 clear:

1. ✅ replay seed=42 deep-equal PASS
2. ✅ 14 项 smoke 已实填字段 byte-identical
3. ✅ LGF 73/73 PASS
4. ✅ LGF submodule core/ 或 stdlib/ 0 改动(全在 example/rts-auto-battle/)
5. ✅ perf:M6a 不接 production → 不影响 tick_p99 / tick_max
6. ✅ baseline CSV byte-identical(M6a 算法层独立,不消费 production)
7. — 体验点 ✋3 在 M6c
8. ✅ R5 P1 #2 dirty lifecycle invariant 不违反(M6a 不动 dirty 路径)
9. ✅ R5 P1 #1 actor sort 不引入(M6a 不动 motion)

---

## 4. 下一步

按 spec §M6 sub-phase 顺序推进 M6b。Sub-phase 之间不需要 milestone-chain 等用户授权(同 milestone 内推进);M6 整体 done 后才走 archive + 等 ✋3 用户审 → M7。

详见 Next-Steps.md。

---

## 5. Evidence

### M6a sub-phase done(2026-05-04)

- **新代码**(submodule `addons/logic-game-framework/`,commit `d4eda45`):
  - `example/rts-auto-battle/logic/pathfinding/rts_short_path_request.gd`(84 行)
  - `example/rts-auto-battle/logic/pathfinding/rts_line_of_sight.gd`(154 行;含 enclose-radius 早出 + axis-aligned fast-path)
  - `example/rts-auto-battle/logic/pathfinding/rts_vertex_pathfinder.gd`(240 行)
  - `example/rts-auto-battle/logic/pathfinding/rts_pathfinder_heap.gd`(44 行;LongPath/Vertex 共享)
  - `example/rts-auto-battle/tests/battle/smoke_vertex_static_obb.{gd,tscn}`(294 行 .gd,8 sub-test)
  - `example/rts-auto-battle/tests/prototype/proto_vertex_obb.{gd,tscn}`(81 行 .gd;M6c 末删)
- **修改**(submodule):
  - `example/rts-auto-battle/logic/pathfinding/rts_long_pathfinder.gd`(`_heap_insert` / `_key_less` 切到 `RtsPathfinderHeap.insert / key_less`,-29 行 net)
  - `example/rts-auto-battle/tests/test_groups.json`(rts/pathfinding 加 `smoke_vertex_static_obb.tscn`)
- **Phase-close gate 7a-7c**(commit 前强制要求):
  - **simplify pass**:抽 RtsPathfinderHeap + 删 narrate-code 注释 + smoke helper 消重 + OBB enclose-radius 早出 + axis-aligned fast-path
  - **re-validate**:smoke + -Required + rts/pathfinding 全 PASS
  - **AC-doc consistency**:M6a 实现的 detail #1 / #2 / #5 / #9 跟 spec align;detail #3 #4 #6 #7 #8 显式 docstring 标 "M6a 简化(M6b/c 补全)"
- **Validation 全套 PASS**:
  - `-Required` 12/12:LGF 73 + rts/regression(rts_auto_battle / castle_war / ai_vs_player / ai_vs_ai_observe / pathfinding_baseline / long_pathfinder_determinism / hierarchical_unreachable / replay_bit_identical)+ hex/regression(skill_scenarios / frontend_main)+ core unit
  - `rts/pathfinding` 13/13:navigation / grid_pathfinding / pathfinding_baseline / pathfinding_validation / clearance_inflate / region_id_helper / hierarchical_recompute / hierarchical_isolated_region / hierarchical_unreachable / long_pathfinder_basic+unreachable+determinism / **vertex_static_obb** 全 PASS
  - smoke_vertex_static_obb 单跑 0.8s,vertex 算法层 8 sub-test (data class / segment_clear 几何 / direct line / OBB blocks / same-point / 完全包围 / determinism / search bounds toward goal / vertex 候选顺序 deterministic) 全 PASS
  - prototype proto_vertex_obb 单跑 PASS,128×128 grid + 5 OBB(3 barracks + 2 tower)+ start (50,50) → goal (1500,1500) clearance=14 → path size=2 + 全 segment clear
- **Stop runner 检查**:9 条全 clear(详见 §3)

