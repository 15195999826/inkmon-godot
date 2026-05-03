# M3 Component Interfaces (公开 API)

> 父文档: [`README.md`](README.md)
> 字段定义: [`data-structures.md`](data-structures.md)
> 验证流程: [`validation-strategy.md`](validation-strategy.md)
>
> 本文档定义 M0-M8 引入的所有 component 的**公开 API surface**(谁能调谁 / 调用约定 / 同 tick 可见性 / Determinism contract)。
> data-structures.md 写**字段是什么**,本文档写**API 怎么用 + 谁调谁**。

---

## 0. Component 依赖图

```
                     ┌─────────────────────────┐
                     │  RtsPathfinderFacade    │  ← 顶层入口 (M5+)
                     │  (single-call entry)    │     UnitMotion / Activity 只调它
                     └──────────┬──────────────┘
                                │
                ┌───────────────┼────────────────┐
                ▼               ▼                ▼
       ┌──────────────┐  ┌─────────────┐  ┌───────────────┐
       │ Hierarchical │  │  LongPath   │  │  VertexPath   │
       │ Pathfinder   │  │  finder     │  │  finder       │
       │ (M4)         │  │  (M5)       │  │  (M6)         │
       └──────┬───────┘  └──────┬──────┘  └───────┬───────┘
              │                 │                  │
              └─────────────────┼──────────────────┘
                                ▼
                ┌────────────────────────────────┐
                │      RtsNavcellGrid (M1)       │  ← grid layer
                │      RtsObstructionManager (M2)│
                │      RtsPassabilityRegistry    │
                └────────────────────────────────┘
                                ▲
                                │ rasterize / query / register shapes
                ┌───────────────┴────────────────┐
                ▼                                ▼
       ┌────────────────┐               ┌────────────────┐
       │  RtsUnitMotion │               │ RtsBuildingActor│
       │  (M7)          │               │ (M0+)           │
       └────────────────┘               └────────────────┘
              ▲                                  ▲
              │ owns (RtsMotionComponent)        │ owns (obstruction_shape / footprint_shape)
              │                                  │
       ┌────────────────────────────────────────┐
       │            RtsActor (LGF)              │
       └────────────────────────────────────────┘
```

**关键边界**:
- 顶层 (UnitMotion / RtsActivity / RtsPlayerCommand 处理): 只调 `RtsPathfinderFacade`,不直接打 Hierarchical/Long/Vertex
- 中层 (Pathfinder 三层): 互相协作但不引用;统一从 facade 编排
- 底层 (NavcellGrid / ObstructionManager / PassabilityRegistry): 数据层,被中层只读访问;ObstructionManager 自己注册建筑/单位 shape

---

## 1. `RtsPathfinderFacade` — 顶层入口 (M5 引入)

### 1.1 持有

```gdscript
class_name RtsPathfinderFacade
extends RefCounted

var _hierarchical: RtsHierarchicalPathfinder
var _long: RtsLongPathfinder
var _vertex: RtsVertexPathfinder
var _grid: RtsNavcellGrid
var _obstr_mgr: RtsObstructionManager
var _classes: RtsPassabilityClassRegistry
```

### 1.2 公开 API

| API | 签名 | 调用方 | M | 同步 |
|---|---|---|---|---|
| `compute_path_immediate(start, goal, pass_mask) -> RtsWaypointPath` | LongPath 直接出全图路径 | UnitMotion / Activity / Command | M5+ | sync |
| `compute_short_path_immediate(req: RtsShortPathRequest) -> RtsWaypointPath` | VertexPath 短程绕避 | UnitMotion (per tick) | M6+ | sync |
| `is_goal_reachable(start, goal, pass_mask) -> bool` | 不修改 goal,只查 | Activity (cast 前过滤) | M4+ | sync |
| `make_goal_reachable(start, goal, pass_mask) -> bool` | **副作用: 总是 mutate goal canonicalize**,详见 §1.3 | Command (玩家点不可达点) | M4+ | sync |
| `check_movement(filter, a, b, clearance, pass_mask) -> bool` | 线段无障碍? | UnitMotion (绕障判定) | M5+ | sync |
| `set_obstruction_shape_dirty(tag: int) -> void` | 通知 obstruction 改变需要 re-rasterize | ObstructionManager (内部回调) | M2+ | sync |
| `recompute_grid(classes) -> void` | 全图重建 (启动 / 手动重置) | Procedure (启动) | M1+ | sync |
| `tick(delta: float) -> void` | 每 sim tick 调一次 (内部 dirty 增量更新) | RtsWorld | M4+ | sync |

