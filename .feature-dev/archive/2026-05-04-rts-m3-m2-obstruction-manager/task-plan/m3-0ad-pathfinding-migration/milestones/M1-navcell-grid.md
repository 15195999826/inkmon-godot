# M1 — Navcell Grid + 16-bit Passability Class

> 父 plan: [`../README.md`](../README.md)
> 数据结构: [`../data-structures.md`](../data-structures.md) §1 (Grid 层)
> API: [`../interfaces.md`](../interfaces.md) §7 (PassabilityRegistry) + §8 (NavcellGrid)
>
> Status: ✅ **done** (2026-05-04 archived → [`archive/2026-05-04-rts-m3-m1-navcell-grid/`](../../../archive/2026-05-04-rts-m3-m1-navcell-grid/))
> 依赖: M0(obstruction_shape 已落地,但 M1 暂不用 它的 rasterize)
> 阻塞: M2 (M2 已可启动)
>
> **完成进度**:
> - ✅ M1.1 PassabilityClassConfig + Registry — 已落地
> - ✅ M1.2 RtsNavcellGrid (PackedInt32Array) — 已落地
> - ✅ M1.3 RtsBattleGrid 改 facade — 已落地(dual-write 协议)
> - ✅ M1.4 Procedure 启动链路 + attach sync 已有 obstacle — 已落地
> - ✅ M1.5 smoke_navcell_grid_passability + Validation 全套 0 漂移 + simplify pass — 已落地
>
> **完整 evidence + commit hash + 残余风险** 见 [`archive/2026-05-04-rts-m3-m1-navcell-grid/Summary.md`](../../../archive/2026-05-04-rts-m3-m1-navcell-grid/Summary.md)。

---

## 0. 目标 (一句话)

把 `RtsBattleGrid` 的内部数据结构从 `Dictionary[Vector2i, RtsCell]`(对象树)替换成 `RtsNavcellGrid` 的 `PackedInt32Array`(16-bit 位掩码),并引入 `RtsPassabilityClassRegistry` 让 grid 数据按 passability class 区分(本 Epic 实际用 default/ground + air 两 class,留 14 bit 给将来)。

**M1 是数据层重构,寻路算法不变** — 现有 `GridPathfinding.find_path` 仍工作,只是底下数据存储方式变了。

---

## 1. Scope

### 1.1 必做

- 引入 `RtsPassabilityClassConfig` (Resource) + `RtsPassabilityClassRegistry` (单例 / autoload 子系统)
- 注册 2 个 class:`default`(= ground)/ `air`,`bit_index` 自动分配 0/1
- 引入 `RtsNavcellGrid` (RefCounted),内部 `PackedInt32Array` 存 16-bit 位掩码 + `PackedByteArray` 存 dirtiness
- `RtsBattleGrid` 改成 facade:对外 API 不变,内部委托给 `RtsNavcellGrid`
  - 旧 `cells: Dictionary[Vector2i, RtsCell]` 移除
  - 旧 `RtsCell.is_blocking: bool` 语义改成 `navcell_grid.is_passable(i, j, default_mask) == false`
  - 老 API `place_building / get_cell / world_to_coord` 全部委托
- 修 footprint placement (M0 落地的 `obstruction_shape.center` 算 cells)在新 grid 上正确刷写 default class bit
- 加新 smoke `smoke_navcell_grid_passability.tscn` 验证 multi-class passability(default vs air 不互相影响)

### 1.2 不做 (留给后续 M)

| 不做 | 原因 |
|---|---|
| 引入 ObstructionManager(shape 数据库) | M2 |
| Clearance 外扩(per-class buffer) | M3 |
| HierarchicalPathfinder | M4 |
| LongPath / VertexPath 重写 | M5 / M6 |
| 替换 `GridPathfinding.find_path` 算法 | M5(M1 时它仍工作但走旧 A*) |
| 移除 `RtsBattleGrid` facade | M5 |
| Per-unit 区分 ground / air pass class | M3(本 M 留接口但 unit 都暂只用 default) |

### 1.3 核心改动文件清单

#### 新建

```
addons/logic-game-framework/example/rts-auto-battle/
└── logic/
    └── grid/
        ├── rts_passability_class_config.gd        ← Resource (class 配置)
        ├── rts_passability_class_registry.gd      ← 单例 (注册 + 查询)
        └── rts_navcell_grid.gd                    ← 新 grid 数据结构 (PackedInt32Array)
```

#### 修改

