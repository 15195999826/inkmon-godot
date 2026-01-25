# Learnings - Hex ATB Frontend Fixes

## Conventions
- GDScript, Godot 4.x
- 使用 `_exit_tree()` 清理信号连接和资源
- 使用 `lerp` 而非 Tween 进行每帧插值
- 信号命名: snake_case

## Patterns
- 架构: BattleDirector -> VisualizerRegistry -> ActionScheduler -> RenderWorld
- 信号转发: RenderWorld -> BattleDirector -> BattleReplayScene
- 位置管理: `_interpolated_positions` 用于移动动画插值

## Code Style
- 类型注解: `var _variable: Type`
- 信号连接: `signal_name.connect(_on_signal_name)`
- 信号断开: `signal_name.disconnect(_on_signal_name)`

## 2026-01-25 - Fix C2: 移动动画丢失

### Problem
- `_apply_move_action` 在 `render_world.gd` 中只更新 `_interpolated_positions` 进行插值
- 只有在 `progress >= 1.0` 时才触发 `actor_state_changed` 信号
- 导致移动动画期间单位视觉位置不更新，表现为瞬移

### Solution
在 `BattleReplayScene` 的 `_process()` 中添加 `_update_all_unit_positions()` 方法：
1. 每帧遍历所有 `_unit_views`
2. 调用 `_director.get_actor_world_position(actor_id)` 获取插值位置
3. 调用 `unit_view.set_world_position(world_pos)` 更新位置

### Key Implementation
```gdscript
func _process(_delta: float) -> void:
	# 更新所有单位位置（修复 C2: 移动动画期间单位位置平滑更新）
	_update_all_unit_positions()
	# ... 其他逻辑

func _update_all_unit_positions() -> void:
	for actor_id in _unit_views.keys():
		var unit_view: FrontendUnitView = _unit_views[actor_id]
		var world_pos := _director.get_actor_world_position(actor_id)
		unit_view.set_world_position(world_pos)
```

### Design Pattern
- **分离关注点**：`RenderWorld` 只负责插值计算，`BattleReplayScene` 负责视觉更新
- **性能考虑**：不在 `render_world.gd` 的 `_apply_move_action` 中每帧触发信号（避免性能问题）
- **数据流向**：`RenderWorld._interpolated_positions` → `BattleDirector.get_actor_world_position()` → `BattleReplayScene._update_all_unit_positions()` → `UnitView.set_world_position()`

### Testing
- 测试命令: `godot --headless addons/logic-game-framework/example/hex-atb-battle-frontend/test_3d_visualization.tscn`
- 结果: 测试通过 ✅
- 验证: 单位移动期间位置平滑更新，无瞬移现象

### Related Files
- `addons/logic-game-framework/example/hex-atb-battle-frontend/scene/battle_replay_scene.gd` - 修改位置更新逻辑
- `addons/logic-game-framework/example/hex-atb-battle-frontend/core/render_world.gd:150-160` - 参考插值实现
- `addons/logic-game-framework/example/hex-atb-battle-frontend/core/battle_director.gd:222-223` - `get_actor_world_position()` 方法


## 2026-01-25 - Fix M6: UnitView 位置插值

### Problem
- `set_world_position` 直接设置 `position`，没有平滑插值
- 如果物理帧率高于逻辑帧率（10fps vs 60fps），移动会显得卡顿

### Solution
在 `unit_view.gd` 中添加 `_target_position: Vector3` 变量，修改 `set_world_position()` 设置 `_target_position` 而非直接设置 `position`，添加 `_process(delta)` 方法使用 `lerp` 平滑插值到目标位置。

### Key Implementation
```gdscript
# 状态变量
var _target_position: Vector3 = Vector3.ZERO

# _ready() 初始化
func _ready() -> void:
    _create_mesh()
    _create_hp_bar()
    _create_name_label()
    _target_position = position

# 每帧插值
func _process(delta: float) -> void:
    # 平滑插值到目标位置 (修复 M6)
    position = position.lerp(_target_position, delta * 15.0)

# 设置目标位置
func set_world_position(world_pos: Vector3) -> void:
    _target_position = world_pos
```

### Design Pattern
- **插值速度**: `delta * 15.0` (与 Task 1 C2 保持一致)
- **避免 Tween**: 使用 `lerp` 而非 Tween，避免与死亡动画冲突
- **数据流向**: `BattleReplayScene._update_all_unit_positions()` → `UnitView.set_world_position()` → `_target_position` → `_process()` → `position`

### Related Files
- `addons/logic-game-framework/example/hex-atb-battle-frontend/scene/unit_view.gd` - 修改位置插值逻辑
- `addons/logic-game-framework/example/hex-atb-battle-frontend/scene/battle_replay_scene.gd:_update_all_unit_positions()` - 调用 `set_world_position()`

