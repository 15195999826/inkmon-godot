# M0 — Footprint 拆分 + 修 Bug 1

> 父 plan: [`../README.md`](../README.md)
> 数据结构定义: [`../data-structures.md`](../data-structures.md) §3 (Footprint), §2 (Obstruction shape data class)
>
> Status: 🟡 **active** (Step A + Step B 完成,codex Round 1-8 全 APPROVE,`/next-feature-planner` 已接入;**M0.1 + M0.2 已 done**,runner 从 M0.3 起步)
> 依赖: 无 (M0 是 Epic 起点)
> 阻塞: M1 (M0 完成后 M1 可启动)
>
> **当前进度** (详见 §5 + `.feature-dev/Progress.md`):
> - ✅ M0.1 Trace utility + baseline replay 准备 — 已落地(Step C 之前由 Agent 完成)
> - ✅ M0.2 引入 3 个 data class — 已落地(2026-05-03;`logic/obstruction/{rts_obstruction_shape,_static,rts_footprint_shape}.gd` 三文件;import 通过 + LGF 73/73 + smoke_rts_auto_battle 0 漂移)
> - ⏭️ M0.3 RtsBuildingConfig.StatBlock 加 4 字段 — **下一步**
> - 🔒 M0.4 - M0.7 — pending

---

## 0. 目标 (一句话)

把 `RtsBuildingActor` 的"位置 / 寻路占地 / 选择"从 `position_2d` + `footprint_cells` + `collision_radius` 杂糅状态拆成 **三个独立 data**:**Position (渲染锚点) + ObstructionShape (寻路占地) + FootprintShape (UI 选择)**;过程中**自然修复 Bug 1** (footprint 几何中心和 position_2d 偏 12-42 px 导致单位视觉穿建筑)。

**M0 是 Epic 唯一改动 frontend 渲染锚点的 milestone**。M1-M8 全部 logic-only,frontend 不动。

---

## 1. Scope

### 1.1 必做

