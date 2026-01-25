## DeathVisualizer - 死亡事件转换器
##
## 将 death 事件翻译为死亡动画动作
class_name FrontendDeathVisualizer
extends FrontendBaseVisualizer


func _init() -> void:
	visualizer_name = "DeathVisualizer"


## 检查是否为死亡事件
func can_handle(event: Dictionary) -> bool:
	return get_event_kind(event) == "death"


## 翻译死亡事件为视觉动作
func translate(event: Dictionary, context: FrontendVisualizerContext) -> Array:
	var config := context.get_animation_config()
	
	var actor_id := get_string_field(event, "actor_id")
	var killer_id := get_string_field(event, "killer_actor_id")
	
	var actions: Array = []
	
	# 死亡动画
	var death_action := FrontendDeathAction.new(
		actor_id,
		config.death_duration,
		killer_id
	)
	actions.append(death_action)
	
	return actions
