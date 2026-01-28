# 强类型事件系统重构

## TL;DR

> **Quick Summary**: 重构事件系统为强类型，创建三层架构（core/逻辑/表演），提升类型安全
> 
> **Deliverables**:
> - `hex-atb-battle-core/` 共享数据层
> - 强类型 `GameEvent` 框架事件
> - 强类型 `ReplayData` 录像数据
> - `GridMapConfig` 序列化支持
> - 更新文档最佳实践
> 
> **Estimated Effort**: Large
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Phase 1 → Phase 2 → Phase 3 → Phase 4

---

## Context

### Original Request
创建前后端公用的事件数据层，使用强类型替代 Dictionary，实现逻辑层和表演层共享数据结构。

### Interview Summary
**Key Discussions**:
- 三层架构：hex-atb-battle-core (共享) + hex-atb-battle (逻辑) + hex-atb-battle-frontend (表演)
- 框架层类应自带 `to_dict()` / `from_dict()` 序列化方法
- Actor 使用轻量级 `ActorRecordData` 而非重建完整实例
- GameEvent 框架层也需要重构为强类型

**Research Findings**:
- `HexCoord` 已有完整的 to_dict/from_dict
- `GridMapConfig` 需要添加序列化方法
- `replay_keys.gd` 无引用，可安全删除

### Metis Review
**Identified Gaps** (addressed):
- Actor 反序列化策略 → 使用 ActorRecordData 轻量级类
- GameEvent 重构范围 → 同时重构框架层
- 向后兼容性 → 保持录像 JSON 格式不变

---

## Work Objectives

### Core Objective
将事件系统从 Dictionary 模式重构为强类型类模式，实现编译时类型检查和 IDE 自动补全。

### Concrete Deliverables
- `addons/logic-game-framework/example/hex-atb-battle-core/events/battle_events.gd` - 项目事件类
- `addons/logic-game-framework/stdlib/replay/replay_data.gd` - 录像数据结构
- `addons/logic-game-framework/core/events/game_event.gd` - 重构为强类型事件基类
- `addons/ultra-grid-map/core/grid_types.gd` - 添加序列化方法
- `addons/logic-game-framework/docs/README.md` - 添加最佳实践文档

### Definition of Done
- [ ] 所有事件类有 `create()`, `to_dict()`, `from_dict()`, `is_match()` 方法
- [ ] 录像文件 JSON 格式与重构前完全一致
- [ ] 表演层 Visualizers 使用强类型事件
- [ ] 文档包含三层架构最佳实践

### Must Have
- 强类型事件类（DamageEvent, HealEvent, MoveEvent, DeathEvent）
- 序列化往返测试通过
- 现有测试全部通过

### Must NOT Have (Guardrails)
- 不修改录像文件 JSON 结构
- 不在单个 commit 混合多个阶段
- 不创建循环依赖（core ← battle ← frontend）

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES
- **User wants tests**: Manual verification + 现有测试
- **Framework**: godot --headless

### Automated Verification

**现有测试回归**（已存在，直接运行）:
```bash
godot --headless addons/logic-game-framework/tests/run_tests.tscn
# Assert: 退出码 0
```

**编译检查**（无需额外文件）:
```bash
godot --headless --quit
# Assert: 退出码 0，无编译错误
```

### 手动验证步骤

**录像格式兼容性验证**（在 Task 7 完成后执行）:
1. 运行 `hex-atb-battle-frontend/main.tscn` 生成新录像
2. 对比新旧录像 JSON 结构是否一致
3. 验证 key 名称（camelCase）和数据类型未变

**序列化往返验证**（在 Task 3, 4, 5, 6 完成后执行）:
1. 在 GDScript 控制台测试：
   ```gdscript
   # ReplayData 往返测试
   var record := ReplayData.BattleRecord.new()
   record.meta = ReplayData.BattleMeta.new()
   record.meta.battle_id = "test"
   var dict := record.to_dict()
   var restored := ReplayData.BattleRecord.from_dict(dict)
   assert(restored.meta.battle_id == "test")
   
   # BattleEvents 往返测试
   var damage := BattleEvents.DamageEvent.create("actor_1", 50.0)
   var d := damage.to_dict()
   var restored_damage := BattleEvents.DamageEvent.from_dict(d)
   assert(restored_damage.target_actor_id == "actor_1")
   assert(restored_damage.damage == 50.0)
   ```

**回放功能验证**（在 Task 8 完成后执行）:
1. 运行 `hex-atb-battle-frontend/main.tscn`
2. 加载现有录像文件
3. 验证伤害飘字、治疗飘字、移动动画、死亡动画正常显示

### 可选：创建自动化测试文件

如果需要自动化测试，可在 Task 7 完成后创建以下测试文件：

**`addons/logic-game-framework/tests/test_serialization_roundtrip.gd`**:
```gdscript
extends SceneTree

func _init() -> void:
    var success := run_tests()
    quit(0 if success else 1)

func run_tests() -> bool:
    var all_passed := true
    
    # Test ReplayData.BattleMeta
    var meta := ReplayData.BattleMeta.new()
    meta.battle_id = "test_battle"
    meta.recorded_at = 1234567890
    var meta_dict := meta.to_dict()
    var meta_restored := ReplayData.BattleMeta.from_dict(meta_dict)
    if meta_restored.battle_id != "test_battle":
        push_error("BattleMeta roundtrip failed")
        all_passed = false
    
    # Test BattleEvents.DamageEvent
    var damage := BattleEvents.DamageEvent.create("actor_1", 50.0, BattleEvents.DamageType.MAGICAL)
    var damage_dict := damage.to_dict()
    var damage_restored := BattleEvents.DamageEvent.from_dict(damage_dict)
    if damage_restored.target_actor_id != "actor_1" or damage_restored.damage != 50.0:
        push_error("DamageEvent roundtrip failed")
        all_passed = false
    if damage_restored.damage_type != BattleEvents.DamageType.MAGICAL:
        push_error("DamageEvent damage_type roundtrip failed")
        all_passed = false
    
    if all_passed:
        print("All roundtrip tests passed")
    return all_passed
```

> **注意**：上述测试文件是可选的。主要验证通过现有测试 + 手动验证完成。

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: 创建 hex-atb-battle-core 目录结构
├── Task 2: GridMapConfig 添加序列化方法
└── Task 3: 创建 ReplayData 强类型类（含 ActorInitData）

Wave 2 (After Wave 1):
├── Task 4: 重构 GameEvent 为强类型
└── Task 5: 创建 BattleEvents 项目事件类
(Task 6 已合并到 Task 3)

Wave 3 (After Wave 2):
├── Task 7: 更新 BattleRecorder 使用强类型
├── Task 8: 更新表演层 Visualizers
└── Task 8.5: 迁移逻辑层 Actions 和 Skills

