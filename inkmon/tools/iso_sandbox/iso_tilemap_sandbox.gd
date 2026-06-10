class_name InkMonIsoTilemapSandbox
extends Node2D

## iso 沙盒（TileMap 版）：Godot 内置 hex tile 管线对照版。F6 直接跑。
##
## 本质限制：tile 管线 = 角度烘焙进贴图 + 网格取向固定（flat-top / squish 0.5 烘死），
## **不可运行时调角** —— 动态调角请看对照场景 iso_angle_sandbox.tscn（绘制版）。
## 高度差用"每级海拔一个 TileMapLayer、整层上移"的烘焙管线惯用手法。

const MAX_ELEVATION := 2
## 每级海拔整层上移像素 ≈ 世界高度 × cos(30°)，与烘焙 pitch 对齐的近似演示值。
const ELEV_LAYER_RAISE := 10.0

var _layers: Array[TileMapLayer] = []


func _ready() -> void:
	var camera := Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	camera.make_current()

	var tile_set := _build_tile_set()
	for level in range(MAX_ELEVATION + 1):
		var layer := TileMapLayer.new()
		layer.name = "Elev%d" % level
		layer.tile_set = tile_set
		layer.y_sort_enabled = true
		layer.position = Vector2(0.0, -ELEV_LAYER_RAISE * float(level))
		add_child(layer)
		_layers.append(layer)

	_paint(InkMonIsoSandboxDemoMap.generate())
	_build_note()


func get_debug_state() -> Dictionary:
	var base := _layers[0]
	var cells := base.get_used_cells()
	var probe := cells[0] as Vector2i if not cells.is_empty() else Vector2i.ZERO
	var raised_count := 0
	for level in range(1, _layers.size()):
		raised_count += _layers[level].get_used_cells().size()
	return {
		"node_type": "InkMonIsoTilemapSandbox",
		"base_cell_count": cells.size(),
		"raised_cell_count": raised_count,
		"has_tile_set": base.tile_set != null,
		"map_roundtrip_ok": base.local_to_map(base.map_to_local(probe)) == probe,
	}


func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_VERTICAL
	tile_set.tile_size = Vector2i(InkMonIsoTileBaker.TILE_W, InkMonIsoTileBaker.TILE_H)

	var source := TileSetAtlasSource.new()
	source.texture = InkMonIsoTileBaker.bake_atlas()
	source.texture_region_size = InkMonIsoTileBaker.REGION
	for column in range(4):
		var coords := Vector2i(column, 0)
		source.create_tile(coords)
		# 贴图比名义格高出 SKIRT（侧裙只朝下垂）：把贴图中心下移半个裙高对齐顶面中心。
		source.get_tile_data(coords, 0).texture_origin = Vector2i(0, -InkMonIsoTileBaker.SKIRT / 2)
	tile_set.add_source(source, 0)
	return tile_set


func _paint(map: Dictionary) -> void:
	for key in map.keys():
		var axial := key as Vector2i
		var info := map[key] as Dictionary
		var column := InkMonIsoSandboxDemoMap.atlas_column(str(info["terrain"]))
		var elevation := mini(int(info["elevation"]), MAX_ELEVATION)
		# 0..elevation 每层都铺（下层垫底，避免高台侧面透空）
		for level in range(elevation + 1):
			_layers[level].set_cell(axial, 0, Vector2i(column, 0))


func _build_note() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12.0, 12.0)
	layer.add_child(panel)
	var label := Label.new()
	label.text = "TileMap 版：角度烘焙 flat-top / squish 0.5（pitch 30°）\ntile 管线不可动态调角 —— 动态版见 iso_angle_sandbox.tscn"
	panel.add_child(label)
