class_name InkMonCommandDrainSystem
extends System
## 主世界 tick 第一阶段:抽干本帧 UI 入队的 command,应用为 world actor 移动意图(latest-wins)。
##
## 逻辑住 GI(它持 grid + actors);本 System 只是 base_tick 的优先级调度钩子(HIGHEST = 先于 Movement)。


func _init() -> void:
	super._init(System.SystemPriority.HIGHEST)
	type = "inkmon_command_drain"


func tick(_actors: Array[Actor], _dt: float) -> void:
	var gi := get_instance() as InkMonWorldGI
	if gi != null:
		gi.drain_commands()
