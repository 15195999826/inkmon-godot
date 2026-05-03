# M5 — LongPathfinder 重写

> 父 plan: [`../README.md`](../README.md)
> 数据结构: [`../data-structures.md`](../data-structures.md) §6
> API: [`../interfaces.md`](../interfaces.md) §4
>
> Status: 🔒 pending(M4 完成后启动)
> 依赖: M4 (hierarchical 提供 make_goal_reachable canonicalize)
> 阻塞: M6 (VertexPath 在 LongPath 输出基础上做短程绕避)

---

## 0. 目标

引入 `RtsLongPathfinder` — 朴素 A* on `RtsNavcellGrid`,替换现有 `GridPathfinding.find_path`。

**D6 决策(有意简化 0 A.D.)**:0 A.D. 真实实现是 JPS+JumpPointCache,我们用朴素 A*。规模 100 单位 / 1024×1024 grid 够用,JPS 工程量大收益小。

**关键点**(全 deterministic,§12.1):
- A* heap key = 5 元组 `(f, h, i, j, insertion_seq)`,严格字典序比较
- PathCost 用整数(`hv * 65536 + diag * 92682`),不引入浮点
- WaypointPath 反向存储(`back()` = 下一目标)
- M5 末**移除 RtsBattleGrid facade**(§interfaces.md §11),全部调用方迁到直接 NavcellGrid + LongPathfinder

---

## 1. Scope

### 1.1 必做

- 引入 `RtsLongPathRequest` data class
- 引入 `RtsWaypointPath` reverse-stored container
- 引入 `RtsLongPathfinder.compute_path_immediate(start, goal, pass_mask)` 朴素 A*
- A* heap 用 SortedArray + 5 元组 binary search insertion(GDScript 没 priority queue)
- 整数 PathCost (`COST_HV = 65536` / `COST_DIAG = 92682`)
- 接 `RtsPathfinderFacade.compute_path_immediate` 入口
- 替换 RtsActivity / 玩家 move command 内 `GridPathfinding.find_path` 调用 → `facade.compute_path_immediate`
- **M5 末**移除 `RtsBattleGrid` facade(scope 见 §1.2)
- 加新 smoke `smoke_long_pathfinder_basic.tscn` + `smoke_long_pathfinder_unreachable.tscn`

### 1.2 RtsBattleGrid facade 移除范围