- 引入 3 个新 data class (`RtsObstructionShape` 基类 / `RtsObstructionShapeStatic` 子类 / `RtsFootprintShape`),完全按 [`data-structures.md`](../data-structures.md) §2 §3 字段定义,**纯 data,不挂任何算法逻辑**
- `RtsBuildingActor` 加 `obstruction_shape: RtsObstructionShapeStatic` + `footprint_shape: RtsFootprintShape` 字段
- `RtsBuildings` 工厂**只填 shape 默认字段** (size / type / offset),**不写 center**;procedure / command 写完 `position_2d` 后调 `actor.sync_obstruction_shape()` 把 center 设到 `position_2d + obstruction_offset`,再 call `place_building`。**factory 不知道最终 position,不能在那里算 center** (codex P1 #2)
- `RtsBuildingConfig.StatBlock` 加 4 个字段 (从原 `footprint_size: Vector2i` 派生默认值): `obstruction_size: Vector2` / `obstruction_offset: Vector2` / `footprint_shape_type: int` / **`selection_footprint_size: Vector2`** (UI 选择形状尺寸 — **新名,避免跟旧 `footprint_size: Vector2i` 冲突**;codex P1 #3)
- **`RtsBuildingActor.get_footprint_cells()` 算法改成: 用 `obstruction_shape` 的几何中心 + `obstruction.width / height` 计算 cells**,而不是 `position_2d` 当中心
- `RtsBuildingPlacement._compute_footprint_cells()` 同步改算法 (保持与 actor 一致 — 共享一个 helper,无双份漂移)
- 新增 `tools/path_trace_v2.gd` 标准化 trace utility (M0 启动前置,但 M0 内落地)
- 新增 baseline replay snapshot smoke (`smoke_pathfinding_baseline.tscn`),M0 启动前**必须**先跑生成基线
- 新增 M0 验收 smoke `smoke_obstruction_footprint_split.tscn` (验证 footprint vs obstruction 中心可错位)
- frontend 渲染层 (`rts_building_visualizer.gd`) **sprite 锚点保持 `position_2d` 不变** (F4 决策 A);**只动选择圈渲染**,改用 `footprint_shape.get_world_aabb(actor.position_2d)` 算外接矩形;**ghost 预览的 cells 高亮**改走新 `_compute_footprint_cells_from_shape` (玩家看到的占地 = 最终生效 obstruction 占地)

### 1.2 不做 (留给后续 M)

| 不做 | 原因 |
|---|---|
| 引入 `RtsObstructionManager` 单例 + 空间索引 | 那是 M2 |
| 单位的 obstruction_shape | M2 时 unit 才挂 obstruction (M0 单位用现有 collision_radius) |
| Multi-class passability (16-bit) | M1 |
| 替换 RtsBattleGrid 内部数据结构 (PackedInt32Array) | M1 |
| Hierarchical / Long / Vertex pathfinder | M4-M6 |
| Motion 重写 | M7 |
| Group filter / push pass | M8 |
| Formation | 下个 Epic |

### 1.3 核心改动文件清单

#### 新建 (4 个文件)

```
addons/logic-game-framework/example/rts-auto-battle/
├── logic/
│   └── obstruction/
│       ├── rts_obstruction_shape.gd        ← 基类 (data only)
│       ├── rts_obstruction_shape_static.gd ← OBB
│       └── rts_footprint_shape.gd          ← UI 形状
└── tools/
    └── path_trace_v2.gd                    ← 标准化 trace utility
```

#### 修改 (8 个文件)

```
addons/logic-game-framework/example/rts-auto-battle/
├── logic/
│   ├── rts_building_actor.gd               ← 加 obstruction_shape / footprint_shape 字段
│   │                                          + 改 get_footprint_cells 算法
│   ├── buildings/
│   │   └── rts_buildings.gd                ← 工厂注入新字段
│   ├── commands/
│   │   ├── rts_building_placement.gd       ← _compute_footprint_cells 改算法
│   │   └── rts_place_building_command.gd   ← 调用方一致性 (call obstruction_shape)
│   └── config/
│       └── rts_building_config.gd          ← StatBlock 加 obstruction_* / footprint_* 字段
└── frontend/
    ├── visualizers/
    │   ├── rts_building_visualizer.gd      ← sprite 锚点保持 actor.position_2d (F4-A 不变);只动选择圈渲染用 footprint_shape.get_world_aabb()
    │   └── rts_unit_visualizer.gd          ← (M0 单位不变, 但选择圈渲染要用 footprint)
    └── ui/
        └── build_panel.gd                  ← ghost 预览算 cells 用新算法
```

#### 新建 (smoke)

```
addons/logic-game-framework/example/rts-auto-battle/tests/battle/
├── smoke_pathfinding_baseline.tscn         ← M0 启动前置 (生成 baseline)
├── smoke_pathfinding_baseline.gd
├── smoke_obstruction_footprint_split.tscn  ← M0 验收
└── smoke_obstruction_footprint_split.gd
```

---

## 2. 子任务 (M0.1 → M0.7)

### M0.1 — Trace utility + baseline replay 准备 (启动前置, **早于 M0.2**)

**目标**: 为整个 Epic 准备验证基础设施。

**步骤**:
1. 新建 `tools/path_trace_v2.gd`,实现标准化 trace CSV writer (schema 见 [`../validation-strategy.md`](../validation-strategy.md), 待 Step B 写) — Step A 暂用以下 schema:
   ```
   tick, unit_id, team, kind, px, py, vx, vy, vmag,
   long_path_size, long_path_wp_json,
   short_path_size, short_path_wp_json,
   has_target, final_tx, final_ty, dist_final,
   obstruction_radius, clearance,
   region_id, global_region_id,
   failed_movements, ticket_state,
   activity
   ```
   未实现的字段先填占位值 (如 -1 / "")。
2. 新建 `smoke_pathfinding_baseline.tscn` + `.gd`,跑一份 master 当前状态 30s 战斗,dump trace + replay 序列化到 `%APPDATA%/Godot/app_userdata/Inkmon/0ad-baseline-master.csv` + `0ad-baseline-master.replay.json`。
3. 在 master 分支上**先跑一次** baseline smoke,把生成的 CSV / replay JSON copy 到 `tests/baselines/0ad-baseline-master.csv` (作为 git-tracked 基准文件 — 未来 M5/M7 跑同 smoke 应 bit-identical 这个文件)。
4. baseline 文件 size 大可以 commit 到 `tests/baselines/` 但加 `.gitignore` 注释,具体策略由 `validation-strategy.md` 定。

**完成标志**: `tests/baselines/0ad-baseline-master.csv` 存在 + 大小合理 (~几 MB) + replay 可用 LGF 既有 ReplayPlayer 重放成功。

### M0.2 — 引入 3 个 data class (纯 data,不挂逻辑)

**目标**: 落地数据结构。

**步骤**:
1. 新建 `logic/obstruction/rts_obstruction_shape.gd`:
   ```gdscript
   class_name RtsObstructionShape
   extends RefCounted

   enum Type { UNIT, STATIC }

   var type: Type
   var entity_id: String = ""
   var center: Vector2 = Vector2.ZERO    # 世界坐标 (绝对)
   var flags: int = 0                    # RtsObstructionFlags
   var control_group: String = ""
   var control_group_2: String = ""
   var tag: int = 0
   ```
2. 新建 `logic/obstruction/rts_obstruction_shape_static.gd`:
   ```gdscript
   class_name RtsObstructionShapeStatic
   extends RtsObstructionShape

   var width: float = 0.0
   var height: float = 0.0
   var rotation_rad: float = 0.0

   func _init() -> void:
       type = Type.STATIC

   func get_corners() -> Array[Vector2]:
       # OBB 4 角 (按 rotation_rad / width / height / center 算)
       ...

   func get_axes() -> Array[Vector2]:
       var u := Vector2(cos(rotation_rad), sin(rotation_rad))
       var v := Vector2(-sin(rotation_rad), cos(rotation_rad))
       return [u, v]
   ```
3. 新建 `logic/obstruction/rts_footprint_shape.gd`:
   ```gdscript
   class_name RtsFootprintShape
   extends RefCounted

   enum Type { CIRCLE, SQUARE }

   var type: Type = Type.CIRCLE
   var center_offset: Vector2 = Vector2.ZERO    # 相对 owner.position
   var size: Vector2 = Vector2(16.0, 16.0)      # CIRCLE: x=radius / SQUARE: 半宽 + 半高

   func contains(world_pos: Vector2, owner_pos: Vector2) -> bool:
       var local := world_pos - (owner_pos + center_offset)
       match type:
           Type.CIRCLE:
               return local.length_squared() <= size.x * size.x
           Type.SQUARE:
               return absf(local.x) <= size.x and absf(local.y) <= size.y
       return false

   func get_world_aabb(owner_pos: Vector2) -> Rect2:
       var c := owner_pos + center_offset
       match type:
           Type.CIRCLE:
               var r := size.x
               return Rect2(c.x - r, c.y - r, r * 2, r * 2)
           Type.SQUARE:
               return Rect2(c.x - size.x, c.y - size.y, size.x * 2, size.y * 2)
       return Rect2()
   ```
4. **不挂 RtsObstructionFlags**:M0 只用 `BLOCK_PATHFINDING` (= 1<<3),硬编码用 int,**不引入 RtsObstructionFlags class** (M2 引入 flags 完整枚举)。

**完成标志**: 3 个文件存在,`godot --headless --path . --import` 通过,无 type error。

### M0.3 — `RtsBuildingConfig.StatBlock` 加 4 个新字段

**目标**: 配置层定义建筑的 obstruction / footprint 几何。

**步骤**:
1. 修改 `logic/config/rts_building_config.gd`,`StatBlock` 加字段 — **注意命名: 新字段不能叫 `footprint_size`,避免跟旧 `footprint_size: Vector2i` 冲突**(codex P1 #3):
   ```gdscript
   # M0 新增 (从 footprint_size 派生默认值, 但允许配置覆盖):
   var obstruction_size: Vector2 = Vector2.ZERO          # OBB width × height (px); 默认 = footprint_size * cell_size
   var obstruction_offset: Vector2 = Vector2.ZERO        # 相对 position 的偏移; 默认 = ZERO
   var footprint_shape_type: int = 0                     # 0=CIRCLE, 1=SQUARE; 默认 CIRCLE
   var selection_footprint_size: Vector2 = Vector2.ZERO  # UI 选择形状尺寸 (CIRCLE: x=radius / SQUARE: 半宽 半高);
                                                         # 默认 = max(obstruction.w, obstruction.h) / 2
                                                         # ⚠️ 新字段叫 selection_footprint_size, 不叫 footprint_size_v2,
                                                         # 也不叫 footprint_size — 旧 footprint_size: Vector2i 保留到 M2 再删
   ```
2. **旧字段 `footprint_size: Vector2i` 保留** (M2 才删,向后兼容当前所有 smoke 数字)。新字段没显式配置时,走 fallback 从旧 `footprint_size` 派生:
   ```gdscript
   if raw.has("obstruction_size"):
       block.obstruction_size = raw["obstruction_size"]
   else:
       block.obstruction_size = Vector2(raw["footprint_size"]) * cell_size  # backward compat
   if raw.has("obstruction_offset"):
       block.obstruction_offset = raw["obstruction_offset"]
   if raw.has("footprint_shape_type"):
       block.footprint_shape_type = raw["footprint_shape_type"]
   if raw.has("selection_footprint_size"):
       block.selection_footprint_size = raw["selection_footprint_size"]
   else:
       # default = obstruction 外接圆半径
       block.selection_footprint_size = Vector2(maxf(block.obstruction_size.x, block.obstruction_size.y) * 0.5, 0.0)
   ```
3. 三个建筑 (barracks / archer_tower / crystal_tower) 的 raw config 暂时不显式加新字段,走 fallback;M0 验收完后,再有意把某个建筑的 obstruction_offset 改非零值验证错位生效。

**完成标志**: `RtsBuildingConfig.get_stats(kind).obstruction_size` 返回正确值,`smoke_resource_nodes / smoke_economy_demo` 等现有 smoke PASS (向后兼容)。

### M0.4 — `RtsBuildingActor` 加新字段 + 改 `get_footprint_cells` 算法

**目标**: 单位实例持有新数据,寻路占地从 obstruction_shape 几何中心算,而不是 position_2d。

**步骤**:
1. 修改 `logic/rts_building_actor.gd`,加字段:
   ```gdscript
   var obstruction_shape: RtsObstructionShapeStatic = null   # 寻路占地 (M2 注册到 ObstructionManager)
   var footprint_shape: RtsFootprintShape = null             # UI 选择
   ```
2. 改 `get_footprint_cells(grid)` 算法 — **核心 Bug 1 修复** (偶数尺寸偏置方向**严格保留旧"左上偏置"**,跟现有 `RtsBuildingPlacement._compute_footprint_cells` 完全一致 — 不能改方向,改了 AC6 漂移):
   ```gdscript
   func get_footprint_cells(grid) -> Array:
       if grid == null or obstruction_shape == null:
           return []
       # 用 obstruction_shape.center 算 cells (不再是 position_2d!)
       var obstr_center: Vector2 = obstruction_shape.center
       var center_cell: HexCoord = grid.world_to_coord(obstr_center)
       # 按 obstruction_size (px) ÷ cell_size 推 footprint_cells
       var cells_w: int = int(round(obstruction_shape.width / grid.cell_size))
       var cells_h: int = int(round(obstruction_shape.height / grid.cell_size))
       if cells_w <= 1 and cells_h <= 1:
           return [center_cell]
       # 偏置方向: 偶数尺寸"左上偏置" (上半左半),奇数居中.
       # 严格跟 RtsBuildingPlacement._compute_footprint_cells 旧实现一致,不改方向.
       var half_x_lo: int = cells_w / 2
       var half_x_hi: int = cells_w - 1 - half_x_lo
       var half_y_lo: int = cells_h / 2
       var half_y_hi: int = cells_h - 1 - half_y_lo
       var result: Array = []
       for dy in range(-half_y_lo, half_y_hi + 1):
           for dx in range(-half_x_lo, half_x_hi + 1):
               result.append(HexCoord.new(center_cell.q + dx, center_cell.r + dy))
       return result
   ```
3. **保留** `footprint_size: Vector2i` 字段 (M2 之前 frontend 部分代码可能仍读它),M2 一起删。
4. **新增** `RtsBuildingActor.sync_obstruction_shape()` 方法:
   ```gdscript
   ## 把 obstruction_shape.center 设为 position_2d + stats.obstruction_offset.
   ## 必须在 actor.position_2d 设置之后, place_building 之前调用一次.
   ## 由 RtsBuildings 工厂构造完后,调方在 set position_2d 之后立即调.
   func sync_obstruction_shape() -> void:
       if obstruction_shape == null:
           return
       var stats: RtsBuildingConfig.StatBlock = RtsBuildingConfig.get_stats(building_kind)
       obstruction_shape.center = position_2d + stats.obstruction_offset
   ```

**注意点**: `RtsBuildingActor.position_2d` 仍然是 sprite 渲染锚点 (frontend 用),**不再是寻路占地中心**。这是设计 — 允许 sprite 视觉中心和寻路逻辑中心错位。

**完成标志**:
- 当 `obstruction_offset = ZERO` 时 (默认),`get_footprint_cells()` 跟旧实现 bit-identical (smoke 全 PASS)
- 当 `obstruction_offset` 非零时 (新 smoke 测试),寻路 cells 跟着 obstruction.center 走,sprite 锚点不变

### M0.5 — `RtsBuildings` 工厂 (只填默认 shape) + sync 时机 + `RtsBuildingPlacement` 算法同步

**目标**: 工厂初始化新字段 — **只填 shape 默认 size / type / offset,不写 center**(因 factory 不知道最终 position);procedure / command 写完 position 后调 `sync_obstruction_shape()`;placement command 用新算法。

**重要时机修正** (codex P1 #2): 不能在 factory 里写 `obstruction_shape.center = position_2d + offset`,因为 factory **不知道最终 position_2d**(position 是 command/procedure 后续写的)。所以 factory 只填 size/offset/type 等"位置无关字段",center 在 sync 时才填。

**步骤**:
1. 修改 `logic/buildings/rts_buildings.gd` 的 `_create_from_kind` — **不写 center,不写 entity_id 也行(M0 工厂构造时还没 register,id 一般在 add_actor 时才确定)**:
   ```gdscript
   # 新增 (在 attribute_set / footprint_size 等设置之后, 跟 actor 一起返回前):
   var obstr := RtsObstructionShapeStatic.new()
   # obstr.entity_id 等 register 后由 sync_obstruction_shape() 填
   # obstr.center 等 position_2d 写完后由 sync_obstruction_shape() 填
   obstr.width = stats.obstruction_size.x
   obstr.height = stats.obstruction_size.y
   obstr.rotation_rad = 0.0   # 当前所有建筑无旋转, M2 加旋转支持
   obstr.flags = 1 << 3       # FLAG_BLOCK_PATHFINDING (M0 硬编码)
   actor.obstruction_shape = obstr

   var fp := RtsFootprintShape.new()
   fp.type = stats.footprint_shape_type as RtsFootprintShape.Type
   fp.size = stats.selection_footprint_size      # 见 M0.3 (注意: 是 selection_footprint_size, 不是 footprint_size_v2 / footprint_size)
   fp.center_offset = Vector2.ZERO               # 默认与 sprite 锚点重合 (玩家点 sprite 中心能选中); F5 决策 A
   actor.footprint_shape = fp
   ```
2. **改 procedure / command 调用顺序** — 在 `actor.position_2d = ...` / `actor.team_id = ...` 设完后,**在 `place_building` / `get_footprint_cells` 之前**调 `sync_obstruction_shape()`。

   **完整 call sites 清单** (codex P2 R2 反馈,grep 真实代码后列全):

   | # | 文件 | 行号 | call 类型 | M0 改造 |
   |---|---|---|---|---|
   | 1 | `logic/commands/rts_place_building_command.gd` | 81-90 (`apply`) | 玩家命令路径 (主流程) | sync 在 `_create_building_for_kind` 后, `place_building` 前 |
   | 2 | `core/rts_auto_battle_procedure.gd` | 188 (`place_building` 直调) | procedure 内部 setup | sync 在 procedure 调 `place_building` 前 |
   | 3 | `frontend/demo_rts_frontend.gd` | 164, 170 (`create_crystal_tower`) | demo setup 创双方水晶塔 | 每次 `create_crystal_tower()` 后 set position 再 sync |
   | 4 | `frontend/demo_rts_pathfinding.gd` | 115, 121, 269, 274 (`create_barracks` + `place_building`) | pathfinding demo 静态 + 动态障碍 | 4 处都加 sync (含动态生成 obstacle 的循环里) |
   | 5 | `logic/scenario/rts_scenario_harness.gd` | 92, 282-289, 301 (`_create_building_by_kind`) | scenario harness (含 `place_building` + `add_static_obstacle` 两路径) | 在 harness 内 set position 后, place_building 之前调 sync |
   | 6 | `frontend/preset/rts_match_preset.gd` | (整文件) `RtsMatchPreset` | match preset 加载 (主菜单 → demo) | 若 preset 内创建建筑则同样要 sync;**注意类名 `RtsMatchPreset`,不是 `RtsRtsMatchPreset`** (M0 文档之前写错过) |

   **改造模板** (以 1 号 `rts_place_building_command.gd:apply` 为例):
     ```gdscript
     # 现有 (M2.x):
     building.position_2d = world_pos
     building.team_id = team_id
     ...
     var footprint: Array = building.get_footprint_cells(rts_world.rts_grid)
     rts_world.rts_grid.place_building(building.get_id(), footprint)

     # M0 改造 (在 get_footprint_cells 之前 sync):
     building.position_2d = world_pos
     building.team_id = team_id
     ...
     building.sync_obstruction_shape()             # ← 新增,M0 必须在 get_footprint_cells 前调
     # M0 也要把 control_group 在这里设 (因 factory 时还没 team_id):
     building.obstruction_shape.entity_id = building.get_id()
     building.obstruction_shape.control_group = str(building.team_id)
     ...
     var footprint: Array = building.get_footprint_cells(rts_world.rts_grid)
     rts_world.rts_grid.place_building(building.get_id(), footprint)
     ```
   - **6 个 call sites 全部按上面清单改完** (见上表)。**任何漏 sync 的地方,obstruction.center 仍是 ZERO,寻路会以为建筑在 (0,0)** — 故 M0.7 加专门 smoke 验证 + 加 `Log.assert_crash(actor.obstruction_shape.center != Vector2.ZERO or stats.obstruction_offset == Vector2.ZERO)` 在 `place_building` 入口兜底。
3. 修改 `logic/commands/rts_building_placement.gd._compute_footprint_cells`:
   - 现有签名 `(center: HexCoord, footprint_size: Vector2i)` 保留 (向后兼容)
   - 新增重载 `_compute_footprint_cells_from_shape(shape: RtsObstructionShapeStatic, grid: RtsBattleGrid) -> Array`
   - 内部把"按 cells_w / cells_h 推 footprint cells"抽出独立 helper (`_compute_footprint_cells_core(center_cell: HexCoord, cells_w: int, cells_h: int) -> Array`),actor.get_footprint_cells 和这俩签名都 call 同一个 core,**避免双份算法漂移**
4. **修改 ghost preview 链路** (`logic/commands/rts_building_placement.gd` 里的 ghost 验证逻辑 + `frontend/demo_rts_frontend.gd` 里的 placement preview): ghost 当前 cells 计算用同一个 core helper,确保玩家看到的占地和最终 obstruction 占地一致。

**完成标志**: placement 链路端到端通,放下建筑后 `actor.obstruction_shape.center` 等于 `actor.position_2d + obstruction_offset`,grid 写入的 cells 跟新算法一致。**任何漏 sync 的入口**会被 M0.7 步骤 1 新 smoke 抓到 (validate `obstruction_shape.center != ZERO`)。

### M0.6 — Frontend 选择圈 / ghost 渲染对齐 (sprite 锚点不动)

**目标**: **sprite 渲染锚点 = `actor.position_2d` 不变** (F4 决策 A,贯穿全文档统一);**只动**选择圈 / ghost cells 高亮 这两处,让玩家看到的"占地高亮"和最终生效 obstruction 占地一致。

**步骤**:
1. 修改 `frontend/visualizers/rts_building_visualizer.gd`:
   - **sprite 锚点 = `actor.position_2d`,不动** (跟现有完全一致,F4 决策 A)
   - 选择圈 (M2.3 加的) 渲染: 用 `actor.footprint_shape.get_world_aabb(actor.position_2d)` 算外接矩形,画选择高亮 (这是唯一改动)
2. 修改 `frontend/visualizers/rts_unit_visualizer.gd`:
   - **sprite 锚点 = `actor.position_2d`,不动**
   - M0 单位的 footprint_shape 暂时不引入 (M2 时单位才有),选择圈走 `actor.collision_radius` (现有逻辑不动)
3. 修改 `frontend/ui/build_panel.gd` 的 ghost 预览 + `frontend/demo_rts_frontend.gd` 的 placement preview:
   - ghost sprite 锚点跟鼠标 (跟现有逻辑一致,不动)
   - **ghost cells 高亮 (绿/红)** 走新算法 `_compute_footprint_cells_from_shape` (走 M0.5 步骤 3 的 core helper),**让玩家看到的占地和最终 obstruction 占地一致**
   - **这是 M0 真正的视觉改进点**:玩家放建筑前 ghost 的占地高亮 = 放下后单位实际绕走的 cells = obstruction 占的 cells

**完成标志**:
- demo_rts_frontend F6 跑,**ghost 占地高亮** 和 **放下后单位实际绕走 cells** 一致
- sprite 渲染位置不变 (玩家看不出 sprite 移位 — 跟 M2.3 完全一致)
- 玩家鼠标点击 sprite 中心仍能选中建筑 (Footprint.contains 正确工作)

### M0.7 — 新 smoke + Validation 全套 + commit

**步骤**:
1. 新增 `tests/battle/smoke_obstruction_footprint_split.gd`:
   - 创建一个 RtsBattleProcedure
   - 放下一个 barracks,**人为设置 obstruction_offset = (16, 16)** (config 临时改 / 或 procedure 直接 mutate actor.obstruction_shape)
   - 验证:
     - `actor.position_2d == 原位置` (sprite 渲染锚点不变)
     - `actor.obstruction_shape.center == 原位置 + (16, 16)`
     - `actor.get_footprint_cells(grid)` 占的 cells 中心在 `obstruction_shape.center` 而不是 `position_2d`
     - `actor.footprint_shape.contains(原位置, 原位置)` true (玩家能点中)
     - 一个单位寻路绕这个 barracks,实际绕走 cells 是 obstruction 占的 cells (不是 sprite 周围)
   - 输出 `SMOKE_TEST_RESULT: PASS|FAIL`
2. 跑现有 14 项 smoke + LGF 73 unit + replay bit-identical:
   ```
   M2.3 末态 baseline (本 milestone 0 漂移):
   - run_tests.tscn: 73/73 PASS
   - smoke_rts_auto_battle: ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00
   - smoke_castle_war_minimal: ticks=193 left_win unit_to_building=4 archer_anti_air=1
   - smoke_player_command: gold_remaining=20 wood_remaining=50 log=3
   - smoke_player_command_production: ticks=600 left_spawned=7 max_eastward=254.74 gold=20
   - smoke_production: ticks=600 left=7 right=7 max_left_eastward=118.51
   - smoke_crystal_tower_win: ticks=2 left_win
   - smoke_resource_nodes: ticks=200 alive=5 max_drift=0
   - smoke_harvest_loop: ticks=600 alive=5 team_gold=140 team_wood=212 cycle=5
   - smoke_economy_demo: ticks=900 melee_to_ct=31
   - smoke_ai_vs_player_full_match: ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9
   - smoke_replay_bit_identical: seed=42 frames=9 events=20 deep-equal
   - smoke_determinism: tick_diff=0
   - smoke_frontend_main: visualizers=10 alive_after_3.0s=10
   ```
3. 跑新 smoke `smoke_obstruction_footprint_split` PASS。
4. F6 demo_rts_frontend **视觉验收 + 录屏 30s**:
   - 玩家放 1 个 barracks + 1 个 archer_tower
   - 单位 (4-6 个) 绕这两个建筑走
   - 视觉确认:**单位贴墙绕走时 sprite 不穿建筑 sprite** (Bug 1 消失)
   - 录屏文件名 `0ad-migration-M0-after.mp4` 落到本地 (不进 git,作为体验点 1 证据)
5. submodule 内 commit + 主仓 bump pointer:
   ```
   feat(rts-m3): M0 done — Footprint / Obstruction shape 拆分 + Bug 1 修复
   ```

**完成标志**: 全套 14 项 + 新 smoke + replay bit-identical + LGF 73/73 + 视觉录屏。

---

## 3. 验收准则 (10 AC)

### AC1 — 3 个 data class 落地 ✅ **done 2026-05-03**
- ✅ `logic/obstruction/rts_obstruction_shape.gd` (基类) + `rts_obstruction_shape_static.gd` (OBB) + `rts_footprint_shape.gd` (UI) 文件存在
- ✅ `class_name` + 字段定义按 [`data-structures.md`](../data-structures.md) §2 §3 (基类 type/entity_id/center/flags/control_group/control_group_2/tag;static 子类 width/height/rotation_rad + get_corners + get_axes;footprint type/center_offset/size + contains + get_world_aabb)
- ✅ `--import` 通过 (exit=0),update_scripts_classes 注册 3 个 class_name,无 type error
- ✅ LGF 73/73 + smoke_rts_auto_battle 0 漂移(byte-identical baseline)

### AC2 — `RtsBuildingActor` 持有新字段 🔒 pending
- 字段 `obstruction_shape: RtsObstructionShapeStatic` + `footprint_shape: RtsFootprintShape` 存在,默认 null
- 工厂 `RtsBuildings._create_from_kind` 调用后,这两字段非 null
- 字段值跟 `RtsBuildingConfig.StatBlock` 配置一致

### AC3 — `RtsBuildingConfig.StatBlock` 字段扩展 🔒 pending
- 新增 4 个字段 (`obstruction_size / obstruction_offset / footprint_shape_type / selection_footprint_size`),按 M0.3 步骤
- 旧字段 `footprint_size: Vector2i` 保留 (向后兼容,M2 删除)
- 没显式配置新字段时,fallback 从旧 `footprint_size` 派生

### AC4 — `get_footprint_cells` 用新算法 + 当 offset=0 时 bit-identical 旧行为 🔒 pending
- `RtsBuildingActor.get_footprint_cells(grid)` 内部用 `obstruction_shape.center` 算 cells (不再用 `position_2d`)
- 当 `obstruction_offset = ZERO` 时,返回 cells 跟旧算法 bit-identical
- 当 `obstruction_offset` 非零时,返回 cells 中心跟着 obstruction.center 走
- `RtsBuildingPlacement._compute_footprint_cells_from_shape` 同步,跟 actor 共享 helper (无双份算法漂移)

### AC5 — `smoke_obstruction_footprint_split` PASS 🔒 pending
- 新 smoke 文件 (`tests/battle/smoke_obstruction_footprint_split.tscn` + `.gd`) 存在
- 验证 5 项 (见 M0.7 步骤 1):position_2d 不变 / obstruction.center 偏移 / cells 跟 obstruction 走 / footprint contains 原位置 true / 单位寻路绕 obstruction 占地
- exit code = 0,输出 `SMOKE_TEST_RESULT: PASS`

### AC6 — Validation 全套 0 漂移 (M2.3 末态 14 项 + LGF 73) 🔒 pending
- 所有 smoke 数字跟 §M0.7 步骤 2 列表 bit-identical
- LGF 73/73 PASS
- replay seed=42 deep-equal

### AC7 — Trace utility 落地 ✅ **done** (Step C 之前由 Agent 落地)
- ✅ `addons/.../tools/path_trace_v2.gd` (7910 B,24 字段 CSV writer)
- ✅ `addons/.../tests/battle/smoke_pathfinding_baseline.{tscn,gd}` PASS (900 ticks / 6155 trace rows / 111 replay events / exit code 0)
- ✅ `addons/.../tests/baselines/0ad-baseline-master.csv` (882 KB / 6156 行,byte-identical 跨 run)
- ✅ `addons/.../tests/baselines/0ad-baseline-master.replay.json` (34 KB)
- ✅ Regress 验证 `smoke_rts_auto_battle` 0 漂移(left_win ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 完全对齐 CLAUDE.md baseline)
- baseline 文件可被未来 M5/M7 用作 bit-identical 参照

### AC8 — Frontend 视觉一致性: ghost cells == placed cells == unit path cells (体验点 1, 客观化) 🔒 pending

**主验收 (客观, smoke 自动验证)**:
- 新 smoke `smoke_obstruction_footprint_split` 内增加一段:
  1. 进 placement mode,模拟鼠标 hover 某 (x, y) 位置
  2. 取此时 ghost 高亮的 cells (Set A)
  3. 实际下令 enqueue PlaceBuildingCommand → flush procedure
  4. 取此时 actor.get_footprint_cells() 实际占的 cells (Set B)
  5. spawn 一个单位寻路绕这个 building,从单位实际走过的 cells trace (Set C: 单位经过的 cells 不能跟 Set B 重叠)
  6. **断言**: A == B 且 (B ∩ C) = ∅
- 输出 `SMOKE_TEST_RESULT: PASS` 才算 AC8 主验收通过

**辅助验收 (主观, 仅作补充)**:
- F6 demo_rts_frontend,玩家放 barracks + archer_tower 各 ≥1 个,4-6 个单位绕走
- 录屏 `0ad-migration-M0-after.mp4` 留底 (作为体验点 1 给用户的演示材料,不是 pass 条件)
- **诚实告知用户**: M0 完成时 sprite 锚点未变 (F4 决策 A),所以视觉差异有限;真正"贴墙绕角不穿建筑 sprite"完整体感需 M6 vertex pathfinder 加 32px 亚 cell 精度才能完成。M0 的 Bug 1 修复体现在"ghost / placed / path 三者 cells 精确一致" — 这是后续 M2-M6 的基础

### AC9 — 选择 / 点击 / placement ghost 全链路一致 🔒 pending
- 玩家鼠标点击建筑 sprite → 选中 (Footprint.contains 正确)
- placement ghost 占地高亮 (cells 高亮) 跟最终生效 obstruction 一致
- ESC / 右键取消 placement 仍工作 (M2.3 既有功能不退化)

### AC10 — 不动 LGF submodule core/ stdlib/ 🔒 pending
- 所有改动在 `addons/logic-game-framework/example/rts-auto-battle/` 内
- `addons/logic-game-framework/core/` 和 `stdlib/` 没动 (即使是间接 import)

---

## 4. 决策表 (F 系列)

### F1 — `obstruction_offset` 默认值

- **A. ZERO** (跟 sprite 中心重合,跟现有行为完全 bit-identical) — Recommended
- B. 自动算 OBB 几何中心和 sprite 中心的差 (按现有 `get_footprint_cells` 偶数偏置算)
- C. 让每个建筑 config 必须显式配 (强制思考)

> default A;选 A 因为 0 漂移最容易满足 AC6;**Bug 1 修复不是靠 offset 非零,是靠 cells 用 obstruction_shape.center 算 → 当 offset=0 时 obstruction.center == position_2d,新算法跟旧算法在 cells 计算上完全 bit-identical,没有差异**。Bug 1 体验差异来自:**ghost 预览** + **单位实际绕走 cells** 现在精确匹配,而不是依赖 offset。

### F2 — `RtsObstructionFlags` 是否在 M0 引入完整枚举

- **A. M0 不引入,硬编码 `1 << 3` (BLOCK_PATHFINDING)** — Recommended
- B. M0 引入完整枚举 (BLOCK_MOVEMENT / BLOCK_FOUNDATION / BLOCK_CONSTRUCTION / BLOCK_PATHFINDING / MOVING / DELETE_UPON_CONSTRUCTION)

> default A;flags 完整枚举留 M2 引入 ObstructionManager 时一起做 (因为那时才真正按 flag 区分行为)。M0 阶段所有建筑 flag 都是 BLOCK_PATHFINDING,一个常量够用。

### F3 — `RtsBattleGrid.place_building` API 是否要在 M0 改

- **A. 不改,保持 `(actor_id: String, footprint_cells: Array) -> void`,内部自然受益于 actor.get_footprint_cells 新算法** — Recommended
- B. 改成 `(shape: RtsObstructionShapeStatic) -> void`,直接传 shape

> default A;M0 不改 grid API。M1 重构 grid 数据结构时一起改 API。

### F4 — Frontend visualizer sprite 锚点策略

- **A. sprite 锚点 = position_2d (跟现有完全一致),选择圈用 footprint_shape** — Recommended
- B. sprite 锚点 = obstruction_shape.center (sprite 视觉跟着寻路占地走)

> default A;A 保持 sprite 视觉位置不变 (玩家不感知差异);Bug 1 修复来自 cells 精度,不来自 sprite 移位。**未来美术想让 sprite 跟 obstruction 偏移视觉错位,可以反过来用 obstruction_offset = sprite_offset_inverse 配置**。

### F5 — `footprint_shape.center_offset` 的语义

- **A. 相对 owner.position 的偏移 (UI 跟 sprite 走)** — Recommended
- B. 相对 obstruction_shape.center 的偏移 (UI 跟寻路占地走)
- C. 绝对世界坐标 (跟其他都解耦)

> default A;让 footprint 默认跟 sprite 锚点重合 (玩家点 sprite 中心能选中)。**B 选项视未来需求 (建筑 sprite 跟 obstruction 错位且 UI 选择圈想跟着 sprite 而不是 obstruction) 时再加 helper**。

---

## 5. 子任务进度 (M0.1 - M0.7)

- [x] **M0.1** — Trace utility + baseline replay 准备 ✅ **done** (Step C 之前由 Agent 落地;evidence 见 §AC7)
- [x] **M0.2** — 引入 3 个 data class ✅ **done 2026-05-03** (3 文件落地;`--import` 通过 + 3 class_name 注册;LGF 73/73 + smoke_rts_auto_battle ticks=347 attacks=74 melee_max=24.00 0 漂移)
- [ ] **M0.3** — `RtsBuildingConfig.StatBlock` 加新字段 ⏭️ **下一步**
- [ ] **M0.4** — `RtsBuildingActor` 加字段 + 改 `get_footprint_cells` 🔒 pending
- [ ] **M0.5** — `RtsBuildings` 工厂 + `RtsBuildingPlacement` 算法同步 🔒 pending
- [ ] **M0.6** — Frontend 渲染锚点对齐 🔒 pending
- [ ] **M0.7** — 新 smoke + Validation 全套 + commit 🔒 pending

---

## 6. 残余风险 (M0 启动前预判)

| # | 风险 | 缓解 |
|---|---|---|
| R1 | 新算法在偶数 footprint_size 时偏置方向跟旧算法不一致 → 既有 smoke 中建筑覆盖 cells 漂移 → smoke 数字漂 | 算法严格保留旧"左上偏置"方向 (上半左半);M0.4 实现时跟 M2.1 placement 实现 byte-identical 对照单元测试 |
| R2 | obstruction_offset = ZERO 时,新算法返回 cells 跟旧实现不 bit-identical (浮点精度) | 用 `int(round(...))` 显式整数化;先写 unit test 确认所有 footprint_size ∈ {(1,1), (2,2)} cases 与旧算法 bit-identical |
| R3 | frontend visualizer 改 sprite 锚点逻辑后视觉位置错位 | 选 F4 A;sprite 锚点 = position_2d 不变;只动选择圈/ghost 渲染 |
| R4 | trace utility 落地不及时,M0.7 跑 baseline 时 utility 有 bug | M0.1 优先做,且作为 M0 启动前置;trace utility bug 不能阻塞 M0 实现,先用占位 schema (-1 / "" 填未实现字段) |
| R5 | replay determinism 漂移 (即使 obstruction_offset = 0) | M0 启动前先在 master 跑一份 replay seed=42 baseline;M0 末跑对比 deep-equal |
| R6 | M0 改完 demo_rts_frontend 视觉看起来 OK,但单位实际绕走精度仍受 RtsBattleGrid 32px 粒度限制 (Bug 1 不能靠 M0 完全消) | M0 验收只到 "cells 跟 obstruction 一致" + "ghost 预览精准";完整视觉对齐 (亚 cell 精度) 等 M6 vertex pathfinder 才能解决;**用户体验点 1 验收时明确告知"M0 只解决 cells 一致性,完美贴墙绕角等 M6"** |
| R7 | F1 选项 A (offset=ZERO) 让 M0 看不出明显视觉差异,用户体验点 1 不满意 | M0.7 步骤 5 时,**故意把 barracks 临时配 obstruction_offset=(16,16)** 做对比演示 (展示拆分后能力),验收完恢复 ZERO |

---

## 7. 决策来源

- 范围: [`../README.md`](../README.md) §0.2 §0.3 (D2 决策: 复刻 Position / Obstruction / Footprint / Motion 4 component)
- 数据结构: [`../data-structures.md`](../data-structures.md) §2 §3
- Bug 1 诊断: [`../../../Handoff-2026-05-03-pathfinding-diag.md`](../../../Handoff-2026-05-03-pathfinding-diag.md) Bug 1 段
- 既有 footprint 算法: `addons/logic-game-framework/example/rts-auto-battle/logic/rts_building_actor.gd:127-147` + `logic/commands/rts_building_placement.gd:101-115`
- F1-F5 决策默认值: 本文档 §决策表
- M2.3 末态 baseline (AC6): `archive/2026-05-03-rts-m2-3-ui-hud/Summary.md`

---

## 8. 完成后下一步 (M1 启动)

M0 完成 + 用户体验点 1 通过后,启动 M1 — Navcell Grid + 16-bit Passability Class。

M1 的依赖:
- M0 引入的 3 个 data class (`RtsObstructionShape*` / `RtsFootprintShape`) → M1 不动这些
- `tools/path_trace_v2.gd` → M1 加 `region_id` 字段 (M4 才填)
- `tests/baselines/0ad-baseline-master.csv` → M1 末跑同 smoke,对比寻路路径 bit-identical

详见 [`M1-navcell-grid.md`](M1-navcell-grid.md) (Step B 产出)。
