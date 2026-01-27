## MoveVisualizer - 移动事件转换器
##
## 将 move_start 事件翻译为 MoveAction
class_name FrontendMoveVisualizer
extends FrontendBaseVisualizer


func _init() -> void:
	visualizer_name = "MoveVisualizer"


## 检查是否为移动开始事件
func can_handle(event: Dictionary) -> bool:
	return get_event_kind(event) == "move_start"


## 翻译移动事件为 MoveAction
func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array[FrontendVisualAction]:
	var config := context.get_animation_config()
	
	var actor_id := get_string_field(event, "actor_id")
	var from_hex: HexCoord = get_hex_field(event, "from_hex")
	var to_hex: HexCoord = get_hex_field(event, "to_hex")
	
	var move_action := FrontendMoveAction.new(
		actor_id,
		from_hex,
		to_hex,
		config.move_duration,
		config.move_easing
	)
	
	return [move_action]
