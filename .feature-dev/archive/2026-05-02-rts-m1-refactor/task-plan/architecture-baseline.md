# RTS Auto-Battle 架构基线 — 锁定决策与总图

> 本文档是 RTS M1 重构（Phase 1/2/3）的稳定 spec。**跨 phase 不变**；任何代码都要能从这张图反推到具体决策。
>
> 如发现决策需要调整，**先停下来跟用户对齐**再改本文，不要让代码与本文不一致。

---

## 1. 顶层定位

**玩法（决策 D1）**：城堡战争 — 玩家 + AI 各占地图一侧；各有水晶塔 + 建造区；建筑周期生产单位；单位自动出击对方水晶塔，路上遇敌优先战斗。

**架构哲学**：
- 三层硬性边界（`core / logic / frontend`）— 照搬 hex 已验证的 LGF 范式
- **流式 simulation**（决策 D2）— fixed-tick + 边跑边录，**不再"算完再渲染"**
- **逻辑纯 2D**（决策 D3）— 连续坐标 + 离散高度；3D 仅在表演层
- **业界标本对齐**：单位/碰撞 = WC3，AI 行为 = OpenRA Activity，Tick = 经典 RTS fixed-tick

---

## 2. 锁定决策清单（共 13 条）

| # | 决策 | 来源讨论 |
|---|---|---|
| **D1** | 玩法 = 城堡战争（玩家 + AI 混合驱动）| 用户确认 |
| **D2** | Sim 流式驱动，**不能"一次算完再渲染"** | 用户确认 |
| **D3** | 自研逻辑层寻路 + 形状碰撞，**不用 NavigationServer2D / NavigationAgent2D** | 用户确认 |
| **D3-A** | Sim = 30Hz **fixed-tick**，frontend 渲染插值，全局 RNG with seed | 业界 + 用户确认 |
| **D3-B** | 寻路 = **2D grid + A***（不用 navmesh polygon） | 用户确认 |
| **D3-C** | 单位 = **2D 圆**, 建筑 = **2D AABB**（3D 仅在 frontend） | 用户确认 |
| **D3-D** | **Layer-based 多层**（GROUND / AIR），武器有 `target_layer_mask` | 业界标准 + 用户确认 |
| **D3-E** | 高度 = **离散 `tile.height` + 命中/视野 resolver**（WC3 / AoE 风格，不是真 Y 坐标） | 业界 + 用户确认 |
| **D3-F** | Grid 走 **ultra-grid-map plugin**, RTS 包一层 `RtsBattleGrid` wrapper（不动插件本身） | 用户确认 |
| **D3-G** | **Cell size = 32**, 标准单位 `collision_radius = 14`（数值起点，可调） | 用户确认 |
| **E** | 建筑 = `RtsBattleActor → RtsBuildingActor + building_kind: String` 工厂模式（照抄 hex `EnvironmentActor + StoneWall` 模式） | 用户确认 |
| **F** | 单位/建筑用连续 `collision_radius: float`（WC3 风），不用 small/medium/large enum | 用户确认 |
| **G** | 动态避障 = **4 层全要**（spatial hash + steering + stuck/repath + group formation） | 用户确认 |

---

## 3. 模块拓扑（依赖方向严格自上而下）

