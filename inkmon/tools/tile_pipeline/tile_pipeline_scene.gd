class_name InkMonTilePipelineScene
extends Node2D

## 标准地块美术管线拼装场景（goal: tile-art-pipeline phase 2）。
## 读 baked manifest.json（角度/比例单一真相，Blender 写 Godot 读，两边禁止各写常量）
## + 复用 InkMonIsoSandboxDemoMap，拼 Blender 烘焙 hex 地块（海拔抬升 + painter 排序）
## + 装饰 billboard（针叶树/石头堆/灌木）+ 水带。
## dev-agent：挂通用 bridge（--dev-agent 启用）；scene ops = state / set_view / set_decor_density。

const DevAgentBridgeScript := preload("res://addons/lomolib/dev_agent/dev_agent_bridge.gd")

const BAKED_DIR := "res://inkmon/tools/tile_pipeline/assets/baked/"
const MANIFEST_PATH := BAKED_DIR + "manifest.json"
const SQRT3 := sqrt(3.0)
## 概念图的纸面底色
const PAPER_COLOR := Color(0.93, 0.91, 0.86)

var _manifest: Dictionary = {}
var _map_root: Node2D
var _camera: Camera2D
var _tile_count := 0
var _decor_count := 0
var _decor_density := 1.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(PAPER_COLOR)
	_manifest = _load_manifest()
	if _manifest.is_empty():
		push_error("tile_pipeline: manifest 加载失败 %s" % MANIFEST_PATH)
		return
	_camera = Camera2D.new()
	_camera.name = "Camera"
	add_child(_camera)
	_camera.make_current()
	_rebuild()
	_install_dev_agent()


## manifest 驱动的整图重建（density 调装饰密度，1.0 = 默认）。
func _rebuild() -> void:
	if _map_root != null:
		_map_root.queue_free()
	_map_root = Node2D.new()
	_map_root.name = "MapRoot"
	add_child(_map_root)
	_tile_count = 0
	_decor_count = 0

	var pitch := float(_manifest["pitch_deg"])
	var yaw := float(_manifest["yaw_deg"])
	var edge_px := float(_manifest["px_per_hex_edge"])
	var px_per_unit := float(_manifest["px_per_unit"])
	var elevation_step_px := float(_manifest["elevation_step_world"]) * px_per_unit
	var ground := InkMonRender2DIsoProjection.ground_basis(pitch, yaw)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260611

	var tiles := InkMonIsoSandboxDemoMap.generate()
	var entries: Array[Dictionary] = []
	for key in tiles.keys():
		var axial := key as Vector2i
		var info := tiles[axial] as Dictionary
		var terrain := str(info["terrain"])
		var elevation := int(info["elevation"])
		var center_plane := _center_of_flat_top(axial, edge_px)
		var ground_screen := ground * center_plane
		var lift := InkMonRender2DIsoProjection.height_to_screen(float(elevation) * elevation_step_px, pitch)
		var anchor := ground_screen - Vector2(0.0, lift)

		entries.append({
			"sort": Vector2(ground_screen.x, ground_screen.y),
			"order": 0,
			"asset": "tile_%s_e%d" % [terrain, elevation],
			"pos": anchor,
			"axial": axial,
		})
		_tile_count += 1

		var decor := _pick_decor(info, rng)
		if decor != "":
			# 平面内 jitter：打破"装饰全在 tile 正中"的机械感（树保持居中更像概念图）
			var jitter := Vector2.ZERO
			if decor != "decor_pine" and decor != "decor_pine_tall":
				jitter = Vector2(rng.randf_range(-0.28, 0.28), rng.randf_range(-0.28, 0.28)) * edge_px
			entries.append({
				"sort": Vector2(ground_screen.x, ground_screen.y),
				"order": 1,
				"asset": decor,
				"pos": ground * (center_plane + jitter) - Vector2(0.0, lift),
				"axial": axial,
			})
			_decor_count += 1

	# painter：投影后地面 y 远→近，同 y 按 x，再 tile 先于其装饰
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := a["sort"] as Vector2
		var sb := b["sort"] as Vector2
		if sa.y != sb.y:
			return sa.y < sb.y
		if sa.x != sb.x:
			return sa.x < sb.x
		return int(a["order"]) < int(b["order"]))

	for i in entries.size():
		var entry := entries[i]
		var sprite := _make_sprite(str(entry["asset"]), entry["axial"] as Vector2i)
		if sprite == null:
			continue
		sprite.name = "%s_%d" % [str(entry["asset"]), i]
		sprite.position = entry["pos"] as Vector2
		_map_root.add_child(sprite)

	_fit_camera()


## flat-top axial → hex 平面中心（未投影，像素）。
func _center_of_flat_top(axial: Vector2i, edge_px: float) -> Vector2:
	return Vector2(1.5 * float(axial.x), SQRT3 * (float(axial.y) + float(axial.x) * 0.5)) * edge_px


