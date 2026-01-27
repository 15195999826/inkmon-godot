## ApplyMoveAction - 应用移动 Action
##
## 移动的第二阶段：执行实际移动，更新 grid 状态，取消预订，创建 MoveCompleteEvent。
class_name HexBattleApplyMoveAction
extends Action.BaseAction

const _HexCoord = preload("res://addons/ultra-grid-map/core/hex_coord.gd")

var _target_coord: DictResolver


## 构造函数
## @param target_selector: 目标选择器（移动的 Actor）
## @param target_coord: 目标坐标解析器
func _init(
	target_selector: TargetSelector,
	target_coord: DictResolver
) -> void:
	super._init(target_selector)
	type = "apply_move"
	_target_coord = target_coord


func execute(ctx: ExecutionContext) -> ActionResult:
	var targets := get_targets(ctx)
	
	# 解析目标坐标 (从事件中获取的是 Dictionary)
	var target_coord_dict := _target_coord.resolve(ctx)
	
	if target_coord_dict == null or target_coord_dict.is_empty():
		push_warning("  [ApplyMoveAction] 目标坐标未定义")
		return ActionResult.create_success_result([])
	
	# 转换为 HexCoord
	var target_coord = _HexCoord.from_dict(target_coord_dict)
	
	# 获取 HexBattle 实例
	var battle = ctx.gameplay_state
	
	# 对每个目标执行移动
	var all_events: Array = []
	for target in targets:
		# 获取 Actor 当前位置
		var actor = battle.get_actor(target.id)
		if actor == null:
			push_warning("  [ApplyMoveAction] %s 未找到" % target.id)
			continue
		
		var from_hex = actor.hex_position  # HexCoord
		if from_hex == null:
			push_warning("  [ApplyMoveAction] %s 当前位置未找到" % target.id)
			continue
		
		# 执行实际移动（move_occupant 会自动取消预订）
		var grid = battle.grid
		var move_success: bool = grid.move_occupant(from_hex, target_coord)
		
		if not move_success:
			var occupant: Variant = grid.get_occupant(target_coord)
			var reservation: String = grid.get_reservation(target_coord)
			var has_tile: bool = grid.has_tile(target_coord)
			push_error(
				"[ApplyMoveAction] BUG: %s 移动失败：从 (%d, %d) → (%d, %d)\n" % [
					target.id, from_hex.q, from_hex.r, target_coord.q, target_coord.r
				] +
				"  格子存在: %s\n" % str(has_tile) +
				"  当前占用: %s\n" % (occupant.get_id() if occupant != null else "none") +
				"  当前预订: %s\n" % (reservation if reservation != "" else "none") +
				"  这不应该发生！StartMoveAction 已预订该格子。"
			)
			continue
		
		# 更新 Actor 位置
		actor.hex_position = target_coord.duplicate()
		
		print("  [ApplyMoveAction] %s 移动完成：从 (%d, %d) → (%d, %d)" % [
			target.id, from_hex.q, from_hex.r, target_coord.q, target_coord.r
		])
		
		# 创建移动完成事件 (使用 Dictionary 以便 JSON 序列化)
		var move_event: Dictionary = ctx.event_collector.push(
			HexBattleReplayEvents.create_move_complete_event(
				target.id,
				from_hex.to_dict(),
				target_coord.to_dict()
			)
		)
		all_events.append(move_event)
	
	return ActionResult.create_success_result(all_events, { "target_coord": target_coord_dict })