```
┌─────────────────────────────────────────────────────────────┐
│ FRONTEND (rts-auto-battle/frontend/)                        │
│ • 3D 渲染 (Vector2 → Vector3 lift)                          │
│ • BattleDirector + Visualizer 复用 hex 表演四层管线         │
│ • 流式消费 event_timeline (边跑边写边播)                    │
│ • 渲染 fixed-tick 之间用 alpha 插值                         │
└──────────────────────┬──────────────────────────────────────┘
                       │ 只消费 events，不读 logic state
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ LOGIC (rts-auto-battle/logic/)                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Actor 家族                                          │   │
│  │ RtsBattleActor (基类)                               │   │
│  │ ├── RtsUnitActor      (单位)                        │   │
│  │ └── RtsBuildingActor  (建筑, building_kind: String) │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Activity 系统 (Phase 2, 解 S3 + 单位 FSM)           │   │
│  │ Activity (基类)                                     │   │
│  │ ├── MoveTo / AttackMove / Attack / Idle             │   │
│  │ └── ChildActivity 嵌套, NextActivity 队列, Cancel 递归 │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ AI 层 (Phase 1 拆分)                                │   │
│  │ RtsAIStrategy        (无状态, decide → Intent)      │   │
│  │ RtsUnitController    (有状态, 持 Activity / cooldown / target) │
│  │ RtsAutoTargetSystem  (Phase 2: 集中扫描 + targetInterval) │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 移动 / 避障 (D3-B + G 4 层)                         │   │
│  │ RtsBattleGrid       (wrapper 包 GridMapModel)       │   │
│  │ RtsPathfinding      (调 GridPathfinding.astar)      │   │
│  │ RtsSpatialHash      (Phase 2)                       │   │
│  │ RtsUnitSteering     (Phase 2: separation+deflection)│   │
│  │ RtsStuckDetector    (Phase 2: stuck → local repath) │   │
│  │ RtsGroupFormation   (Phase 2 末: 多单位同令队形)    │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Action / Skill (Phase 1 修复 S2)                    │   │
│  │ RtsBasicAttackAction extends Action.BaseAction      │   │
│  │ Pre/Atomic/Post 三段 (与 hex damage_action 同构)    │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Production / Player Command (Phase 2 新增)          │   │
│  │ RtsProductionSystem  (建筑周期 spawn unit)          │   │
│  │ RtsPlayerCommand     (放置/升级/拆除建筑)           │   │
│  │ RtsBuildingPlacement (合法性 + 占用 pathing cells)  │   │
│  └─────────────────────────────────────────────────────┘   │
└──────────────────────┬──────────────────────────────────────┘
                       │ Procedure 内化主循环 (Phase 1 修复 S1)
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ CORE (rts-auto-battle/core/)                                │
│ RtsBattleProcedure  (S1: tick_once 内化所有推进)            │
│ RtsWorldGameplayInstance  (持 grid + spatial_hash + systems)│
│ RtsBattleEvents  (强类型 + to_dict/from_dict/is_match)      │
└──────────────────────┬──────────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ ULTRA-GRID-MAP plugin  (D3-F: 不动)                         │
│ • GridMapModel (SQUARE, cell_size=32)                       │
│ • GridPathfinding.astar (passable/cost callback 注入)       │
│ • GridTileData.height (D3-E 离散高度直接用)                 │
│ • Bresenham line / FOV (LOS 判定直接复用)                   │
│ • plugin 用 HexCoord 类作 cell 坐标 (即使 SQUARE grid)      │
│   RTS 约定: cell = HexCoord, world = Vector2                │
└──────────────────────┬──────────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ LGF CORE  (Action / Event / Ability / EventProcessor / Tag) │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. RtsBattleActor 基类骨架

```gdscript
## RtsBattleActor — RTS 战斗 Actor 基类（Unit / Building 共用）
class_name RtsBattleActor extends Actor

# === 公共（与 hex 同构）===
var ability_set: BattleAbilitySet
var collision_profile: CollisionProfile
var _is_dead: bool = false

# === RTS 专属 ===
var position_2d: Vector2 = Vector2.ZERO       # 连续逻辑坐标（事实）
var velocity: Vector2 = Vector2.ZERO          # 当前速度（steering 计算后写）
var collision_radius: float = 14.0            # WC3 风连续值
var movement_layer: int = MovementLayer.GROUND
var team_id: int = -1

# === Footprint（子类 override）===
func get_footprint_cells(grid: RtsBattleGrid) -> Array[HexCoord]:
    return [grid.world_to_coord(position_2d)]   # 默认: 中心 cell

