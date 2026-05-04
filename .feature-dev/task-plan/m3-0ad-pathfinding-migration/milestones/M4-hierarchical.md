# M4 — HierarchicalPathfinder (可达性)

> 父 plan: [`../README.md`](../README.md)
> 数据结构: [`../data-structures.md`](../data-structures.md) §4
> API: [`../interfaces.md`](../interfaces.md) §3
>
> Status: 🔒 pending(M3 完成后启动)
> 依赖: M3 (per-class navcell 已外扩,dirty 机制工作)
> 阻塞: M5 (LongPath 启动前需要 hierarchical 提供 is_goal_reachable / make_goal_reachable)
> ✋ 用户体验点 2: M4 完成时

---

## 0. 目标

实现 0 A.D. 风格 `HierarchicalPathfinder` — chunk + region 结构,提供:
- `get_region(i, j, pass_mask) -> packed RegionID` 取 navcell 所在 chunk 内 region
- `get_global_region` 取连通分量 ID(同 ID = 整图可达)
- `is_goal_reachable` 不修改 goal 检查可达
- `make_goal_reachable` **canonicalize goal**(即使可达也替换为最近 navcell POINT)

**解决 M3 之前的"在建筑前徘徊"症状** — 玩家点不可达点时,单位走到最近可达 navcell,不再死循环。

**M4 拆 3 个 sub-phase**(codex R1 反馈):
- **M4a**: full recompute(启动 / 全图重建)
- **M4b**: `MakeGoalReachable` canonicalization(replace goal with nearest reachable POINT)
- **M4c**: dirty 增量更新(基于 dirtinessGrid)

---

## 1. Scope

⚠️ **R5 反馈**: M4c 是否 over-engineering 降级为 P2 — **建议 M4a full recompute 先落, M4c 作为 perf 触发项**:
- M4a + M4b 是 M4 默认必做(全图重建 + canonicalize)
- **M4c 改为可选**: 只在 M4a full recompute perf > 30 ms / tick(性能监控触发)时才启动 M4c sub-phase
- 100 unit / 16 building 规模 full recompute 单次估算 ≤ 30 ms,不一定需要 M4c
- 若启动 M4c,严格按 R5 P1 #2 dirty snapshot 协议(本文档已修)

### 1.1 必做(M4a + M4b)+ 可选(M4c)