Wave 4 (After Wave 3):
└── Task 9: 删除 replay_keys.gd 和 replay_events.gd

Wave 5 (After Wave 4):
└── Task 10: 更新文档
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 5 | 2, 3 |
| 2 | None | 3 | 1 |
| 3 | 2 | 7 | 1 |
| 4 | None | 5, 7 | 1, 2, 3 |
| 5 | 1, 4 | 7, 8, 8.5 | None |
| ~~6~~ | ~~1~~ | ~~7~~ | ~~5~~ (已合并到 Task 3) |
| 7 | 3, 5 | 9 | 8, 8.5 |
| 8 | 5 | 9 | 7, 8.5 |
| 8.5 | 5 | 9 | 7, 8 |
| 9 | 7, 8, 8.5 | 10 | None |
| 10 | 9 | None | None |

---

## TODOs

- [x] 1. 创建 hex-atb-battle-core 目录结构

  **What to do**:
  - 创建 `addons/logic-game-framework/example/hex-atb-battle-core/` 目录
  - 创建 `addons/logic-game-framework/example/hex-atb-battle-core/events/` 子目录
  - 创建 README.md 说明目录用途和三层架构

  **Must NOT do**:
  - 不创建任何逻辑代码（只是目录结构）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Tasks 5, 6
  - **Blocked By**: None

  **References**:
  - `addons/logic-game-framework/example/hex-atb-battle/` - 参考现有目录结构

  **Acceptance Criteria**:
  - [ ] `ls addons/logic-game-framework/example/hex-atb-battle-core/events/` 成功
  - [ ] README.md 存在且包含三层架构说明

  **Commit**: YES
  - Message: `feat(core): create hex-atb-battle-core directory structure`
  - Files: `addons/logic-game-framework/example/hex-atb-battle-core/`

---

- [x] 2. GridMapConfig 添加序列化方法

  **What to do**:
  - 在 `GridMapConfig` 类中添加 `to_dict()` 方法
  - 添加 `static func from_dict(d: Dictionary) -> GridMapConfig` 方法
  - 序列化所有 @export 属性：grid_type, orientation, draw_mode, size, tile_size, origin, rows, columns, radius

  **实现示例**:
  ```gdscript
  func to_dict() -> Dictionary:
      return {
          "grid_type": grid_type,
          "orientation": orientation,
          "draw_mode": draw_mode,
          "size": size,
          "tile_size": { "x": tile_size.x, "y": tile_size.y },
          "origin": { "x": origin.x, "y": origin.y },
          "rows": rows,
          "columns": columns,
          "radius": radius,
      }
  
  static func from_dict(d: Dictionary) -> GridMapConfig:
      var config := GridMapConfig.new()
      config.grid_type = d.get("grid_type", GridType.HEX) as GridType
      config.orientation = d.get("orientation", Orientation.POINTY) as Orientation
      config.draw_mode = d.get("draw_mode", DrawMode.ROW_COLUMN) as DrawMode
      config.size = d.get("size", 32.0)
      var ts: Dictionary = d.get("tile_size", {})
      config.tile_size = Vector2(ts.get("x", 32.0), ts.get("y", 32.0))
      var og: Dictionary = d.get("origin", {})
      config.origin = Vector2(og.get("x", 0.0), og.get("y", 0.0))
      config.rows = d.get("rows", 10)
      config.columns = d.get("columns", 10)
      config.radius = d.get("radius", 5)
      return config
  ```

  **Must NOT do**:
  - 不修改现有属性定义
  - 不改变类的继承关系

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Task 3
  - **Blocked By**: None

  **References**:
  - `addons/ultra-grid-map/core/grid_types.gd` - 目标文件
  - `addons/ultra-grid-map/core/hex_coord.gd:55-88` - to_dict/from_dict 参考实现

  **Acceptance Criteria**:
  - [ ] `GridMapConfig.new().to_dict()` 返回包含所有 9 个属性的 Dictionary
  - [ ] `GridMapConfig.from_dict(config.to_dict())` 往返测试通过

  **Commit**: YES
  - Message: `feat(grid): add serialization to GridMapConfig`
  - Files: `addons/ultra-grid-map/core/grid_types.gd`

---

