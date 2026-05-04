# M3 — Clearance + 外扩 (per-class buffer)

> 父 plan: [`../README.md`](../README.md)
> 数据结构: [`../data-structures.md`](../data-structures.md) §1.1 (clearance 字段) + §2.3 (rasterize)
> API: [`../interfaces.md`](../interfaces.md) §2 + §7
>
> Status: 🔒 pending(M2 完成后启动)
> 依赖: M2 (ObstructionManager.rasterize + dirty 机制)
> 阻塞: M4 (Hierarchical 需要 per-class passability 已外扩)

---

## 0. 目标

引入 **per-passability-class clearance**(单位半径)+ **外扩算法**(Inflate),让 navcell grid 上每个 class 的 passable 区域已经把"单位自己的半径"算进去 — pathfinder 走 navcell center 直线连线时不会撞 obstruction 边。

这是 0 A.D. 最关键的设计之一(`CCmpPathfinder.cpp:RecalculateGridDirty` 同名算法):**一次外扩,任何同 class 单位 free path** — 不需要每次寻路时考虑"我自己有半径"。

**Bug 1 完整修复的预备**:M3 完成后,clearance 外扩让单位走 navcell center 路径就不会贴墙穿建筑;但完整自然角度路径仍要等 M6 vertex pathfinder。

---

## 1. Scope

### 1.1 必做

- ObstructionManager.rasterize 增加第二遍:**外扩** (Inflate)
- 每个 PassabilityClass 用自己的 clearance:`default` = 14 px,`air` = 8 px
- 外扩算法:对每个 BLOCK_PATHFINDING obstruction 的 navcell-projected 边界,在 clearance / NAVCELL_SIZE_PX(rounded up)半径内的 navcell 标 impassable
- 飞行单位的 obstruction 仍然存在但只对 air class 生效(M3 顺手 wire `set_unit_moving_flag` 等已有)— 实际 air 单位现在没真实场景使用 air 区分,但留通路(本 Epic 不引入飞行单位,M3 只把 wiring 通,留功能给后续)
- dirty 增量:只重算 dirty navcells 周围 clearance 半径范围,不全图重刷
- 加新 smoke `smoke_clearance_inflate.tscn` 验证不同 clearance 的 buffer 范围正确

### 1.2 不做

| 不做 | 原因 |
|---|---|
| 0 A.D. 真正的 EDT (Euclidean Distance Transform) 算法 | 工程量大,brute-force 暴力 O(dirty × clearance²) GDScript 100 单位规模够用 |
| Hierarchical 增量更新触发 | M4(M3 只标 dirty,M4 消费) |
| Per-unit clearance(运行时变化) | 不需要;clearance 由 unit_kind config 决定,变化罕见 |
| Water depth / shore distance(0 A.D. 也支持) | 我们没水机制,留接口不实现 |
| 飞行单位的 demo / smoke 集成 | 走 wiring 不引入新单位类型 |

### 1.3 文件清单

#### 修改

```
addons/.../logic/obstruction/
└── rts_obstruction_manager.gd                ← rasterize 加 inflate 第二遍

addons/.../logic/grid/
├── rts_passability_class_config.gd          ← clearance 字段已在 M1 加,M3 启用 per-class 外扩
└── rts_passability_class_registry.gd        ← max_clearance 已存在,M3 用作 dirty 范围估算

addons/.../core/rts_auto_battle_procedure.gd ← 启动时把 air class 的 clearance 改 8 px(M1 时已注册)
```

#### 新建 (smoke)

```
addons/.../tests/battle/
└── smoke_clearance_inflate.tscn / .gd
```

---

## 2. 子任务 (M3.1 → M3.4)

### M3.1 — ObstructionManager.rasterize 加 inflate 第二遍

**目标**: rasterize 现在分两步:第一步原 cell 占用(M2 已有);第二步**外扩** clearance 半径。

