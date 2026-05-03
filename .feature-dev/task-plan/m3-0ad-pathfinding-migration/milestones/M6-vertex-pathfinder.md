# M6 — VertexPathfinder (短程绕避 + 可视图 A*)

> 父 plan: [`../README.md`](../README.md)
> 数据结构: [`../data-structures.md`](../data-structures.md) §7 (含 codex R1 修正 7+2 细节)
> API: [`../interfaces.md`](../interfaces.md) §5
>
> Status: 🔒 pending(M5 完成后启动)
> 依赖: M5 (LongPath / Facade 已工作)
> 阻塞: M7 (UnitMotion 双轨整合需要 short pathfinder 工作)
> ✋ 用户体验点 3: M6 完成时(真正的"贴墙绕角不穿建筑"体感)

---

## 0. 目标

实现 0 A.D. 风格 `VertexPathfinder` — 在小范围内构建 visibility graph + A*,任意角度路径(不再受 navcell 32 px 粒度限制)。

**Bug 1 完整修复**:M0 cells 一致性 + M3 clearance 外扩 + M6 vertex 任意角度 = 单位贴墙绕角自然,不穿建筑 sprite。

**M6 拆 3 个 sub-phase**(codex R1 反馈,最难一层):
- **M6a**: Static OBB prototype(独立 scene 验证几何)
- **M6b**: Virtual goal + domain bounds + terrain edges(完整搜索框 + goal 处理)
- **M6c**: Dynamic units + group filter(单位作为方形代理 + 同 group 跳过)

---

## 1. Scope

### 1.1 必做(M6a + M6b + M6c)