- [x] 3. 创建 ReplayData 强类型类

  **What to do**:
  - 创建 `addons/logic-game-framework/stdlib/replay/replay_data.gd`
  - 定义以下内部类，每个类实现 `to_dict()`, `from_dict()` 方法

  **类结构定义**:
  ```gdscript
  class_name ReplayData
  extends RefCounted
  
  const PROTOCOL_VERSION = "2.0"
  
  class BattleRecord:
      var version: String = PROTOCOL_VERSION
      var meta: BattleMeta
      var configs: Dictionary = {}
      var map_config: Dictionary = {}  # 保持 Dictionary，兼容不同地图类型
      var initial_actors: Array = []   # Array of ActorInitData
      var timeline: Array = []         # Array of FrameData
      
      func to_dict() -> Dictionary:
          var actors_arr: Array = []
          for a in initial_actors:
              actors_arr.append(a.to_dict() if a is ActorInitData else a)
          var timeline_arr: Array = []
          for f in timeline:
              timeline_arr.append(f.to_dict() if f is FrameData else f)
          return {
              "version": version,
              "meta": meta.to_dict() if meta else {},
              "configs": configs,
              "mapConfig": map_config,
              "initialActors": actors_arr,
              "timeline": timeline_arr,
          }
      
      static func from_dict(d: Dictionary) -> BattleRecord:
          var record := BattleRecord.new()
          record.version = d.get("version", PROTOCOL_VERSION)
          record.meta = BattleMeta.from_dict(d.get("meta", {}))
          record.configs = d.get("configs", {})
          record.map_config = d.get("mapConfig", {})
          record.initial_actors = []
          for a in d.get("initialActors", []):
              record.initial_actors.append(ActorInitData.from_dict(a))
          record.timeline = []
          for f in d.get("timeline", []):
              record.timeline.append(FrameData.from_dict(f))
          return record
  
  class BattleMeta:
      var battle_id: String = ""
      var recorded_at: int = 0
      var tick_interval: int = 100
      var total_frames: int = 0
      var result: String = ""
      
      func to_dict() -> Dictionary:
          return {
              "battleId": battle_id,
              "recordedAt": recorded_at,
              "tickInterval": tick_interval,
              "totalFrames": total_frames,
              "result": result,
          }
      
      static func from_dict(d: Dictionary) -> BattleMeta:
          var meta := BattleMeta.new()
          meta.battle_id = d.get("battleId", "")
          meta.recorded_at = d.get("recordedAt", 0)
          meta.tick_interval = d.get("tickInterval", 100)
          meta.total_frames = d.get("totalFrames", 0)
          meta.result = d.get("result", "")
          return meta
  
  class FrameData:
      var frame: int = 0
      var events: Array = []  # Array of Dictionary (事件保持 Dictionary)
      
      func to_dict() -> Dictionary:
          return { "frame": frame, "events": events }
      
      static func from_dict(d: Dictionary) -> FrameData:
          var fd := FrameData.new()
          fd.frame = d.get("frame", 0)
          fd.events = d.get("events", [])
          return fd
  
  class ActorInitData:
      var id: String = ""
      var type: String = ""
      var config_id: String = ""
      var display_name: String = ""
      var team: Variant = 0
      var position: Array = []
      var attributes: Dictionary = {}
      var abilities: Array = []
      var tags: Dictionary = {}
      
      ## 从 Actor 实例创建 ActorInitData（用于录像）
      static func create(actor: Actor) -> ActorInitData:
          var data := ActorInitData.new()
          data.id = actor.id
          data.type = actor.type
          data.config_id = actor.config_id
          data.display_name = actor.display_name
          data.team = actor.team
          data.position = actor.getPositionSnapshot()  # 使用 Actor 的快照方法
          data.attributes = actor.getAttributeSnapshot()
          data.abilities = actor.getAbilitySnapshot()
          data.tags = actor.getTagSnapshot()
          return data
      
      func to_dict() -> Dictionary:
          return {
              "id": id, "type": type, "configId": config_id,
              "displayName": display_name, "team": team,
              "position": position, "attributes": attributes,
              "abilities": abilities, "tags": tags,
          }
      
      static func from_dict(d: Dictionary) -> ActorInitData:
          var data := ActorInitData.new()
          data.id = d.get("id", "")
          data.type = d.get("type", "")
          data.config_id = d.get("configId", "")
          data.display_name = d.get("displayName", "")
          data.team = d.get("team", 0)
          data.position = d.get("position", [])
          data.attributes = d.get("attributes", {})
          data.abilities = d.get("abilities", [])
          data.tags = d.get("tags", {})
          return data
  ```

  **Must NOT do**:
  - 不修改现有 BattleRecorder 代码（后续任务处理）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Task 7
  - **Blocked By**: Task 2 (需要 GridMapConfig 序列化)

  **References**:
  - `addons/logic-game-framework/stdlib/replay/battle_recorder.gd:73-88` - 现有录像数据结构
  - `addons/logic-game-framework/stdlib/replay/replay_keys.gd` - 现有 key 定义（将被替代）

  **Acceptance Criteria**:
  - [ ] `ReplayData.BattleRecord.from_dict(record.to_dict())` 往返测试通过
  - [ ] 序列化结果的 JSON key 与现有格式完全一致（camelCase）

  **Commit**: YES
  - Message: `feat(replay): add strongly-typed ReplayData classes`
  - Files: `addons/logic-game-framework/stdlib/replay/replay_data.gd`

---

- [x] 4. 重构 GameEvent 为强类型

  **What to do**:
  - 在 `addons/logic-game-framework/core/events/game_event.gd` 中定义事件基类和强类型事件
  - 保留现有工厂函数作为兼容层（标记 deprecated）

  **类结构定义**:
  ```gdscript
  class_name GameEvent
  extends RefCounted
  
  # ========== 事件类型常量（保留兼容） ==========
  const ABILITY_ACTIVATE_EVENT := "abilityActivate"
  const ACTOR_SPAWNED_EVENT := "actorSpawned"
  # ... 其他常量保持不变
  
  # ========== 事件基类 ==========
  class Base:
      var kind: String = ""
      func to_dict() -> Dictionary:
          return { "kind": kind }
      static func is_match(d: Dictionary) -> bool:
          return false  # 子类覆盖
  
  # ========== 强类型事件类 ==========
  class ActorSpawned extends Base:
      var actor_id: String = ""
      var actor_data: Dictionary = {}
      
      func _init():
          kind = ACTOR_SPAWNED_EVENT
      
      static func create(actor_id: String, actor_data: Dictionary) -> ActorSpawned:
          var e := ActorSpawned.new()
          e.actor_id = actor_id
          e.actor_data = actor_data
          return e
      
      func to_dict() -> Dictionary:
          return { "kind": kind, "actorId": actor_id, "actor": actor_data }
      
      static func from_dict(d: Dictionary) -> ActorSpawned:
          var e := ActorSpawned.new()
          e.actor_id = d.get("actorId", "")
          e.actor_data = d.get("actor", {})
          return e
      
      static func is_match(d: Dictionary) -> bool:
          return d.get("kind") == ACTOR_SPAWNED_EVENT
  
  class AttributeChanged extends Base:
      var actor_id: String = ""
      var attribute: String = ""
      var old_value: float = 0.0
      var new_value: float = 0.0
      var source: Dictionary = {}
      
      func _init():
          kind = ATTRIBUTE_CHANGED_EVENT
      
      static func create(actor_id: String, attribute: String, old_value: float, new_value: float, source: Dictionary = {}) -> AttributeChanged:
          var e := AttributeChanged.new()
          e.actor_id = actor_id
          e.attribute = attribute
          e.old_value = old_value
          e.new_value = new_value
          e.source = source
          return e
      
      func to_dict() -> Dictionary:
          var d := { "kind": kind, "actorId": actor_id, "attribute": attribute, "oldValue": old_value, "newValue": new_value }
          if not source.is_empty():
              d["source"] = source
          return d
      
      static func from_dict(d: Dictionary) -> AttributeChanged:
          var e := AttributeChanged.new()
          e.actor_id = d.get("actorId", "")
          e.attribute = d.get("attribute", "")
          e.old_value = d.get("oldValue", 0.0)
          e.new_value = d.get("newValue", 0.0)
          e.source = d.get("source", {})
          return e
      
      static func is_match(d: Dictionary) -> bool:
          return d.get("kind") == ATTRIBUTE_CHANGED_EVENT
  
  # ... 为其他事件类型创建类似的强类型类:
  # - AbilityActivate, AbilityGranted, AbilityRemoved, AbilityActivated
  # - AbilityTriggered, ExecutionActivated, TagChanged, StageCue, ActorDestroyed
  
  # ========== 旧工厂函数（标记 deprecated，保持兼容） ==========
  ## @deprecated Use ActorSpawned.create() instead
  static func create_actor_spawned_event(actor) -> Dictionary:
      return { "kind": ACTOR_SPAWNED_EVENT, "actor": actor }
  # ... 其他工厂函数保持不变，添加 @deprecated 注释
  ```

  **需要创建的强类型类**（共 11 个）:
  1. `ActorSpawned` - actorSpawned
  2. `ActorDestroyed` - actorDestroyed
  3. `AttributeChanged` - attributeChanged
  4. `AbilityGranted` - abilityGranted
  5. `AbilityRemoved` - abilityRemoved
  6. `AbilityActivated` - abilityActivated
  7. `AbilityTriggered` - abilityTriggered
  8. `ExecutionActivated` - executionActivated
  9. `TagChanged` - tagChanged
  10. `StageCue` - stageCue
  11. `AbilityActivate` - abilityActivate

  **Must NOT do**:
  - 不删除现有工厂函数（保持向后兼容）
  - 不修改事件的 Dictionary 结构（key 名保持 camelCase）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (独立)
  - **Blocks**: Tasks 5, 7
  - **Blocked By**: None

  **References**:
  - `addons/logic-game-framework/core/events/game_event.gd` - 目标文件（现有 149 行）
  - `addons/logic-game-framework/example/hex-atb-battle/events/replay_events.gd` - 项目事件参考

  **Acceptance Criteria**:
  - [ ] 所有 11 个事件类型有对应的强类型类
  - [ ] 现有工厂函数仍可用（兼容性）
  - [ ] `GameEvent.AttributeChanged.from_dict(event.to_dict())` 往返测试通过
  - [ ] 序列化结果的 JSON key 与现有格式完全一致（camelCase）

  **Commit**: YES
  - Message: `feat(events): refactor GameEvent to strongly-typed classes`
  - Files: `addons/logic-game-framework/core/events/game_event.gd`