**步骤**:
1. 修改 `rts_obstruction_manager.gd.rasterize`:
   ```gdscript
   func rasterize(grid: RtsNavcellGrid, pass_class: RtsPassabilityClassConfig, dirty_only: bool) -> void:
       var class_mask: int = 1 << pass_class.bit_index
       var clearance: float = pass_class.clearance
       var clearance_cells: int = int(ceilf(clearance / RtsNavcellGrid.NAVCELL_SIZE_PX))
       
       if not dirty_only:
           # 全图清这个 class 的 bit
           for j in range(grid.height()):
               for i in range(grid.width()):
                   grid.and_data(i, j, class_mask)
       else:
           # 只清 dirty + clearance buffer 范围(防止外扩残留)
           _clear_dirty_with_buffer(grid, class_mask, clearance_cells)
       
       # 第一步: 原始 cell 占用 (M2 已有逻辑)
       for tag in _shapes:
           var s = _shapes[tag]
           if (s.flags & RtsObstructionFlags.BLOCK_PATHFINDING) == 0:
               continue
           # 飞行单位: BLOCK_PATHFINDING 标 air class; 地面单位: 标 default
           # M3 阶段建筑都 BLOCK_PATHFINDING for default class only (air 飞过去, 不挡)
           if not _shape_blocks_class(s, pass_class):
               continue
           _rasterize_one_shape(grid, s, class_mask)
       
       # 第二步: 外扩 (M3 新)
       _inflate(grid, class_mask, clearance_cells, dirty_only)
       
       # ⚠️ R5 P1 #2: 不再在 rasterize 内 clear_dirty
       # 因为 hierarchical_pathfinder.update(grid, dirtinessGrid) 还需要这个 dirty 集合做增量
       # caller (RtsWorld.tick / facade.tick) 在 step 7 末端统一清
       # grid.clear_dirty()  ← 删除

   func _shape_blocks_class(s: RtsObstructionShape, pass_class: RtsPassabilityClassConfig) -> bool:
       # 默认: BLOCK_PATHFINDING shape 对 default class 生效
       # 飞行单位 (FLAG_FLYING) 对 air class 生效  
       # M3 简化: 建筑 OBB 对 default 生效, 不挡 air; 飞行单位的 unit shape 同样
       if pass_class.class_name_id == "default":
           return true
       elif pass_class.class_name_id == "air":
           # M3 阶段没 BLOCK_PATHFINDING 的飞行 shape 进入 ObstructionManager
           # 留接口,M3 不实际触发
           return false
       return false

   func _inflate(grid: RtsNavcellGrid, class_mask: int, clearance_cells: int, dirty_only: bool) -> void:
       # 对每个本轮新写入 class_mask 的 navcell, 在半径 clearance_cells 内的 navcell 也标 class_mask.
       # 简化策略:对所有 BLOCK_PATHFINDING shape, 计算它的 footprint AABB + clearance_cells buffer, 逐 cell 标.
       for tag in _shapes:
           var s = _shapes[tag]
           if (s.flags & RtsObstructionFlags.BLOCK_PATHFINDING) == 0:
               continue
           if not _shape_blocks_class(s, _passability_registry.get_class_by_mask(class_mask)):
               continue
           _inflate_one_shape(grid, s, class_mask, clearance_cells)

   func _inflate_one_shape(grid: RtsNavcellGrid, s: RtsObstructionShape, class_mask: int, clearance_cells: int) -> void:
       # 对 OBB shape,展开 AABB + clearance buffer,逐 cell 算到 OBB 最近距离 ≤ clearance 时标
       if s is RtsObstructionShapeStatic:
           var corners := s.get_corners()
           var min_x: float = INF
           var max_x: float = -INF
           var min_y: float = INF
           var max_y: float = -INF
           for c in corners:
               min_x = minf(min_x, c.x)
               max_x = maxf(max_x, c.x)
               min_y = minf(min_y, c.y)
               max_y = maxf(max_y, c.y)
           var buffer_px: float = clearance_cells * RtsNavcellGrid.NAVCELL_SIZE_PX
           var i0: int = int(floorf((min_x - buffer_px) / RtsNavcellGrid.NAVCELL_SIZE_PX))
           var i1: int = int(floorf((max_x + buffer_px) / RtsNavcellGrid.NAVCELL_SIZE_PX))
           var j0: int = int(floorf((min_y - buffer_px) / RtsNavcellGrid.NAVCELL_SIZE_PX))
           var j1: int = int(floorf((max_y + buffer_px) / RtsNavcellGrid.NAVCELL_SIZE_PX))
           var clearance_px: float = clearance_cells * RtsNavcellGrid.NAVCELL_SIZE_PX
           for j in range(j0, j1 + 1):
               for i in range(i0, i1 + 1):
                   if i < 0 or i >= grid.width() or j < 0 or j >= grid.height():
                       continue
                   var cell_center := grid.navcell_center_world(i, j)
                   var dist := _shape_to_point_distance(s, cell_center)
                   if dist <= clearance_px:
                       grid.or_data(i, j, class_mask)
       elif s is RtsObstructionShapeUnit:
           # Unit obstruction inflate: 圆心 clearance + buffer
           var total_radius: float = s.clearance + clearance_cells * RtsNavcellGrid.NAVCELL_SIZE_PX
           var i0: int = int(floorf((s.center.x - total_radius) / RtsNavcellGrid.NAVCELL_SIZE_PX))
           var i1: int = int(floorf((s.center.x + total_radius) / RtsNavcellGrid.NAVCELL_SIZE_PX))
           var j0: int = int(floorf((s.center.y - total_radius) / RtsNavcellGrid.NAVCELL_SIZE_PX))
           var j1: int = int(floorf((s.center.y + total_radius) / RtsNavcellGrid.NAVCELL_SIZE_PX))
           for j in range(j0, j1 + 1):
               for i in range(i0, i1 + 1):
                   if i < 0 or i >= grid.width() or j < 0 or j >= grid.height():
                       continue
                   var cell_center := grid.navcell_center_world(i, j)
                   if cell_center.distance_to(s.center) <= total_radius:
                       grid.or_data(i, j, class_mask)

   func _clear_dirty_with_buffer(grid: RtsNavcellGrid, class_mask: int, clearance_cells: int) -> void:
       # 找出本轮 dirty 的 navcells, 把它们 + 周围 clearance_cells buffer 都清 class_mask bit
       var inverse_mask: int = class_mask
       for j in range(grid.height()):
           for i in range(grid.width()):
               if grid._dirtiness[grid._idx(i, j)] != 1:
                   continue
               # 清 (i,j) + 周围 clearance_cells
               for dj in range(-clearance_cells, clearance_cells + 1):
                   for di in range(-clearance_cells, clearance_cells + 1):
                       var ii := i + di
                       var jj := j + dj
                       if ii >= 0 and ii < grid.width() and jj >= 0 and jj < grid.height():
                           grid.and_data(ii, jj, inverse_mask)
   ```
