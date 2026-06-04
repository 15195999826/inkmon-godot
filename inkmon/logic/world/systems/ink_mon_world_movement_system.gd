class_name InkMonWorldMovementSystem
extends System
## 主世界 tick 第二阶段:推进每个移动中 world actor 的进度,逐格跨越 + emit actor_position_changed。
##
## 逻辑住 GI;本 System 只是 base_tick 的优先级调度钩子(HIGH = 在 CommandDrain 之后)。


func _init() -> void:
	super._init(System.SystemPriority.HIGH)
	type = "inkmon_world_movement"


func tick(_actors: Array[Actor], dt: float) -> void:
	var gi := get_instance() as InkMonWorldGI
	if gi != null:
		gi.advance_world_movement(dt)