---

- [x] 5. 创建 BattleEvents 项目事件类

  **What to do**:
  - 创建 `addons/logic-game-framework/example/hex-atb-battle-core/events/battle_events.gd`
  - 定义 `DamageEvent`, `HealEvent`, `MoveStartEvent`, `MoveCompleteEvent`, `DeathEvent`
  - 迁移 `DamageType` 枚举和转换函数

  **类结构定义**:
  ```gdscript
  class_name BattleEvents
  extends RefCounted
  
  # ========== 枚举 ==========
  enum DamageType { PHYSICAL, MAGICAL, PURE }
  
  # ========== 事件基类 ==========
  class Base:
      var kind: String = ""
      func to_dict() -> Dictionary:
          return { "kind": kind }
      static func is_match(d: Dictionary) -> bool:
          return false
  
  # ========== DamageEvent ==========
  class DamageEvent extends Base:
      var target_actor_id: String = ""
      var damage: float = 0.0
      var damage_type: DamageType = DamageType.PHYSICAL
      var source_actor_id: String = ""
      var is_critical: bool = false
      var is_reflected: bool = false
      
      func _init():
          kind = "damage"
      
      static func create(
          target_actor_id: String,
          damage: float,
          damage_type: DamageType = DamageType.PHYSICAL,
          source_actor_id: String = "",
          is_critical: bool = false,
          is_reflected: bool = false
      ) -> DamageEvent:
          var e := DamageEvent.new()
          e.target_actor_id = target_actor_id
          e.damage = damage
          e.damage_type = damage_type
          e.source_actor_id = source_actor_id
          e.is_critical = is_critical
          e.is_reflected = is_reflected
          return e
      
      func to_dict() -> Dictionary:
          var d := {
              "kind": kind,
              "target_actor_id": target_actor_id,
              "damage": damage,
              "damage_type": BattleEvents._damage_type_to_string(damage_type),
              "is_critical": is_critical,
              "is_reflected": is_reflected,
          }
          if source_actor_id != "":
              d["source_actor_id"] = source_actor_id
          return d
      
      static func from_dict(d: Dictionary) -> DamageEvent:
          var e := DamageEvent.new()
          e.target_actor_id = d.get("target_actor_id", "")
          e.damage = d.get("damage", 0.0)
          e.damage_type = string_to_damage_type(d.get("damage_type", "physical"))
          e.source_actor_id = d.get("source_actor_id", "")
          e.is_critical = d.get("is_critical", false)
          e.is_reflected = d.get("is_reflected", false)
          return e
      
      static func is_match(d: Dictionary) -> bool:
          return d.get("kind") == "damage"
  
  # ========== HealEvent ==========
  class HealEvent extends Base:
      var target_actor_id: String = ""
      var heal_amount: float = 0.0
      var source_actor_id: String = ""
      
      func _init():
          kind = "heal"
      
      static func create(target_actor_id: String, heal_amount: float, source_actor_id: String = "") -> HealEvent:
          var e := HealEvent.new()
          e.target_actor_id = target_actor_id
          e.heal_amount = heal_amount
          e.source_actor_id = source_actor_id
          return e
      
      func to_dict() -> Dictionary:
          var d := { "kind": kind, "target_actor_id": target_actor_id, "heal_amount": heal_amount }
          if source_actor_id != "":
              d["source_actor_id"] = source_actor_id
          return d
      
      static func from_dict(d: Dictionary) -> HealEvent:
          var e := HealEvent.new()
          e.target_actor_id = d.get("target_actor_id", "")
          e.heal_amount = d.get("heal_amount", 0.0)
          e.source_actor_id = d.get("source_actor_id", "")
          return e
      
      static func is_match(d: Dictionary) -> bool:
          return d.get("kind") == "heal"
  
  # ========== MoveStartEvent ==========
  class MoveStartEvent extends Base:
      var actor_id: String = ""
      var from_hex: Dictionary = {}  # { "q": int, "r": int }
      var to_hex: Dictionary = {}
      
      func _init():
          kind = "move_start"
      
      static func create(actor_id: String, from_hex: Dictionary, to_hex: Dictionary) -> MoveStartEvent:
          var e := MoveStartEvent.new()
          e.actor_id = actor_id
          e.from_hex = from_hex
          e.to_hex = to_hex
          return e
      
      func to_dict() -> Dictionary:
          return { "kind": kind, "actor_id": actor_id, "from_hex": from_hex, "to_hex": to_hex }
      
      static func from_dict(d: Dictionary) -> MoveStartEvent:
          var e := MoveStartEvent.new()
          e.actor_id = d.get("actor_id", "")
          e.from_hex = d.get("from_hex", {})
          e.to_hex = d.get("to_hex", {})
          return e
      
      static func is_match(d: Dictionary) -> bool:
          return d.get("kind") == "move_start"
  
  # ========== MoveCompleteEvent ==========
  class MoveCompleteEvent extends Base:
      var actor_id: String = ""
      var from_hex: Dictionary = {}
      var to_hex: Dictionary = {}
      
      func _init():
          kind = "move_complete"
      
      static func create(actor_id: String, from_hex: Dictionary, to_hex: Dictionary) -> MoveCompleteEvent:
          var e := MoveCompleteEvent.new()
          e.actor_id = actor_id
          e.from_hex = from_hex
          e.to_hex = to_hex
          return e
      
      func to_dict() -> Dictionary:
          return { "kind": kind, "actor_id": actor_id, "from_hex": from_hex, "to_hex": to_hex }
      
      static func from_dict(d: Dictionary) -> MoveCompleteEvent:
          var e := MoveCompleteEvent.new()
          e.actor_id = d.get("actor_id", "")
          e.from_hex = d.get("from_hex", {})
          e.to_hex = d.get("to_hex", {})
          return e
      
      static func is_match(d: Dictionary) -> bool:
          return d.get("kind") == "move_complete"
  
  # ========== DeathEvent ==========
  class DeathEvent extends Base:
      var actor_id: String = ""
      var killer_actor_id: String = ""
      
      func _init():
          kind = "death"
      
      static func create(actor_id: String, killer_actor_id: String = "") -> DeathEvent:
          var e := DeathEvent.new()
          e.actor_id = actor_id
          e.killer_actor_id = killer_actor_id
          return e
      
      func to_dict() -> Dictionary:
          var d := { "kind": kind, "actor_id": actor_id }
          if killer_actor_id != "":
              d["killer_actor_id"] = killer_actor_id
          return d
      
      static func from_dict(d: Dictionary) -> DeathEvent:
          var e := DeathEvent.new()
          e.actor_id = d.get("actor_id", "")
          e.killer_actor_id = d.get("killer_actor_id", "")
          return e
      
      static func is_match(d: Dictionary) -> bool:
          return d.get("kind") == "death"
  
  # ========== 辅助函数 ==========
  static func _damage_type_to_string(damage_type: DamageType) -> String:
      match damage_type:
          DamageType.PHYSICAL: return "physical"
          DamageType.MAGICAL: return "magical"
          DamageType.PURE: return "pure"
          _: return "unknown"
  
  static func string_to_damage_type(s: String) -> DamageType:
      match s:
          "physical": return DamageType.PHYSICAL
          "magical": return DamageType.MAGICAL
          "pure": return DamageType.PURE
          _: return DamageType.PHYSICAL
  ```

  **Must NOT do**:
  - 不删除原 `replay_events.gd`（后续任务处理）
  - 不修改事件的 Dictionary key 名（保持 snake_case）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **跨目录访问机制**:
  - `BattleEvents` 使用 `class_name` 声明为全局类
  - GDScript 会自动扫描所有 `.gd` 文件中的 `class_name` 声明
  - **无需**在 `project.godot` 中配置
  - **无需**使用 `preload` 或 `const`
  - 任何目录的代码都可以直接使用 `BattleEvents.DamageEvent.create()`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 6)
  - **Blocks**: Tasks 7, 8, 8.5
  - **Blocked By**: Tasks 1, 4

  **References**:
  - `addons/logic-game-framework/example/hex-atb-battle/events/replay_events.gd` - 现有事件定义（将被替代）
  - `addons/logic-game-framework/core/events/game_event.gd` - 框架事件参考（Task 4 完成后）

  **Acceptance Criteria**:
  - [ ] 5 个项目事件类型有对应的强类型类
  - [ ] `DamageType` 枚举已迁移
  - [ ] `BattleEvents.DamageEvent.from_dict(event.to_dict())` 往返测试通过
  - [ ] 序列化结果与现有 `HexBattleReplayEvents` 格式完全一致

  **Commit**: YES
  - Message: `feat(battle-core): add strongly-typed BattleEvents`
  - Files: `addons/logic-game-framework/example/hex-atb-battle-core/events/battle_events.gd`

