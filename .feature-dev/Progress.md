# Progress — RTS Pathfinding M3 Epic / M4 active

**Status**: 🟡 M4 进行中 (M4a + M4b done; M4-perf-gate 待启动决定 M4c 是否做)。M0+M1+M2+M3 archived 2026-05-04。

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

- [x] **M4b.1** get_region / get_global_region / is_goal_reachable_point + spiral ring scan(`rts_hierarchical_pathfinder.gd:331/351/362/432-482`)
- [x] **M4b.2** make_goal_reachable_point canonicalize(M4b 阶段 reachable → no-op,不可达 → 跟 start 同 GlobalRegion 的离 goal 最近 navcell;`rts_hierarchical_pathfinder.gd:392-425`)
  - **设计偏离 spec**:spec §M4b.2 "总是 mutate goal 到 navcell 中心" 被推迟到 M5 LongPathfinder 落地时再做 — M4b 阶段保 baseline 不动(reachable → no-op),M5 引入 LongPathfinder 时再切"总是 navcell 中心" + 接受 P1 baseline 漂(详见函数 docstring)
- [~] **M4b.3** Wire 进 RtsMoveUnitsCommand — **DEFERRED 到 M5**(2026-05-04 用户确认)
  - **问题**:spec §M4b.3 前提 "target = 玩家右键点的地图坐标" 与 AI attack-move "target = enemy actor 中心" 语义冲突。wire 进 `rts_move_units_command.gd` 后 ai_vs_player smoke unit-to-ct attacks 7 → 0(canonicalize 把 enemy actor 中心 — 落在 building footprint 内 — 拽到 ct 旁外缘 navcell,unit 走到那里停但 ct 在 attack range 外 → 永远打不到)
  - **触发条件 M5 解锁**:M5 LongPathfinder 落地后,canonicalize 总是 mutate(M4b reachable → no-op 语义改成 "总是到 navcell 中心"),AI attack-move 走单独路径(直接传 enemy actor 中心,不过 canonicalize)
  - **临时回避**:wire 已 revert,baseline 恢复 byte-identical
- [x] **M4b.4** Smoke `smoke_hierarchical_unreachable`(6 sub-test:reachable / unreachable / goal-in-wall / start-in-wall / pure-query / split-by-wall)PASS — 纯 API 测试不依赖 wire

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
- [x] **AC3** M4b is_goal_reachable / make_goal_reachable:**API 层实现 + smoke 验证 PASS**(`smoke_hierarchical_unreachable` 6 sub-test:reachable / unreachable / goal-in-wall / start-in-wall / pure-query / split-by-wall)。**M4b 阶段语义偏离 spec**:reachable → no-op(不动 goal),不可达 → 同 GlobalRegion 离 goal 最近 navcell;原 spec "总是 navcell 中心 canonicalize" 推迟到 M5 LongPathfinder 落地(详见函数 docstring)。**Wire 进 player command 推迟到 M5**(target 语义冲突,详见 §1 M4b.3 deferred)
- [ ] **AC4** M4c dirty 增量(若启动):add/remove building → 受影响 chunks 重 flood,GlobalRegion 重算;增量 ≥3× full recompute
- [ ] **AC5** ✋2 体验点 demo 玩家点不可达点不死循环 — **M5 LongPathfinder 落地 + wire 完成后才能验**(M4b 阶段 wire 推迟,体验点跟 wire 一起推到 M5)
- [x] **AC6** 3 smoke PASS — M4a (recompute + isolated_region) + M4b (unreachable) 全 PASS。Validation 全套:LGF 73/73 + replay seed=42 frames=11 events=20 deep-equal + baseline CSV byte-identical 829520 bytes + 5 RTS smoke spot-check baseline-identical(rts_auto / castle_war / flying / determinism / clearance_inflate)
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

### M4b sub-phase done(2026-05-04)

- **新代码**(submodule):
  - `example/rts-auto-battle/logic/pathfinding/rts_hierarchical_pathfinder.gd` 加 ~170 行 M4b 公开 API:
    - `is_recomputed()` / `get_region(i,j,mask)` / `get_global_region(i,j,mask)` / `is_goal_reachable_point(start,goal,mask)` / `make_goal_reachable_point(start,goal,mask)` / `find_nearest_passable_navcell(start,mask)` + 内部 helper(`_find_nearest_in_global_region` / `_scan_ring_for_passable` / `_scan_ring_for_global`)
  - `example/rts-auto-battle/tests/battle/smoke_hierarchical_unreachable.{gd,tscn}`(6 sub-test 覆盖 AC3.1-AC3.4 + 边界)
- **设计偏离 spec(已写函数 docstring)**:M4b 阶段 `make_goal_reachable_point` reachable → no-op(不动 goal,保 baseline 路径不漂);原 spec §M4b.2 "总是 mutate 到 navcell 中心" 推迟到 M5 LongPathfinder 落地 — 因为 M5 之前 LongPathfinder 不存在,canonicalize 到 navcell 中心会让 target 偏 0-16 px → 改 baseline → 触发 stop runner 第 6 条
- **M4b.3 wire DEFERRED 到 M5**(2026-05-04 用户确认):
  - **冲突点**:spec §M4b.3 假设 wire 入口 = "玩家右键点目标" 的 click 坐标(地图 free space 的点);AI attack-move(`rts_ai_strategy.gd` 决策)的 target = enemy actor 中心(很可能落在 building footprint impassable 区)。wire 进 `rts_move_units_command.gd` 后:canonicalize 把 enemy actor 中心 → 拽到 ct 旁外缘 navcell → unit 走到那站住 → ct 在 attack range 外 → ai_vs_player smoke unit-to-ct attacks 7 → 0
  - **触发 M5 才解锁**:M5 LongPathfinder 落地时改 canonicalize 语义 + AI attack-move 走单独路径(直接传 enemy actor 中心,不过 canonicalize)
  - **临时回避**:wire 已 revert,baseline 恢复 byte-identical
- **Validation 全套 PASS**(M4b sub-phase 收口):
  - `/tmp/lgf.txt`:LGF 73/73 PASS
  - `/tmp/s_replay.txt`:replay seed=42 commands=2 frames=11 events=20 deep-equal PASS
  - `/tmp/s_rts.txt`:rts_auto_battle ticks=264 attacks=65 melee=33 ranged=32 melee_max=24.16 deaths=4 detoured=4(M3 末态完全 baseline-identical)
  - `/tmp/s_clear.txt`:clearance_inflate AC1+AC2+AC3+AC8 PASS
  - `/tmp/s_baseline.txt` + `cmp` 验:baseline CSV byte-identical 829520 bytes
  - `/tmp/s_unreach.txt`:smoke_hierarchical_unreachable 6 sub-test PASS
- **Stop runner 检查**:9 条全 clear(M4b 算法层不消费 production code → 0 baseline 漂移)

