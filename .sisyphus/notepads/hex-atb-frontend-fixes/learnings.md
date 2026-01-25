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


## 2026-01-25 - Fix C1: 内存泄漏 - 信号连接未清理

### Problem
- `BattleReplayScene` 在 `_ready()` 中连接了 Director 的5个信号（第48-52行）
- `BattleDirector` 在 `_ready()` 中连接了 RenderWorld 的3个信号（第96-99行）
- 场景销毁时没有断开连接，导致 `ObjectDB instances leaked` 警告
- RefCounted 对象（`_world`, `_scheduler`）的信号连接形成循环引用

### Solution
1. 在 `battle_replay_scene.gd` 添加 `_exit_tree()` 方法断开 Director 信号
2. 在 `battle_director.gd` 添加 `_exit_tree()` 方法断开 RenderWorld 信号并清空引用
3. 在测试脚本 `test_3d_visualization.gd` 添加 `_exit_tree()` 断开信号

### Key Implementation
```gdscript
# battle_replay_scene.gd
func _exit_tree() -> void:
	# 断开 Director 信号连接 (修复 C1: 内存泄漏)
	if _director:
		_director.actor_state_changed.disconnect(_on_actor_state_changed)
		_director.floating_text_created.disconnect(_on_floating_text_created)
		_director.actor_died.disconnect(_on_actor_died)
		_director.frame_changed.disconnect(_on_frame_changed)
		_director.playback_ended.disconnect(_on_playback_ended)

# battle_director.gd
func _exit_tree() -> void:
	# 断开 RenderWorld 信号连接 (修复 C1: 内存泄漏)
	if _world:
		_world.actor_state_changed.disconnect(_on_actor_state_changed)
		_world.floating_text_created.disconnect(_on_floating_text_created)
		_world.actor_died.disconnect(_on_actor_died)
	
	# 清空 RefCounted 引用，打破循环引用
	_world = null
	_scheduler = null
	_registry = null
```

### Design Pattern
- **信号清理**: 在 `_exit_tree()` 中断开所有在 `_ready()` 中连接的信号
- **循环引用**: Node 持有 RefCounted 对象，RefCounted 信号连接到 Node 方法，形成循环引用
- **打破循环**: 断开信号后显式清空 RefCounted 引用（`= null`）

### Testing
- 测试命令: `godot --headless addons/logic-game-framework/example/hex-atb-battle-frontend/test_3d_visualization.tscn`
- 结果: 修复了 `BattleReplayScene` 和 `BattleDirector` 的信号连接泄漏
- 注意: 测试仍有 `inventoryKit` 相关的资源泄漏（与本任务无关）

### Related Files
- `addons/logic-game-framework/example/hex-atb-battle-frontend/scene/battle_replay_scene.gd` - 添加 `_exit_tree()` 断开信号
- `addons/logic-game-framework/example/hex-atb-battle-frontend/core/battle_director.gd` - 添加 `_exit_tree()` 断开信号并清空引用
- `addons/logic-game-framework/example/hex-atb-battle-frontend/test_3d_visualization.gd` - 添加 `_exit_tree()` 断开信号



## 2026-01-25 - Fix C3: 资源未释放 - UnitView 材质和 Tween

### Problem
- `_base_material` (StandardMaterial3D) 未显式释放（Godot 会自动管理，无需手动释放）
- 死亡动画的 Tween 在 UnitView 被 `queue_free()` 时可能仍在运行
- 多次调用 `_play_death_animation()` 会创建多个 Tween，导致资源泄漏

### Solution
在 `unit_view.gd` 中添加 `_death_tween: Tween` 变量，修改 `_play_death_animation()` 检查 Tween 是否已在运行，添加 `_exit_tree()` 方法 kill Tween。

### Key Implementation
```gdscript
# 状态变量区（第47行）
var _death_tween: Tween  # 死亡动画 Tween (修复 C3)

# 修改 _play_death_animation()（第209-218行）
func _play_death_animation() -> void:
	# 防止重复创建 Tween (修复 C3)
	if _death_tween and _death_tween.is_running():
		return
	
	_death_tween = create_tween()
	_death_tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.5)
	_death_tween.parallel().tween_property(self, "position:y", position.y - 0.5, 0.5)
	_death_tween.tween_callback(_on_death_animation_finished)

# 添加 _exit_tree()（第224-227行）
func _exit_tree() -> void:
	# 清理死亡动画 Tween (修复 C3)
	if _death_tween:
		_death_tween.kill()
```