---

- [x] 6. ~~创建 ActorRecordData 类~~ **[已合并到 Task 3]**

  > **注意**：此任务已合并到 Task 3 的 `ReplayData.ActorInitData` 类中。
  > `ActorInitData` 现在包含 `create(actor: Actor)` 静态方法，可以从 Actor 实例创建录像数据。
  > 
  > 不再需要单独的 `ActorRecordData` 类。

---

- [x] 7. 更新 BattleRecorder 使用强类型

  **What to do**:
  - 修改 `addons/logic-game-framework/stdlib/replay/battle_recorder.gd`
  - 使用 `ReplayData` 类替代手动构建 Dictionary
  - 使用 `ReplayData.ActorInitData.create(actor)` 替代 `_capture_actor_init_data`
  - 删除对 `ReplayKeys` 的依赖

  **代码重构示例**:

  **1. 成员变量修改**:
  ```gdscript
  # Before:
  var configs: Dictionary = {}
  var map_config: Dictionary = {}
  var initial_actors: Array = []
  var timeline: Array = []
  
  # After:
  var _record: ReplayData.BattleRecord
  var _meta: ReplayData.BattleMeta
  ```

  **2. _init() 修改**:
  ```gdscript
  # Before:
  func _init(recorder_config: Dictionary = {}):
      var battle_id = recorder_config.get(ReplayKeys.META_BATTLE_ID, "")
      if battle_id.is_empty():
          battle_id = IdGenerator.generate("battle")
      config = {
          ReplayKeys.META_BATTLE_ID: battle_id,
          ReplayKeys.META_TICK_INTERVAL: recorder_config.get(ReplayKeys.META_TICK_INTERVAL, 100),
      }
  
  # After:
  func _init(recorder_config: Dictionary = {}):
      _meta = ReplayData.BattleMeta.new()
      _meta.battle_id = recorder_config.get("battleId", "")
      if _meta.battle_id.is_empty():
          _meta.battle_id = IdGenerator.generate("battle")
      _meta.tick_interval = recorder_config.get("tickInterval", 100)
  ```

  **3. start_recording() 修改**:
  ```gdscript
  # Before:
  func start_recording(actors: Array, configs_value: Dictionary = {}, map_config_value: Dictionary = {}) -> void:
      recorded_at = Time.get_unix_time_from_system()
      configs = configs_value
      map_config = map_config_value
      for actor in actors:
          initial_actors.append(_capture_actor_init_data(actor))
  
  # After:
  func start_recording(actors: Array, configs_value: Dictionary = {}, map_config_value: Dictionary = {}) -> void:
      _record = ReplayData.BattleRecord.new()
      _record.meta = _meta
      _meta.recorded_at = Time.get_unix_time_from_system()
      _record.configs = configs_value
      _record.map_config = map_config_value
      for actor in actors:
          _record.initial_actors.append(ReplayData.ActorInitData.create(actor))
  ```

  **4. record_frame() 修改**:
  ```gdscript
  # Before:
  func record_frame(frame: int, events: Array) -> void:
      if not all_events.is_empty():
          timeline.append({
              ReplayKeys.FRAME: frame,
              ReplayKeys.EVENTS: all_events,
          })
  
  # After:
  func record_frame(frame: int, events: Array) -> void:
      if not all_events.is_empty():
          var frame_data := ReplayData.FrameData.new()
          frame_data.frame = frame
          frame_data.events = all_events
          _record.timeline.append(frame_data)
  ```

  **5. stop_recording() 修改**:
  ```gdscript
  # Before:
  func stop_recording(result: String = "") -> Dictionary:
      var meta := {
          ReplayKeys.META_BATTLE_ID: config.get(ReplayKeys.META_BATTLE_ID, ""),
          # ... more ReplayKeys
      }
      return {
          ReplayKeys.VERSION: ReplayKeys.PROTOCOL_VERSION,
          ReplayKeys.META: meta,
          # ... more ReplayKeys
      }
  
  # After:
  func stop_recording(result: String = "") -> Dictionary:
      _meta.total_frames = current_frame
      _meta.result = result
      return _record.to_dict()
  ```

  **6. register_actor() 修改**:
  ```gdscript
  # Before:
  func register_actor(actor: Actor) -> void:
      var init_data = _capture_actor_init_data(actor)
      var event = GameEvent.create_actor_spawned_event(init_data)
  
  # After:
  func register_actor(actor: Actor) -> void:
      var actor_data := ReplayData.ActorInitData.create(actor)
      var event := GameEvent.ActorSpawned.create(actor.id, actor_data.to_dict())
      pending_events.append(event.to_dict())
  ```

  **7. 删除 _capture_actor_init_data() 方法** - 已被 ReplayData.ActorInitData.create() 替代

  **Must NOT do**:
  - 不修改公共 API 签名（start_recording, stop_recording 等参数不变）
  - 不改变录像文件输出格式（JSON 结构必须一致）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 8, 8.5)
  - **Blocks**: Task 9
  - **Blocked By**: Tasks 3, 5

  **References**:
  - `addons/logic-game-framework/stdlib/replay/battle_recorder.gd` - 目标文件（169 行）
  - `addons/logic-game-framework/stdlib/replay/replay_data.gd` - ReplayData 类（Task 3 创建，包含 ActorInitData）
  - `addons/logic-game-framework/stdlib/replay/replay_keys.gd` - 现有 key 定义（将被移除）

  **Acceptance Criteria**:
  - [ ] BattleRecorder 不再 import 或使用 ReplayKeys
  - [ ] 生成的录像 JSON 与重构前格式完全一致（可用 diff 验证）
  - [ ] `godot --headless addons/logic-game-framework/tests/run_tests.tscn` 通过

  **Commit**: YES
  - Message: `refactor(replay): use strongly-typed ReplayData in BattleRecorder`
  - Files: `addons/logic-game-framework/stdlib/replay/battle_recorder.gd`

