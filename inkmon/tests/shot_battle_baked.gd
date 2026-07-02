extends Node
## 战斗场景截图 harness（非断言型，不进 launcher）：InkMonBattle2DView + 假 replay，
## 验证 baked battle_main 地图层的视觉（T2 G2 迁移证据）。
## 跑法: godot --path . inkmon/tests/shot_battle_baked.tscn  —— **不带 --headless**。
## 输出: .claude/tmp/ui-shots/10_battle_baked.png（--shot-dir= 可覆盖）。

const DEFAULT_SHOT_DIR := "res://.claude/tmp/ui-shots"

var _shot_dir_global := ""


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	_shot_dir_global = ProjectSettings.globalize_path(DEFAULT_SHOT_DIR)
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shot-dir="):
			_shot_dir_global = str(arg).trim_prefix("--shot-dir=")
	DirAccess.make_dir_recursive_absolute(_shot_dir_global)

	var view := InkMonBattle2DView.new()
	add_child(view)
	await get_tree().process_frame
	view.play_replay(_fake_record(), {"result": "shot-harness"})
	# 半程截图：u_r 正在移动、双方在场。
	for _i in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/10_battle_baked.png" % _shot_dir_global
	var err := image.save_png(path)
	print("  [shot] 10_battle_baked -> %s (err=%d)" % [path, err])
	print("SHOT_HARNESS_RESULT: DONE - shots in %s" % _shot_dir_global)
	get_tree().quit(0 if err == OK else 1)


func _fake_record() -> Dictionary:
	var move_events: Array[Dictionary] = [
		{"kind": "inkmon_move_start", "actor_id": "u_r", "from_hex": {"q": 3, "r": 0}, "to_hex": {"q": 2, "r": 0}},
	]
	var no_abilities: Array[Dictionary] = []
	return {
		"meta": {"tickInterval": 100, "totalFrames": 30},
		"initialActors": [
			{"id": "u_l", "team": 0, "displayName": "L", "position": [-3, 0, 0], "attributes": {"hp": 30, "max_hp": 30}, "abilities": no_abilities, "tags": {}},
			{"id": "u_r", "team": 1, "displayName": "R", "position": [3, 0, 0], "attributes": {"hp": 20, "max_hp": 20}, "abilities": no_abilities, "tags": {}},
		],
		"timeline": [
			{"frame": 1, "events": move_events},
		],
	}
