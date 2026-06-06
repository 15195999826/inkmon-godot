## InkMonRender2DMoveVisualizer - 移动事件转换器
##
## 绑 inkmon 的 `inkmon_move_start`，翻译为 MoveAction（duration 缓动移动）。
## 直接读事件 dict 字段（actor_id / from_hex / to_hex），不依赖逻辑层事件类。
class_name InkMonRender2DMoveVisualizer
extends InkMonRender2DBaseVisualizer


func _init() -> void:
	visualizer_name = "MoveVisualizer"


func can_handle(event: Dictionary) -> bool:
	return get_event_kind(event) == "inkmon_move_start"


func translate(event: Dictionary, context: InkMonRender2DVisualizerContext) -> Array[InkMonRender2DVisualAction]:
	var config := context.get_animation_config()
	var actor_id := get_string_field(event, "actor_id")
	var from_hex := get_hex_field(event, "from_hex")
	var to_hex := get_hex_field(event, "to_hex")

	var move_action := InkMonRender2DMoveAction.new(
		actor_id,
		from_hex,
		to_hex,
		config.move_duration,
		config.move_easing
	)
	return [move_action]