### Design Pattern
- **Tween 生命周期管理**: 使用成员变量 `_death_tween` 持有 Tween 引用
- **防止重复创建**: 在 `_play_death_animation()` 中检查 `is_running()`
- **资源清理**: 在 `_exit_tree()` 中调用 `kill()` 停止 Tween
- **材质管理**: `_base_material` 由 Godot 自动管理，无需手动释放

### Testing
- LSP 诊断: 无错误 ✅
- 预期效果: 多次调用 `_play_death_animation()` 不会创建多个 Tween，退出时无资源泄漏警告

### Related Files
- `addons/logic-game-framework/example/hex-atb-battle-frontend/scene/unit_view.gd` - 修改死亡动画 Tween 管理


## 2026-01-25 - Fix C4: 视觉特效在暂停时失效

### Problem
- `render_world.gd` 使用 `Time.get_ticks_msec()` (墙上时间) 管理特效生命周期
- 当战斗暂停时，墙上时间仍在增加，导致特效在暂停期间"过期"并消失
- 播放速度改变不会影响特效的播放速度

### Solution
在 `render_world.gd` 中维护内部 `_world_time_ms` 变量，在 `battle_director.gd` 的 `_tick()` 中累加时间。

### Key Implementation
```gdscript
# render_world.gd - 内部状态区（第50-51行）
var _world_time_ms: int = 0

# render_world.gd - 飘字使用内部时间（第196行）
"start_time": _world_time_ms,

# render_world.gd - 特效使用内部时间（第241行）
"start_time": _world_time_ms,

# render_world.gd - 重置时清零（第367行）
func reset_to(replay_data: Dictionary) -> void:
	_world_time_ms = 0
	initialize_from_replay(replay_data)

# render_world.gd - 推进内部时间（第372-373行）
func advance_time(delta_ms: int) -> void:
	_world_time_ms += delta_ms

# render_world.gd - 获取内部时间（第377-378行）
func get_world_time() -> int:
	return _world_time_ms

# battle_director.gd - 在 _tick() 中推进时间（第278-279行）
# 推进内部世界时间 (修复 C4: 暂停时特效失效)
_world.advance_time(int(delta_ms))

# battle_director.gd - cleanup 使用内部时间（第287行）
_world.cleanup(_world.get_world_time())
```

### Design Pattern
- **内部时间管理**: 使用 `_world_time_ms` 替代 `Time.get_ticks_msec()`
- **暂停支持**: 暂停时 `_tick()` 不执行，`_world_time_ms` 不增加
- **变速播放**: 播放速度改变时，`delta_ms` 相应调整，特效持续时间也相应调整
- **数据流向**: `BattleDirector._tick(delta_ms)` → `RenderWorld.advance_time(delta_ms)` → `_world_time_ms += delta_ms`

### Testing
- 测试命令: `godot --headless addons/logic-game-framework/example/hex-atb-battle-frontend/test_3d_visualization.tscn`
- 结果: 测试通过 ✅
- 验证: 暂停时特效不会提前消失，播放速度改变时特效持续时间相应调整

### Related Files
- `addons/logic-game-framework/example/hex-atb-battle-frontend/core/render_world.gd:50-51` - 添加 `_world_time_ms` 变量
- `addons/logic-game-framework/example/hex-atb-battle-frontend/core/render_world.gd:196` - 飘字使用内部时间
- `addons/logic-game-framework/example/hex-atb-battle-frontend/core/render_world.gd:241` - 特效使用内部时间
- `addons/logic-game-framework/example/hex-atb-battle-frontend/core/render_world.gd:367` - 重置时清零
- `addons/logic-game-framework/example/hex-atb-battle-frontend/core/render_world.gd:372-378` - 时间管理方法
- `addons/logic-game-framework/example/hex-atb-battle-frontend/core/battle_director.gd:278-279` - 推进内部时间
- `addons/logic-game-framework/example/hex-atb-battle-frontend/core/battle_director.gd:287` - cleanup 使用内部时间