### 1.3 `make_goal_reachable` 语义 (codex R1 P1 修正)

**总是 mutate `goal` 参数**(canonicalize 成具体可达 navcell 的 POINT goal):
- `return true`: 原 goal 区域内有可达 navcell → goal 替换为该区域内**离 start 最近**的 navcell POINT goal
- `return false`: 原 goal 区域内无可达 navcell → goal 替换为**全图最近可达 navcell**的 POINT goal

**为什么总是 canonicalize**: LongPathfinder 拿到的 goal 必须是单一确定点,避免多解 / 边界 case;让算法层不用反复处理"goal 是 CIRCLE/SQUARE 怎么收敛"。

### 1.4 调用约定

- **不要在外部缓存 facade 持的 grid / obstr_mgr 引用** — facade 内部可能在 tick 时换实例(M4 增量更新触发整体替换的极端 case)
- **同 sim tick 内多次调用**: 后调看到前调的 mutation(synchronous + serialized)
- **跨 tick 一致性**: facade 不持 tick 状态,所有"变化"通过 obstr_mgr 与 grid 的 dirty bit 传播
- **失败模式**: `compute_path_immediate` 返回空 WaypointPath 时 = 找不到路径(不抛异常);调用方按"原地不动 / failed_movements + 1"处理

### 1.5 不在 facade 暴露的 API

| 不暴露 | 理由 | 替代 |
|---|---|---|
| Hierarchical 内部的 chunk/region 数据 | 暴露增加耦合面;后续重构难 | 走 `is_goal_reachable` / `make_goal_reachable` 抽象 |
| LongPath 的 open list / closed set | 内部状态不该外露 | 走 `compute_path_immediate` 一次性出路径 |
| VertexPath 的 visibility graph | 同上 | 走 `compute_short_path_immediate` |
| 直接修改 navcell data | 数据一致性走 ObstructionManager.rasterize | `obstr_mgr.add_*_shape` → 内部触发 dirty |

---

## 2. `RtsObstructionManager` — Shape 数据库 (M2 引入)

### 2.1 持有

