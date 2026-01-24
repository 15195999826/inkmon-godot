## HealAction - 治疗 Action
class_name HexBattleHealAction
extends Action.BaseAction


var _heal_amount: Variant  # float 或 Callable


func _init(params: Dictionary) -> void:
	super._init(params)
	type = "heal"
	_heal_amount = params.get("heal_amount", 0.0)


func execute(ctx: ExecutionContext) -> ActionResult:
	var source: ActorRef = null
	if ctx.ability != null:
		source = ctx.ability.owner
	var targets := get_targets(ctx)
	
	# 解析参数
	var heal_amount := _resolve_param(_heal_amount, ctx)
	
	# 打印日志
	var target_ids: Array[String] = []
	for t in targets:
		target_ids.append(t.id)
	var source_id := source.id if source != null else "???"
	print("  [HealAction] %s 对 [%s] 治疗 %.0f HP" % [source_id, ", ".join(target_ids), heal_amount])
	
	# 产生回放格式事件
	var all_events: Array = []
	for target in targets:
		var source_id_str := source.id if source != null else ""
		var heal_event: Dictionary = ctx.event_collector.push(
			HexBattleReplayEvents.create_heal_event(
				target.id,
				heal_amount,
				source_id_str
			)
		)
		all_events.append(heal_event)
	
	return ActionResult.create_success_result(all_events, { "heal_amount": heal_amount })


func _resolve_param(value: Variant, ctx: ExecutionContext) -> float:
	if value is Callable:
		return float(value.call(ctx))
	return float(value)
