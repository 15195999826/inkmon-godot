extends Node
## T6 面片遮挡目检截图 harness（非断言型，不进 launcher）：world_main +
## inkmon-patches-main 台阶复合体，验证 ysort-occluder-marking 消费端——
## 整图垫底 Sprite2D + 遮挡体 Polygon2D（baseline_y 入 Y-sort）+ 被盖格压制。
## 两个替身单位：一个站台阶脚下（完整显示），一个站高地身后（被遮挡体盖下半身、
## 探出半身）。
## 跑法: godot --path . inkmon/tests/shot_patch_occlusion.tscn —— **不带 --headless**。
## 输出: .claude/tmp/ui-shots/14_patch_occlusion.png（--shot-dir= 可覆盖）。

const DEFAULT_SHOT_DIR := "res://.claude/tmp/ui-shots"
const ANCHOR := Vector2i(-2, -1)
const FRONT_UNIT_CELL := Vector2i(-2, -1)   # 台阶脚下（面片近端，完整显示）
const BEHIND_UNIT_CELL := Vector2i(-1, -4)  # 高地正后方（应被 e2 遮挡体盖住下半身）


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var shot_dir := ProjectSettings.globalize_path(DEFAULT_SHOT_DIR)
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shot-dir="):
			shot_dir = str(arg).trim_prefix("--shot-dir=")
	DirAccess.make_dir_recursive_absolute(shot_dir)

	var bundle := InkMonMapLoader.load_bundle("world_main")
	if bundle.is_empty():
		push_error("[shot_patch_occlusion] load_bundle failed")
		get_tree().quit(1)
		return
	var map := InkMonRender2DBakedHexMap.new()
	add_child(map)
	if not map.setup_from_bundle(bundle, 96.0):
		push_error("[shot_patch_occlusion] setup_from_bundle failed")
		get_tree().quit(1)
		return

	# 单位/遮挡体同场 Y-sort 容器（overworld view 同构接线）。
	var units_root := Node2D.new()
	units_root.name = "UnitsRoot"
	units_root.y_sort_enabled = true
	add_child(units_root)
	var occluders := map.build_occluders(units_root)
	print("  [shot] tiles=%d patches=%d occluders=%d decors=%d" % [map.tile_count(), map.patch_count(), occluders, map.decor_count()])
	if map.patch_count() < 1 or occluders < 1:
		push_error("[shot_patch_occlusion] expected >=1 patch and >=1 occluder")
		get_tree().quit(1)
		return

	units_root.add_child(_make_dummy_unit("unit_front", map.coord_to_world(FRONT_UNIT_CELL.x, FRONT_UNIT_CELL.y), Color(0.95, 0.45, 0.25)))
	units_root.add_child(_make_dummy_unit("unit_behind", map.coord_to_world(BEHIND_UNIT_CELL.x, BEHIND_UNIT_CELL.y), Color(0.30, 0.65, 0.95)))

	var camera := Camera2D.new()
	camera.position = map.coord_to_world(ANCHOR.x, ANCHOR.y - 1)
	camera.zoom = Vector2(1.35, 1.35)
	add_child(camera)
	camera.make_current()

	for _i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/14_patch_occlusion.png" % shot_dir
	var err := image.save_png(path)
	print("  [shot] 14_patch_occlusion -> %s (err=%d)" % [path, err])
	get_tree().quit(0)


## 替身单位：脚点在 position（y-sort 键），胶囊身体向上伸展 —— 高 160px 足够
## 探出 e2 遮挡体上缘（半身效果目检）。
func _make_dummy_unit(unit_name: String, foot: Vector2, color: Color) -> Node2D:
	var unit := Node2D.new()
	unit.name = unit_name
	unit.position = foot
	var body := Polygon2D.new()
	var w := 46.0
	var h := 160.0
	var pts := PackedVector2Array()
	for i in range(13):
		var a := PI * float(i) / 12.0
		pts.append(Vector2(-cos(a) * w * 0.5, -h + (1.0 - sin(a)) * w * 0.5))
	for i in range(13):
		var a := PI * float(i) / 12.0
		pts.append(Vector2(cos(a) * w * 0.5, -(1.0 - sin(a)) * w * 0.5))
	body.polygon = pts
	body.color = color
	unit.add_child(body)
	var outline := Line2D.new()
	outline.points = pts
	outline.closed = true
	outline.width = 3.0
	outline.default_color = Color(0.12, 0.08, 0.06)
	unit.add_child(outline)
	return unit