2. 在 `rts_passability_class_registry.gd` 加辅助:
   ```gdscript
   func get_class_by_mask(mask: int) -> RtsPassabilityClassConfig:
       for c in _classes:
           if (1 << c.bit_index) == mask:
               return c
       return null
   ```

**完成标志**: rasterize 跑完后,obstruction 周围 clearance 半径内 navcell 全标 class bit;dirty 增量正确清除残留。

### M3.2 — Per-class clearance 配置

**步骤**:
1. 修改 `rts_auto_battle_procedure.gd._init_world` 启动注册:
   - default class clearance = 14.0(已 M1 设)
   - air class clearance = 8.0(确认)
2. 单元测试 verify:`registry.get_class("default").clearance == 14.0`,`registry.get_class("air").clearance == 8.0`,`registry.max_clearance() == 14.0`。

**完成标志**: 启动后 PassabilityRegistry 配置正确。

### M3.3 — Procedure / RtsWorld 接 rasterize 调度

**步骤**:
1. 决定 rasterize 调用时机:
   - **建筑 placement**:placement command apply 后立即 rasterize(M2 已是)
   - **建筑死亡**:`_pre_destroy` 时 rasterize(remove_shape 已 mark_dirty,这里 rasterize 同步)
   - **单位 spawn / move / death**:M3 阶段单位**不**触发 rasterize(单位走 BLOCK_MOVEMENT 但**不** BLOCK_PATHFINDING,所以不影响 grid)。M7 阶段如果引入 dynamic units 进入 grid 才需要,本 Epic 推到 M7c+。
2. 修改 `RtsWorld.tick`:加一个 `obstruction_manager.rasterize_if_dirty()` 调用,每 tick 末检查是否有 dirty navcells,有则触发 rasterize:
   ```gdscript
   func tick(_delta: float) -> void:
       ...
       obstruction_manager.rasterize_if_dirty(_navcell_grid, passability_registry)
   ```
