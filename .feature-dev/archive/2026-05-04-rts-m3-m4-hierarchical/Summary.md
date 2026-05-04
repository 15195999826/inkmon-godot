# RTS Pathfinding M3 Epic / M4 — HierarchicalPathfinder + Canonicalize API — Summary (2026-05-04)

> M3 Epic 第五个 milestone(M4/9)。在 M3 末态(NavcellGrid + ObstructionManager + Clearance inflate)之上落地 0 A.D. 风格 HierarchicalPathfinder — chunk + region 数据结构 + canonicalize API。
>
> **整 milestone 算法层落地 + production code 不消费** → 0 baseline 漂移(LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical 829520 bytes)。M4b.3 wire 试 RtsMoveUnitsCommand 失败(spec assumption 与 AI attack-move 语义冲突),已 revert,wire + ✋2 体验点 deferred 到 M5;M4-perf-gate realistic demo p99=28 ms ≤ 30 ms 阈值 → M4c CANCEL。

---

## Acceptance 结论 (M4a + M4b + M4-perf-gate done;AC1-AC8 完成或显式 CANCEL/DEFERRED)

### M4 子 phase 状态

| Sub | Scope | 状态 |
|---|---|---|
| **M4a** | Full Recompute:`RtsRegionIdHelper` packed int64 + `RtsHierarchicalChunk` 96² + `RtsHierarchicalPathfinder.recompute`(per-class flood-fill BFS + 跨 chunk edges + GlobalRegion 全量起点 BFS,R5 P1 #3 含 isolated region)+ wire 进 `world.hierarchical_pathfinder` + procedure step 6.7 lazy recompute | ✅ done |
| **M4b** | MakeGoalReachable 公开查询 API:`is_recomputed` / `get_region` / `get_global_region` / `is_goal_reachable_point` / `make_goal_reachable_point` / `find_nearest_passable_navcell` + spiral ring scan;**M4b 阶段语义偏离 spec**(reachable → no-op 保 baseline);M4b.3 wire 进 RtsMoveUnitsCommand DEFERRED 到 M5(target 语义冲突) | ✅ done(wire deferred) |
| **M4-perf-gate** | Synthetic perf smoke `smoke_hierarchical_perf` + 阈值判:realistic demo(96² + 16 building × 5²)p99=28 ms ≤ 30 ms 阈值 → 跳 M4c;synthetic future-warning(192²/384²/768² + 10% scattered)p99=119/450/1683 ms info | ✅ done(M4c CANCEL) |
| **M4c** | Dirty 增量更新 | ⛔ CANCEL(perf-gate 不触发) |
| **✋2 体验点** | demo 玩家点不可达点不死循环 | ⏸ DEFERRED 到 M5(依赖 M4b.3 wire) |

### AC1-AC8 验收

- ✅ **AC1** RtsRegionId helper packed int64:pack/unpack 可逆 + 0 = invalid 与 (ci=0, cj=0, r=N) 区分(`is_invalid` 仅检 r 字段)— `smoke_region_id_helper` 4 sub-test PASS
- ✅ **AC2** M4a recompute:单 chunk 全可通 → 1 region;一半 impassable → 2+ regions;跨 chunk edges 完整 — `smoke_hierarchical_recompute` 6 sub-test PASS
- ✅ **AC3** M4b is_goal_reachable / make_goal_reachable:**API 层实现 + smoke 验证 PASS**(`smoke_hierarchical_unreachable` 6 sub-test:reachable / unreachable / goal-in-wall / start-in-wall / pure-query / split-by-wall)。**M4b 阶段语义偏离 spec**(reachable → no-op 保 baseline,不可达 → 跟 start 同 GlobalRegion 离 goal 最近 navcell);**Wire 进 player command DEFERRED 到 M5**
- ⛔ **AC4** M4c dirty 增量 — CANCEL(M4-perf-gate realistic demo p99=28 ms ≤ 阈值)
- ⏸ **AC5** ✋2 体验点 demo 玩家点不可达点不死循环 — DEFERRED 到 M5(依赖 wire,跟 wire 一起推 M5)
- ✅ **AC6** 4 hierarchical smoke PASS(region_id_helper + recompute + isolated_region + unreachable + perf)+ Validation 全套(LGF 73/73 + replay deep-equal + baseline CSV byte-identical 829520 bytes + 5 RTS smoke baseline-identical)
- ✅ **AC7** Perf:realistic demo p99=28 ms ≤ 30 ms 阈值 PASS;synthetic future-warning info(28 ms 离阈值仅 7% 余地,M5+ 复测)
- ✅ **AC8** Determinism §12.2 严格遵守:chunk flood-fill 字典序起点 + Region ID 单调递增 + Edge bsearch+insert 升序 + GlobalRegion BFS 起点 = 全量 packed RID 升序 — `smoke_hierarchical_recompute._test_determinism_two_runs` 跑两次 deep-equal PASS

---

## 关键 artifact 路径

### 修改文件 (submodule)

```
addons/logic-game-framework/example/rts-auto-battle/
└── core/
    └── rts_auto_battle_procedure.gd          ← _init 末构造 hierarchical_pathfinder;
                                                  tick_once step 6.7 lazy recompute(在 step 6.6
                                                  rasterize 之后,is_recomputed() derived state 守卫)
```

### 新建文件 (submodule)

```
addons/logic-game-framework/example/rts-auto-battle/
├── logic/pathfinding/
│   ├── rts_region_id_helper.gd               ← packed int64 (24+24+16 bit) helper;pack / unpack /
│   │                                            unpack_ci/unpack_cj/unpack_r / is_invalid +
│   │                                            INVALID const + boundary case (ci=0, cj=0, r=0 → 0)
│   ├── rts_hierarchical_chunk.gd             ← 96×96 navcells per chunk;regions: PackedInt32Array
│   │                                            (size = 96², 0=impassable / ≥1=local region ID) +
│   │                                            regions_id: Array[int]; get_region / region_center
│   └── rts_hierarchical_pathfinder.gd        ← 主类 RefCounted;字段 _chunks_w/h / _chunks /
│                                                _edges / _global_regions / _next_global_region /
│                                                _grid; M4a recompute / _build_chunk /
│                                                _flood_fill_chunk(cursor + PackedInt32Array O(N) BFS)/
│                                                _build_edges + _add_vertical_edges /
│                                                _add_horizontal_edges + _add_pair_if_passable /
│                                                _add_undirected_edge / _insert_sorted_unique
│                                                (bsearch+insert 升序);_compute_global_regions
│                                                (R5 P1 #3 全量起点 BFS); M4b is_recomputed /
│                                                get_region / get_global_region /
│                                                is_goal_reachable_point /
│                                                make_goal_reachable_point /
│                                                find_nearest_passable_navcell + 内部
│                                                _find_nearest_in_global_region /
│                                                _scan_ring_for_passable / _scan_ring_for_global
│                                                ~520 行
└── tests/battle/
    ├── smoke_region_id_helper.{tscn,gd,gd.uid}             ← M4a.1 — 4 sub-test (pack/unpack 可逆 + 0=invalid 与 (ci=0,cj=0,r=0)/r≥1 区分)
    ├── smoke_hierarchical_recompute.{tscn,gd,gd.uid}       ← M4a — 6 sub-test (单 chunk 全可通 / 一半 impassable / 全 impassable / 2×2 全连通 / 2×2 墙隔开 / determinism)
    ├── smoke_hierarchical_isolated_region.{tscn,gd,gd.uid} ← M4a — 3 sub-test (R5 P1 #3:4 完全孤立 region 4 unique GlobalID + isolated 1 chunk + edges 表外 region 全量起点 BFS)
    ├── smoke_hierarchical_unreachable.{tscn,gd,gd.uid}     ← M4b — 6 sub-test (reachable / unreachable canon ∈ start_g / goal-in-wall / start-in-wall fallback / pure-query / split-by-wall canon ∈ start 半区)
    └── smoke_hierarchical_perf.{tscn,gd,gd.uid}            ← M4-perf-gate — realistic demo (96² + 16 building × 5²) 阈值判 + synthetic future-warning (192²/384²/768² + 10% scattered) info
```

### 子任务 commit

- submodule sha **b587503**: `feat(rts-m3): M4a done — Hierarchical Pathfinder full recompute`
- submodule sha **b1ff422**: `feat(rts-m3): M4b done — MakeGoalReachable canonicalize API + smoke`
- submodule sha **5bd9a36**: `test(rts-m3): M4-perf-gate — synthetic perf smoke 决定 M4c 跳过`

---

## Spec 偏离

### 1. `make_goal_reachable_point` reachable → no-op(M4b 阶段临时方案)

spec [§M4b.2](task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md) "总是 mutate goal 到 navcell 中心" 推迟到 M5 LongPathfinder 落地。

**why**:M5 之前 LongPathfinder 不存在,canonicalize 到 navcell 中心会让 target 偏 0-16 px → 改 baseline 路径 → 触发 stop runner 第 6 条(M4 不应改路径)。M4b 阶段 reachable → no-op,M5 引入 LongPathfinder 时再切 "总是 navcell 中心" + 接受 P1 baseline 漂(详见函数 docstring)。

### 2. M4b.3 wire DEFERRED 到 M5

spec §M4b.3 假设 wire 入口 = "玩家右键点目标" 的 click 坐标(地图 free space 的点);AI attack-move(`rts_ai_strategy.gd` 决策)的 target = enemy actor 中心 — 很可能落在 building footprint impassable 区。

**实测 wire 进 `rts_move_units_command.gd` 后** ai_vs_player smoke unit-to-ct attacks 7 → 0(canonicalize 把 enemy actor 中心 → 拽到 ct 旁外缘 navcell → unit 走到那站住但 ct 在 attack range 外 → 永远打不到)。

**M5 解锁条件**:
1. canonicalize 语义改成"总是 mutate 到 navcell 中心"(M4b 阶段 reachable → no-op 临时方案被替代)
2. AI attack-move 走单独路径(直接传 enemy actor 中心,**不**过 canonicalize)— 跟玩家 click move 区分入口
3. 重新 wire 时验 `smoke_ai_vs_player_full_match` unit-to-ct attacks ≥ baseline 阈值

### 3. M4c CANCEL(perf-gate 不触发)

spec §1 R5 反馈把 M4c 降级为 perf 触发项(> 30 ms / tick 才启动)。M4-perf-gate 实测 realistic demo p99=28 ms ≤ 30 ms 阈值 → 跳 M4c。

**未来需补 M4c 的信号**:
- demo grid 扩大到 192²+ (4+ chunks)
- dynamic building 多触发 dirty rasterize 频率上升
- M5 wire LongPath 后 dirty trigger 增加 → 28 ms 离阈值仅 7% 余地

### 4. ✋2 体验点 DEFERRED 到 M5

spec §3 AC5 体验点 = "demo 玩家右键点不可达点 → 单位走到最近可达 navcell,不死循环"。这个体验**完全依赖 M4b.3 wire 落地**(没 wire = canonicalize 不调 = 体验不存在)。M4b.3 wire deferred 到 M5,体验点跟 wire 一起推迟,**不阻塞 M4 archive**。

---

## Simplify pass 改进

M4a sub-phase 收口前(commit b587503 前):
1. **flood_fill / global_regions BFS 用 cursor + PackedInt32Array** 替代 `Array.pop_front()`(O(N²) → O(N);9216-cell BFS 最坏 ~8500 万次 memmove → 改完 ~9216 次)
2. **4 邻居 hoist 成 file-level const** `_NEIGHBOR_DELTA_LI/J`(避免 BFS 内层每次 alloc 4 元 Array + 4 个 Vector2i)
3. **`_add_undirected_edge` 用 bsearch+insert** 替代 append+sort(deduplicate + 升序一步)
4. **`_add_edges_between(direction:String)` 拆 `_add_vertical_edges` / `_add_horizontal_edges` + `_add_pair_if_passable`** helper(消除 stringly-typed)
5. **删 `_hierarchical_initial_recompute_done` flag** 改用 `is_recomputed()` derived state(省字段省 8 行 docstring)

M4b 没明显 simplify 候选(代码已干净:复用 M4a get_chunk / get_global_region helper;`_scan_ring_for_passable` vs `_scan_ring_for_global` 重复但合并成 lambda 在 GDScript hot path 不友好,保留)。

---

## 决策来源 / 引用

- spec: `task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md` §M4a / §M4b
- 数据结构: `task-plan/m3-0ad-pathfinding-migration/data-structures.md` §4 (含 R5 P1 #3 isolated region 修订)
- API: `task-plan/m3-0ad-pathfinding-migration/interfaces.md` §3
- 决策模型: 2026-05-04 用户确认 "M4b.3 wire 跳过 → DEFERRED 到 M5" + "M4-perf-gate 重测真实 demo 规模后再判 → realistic ≤ 阈值 → 跳 M4c"
- 风险: `task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md` §1.1 / §3 stop runner 9 条
- 0 A.D. 对照: `helpers/HierarchicalPathfinder.h:120-170` 公开 API + `Recompute / Update`
- M3 末态 baseline: `archive/2026-05-04-rts-m3-m3-clearance/Summary.md`

---

## 残余风险 → M5 启动

- **R1 M5 canonicalize 切换 P1 baseline 漂**: M4b 阶段 reachable → no-op,M5 切 "总是 navcell 中心" 会让 target 偏 0-16 px → 改 baseline。**预期 P1 算法变化,接受新 baseline**(stop runner 第 6 条不触发)
- **R2 M5 wire AI attack-move 路径独立**: M5 必须先把 AI attack-move 拆成单独路径(直接传 enemy actor 中心,不过 canonicalize),再 wire 玩家命令;否则重蹈 M4b.3 试 wire 失败覆辙(unit-to-ct attacks 7→0)
- **R3 M5+ perf 击穿阈值**: M4-perf-gate 28 ms 离 30 ms 仅 7% 余地;M5 加 LongPath A* + dirty rasterize 频率上升 + grid 扩大 → 可能超阈,触发补 M4c
- **R4 GDScript BFS overhead**: 每 navcell ~3 us(0 A.D. C++ ~0.03 us),100× 慢;算法已优化到极限,真正解法是 GDExtension 重写 hot path(perf 真冲突时再做)

---

## 下一个 milestone

**M5 — LongPathfinder**(详见 `task-plan/m3-0ad-pathfinding-migration/milestones/M5-long-pathfinder.md`)

M5 启动一次性兑现 M4 deferred 项:LongPath A* 落地 + canonicalize 语义切换("总是 navcell 中心")+ wire 进玩家命令 + AI attack-move 走单独路径 + ✋2 体验点验收。

M5 启动等用户授权(milestone-chain 协议:每 milestone 末等用户审阅)。
