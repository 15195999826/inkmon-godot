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

	# M2.2 野群模板生成图 (森林皮肤 + 含障碍的 seed): 同一 view 换图重放, 验证生成棋盘渲染。
	var wild_doc := _wild_doc_with_obstacles()
	view.play_replay(_fake_record(), {"result": "wild-shot"}, wild_doc)
	for _i in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var wild_image := get_viewport().get_texture().get_image()
	var wild_path := "%s/11_wild_battle_map.png" % _shot_dir_global
	var wild_err := wild_image.save_png(wild_path)
	print("  [shot] 11_wild_battle_map (%s) -> %s (err=%d)" % [str(wild_doc.get("map_id", "")), wild_path, wild_err])
	print("SHOT_HARNESS_RESULT: DONE - shots in %s" % _shot_dir_global)
	get_tree().quit(0 if err == OK and wild_err == OK else 1)


## 找一个必带障碍的野群图 seed (截图要看得到 water 障碍)。生成确定性 → 找到的 seed 稳定。
func _wild_doc_with_obstacles() -> Dictionary:
	for seed_value in range(1, 50):
		var doc := InkMonWildBattleMapGen.generate_doc(seed_value, InkMonWorldMapData.TERRAIN_FOREST)
		for tile_value in (doc.get("tiles", []) as Array):
			if str((tile_value as Dictionary).get("terrain", "")) == InkMonWildBattleMapGen.OBSTACLE_TERRAIN:
				return doc
	return InkMonWildBattleMapGen.generate_doc(1, InkMonWorldMapData.TERRAIN_FOREST)


func _fake_record() -> Dictionary:
	var move_events: Array[Dictionary] = [
		{"kind": "inkmon_move_start", "actor_id": "u_r", "from_hex": {"q": 3, "r": 0}, "to_hex": {"q": 2, "r": 0}},
	]
	return {
		"meta": {"tickInterval": 100, "totalFrames": 30},
		"world_snapshot": {"actors": [
			{"id": "u_l", "team": 0, "displayName": "L", "position": [-3, 0, 0], "attributes": {"hp": 30, "max_hp": 30}},
			{"id": "u_r", "team": 1, "displayName": "R", "position": [3, 0, 0], "attributes": {"hp": 20, "max_hp": 20}},
		]},
		"timeline": [
			{"frame": 1, "events": move_events},
		],
	}
