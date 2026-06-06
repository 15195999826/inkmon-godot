## InkMonBattle2DVisualizerContext - Visualizer 的只读上下文
##
## 只读查询，Visualizer 是纯函数只返回声明式 VisualAction，状态修改由 RenderWorld 统一执行。
## 平移自 hex frontend（见 docs/adr/0006）：坐标全用逻辑 axial（Vector2 = q,r），无 GridLayout
## 依赖——hex→像素转换在 animator→view 边界做。
class_name InkMonBattle2DVisualizerContext
extends RefCounted


## 角色状态 Map（actor_id -> InkMonBattle2DActorRenderState）
var _actors: Dictionary = {}

## 插值位置 Map（actor_id -> Vector2 逻辑 axial）
var _interpolated_positions: Dictionary = {}

## 动画配置
var _animation_config: InkMonBattle2DAnimationConfig


func _init(
	actors: Dictionary,
	interpolated_positions: Dictionary,
	animation_config: InkMonBattle2DAnimationConfig
) -> void:
	_actors = actors
	_interpolated_positions = interpolated_positions
	_animation_config = animation_config


# ========== 角色查询 ==========

## 获取角色当前位置（逻辑 axial：q,r，含 in-flight 插值）
func get_actor_position(actor_id: String) -> Vector2:
	if _interpolated_positions.has(actor_id):
		return _interpolated_positions[actor_id]
	var actor: InkMonBattle2DActorRenderState = _actors.get(actor_id)
	if actor == null:
		return Vector2.ZERO
	return Vector2(actor.position.q, actor.position.r)


func get_actor_hp(actor_id: String) -> float:
	var actor: InkMonBattle2DActorRenderState = _actors.get(actor_id)
	if actor == null:
		return 0.0
	return actor.visual_hp


func get_actor_max_hp(actor_id: String) -> float:
	var actor: InkMonBattle2DActorRenderState = _actors.get(actor_id)
	if actor == null:
		return 100.0
	return actor.max_hp


func is_actor_alive(actor_id: String) -> bool:
	var actor: InkMonBattle2DActorRenderState = _actors.get(actor_id)
	if actor == null:
		return false
	return actor.is_alive


## 获取角色六边形坐标（插值取整 / 逻辑位置）
func get_actor_hex_position(actor_id: String) -> HexCoord:
	if _interpolated_positions.has(actor_id):
		var pos: Vector2 = _interpolated_positions[actor_id]
		return HexCoord.new(roundi(pos.x), roundi(pos.y))
	var actor: InkMonBattle2DActorRenderState = _actors.get(actor_id)
	if actor == null:
		return HexCoord.zero()
	return actor.position


func get_actor_team(actor_id: String) -> int:
	var actor: InkMonBattle2DActorRenderState = _actors.get(actor_id)
	if actor == null:
		return 0
	return actor.team


func get_all_actor_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _actors.keys():
		ids.append(key as String)
	return ids


func get_actor_display_name(actor_id: String) -> String:
	var actor: InkMonBattle2DActorRenderState = _actors.get(actor_id)
	if actor == null:
		return ""
	return actor.display_name


# ========== 配置查询 ==========

func get_animation_config() -> InkMonBattle2DAnimationConfig:
	return _animation_config
