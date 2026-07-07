extends Node
## overworld 水面 shader 截图 harness（非断言，不进 launcher）：world_main + water_bodies，
## 验证 water 格出 toon 青绿 shader 水面（岸沫 / 裂纹网线 / 顺流漂移动画）替代 baked 水 tile，
## 以及相邻 body 落差边的瀑布竖直面（water_face.gdshader 下落条纹 + 下位水面落水翻涌）。
## 跑法: godot --path . inkmon/tests/shot_water_overworld.tscn —— **不带 --headless**。
## 输出: .claude/tmp/ui-shots/water_overworld_*.png（--shot-dir= 可覆盖）。

const DEFAULT_SHOT_DIR := "res://.claude/tmp/ui-shots"

var _map: InkMonRender2DBakedHexMap = null
var _camera: Camera2D = null
var _shot_dir := ""


func _ready() -> void:
	get_window().size = Vector2i(1600, 900)
	_shot_dir = ProjectSettings.globalize_path(DEFAULT_SHOT_DIR)
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shot-dir="):
			_shot_dir = str(arg).trim_prefix("--shot-dir=")
	DirAccess.make_dir_recursive_absolute(_shot_dir)

	var bundle := InkMonMapLoader.load_bundle("world_main")
	if bundle.is_empty():
		push_error("[water_probe] load_bundle failed")
		get_tree().quit(1)
		return
	_map = InkMonRender2DBakedHexMap.new()
	add_child(_map)
	if not _map.setup_from_bundle(bundle, 96.0):
		push_error("[water_probe] setup_from_bundle failed")
		get_tree().quit(1)
		return
	print("  [water_probe] tiles=%d" % _map.tile_count())

	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()

	# 瀑布特写（river_upper e1 唇口 (2,-4)/(3,-4) → river_lower e0 潭）。
	_camera.position = (_map.coord_to_world(2, -4) + _map.coord_to_world(3, -3)) * 0.5
	_camera.zoom = Vector2(1.6, 1.6)
	for _i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("water_overworld_fall_a")
	# B 帧（隔 0.7s 验证瀑布面下落条纹 + 潭面翻涌在动）。
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	_save("water_overworld_fall_b")

	# 下游河中段特写（东界主干）。
	_camera.position = _map.coord_to_world(5, -2)
	_camera.zoom = Vector2(1.7, 1.7)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_save("water_overworld_river_a")
	# B 帧（隔 1.2s 验证裂纹/漂移动画在动）。
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	_save("water_overworld_river_b")

	# creek_mid 斜带特写（另一片水域，另一个 flow）。
	_camera.position = _map.coord_to_world(3, 2)
	_camera.zoom = Vector2(1.9, 1.9)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_save("water_overworld_creek")

	# 全景。
	_camera.position = _map.coord_to_world(1, -1)
	_camera.zoom = Vector2(0.42, 0.42)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_save("water_overworld_full")

	get_tree().quit(0)


func _save(shot_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_shot_dir, shot_name]
	var err := image.save_png(path)
	print("  [water_probe] %s -> %s (err=%d)" % [shot_name, path, err])
