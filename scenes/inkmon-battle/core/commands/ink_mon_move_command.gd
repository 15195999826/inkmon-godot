class_name InkMonMoveCommand
extends InkMonWorldCommand
## 移动玩家到目标格(latest-wins,方案 A)。apply 委托 GI 解析目标 + 排路;逐格推进的回流走
## `actor_position_changed` signal(非 command_applied —— move 无 UI message,view 据位置信号补间)。


var target_coord: Vector2i


func _init(p_target_coord: Vector2i) -> void:
	target_coord = p_target_coord


func apply(gi: InkMonWorldGI) -> void:
	gi.apply_move_player(target_coord)
