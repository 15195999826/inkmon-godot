extends Node
## 装饰物地图层截图 harness（非断言型，不进 launcher）：world_main + inkmon-decor-basic，
## 验证 T3 decor 消费端（影层分离两 sprite / 画家序 tile<shadow<decor / offset 落点 / 密度）。
## 跑法: godot --path . inkmon/tests/shot_world_decor.tscn —— **不带 --headless**。
## 输出: .claude/tmp/ui-shots/13_world_decor.png（--shot-dir= 可覆盖）。

const DEFAULT_SHOT_DIR := "res://.claude/tmp/ui-shots"


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var shot_dir := ProjectSettings.globalize_path(DEFAULT_SHOT_DIR)
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shot-dir="):
			shot_dir = str(arg).trim_prefix("--shot-dir=")
	DirAccess.make_dir_recursive_absolute(shot_dir)

	var bundle := InkMonMapLoader.load_bundle("world_main")
	if bundle.is_empty():
		push_error("[shot_world_decor] load_bundle failed")
		get_tree().quit(1)
		return
	var map := InkMonRender2DBakedHexMap.new()
	add_child(map)
	if not map.setup_from_bundle(bundle, 96.0):
		push_error("[shot_world_decor] setup_from_bundle failed")
		get_tree().quit(1)
		return
	print("  [shot] tiles=%d decors=%d" % [map.tile_count(), map.decor_count()])

	# 相机对准 decor 密集区（(-3,2) 同格双 decor 一带）。
	var camera := Camera2D.new()
	camera.position = map.coord_to_world(-3, 1)
	camera.zoom = Vector2(1.6, 1.6)
	add_child(camera)
	camera.make_current()

	for _i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/13_world_decor.png" % shot_dir
	var err := image.save_png(path)
	print("  [shot] 13_world_decor -> %s (err=%d)" % [path, err])
	get_tree().quit(0)
