# RTS Pathfinding M3 Epic / M6 — VertexPathfinder — Summary (2026-05-04)

> M3 Epic 第七个 milestone(M6/9)。引入 `RtsVertexPathfinder`(0 A.D. helpers/VertexPathfinder.cpp ~1500 行 GDScript 复刻)— visibility graph + lazy A*,任意角度直线段路径替代 LongPath 的 navcell 阶梯形;9 大类边界 case 全实现(9 details);facade `compute_short_path_immediate` API 加上,**production callsite 暂不消费**(M7 UnitMotion 整合双轨时接,届时 baseline CSV `short_path_*` 字段从占位变实填 + ✋3 demo 看效果)。
>
> M6 拆 3 sub-phase 各 ~1.5 周(spec README §7,实际本次会话内推完):
> - **M6a**: static OBB only(detail #1/#2/#5/#9 + 5 元组 deterministic + RtsPathfinderHeap 共享)
> - **M6b**: virtual goal CIRCLE/SQUARE/INVERTED 几何(detail #3)+ terrain edges(detail #4)+ best-so-far(detail #6)+ Liang-Barsky segment-vs-OBB 精确化
> - **M6c**: dynamic units square proxy(detail #7)+ group filter(detail #8)+ avoid_moving_units 开关 + facade wire(API only)+ prototype 退役(R6)
>
> **baseline CSV byte-identical**(production 不消费 vertex pathfinder → 0 漂移);LGF 73/73 + replay seed=42 deep-equal frames=11 events=24 + 16 RTS pathfinding smoke 全 PASS;9 条 stop runner 全 clear。

---

## Acceptance 结论

### M6a-c sub-phase 状态

| Sub | Scope | 状态 |
|---|---|---|
| **M6a** | RtsShortPathRequest / RtsLineOfSight(t-stepping)/ RtsVertexPathfinder static-OBB only / RtsPathfinderHeap 抽出(LongPath/Vertex 共享 5 元组 lex)/ smoke_vertex_static_obb 8 sub-test / proto_vertex_obb prototype scene | ✅ done(`d4eda45`) |
| **M6b** | RtsPathGoal CIRCLE/SQUARE/INVERTED 几何 nearest_point_on_goal + distance_to_point / VertexPathfinder._compute_virtual_goal + _add_terrain_vertices + best-so-far / RtsLineOfSight Liang-Barsky 精确替代 t-stepping / smoke_vertex_virtual_goal 7 sub-test | ✅ done(`c458bee`) |
| **M6c** | VertexPathfinder dynamic units (square proxy) + group filter (control_group + control_group_2) + avoid_moving_units 开关 / RtsPathfinderFacade.compute_short_path_immediate API + procedure 构造 vertex_pathfinder + world.vertex_pathfinder 字段 / smoke_vertex_corner_walking + smoke_vertex_group_filter / 删 prototype/ 整目录(R6) | ✅ done(`07735c8`) |

### AC1-AC12 验收

- ✅ **AC1-AC9** 9 大类边界 case 全实现:
  - **AC1.1** detail #1 search bounds toward goal shift — `_compute_search_bounds`(M6a)
  - **AC1.2** detail #2 range boundary 4 角 vertex(M6a)
  - **AC1.3** detail #3 virtual goal — `RtsPathGoal.nearest_point_on_goal` 5 type 几何 + `_compute_virtual_goal`(M6b)
  - **AC1.4** detail #4 terrain edges — `_add_terrain_vertices` (j, i) 字典序(M6b)
  - **AC1.5** detail #5 lazy visibility — A* expand 时 `segment_clear`(M6a)
  - **AC1.6** detail #6 best-so-far — `_astar_lazy_visibility` 跟踪 best_idx + start_idx 兜底(M6b)
  - **AC1.7** detail #7 moving unit square proxy — 圆形 unit 转 AABB 4 corner vertex(M6c)
  - **AC1.8** detail #8 group filter — control_group / control_group_2 双匹配(M6c)
  - **AC1.9** detail #9 tie-break — vertex (obstr.tag, corner_idx) + A* 5 元组(M6a 起)
- ⏸ **AC10** ✋3 体验点 demo F6 visual — **延后到 M7**(facade wire 仅 API,production 不接,demo 仍 LongPath;M7 UnitMotion 整合双轨后看到自然绕角)
- ✅ **AC11(部分)** Validation:LGF 73/73 + replay seed=42 deep-equal + 14 项 smoke 字段 byte-identical + baseline CSV byte-identical(M6 production 不消费 vertex,0 漂移)
- ⏸ **AC11(完整)** baseline CSV `short_path_size` / `short_path_wp_json` 字段从占位 -1 变实填 — **M7 production wire 后预期 P1 漂**;perf tick_p99 / tick_max ≤ +50% — M7 整合后实测
- ✅ **AC12** Determinism §12.3 严格遵守:vertex 候选顺序、A* 5 元组、terrain (j,i)、best-so-far 严格 < 全 deterministic;`_test_determinism_two_runs` + `_test_vertex_candidate_order_deterministic` 跨 run byte-identical PASS

---

## 关键 artifact 路径

### 新代码(submodule `addons/logic-game-framework/`)

```
example/rts-auto-battle/
├── logic/pathfinding/
│   ├── rts_short_path_request.gd          ← M6a data class(start/clearance/range/goal/
│   │                                            pass_mask/avoid_moving_units/control_group)
│   ├── rts_line_of_sight.gd               ← M6a t-stepping + M6b Liang-Barsky 精确化
│   │                                          (segment_clear + check_line_movement);
│   │                                          enclose-radius 早出 + axis-aligned fast-path
│   ├── rts_vertex_pathfinder.gd           ← M6 核心 ~290 行 GDScript;9 details 全实现
│   ├── rts_pathfinder_heap.gd             ← M6a 抽出(LongPath/Vertex 共享 5 元组 lex)
│   └── rts_path_goal.gd                   ← M6b 扩 CIRCLE/SQUARE/INVERTED 几何
└── tests/battle/
    ├── smoke_vertex_static_obb.{gd,tscn}      ← M6a 8 sub-test (rts/pathfinding manifest)
    ├── smoke_vertex_virtual_goal.{gd,tscn}    ← M6b 7 sub-test
    ├── smoke_vertex_corner_walking.{gd,tscn}  ← M6c ✋3 体感(headless)
    └── smoke_vertex_group_filter.{gd,tscn}    ← M6c group / avoid_moving 3 sub-test
```

### 修改(submodule)

```
example/rts-auto-battle/
├── core/
│   ├── rts_world_gameplay_instance.gd        ← + vertex_pathfinder 字段
│   └── rts_auto_battle_procedure.gd          ← _init 末构造 vertex + 传 facade ctor
└── logic/pathfinding/
    ├── rts_pathfinder_facade.gd              ← _init 加 p_vertex 参数 + compute_short_path_immediate API
    └── rts_long_pathfinder.gd                ← _heap_insert / _key_less 切到 RtsPathfinderHeap.insert / key_less
```

### 删除(M6c.6 R6 退役)

```
example/rts-auto-battle/tests/prototype/      ← 整目录删(proto_vertex_obb.{gd,gd.uid,tscn})
```

---

## 真实运行证据

### `-Required` 12/12 PASS(LGF + RTS regression + hex)
- `tools/run_tests.ps1 -Required` → ALL PASS,12 scene including LGF run_tests / smoke_rts_auto_battle / smoke_castle_war_minimal / smoke_ai_vs_player_full_match / smoke_ai_vs_ai_observe / smoke_pathfinding_baseline / smoke_long_pathfinder_determinism / smoke_hierarchical_unreachable / smoke_replay_bit_identical / smoke_skill_scenarios / smoke_frontend_main / tests/run_tests

### `rts/pathfinding` 16/16 PASS(M6 完整 + 历史 13)
- `tools/run_tests.ps1 rts/pathfinding`
  - `smoke_navigation`,`smoke_grid_pathfinding`,`smoke_pathfinding_baseline`,`smoke_pathfinding_validation`,`smoke_clearance_inflate`,`smoke_region_id_helper`,`smoke_hierarchical_recompute`,`smoke_hierarchical_isolated_region`,`smoke_hierarchical_unreachable`,`smoke_long_pathfinder_basic`,`smoke_long_pathfinder_unreachable`,`smoke_long_pathfinder_determinism`(M5)
  - `smoke_vertex_static_obb` 8 sub-test PASS(M6a)
  - `smoke_vertex_virtual_goal` 7 sub-test PASS(M6b)
  - `smoke_vertex_corner_walking` ✋3 算法层 PASS(M6c)
  - `smoke_vertex_group_filter` 3 sub-test PASS(M6c)

### Stop runner 9 条全 clear

1. ✅ replay seed=42 deep-equal PASS
2. ✅ 14 项 smoke 已实填字段 byte-identical
3. ✅ LGF 73/73 PASS
4. ✅ LGF submodule core/ 或 stdlib/ 0 改动
5. ✅ perf:M6 不接 production → tick_p99 / tick_max 不变
6. ✅ baseline CSV byte-identical(M6 production 不消费 vertex)
7. — ✋3 体验点延后到 M7(production wire)
8. ✅ R5 P1 #2 dirty lifecycle invariant 不违反(M6 不动 dirty 路径)
9. ✅ R5 P1 #1 actor sort 不引入(M6 不动 motion)

---

## 残余风险 / 已知 follow-up

### M7 UnitMotion 解锁的 ✋3 + AC11 完整漂

- **✋3 demo F6 visual** — M6c.4 facade wire 仅 API,production callsite 仍走 LongPath。M7 UnitMotion 把 long+short 双轨整合后,玩家 right-click 移动 / AI attack-move 才会调 `compute_short_path_immediate`,demo F6 看到任意角度斜线绕角。
- **baseline CSV short path 字段实填** — M7 production wire 后,`pathfinding_baseline.csv` 的 `short_path_size` / `short_path_wp_json` 列从占位 -1 变实数,P1 接受新 baseline。其他字段(unit position / attack count)应 byte-identical。
- **perf 实测 ≤ +50% vs M5** — M7 wire 后实测;M6 算法层 enclose-radius 早出 + axis-aligned fast-path + Liang-Barsky 精确版应足够,但需 100 unit × 30 Hz 实战验证。

### 几何精度边界 case

- Liang-Barsky `1e-9` epsilon 在极端浮点 inputs 可能误判(段几乎平行轴);典型 buffer ~12-14 px 远大于 epsilon → 实际无影响,留意未来若引入小 buffer (< 1 px) 时复查。
- best-so-far `nb_h < best_dist` 严格 < 让等距按 expansion 顺序保 deterministic;若未来引入"反向 BFS"或 expand 顺序变,需重 verify。

### M6c.6 prototype 删除是 destructive

- `tests/prototype/` 已 git rm,如需回看历史看 commit `07735c8` 前的 tree(or `git show HEAD~1:example/rts-auto-battle/tests/prototype/proto_vertex_obb.gd`)。

---

## Commits

- 主仓:
  - `76e2f4e` feat(rts-m6a): bump submodule → d4eda45 (VertexPathfinder static-OBB only)
  - `7d3f5f2` feat(rts-m6b): bump submodule → c458bee (Virtual goal + Terrain + Best-so-far + Liang-Barsky)
  - `<bump M6c TBD>` feat(rts-m6b): bump submodule → 07735c8 (M6c + archive M6)
- submodule(`addons/logic-game-framework/`):
  - `d4eda45` feat(rts): M6a VertexPathfinder static-OBB only (M3 Epic milestone 6a)
  - `c458bee` feat(rts): M6b VertexPathfinder virtual goal + Terrain + Best-so-far + Liang-Barsky 精确化
  - `07735c8` feat(rts): M6c VertexPathfinder dynamic units + group filter + facade wire + prototype 退役

---

## 决策来源

- Spec: `task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md`(本 archive 内 task-plan/ 子目录有快照)
- 0 A.D. 对照: `helpers/VertexPathfinder.cpp` ~1500 行 C++(本地副本 `addons/.../docs/references/0ad-source/`)
- Determinism: `data-structures.md §12.3` (vertex 顺序 + A* 5 元组)
- M5 末态 baseline: `archive/2026-05-04-rts-m3-m5-long-pathfinder/Summary.md`

## 下一步

按 milestone-chain 协议:**等用户授权 M7 UnitMotion 启动**;Next-Steps.md 切换到等待状态(根目录 reset 后看 .feature-dev/Next-Steps.md)。