7+2 细节按 [data-structures §7.2](../data-structures.md#72-rtsvertexpathfinder-核心算法m6) 全部实现:

1. **Search bounds toward goal shift** — 搜索框朝 goal 偏移
2. **Range boundary edges** — 搜索框 4 条边作 "墙"
3. **Virtual goal vertex** — non-POINT goal 在搜索框内找最近可达边界点
4. **Terrain edges** — passable / impassable 邻居对 中点作 vertex
5. **Lazy visibility** — A* expand 时再测可见,不预建全图
6. **Best-so-far fallback** — 找不到时返回离 goal 最近的扩展节点路径
7. **Moving unit square proxy** — 圆形 obstruction 在 vertex graph 中近似 AABB(不切线)
8. **Group filter** — 同 control_group obstruction 跳过
9. **Tie-break** — vertex 候选生成顺序按 (obstruction.tag, corner_index);A* 5 元组 deterministic key

### 1.2 不做

| 不做 | 原因 |
|---|---|
| 完整 0 A.D. 优化(JPS-style short path / VertexPathfinder caching) | 100 单位 × 30Hz 应可承受;M8 末若 perf 不够再优化 |
| Multi-hop search(跨多 search box 自动接龙) | 通过 LongPath + ShortPath 双层组合自然实现 |
| Curve smoothing(贝塞尔后处理) | 直线段够用 |

### 1.3 文件清单

#### 新建

```
addons/.../logic/pathfinding/
├── rts_short_path_request.gd
├── rts_vertex_pathfinder.gd                  ← 核心(~800 行 GDScript)
├── rts_visibility_graph.gd                   ← 内部 visibility graph helper
└── rts_line_of_sight.gd                      ← 线段 vs shapes / grid raycast(M5 已建?这里完善)
```

#### 修改

```
addons/.../logic/pathfinding/
└── rts_pathfinder_facade.gd                  ← 加 compute_short_path_immediate
```

#### 新建 (smoke)

```
addons/.../tests/battle/
├── smoke_vertex_static_obb.tscn               ← M6a: static OBB
├── smoke_vertex_virtual_goal.tscn             ← M6b: virtual goal + terrain
├── smoke_vertex_corner_walking.tscn           ← M6c: 真正贴墙绕角
└── smoke_vertex_group_filter.tscn             ← M6c: group filter

addons/.../tests/prototype/                    ← M6a 启动前置(prototype scene)
└── proto_vertex_obb.tscn                      ← 独立 prototype 验证算法
```

---

## 2. 子任务

### M6a — Static OBB Prototype (1.5 周)

**M6a.1 — Prototype scene (独立验证)**

新建 `tests/prototype/proto_vertex_obb.tscn`:
- 单 scene,独立于 RTS battle procedure
- 手动放 3-5 个 OBB barracks
- 单位 start (50, 50) → goal (500, 500)
- VertexPathfinder 输出 path 画在屏幕上(可视调试)
- 不进 production,只验算法正确性

**M6a.2 — RtsShortPathRequest data class**

按 [data-structures §7.1](../data-structures.md#71-rtsshortpathrequest)。

**M6a.3 — VertexPathfinder 静态 OBB only 版本**

```gdscript
class_name RtsVertexPathfinder
extends RefCounted

const SHORT_PATH_MAX_RANGE: float = 1792.0    # 56 navcells × 32 px

var _grid: RtsNavcellGrid

func _init(grid: RtsNavcellGrid) -> void:
    _grid = grid

func compute_short_path_immediate(req: RtsShortPathRequest, obstr_mgr: RtsObstructionManager) -> RtsWaypointPath:
    # M6a 阶段: 只处理 static OBB obstructions, ignore moving units
    
    # 1) Search bounds toward goal shift (细节 #1)
    var bounds: Rect2 = _compute_search_bounds(req)
    
    # 2) 收集范围内 obstructions
    var nearby: Array = obstr_mgr.get_obstructions_in_range(bounds.get_center(), bounds.size.length() / 2)
    var static_only: Array = []
    for s in nearby:
        if s is RtsObstructionShapeStatic:
            static_only.append(s)
    # tags 已升序 (§12.4)
    
    # 3) 收集 vertex 候选(OBB 4 角 + buffer)
    var vertices: Array[Vector2] = [req.start]    # index 0 = start
    var goal_index: int = -1
    
    # virtual goal: M6b 才完整,M6a 简化为 goal.center 直接做 vertex
    var goal_pos: Vector2 = req.goal.center
    vertices.append(goal_pos)
    goal_index = vertices.size() - 1
    
    # OBB corners(按 obstruction.tag, corner_index 字典序 — Determinism §12.3)
    for obstr in static_only:
        var corners: Array[Vector2] = obstr.get_corners()
        for c in corners:
            # 加 buffer = clearance 让 vertex 在 OBB 外面 clearance 距离
            var dir := (c - obstr.center).normalized()
            vertices.append(c + dir * req.clearance)
    
    # 4) Range boundary edges (细节 #2): 搜索框 4 角作 vertex
    var br := bounds
    vertices.append(Vector2(br.position.x, br.position.y))
    vertices.append(Vector2(br.position.x + br.size.x, br.position.y))
    vertices.append(Vector2(br.position.x, br.position.y + br.size.y))
    vertices.append(br.position + br.size)
    
    # 5) Lazy visibility A*
    var path: RtsWaypointPath = _astar_lazy_visibility(vertices, 0, goal_index, static_only, req.clearance)
    
    # 6) Best-so-far fallback (细节 #6) - M6a 简化先返回结果, M6b 加完整版
    if path.is_empty():
        # 找不到 path: 简化返回 only start (M6b 加 best-so-far)
        return path
    
    return path

func _compute_search_bounds(req: RtsShortPathRequest) -> Rect2:
    # 中心 = (start, goal) 中点偏向 goal 1/3
    var mid: Vector2 = req.start.lerp(req.goal.center, 0.5)
    var toward_goal: Vector2 = req.goal.center - req.start
    var biased_center: Vector2 = mid + toward_goal.normalized() * minf(toward_goal.length() / 6.0, req.range / 4.0)
    var size: Vector2 = Vector2(req.range, req.range)
    return Rect2(biased_center - size / 2, size)

func _astar_lazy_visibility(vertices: Array[Vector2], start_idx: int, goal_idx: int, obstacles: Array, clearance: float) -> RtsWaypointPath:
    # 5 元组 (f, h, vx_int, vy_int, seq) heap key — Determinism §12.1
    var open: Array = []
    var came_from: Dictionary = {}    # idx → idx
    var g_score: Dictionary = {idx: float}
    var closed: Dictionary = {}
    var insertion_seq: int = 0
    
    g_score[start_idx] = 0.0
    var h0: float = vertices[start_idx].distance_to(vertices[goal_idx])
    open.append([h0, h0, int(round(vertices[start_idx].x * 10)), int(round(vertices[start_idx].y * 10)), insertion_seq, start_idx])
    insertion_seq += 1
    
    while not open.is_empty():
        var key: Array = open[0]
        open.remove_at(0)
        var cur_idx: int = key[5]
        if closed.has(cur_idx):
            continue
        closed[cur_idx] = true
        
        if cur_idx == goal_idx:
            return _reconstruct(vertices, came_from, start_idx, goal_idx)
        
        # Expand: 测试 cur 跟所有未访问 vertex 的可见性
        for nb_idx in range(vertices.size()):
            if closed.has(nb_idx) or nb_idx == cur_idx:
                continue
            # Lazy visibility (细节 #5): 这里才测 segment_clear
            if not _segment_clear(vertices[cur_idx], vertices[nb_idx], obstacles, clearance):
                continue
            var new_g: float = g_score[cur_idx] + vertices[cur_idx].distance_to(vertices[nb_idx])
            if g_score.has(nb_idx) and new_g >= g_score[nb_idx]:
                continue
            g_score[nb_idx] = new_g
            came_from[nb_idx] = cur_idx
            var h: float = vertices[nb_idx].distance_to(vertices[goal_idx])
            var f: float = new_g + h
            _heap_insert(open, [f, h, int(round(vertices[nb_idx].x * 10)), int(round(vertices[nb_idx].y * 10)), insertion_seq, nb_idx])
            insertion_seq += 1
    
    return RtsWaypointPath.new()    # M6a 找不到 = 空; M6b 加 best-so-far

func _segment_clear(a: Vector2, b: Vector2, obstacles: Array, clearance: float) -> bool:
    return RtsLineOfSight.segment_clear(a, b, obstacles, clearance)

func _reconstruct(vertices, came_from, start_idx, goal_idx) -> RtsWaypointPath:
    var path := RtsWaypointPath.new()
    var cur := goal_idx
    var trail: Array[int] = [cur]
    while cur != start_idx:
        if not came_from.has(cur):
            return RtsWaypointPath.new()
        cur = came_from[cur]
        trail.append(cur)
    # 同 LongPath: trail = [goal, ..., start]
    # waypoints[0] = goal, waypoints[size-1] = next step from start
    for k in range(trail.size() - 1):
        path.push_back(vertices[trail[k]])
    return path

func _heap_insert(arr: Array, key: Array) -> void:
    # Lex insert (跟 LongPath 同套路, 但比较 6 元组的前 5 项, 第 6 项是 vertex idx 不进 key)
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
    for i in range(5):
        if typeof(a[i]) == TYPE_FLOAT or typeof(a[i]) == TYPE_INT:
            if a[i] < b[i]: return true
            if a[i] > b[i]: return false
    return false
```

**M6a.4 — RtsLineOfSight.segment_clear**

```gdscript
class_name RtsLineOfSight
extends RefCounted

static func segment_clear(a: Vector2, b: Vector2, shapes: Array, clearance: float) -> bool:
    # 线段 a → b 距任何 shape ≥ clearance?
    for s in shapes:
        if s is RtsObstructionShapeStatic:
            if _segment_obb_dist(a, b, s) < clearance:
                return false
        elif s is RtsObstructionShapeUnit:
            if _segment_to_point_dist(a, b, s.center) < (s.clearance + clearance):
                return false
    return true

static func _segment_to_point_dist(a: Vector2, b: Vector2, p: Vector2) -> float:
    var ab := b - a
    var ap := p - a
    var t: float = clampf(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
    var nearest: Vector2 = a + ab * t
    return p.distance_to(nearest)

static func _segment_obb_dist(a: Vector2, b: Vector2, obb: RtsObstructionShapeStatic) -> float:
    # 线段到 OBB 最短距离 — 对每条 OBB 边求 segment-to-segment dist,取 min
    # 简化:把 OBB 转 local 坐标(以 obb.center 为原点 / u, v 为轴),线段也转 local,再用 AABB 距离
    var u: Vector2 = Vector2(cos(obb.rotation_rad), sin(obb.rotation_rad))
    var v: Vector2 = Vector2(-sin(obb.rotation_rad), cos(obb.rotation_rad))
    var la := Vector2((a - obb.center).dot(u), (a - obb.center).dot(v))
    var lb := Vector2((b - obb.center).dot(u), (b - obb.center).dot(v))
    var hw := obb.width / 2.0
    var hh := obb.height / 2.0
    # AABB 中心 (0,0),半宽 hw / hh — 测线段到 AABB 距离
    return _segment_to_aabb_dist(la, lb, hw, hh)

static func _segment_to_aabb_dist(a: Vector2, b: Vector2, hw: float, hh: float) -> float:
    # 实现用最简策略: t-stepping 100 个 sample 点,取 min 距离
    # M6a prototype 用此简化,M6b 末换成精确版 (Liang-Barsky 或 SAT-based)
    var min_dist: float = INF
    var steps: int = 100
    for k in range(steps + 1):
        var t: float = float(k) / steps
        var p: Vector2 = a.lerp(b, t)
        var dx: float = maxf(absf(p.x) - hw, 0.0)
        var dy: float = maxf(absf(p.y) - hh, 0.0)
        var d: float = sqrt(dx * dx + dy * dy)
        min_dist = minf(min_dist, d)
    return min_dist

static func check_line_movement(grid: RtsNavcellGrid, a: Vector2, b: Vector2, pass_mask: int) -> bool:
    # Bresenham raycast on grid
    var ca: Vector2i = grid.nearest_navcell(a)
    var cb: Vector2i = grid.nearest_navcell(b)
    var di: int = absi(cb.x - ca.x)
    var dj: int = absi(cb.y - ca.y)
    var sx: int = 1 if cb.x >= ca.x else -1
    var sy: int = 1 if cb.y >= ca.y else -1
    var err: int = di - dj
    var x: int = ca.x
    var y: int = ca.y
    while true:
        if not grid.is_passable(x, y, pass_mask):
            return false
        if x == cb.x and y == cb.y:
            break
        var e2: int = 2 * err
        if e2 > -dj:
            err -= dj
            x += sx
        if e2 < di:
            err += di
            y += sy
    return true
```

**M6a 完成标志**: prototype scene F6 看到正确路径绕开 OBB;`smoke_vertex_static_obb` PASS。

### M6b — Virtual Goal + Terrain Edges + Best-So-Far (1.5 周)

**M6b.1 — Virtual goal vertex (细节 #3)**

如果 goal 不是 POINT 而是 CIRCLE/SQUARE,在搜索框内找"goal 边界上离 start 最近的可达点"作 vertex,而不是 goal.center:

```gdscript
func _compute_virtual_goal(req: RtsShortPathRequest, bounds: Rect2) -> Vector2:
    if req.goal.type == RtsPathGoal.Type.POINT:
        return req.goal.center
    # 对 CIRCLE/SQUARE,在 bounds 内找 goal 边界上离 start 最近 + passable 的点
    return req.goal.nearest_point_on_goal(req.start)   # data-structures §5
```

**M6b.2 — Terrain edges (细节 #4)**

```gdscript
func _add_terrain_vertices(vertices: Array, bounds: Rect2, pass_mask: int) -> void:
    # 沿 search bounds 内 grid 边界,passable / impassable 邻居对的中点作 vertex
    var i0: int = int(floorf(bounds.position.x / RtsNavcellGrid.NAVCELL_SIZE_PX))
    var i1: int = int(floorf((bounds.position.x + bounds.size.x) / RtsNavcellGrid.NAVCELL_SIZE_PX))
    var j0: int = int(floorf(bounds.position.y / RtsNavcellGrid.NAVCELL_SIZE_PX))
    var j1: int = int(floorf((bounds.position.y + bounds.size.y) / RtsNavcellGrid.NAVCELL_SIZE_PX))
    for j in range(j0, j1):
        for i in range(i0, i1):
            var here_pass: bool = _grid.is_passable(i, j, pass_mask)
            # 检查与 (i+1, j) 边界
            if i + 1 < _grid.width():
                var east_pass: bool = _grid.is_passable(i + 1, j, pass_mask)
                if here_pass != east_pass:
                    var c: Vector2 = (_grid.navcell_center_world(i, j) + _grid.navcell_center_world(i + 1, j)) / 2.0
                    vertices.append(c)
            # 同样检查与 (i, j+1) 边界
            if j + 1 < _grid.height():
                var south_pass: bool = _grid.is_passable(i, j + 1, pass_mask)
                if here_pass != south_pass:
                    var c: Vector2 = (_grid.navcell_center_world(i, j) + _grid.navcell_center_world(i, j + 1)) / 2.0
                    vertices.append(c)
```

**M6b.3 — Best-so-far fallback (细节 #6)**

A* 跑完没找到 goal_idx 时,返回扩展过的 vertices 中**离 goal 最近**的那个的路径:

```gdscript
# 在 _astar_lazy_visibility 内, 每次 expand 节点更新 best_idx
var best_idx: int = start_idx
var best_dist: float = vertices[start_idx].distance_to(vertices[goal_idx])
# ... 在 expand 时:
var d: float = vertices[nb_idx].distance_to(vertices[goal_idx])
if d < best_dist:
    best_dist = d
    best_idx = nb_idx
# A* 末端没到 goal 时:
return _reconstruct(vertices, came_from, start_idx, best_idx)
```

**M6b.4 — Smoke**

`smoke_vertex_virtual_goal`:
- start (50, 50) + CIRCLE goal 中心 (500, 500) radius 80
- 路径终点应该在 CIRCLE 边缘,不是 center
- 验证:terrain edges 处理水陆交界(若有)

### M6c — Dynamic Units + Group Filter (1.5 周)

**M6c.1 — Moving unit square proxy (细节 #7)**

UnitShape (圆) 在 vertex graph 中 **不**用切线,转 AABB 4 角:

```gdscript
func _add_unit_proxies(vertices: Array, units: Array, clearance: float) -> void:
    # 圆形 obstruction 转方形(轴对齐 AABB),4 角作 vertex
    for u in units:
        var r := u.clearance + clearance    # buffer
        # AABB 4 角(轴对齐, 不旋转)
        vertices.append(u.center + Vector2(r, r))
        vertices.append(u.center + Vector2(r, -r))
        vertices.append(u.center + Vector2(-r, r))
        vertices.append(u.center + Vector2(-r, -r))
```

注意: visibility 测试时 unit 仍当圆处理(`_segment_to_point_dist` 模式),只有"作 vertex 候选"时用 AABB 4 角 — 这是 0 A.D. 的简化(避免几何 bug)。

**M6c.2 — Group filter (细节 #8)**

```gdscript
func _filter_obstructions(nearby: Array, control_group: String) -> Array:
    if control_group == "":
        return nearby
    var filtered: Array = []
    for s in nearby:
        if s.control_group == control_group or s.control_group_2 == control_group:
            continue   # 同 group 跳过
        filtered.append(s)
    return filtered
```

放在 obstruction 收集后立即 filter:

```gdscript
# compute_short_path_immediate 内:
var nearby: Array = obstr_mgr.get_obstructions_in_range(...)
nearby = _filter_obstructions(nearby, req.control_group)
# 进一步 split static / unit
```

**M6c.3 — moving unit 不参与挡 (avoid_moving_units = false 时)**

```gdscript
func _filter_moving(units: Array, avoid_moving: bool) -> Array:
    if avoid_moving:
        return units
    var result: Array = []
    for u in units:
        if (u.flags & RtsObstructionFlags.MOVING) != 0:
            continue
        result.append(u)
    return result
```

**M6c.4 — 接 facade.compute_short_path_immediate**

facade 加 API:
```gdscript
func compute_short_path_immediate(req: RtsShortPathRequest) -> RtsWaypointPath:
    return _vertex.compute_short_path_immediate(req, _obstr_mgr)
```

**M6c.5 — Smokes**

`smoke_vertex_corner_walking` (✋3 体感):
- start (100, 100), goal (700, 100), 中间 barracks (400, 60..140)
- short path: 从上方或下方绕,任意角度斜线
- 验证:waypoints 数 ≤ 4;vertex 在 barracks 角点 (clearance 外扩)
- 路径 2 段曲线,无 zig-zag

`smoke_vertex_group_filter`:
- 4 unit (control_group = "0"), 2 unit (control_group = "1")
- group "0" 单位 short path 计算时 ignore 同 group 单位

---

## 3. 验收准则 (M6 总)

### AC1-AC9 — 7+2 细节全部实现 🔒
- 1) search bounds toward goal shift / 2) range boundary / 3) virtual goal / 4) terrain edges / 5) lazy visibility / 6) best-so-far / 7) moving unit proxy / 8) group filter / 9) tie-break
- 单元 / smoke 各覆盖一项