func writes_to_pathing_map() -> bool:
    return false   # Unit 默认 false（WC3 风）, Building override 为 true

# === 高度（D3-E）===
func get_terrain_height(grid: RtsBattleGrid) -> int:
    if movement_layer == MovementLayer.AIR: return 99
    return grid.get_tile_height_at(position_2d)

# === LGF 契约（照抄 hex_battle_actor）===
func get_attribute_set() -> RtsBattleActorAttributeSet: ...  # 子类 override
func _on_id_assigned() -> void: ...                          # 同步 owner_id
func check_death() -> bool: ...
func is_dead() -> bool: ...
func is_pre_event_responsive() -> bool: return not _is_dead
func get_ability_set() -> BattleAbilitySet: return ability_set

# === 录像（lift 2D → 3D）===
func _get_position() -> Vector3:
    return Vector3(position_2d.x, get_render_height(), position_2d.y)

func get_render_height() -> float:
    return 8.0 if movement_layer == MovementLayer.AIR else 0.0
```

### 子类家族

```gdscript
class_name RtsUnitActor extends RtsBattleActor
# 字段: unit_class / current_target_id / activity（Phase 2）/ cooldown_tag_id

class_name RtsBuildingActor extends RtsBattleActor
# 字段: building_kind: String / footprint_cells / production_state
# 工厂: RtsBuildings.create_crystal_tower() / create_barracks() / ...
# 不为 CrystalTower 单独建子类（照抄 hex StoneWall 模式）

func writes_to_pathing_map() -> bool:
    return true  # 建筑硬阻挡, footprint 写入 pathing map
```

---

## 5. Procedure 主循环（S1 修复后）

```gdscript
class_name RtsBattleProcedure extends BattleProcedure

const SIM_DT := 1.0 / 30.0   # fixed tick (D3-A)

func tick_once(_unused_dt: float) -> void:
    # 注意: _unused_dt 是父类签名要求, 内部一律用 SIM_DT
    
    # 1. 几何索引（Phase 2 加 spatial_hash）
    grid.update_dirty_actors()
    
    # 2. 玩家命令处理（Phase 2 新增）
    player_command_queue.drain_and_apply(world)
    
    # 3. 建筑生产（Phase 2 新增）
    production_system.tick(SIM_DT)
    
    # 4. 框架级 system tick
    world.base_tick(SIM_DT)
    world.broadcast_projectile_events()
    
    # 5. AutoTarget 集中扫描（Phase 2; Mindustry 风, 每 20 tick 一次）
    if _tick_counter % 20 == 0:
        auto_target_system.refresh_all()
    
    # 6. 单位推进
    for actor in world.get_alive_actors():
        actor.ability_set.tick(SIM_DT, logic_time)
        var controller := unit_controllers.get(actor.id)
        if controller:
            controller.tick(SIM_DT)
            steering.compute(actor, SIM_DT)        # Phase 2
            stuck_detector.check(actor, SIM_DT)    # Phase 2
        actor.position_2d += actor.velocity * SIM_DT
    
    # 7. 录像帧（流式，每 tick 都写）
    recorder.record_current_frame()
    
    # 8. 胜负判定（D1: 水晶塔死 = 战斗结束）
    if _check_crystal_tower_destroyed():
        emit_signal("battle_finished", winner_team)
    
    _tick_counter += 1
