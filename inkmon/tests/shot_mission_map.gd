extends Node
## 开窗截图自验工具 (非测试组): 出征大地图 view 渲染成什么样, 截 PNG 供人/AI 目检。
## 跑法: godot --path . inkmon/tests/shot_mission_map.tscn (不带 --headless)。


const SHOT_PATH := "res://.claude/tmp/shot_mission_map.png"


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await _run()


func _run() -> void:
	var host := InkMonWorldHost.new()
	add_child(host)
	await get_tree().process_frame
	await get_tree().process_frame
	var presentation := host.get_node("Presentation") as InkMonWorldPresentation
	presentation.run_npc_action_for("guild", InkMonGuildNpcHandler.ACTION_START_MISSION)
	await get_tree().create_timer(0.8).timeout
	var gi: InkMonWorldGI = host._world_gi
	if gi.mission_state != null:
		var nexts := gi.mission_state.map.next_node_ids(gi.mission_state.current_node_id)
		if not nexts.is_empty():
			gi.submit(InkMonMissionMoveCommand.new(nexts[0]))
	await get_tree().create_timer(0.8).timeout
	var image := get_viewport().get_texture().get_image()
	var absolute := ProjectSettings.globalize_path(SHOT_PATH)
	image.save_png(absolute)
	print("SHOT_SAVED: %s" % absolute)
	get_tree().quit(0)