### AC10 — 体验点 ✋3 通过 🔒
- demo F6 验证:单位绕单一矩形 barracks 路径任意角度,转角自然贴边

### AC11 — Validation + perf 🔒
- 14 项 + LGF + replay seed=42 deep-equal
- baseline CSV diff: short_path_size / short_path_wp_json 字段从占位变实填(预期);其他字段不变
- perf ≤ 50% (vs M5)

### AC12 — Determinism §12.3 严格遵守 🔒
- Vertex 候选生成顺序按 (obstruction.tag, corner_index) 字典序
- A* 5 元组 (f, h, vx_int, vy_int, seq) deterministic

---

## 4. 关键决策

### L1 — Vertex coord 整数化粒度 (§12.3)

- **A. `int(round(x * 10))`** (0.1 px 粒度 deterministic key) — Recommended
- B. `int(round(x))` (1 px 粒度,可能 vertex 重合时 tie-break 走 seq)

> default A;0.1 px 粒度足够区分实际 vertex 位置;1 px 粒度容易让两个不同 vertex 同 key 走 seq tie-break — 不稳定。

### L2 — Terrain edges 是否在 M6 全启用

- **A. M6 启用,但只在 demo 有水/不可走地形时实际生效**(我们当前没水,实际是 BLOCK_PATHFINDING 边界 — 跟 obstacle 边重合) — Recommended
- B. M6 不启用,留 M9 加水机制时再启

