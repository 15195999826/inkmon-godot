## StartMoveAction - 开始移动 Action
##
## 移动的第一阶段：预订目标格子，创建 MoveStartEvent。
## 此时 Actor 仍在原位置，但目标格子已被预订。
class_name HexBattleStartMoveAction
extends Action.BaseAction



var _target_coord: DictResolver


## 构造函数
## @param target_selector: 目标选择器（移动的 Actor）
## @param target_coord: 目标坐标解析器
func _init(
	target_selector: TargetSelector,
	target_coord: DictResolver
) -> void:
	super._init(target_selector)
	type = "start_move"
	_target_coord = target_coord


func execute(ctx: ExecutionContext) -> ActionResult:
	var targets := get_targets(ctx)
	
	# 解析目标坐标 (从事件中获取的是 Dictionary)
	var target_coord_dict := _target_coord.resolve(ctx)
	
	if target_coord_dict == null or target_coord_dict.is_empty():
		push_warning("  [StartMoveAction] 目标坐标未定义")
		return ActionResult.create_success_result([])
	
	# 转换为 HexCoord
	var target_coord := HexCoord.from_dict(target_coord_dict)
	
	# 获取 HexBattle 实例
	var battle: HexBattle = ctx.game_state_provider
	
	# 对每个目标执行预订
	var all_events: Array[Dictionary] = []
	for target in targets:
		# 获取 Actor 当前位置
		var actor := battle.get_actor(target.id)
		if actor == null:
			push_warning("  [StartMoveAction] %s 未找到" % target.id)
			continue
		
		var from_hex := actor.hex_position  # HexCoord
		if not from_hex.is_valid():
			push_warning("  [StartMoveAction] %s 当前位置未找到" % target.id)
			continue
		
		# 预订目标格子
		var reserved: bool = battle.grid.reserve_tile(target_coord, target.id)
		
		if not reserved:
			var occupant := battle.grid.get_occupant(target_coord)
			var reservation := battle.grid.get_reservation(target_coord)
			push_error(
				"[StartMoveAction] BUG: %s 无法预订格子 (%d, %d)\n" % [target.id, target_coord.q, target_coord.r] +
				"  当前占用: %s\n" % (occupant.get_id() if occupant != null else "none") +
				"  当前预订: %s\n" % (reservation if reservation != "" else "none") +
				"  这不应该发生！AI 决策应该过滤了不可用格子。"
			)
			continue
		
		print("  [StartMoveAction] %s 开始移动：从 (%d, %d) → (%d, %d)" % [
			target.id, from_hex.q, from_hex.r, target_coord.q, target_coord.r
		])
		
		# 创建开始移动事件 (使用 Dictionary 以便 JSON 序列化)
		var event := BattleEvents.MoveStartEvent.create(
			target.id,
			from_hex.to_dict(),
			target_coord.to_dict()
		)
		var move_event: Dictionary = ctx.event_collector.push(event.to_dict())
		all_events.append(move_event)
	
	return ActionResult.create_success_result(all_events, { "target_coord": target_coord_dict })