3. ObstructionManager 加这个方法(⚠️ R5 P1 #2 修订:**不**在内部 clear_dirty,留给 caller 用 dirty snapshot 做 hierarchical update 后统一清):
   ```gdscript
   ## 检查是否有 dirty navcell, 有则对每个 class rasterize.
   ## 不 clear dirty — caller 在 hierarchical update 完成后, RtsWorld.tick step 7 末端统一清.
   func rasterize_if_dirty(grid: RtsNavcellGrid, registry: RtsPassabilityClassRegistry) -> bool:
       var has_dirty: bool = false
       for k in range(grid._dirtiness.size()):
           if grid._dirtiness[k] == 1:
               has_dirty = true
               break
       if not has_dirty:
           return false
       # 对所有注册的 class 都重 rasterize (M3 阶段只 default 实际有 BLOCK_PATHFINDING shape)
       for c in registry._classes:
           rasterize(grid, c, true)
       return true   # 返回 "需要后续 hierarchical update + clear dirty" 信号
   ```

4. **dirty lifecycle ownership**(关键 R5 P1 #2 invariant):
   - **ObstructionManager.rasterize**:**读** dirty + **不**清 dirty
   - **RtsHierarchicalPathfinder.update(grid, dirty)**:**读** dirty + **不**清 dirty(可读多次,M3/M4 分别用)
   - **RtsWorld.tick step 7**:`grid.clear_dirty()` 末端统一清
   - 任何中途 `clear_dirty()` 调用 = bug → M3.4 + M4 smoke 必须验证 dirty 在 hierarchical.update 时仍非空

**完成标志**: 建筑 placement / removal 时 rasterize 自动触发;空 dirty 时 noop。

### M3.4 — 新 smoke + Validation 全套

**步骤**:
1. 新建 `tests/battle/smoke_clearance_inflate.gd`:
   - 创 ObstructionManager + grid 100×100
   - register default (clearance=14) + air (clearance=8)
   - add_static_shape barracks at (500, 500),size = 64×64
   - rasterize default class
   - 验证: barracks 占的 cells (480..560 / 480..560 范围) **及** clearance buffer (14 px = 0.4 cells, ceil = 1 cell)都标 default bit
   - 具体:barracks 占 (15..17, 15..17) 共 9 cells (3×3, 64/32 = 2 cells per side, +1 buffer cell);clearance 加 1 cell 外扩 → 共 (14..18, 14..18) = 25 cells 标 default bit
   - 验证:同样 cells 对 air class 检查 → 全可通(`is_passable(i, j, air_mask) == true`)
2. 跑 14 项 + LGF + replay + new smoke
3. baseline CSV 跑两次 byte-identical
4. 对比 M2 baseline:**预期变化** = clearance 外扩后,unit 寻路绕建筑路径会**更宽**(navcell 障碍范围加 1 cell)→ trace `final_tx / final_ty` 路径偏移 → **算 baseline 漂移**(预期)
5. **新 baseline 接受**:跑 `smoke_pathfinding_baseline` 后 copy 新 csv 覆盖 master baseline
6. perf-trace M3 行;rasterize 开销可能 +30-100%(外扩遍历 buffer cells)
7. submodule commit:
   ```
   feat(rts-m3): M3 done — Clearance + 外扩 (per-class buffer)
   ```

---

## 3. 验收准则

### AC1 — Rasterize 加 inflate 第二遍 🔒 pending
- ObstructionManager.rasterize 调用后,obstruction 周围 clearance 范围内 navcell 标 class bit

### AC2 — Per-class clearance 生效 🔒 pending
- default class 14 px 外扩 / air class 8 px 外扩独立工作
- 同一 obstruction 在两 class 上 inflate 范围不同

### AC3 — Dirty 增量正确 🔒 pending
- 移走一个 building → rasterize_if_dirty 后该位置 navcell 不再 impassable
- 残留检查:多个 building 互相靠近时,移走一个不影响另一个的 inflate

### AC4 — Procedure 接调度 🔒 pending
- building placement 自动触发 rasterize
- 空 dirty 时 noop(perf)

### AC5 — `smoke_clearance_inflate` PASS 🔒 pending

### AC6 — Validation 14 项 + LGF + replay 🔒 pending
- replay seed=42 deep-equal(关键!外扩算法引入新代码路径,确保 deterministic)
- baseline CSV diff vs M2:预期变化 = unit 路径绕建筑变宽 (final_tx/ty 偏移) → 接受新 baseline

### AC7 — Perf 增长 ≤ 50% 🔒 pending
- rasterize 时间增加(外扩 brute-force);若超 50% 用户审阅(M3 是已知 perf 转折点)

### AC8 — air class 外扩独立 🔒 pending
- smoke 内验证 air class rasterize 不受 default building 影响

### AC9 — 体验点改进准备 🔒 pending
- demo_rts_frontend 跑一局,**单位绕建筑路径明显比 M2 更宽**(目测,虽然 M3 没新体验点,但视觉上能看出 buffer 生效)

### AC10 — 不动 LGF submodule core/ stdlib/ 🔒 pending

---

## 4. 决策表 (I 系列)

### I1 — Inflate 算法选 brute-force vs EDT

- **A. Brute-force**(每 obstruction AABB + buffer 内逐 cell 算距离) — Recommended
- B. EDT (Euclidean Distance Transform 二次扫描)

> default A;100 单位规模 + 30 Hz GDScript 跑得动;EDT 工程量大;若 ≥500 单位 / 多 class 同时 inflate perf 不够再换 EDT。

### I2 — Inflate 用圆形 buffer vs 方形 buffer

- **A. 圆形**(精确距离 ≤ clearance 标 buffer) — Recommended
- B. 方形(AABB Chebyshev 距离 ≤ clearance)

> default A;圆形跟单位实际形状(圆)对齐,绕角更自然;方形会让"对角缘"多出额外 buffer cell 显得突兀。

### I3 — `clearance` 单位 px vs navcell

- **A. px**(`14.0`,跟现有 collision_radius 兼容) — Recommended  
- B. navcell 数(`0.4`)

> default A;前文 data-structures Q1 已拍板 px。

### I4 — 飞行单位的 inflate 在 M3 是否真用

- **A. 留 wiring 不实际用**(air class shape 不引入,inflate 通过单元测试覆盖) — Recommended
- B. 引入 1 个测试用飞行单位 demo

> default A;本 Epic 不引入飞行单位 game logic 改动;air wiring 通即可。

### I5 — `_clear_dirty_with_buffer` 是否优先于 full clear

- **A. 启动时 / 全重建时 full clear,平时 dirty + buffer**(性能折中) — Recommended
- B. 永远 full clear(简单但 perf 差)

> default A;dirty 增量是 0 A.D. 风格,延迟 OK 时启用;复杂 corner case (M5/M6 后 perf 不够时) 再调。

---

## 5. 子任务进度

- [ ] M3.1 — ObstructionManager.rasterize 加 inflate
- [ ] M3.2 — Per-class clearance 配置
- [ ] M3.3 — Procedure 接 rasterize 调度
- [ ] M3.4 — 新 smoke + Validation

---

## 6. 残余风险

| # | 风险 | 缓解 |
|---|---|---|
| R1 | brute-force inflate 多 building 时 perf 炸 | smoke perf 监控;若 M2.3 16 building 场景 rasterize > 30 ms,M3 末端考虑 EDT 优化 |
| R2 | 外扩范围算错 → 单位走过建筑边角 | 严格按 0 A.D. 算法 (距离测试 ≤ clearance + buffer cells × NAVCELL_SIZE_PX);新 smoke 覆盖边角 case |
| R3 | dirty 增量清残留 bug → 移走 building 后周围仍 impassable | smoke `smoke_clearance_inflate` 包含 "add → remove → 验证 cells 全可通"流程 |
| R4 | replay 漂:rasterize 引入"obstruction 迭代序"依赖 | `_shapes` 迭代用 sort by tag (借 spatial_index.query_circle 已有 sort),不依赖 Dictionary 内部 |
| R5 | 单位走的路径变宽 → smoke baseline 漂移 → 误判 bug | M3.4 步骤 5 显式接受新 baseline,文档说明此处是预期变化 |
| R6 | 多 class rasterize 互相覆盖 bit | 每 class 独立 mask,or_data / and_data 只动该 bit |

---

## 7. 决策来源

- 数据结构: data-structures §1.1 (clearance 字段) + §2.3 (rasterize)
- 0 A.D. 对照: components/CCmpPathfinder.cpp `RecalculateGridDirty` + `Inflate` (内部算法)
- M2 末态 baseline

---

## 8. 完成后下一步 (M4 启动)

M3 完成 → M4 HierarchicalPathfinder。

M4 依赖 M3:
- per-class navcell grid passability(已外扩)
- dirty 机制(M4 增量更新触发)
- ObstructionManager 注册 / 删除链路稳定

详见 [`M4-hierarchical.md`](M4-hierarchical.md)。