- 引入 `RtsRegionId` packed int64 helper(constants + pack/unpack)— [data-structures §4.1](../data-structures.md#41-rtsregionid--packed-int64不是-refcounted)
- 引入 `RtsHierarchicalChunk`(96×96 navcells per chunk,固定 CHUNK_SIZE)
- 引入 `RtsHierarchicalPathfinder` 单例
- M4a:`recompute(grid, classes)` 全图重建 — flood-fill chunks → 注册 edges → 计算 GlobalRegionID
- M4b:`make_goal_reachable(start, goal, pass_mask)` — BFS within chunk + 跨 chunk → canonicalize goal
- M4c:`update(grid, dirty)` 增量 — only re-flood dirty chunks,patch GlobalRegion graph
- ObstructionManager.rasterize 后 → trigger HierarchicalPathfinder.update(dirty)
- LongPath 仍用旧 GridPathfinding(M5 才换),但 M4b `make_goal_reachable` 在 placement command + activity setMoveRequest 时 wire 进去
- 加 3 新 smoke

### 1.2 不做

| 不做 | 原因 |
|---|---|
| LongPath / VertexPath 重写 | M5 / M6 |
| Hierarchical-aware long path(优先按 region 走) | 不需要,LongPath 直接走 navcell A* (D6) |
| 跨 pass class 的 region 共享 | 每 class 独立 chunks + edges + globalRegions |
| Dynamic obstruction(单位移动时 region 变化) | 单位不 BLOCK_PATHFINDING,所以 region 不动 |

### 1.3 文件清单

#### 新建

```
addons/.../logic/pathfinding/
├── rts_region_id_helper.gd                   ← packed int64 helper
├── rts_hierarchical_chunk.gd                 ← per-chunk data
└── rts_hierarchical_pathfinder.gd            ← 单例
```

#### 修改

```
addons/.../logic/
├── obstruction/rts_obstruction_manager.gd    ← rasterize 后触发 hierarchical.update
├── rts_world.gd                              ← 加 hierarchical_pathfinder 字段
├── core/rts_auto_battle_procedure.gd         ← 启动初始化 hierarchical
└── commands/rts_player_command_*.gd          ← move command 用 make_goal_reachable canonicalize
```

#### 新建 (smoke)

```
addons/.../tests/battle/
├── smoke_hierarchical_recompute.tscn          ← M4a 全图重建
├── smoke_hierarchical_unreachable.tscn        ← M4b unreachable goal canonicalize
└── smoke_hierarchical_dirty_update.tscn       ← M4c 增量更新
```

---

## 2. 子任务

### M4a — Full Recompute (1 周)

**M4a.1** — RtsRegionId helper

按 [data-structures §4.1](../data-structures.md#41-rtsregionid--packed-int64不是-refcounted) 实现 `pack(ci, cj, r) -> int` / `unpack_*`。单元测试覆盖 boundary case (ci=0/cj=0 与 r=0 区分)。

**M4a.2** — RtsHierarchicalChunk

```gdscript
class_name RtsHierarchicalChunk
extends RefCounted

const CHUNK_SIZE: int = 96

var ci: int
var cj: int
var regions_id: PackedInt32Array          # 此 chunk 内有效 region ID 列表
var regions: PackedInt32Array             # 长度 = 96*96, 每 navcell 属于哪 region (0 = impassable)

func _init(c_i: int, c_j: int) -> void:
    ci = c_i
    cj = c_j
    regions = PackedInt32Array()
    regions.resize(CHUNK_SIZE * CHUNK_SIZE)

func get_region(local_i: int, local_j: int) -> int:
    return regions[local_j * CHUNK_SIZE + local_i]

func region_center(r: int) -> Vector2i:
    var sum_i: int = 0
    var sum_j: int = 0
    var count: int = 0
    for j in range(CHUNK_SIZE):
        for i in range(CHUNK_SIZE):
            if regions[j * CHUNK_SIZE + i] == r:
                sum_i += i
                sum_j += j
                count += 1
    if count == 0:
        return Vector2i(-1, -1)
    return Vector2i(sum_i / count, sum_j / count)
```

**M4a.3** — RtsHierarchicalPathfinder.recompute

逐 chunk flood-fill:
```gdscript
func recompute(grid: RtsNavcellGrid, classes: Array[RtsPassabilityClassConfig]) -> void:
    _chunks_w = (grid.width() + RtsHierarchicalChunk.CHUNK_SIZE - 1) / RtsHierarchicalChunk.CHUNK_SIZE
    _chunks_h = (grid.height() + RtsHierarchicalChunk.CHUNK_SIZE - 1) / RtsHierarchicalChunk.CHUNK_SIZE
    
    for cls in classes:
        var pass_mask: int = 1 << cls.bit_index
        var chunks: Array[RtsHierarchicalChunk] = []
        chunks.resize(_chunks_w * _chunks_h)
        for cj in range(_chunks_h):
            for ci in range(_chunks_w):
                chunks[cj * _chunks_w + ci] = _build_chunk(grid, ci, cj, pass_mask)
        _chunks[pass_mask] = chunks
        # 注册跨 chunk edges
        _build_edges(pass_mask, chunks, _chunks_w, _chunks_h)
        # 计算 GlobalRegionID (跨 chunk flood-fill)
        _compute_global_regions(pass_mask)

func _build_chunk(grid: RtsNavcellGrid, ci: int, cj: int, pass_mask: int) -> RtsHierarchicalChunk:
    var ch := RtsHierarchicalChunk.new(ci, cj)
    var next_local_r: int = 1   # 0 留给 impassable
    # BFS flood-fill 顺序按 (local_j, local_i) 字典序 (Determinism §12.2)
    for lj in range(RtsHierarchicalChunk.CHUNK_SIZE):
        for li in range(RtsHierarchicalChunk.CHUNK_SIZE):
            if ch.regions[lj * RtsHierarchicalChunk.CHUNK_SIZE + li] != 0:
                continue
            var gi := ci * RtsHierarchicalChunk.CHUNK_SIZE + li
            var gj := cj * RtsHierarchicalChunk.CHUNK_SIZE + lj
            if not grid.is_passable(gi, gj, pass_mask):
                continue
            # BFS 标 next_local_r
            _flood_fill_chunk(grid, ch, ci, cj, li, lj, next_local_r, pass_mask)
            ch.regions_id.append(next_local_r)
            next_local_r += 1
    return ch

func _flood_fill_chunk(grid, ch, ci, cj, start_li, start_lj, r, pass_mask) -> void:
    var queue: Array[Vector2i] = [Vector2i(start_li, start_lj)]
    while not queue.is_empty():
        var v := queue.pop_front()
        var lj_idx := v.y * RtsHierarchicalChunk.CHUNK_SIZE + v.x
        if ch.regions[lj_idx] != 0:
            continue
        ch.regions[lj_idx] = r
        # 4 邻居 (chunk 内, 不跨 chunk)
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var nl := v + d
            if nl.x < 0 or nl.x >= RtsHierarchicalChunk.CHUNK_SIZE or nl.y < 0 or nl.y >= RtsHierarchicalChunk.CHUNK_SIZE:
                continue
            var ngi := ci * RtsHierarchicalChunk.CHUNK_SIZE + nl.x
            var ngj := cj * RtsHierarchicalChunk.CHUNK_SIZE + nl.y
            if grid.is_passable(ngi, ngj, pass_mask) and ch.regions[nl.y * RtsHierarchicalChunk.CHUNK_SIZE + nl.x] == 0:
                queue.append(nl)
```

**M4a.4** — Build edges (跨 chunk)

对每对相邻 chunk,扫描接壤的 navcell 行/列,若双侧都 passable → 注册 edge `(rid_a, rid_b)`:

```gdscript
func _build_edges(pass_mask, chunks, w, h) -> void:
    var edges: Dictionary = {}    # packed_rid → Array[packed_rid]
    for cj in range(h):
        for ci in range(w):
            var ch_a := chunks[cj * w + ci]
            # 与右邻(ci+1, cj)共享垂直边
            if ci + 1 < w:
                _add_edges_between(ch_a, chunks[cj * w + ci + 1], "vertical", edges)
            # 与下邻(ci, cj+1)共享水平边
            if cj + 1 < h:
                _add_edges_between(ch_a, chunks[(cj + 1) * w + ci], "horizontal", edges)
    _edges[pass_mask] = edges

func _add_edges_between(ch_a, ch_b, direction, edges) -> void:
    # 沿接壤边逐 navcell 测,若双侧 r != 0 → 加 edge
    var a_size := RtsHierarchicalChunk.CHUNK_SIZE
    if direction == "vertical":
        # ch_a 右边 (li=a_size-1) vs ch_b 左边 (li=0)
        for lj in range(a_size):
            var ra := ch_a.get_region(a_size - 1, lj)
            var rb := ch_b.get_region(0, lj)
            if ra != 0 and rb != 0:
                _add_undirected_edge(edges, RtsRegionIdHelper.pack(ch_a.ci, ch_a.cj, ra), RtsRegionIdHelper.pack(ch_b.ci, ch_b.cj, rb))
    else:  # horizontal
        for li in range(a_size):
            var ra := ch_a.get_region(li, a_size - 1)
            var rb := ch_b.get_region(li, 0)
            if ra != 0 and rb != 0:
                _add_undirected_edge(edges, RtsRegionIdHelper.pack(ch_a.ci, ch_a.cj, ra), RtsRegionIdHelper.pack(ch_b.ci, ch_b.cj, rb))

func _add_undirected_edge(edges: Dictionary, a: int, b: int) -> void:
    # 两端都加,且按"较小 packed RID 先注册"保 deterministic (§12.2)
    var lo := mini(a, b)
    var hi := maxi(a, b)
    var lo_arr: Array = edges.get(lo, [])
    if not (hi in lo_arr):
        lo_arr.append(hi)
        lo_arr.sort()
        edges[lo] = lo_arr
    var hi_arr: Array = edges.get(hi, [])
    if not (lo in hi_arr):
        hi_arr.append(lo)
        hi_arr.sort()
        edges[hi] = hi_arr
```

**M4a.5** — GlobalRegionID 计算 (⚠️ R5 P1 #3 修订)

⚠️ **R5 P1 #3**: 原实现只从 `edges.keys()` 取起点,**漏了"无跨 chunk edge 的 isolated passable region"** — 这种 region 不在 edges 表里,但仍是合法可通行区域(整个 region 完全在某 chunk 内,没邻接 chunk 接壤)。漏算导致 `get_global_region` 返回 0,`is_goal_reachable` 把合法 isolated region 当不可达。

**修订**: 起点必须**枚举所有 chunk.regions_id 生成全量 packed RegionID**(包括没在 edges 里的 isolated region),再用 edges 做连通扩展。

```gdscript
func _compute_global_regions(pass_mask: int) -> void:
    var edges: Dictionary = _edges[pass_mask]
    var chunks: Array = _chunks[pass_mask]
    
    # ⚠️ R5 P1 #3: 起点 = 全量 packed RegionID, 不是 edges.keys()
    # 否则 isolated region (无跨 chunk edge) 不会进 global 表 → is_goal_reachable false 误判
    var all_rids: Array[int] = []
    for ch in chunks:
        for local_r in ch.regions_id:    # local_r 不含 0 (impassable)
            all_rids.append(RtsRegionIdHelper.pack(ch.ci, ch.cj, local_r))
    all_rids.sort()       # 起点 packed RID 升序 (§12.2)
    
    var global: Dictionary = {}
    var next_global: int = 1
    for rid in all_rids:
        if global.has(rid):
            continue
        # BFS 起点 rid, 通过 edges 扩展整个连通分量
        var queue: Array = [rid]
        while not queue.is_empty():
            var r := queue.pop_front()
            if global.has(r):
                continue
            global[r] = next_global
            # 没有 edge 的 region: edges.get(r, []) = [], 这里 BFS 直接结束 — 但 rid 已分配到 next_global, isolated region 也拿到 GlobalID
            for n in edges.get(r, []):
                if not global.has(n):
                    queue.append(n)
        next_global += 1
    _global_regions[pass_mask] = global
    _next_global_region[pass_mask] = next_global
```

**新 smoke `smoke_hierarchical_isolated_region`** (M4a 验):
- 创 grid,4 个完全围闭的 passable 区域(各 ≤ 1 chunk,跟其他区域无 edge)
- recompute → 验证 4 个 isolated region 都拿到 unique GlobalRegionID(不是 0)
- `is_goal_reachable(isolated_region 内 navcell, 同 region goal, mask) == true`

**M4a.6** — Smoke + AC

`smoke_hierarchical_recompute`:
- 创 grid 192×192(2×2 chunks @ 96)+ 几个建筑
- recompute → 验证:
  - 每 chunk 有 ≥1 region(若 chunk 全可通)
  - 跨 chunk edges 已建(可见 chunk(0,0).region 1 与 chunk(1,0).region 1 同 GlobalRegion)

### M4b — MakeGoalReachable (1 周)

**M4b.1** — `is_goal_reachable / get_region / get_global_region`

```gdscript
func get_region(i: int, j: int, pass_mask: int) -> int:
    var ci := i / RtsHierarchicalChunk.CHUNK_SIZE
    var cj := j / RtsHierarchicalChunk.CHUNK_SIZE
    var li := i % RtsHierarchicalChunk.CHUNK_SIZE
    var lj := j % RtsHierarchicalChunk.CHUNK_SIZE
    if ci < 0 or ci >= _chunks_w or cj < 0 or cj >= _chunks_h:
        return 0
    var ch: RtsHierarchicalChunk = _chunks[pass_mask][cj * _chunks_w + ci]
    var r := ch.get_region(li, lj)
    if r == 0:
        return 0
    return RtsRegionIdHelper.pack(ci, cj, r)

func get_global_region(i: int, j: int, pass_mask: int) -> int:
    var rid := get_region(i, j, pass_mask)
    if rid == 0:
        return 0
    return _global_regions[pass_mask].get(rid, 0)

func is_goal_reachable(start_i: int, start_j: int, goal: RtsPathGoal, pass_mask: int) -> bool:
    var start_global: int = get_global_region(start_i, start_j, pass_mask)
    if start_global == 0:
        return false
    # goal 区域内是否有 navcell global == start_global?
    var goal_navcell := _navcell_in_goal(goal, start_global, pass_mask)
    return goal_navcell != Vector2i(-1, -1)

func _navcell_in_goal(goal, target_global, pass_mask) -> Vector2i:
    # 暴力扫 goal 范围内 navcells, 看哪个 in target_global
    var bbox := _goal_bounding_navcells(goal)
    var i0 := bbox[0]
    var j0 := bbox[1]
    var i1 := bbox[2]
    var j1 := bbox[3]
    for j in range(j0, j1 + 1):
        for i in range(i0, i1 + 1):
            if not goal.navcell_contains_goal(i, j):
                continue
            if get_global_region(i, j, pass_mask) == target_global:
                return Vector2i(i, j)
    return Vector2i(-1, -1)
```

**M4b.2** — `make_goal_reachable` (canonicalize) — **实际实现 = `make_goal_reachable_point` 偏离 spec(详见函数 docstring)**

按 [interfaces §1.3](../interfaces.md#13-make_goal_reachable-语义-codex-r1-p1-修正):
- true: goal 区域内有可达 → 替换 goal 为该区域**离 start 最近**的 navcell POINT
- false: goal 区域无可达 → 全图最近可达 POINT

⚠️ **M4b 阶段实际实现偏离**(2026-05-04):`make_goal_reachable_point` reachable → **no-op**(不动 goal,保 baseline 路径不漂);不可达 → 跟 start 同 GlobalRegion 的离 goal 最近 navcell 中心。原 spec "总是 navcell 中心 mutate" 推迟到 M5 LongPathfinder 落地 + 接受 P1 baseline 漂(M4b 阶段 LongPathfinder 不存在,canonicalize 到 navcell 中心会让 target 偏 0-16 px → 改 baseline → 触发 stop runner 第 6 条)。

```gdscript
func make_goal_reachable(start_i: int, start_j: int, goal: RtsPathGoal, pass_mask: int) -> bool:
    var start_global: int = get_global_region(start_i, start_j, pass_mask)
    if start_global == 0:
        # start 本身在 impassable navcell, 找最近可通
        var fallback := find_nearest_passable_navcell(Vector2i(start_i, start_j), pass_mask)
        if fallback == Vector2i(-1, -1):
            return false
        start_i = fallback.x
        start_j = fallback.y
        start_global = get_global_region(start_i, start_j, pass_mask)
    
    # 1) 查 goal 区域内最近可达 navcell
    var nearest_in_goal := _find_nearest_in_goal_with_global(goal, start_global, Vector2i(start_i, start_j), pass_mask)
    if nearest_in_goal != Vector2i(-1, -1):
        # canonicalize: 替换 goal 为 POINT
        goal.type = RtsPathGoal.Type.POINT
        goal.center = _navcell_center(nearest_in_goal)
        goal.hw = 0.0
        goal.hh = 0.0
        return true
    
    # 2) 不可达:找全图离 goal 最近的、跟 start 同 global 的 navcell
    var fallback := _find_nearest_with_global(goal.center, start_global, pass_mask)
    if fallback == Vector2i(-1, -1):
        return false
    goal.type = RtsPathGoal.Type.POINT
    goal.center = _navcell_center(fallback)
    goal.hw = 0.0
    goal.hh = 0.0
    return false
```

**M4b.3** — Wire 进 placement / move command — **DEFERRED 到 M5(2026-05-04)**

⚠️ **冲突点**:spec 假设 wire 入口 = "玩家右键点目标" 的 click 坐标(地图 free space 的点);AI attack-move(`rts_ai_strategy.gd` 决策)的 target = enemy actor 中心 — 很可能落在 building footprint impassable 区。wire 进 `rts_move_units_command.gd` 后:canonicalize 把 enemy actor 中心 → 拽到 ct 旁外缘 navcell → unit 走到那站住 → ct 在 attack range 外 → ai_vs_player smoke unit-to-ct attacks 7 → 0(unit 永远打不到 ct)。

⚠️ **M5 解锁条件**:M5 LongPathfinder 落地时:
1. canonicalize 语义改成"总是 mutate 到 navcell 中心"(M4b 阶段 reachable → no-op 临时方案被 M5 替代)
2. AI attack-move 走单独路径(直接传 enemy actor 中心,不过 canonicalize)— 跟玩家 click move 区分入口
3. 重新 wire 时验 `smoke_ai_vs_player_full_match` unit-to-ct attacks ≥ baseline 阈值

**临时回避**(M4b 阶段):wire revert,baseline 保 byte-identical;canonicalize 仅 smoke 内部测试调用,不进 production code。

**M4b.4** — Smoke

`smoke_hierarchical_unreachable`:
- 设置:单位 (100, 100),建筑挡住 (200..300, 100..200) 
- move command 到 (250, 150) (建筑内部)
- 验证:goal canonicalized 到建筑外缘最近 navcell;单位走到那里停;不死循环

### M4c — Dirty 增量更新 (1 周)

**M4c.1** — `update(grid, dirty)` 实现

```gdscript
func update(grid: RtsNavcellGrid, dirty: PackedByteArray) -> void:
    # 找出 dirty 涉及的 chunks
    var dirty_chunks: Dictionary = {}    # (ci, cj) → true
    for k in range(dirty.size()):
        if dirty[k] != 1:
            continue
        var i: int = k % grid.width()
        var j: int = k / grid.width()
        var ci: int = i / RtsHierarchicalChunk.CHUNK_SIZE
        var cj: int = j / RtsHierarchicalChunk.CHUNK_SIZE
        dirty_chunks[Vector2i(ci, cj)] = true
        # 邻 chunk 也要更新 edges (跨 chunk edge 受影响)
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var nei: Vector2i = Vector2i(ci, cj) + d
            if nei.x >= 0 and nei.x < _chunks_w and nei.y >= 0 and nei.y < _chunks_h:
                dirty_chunks[nei] = true
    
    for cls_mask in _chunks:
        # 1) 重 flood-fill dirty chunks
        for chunk_xy in dirty_chunks:
            var ch := _build_chunk(grid, chunk_xy.x, chunk_xy.y, cls_mask)
            _chunks[cls_mask][chunk_xy.y * _chunks_w + chunk_xy.x] = ch
        # 2) 重建 dirty chunks 涉及的 edges
        # (移除原 edges, 重建跨 chunk edges)
        _rebuild_edges_for_chunks(cls_mask, dirty_chunks)
        # 3) 重算 GlobalRegionID (整 graph,以为 dirty 可能合并/分裂分量)
        _compute_global_regions(cls_mask)
```

**M4c.2** — Procedure tick 接 update (⚠️ R5 P1 #2 dirty snapshot 协议)

⚠️ **R5 P1 #2**: rasterize 不再 clear dirty,update 仍能拿到 dirty 集合;末端统一清。

```gdscript
# RtsWorld.tick step 5-7:
func tick(delta: float) -> void:
    ...   # step 1-4 (commands / motion / push / activity)
    
    # step 5: rasterize (rasterize 内部不 clear, R5 P1 #2)
    var did_rasterize: bool = obstruction_manager.rasterize_if_dirty(_navcell_grid, _passability_registry)
    
    # step 6: hierarchical update — 拿同一个 dirty 集合 (snapshot 已经在 grid 里, 不变)
    if did_rasterize:
        hierarchical_pathfinder.update(_navcell_grid, _navcell_grid._dirtiness)
    
    # step 7: 末端统一清 + 落事件 (R5 P2 真实 API)
    _navcell_grid.clear_dirty()
    GameWorld.event_collector.flush()    # 真实 API: event_collector, 不是 EventProcessor
```

**dirty 一致性 invariant** (R5 P1 #2 落地):
- step 5 期间 grid._dirtiness 保持不变(rasterize 只读)
- step 6 期间 grid._dirtiness 仍保持不变(update 只读)
- step 7 末端 `clear_dirty()` 之后下一 tick 起 dirty 集合空(干净起点)
- 任何路径在 step 5-6 中间清 dirty = bug → M4c smoke 验证 update 拿到的 dirty 集合**等于** rasterize 看到的

**M4c.3** — Smoke

`smoke_hierarchical_dirty_update`:
- recompute 一次
- add building → tick → 验证 hierarchical 自动 update
- remove building → tick → 验证 region 重新合并;原本被分隔的两 region 现在同 global
- 比 full recompute 快(perf 对比)

---

## 3. 验收准则 (M4 总)

### AC1 — RtsRegionId helper packed int64 工作 🔒 pending
- pack(ci, cj, r) / unpack 可逆
- 0 = invalid 与 (ci=0, cj=0, r=N) 区分(`is_invalid` 只检 r)

### AC2 — M4a recompute 正确 🔒 pending
- 单 chunk 全可通 → 1 region
- 单 chunk 一半 impassable → 2 regions(若两半连通)或更多
- 跨 chunk edges 完整建立

### AC3 — M4b is_goal_reachable / make_goal_reachable 正确 🔒 pending
- 可达 goal 返回 true,canonicalize 到区内最近
- 不可达 goal 返回 false,canonicalize 到全图最近 reachable

### AC4 — M4c dirty 增量正确 🔒 pending
- add / remove building → 受影响 chunks 重 flood,GlobalRegion 重算
- 增量比 full recompute 快 ≥3×(perf)

### AC5 — 体验点 ✋2 通过 🔒 pending
- demo_rts_frontend 玩家右键点不可达点 → 单位走到最近可达 navcell,不死循环

### AC6 — 3 smoke PASS + Validation 全套 🔒 pending
- 14 项 + LGF + replay seed=42 deep-equal
- baseline CSV diff vs M3:**新字段 region_id / global_region_id 从 -1 变实填**(预期变化,接受新 baseline)

### AC7 — Perf 增长 ≤ 50% (M4a) / +200% 不算超(M4c) 🔒 pending
- M4a recompute 在启动时一次 ~50-200 ms 接受
- M4c update 每 tick 通常空 op;dirty 时 ≤ 5 ms

### AC8 — Determinism §12.2 严格遵守 🔒 pending
- chunk flood-fill 起点字典序 / Region ID 单调递增 / Edge 注册按 packed RID 升序
- GlobalRegion BFS 起点字典序 / GlobalID 单调递增

---

## 4. 关键决策

### J1 — Recompute vs Update 调度策略

- **A. 启动时 recompute,运行时 update(dirty)**(M4a + M4c) — Recommended  
- B. 每 tick 全 recompute(简单但 perf 差)

> default A;0 A.D. 风格;recompute 一次性贵,update 摊销小。

### J2 — Per-class 独立 chunks vs 共享

- **A. 独立**(每 class 一份 _chunks / _edges / _global_regions) — Recommended
- B. 共享 chunks(多 mask 同 chunk 内 region)

> default A;data-structures §4.4 已定义独立;可读性 + 调试方便;memory 代价 ≤ 2 MB / class @ 1024² grid。

### J3 — _navcell_in_goal 暴力扫 vs BFS

- **A. 暴力扫 goal 包围盒内所有 navcells** — Recommended
- B. BFS from start

> default A;goal 包围盒通常小(≤ 50×50 navcells);BFS 起点 / 终点维护复杂。

---

## 5. 子任务进度

- [x] M4a — Full Recompute (2026-05-04)
- [x] M4b — MakeGoalReachable (2026-05-04, M4b.3 wire DEFERRED 到 M5)
- [ ] M4-perf-gate — pending(决定 M4c 是否启动)
- [ ] M4c — Dirty 增量(perf-gate 触发才启动)
- [ ] ✋2 体验点 — DEFERRED 到 M5(依赖 M4b.3 wire 落地)

---

## 6. 残余风险

| # | 风险 | 缓解 |
|---|---|---|
| R1 | M4c 增量更新 GlobalRegion 错算(分量合并/分裂未正确处理) | 每个 update 末 invariant check:同 GlobalID 必同 connected component;实际项目用 sanity smoke 跑 100 次 add/remove cycle 验证 |
| R2 | replay 漂:edges Dictionary 迭代序 | 所有 edges 操作按 packed RID 升序 sort,不依赖 Dictionary 内部 |
| R3 | _build_chunk flood_fill 起点顺序 | 严格 (lj, li) 字典序 — Determinism §12.2 |
| R4 | make_goal_reachable canonicalize 后 LongPath 仍找不到 | M4b smoke 必须验证 "canonicalize 后 LongPath PASS" 闭环;若 LongPath 仍失败,说明 hierarchical edges 注册有 bug |
| R5 | M4c update 触发频率(每 tick 都跑会贵) | rasterize_if_dirty 已确保只 dirty 时跑;若 1 tick 多 building add/remove 合批 |

---

## 7. 决策来源

- 数据结构: data-structures §4 (含 codex P1 #1 packed int64)
- API: interfaces §3
- 0 A.D. 对照: helpers/HierarchicalPathfinder.h/cpp(`Update(grid, dirtinessGrid)`)
- M3 末态 baseline

---

## 8. 完成后下一步 (M5 启动)

M4 完成 → M5 LongPathfinder 重写(在新 navcell grid 上跑朴素 A*)。

详见 [`M5-long-pathfinder.md`](M5-long-pathfinder.md)。