参见 [data-structures §2.3](data-structures.md#23-rtsobstructionmanager-autoload--gameworld-单例)。

### 2.2 公开 API

#### 注册 / 注销

| API | 签名 | 调用方 |
|---|---|---|
| `add_unit_shape(entity_id, pos, clearance, flags, group) -> int (tag)` | 单位注册圆形障碍 | RtsMotionComponent.\_init() |
| `add_static_shape(entity_id, pos, rotation, w, h, flags, group, group2="") -> int (tag)` | 建筑/树/资源点注册 OBB 障碍 | RtsBuildingActor.\_post\_init() / RtsResourceNodeActor.\_init() |
| `move_shape(tag, pos, rotation=0.0) -> void` | 移动现有 shape | UnitMotion.\_step() (每 tick 一次) |
| `set_unit_moving_flag(tag, moving: bool) -> void` | 单位起步/停步触发 FLAG_MOVING | UnitMotion (state 变化时) |
| `set_unit_control_group(tag, group: String) -> void` | 单位换队/编队 | Formation (M9, 不在本 Epic) |
| `set_static_control_group(tag, group, group2="") -> void` | 建筑换 owner | Building command (capture / convert,如有) |
| `remove_shape(tag) -> void` | 注销 (entity 死亡 / 销毁) | RtsActor.\_pre\_destroy() |

#### 查询

| API | 签名 | 调用方 |
|---|---|---|
| `test_unit_shape(filter, pos, clearance) -> bool` | 圆形 shape 与现有障碍是否冲突 | Placement command (放兵营前检) / ShortPath (绕障) |
| `test_static_shape(filter, pos, rotation, w, h) -> bool` | OBB 与现有障碍是否冲突 | Placement command (放建筑前检) |
| `get_shape(tag) -> RtsObstructionShape` | 按 tag 查 shape | VertexPathfinder (visibility) |
| `get_obstructions_in_range(pos, range) -> Array[RtsObstructionShape]` | 范围查询(spatial index 加速) | VertexPathfinder (短路径候选) |
| `distance_to_point(entity_id, point) -> float` | shape 到点最短距离 | Activity.is_in_range / AutoTarget 优先级 |
| `distance_to_target(entity_id_a, entity_id_b) -> float` | 两 entity shape 间距离 | Activity.attack 距离判定 |

#### 序列化进 grid

| API | 签名 | 调用方 |
|---|---|---|
| `rasterize(grid, pass_class, dirty_only) -> void` | 把所有 shape 烧到 navcell grid 上 | Pathfinder facade (M3 之后) |

### 2.3 调用约定

- **`add_*_shape` 的 entity_id 必须在调用前已分配** — `IdGenerator` 在 procedure 起始 reset,fixed seed 下序列固定
- **tag 是单调递增 int**,从 1 开始;**0 永远表示无效**(不会被分配)
- **`get_obstructions_in_range` 返回顺序必须按 `tag` 升序**(§12.4 determinism contract)
- **同 tick 内 `move_shape` 后立即调 `get_obstructions_in_range`**: 看到的位置是 move 后的(synchronous)
- **`rasterize(dirty_only=true)`**: 只刷被 set_dirty 的 navcells (M3 增量优化);`false` = 全图重刷 (启动 / 重置)
- **filter 失败时**: `test_*_shape` 返回 `true` (默认保守 — "不能放/不能走")

### 2.4 必须避免

- ❌ 直接读写 `_shapes: Dictionary` — 走 `get_shape(tag)` API
- ❌ 直接读写 `_spatial_index` — 内部实现可换 (uniform grid → quadtree)
- ❌ 在 `rasterize` 期间调 `add_*_shape` — 走"先 add → 下 tick rasterize"链路

---

## 3. `RtsHierarchicalPathfinder` — 可达性 (M4 引入)

### 3.1 公开 API

| API | 签名 | 调用方 | 复杂度 |
|---|---|---|---|
| `recompute(grid, classes) -> void` | 全图重建 chunks + edges + global regions | Facade.recompute_grid() | O(W·H · classes) |
| `update(grid, dirty: PackedByteArray) -> void` | 增量更新(M4c) | Facade.tick() | O(dirty navcells · classes) |
| `get_region(i, j, pass_mask) -> int` | 取 navcell 所在 packed RegionID(0=invalid) | Facade.is_goal_reachable | O(1) |
| `get_global_region(i, j, pass_mask) -> int` | 取连通分量 ID | Facade.is_goal_reachable | O(1) |
| `make_goal_reachable(start_i, start_j, goal, pass_mask) -> bool` | canonicalize goal,详见 §1.3 | Facade.make_goal_reachable | O(BFS within chunk) |
| `is_goal_reachable(start_i, start_j, goal, pass_mask) -> bool` | 只查不变 goal | Facade.is_goal_reachable | O(1) |
| `find_nearest_passable_navcell(start, pass_mask) -> Vector2i` | 起点本身不可通时找最近可通 navcell | Facade (开局 unit spawn 在障碍里) | O(BFS spiral) |

### 3.2 不暴露 (内部实现)

- `_chunks` / `_edges` / `_global_regions` Dictionary 直接读写 → 内部存储格式可变
- 单 chunk flood-fill 算法 → 实现细节
- GlobalRegionID 分配策略 → 详见 [data-structures §12.2](data-structures.md#122-hierarchical-pathfinder-m4)

### 3.3 调用约定

- **`recompute` 必须在 grid 完成 rasterize 后调** — 否则 chunks 拿到 partial state
- **`update(dirty_only)` 是 M4c 的优化** — M4a 默认走 `recompute` 全量重算;只在 perf 不够时启用增量
- **`make_goal_reachable` 总 mutate goal**(参考 [data-structures §4.4](data-structures.md#44-rtshierarchicalpathfinder))
- **packed RegionID = 0 表示"在不可通 navcell 上"**(`is_invalid` 判 `r==0`)— 不是"chunk (0,0) 第 0 region"

---

## 4. `RtsLongPathfinder` — 全图寻路 (M5 引入)

### 4.1 公开 API

| API | 签名 | 调用方 | 实现 |
|---|---|---|---|
| `compute_path_immediate(start, goal, pass_mask) -> RtsWaypointPath` | 朴素 A* on navcell grid (D6 决策) | Facade.compute_path_immediate | sync |

### 4.2 调用约定

- 内部 A* heap key = 5 元组 `(f_cost, h_cost, i, j, insertion_seq)`,严格按字典序比较([data-structures §6.4 / §12.1](data-structures.md))
- **PathCost 是整数**(`hv * 65536 + diag * 92682`),不引入浮点漂移
- **WaypointPath 反向存储**: `back()` = 下一目标 / `pop_back()` = 推进
- **goal 必须是 POINT**(facade 已 canonicalize);LongPathfinder 自身不处理 CIRCLE/SQUARE goal
- **找不到路径**: 返回空 WaypointPath(`is_empty() == true`),不抛异常

### 4.3 不暴露

- `_open_list` / `_closed_set` / heap 内部
- heuristic 函数(内部固定 octile)
- 任何"中途打断"或"渐进出 path" — D6 决策朴素 A*,一次出完整路径

---

## 5. `RtsVertexPathfinder` — 短程绕避 (M6 引入)

### 5.1 公开 API

| API | 签名 | 调用方 | 实现 |
|---|---|---|---|
| `compute_short_path_immediate(req: RtsShortPathRequest, obstr_mgr) -> RtsWaypointPath` | Visibility graph A* | Facade.compute_short_path_immediate | sync |

### 5.2 `RtsShortPathRequest` 字段(必填)

参见 [data-structures §7.1](data-structures.md#71-rtsshortpathrequest)。

| 字段 | 必填? | 含义 |
|---|---|---|
| `start: Vector2` | ✅ | 起点世界坐标 |
| `clearance: float` | ✅ | 单位半径(避让用) |
| `range: float` | ✅ | 搜索范围(默认 1792 px = 56 navcells) |
| `goal: RtsPathGoal` | ✅ | 目标(POINT/CIRCLE/SQUARE/INVERTED 都支持) |
| `pass_mask: int` | ✅ | passability class mask |
| `avoid_moving_units: bool` | optional (默认 true) | FLAG_MOVING 单位是否算障碍 |
| `control_group: String` | optional (默认 "") | 同 group 不算障碍 |
| `notify_entity: String` | optional | sync 实现下不用 |

### 5.3 调用约定

- **高频调用**(每个移动单位每 tick 都可能调) — 性能敏感
- 实现按 [data-structures §7.2](data-structures.md#72-rtsvertexpathfinder-核心算法m6) 完整 9 大类边界 case(含 group filter / tie-break)
- **best-so-far fallback**: 找不到完整路径时返回"已扩展过的离 goal 最近的节点路径"(让单位至少朝 goal 方向走一段),M7 配合 `m_FollowKnownImperfectPathCountdown` 触发 retry
- **moving unit 用方形代理**: 圆形 obstruction 不切线,用 AABB 4 角作 vertex(简化几何 / 避免 bug)

### 5.4 不暴露

- 内部 visibility graph 数据 / lazy 测试缓存
- search bounds shift / virtual goal 算法 → 内部实现

---

## 6. `RtsUnitMotion` — Agent (M7 引入)

### 6.1 持有

参见 [data-structures §8.3](data-structures.md#83-rtsunitmotion-替换-rtsnavagent--rtsunitsteering)。

### 6.2 公开 API

#### 命令入口(Activity / Command 调)

| API | 签名 | 含义 |
|---|---|---|
| `move_to(pos, min_r, max_r) -> void` | 走到点附近(距离 ∈ [min, max]) |
| `move_to_entity(eid, min_r, max_r) -> void` | 接近某 entity 到指定距离 |
| `move_with_offset(eid, off) -> void` | 跟随某 entity,保持 offset(编队) |
| `stop() -> void` | 立即停下 |

#### 状态查询

| API | 签名 | 含义 |
|---|---|---|
| `has_target() -> bool` | 是否有 active MoveRequest |
| `get_clearance() -> float` | 当前半径 |
| `set_clearance(c: float) -> void` | 同步通知 obstruction component(必须保持 clearance ≡ obstruction_shape.radius) |
| `get_speed() -> float` | 当前速度 |

#### Tick(每 sim tick 由 World 调)

| API | 签名 | 含义 |
|---|---|---|
| `tick(delta, world, pathfinder) -> void` | 内部 state machine: path_update / step / handle_obstructed |

### 6.3 调用约定

- **每 sim tick 必须调 `tick()` 一次**,顺序按 `actor.get_id()` 字典序(§12.5 determinism)
- **同 tick 内 unit_A.tick() 先于 unit_B.tick()** → unit_A 移动后 obstr_mgr 已更新 → unit_B 看到 unit_A 新位置(synchronous + ordered)
- **`set_clearance` 必须同步通知 obstr_mgr**: clearance ≡ obstruction_shape.radius 是不变量(D2)
- **失败累积 (`_failed_movements`)**: 35 次后认死路 → activity 层 abort
- **path 持有 (long + short)**: motion 自管理,activity 不得直接 mutate

### 6.4 必须避免

- ❌ Activity 直接读 `_long_path` / `_short_path` — 走 `has_target` / `tick` 抽象
- ❌ 同 tick 内多次调 `move_to()` 切换目标 — Activity 应自己合并;motion 内部不去重多次入参(若多次 setMoveRequest,以最后一次为准但不重置 path)
- ❌ 在 `tick()` 外调 `_step` / `_request_long_path` 等 `_` prefix 私有方法

---

## 7. `RtsPassabilityClassRegistry` — 类注册 (M1 引入)

### 7.1 公开 API

| API | 签名 | 调用方 |
|---|---|---|
| `register(cfg: RtsPassabilityClassConfig) -> void` | 注册一个 class | Procedure (启动一次) |
| `get_class(name_id: String) -> RtsPassabilityClassConfig` | 按 ID 取配置 | UnitMotion (取 clearance 默认值) |
| `get_mask(name_id: String) -> int` | 取 1<<bit_index | Pathfinder (传 pass_mask) |
| `max_clearance() -> float` | 全部 class 中最大 clearance | ShortPath buffer 计算 |

### 7.2 调用约定

- **register 阶段**: procedure 启动时一次性调,之后 frozen
- **bit_index 自动分配**: 0..14 (第 16 bit / SPECIAL_PASS_CLASS_INDEX = 15 留给 in-place 计算)
- **本 Epic 实际只用 `default` (= ground) 和 `air` 两 class**;留 14 bit 给未来扩展(mod / 船类)

---

## 8. `RtsNavcellGrid` — 数据层 (M1 引入)

### 8.1 公开 API

| API | 签名 | 调用方 |
|---|---|---|
| `get_data(i, j) -> int` | 取位掩码 | Pathfinder (per cell) |
| `set_data(i, j, value) -> void` | 整体设位掩码 | ObstructionManager.rasterize 内部 |
| `or_data(i, j, mask) -> void` | 设 bit | ObstructionManager.rasterize 内部 |
| `and_data(i, j, mask) -> void` | 清 bit (mask 是反掩码) | 同上 |
| `is_passable(i, j, class_mask) -> bool` | 是否可通过(对此 class) | Pathfinder (高频) |
| `mark_dirty(i, j) -> void` | 标 dirty(增量更新用) | ObstructionManager 内部 |
| `clear_dirty() -> void` | 清 dirty bits | Hierarchical.update 完后调 |
| `width() / height() -> int` | grid 尺寸 | Pathfinder (边界检查) |
| `navcell_center_world(i, j) -> Vector2` | navcell 中心世界坐标 | Pathfinder waypoint 生成 |
| `nearest_navcell(world_pos: Vector2) -> Vector2i` | 世界坐标 → cell index | Facade (start/goal 转换) |

### 8.2 不暴露

- `_data: PackedInt32Array` 直接 — 走 `get_data / set_data`(实现可换)
- `_dirtiness: PackedByteArray` 直接 — 走 `mark_dirty / clear_dirty`

---

## 9. Helper APIs

### 9.1 `RtsLineOfSight`

| API | 签名 | 调用方 |
|---|---|---|
| `static segment_clear(a, b, shapes, clearance) -> bool` | 线段 vs shapes 集合无障碍? | VertexPathfinder (lazy visibility) |
| `static check_line_movement(grid, a, b, pass_mask) -> bool` | Bresenham raycast on grid | LongPath 后处理 (path smoothing) |

### 9.2 `RtsObstructionTestFilter`

| API | 签名 | 用途 |
|---|---|---|
| `predicate(shape: RtsObstructionShape) -> bool` | 抽象方法,子类实现 | Filter 谁算障碍 |
| `static skip_control_group(group) -> RtsObstructionTestFilter` | 同 group 不算 | 编队内寻路 |
| `static only_blocking_movement() -> RtsObstructionTestFilter` | 只看 BLOCK_MOVEMENT flag | LongPath / ShortPath 默认 |
| `static combined(a, b) -> RtsObstructionTestFilter` | AND 两 filter | 组合复杂条件 |

### 9.3 `RtsSpatialIndex` (M2 内部)

| API | 签名 | 调用方 |
|---|---|---|
| `insert(tag, pos, radius) -> void` | 单 shape 入桶 | ObstructionManager.add_*_shape |
| `update(tag, old_pos, new_pos, radius) -> void` | 移动 | ObstructionManager.move_shape |
| `remove(tag, pos, radius) -> void` | 删除 | ObstructionManager.remove_shape |
| `query_circle(pos, range) -> Array[int (tag)]` | 范围查 | ObstructionManager.get_obstructions_in_range |

**调用约定**: 只 ObstructionManager 内部用,不直接对外暴露;实现可换 (uniform grid → quadtree)。

---

## 10. 调用约定总览

### 10.1 同步性 (sync vs async)

本 Epic 全部 sync:
- `compute_path_immediate` / `compute_short_path_immediate` 命名带 `immediate` 表明 sync
- `notify_entity` / `ticket` 字段 M5/M7 暂保留但内部不走 async(留给将来 GDExtension 化时启用)

### 10.2 同 tick 内可见性

- **核心约束**: 同 sim tick 内,先调用方对 ObstructionManager / Grid 的 mutation **立即对后调用方可见**
- 这意味着 unit_B.tick() 看到 unit_A 已 move_shape 后的位置,而不是 tick 开始时的快照
- 跨平台 Dictionary 迭代序如果不固定,unit 处理顺序漂移 → bit-identical 漂
- 解法: §12.5 显式按 `actor.get_id()` 字典序排序

### 10.3 Tick 顺序 (M7+)

```
sim tick:
  1. RtsPlayerCommandQueue.flush()       # 处理玩家命令(可能 add/remove shape)
  2. for actor in sorted_by_id(motion-bearing):
       actor.motion.tick(delta, world, facade)
       # 内部: path_update_needed → request_long_path → step → handle_obstructed
       # 同步立即更新 obstr_mgr (move_shape / set_unit_moving_flag)
  3. RtsActivity.tick(delta)             # attack / gather / build (使用刚更新的位置)
  4. ObstructionManager.flush_dirty()    # 标记本 tick dirty navcells
  5. RtsHierarchicalPathfinder.update()  # 增量更新 (M4c 后)
  6. EventProcessor.flush()              # post events / replay record
```

### 10.4 Determinism Contract

参见 [data-structures §12](data-structures.md#12-determinism-总排序-contract-codex-p1-4) — 所有 API 实现都必须满足:

- 集合迭代有序(走显式 sort,不走 Dictionary 内部序)
- 浮点比较带 epsilon,不用 `==`
- RNG 一律走 `RtsRng.randf / randi / randf_range / randi_range`(autoload Node)
- 不依赖 wall clock / pointer identity

---

## 11. 兼容性: 现有 RtsBattleGrid facade 退役计划

| 阶段 | RtsBattleGrid 状态 | RtsNavcellGrid 状态 |
|---|---|---|
| M0 | 唯一 grid,API 不变 | 不存在 |
| M1 | 改成 facade,内部委托给 RtsNavcellGrid | 引入,实际数据存这里 |
| M2 | facade 仍存在,placement / footprint 走 facade(内部用 NavcellGrid) | 主存储 |
| M3 | facade 仍存在,但 obstruction.rasterize 直写 NavcellGrid | 主存储 |
| M4 | facade 仍存在(只读 API);调用方逐步迁到直接打 NavcellGrid + Facade | 主存储 |
| **M5** | **移除 facade**(所有调用方直接用 NavcellGrid + Pathfinder Facade) | 主存储,统一入口 |
| M6-M8 | 不存在 | 主存储 |

**M5 RtsBattleGrid 移除时**:
- 所有 `RtsBattleGrid.place_building` / `RtsBattleGrid.world_to_coord` 等调用迁到等价 `RtsNavcellGrid` API
- 现有 `RtsCell` 类删除(对象树结构已被 PackedInt32Array 替代)
- `HexCoord` 类是否保留: M0-M4 期间 grid 内部仍用 `Vector2i` / `HexCoord`,M5 决策时再看是否统一

**RtsBattleGrid facade 期间(M1-M4)**:
- 不再新加 API(冻结 surface)
- 内部调用走新 NavcellGrid,但参数/返回类型保持
- 性能可能略降(facade 多一层调用)— 接受,M5 移除后回归

---

## 12. 字段对照: data-structures.md 索引

| API surface | data-structures 节 |
|---|---|
| RtsPathfinderFacade | §9 |
| RtsObstructionManager | §2.3 |
| RtsHierarchicalPathfinder | §4 |
| RtsLongPathfinder | §6 |
| RtsVertexPathfinder | §7 |
| RtsUnitMotion | §8.3 |
| RtsPassabilityClassRegistry | §1.2 |
| RtsNavcellGrid | §1.4 |
| Helper (LineOfSight / Filter / SpatialIndex) | §7.3 / §2.5 / §2.4 |
| Determinism contract | §12 |