---

- [x] 8. 更新表演层 Visualizers

  **What to do**:
  - 修改 `addons/logic-game-framework/example/hex-atb-battle-frontend/visualizers/*.gd`
  - 使用 `BattleEvents.XxxEvent.from_dict()` 替代手动解析
  - 移除 `get_string_field`, `get_float_field` 等辅助方法调用

  **跨目录依赖说明**:
  - `BattleEvents` 位于 `hex-atb-battle-core/events/battle_events.gd`
  - Visualizers 位于 `hex-atb-battle-frontend/visualizers/`
  - 由于 `BattleEvents` 使用 `class_name` 声明，可直接使用，无需 preload

  **需要修改的文件**（共 4 个）:
  1. `damage_visualizer.gd`
  2. `heal_visualizer.gd`
  3. `move_visualizer.gd`
  4. `death_visualizer.gd`

  **代码重构示例**:

  **1. damage_visualizer.gd**:
  ```gdscript
  # Before:
  func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array[FrontendVisualAction]:
      var target_id := get_string_field(event, "target_actor_id")
      var damage := get_float_field(event, "damage")
      var is_critical := get_bool_field(event, "is_critical")
      var is_reflected := get_bool_field(event, "is_reflected")
  
  # After:
  func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array[FrontendVisualAction]:
      var e := BattleEvents.DamageEvent.from_dict(event)
      var target_id := e.target_actor_id
      var damage := e.damage
      var is_critical := e.is_critical
      var is_reflected := e.is_reflected
  ```

  **2. heal_visualizer.gd**:
  ```gdscript
  # Before:
  func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array[FrontendVisualAction]:
      var target_id := get_string_field(event, "target_actor_id")
      var heal_amount := get_float_field(event, "heal_amount")
  
  # After:
  func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array[FrontendVisualAction]:
      var e := BattleEvents.HealEvent.from_dict(event)
      var target_id := e.target_actor_id
      var heal_amount := e.heal_amount
  ```

  **3. move_visualizer.gd**:
  ```gdscript
  # Before:
  func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array[FrontendVisualAction]:
      var actor_id := get_string_field(event, "actor_id")
      var from_hex: HexCoord = get_hex_field(event, "from_hex")
      var to_hex: HexCoord = get_hex_field(event, "to_hex")
  
  # After:
  func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array[FrontendVisualAction]:
      var e := BattleEvents.MoveStartEvent.from_dict(event)
      var actor_id := e.actor_id
      # 注意：from_hex/to_hex 在 BattleEvents 中是 Dictionary，需要转换为 HexCoord
      var from_hex := HexCoord.from_dict(e.from_hex)
      var to_hex := HexCoord.from_dict(e.to_hex)
  ```

  **4. death_visualizer.gd**:
  ```gdscript
  # Before:
  func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array[FrontendVisualAction]:
      var actor_id := get_string_field(event, "actor_id")
      var killer_id := get_string_field(event, "killer_actor_id")
  
  # After:
  func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array[FrontendVisualAction]:
      var e := BattleEvents.DeathEvent.from_dict(event)
      var actor_id := e.actor_id
      var killer_id := e.killer_actor_id
  ```

  **Must NOT do**:
  - 不修改 Visualizer 的公共接口（仍接收 Dictionary，内部转换为强类型）
  - 不改变视觉效果行为
  - 不修改 `base_visualizer.gd`（辅助方法保留，其他 visualizer 可能使用）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 7)
  - **Blocks**: Task 9
  - **Blocked By**: Task 5

  **References**:
  - `addons/logic-game-framework/example/hex-atb-battle-frontend/visualizers/damage_visualizer.gd` - 伤害可视化器（78 行）
  - `addons/logic-game-framework/example/hex-atb-battle-frontend/visualizers/heal_visualizer.gd` - 治疗可视化器（55 行）
  - `addons/logic-game-framework/example/hex-atb-battle-frontend/visualizers/move_visualizer.gd` - 移动可视化器（34 行）
  - `addons/logic-game-framework/example/hex-atb-battle-frontend/visualizers/death_visualizer.gd` - 死亡可视化器（35 行）
  - `addons/logic-game-framework/example/hex-atb-battle-frontend/visualizers/base_visualizer.gd` - 基类（保留辅助方法）
  - `addons/logic-game-framework/example/hex-atb-battle-core/events/battle_events.gd` - 强类型事件（Task 5 创建）
  - `addons/ultra-grid-map/core/hex_coord.gd` - HexCoord.from_dict() 用于坐标转换

  **Acceptance Criteria**:
  - [ ] 4 个 Visualizers 使用 `BattleEvents.XxxEvent.from_dict()` 解析事件
  - [ ] `godot --headless --quit` 编译无错误
  - [ ] 回放功能正常工作（手动运行 `hex-atb-battle-frontend/main.tscn` 验证）

  **Commit**: YES
  - Message: `refactor(frontend): use strongly-typed events in Visualizers`
  - Files: 
    - `addons/logic-game-framework/example/hex-atb-battle-frontend/visualizers/damage_visualizer.gd`
    - `addons/logic-game-framework/example/hex-atb-battle-frontend/visualizers/heal_visualizer.gd`
    - `addons/logic-game-framework/example/hex-atb-battle-frontend/visualizers/move_visualizer.gd`
    - `addons/logic-game-framework/example/hex-atb-battle-frontend/visualizers/death_visualizer.gd`