> default A;wiring 通避免 M9 时反复修;实际功能在当前游戏里看不到差别;perf 代价小(只扫 search bounds 内 grid 边界)。

### L3 — Best-so-far 触发条件

- **A. A* 跑完(open empty 或 时间 budget 到)还没到 goal → 返回 best**(0 A.D. 风格) — Recommended
- B. 永远找完,空 path 返回 abort

> default A;让单位至少朝 goal 方向走一段;配合 M7 m_FollowKnownImperfectPathCountdown 触发 retry。

---

## 5. 子任务进度

- [ ] M6a — Static OBB Prototype + smoke_vertex_static_obb
- [ ] M6b — Virtual Goal + Terrain + Best-So-Far
- [ ] M6c — Dynamic Units + Group Filter

---

## 6. 残余风险

| # | 风险 | 缓解 |
|---|---|---|
| R1 | 几何边界 case 漏(start 在 obstruction 内 / 两 obstruction 完全重叠 / 单位即将进入 obstruction) | M6a prototype 阶段先暴露;0 A.D. VertexPathfinder.cpp 1500 行没读完,M6a 启动前必须再过一遍源码 |
| R2 | _segment_obb_dist 用 t-stepping 不精确,边角误判可见 | M6b 末换成精确版 (Liang-Barsky 或 SAT) |
| R3 | A* lazy visibility 性能(每 expand 测 N 个 vertex 可见性 — O(V²) worst case) | M6 搜索框内 vertex 数通常 ≤ 50,O(V²) = 2500 次 segment_clear,每次 segment_clear ~ O(obstacles) ~10 → 25K op/path,GDScript 撑得住 |
| R4 | Replay 漂:vertex 候选生成顺序若依赖 nearby 数组迭代序 | get_obstructions_in_range 内 sort by tag 已保;新增 candidate (terrain / range boundary / virtual goal) 必须按 enum 固定顺序追加 |
| R5 | Best-so-far fallback 引入新代码路径 → 可能 replay 漂 | smoke_replay_bit_identical 跑双倍 epoch 验证 |
| R6 | M6a prototype 跟 production VertexPathfinder 漂移(prototype 简化版 vs 完整版) | M6c 末端把 prototype 退役,完整版替换 + smoke 全跑一遍 |

---

## 7. 决策来源

- 数据结构: data-structures §7.2 (codex R1 P1 #4 7+2 细节补全)
- 0 A.D. 对照: helpers/VertexPathfinder.cpp (~1500 行)
- M5 末态 baseline

---

## 8. 完成后下一步 (M7 启动)

M6 完成 → M7 UnitMotion 重写整合 long+short 双轨。

详见 [`M7-unit-motion.md`](M7-unit-motion.md)。
