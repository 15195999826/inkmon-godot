# Progress — RTS Pathfinding M3 Epic / M4 active

**Status**: 🟡 M4 进行中 (M0+M1+M2+M3 done + archived 2026-05-04)。

**Active feature**: M4 — HierarchicalPathfinder
**完整 spec**: [`task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md)

---

## 0. 已完成 milestones

✅ M0 done + archived(2026-05-04)— [`archive/2026-05-04-rts-m3-m0-footprint-split/Summary.md`](archive/2026-05-04-rts-m3-m0-footprint-split/Summary.md)
✅ M1 done + archived(2026-05-04)— [`archive/2026-05-04-rts-m3-m1-navcell-grid/Summary.md`](archive/2026-05-04-rts-m3-m1-navcell-grid/Summary.md)
✅ M2 done + archived(2026-05-04)— [`archive/2026-05-04-rts-m3-m2-obstruction-manager/Summary.md`](archive/2026-05-04-rts-m3-m2-obstruction-manager/Summary.md)
✅ M3 done + archived(2026-05-04)— [`archive/2026-05-04-rts-m3-m3-clearance/Summary.md`](archive/2026-05-04-rts-m3-m3-clearance/Summary.md)

M3 末态 baseline(M4 出发点):ObstructionManager.rasterize 两步(原 cell 占用 + clearance 外扩 inflate)+ procedure.tick_once `rasterize_if_dirty` 增量重写 NavcellGrid + R5 P1-2 dirty lifecycle invariant + LGF 73/73 + 17 RTS smoke 全 PASS + replay seed=42 frames=11 events=20 deep-equal + baseline CSV byte-identical 829520 bytes + `smoke_clearance_inflate` 4 sub-test 全过。

---

## 1. M4 子任务 checklist

完整定义见 [`M4-hierarchical.md §2`](task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md#2-子任务)。

### M4a — Full Recompute (默认必做)

- [x] **M4a.1** RtsRegionIdHelper packed int64 (24+24+16 bit) + boundary case 单元测试 — `logic/pathfinding/rts_region_id_helper.gd` + `tests/battle/smoke_region_id_helper.tscn` PASS
- [x] **M4a.2** RtsHierarchicalChunk(96×96 navcells per chunk + regions / regions_id PackedInt32Array)— `logic/pathfinding/rts_hierarchical_chunk.gd`
- [x] **M4a.3** RtsHierarchicalPathfinder.recompute(per-class 全图 chunks → flood-fill within chunk,字典序起点 §12.2)— `logic/pathfinding/rts_hierarchical_pathfinder.gd:88` recompute / `_build_chunk:122` / `_flood_fill_chunk:146`(cursor + PackedInt32Array O(N) BFS)
- [x] **M4a.4** _build_edges + _add_vertical_edges / _add_horizontal_edges(跨 chunk edges,bsearch+insert 替代 append+sort)— `rts_hierarchical_pathfinder.gd:188 / 199 / 207 / 215 / 232 / 245`
- [x] **M4a.5** _compute_global_regions(R5 P1 #3 修订:起点 = 全量 packed RegionID,cursor BFS)— `rts_hierarchical_pathfinder.gd:262` + 验 via `smoke_hierarchical_isolated_region.tscn` 4 isolated 4 unique GlobalID
- [x] **M4a.6** Smoke `smoke_hierarchical_recompute`(AC2+AC8 6 sub-test PASS)+ `smoke_hierarchical_isolated_region`(R5 P1 #3 + AC1+AC8 3 sub-test PASS)
- [x] **M4a.7** Wire — `world.hierarchical_pathfinder` 字段 + procedure.tick step 6.7 lazy recompute (在 step 6.6 rasterize 之后,production code M4a 不消费 → 0 baseline 漂移)

### M4b — MakeGoalReachable canonicalization (默认必做)

- [ ] **M4b.1** get_region / get_global_region / is_goal_reachable + _navcell_in_goal 暴力扫
- [ ] **M4b.2** make_goal_reachable canonicalize(可达 → 替换 POINT;不可达 → 全图最近)
- [ ] **M4b.3** Wire 进 RtsMoveUnitsCommand / RtsPlaceBuildingCommand(启动寻路前调 facade.make_goal_reachable)
- [ ] **M4b.4** Smoke `smoke_hierarchical_unreachable`(点建筑内部 → canonicalize 到外缘最近 navcell,单位走到那里停)

### M4c — Dirty 增量更新 (M4-spec §1 R5 反馈:可选,perf 触发)

- [ ] **M4-perf-gate** 测 M4a 100 unit / 16 building 规模 full recompute perf;> 30 ms / tick 才启动 M4c,否则跳过
- [ ] (M4c 启动条件触发后) M4c.1 update(grid, dirty)
- [ ] (M4c 启动条件触发后) M4c.2 procedure tick step 6.7 接 update(R5 P1-2 invariant 严格保:不在 step 5-6 中间清 dirty)
- [ ] (M4c 启动条件触发后) M4c.3 Smoke `smoke_hierarchical_dirty_update`(add/remove building → region 自动 update + 回归合并)

### Validation 收口

- [ ] **M4-validation** 全套 17 项 + LGF 73 + replay seed=42 deep-equal + baseline CSV(M4 path 变化预期 P1,接受新 baseline)
- [ ] **✋2 用户体验点** demo_rts_frontend 玩家右键点不可达点 → 单位走到最近可达 navcell,不死循环

---

## 2. AC 验收(镜像自 [M4-hierarchical.md §3](task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md#3-验收准则-m4-总))

- [x] **AC1** RtsRegionId helper packed int64:pack/unpack 可逆 + 0 = invalid 与 (ci=0, cj=0, r=N) 区分 — `smoke_region_id_helper` 4 sub-test PASS
- [x] **AC2** M4a recompute:单 chunk 全可通 → 1 region;一半 impassable → 2+ regions;跨 chunk edges 完整 — `smoke_hierarchical_recompute` 6 sub-test PASS
- [ ] **AC3** M4b is_goal_reachable / make_goal_reachable:可达 → canonicalize 到区内最近;不可达 → 全图最近
- [ ] **AC4** M4c dirty 增量(若启动):add/remove building → 受影响 chunks 重 flood,GlobalRegion 重算;增量 ≥3× full recompute
- [ ] **AC5** ✋2 体验点 demo 玩家点不可达点不死循环
- [~] **AC6** 3 smoke PASS — M4a 阶段 2/3 PASS(recompute + isolated_region);M4b smoke 留 M4b。Validation 全套:LGF 73/73 + replay seed=42 frames=11 events=20 deep-equal + baseline CSV byte-identical 829520 bytes + 5 RTS smoke spot-check baseline-identical(rts_auto / castle_war / flying / determinism / clearance_inflate)
- [ ] **AC7** Perf 增长 ≤ 50%(M4a)+ ≤ 200%(M4c)+ tick_p99 / tick_max ≤ +50%(stop runner 第 5 条)— 留 M4-perf-gate
- [x] **AC8** Determinism §12.2 严格遵守:chunk flood-fill 字典序 (`_build_chunk:128-130` lj outer / li inner) + Region ID 单调递增 (`:135` next_local_r += 1) + Edge bsearch+insert 升序 (`_insert_sorted_unique:245`) + GlobalRegion BFS 起点 = 全量 packed RID 升序 (`_compute_global_regions:271 all_rids.sort()`)— `smoke_hierarchical_recompute._test_determinism_two_runs` 跑两次 deep-equal + isolated_region order test PASS

---

## 3. 残余风险

完整列表见 [M4-hierarchical.md §6](task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md#6-残余风险) + [risks-and-rollback.md §1.1 / §3](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md);M4 主要风险:

- **R1** M4c 增量 GlobalRegion 错算(分量合并/分裂)— invariant check + 100 cycle smoke
- **R2** edges Dictionary 迭代序漂 — 所有 edges 操作按 packed RID 升序 sort
- **R3** _build_chunk flood_fill 起点漂 — 严格 (lj, li) 字典序
- **R4** make_goal_reachable canonicalize 后 LongPath 仍找不到 — M4b smoke 必须验证闭环
- **R5** M4c update 触发频率(每 tick 都跑会贵)— rasterize_if_dirty 已确保只 dirty 时跑

⚠️ **risks-and-rollback §3 stop runner 9 条触发条件 已读完**:
1. replay seed=42 deep-equal FAIL
2. 14 项 smoke 任一项已实填字段 byte diff
3. LGF 73 单元测试任一 FAIL
4. LGF submodule core/ 或 stdlib/ 内文件被改
5. perf tick_p99 / tick_max 增长 ≥ 100%(2×)
6. baseline CSV 已实填字段值变化但不在预期算法变化范围(M4 引入新字段从占位 -1 变实填属于预期 P1)
7. ✋2 用户体验点不通过
8. R5 P1 #2 dirty lifecycle invariant 违反(任一路径在 step 5-6 中间清 dirty)
9. R5 P1 #1 actor sort 用字典序而非 (kind, spawn_seq) 数值复合 key (M7 引入 sort 时漂)

---

## 4. 下一步动作

由 `/autonomous-feature-runner` 接 M4 起步。详见 Next-Steps.md。

---

## 5. Evidence(累积)

### M4a sub-phase done(2026-05-04)

- **新代码**(submodule `addons/logic-game-framework/`):
  - `example/rts-auto-battle/logic/pathfinding/rts_region_id_helper.gd`
  - `example/rts-auto-battle/logic/pathfinding/rts_hierarchical_chunk.gd`
  - `example/rts-auto-battle/logic/pathfinding/rts_hierarchical_pathfinder.gd`
  - `example/rts-auto-battle/tests/battle/smoke_region_id_helper.{gd,tscn}`
  - `example/rts-auto-battle/tests/battle/smoke_hierarchical_recompute.{gd,tscn}`
  - `example/rts-auto-battle/tests/battle/smoke_hierarchical_isolated_region.{gd,tscn}`
- **修改**(submodule):
  - `example/rts-auto-battle/core/rts_world_gameplay_instance.gd`(+ `hierarchical_pathfinder` 字段)
  - `example/rts-auto-battle/core/rts_auto_battle_procedure.gd`(`_init` 末尾 `world.hierarchical_pathfinder = RtsHierarchicalPathfinder.new()` + `tick_once` step 6.7 lazy recompute,守卫用 `is_recomputed()` derived state)
- **Simplify pass 收尾**(commit 前 7a-7b 强制要求):
  - flood_fill / global_regions BFS 用 cursor + PackedInt32Array 替代 Array.pop_front()(O(N²) → O(N))
  - 4-邻居 hoist 成 file-level const(避免 BFS 内层每次 alloc)
  - `_add_undirected_edge` 用 bsearch+insert 替代 append+sort
  - `_add_edges_between(direction:String)` 拆 `_add_vertical_edges` / `_add_horizontal_edges` + `_add_pair_if_passable` helper(消除 stringly-typed)
  - 删 `_hierarchical_initial_recompute_done` flag(改用 `is_recomputed()` derived state),省字段省 8 行 docstring
- **Validation 全套 PASS**(simplify 后重跑):
  - `/tmp/lgf.txt`:LGF 73/73 PASS
  - `/tmp/s_rts.txt`:rts_auto_battle ticks=264 attacks=65 melee=33 ranged=32 melee_max=24.16 deaths=4 detoured=4(完全 baseline-identical)
  - `/tmp/s_replay.txt`:replay seed=42 commands=2 frames=11 events=20 deep-equal
  - `/tmp/s_baseline.txt` + `cmp` 验:baseline CSV byte-identical 829520 bytes
  - `/tmp/castle.txt`、`/tmp/flying.txt`、`/tmp/det.txt`、`/tmp/clear.txt`:4 baseline-critical smoke 全 PASS
  - 3 hierarchical smoke 全 PASS(`/tmp/s_rid.txt` + `/tmp/s_hier_r.txt` + `/tmp/s_hier_iso.txt`)
- **Stop runner 检查**:9 条全 clear(无 replay 漂、无数字漂、无 LGF 回归、无 LGF submodule core/ stdlib 改动、无 perf 信息变化、无 baseline 已实填字段值变、体验点未到、dirty lifecycle invariant 未违反、无 actor sort 引入)