---

- [x] 8.5. 迁移逻辑层 Actions 和 Skills

  **What to do**:
  - 修改 `addons/logic-game-framework/example/hex-atb-battle/actions/*.gd` 和 `skills/*.gd`
  - 将 `HexBattleReplayEvents` 替换为 `BattleEvents`
  - 将工厂函数调用改为强类型类调用

  **需要修改的文件**（共 7 个，22 处引用）:
  1. `actions/damage_action.gd` - 5 处
  2. `actions/heal_action.gd` - 1 处
  3. `actions/reflect_damage_action.gd` - 4 处
  4. `actions/start_move_action.gd` - 1 处
  5. `actions/apply_move_action.gd` - 1 处
  6. `skills/passive_abilities.gd` - 1 处
  7. `skills/skill_abilities.gd` - 9 处

  **代码重构模式**:

  **1. DamageType 枚举替换**:
  ```gdscript
  # Before:
  var _damage_type: HexBattleReplayEvents.DamageType
  damage_type: HexBattleReplayEvents.DamageType = HexBattleReplayEvents.DamageType.PHYSICAL
  
  # After:
  var _damage_type: BattleEvents.DamageType
  damage_type: BattleEvents.DamageType = BattleEvents.DamageType.PHYSICAL
  ```

  **2. 工厂函数替换（damage_action.gd）**:
  ```gdscript
  # Before:
  var damage_type_str := HexBattleReplayEvents._damage_type_to_string(_damage_type)
  HexBattleReplayEvents.create_damage_event(
      target.id,
      final_damage,
      damage_type_str,
      source_actor_id,
      is_critical,
      is_reflected
  )
  
  # After:
  var event := BattleEvents.DamageEvent.create(
      target.id,
      final_damage,
      _damage_type,
      source_actor_id,
      is_critical,
      is_reflected
  )
  ctx.push_event(event.to_dict())
  ```

  **3. 工厂函数替换（heal_action.gd）**:
  ```gdscript
  # Before:
  HexBattleReplayEvents.create_heal_event(target.id, final_heal, source_actor_id)
  
  # After:
  var event := BattleEvents.HealEvent.create(target.id, final_heal, source_actor_id)
  ctx.push_event(event.to_dict())
  ```

  **4. 工厂函数替换（start_move_action.gd）**:
  ```gdscript
  # Before:
  HexBattleReplayEvents.create_move_start_event(actor.id, from_hex.to_dict(), to_hex.to_dict())
  
  # After:
  var event := BattleEvents.MoveStartEvent.create(actor.id, from_hex.to_dict(), to_hex.to_dict())
  ctx.push_event(event.to_dict())
  ```

  **5. 工厂函数替换（apply_move_action.gd）**:
  ```gdscript
  # Before:
  HexBattleReplayEvents.create_move_complete_event(actor.id, from_hex.to_dict(), to_hex.to_dict())
  
  # After:
  var event := BattleEvents.MoveCompleteEvent.create(actor.id, from_hex.to_dict(), to_hex.to_dict())
  ctx.push_event(event.to_dict())
  ```

  **Must NOT do**:
  - 不修改 Action 的公共接口
  - 不改变事件的 Dictionary 结构（保持与 Visualizers 兼容）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 7, 8)
  - **Blocks**: Task 9
  - **Blocked By**: Task 5

  **References**:
  - `addons/logic-game-framework/example/hex-atb-battle/actions/damage_action.gd` - 伤害动作
  - `addons/logic-game-framework/example/hex-atb-battle/actions/heal_action.gd` - 治疗动作
  - `addons/logic-game-framework/example/hex-atb-battle/actions/reflect_damage_action.gd` - 反伤动作
  - `addons/logic-game-framework/example/hex-atb-battle/actions/start_move_action.gd` - 开始移动动作
  - `addons/logic-game-framework/example/hex-atb-battle/actions/apply_move_action.gd` - 应用移动动作
  - `addons/logic-game-framework/example/hex-atb-battle/skills/passive_abilities.gd` - 被动技能
  - `addons/logic-game-framework/example/hex-atb-battle/skills/skill_abilities.gd` - 主动技能
  - `addons/logic-game-framework/example/hex-atb-battle-core/events/battle_events.gd` - 强类型事件（Task 5 创建）

  **Acceptance Criteria**:
  - [ ] `grep -r "HexBattleReplayEvents" addons/logic-game-framework/example/hex-atb-battle/ --include="*.gd"` 返回 0 结果（除了 replay_events.gd 本身）
  - [ ] `godot --headless --quit` 编译无错误
  - [ ] `godot --headless addons/logic-game-framework/tests/run_tests.tscn` 通过

  **Commit**: YES
  - Message: `refactor(battle): migrate actions and skills to BattleEvents`
  - Files:
    - `addons/logic-game-framework/example/hex-atb-battle/actions/damage_action.gd`
    - `addons/logic-game-framework/example/hex-atb-battle/actions/heal_action.gd`
    - `addons/logic-game-framework/example/hex-atb-battle/actions/reflect_damage_action.gd`
    - `addons/logic-game-framework/example/hex-atb-battle/actions/start_move_action.gd`
    - `addons/logic-game-framework/example/hex-atb-battle/actions/apply_move_action.gd`
    - `addons/logic-game-framework/example/hex-atb-battle/skills/passive_abilities.gd`
    - `addons/logic-game-framework/example/hex-atb-battle/skills/skill_abilities.gd`

