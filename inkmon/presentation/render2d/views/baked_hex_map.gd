class_name InkMonRender2DBakedHexMap
extends Node2D

## flat-top baked tile 地图层（T2 美术资产契约消费端；接替 adr/0007 的
## InkMonRender2DIsoHexGrid pointy 线框件——该用法随本件退役）。
##
## 输入 = InkMonMapLoader.load_bundle 的产物（map + terrains + set manifest + model）。
## 摆放语义照抄探索期 PATCH 模式（inkmon美术探索/art_tile_map_base.gd），常量全部来自
## set manifest 的 projection 块（发布时由 Lab 契约单源盖章）：
##   - 平面中心 = edge_px · (1.5q, √3(r + q/2))；屏幕 = ground_basis(pitch, yaw) × 平面
##   - 海拔抬升 = height_to_screen(elevation × elevation_step_world × px_per_unit, pitch)
##   - sprite centered，offset = size_px/2 − anchor_px（anchor = 顶面中心@海拔0平面）
##   - 变体：格子显式 variant 优先，否则 posmod((q·73856093) ^ (r·19349663), n) 确定性抽签
##   - 画家序：(screen_y, screen_x) 排序后按序 add_child（树序即绘制序，不用 z_index；
##     decor 进场时沿同一排序列表插入）
##
## 坐标 API 与旧共享网格件同形（coord_to_world(_f) / world_to_coord_f / has_coord /
## get_all_coords），差异：返回的屏幕坐标**含海拔抬升**（单位站在顶面），拾取按画家序
## 反向做 lift-aware 命中（先命中视觉最靠前的格子）。

const SQRT3 := sqrt(3.0)

var _model: GridMapModel = null
var _ground := Transform2D.IDENTITY
var _ground_inv := Transform2D.IDENTITY
var _pitch_deg := 0.0
## 显示用 px/边（= display_edge_px 或素材原生密度）；坐标 API 全部在这个尺度上。
var _edge_px := 0.0
## 素材原生 px/边（manifest projection.px_per_hex_edge）；sprite 按二者比值缩放。
var _native_edge_px := 0.0
var _sprite_scale := 1.0
var _px_per_unit := 0.0
var _elevation_step_world := 0.5
var _families: Dictionary = {}
var _set_dir := ""
var _tiles_root: Node2D = null
var _tile_count := 0
## 拾取用画家序坐标缓存（屏幕 y/x 升序；拾取时反向扫）。
var _paint_order: Array[Vector2i] = []


## bundle = InkMonMapLoader.load_bundle(...)。返回是否成功建层。
## display_edge_px：视图显示密度（px/边）；<=0 用素材原生密度。素材按
## display/native 比值等比缩放——摆放契约不变，只是换个"镜头倍率"，让既有
## avatar / marker / 相机的像素尺度不用跟着素材密度走。
func setup_from_bundle(bundle: Dictionary, display_edge_px: float = 0.0) -> bool:
	var model := bundle.get("model", null) as GridMapModel
	var manifest := bundle.get("manifest", null) as Dictionary
	var projection := bundle.get("projection", null) as Dictionary
	if model == null or manifest == null or projection == null or projection.is_empty():
		push_error("baked_hex_map: incomplete bundle (model/manifest/projection)")
		return false
	_model = model
	_pitch_deg = float(projection.get("pitch_deg", 35.26))
	var yaw_deg := float(projection.get("yaw_deg", -15.0))
	_native_edge_px = float(projection.get("px_per_hex_edge", 0.0))
	if _native_edge_px <= 0.0:
		push_error("baked_hex_map: projection.px_per_hex_edge missing/invalid")
		return false
	_edge_px = display_edge_px if display_edge_px > 0.0 else _native_edge_px
	_sprite_scale = _edge_px / _native_edge_px
	_px_per_unit = float(projection.get("runtime_px_per_unit", _native_edge_px)) * _sprite_scale
	_elevation_step_world = float(projection.get("elevation_step_world", 0.5))
	_ground = InkMonRender2DIsoProjection.ground_basis(_pitch_deg, yaw_deg)
	_ground_inv = _ground.affine_inverse()
	_families = manifest.get("families", {}) as Dictionary
	_set_dir = str(bundle.get("set_dir", ""))
	_rebuild_sprites()
	return true


func _rebuild_sprites() -> void:
	if _tiles_root != null:
		_tiles_root.queue_free()
	_tiles_root = Node2D.new()
	_tiles_root.name = "TilesRoot"
	add_child(_tiles_root)
	_tile_count = 0
	_paint_order.clear()

	var entries: Array[Dictionary] = []
	for coord in _model.get_all_coords():
		var axial := coord.to_axial()
		var screen := _ground * _plane_center(axial)
		entries.append({"axial": axial, "screen": screen})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := a["screen"] as Vector2
		var sb := b["screen"] as Vector2
		if sa.y != sb.y:
			return sa.y < sb.y
		return sa.x < sb.x
	)

	# 画家序 = 子节点树序（按 screen y/x 升序 add_child，后加的画在上面）。不用
	# z_index：单位/marker 由 view 以兄弟节点后置画在整个地面之上（与旧网格行为一致），
	# tile 间遮挡靠这里的排序。decor 进场（T3）沿同一列表插入即可。
	for i in entries.size():
		var entry := entries[i]
		var axial := entry["axial"] as Vector2i
		_paint_order.append(axial)
		var sprite := _make_tile_sprite(axial)
		if sprite == null:
			continue
		sprite.position = entry["screen"] as Vector2 - Vector2(0.0, _lift_of(axial))
		_tiles_root.add_child(sprite)
		_tile_count += 1


