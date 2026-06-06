## InkMonBattle2DHealVisualizer - 治疗事件转换器
##
## 绑 inkmon 的 `inkmon_heal`，翻译为绿色飘字 + 血条回血（state 路径）。直接读事件 dict 字段。
class_name InkMonBattle2DHealVisualizer
extends InkMonRender2DBaseVisualizer


func _init() -> void:
	visualizer_name = "HealVisualizer"


func can_handle(event: Dictionary) -> bool:
	return get_event_kind(event) == "inkmon_heal"


func translate(event: Dictionary, context: InkMonRender2DVisualizerContext) -> Array[InkMonRender2DVisualAction]:
	var config := context.get_animation_config()
	var target_id := get_string_field(event, "target_actor_id")
	var heal_amount := get_float_field(event, "heal_amount", 0.0)
	var target_position := context.get_actor_position(target_id)

	var actions: Array[InkMonRender2DVisualAction] = []

	# 1. 治疗飘字
	var floating_text := InkMonRender2DFloatingTextAction.new(
		target_id,
		"+%d" % roundi(heal_amount),
		Color(0.2, 1.0, 0.2),
		target_position,
		InkMonRender2DFloatingTextAction.FloatingTextStyle.HEAL,
		config.heal_floating_text_duration
	)
	actions.append(floating_text)

	# 2. 血条回血
	var apply_delta := InkMonRender2DApplyHPDeltaAction.new(
		target_id,
		heal_amount
	)
	actions.append(apply_delta)

	return actions
