## InkMonBattle2DDamageVisualizer - 伤害事件转换器
##
## 绑 inkmon 的 `inkmon_damage`，翻译为飘字 + 受击闪白 + 血条扣血（state 路径）。
## inkmon 暂无暴击 / 反伤 / 护盾吸收：那些只在 visualizer 内按缺省处理，不动逻辑层
## （Strategy B，见 docs/adr/0006）。直接读事件 dict 字段。
class_name InkMonBattle2DDamageVisualizer
extends InkMonBattle2DBaseVisualizer


func _init() -> void:
	visualizer_name = "DamageVisualizer"


func can_handle(event: Dictionary) -> bool:
	return get_event_kind(event) == "inkmon_damage"


func translate(event: Dictionary, context: InkMonBattle2DVisualizerContext) -> Array[InkMonBattle2DVisualAction]:
	var config := context.get_animation_config()
	var target_id := get_string_field(event, "target_actor_id")
	# 优先 actual_life_damage（真实扣血），回退 damage
	var actual_life_damage := get_float_field(event, "actual_life_damage", get_float_field(event, "damage", 0.0))
	var target_position := context.get_actor_position(target_id)

	var actions: Array[InkMonBattle2DVisualAction] = []
	if actual_life_damage <= 0.0:
		return actions

	# 1. 伤害飘字（hex 原设计：普通伤害白字，暴击/反伤上色——inkmon 暂无故恒白）
	var text := "-%d" % roundi(actual_life_damage)
	var floating_text := InkMonBattle2DFloatingTextAction.new(
		target_id,
		text,
		Color.WHITE,
		target_position,
		InkMonBattle2DFloatingTextAction.FloatingTextStyle.NORMAL,
		config.damage_floating_text_duration
	)
	actions.append(floating_text)

	# 2. 受击闪白
	var hit_flash := InkMonBattle2DProceduralVFXAction.new(
		InkMonBattle2DProceduralVFXAction.EffectType.HIT_FLASH,
		config.damage_hit_vfx_duration,
		target_id
	)
	actions.append(hit_flash)

	# 3. 血条扣血（target_hp -= damage，visual_hp 由 RenderWorld lerp 收敛；delay 让闪白先起播）
	var apply_delta := InkMonBattle2DApplyHPDeltaAction.new(
		target_id,
		-actual_life_damage,
		config.damage_hp_bar_delay
	)
	actions.append(apply_delta)

	return actions
