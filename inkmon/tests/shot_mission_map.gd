extends Node
## 开窗截图自验工具 (非测试组): 出征大地图 view 渲染成什么样, 截 PNG 供人/AI 目检。
## 跑法: godot --path . inkmon/tests/shot_mission_map.tscn (不带 --headless)。


const SHOT_PATH := "res://.claude/tmp/shot_mission_map.png"
const SHOT_MODAL_PATH := "res://.claude/tmp/shot_departure_modal.png"
const SHOT_BOARD_PATH := "res://.claude/tmp/shot_quest_board.png"


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await _run()


func _run() -> void:
	var host := InkMonWorldHost.new()
	add_child(host)
	await get_tree().process_frame
	await get_tree().process_frame
	var presentation := host.get_node("Presentation") as InkMonWorldPresentation
	# Phase 3 委托板: guild 抽屉里的委托卡列表 (先截一张)。
	presentation.open_npc_menu("guild")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var board_image := get_viewport().get_texture().get_image()
	var board_absolute := ProjectSettings.globalize_path(SHOT_BOARD_PATH)
	board_image.save_png(board_absolute)
	print("SHOT_SAVED: %s" % board_absolute)
	# 接板上第一张单出征 (guild 全链)。
	var gi_for_quest: InkMonWorldGI = host._world_gi
	if gi_for_quest.quest_board.is_empty():
		presentation.run_npc_action_for("guild", InkMonGuildNpcHandler.ACTION_START_MISSION)
	else:
		presentation.run_npc_action_for("guild",
			InkMonGuildNpcHandler.ACTION_QUEST_PREFIX + gi_for_quest.quest_board[0].quest_id)
	await get_tree().create_timer(0.4).timeout
	# M2.4: guild 出征先过出发确认 modal —— 截一张 modal, 再按 Confirm (默认粮数) 进大地图。
	var modal := presentation.get_node_or_null("ModalLayer/DepartureModalRoot") as InkMonDepartureModal
	if modal != null and modal.is_open():
		await RenderingServer.frame_post_draw
		var modal_image := get_viewport().get_texture().get_image()
		var modal_absolute := ProjectSettings.globalize_path(SHOT_MODAL_PATH)
		modal_image.save_png(modal_absolute)
		print("SHOT_SAVED: %s" % modal_absolute)
		(modal.get_debug_controls().get("confirm_button", null) as Button).pressed.emit()
	await get_tree().create_timer(0.8).timeout
	var gi: InkMonWorldGI = host._world_gi
	if gi.mission_state != null:
		# 选非战斗出边 (M2.2 踩野群必战会切进战斗回放, 本 shot 要的是大地图本体)。
		for next_id in gi.mission_state.map.next_node_ids(gi.mission_state.current_node_id):
			if str(gi.mission_state.map.get_node_info(next_id).get("kind", "")) != InkMonMissionMapData.NODE_BATTLE:
				gi.submit(InkMonMissionMoveCommand.new(next_id))
				break
	await get_tree().create_timer(0.8).timeout
	var image := get_viewport().get_texture().get_image()
	var absolute := ProjectSettings.globalize_path(SHOT_PATH)
	image.save_png(absolute)
	print("SHOT_SAVED: %s" % absolute)
	get_tree().quit(0)