```

**关键不变量**（实现时严格遵守）：
- 5 处 demo / smoke 的 `per_tick` callback **全部消失**
- 统一走 `world.start_battle()` → `procedure.tick_once()`
- `dt` 永远是 `SIM_DT`，**不依赖** wall-clock delta
- 全局 `RtsRng` autoload 持种子，所有 randomness 走它

---

## 6. 决定性 Replay 数据结构

```
RtsRecording = {
  "world_snapshot": {
    "grid_config": {...},          # cell_size, dimensions
    "buildings_initial": [...],    # 起手建筑（水晶塔 + 玩家放的）
    "rng_seed": 12345,
    "configs": { positionFormats: { Unit: "vec2_xy", Building: "vec2_xy" } }
  },
  "event_timeline": [              # 流式: 边跑边 append
    { tick: 0, events: [...] },
    { tick: 1, events: [...] },
    ...
  ],
  "player_commands": [             # 玩家命令也录, 重放时按 tick 重放（Phase 2）
    { tick: 45, type: "place_building", kind: "barracks", pos: [128, 64] },
    ...
  ],
  "meta": { total_ticks: ..., winner_team: 0 }
}
```

**重放保证**：固定 RNG seed + 同样的 player_commands 按 tick 重放 → sim 应该产出 bit-identical 的 event_timeline。

> Phase 1 只验证 light determinism（同 seed → 同 winner + 同 final state hash）；
> bit-identical event_timeline 验证留到 Phase 2（player commands 接入后）。

---

## 7. WC3 风的 collision / pathing 双层模型

| 数据 | 分辨率 | 内容 | 谁写入 |
|---|---|---|---|
| **Pathing map** | cell_size = 32（grid cell）| `walkable / cost / height / terrain_type` | **建筑写入，单位不写** |
| **Unit position** | 浮点 `Vector2`（连续）| 单位真实位置 | actor.position_2d |
| **Spatial hash bucket** | 64（更大 bucket）| 单位 ID 索引（近邻查询）| Phase 2 加 |

**单位 collision_radius 推荐档位**（参考 WC3 数值经验）：

| 单位类型 | collision_radius | 说明 |
|---|---|---|
| 小型（小兵 / 苦工）| 10-12 | 4-5 个能挤进 2x2 cells |
| 标准（步兵 / 弓箭手）| 14-16 | 1 cell 大概 1 个 |
| 中型（骑兵 / 重装）| 20-24 | 占 2x2 cells 中心 |
| 大型（巨魔 / 攻城）| 32-40 | 跨 3x3 cells |
| 飞行 | 0 或独立 layer | 不参与地面碰撞 |

---

## 8. 业界对齐速查表

| 我们的设计 | 业界标本 |
|---|---|
| Fixed-tick 30Hz + 渲染插值 | Gaffer "Fix Your Timestep" / OpenRA 25Hz / 几乎所有 RTS |
| Activity 链 + ChildActivity | OpenRA `Activity.cs` |
| Cell-based pathing + 单位连续坐标 | WC3 pathing map 模型 |
| Collision radius float（不写入 pathing）| WC3 `Movement - Collision Size` |
| Layer-based GROUND/AIR + target_layer_mask | StarCraft / WC3 / Mindustry / OpenRA |
| 离散 tile height + LOS resolver | WC3 / AoE / SC2 高低地系统 |
| AutoTarget 集中扫 + targetInterval 缓存 | Mindustry `AIController.targetInterval` |
| Spatial hash 近邻查询 | 通用空间索引（每个商业 RTS 都有变体）|
| Steering: separation + deflection | WC3 / SC1 经典 boids-lite |
| Stuck detection + local repath | WC3 / WC3 mod / AoE |
| Group formation movement | WC3 / SC2 编队系统 |

---

## 9. 与 hex 的差异点速查表

| 维度 | hex | rts |
|---|---|---|
| 时间机制 | ATB（速度累积）| Fixed 30Hz tick |
| 位置 | HexCoord（离散）| Vector2（连续）|
| 占格 | 严格 1 格 1 单位 | cell 是寻路索引，单位是连续圆，多占自然 |
| 阻挡 | actor 占格阻挡 | **只建筑写 pathing map**（WC3）|
| 行为 | Skill timeline keyframe | Activity 链 / 树（Phase 2）|
| AI | AIStrategy 无状态 ✓ | 同样无状态 + UnitController 持 runtime |
| 录像 | 跑完一次性写 | **流式: 边跑边 append**（D2）|
| 视觉 | 录像→Director 回放 | 同 Director 但消费"当前 tick" events |
| 高度 | 不区分 | tile.height 离散等级 + LOS |
| 多层 | 不区分 | GROUND / AIR + target_layer_mask |

---

## 10. 三大根偏离的修复对照（Phase 1 修复目标）

来自 2026-04-30 的架构审查报告（详见 `archive/2026-04-30-rts-auto-battle/`）。

| 偏离 | 现状（M0）| Phase 1 修复目标 |
|---|---|---|
| **S1**: World/Procedure 倒挂，主循环散落 5 处 | 5 处 demo/smoke 的 `per_tick` callback 复制 | Procedure 内化 `tick_once`，统一走 `world.start_battle()` |
| **S2**: Basic attack 绕过 BaseAction | `RtsBasicAttackAction extends RefCounted` 静态 helper | 改造为 `extends Action.BaseAction`, 走 ExecutionContext + TargetSelector |
| **S3**: AI 有状态共享 | `RtsBasicAI` 持 actor / agent / last_decision | 拆 `RtsAIStrategy`（无状态）+ `RtsUnitController`（有状态）|
| **M4**: cooldown 是裸 float | `attack_cooldown_remaining: float` | 走 `tag_container.add_auto_duration_tag` |

---

## 11. 维护约定

- **本文 = spec**：实现时如发现需要改架构，**停下来跟用户对齐**再改本文
- **不改 LGF submodule core / stdlib**：硬约束，沿用 M0 期间约定
- **三层依赖方向**：`core ← logic ← frontend`，frontend 不能被 core/logic 引用
- **新决策落盘**：本文是唯一决策来源；Phase 文档只引用本文，不重复决策

---

## 12. 未来扩展承诺（不在 M1 范围内但承诺不踩坑）

### 12.1 从 2D 圆 → 3D 胶囊体的字段演进路径

如果未来某天玩法演进到需要真 3D 碰撞（例如多层桥/隧道、地面 vs 飞行单位互相阻挡的高度博弈），**架构无需推翻重做**：

| 当前（M1）| 未来（如需）|
|---|---|
| `position_2d: Vector2` | `position_3d: Vector3`（保留 `position_2d` getter 返回 xz 投影做兼容）|
| `collision_radius: float` | 加 `collision_height: float`（默认 = 2.0 \* radius，胶囊体上下半球的圆柱中段长度）|
| `RtsBattleGrid` 2D pathing | 加 `multi_level_grid` overlay（每层独立 GridMapModel）|

**关键不变量**：单位/建筑碰撞数据是 actor 上的属性，从 `radius: float` 升级到 `(radius, height)` 是字段加法，不是改架构。Action / Event / AbilitySet / TargetSelector 全部不需要改。

> 这条承诺**不影响 M1 实现**；M1 内任何代码不应预先抛出 `position_3d` 字段或 stub。只是确保未来真有 3D 需求时不需要重头设计。

### 12.2 从 GROUND/AIR 二层 → 多层（含 WATER / UNDERGROUND）

Movement layer 当前是 `enum { GROUND, AIR }`，未来可平滑扩展为 `enum { GROUND, AIR, WATER, UNDERGROUND }`：
- Tile 加 `terrain_type: enum { LAND, WATER, CLIFF, ... }` 配合 `is_passable_for_layer(layer)` callback
- 武器 `target_layer_mask` 是 bitmask，加新 layer 直接加 bit
- 跨 layer 攻击（如"鱼叉只能打 WATER 单位"）走 weapon target_layer_mask 自然支持

### 12.3 从 RTS 单地图 → 多地图 / 关卡链

当前 `RtsBattleGrid` 是 procedure 级别（一局战斗一个），未来若要做"过场战斗 → 切地图 → 继续打"：
- World 级别加 `map_loader / map_transition` 系统
- `RtsBattleProcedure` 仍是单地图寿命；多地图通过 procedure chain 串联
- 不影响本文 §3 的依赖方向
