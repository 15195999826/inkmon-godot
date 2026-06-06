## InkMonBattle2DDeathVisualizer - 死亡事件转换器
##
## 绑 inkmon 的 `inkmon_death`，翻译为死亡动画动作（淡出）。直接读事件 dict 字段。
class_name InkMonBattle2DDeathVisualizer
extends InkMonRender2DBaseVisualizer


func _init() -> void:
	visualizer_name = "DeathVisualizer"


func can_handle(event: Dictionary) -> bool:
	return get_event_kind(event) == "inkmon_death"


func translate(event: Dictionary, context: InkMonRender2DVisualizerContext) -> Array[InkMonRender2DVisualAction]:
	var config := context.get_animation_config()
	var actor_id := get_string_field(event, "actor_id")
	var killer_id := get_string_field(event, "killer_actor_id")

	var death_action := InkMonRender2DDeathAction.new(
		actor_id,
		config.death_duration,
		killer_id
	)
	return [death_action]