---

- [ ] 9. 删除 replay_keys.gd 和旧 replay_events.gd

  **What to do**:
  - 删除 `addons/logic-game-framework/stdlib/replay/replay_keys.gd`
  - 删除 `addons/logic-game-framework/example/hex-atb-battle/events/replay_events.gd`
  - 搜索并更新所有引用这些文件的 import（预期：无引用，因为 Task 7, 8, 8.5 已移除）

  **验证步骤**:
  1. 运行 `grep -r "replay_keys" addons/logic-game-framework/ --include="*.gd"` 确认无引用
  2. 运行 `grep -r "HexBattleReplayEvents" addons/logic-game-framework/example/hex-atb-battle/ --include="*.gd"` 确认逻辑层无引用
  3. 运行 `grep -r "HexBattleReplayEvents" addons/logic-game-framework/example/hex-atb-battle-frontend/ --include="*.gd"` 确认表演层无引用
  4. 删除文件
  5. 运行编译检查

  **Must NOT do**:
  - 不删除仍有引用的代码（先搜索确认）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4 (after Wave 3)
  - **Blocks**: Task 10
  - **Blocked By**: Tasks 7, 8, 8.5

  **References**:
  - `addons/logic-game-framework/stdlib/replay/replay_keys.gd` - 待删除（常量定义文件）
  - `addons/logic-game-framework/example/hex-atb-battle/events/replay_events.gd` - 待删除（旧事件定义）

  **Acceptance Criteria**:
  - [ ] `ls addons/logic-game-framework/stdlib/replay/replay_keys.gd` 返回 "No such file"
  - [ ] `ls addons/logic-game-framework/example/hex-atb-battle/events/replay_events.gd` 返回 "No such file"
  - [ ] `godot --headless --quit` 编译无错误
  - [ ] `godot --headless addons/logic-game-framework/tests/run_tests.tscn` 通过

  **Commit**: YES
  - Message: `chore: remove deprecated replay_keys.gd and replay_events.gd`
  - Files: 
    - `addons/logic-game-framework/stdlib/replay/replay_keys.gd` (deleted)
    - `addons/logic-game-framework/example/hex-atb-battle/events/replay_events.gd` (deleted)

---

- [ ] 10. 更新文档

  **What to do**:
  - 更新 `addons/logic-game-framework/docs/README.md` 添加"逻辑表演分离架构"最佳实践
  - 添加三层架构说明
  - 添加事件类设计模式示例
  - 添加序列化约定说明

  **文档内容大纲**:
  ```markdown
  ## 逻辑表演分离架构
  
  ### 三层架构
  ```
  hex-atb-battle-core/     # 共享数据层
  ├── events/              # 强类型事件定义
  └── actor_record_data.gd # Actor 录像数据
  
  hex-atb-battle/          # 逻辑层
  ├── 战斗计算
  └── 事件生成
  
  hex-atb-battle-frontend/ # 表演层
  ├── 3D 渲染
  └── 录像回放
  ```
  
  ### 事件类设计模式
  - 每个事件类必须实现: create(), to_dict(), from_dict(), is_match()
  - 序列化使用 camelCase（JSON 兼容）
  - 内部属性使用 snake_case（GDScript 规范）
  
  ### 序列化约定
  - Dictionary key: camelCase
  - 类属性: snake_case
  - 枚举序列化: 转为小写字符串
  ```

  **Must NOT do**:
  - 不删除现有文档内容

  **Recommended Agent Profile**:
  - **Category**: `writing`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4 (final)
  - **Blocks**: None
  - **Blocked By**: Task 9

  **References**:
  - `addons/logic-game-framework/docs/README.md` - 目标文件
  - `addons/logic-game-framework/example/hex-atb-battle-core/events/battle_events.gd` - 事件类示例（Task 5 创建）
  - 本计划的 Context 部分 - 架构说明内容

  **Acceptance Criteria**:
  - [ ] README.md 包含"逻辑表演分离架构"章节
  - [ ] 包含三层架构目录结构图
  - [ ] 包含事件类代码示例（create/to_dict/from_dict/is_match）
  - [ ] 包含序列化约定说明（camelCase vs snake_case）

  **Commit**: YES
  - Message: `docs: add three-layer architecture best practices`
  - Files: `addons/logic-game-framework/docs/README.md`

---

## Commit Strategy

| After Task | Message | Files |
|------------|---------|-------|
| 1 | `feat(core): create hex-atb-battle-core directory structure` | `addons/logic-game-framework/example/hex-atb-battle-core/` |
| 2 | `feat(grid): add serialization to GridMapConfig` | `addons/ultra-grid-map/core/grid_types.gd` |
| 3 | `feat(replay): add strongly-typed ReplayData classes` | `addons/logic-game-framework/stdlib/replay/replay_data.gd` |
| 4 | `feat(events): refactor GameEvent to strongly-typed classes` | `addons/logic-game-framework/core/events/game_event.gd` |
| 5 | `feat(battle-core): add strongly-typed BattleEvents` | `addons/logic-game-framework/example/hex-atb-battle-core/events/battle_events.gd` |
| ~~6~~ | ~~`feat(battle-core): add ActorRecordData class`~~ | (已合并到 Task 3) |
| 7 | `refactor(replay): use strongly-typed ReplayData in BattleRecorder` | `addons/logic-game-framework/stdlib/replay/battle_recorder.gd` |
| 8 | `refactor(frontend): use strongly-typed events in Visualizers` | `addons/logic-game-framework/example/hex-atb-battle-frontend/visualizers/*.gd` |
| 8.5 | `refactor(battle): migrate actions and skills to BattleEvents` | `addons/logic-game-framework/example/hex-atb-battle/actions/*.gd`, `skills/*.gd` |
| 9 | `chore: remove deprecated replay_keys.gd and replay_events.gd` | 删除 `replay_keys.gd`, `replay_events.gd` |
| 10 | `docs: add three-layer architecture best practices` | `addons/logic-game-framework/docs/README.md` |

---

## Success Criteria

### Verification Commands
```bash
# 编译检查
godot --headless --quit
# Expected: 退出码 0

# 运行测试
godot --headless addons/logic-game-framework/tests/run_tests.tscn
# Expected: 0 failures
```

### Final Checklist
- [ ] 所有事件类有强类型定义
- [ ] 录像 JSON 格式未变
- [ ] 表演层使用强类型事件
- [ ] 文档已更新
- [ ] 所有测试通过