func _make_tile_sprite(axial: Vector2i) -> Sprite2D:
	var terrain := str(_model.get_tile_metadata(_to_hex(axial), "terrain", ""))
	var elevation := int(_model.get_tile_metadata(_to_hex(axial), "elevation", 0))
	var family := _families.get(terrain, {}) as Dictionary
	var bucket := family.get("e%d" % elevation, {}) as Dictionary
	var variants := bucket.get("variants", []) as Array
	if variants.is_empty():
		push_error("baked_hex_map: tile set has no %s/e%d variants" % [terrain, elevation])
		return null
	var meta := _pick_variant(axial, variants)
	if meta.is_empty():
		return null
	var texture := load("%s/%s" % [_set_dir, str(meta["file"])]) as Texture2D
	if texture == null:
		push_error("baked_hex_map: texture load failed %s" % str(meta["file"]))
		return null
	var sprite := Sprite2D.new()
	sprite.name = "tile_%s_e%d_%d_%d" % [terrain, elevation, axial.x, axial.y]
	sprite.texture = texture
	sprite.centered = true
	sprite.scale = Vector2(_sprite_scale, _sprite_scale)
	var size := meta["size_px"] as Array
	var anchor := meta["anchor_px"] as Array
	# offset 在贴图本地坐标，随 node scale 一起缩放——契约公式原样。
	sprite.offset = Vector2(float(size[0]) * 0.5 - float(anchor[0]), float(size[1]) * 0.5 - float(anchor[1]))
	return sprite


## 格子显式 variant 优先；否则契约抽签 posmod((q·73856093) XOR (r·19349663), n)。
## 返回 {} = 显式变体名找不到（已 push_error）。
func _pick_variant(axial: Vector2i, variants: Array) -> Dictionary:
	var explicit := str(_model.get_tile_metadata(_to_hex(axial), "variant", ""))
	if explicit != "":
		for v in variants:
			var vd := v as Dictionary
			if vd != null and str(vd.get("name", "")) == explicit:
				return vd
		push_error("baked_hex_map: explicit variant %s missing at %s" % [explicit, str(axial)])
		return {}
	var pick := posmod((axial.x * 73856093) ^ (axial.y * 19349663), variants.size())
	return variants[pick] as Dictionary


# ========== 坐标 API（与旧共享网格件同形） ==========

func has_coord(coord: Vector2i) -> bool:
	return _model != null and _model.has_tile(_to_hex(coord))


func get_all_coords() -> Array[HexCoord]:
	return _model.get_all_coords() if _model != null else []


func tile_count() -> int:
	return _tile_count


func get_model() -> GridMapModel:
	return _model


## 显示用 px/边（marker / 相机取景等按这个定尺寸）。
func edge_px() -> float:
	return _edge_px


## 该俯仰角的纵向压扁系数（贴地椭圆/marker 用 readout）。
func effective_squish() -> float:
	return InkMonRender2DIsoProjection.squish_of(_pitch_deg)


## 整数 axial → 屏幕像素（含该格海拔抬升；单位站在顶面）。
func coord_to_world(q: int, r: int) -> Vector2:
	if _model == null:
		return Vector2.ZERO
	var axial := Vector2i(q, r)
	return _ground * _plane_center(axial) - Vector2(0.0, _lift_of(axial))


## 分数 axial → 屏幕像素（移动插值用；双线性含海拔，跨档移动平滑升降）。
func coord_to_world_f(qf: float, rf: float) -> Vector2:
	if _model == null:
		return Vector2.ZERO
	var q0 := floori(qf)
	var r0 := floori(rf)
	var fq := qf - float(q0)
	var fr := rf - float(r0)
	var p00 := coord_to_world(q0, r0)
	var p10 := coord_to_world(q0 + 1, r0)
	var p01 := coord_to_world(q0, r0 + 1)
	return p00 + (p10 - p00) * fq + (p01 - p00) * fr


## 屏幕像素 → axial 拾取。按画家序**反向**扫（视觉最靠前先命中），把点位抬回该格
## 海拔平面后判是否落在该格 hex 内——高地块的顶面因此可被正确点选。
## 全miss → 按海拔 0 平面反投影取整（可能落在地图外，caller 用 has_coord 判）。
func world_to_coord_f(world2d: Vector2) -> Vector2i:
	if _model == null:
		return Vector2i(-999999, -999999)
	for i in range(_paint_order.size() - 1, -1, -1):
		var axial := _paint_order[i]
		var lifted := world2d + Vector2(0.0, _lift_of(axial))
		if _round_axial(_ground_inv * lifted) == axial:
			return axial
	return _round_axial(_ground_inv * world2d)


# ========== 内部几何 ==========

func _plane_center(axial: Vector2i) -> Vector2:
	return Vector2(1.5 * float(axial.x), SQRT3 * (float(axial.y) + float(axial.x) * 0.5)) * _edge_px


func _lift_of(axial: Vector2i) -> float:
	var elevation := int(_model.get_tile_metadata(_to_hex(axial), "elevation", 0))
	if elevation == 0:
		return 0.0
	var height_px := float(elevation) * _elevation_step_world * _px_per_unit
	return InkMonRender2DIsoProjection.height_to_screen(height_px, _pitch_deg)


## 平面像素 → 最近 axial（flat-top 逆矩阵 + cube round）。
func _round_axial(plane: Vector2) -> Vector2i:
	var qf := (2.0 / 3.0 * plane.x) / _edge_px
	var rf := (-1.0 / 3.0 * plane.x + SQRT3 / 3.0 * plane.y) / _edge_px
	return CoordConverter.axial_round(qf, rf)


func _to_hex(coord: Vector2i) -> HexCoord:
	return HexCoord.new(coord.x, coord.y)