```
addons/logic-game-framework/example/rts-auto-battle/
├── logic/
│   ├── grid/
│   │   └── rts_battle_grid.gd                    ← 改成 facade,委托给 RtsNavcellGrid
│   ├── rts_world.gd                              ← 启动时 register class + 创建 RtsNavcellGrid
│   ├── rts_building_actor.gd                    ← get_footprint_cells 不变(M0 已用 obstruction_shape.center)
│   └── commands/rts_building_placement.gd       ← place_building 委托走 facade(API 兼容)
└── core/rts_auto_battle_procedure.gd            ← 启动时初始化 PassabilityRegistry
```

#### 新建 (smoke)

```
addons/.../tests/battle/
├── smoke_navcell_grid_passability.tscn
└── smoke_navcell_grid_passability.gd
```

---

## 2. 子任务 (M1.1 → M1.5)

### M1.1 — 引入 PassabilityClassConfig + Registry

**目标**: 类配置数据 + 注册查询单例。

**步骤**:
1. 新建 `logic/grid/rts_passability_class_config.gd`(按 [data-structures §1.1](../data-structures.md#11-rtspassabilityclassconfig-resource)):
   ```gdscript
   class_name RtsPassabilityClassConfig
   extends Resource

   @export var class_name_id: String
   @export var bit_index: int = -1
   @export var clearance: float = 14.0
   @export var max_water_depth: float = 0.0
   @export var min_water_depth: float = 0.0
   @export var min_shore_distance: float = 0.0
   ```
2. 新建 `logic/grid/rts_passability_class_registry.gd`(按 [data-structures §1.2](../data-structures.md#12-rtspassabilityclassregistry-autoload-或-gameworld-子系统)):
   ```gdscript
   class_name RtsPassabilityClassRegistry
   extends RefCounted

   const PASS_CLASS_BITS: int = 16
   const SPECIAL_PASS_CLASS_INDEX: int = 15

   var _classes: Array[RtsPassabilityClassConfig] = []
   var _by_name: Dictionary = {}
   var _next_bit: int = 0

   func register(cfg: RtsPassabilityClassConfig) -> void:
       Log.assert_crash(_next_bit < PASS_CLASS_BITS - 1, "PassabilityClassRegistry full")
       Log.assert_crash(not _by_name.has(cfg.class_name_id), "duplicate class %s" % cfg.class_name_id)
       cfg.bit_index = _next_bit
       _next_bit += 1
       _classes.append(cfg)
       _by_name[cfg.class_name_id] = cfg

   func get_class(name_id: String) -> RtsPassabilityClassConfig:
       return _by_name.get(name_id, null)

   func get_mask(name_id: String) -> int:
       var cfg: RtsPassabilityClassConfig = _by_name.get(name_id, null)
       return 1 << cfg.bit_index if cfg != null else 0

   func max_clearance() -> float:
       var m: float = 0.0
       for c in _classes:
           m = maxf(m, c.clearance)
       return m
   ```
3. 在 `rts_auto_battle_procedure.gd` 启动时注册 default + air:
   ```gdscript
   var registry := RtsPassabilityClassRegistry.new()
   var ground := RtsPassabilityClassConfig.new()
   ground.class_name_id = "default"
   ground.clearance = 14.0
   registry.register(ground)
   var air := RtsPassabilityClassConfig.new()
   air.class_name_id = "air"
   air.clearance = 8.0  # 飞行单位空间需求小
   registry.register(air)
   rts_world.passability_registry = registry
   ```

**完成标志**: `rts_world.passability_registry.get_mask("default") == 0x1` / `get_mask("air") == 0x2`。

### M1.2 — 引入 RtsNavcellGrid

**目标**: 新数据结构落地。

**步骤**:
1. 新建 `logic/grid/rts_navcell_grid.gd`(按 [data-structures §1.4](../data-structures.md#14-rtsnavcellgrid-替换-rtsbattlegrid-的核心数据结构)):
   ```gdscript
   class_name RtsNavcellGrid
   extends RefCounted

   const NAVCELL_SIZE_PX: int = 32

   var _width: int
   var _height: int
   var _data: PackedInt32Array
   var _dirtiness: PackedByteArray

   func _init(w: int, h: int) -> void:
       _width = w
       _height = h
       _data = PackedInt32Array()
       _data.resize(w * h)
       _dirtiness = PackedByteArray()
       _dirtiness.resize(w * h)

   func _idx(i: int, j: int) -> int:
       return j * _width + i

   func get_data(i: int, j: int) -> int:
       return _data[_idx(i, j)] if i >= 0 and i < _width and j >= 0 and j < _height else -1

   func set_data(i: int, j: int, value: int) -> void:
       _data[_idx(i, j)] = value
       _dirtiness[_idx(i, j)] = 1

   func or_data(i: int, j: int, mask: int) -> void:
       var k := _idx(i, j)
       if (_data[k] & mask) != mask:
           _data[k] = _data[k] | mask
           _dirtiness[k] = 1

   func and_data(i: int, j: int, inverse_mask: int) -> void:
       var k := _idx(i, j)
       if (_data[k] & ~inverse_mask) != _data[k]:
           _data[k] = _data[k] & ~inverse_mask
           _dirtiness[k] = 1

   func is_passable(i: int, j: int, class_mask: int) -> bool:
       if i < 0 or i >= _width or j < 0 or j >= _height:
           return false
       return (_data[_idx(i, j)] & class_mask) == 0

   func mark_dirty(i: int, j: int) -> void:
       _dirtiness[_idx(i, j)] = 1

   func clear_dirty() -> void:
       for k in range(_dirtiness.size()):
           _dirtiness[k] = 0

   func width() -> int: return _width
   func height() -> int: return _height

   func navcell_center_world(i: int, j: int) -> Vector2:
       return Vector2((i + 0.5) * NAVCELL_SIZE_PX, (j + 0.5) * NAVCELL_SIZE_PX)

   func nearest_navcell(world_pos: Vector2) -> Vector2i:
       return Vector2i(int(world_pos.x / NAVCELL_SIZE_PX), int(world_pos.y / NAVCELL_SIZE_PX))
   ```

**完成标志**: 单元测试 `RtsNavcellGrid.new(10, 10).is_passable(0, 0, 0x1) == true` / `or_data(5, 5, 0x1)` 后 `is_passable(5, 5, 0x1) == false`。

### M1.3 — RtsBattleGrid 改成 facade

**目标**: API 不变,内部委托。M5 移除 facade 时 API 调用方迁出去。

**步骤**:
1. 修改 `logic/grid/rts_battle_grid.gd`,内部加 `_navcell_grid: RtsNavcellGrid` 字段;移除 `cells: Dictionary` 和 `RtsCell` 类:
   ```gdscript
   class_name RtsBattleGrid
   extends RefCounted

   var cell_size: int = 32
   var _navcell_grid: RtsNavcellGrid
   var _passability_registry: RtsPassabilityClassRegistry
   var _default_class_mask: int = 0x1

   func _init(width: int, height: int, registry: RtsPassabilityClassRegistry) -> void:
       _passability_registry = registry
       _default_class_mask = registry.get_mask("default")
       _navcell_grid = RtsNavcellGrid.new(width, height)

   func get_navcell_grid() -> RtsNavcellGrid:
       return _navcell_grid

   func world_to_coord(world: Vector2) -> HexCoord:
       var v := _navcell_grid.nearest_navcell(world)
       return HexCoord.new(v.x, v.y)

   func place_building(actor_id: String, footprint_cells: Array) -> void:
       for cell in footprint_cells:
           _navcell_grid.or_data(cell.q, cell.r, _default_class_mask)
       # 记录 actor_id → cells 映射(供 remove_building 用,M2 之前保留)
       _placement_map[actor_id] = footprint_cells.duplicate()

   func remove_building(actor_id: String) -> void:
       if not _placement_map.has(actor_id):
           return
       var inverse: int = _default_class_mask
       for cell in _placement_map[actor_id]:
           _navcell_grid.and_data(cell.q, cell.r, inverse)
       _placement_map.erase(actor_id)

   func is_blocking(coord: HexCoord) -> bool:
       return not _navcell_grid.is_passable(coord.q, coord.r, _default_class_mask)
   ```
2. **删除** 旧 `RtsCell` 类文件 / 内部定义;凡是引用 `cell.is_blocking` 的代码改 `grid.is_blocking(coord)`。
3. 更新 `GridPathfinding.find_path` 内 `grid.cells[c].is_blocking` 调用 → `grid.is_blocking(c)`(API 等价)。

**完成标志**: 全部 14 项 smoke + LGF 73 unit 0 漂移。

### M1.4 — 启动时初始化 grid

**目标**: 接 procedure 启动链路,确保 `rts_world.rts_grid._navcell_grid` 在 actor 创建前已 ready。

**步骤**:
1. `rts_auto_battle_procedure.gd._init_world` 内调用顺序:
   ```
   rts_world = RtsWorld.new()
   registry = RtsPassabilityClassRegistry.new()
   register("default", clearance=14.0)
   register("air", clearance=8.0)
   rts_world.passability_registry = registry
   rts_world.rts_grid = RtsBattleGrid.new(grid_w, grid_h, registry)
   # 后续 actor / building 创建 + place_building
   ```
2. 验证 `rts_world.rts_grid.get_navcell_grid()` 返回非 null。

**完成标志**: `smoke_rts_auto_battle` 等所有现有 smoke 不退化。

### M1.5 — 新 smoke + Validation 全套

**步骤**:
1. 新建 `tests/battle/smoke_navcell_grid_passability.gd`:
   - 创 RtsBattleGrid + register default + air
   - 在 navcell (5, 5) 写 default bit
   - 验证 `is_passable(5, 5, default_mask) == false`
   - 验证 `is_passable(5, 5, air_mask) == true`(default 与 air 不互相影响)
   - 在 navcell (10, 10) 写 air bit
   - 验证 `is_passable(10, 10, default_mask) == true`(对地面单位 OK,air bit 不影响)
   - 验证 `is_passable(10, 10, air_mask) == false`
2. 跑全套 14 项 + LGF + replay + new smoke,数字不漂。
3. baseline CSV 跑两次 byte-identical。
4. perf-trace 新加一行 (M1)。
5. submodule commit + 主仓 bump:
   ```
   feat(rts-m3): M1 done — Navcell Grid + 16-bit Passability Class
   ```

---

## 3. 验收准则 (10 AC)

### AC1 — PassabilityClassConfig + Registry 落地 🔒 pending
- 文件存在;register 按 bit_index 自动分配 0..14
- `register` 重复 class_name_id 时 `Log.assert_crash`
- `get_mask("default") == 0x1` / `get_mask("air") == 0x2`(注册顺序固定)

### AC2 — RtsNavcellGrid 落地 🔒 pending
- `PackedInt32Array` 内部存储 + `PackedByteArray` dirtiness
- `or_data` / `and_data` 设置/清除 bit;`is_passable` 正确判定
- 边界外 `is_passable` 返回 false(防越界)

### AC3 — RtsBattleGrid facade 改造 🔒 pending
- 旧 `cells: Dictionary[Vector2i, RtsCell]` 字段删除,无引用
- 旧 `RtsCell` 类移除(或留空 stub 标 deprecated 等 M5 删)
- 公开 API (`world_to_coord / place_building / remove_building / is_blocking`) 行为与 M0 末态等价

### AC4 — Procedure 启动链路 🔒 pending
- procedure 启动时 PassabilityRegistry / NavcellGrid 已初始化
- `rts_world.passability_registry` / `rts_world.rts_grid._navcell_grid` 非 null

### AC5 — `smoke_navcell_grid_passability` PASS 🔒 pending
- 验证 default vs air 不互相影响
- 输出 `SMOKE_TEST_RESULT: PASS`

### AC6 — Validation 全套 0 漂移 🔒 pending
- 14 项 smoke 数字 byte-identical(列表见 [validation-strategy §6](../validation-strategy.md#6-每-milestone-验收-checklist-模板))
- LGF 73/73 PASS
- replay seed=42 deep-equal
- baseline CSV(M0 末态)对比新 baseline:**仅 M1 字段变化** = 无新字段(M1 不引入 trace 新字段) → byte-identical

### AC7 — Perf 增长 ≤ 50% 🔒 pending
- `perf-trace.csv` 新增 M1 行
- vs M0: wall_clock ≤ +50%,tick_p99 ≤ 30 ms

### AC8 — Multi-class 不互相干扰 🔒 pending(smoke 自动验)
- 在 (i, j) 写 default → air 单位仍可通过
- 在 (i, j) 写 air → ground 单位仍可通过

### AC9 — 现有 GridPathfinding.find_path 工作 🔒 pending
- M1 不重写 find_path,只改底层数据访问
- `find_path` 内部访问改成 `grid.is_blocking(c)`(API 兼容)
- 路径输出 跟 M0 完全一致 (replay bit-identical)

### AC10 — 不动 LGF submodule core/ stdlib/ 🔒 pending
- 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内

---

## 4. 决策表 (G 系列)

### G1 — `RtsCell` 类删除 vs deprecate stub

- **A. 完全删除** — Recommended
- B. 留 deprecated stub,M5 一起删

> default A;M1 干净删除,凡引用方都改;M5 移除 facade 时只剩 grid API 调整,降低累加复杂度。

### G2 — `air` class 在 M1 是否真用

- **A. 注册但 M1 不使用**(留接口,M3 飞行单位 obstruction 才用) — Recommended
- B. M1 不注册 air,M3 时再加

> default A;一次性注册避免 M3 时改 procedure 启动顺序。

### G3 — `place_building` 接口是否在 M1 改

- **A. 不改,保持 `(actor_id, footprint_cells)` 兼容**(facade 内部委托 NavcellGrid) — Recommended
- B. 改成 `(shape: RtsObstructionShapeStatic) -> void`

> default A;M2 引入 ObstructionManager 时再统一接口。

### G4 — `_dirtiness` 用 `PackedByteArray` vs `Dictionary`

- **A. PackedByteArray**(密集存储,每 navcell 1 byte)— Recommended
- B. Dictionary(稀疏,只存 dirty cells)

> default A;1024×1024 grid PackedByteArray 仅 1 MB,密集访问更快;clear_dirty O(N) 但跟 grid size 同阶,M3 才会高频清,接受。

### G5 — `default` class 名字 vs 0 A.D. `default-terrain-only` vs `ground`

- **A. `default`**(对标 0 A.D. PassabilityClass 默认配置)— Recommended
- B. `ground`(更易理解但跟 air 对仗欠雅)

> default A;0 A.D. xml 里就叫 default,迁移文档对照方便。

---

## 5. 子任务进度

- [ ] **M1.1** — PassabilityClassConfig + Registry 🔒 pending
- [ ] **M1.2** — RtsNavcellGrid (PackedInt32Array) 🔒 pending
- [ ] **M1.3** — RtsBattleGrid 改 facade 🔒 pending
- [ ] **M1.4** — Procedure 启动链路 🔒 pending
- [ ] **M1.5** — 新 smoke + Validation 🔒 pending

---

## 6. 残余风险

| # | 风险 | 缓解 |
|---|---|---|
| R1 | 删除 `RtsCell` 类导致 grep 不到的 deep callers 漏改 | M1.3 前先 `grep "RtsCell\|cells\[\|cells\.get"` 列全;漏改的 runtime crash → 改 |
| R2 | `place_building` cells 参数 — 现有调用方传 `Array[HexCoord]`,新代码 `cell.q, cell.r` 取坐标后写位掩码;若旧代码传 `Vector2i` 而非 HexCoord 会断 | M1.3 改 facade 时显式断言入参类型 (`Log.assert_crash(cell is HexCoord)`) |
| R3 | 跨平台 `PackedInt32Array` 序列化(若 replay 序列化它)字节序问题 | M1 不序列化 grid;replay 仍序列化 actor state(grid 是 derived);若 M5 后需 serialize grid 时再处理 |
| R4 | `_idx(i, j)` 越界访问导致 PackedInt32Array crash | `is_passable` / `get_data` 加边界检查;`set_data` / `or_data` 走 procedure 信任(内部),不加 check 省 perf;若发现误用必 crash 立刻定位 |
| R5 | `bit_index` 自动分配顺序变化(register 顺序换)会让 mask 数字漂 → replay 漂 | procedure 内 `register("default")` 永远先于 `register("air")`,顺序固化;single source of truth |
| R6 | `RtsBattleGrid.cell_size = 32` 跟 `RtsNavcellGrid.NAVCELL_SIZE_PX = 32` 双源 | M1 阶段保持双源(facade 兼容期);M5 移除 facade 时统一到 NavcellGrid |

---

## 7. 决策来源

- 范围: README §0.2 (D2 决策: 复刻 4 component)
- 数据结构: data-structures §1
- API: interfaces §7-8
- 0 A.D. 对照: `helpers/Pathfinding.h:130` (NavcellData = u16) + `helpers/Grid.h` (Grid<T>)
- M1 启动前置: M0 末态 baseline (AC6 数字)

---

## 8. 完成后下一步 (M2 启动)

M1 完成 → M2 ObstructionManager 启动。

M2 依赖 M1:
- `RtsNavcellGrid.or_data / and_data` API (rasterize 用)
- `RtsPassabilityClassRegistry.get_mask` (rasterize 时知道写哪个 bit)
- 现有 `RtsBattleGrid.place_building` 仍工作(M2 时 ObstructionManager 替代它)

详见 [`M2-obstruction-manager.md`](M2-obstruction-manager.md)。