func _pick_decor(info: Dictionary, rng: RandomNumberGenerator) -> String:
	var terrain := str(info["terrain"])
	if bool(info.get("tree", false)):
		return "decor_pine" if rng.randf() < 0.6 else "decor_pine_tall"
	var roll := rng.randf()
	match terrain:
		InkMonIsoSandboxDemoMap.TERRAIN_GRASS:
			if roll < 0.22 * _decor_density:
				return "decor_bush"
			elif roll < 0.30 * _decor_density:
				return "decor_rocks"
		InkMonIsoSandboxDemoMap.TERRAIN_DIRT:
			if roll < 0.20 * _decor_density:
				return "decor_rocks"
			elif roll < 0.30 * _decor_density:
				return "decor_bush"
		InkMonIsoSandboxDemoMap.TERRAIN_STONE:
			if roll < 0.16 * _decor_density:
				return "decor_rocks"
	return ""


func _make_sprite(asset_name: String, axial: Vector2i) -> Sprite2D:
	var assets := _manifest["assets"] as Dictionary
	if not assets.has(asset_name):
		push_error("tile_pipeline: manifest 缺资产 %s" % asset_name)
		return null
	var meta := assets[asset_name] as Dictionary
	# 变体：按 axial 哈希确定性选图（打破同地形重复感；单变体资产退化为 file）
	var variants: Array = meta.get("variants", [meta["file"]])
	var pick := posmod((axial.x * 73856093) ^ (axial.y * 19349663), variants.size())
	var texture := load(BAKED_DIR + str(variants[pick])) as Texture2D
	if texture == null:
		push_error("tile_pipeline: 贴图加载失败 %s" % str(meta["file"]))
		return null
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	# anchor（资产原点投影位置）→ 节点原点；目前 anchor = 画布中心，offset 为零，
	# 但按 manifest 算保证将来裁切画布也不破位。
	var size := meta["size_px"] as Array
	var anchor := meta["anchor_px"] as Array
	sprite.offset = Vector2(
		float(size[0]) * 0.5 - float(anchor[0]),
		float(size[1]) * 0.5 - float(anchor[1])
	)
	return sprite


func _fit_camera() -> void:
	if _tile_count == 0:
		return
	var rect := Rect2()
	var first := true
	for child in _map_root.get_children():
		var sprite := child as Sprite2D
		if sprite == null:
			continue
		if first:
			rect = Rect2(sprite.position, Vector2.ZERO)
			first = false
		else:
			rect = rect.expand(sprite.position)
	# 资产画布一半作余量（覆盖贴图本体伸出锚点的部分）
	var pad := float(_manifest["px_per_hex_edge"]) * 2.2
	rect = rect.grow(pad)
	var vp := get_viewport_rect().size
	var zoom := minf(vp.x / rect.size.x, vp.y / rect.size.y)
	_camera.position = rect.get_center()
	_camera.zoom = Vector2(zoom, zoom)


func get_debug_state() -> Dictionary:
	return {
		"node_type": "InkMonTilePipelineScene",
		"tile_count": _tile_count,
		"decor_count": _decor_count,
		"decor_density": _decor_density,
		"pitch_deg": float(_manifest.get("pitch_deg", 0.0)),
		"yaw_deg": float(_manifest.get("yaw_deg", 0.0)),
		"hex_orientation": str(_manifest.get("hex_orientation", "")),
		"px_per_hex_edge": float(_manifest.get("px_per_hex_edge", 0.0)),
		"camera_zoom": _camera.zoom.x if _camera != null else 0.0,
		"camera_pos": [_camera.position.x, _camera.position.y] if _camera != null else [],
	}


# === dev-agent scene ops（DevAgentBridge 契约：get_supported_ops + run_scene_op）===

func get_supported_ops() -> Array:
	return ["state", "set_view", "set_decor_density"]


func run_scene_op(op_name: String, args: Dictionary) -> Dictionary:
	match op_name:
		"state":
			return {"ok": true, "message": "tile pipeline state", "data": get_debug_state()}
		"set_view":
			if args.has("zoom"):
				var z := float(args["zoom"])
				_camera.zoom = Vector2(z, z)
			if args.has("x") or args.has("y"):
				_camera.position = Vector2(
					float(args.get("x", _camera.position.x)),
					float(args.get("y", _camera.position.y))
				)
			return {"ok": true, "message": "view applied", "data": get_debug_state()}
		"set_decor_density":
			_decor_density = float(args.get("density", 1.0))
			_rebuild()
			return {"ok": true, "message": "decor density applied + rebuilt", "data": get_debug_state()}
		_:
			return {"ok": false, "message": "unknown scene op: %s" % op_name}


func _install_dev_agent() -> void:
	var bridge := DevAgentBridgeScript.new()
	bridge.name = "DevAgentBridge"
	bridge.scene_ops_path = NodePath("..")
	add_child(bridge)


func _load_manifest() -> Dictionary:
	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	if text.is_empty():
		return {}
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		return data as Dictionary
	return {}
