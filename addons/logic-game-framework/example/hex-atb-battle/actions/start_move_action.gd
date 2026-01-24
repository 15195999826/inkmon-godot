## StartMoveAction - 开始移动 Action
##
## 移动的第一阶段：预订目标格子，创建 MoveStartEvent。
## 此时 Actor 仍在原位置，但目标格子已被预订。
class_name HexBattleStartMoveAction
extends Action.BaseAction


var _target_coord: Variant  # Dictionary 或 Callable


## 构造函数
## @param target_selector: 目标选择器（移动的 Actor）
## @param target_coord: 目标坐标（Dictionary 或 Callable）
func _init(
	target_selector: TargetSelector,
	target_coord: Variant  # Dictionary 或 Callable
) -> void:
	super._init(target_selector)
	type = "start_move"
	_target_coord = target_coord


func execute(ctx: ExecutionContext) -> ActionResult:
	var targets := get_targets(ctx)
	
	# 解析目标坐标
	var target_coord := _resolve_coord(_target_coord, ctx)
	
	if target_coord == null or target_coord.is_empty():
		push_warning("  [StartMoveAction] 目标坐标未定义")
		return ActionResult.create_success_result([])
	
	# 获取 HexBattle 实例
	var battle = ctx.gameplay_state
	
	# 对每个目标执行预订
	var all_events: Array = []
	for target in targets:
		# 获取 Actor 当前位置
		var actor = battle.get_actor(target.id)
		if actor == null:
			push_warning("  [StartMoveAction] %s 未找到" % target.id)
			continue
		
		var from_hex: Dictionary = actor.hex_position
		if from_hex.is_empty():
			push_warning("  [StartMoveAction] %s 当前位置未找到" % target.id)
			continue
		
		# 预订目标格子
		var reserved: bool = battle.grid.reserve_tile(target_coord, target.id)
		
		if not reserved:
			var occupant = battle.grid.get_occupant_at(target_coord)
			var reservation = battle.grid.get_reservation(target_coord)
			push_error(
				"[StartMoveAction] BUG: %s 无法预订格子 (%d, %d)\n" % [target.id, target_coord["q"], target_coord["r"]] +
				"  当前占用: %s\n" % (occupant.get_id() if occupant != null else "none") +
				"  当前预订: %s\n" % (reservation if reservation != "" else "none") +
				"  这不应该发生！AI 决策应该过滤了不可用格子。"
			)
			continue
		
		print("  [StartMoveAction] %s 开始移动：从 (%d, %d) → (%d, %d)" % [
			target.id, from_hex["q"], from_hex["r"], target_coord["q"], target_coord["r"]
		])
		
		# 创建开始移动事件
		var move_event: Dictionary = ctx.event_collector.push(
			HexBattleReplayEvents.create_move_start_event(
				target.id,
				from_hex,
				target_coord
			)
		)
		all_events.append(move_event)
	
	return ActionResult.create_success_result(all_events, { "target_coord": target_coord })


func _resolve_coord(value: Variant, ctx: ExecutionContext) -> Dictionary:
	if value is Callable:
		return value.call(ctx) as Dictionary
	if value is Dictionary:
		return value
	return {}