按 [interfaces §11](../interfaces.md#11-兼容性-现有-rtsbattlegrid-facade-退役计划):
- 删除 `_placement_map`(已在 M2 转交 ObstructionManager)
- 删除 `place_building` / `remove_building` 公开 API(已 deprecated)
- 删除 `is_blocking(coord)` → 调用方改 `navcell_grid.is_passable(i, j, default_mask) == false`
- 删除 `world_to_coord` → 调用方改 `navcell_grid.nearest_navcell(world)`
- **保留** `cell_size = 32` 常量(暂作 facade 末期),整体类删除时 `RtsNavcellGrid.NAVCELL_SIZE_PX` 是唯一来源

### 1.3 不做

| 不做 | 原因 |
|---|---|
| JPS + JumpPointCache | D6 决策 |
| Async path computation | 同步够用,M7 末看是否需要 |
| Path smoothing(后处理直线化) | M6 vertex pathfinder 自然给出更平滑路径 |
| Multi-goal A* | 单 goal 够用 |

### 1.4 文件清单

#### 新建

```
addons/.../logic/pathfinding/
├── rts_long_path_request.gd
├── rts_waypoint_path.gd
├── rts_long_pathfinder.gd
└── rts_pathfinder_facade.gd                ← 顶层 facade(M5 引入,M7 加更多 API)
```

#### 修改

```
addons/.../logic/
├── grid/rts_battle_grid.gd                  ← 移除 (空文件 / 或转 stub 等 M6 删)
├── grid/rts_grid_pathfinding.gd             ← 移除(替换为 RtsLongPathfinder)
├── activities/rts_activity_*.gd             ← 寻路调用走 facade
├── commands/rts_player_command_*.gd         ← move command 走 facade
└── core/rts_auto_battle_procedure.gd        ← 启动初始化 facade
```

#### 新建 (smoke)

```
addons/.../tests/battle/
├── smoke_long_pathfinder_basic.tscn          ← 简单 A→B 寻路
├── smoke_long_pathfinder_unreachable.tscn    ← 不可达兜底(配合 M4 make_goal_reachable)
└── smoke_long_pathfinder_determinism.tscn    ← 同 seed 路径 byte-identical
```

---

## 2. 子任务

### M5.1 — Data classes (RtsLongPathRequest / RtsWaypointPath)

```gdscript
class_name RtsLongPathRequest
extends RefCounted

var ticket: int = 0
var start: Vector2
var goal: RtsPathGoal
var pass_mask: int
var notify_entity: String = ""

# ---

class_name RtsWaypointPath
extends RefCounted

var waypoints: PackedVector2Array

func _init() -> void:
    waypoints = PackedVector2Array()

func size() -> int:
    return waypoints.size()

func is_empty() -> bool:
    return waypoints.is_empty()

func back() -> Vector2:
    Log.assert_crash(not waypoints.is_empty(), "back() on empty path")
    return waypoints[waypoints.size() - 1]

func pop_back() -> Vector2:
    Log.assert_crash(not waypoints.is_empty(), "pop_back() on empty path")
    var v: Vector2 = waypoints[waypoints.size() - 1]
    waypoints.remove_at(waypoints.size() - 1)
    return v

func push_back(v: Vector2) -> void:
    waypoints.append(v)

func clear() -> void:
    waypoints = PackedVector2Array()
```

### M5.2 — RtsLongPathfinder 朴素 A*

```gdscript
class_name RtsLongPathfinder
extends RefCounted

const COST_HV: int = 65536
const COST_DIAG: int = 92682

var _grid: RtsNavcellGrid

func _init(grid: RtsNavcellGrid) -> void:
    _grid = grid

func compute_path_immediate(start: Vector2, goal: RtsPathGoal, pass_mask: int) -> RtsWaypointPath:
    Log.assert_crash(goal.type == RtsPathGoal.Type.POINT, "LongPath requires POINT goal (use make_goal_reachable to canonicalize)")
    
    var start_cell := _grid.nearest_navcell(start)
    var goal_cell := _grid.nearest_navcell(goal.center)
    
    if start_cell == goal_cell:
        var path := RtsWaypointPath.new()
        path.push_back(goal.center)
        return path
    
    return _astar(start_cell, goal_cell, pass_mask)

func _astar(start: Vector2i, goal: Vector2i, pass_mask: int) -> RtsWaypointPath:
    # Open list: SortedArray of [(f, h, i, j, seq, parent_idx)]
    # 实际实现用平行 PackedInt32Array 存 (i, j, parent_idx) 节省 GC
    var open_keys: Array = []     # 5 元组 [(f, h, i, j, seq)]
    var open_idx: Array[int] = [] # 跟 open_keys 同长度,存 parent_idx in flat array
    var came_from: Dictionary = {}    # packed_cell → parent_packed_cell
    var g_score: Dictionary = {}      # packed_cell → int g
    var closed: Dictionary = {}       # packed_cell → true
    var insertion_seq: int = 0
    
    var start_pack := _pack_cell(start)
    var goal_pack := _pack_cell(goal)
    g_score[start_pack] = 0
    var h0 := _octile(start, goal)
    open_keys.append([h0, h0, start.x, start.y, insertion_seq])
    insertion_seq += 1
    
    while not open_keys.is_empty():
        var key: Array = open_keys[0]
        open_keys.remove_at(0)
        var cur := Vector2i(key[2], key[3])
        var cur_pack := _pack_cell(cur)
        if closed.has(cur_pack):
            continue
        closed[cur_pack] = true
        
        if cur == goal:
            return _reconstruct(came_from, start_pack, goal_pack)
        
        # 8 邻居 (4 HV + 4 diag),deterministic 顺序
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
                  Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
            var nb := cur + d
            if nb.x < 0 or nb.x >= _grid.width() or nb.y < 0 or nb.y >= _grid.height():
                continue
            if not _grid.is_passable(nb.x, nb.y, pass_mask):
                continue
            var nb_pack := _pack_cell(nb)
            if closed.has(nb_pack):
                continue
            var step_cost: int
            if d.x == 0 or d.y == 0:
                step_cost = COST_HV
            else:
                step_cost = COST_DIAG
            var new_g: int = g_score[cur_pack] + step_cost
            if g_score.has(nb_pack) and new_g >= g_score[nb_pack]:
                continue
            g_score[nb_pack] = new_g
            came_from[nb_pack] = cur_pack
            var h := _octile(nb, goal)
            var f := new_g + h
            _heap_insert(open_keys, [f, h, nb.x, nb.y, insertion_seq])
            insertion_seq += 1
    
    # 找不到路径,返回空
    return RtsWaypointPath.new()

func _heap_insert(arr: Array, key: Array) -> void:
    # Binary search insertion 保持 ascending lex order
    var lo := 0
    var hi := arr.size()
    while lo < hi:
        var mid := (lo + hi) / 2
        if _key_less(arr[mid], key):
            lo = mid + 1
        else:
            hi = mid
    arr.insert(lo, key)

static func _key_less(a: Array, b: Array) -> bool:
    # Lex compare 5 元组
    for i in range(5):
        if a[i] < b[i]: return true
        if a[i] > b[i]: return false
    return false

func _octile(a: Vector2i, b: Vector2i) -> int:
    var di: int = absi(b.x - a.x)
    var dj: int = absi(b.y - a.y)
    var diag: int = mini(di, dj)
    var hv: int = maxi(di, dj) - diag
    return hv * COST_HV + diag * COST_DIAG

func _pack_cell(v: Vector2i) -> int:
    return v.x * 65536 + v.y    # 16-bit each, 1024x1024 grid 够用

func _reconstruct(came_from: Dictionary, start_pack: int, goal_pack: int) -> RtsWaypointPath:
    var path := RtsWaypointPath.new()
    var cur := goal_pack
    var trail: Array[int] = [cur]
    while cur != start_pack:
        if not came_from.has(cur):
            return RtsWaypointPath.new()    # 重建失败
        cur = came_from[cur]
        trail.append(cur)
    # trail 现在是 goal → start 顺序 (我们要反向存储 so 直接 push: back() = goal)
    # 实际 0 A.D. WaypointPath: back() = next target = path 中靠近 start 的那个 (注意!)
    # 等等: 反向存储 = waypoints[size-1] 是下一步. 我们刚出 A*, 下一步应该是 start 的下一个邻居 (trail.size()-2 索引).
    # 所以填法: waypoints[0] = goal, waypoints[size-1] = next-after-start.
    # trail 顺序 = [goal_pack, ..., start_pack]; 反过来 push: 先 push start_pack (waypoints[0]) ... 不对.
    # 重新:
    #   trail = [goal, ..., start]  (size N)
    #   waypoints[0] = goal      (终点 留底)
    #   waypoints[1] = goal-1
    #   ...
    #   waypoints[N-1] = start+1 (next step from start, back() 取它)
    # 所以从 trail 倒着把 trail[0]..trail[N-2] push 进去 (跳过 start_pack)
    for k in range(trail.size() - 1):     # trail[N-1] = start, 跳过
        var pc := trail[k]
        var x := pc / 65536
        var y := pc % 65536
        path.push_back(_grid.navcell_center_world(x, y))
    # 现在 path.waypoints[0] = goal cell center, path.waypoints[size-1] = next step
    return path
```

### M5.3 — RtsPathfinderFacade 顶层 (M5 雏形)

```gdscript
class_name RtsPathfinderFacade
extends RefCounted

var _hierarchical: RtsHierarchicalPathfinder
var _long: RtsLongPathfinder
var _grid: RtsNavcellGrid
var _obstr_mgr: RtsObstructionManager
var _classes: RtsPassabilityClassRegistry
# var _vertex: RtsVertexPathfinder      # M6 加

func _init(grid, obstr_mgr, classes, hierarchical, long_pf) -> void:
    _grid = grid
    _obstr_mgr = obstr_mgr
    _classes = classes
    _hierarchical = hierarchical
    _long = long_pf

func compute_path_immediate(start: Vector2, goal: RtsPathGoal, pass_mask: int) -> RtsWaypointPath:
    # 1) Canonicalize goal (M4)
    var start_cell := _grid.nearest_navcell(start)
    _hierarchical.make_goal_reachable(start_cell.x, start_cell.y, goal, pass_mask)
    # 2) A* (M5)
    return _long.compute_path_immediate(start, goal, pass_mask)

func is_goal_reachable(start: Vector2, goal: RtsPathGoal, pass_mask: int) -> bool:
    var start_cell := _grid.nearest_navcell(start)
    return _hierarchical.is_goal_reachable(start_cell.x, start_cell.y, goal, pass_mask)

func make_goal_reachable(start: Vector2, goal: RtsPathGoal, pass_mask: int) -> bool:
    var start_cell := _grid.nearest_navcell(start)
    return _hierarchical.make_goal_reachable(start_cell.x, start_cell.y, goal, pass_mask)

func check_movement(filter, a: Vector2, b: Vector2, _clearance: float, pass_mask: int) -> bool:
    return RtsLineOfSight.check_line_movement(_grid, a, b, pass_mask)

func recompute_grid(classes) -> void:
    _hierarchical.recompute(_grid, classes)

func tick(_delta: float) -> void:
    if _grid_has_dirty():
        _obstr_mgr.rasterize_if_dirty(_grid, _classes)
        _hierarchical.update(_grid, _grid._dirtiness)
```

### M5.4 — Activity / move command 迁到 facade

```gdscript
# 现有 (M4 之前):
var path: PackedVector2Array = GridPathfinding.find_path(grid, start, goal_pos)

# M5 改:
var goal := RtsPathGoal.new()
goal.type = RtsPathGoal.Type.POINT
goal.center = goal_pos
var path: RtsWaypointPath = facade.compute_path_immediate(start, goal, default_mask)
# path.back() = next target; consume by pop_back when reached
```

### M5.5 — RtsBattleGrid facade 移除

- `place_building` / `remove_building` / `_placement_map`:删除(M2 已转 ObstructionManager)
- `is_blocking`:删除,调用方改 `navcell_grid.is_passable(... default_mask) == false`
- `world_to_coord`:删除,调用方改 `navcell_grid.nearest_navcell()`
- 整 `RtsBattleGrid` 类:M5 末删除文件;`rts_world.rts_grid` 字段改成 `rts_world.navcell_grid: RtsNavcellGrid`(rename + 调用方更新)

### M5.6 — Smokes + Validation

`smoke_long_pathfinder_basic`:
- 创空 grid 100×100,start (50, 50) → goal (90, 90)
- A* 出路径,验证 waypoints.size() ≈ 40(对角斜线)
- back() 是 next step (start 旁边 cell)

`smoke_long_pathfinder_unreachable`:
- grid 100×100,start (10, 10),goal (90, 90),中间一道墙隔死
- facade.compute_path_immediate → make_goal_reachable canonicalize → goal 改到墙左侧最近 reachable
- 单位走到那里,abort

`smoke_long_pathfinder_determinism`:
- 同 seed 跑两次完整 demo → trace CSV byte-identical

跑 14 + LGF + replay。

**关键风险点**:旧 `GridPathfinding.find_path` 输出的路径 与新 RtsLongPathfinder **可能不完全一致**(算法实现差异)→ baseline CSV trace `final_tx/ty` 路径轨迹会变 → **接受新 baseline**(M5 是 LongPath 重写,trace 漂是预期)。但 replay seed=42 必须仍 deep-equal(determinism contract 保证)。

---

## 3. 验收准则

### AC1 — RtsLongPathRequest / RtsWaypointPath 落地 🔒
### AC2 — A* heap 5 元组比较正确 🔒
- 同输入跑两次 → 输出 byte-identical
### AC3 — Octile heuristic + integer cost 🔒
- 朴素水平 / 对角 cost 比例 = 1 : ≈√2
### AC4 — Facade 顶层入口工作 🔒
- compute_path_immediate(start, goal) 返回非空(可达 case)
- 返回空 WaypointPath(不可达 + canonicalize 后仍找不到 case,极罕见)
### AC5 — Activity / move command 迁完 🔒
- grep "GridPathfinding.find_path" 调用 0 处(全部走 facade)
### AC6 — RtsBattleGrid facade 删除 🔒
- 文件不存在;调用方迁完
### AC7 — 3 smokes PASS + Validation 🔒
- 14 项 + LGF + replay seed=42 deep-equal
- baseline CSV vs M4:**LongPath 路径轨迹变化**(预期),**replay 不变**(determinism)
### AC8 — Perf ≤ 50% 🔒
- A* 在 1024² grid 100 单位 30 Hz: tick_p99 ≤ 30 ms;若超阈值视情考虑 SortedArray → 真 binary heap 优化

---

## 4. 关键决策

### K1 — Heap 实现:SortedArray vs 真 binary heap

- **A. SortedArray + binary search insert**(GDScript Array.insert + binary_search,简单但 O(N) insert) — Recommended start
- B. 真 binary heap(自己用 PackedInt32Array 模拟,O(log N) insert)

> default A;100 单位 × 平均 path length 50 navcells = 5000 ops/path, GDScript 撑得住;若 perf 测出 spike 再换 B。

### K2 — `_pack_cell` 选 `x*65536 + y` vs `y*W + x`?

- **A. `x * 65536 + y`**(16 bit per coord,固定 packing) — Recommended
- B. `y * grid.width() + x`(更紧但依赖 grid 尺寸)

> default A;固定 packing 不依赖 grid 尺寸,跨 grid 大小 reuse 简单。

---

## 5. 子任务进度

- [ ] M5.1 — Data classes
- [ ] M5.2 — RtsLongPathfinder A*
- [ ] M5.3 — Facade 雏形
- [ ] M5.4 — Activity / command 迁移
- [ ] M5.5 — RtsBattleGrid facade 移除
- [ ] M5.6 — Smokes + Validation

---

## 6. 残余风险

| # | 风险 | 缓解 |
|---|---|---|
| R1 | 替换核心算法时 replay seed=42 漂 | M5 启动前先在 master 跑 baseline replay;漂时立即 stop runner,从 §12.1 contract 检查 |
| R2 | RtsBattleGrid 调用方漏改 | 删除前 grep 完整列表 (`grep_callers`);删除后跑 14 项 smoke 自然暴露 |
| R3 | A* 大 grid (1024²) 全图搜索 perf 不够 | M5 末 perf 监控;若 ≥500 ms 单 path,考虑 jump skip 优化 (D6 一开始定的是简化,但留改) |
| R4 | Reconstruct 路径方向反 → 单位往反方向走 | M5.6 smoke 包含"start (10,10) → goal (90,90)" 走出方向断言 |
| R5 | M5 移除 RtsBattleGrid 时若子项目 (HexCoord) 仍依赖,断 | M5 启动前 grep `RtsBattleGrid` / `cell_size` / `world_to_coord` 调用,确认全部走 facade 或新 NavcellGrid |

---

## 7. 决策来源

- 数据结构: data-structures §6 (含 codex P1 #4 整数 PathCost)
- 0 A.D. 对照: helpers/LongPathfinder.h/cpp (有意简化,见 D6)
- M4 末态 baseline

---

## 8. 完成后下一步 (M6 启动)

M5 完成 → M6 VertexPathfinder(短程绕避,可视图 A*)。

详见 [`M6-vertex-pathfinder.md`](M6-vertex-pathfinder.md)。
