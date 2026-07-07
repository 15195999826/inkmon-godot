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

const WATER_FACE_SHADER := preload("res://inkmon/presentation/render2d/water/water_face.gdshader")

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
## decor（T3 契约）：manifest 的 decors 树 + set 目录 + map doc 的显式放置列表。
var _decors: Dictionary = {}
var _decor_set_dir := ""
var _decor_entries: Array = []
var _decor_count := 0
## 影层 modulate 预留位（adr/0004：影子拆出后透明度/色调可按 tile set 明度全局调）。
var decor_shadow_modulate := Color(1.0, 1.0, 1.0, 1.0)
## patch（T6 契约, adr/0006）：manifest 的 patches 树 + set 目录 + map doc 放置列表。
var _patches: Dictionary = {}
var _patch_set_dir := ""
var _patch_entries: Array = []
var _patch_count := 0
## 遮挡体规格（_rebuild_sprites 时算好；build_occluders 在 view 提供的 y-sort
## 容器里落成 Polygon2D——遮挡体必须与单位同场 Y-sort，不能进 _tiles_root 树序层）。
var _occluder_specs: Array = []
var _occluder_nodes: Array = []
## water（inkmon-map/1 water_bodies 扩展）：shader 水面材质表（cell → ShaderMaterial，
## 岸线/flow/落水段已注入）。water 格出 shader 水面 Polygon2D 替代 baked 水 tile；未被任何
## water_body 收录的 water 格回退 baked sprite（合法 fallback）。
var _water_materials: Dictionary = {}
## 落差瀑布面段（上位格 → Array[面段 Dictionary]；随上位格入画家序出竖直面）。
var _water_faces_by_cell: Dictionary = {}
## 瀑布面材质缓存（Vector2i(上位海拔, 下位海拔) → ShaderMaterial，同落差档共用）。
var _water_face_materials: Dictionary = {}
## 水面下沉量（屏幕 px；契约 projection.water_recess_world——烘焙水 tile 的水面低于
## 同海拔陆地顶面的量，shader 水面同步下沉才能读成"切进岸间的河道"而非水台）。
var _water_recess_px := 0.0
## Polygon2D 传 uv 进 shader 需挂 texture（1x1 白；shader 用 UV 通道不采样它）。
var _water_uv_texture: ImageTexture = null


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
	# decor（可选）：manifest 缺席 = 不渲装饰物；条目直接来自 map doc（显式列表，
	# 运行时零随机——adr/0004）。
	var decor_manifest := bundle.get("decor_manifest", {}) as Dictionary
	_decors = (decor_manifest.get("decors", {}) as Dictionary) if decor_manifest != null and not decor_manifest.is_empty() else {}
	_decor_set_dir = str(bundle.get("decor_set_dir", ""))
	var map_doc := bundle.get("map", {}) as Dictionary
	_decor_entries = (map_doc.get("decors", []) as Array) if map_doc != null else []
	var patch_manifest := bundle.get("patch_manifest", {}) as Dictionary
	_patches = (patch_manifest.get("patches", {}) as Dictionary) if patch_manifest != null and not patch_manifest.is_empty() else {}
	_patch_set_dir = str(bundle.get("patch_set_dir", ""))
	_patch_entries = (map_doc.get("patches", []) as Array) if map_doc != null else []
	# water（water_bodies 扩展）：每片水域一个 shader 水面材质（岸线段/flow/落水段已推导
	# 注入）；faces = 相邻 body 落差边的瀑布竖直面，按上位格索引待 _rebuild_sprites 消费。
	var water_bodies := bundle.get("water_bodies", []) as Array
	_water_recess_px = InkMonRender2DIsoProjection.height_to_screen(
		float(projection.get("water_recess_world", 0.0)) * _px_per_unit, _pitch_deg)
	var cell_elevations: Dictionary = {}
	for coord in _model.get_all_coords():
		cell_elevations[coord.to_axial()] = int(_model.get_tile_metadata(coord, "elevation", 0))
	var water_build := InkMonRender2DWaterLayer.build_materials(water_bodies, _edge_px, cell_elevations)
	_water_materials = water_build["materials"] as Dictionary
	_water_faces_by_cell = {}
	_water_face_materials = {}
	for face_value in water_build["faces"] as Array:
		var face := face_value as Dictionary
		var upper_cell := face["upper_cell"] as Vector2i
		if not _water_faces_by_cell.has(upper_cell):
			_water_faces_by_cell[upper_cell] = []
		(_water_faces_by_cell[upper_cell] as Array).append(face)
	if not _water_materials.is_empty():
		var uv_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		uv_image.fill(Color.WHITE)
		_water_uv_texture = ImageTexture.create_from_image(uv_image)
	_rebuild_sprites()
	return true


func _rebuild_sprites() -> void:
	if _tiles_root != null:
		_tiles_root.queue_free()
	_tiles_root = Node2D.new()
	_tiles_root.name = "TilesRoot"
	add_child(_tiles_root)
	_tile_count = 0
	_decor_count = 0
	_paint_order.clear()

	# tile 与 decor 进同一画家序列表（T3 契约）：tile 排序键 = 格中心屏幕点；
	# decor 排序键 = offset 后实际落点屏幕点，且被钳到不早于所在格 tile 的键
	# （同格 tile < shadow < decor——decor 站在 tile 上，落点哪怕在格上半也不许
	# 画到自家 tile 底下）；kind 位（tile=0 < decor=1）只破精确同键平局。
	_patch_count = 0
	_occluder_specs = []
	var entries: Array[Dictionary] = []
	for coord in _model.get_all_coords():
		var axial := coord.to_axial()
		var screen := _ground * _plane_center(axial)
		# 被面片覆盖的格：压制常规 tile sprite（面片整图就是这些格的地板），
		# 但仍进画家序列表 → _paint_order（拾取 lift-aware 命中不依赖 sprite）。
		var suppressed := bool(_model.get_tile_metadata(coord, "patch_covered", false))
		entries.append({"kind": 0, "axial": axial, "screen": screen, "sort": screen, "suppressed": suppressed})
	# patch 整图垫底（T6, adr/0006 + ysort-occluder-marking）：一张 Sprite2D，
	# 排序键 = footprint 各格里屏幕 y 最小者（最远格）——在它覆盖区域的所有常规
	# 邻居 tile 之前画（kind=-1 破平局），身后高落差交界靠地图设计守则目检。
	for i in _patch_entries.size():
		var pentry := _patch_entries[i] as Dictionary
		if pentry == null:
			continue
		var anchor := Vector2i(int(pentry.get("q", 0)), int(pentry.get("r", 0)))
		var node := _patches.get(str(pentry.get("patch", "")), {}) as Dictionary
		if node == null or node.is_empty():
			push_error("baked_hex_map: patch set has no '%s'" % str(pentry.get("patch", "")))
			continue
		var min_sort := _ground * _plane_center(anchor)
		for cell_value in node.get("footprint", []) as Array:
			var cell := cell_value as Dictionary
			if cell == null:
				continue
			var cell_axial := anchor + Vector2i(int(cell.get("dq", 0)), int(cell.get("dr", 0)))
			var cell_screen := _ground * _plane_center(cell_axial)
			if cell_screen.y < min_sort.y or (cell_screen.y == min_sort.y and cell_screen.x < min_sort.x):
				min_sort = cell_screen
		entries.append({
			"kind": -1, "axial": anchor, "screen": _ground * _plane_center(anchor),
			"sort": min_sort, "patch": pentry, "salt": i,
		})
	for i in _decor_entries.size():
		var entry := _decor_entries[i] as Dictionary
		if entry == null:
			continue
		var axial := Vector2i(int(entry.get("q", 0)), int(entry.get("r", 0)))
		if not _model.has_tile(_to_hex(axial)):
			push_error("baked_hex_map: decor at %s has no tile under it" % str(axial))
			continue
		var offset_arr := entry.get("offset", []) as Array
		var offset_world := Vector2.ZERO
		if offset_arr != null and offset_arr.size() == 2:
			offset_world = Vector2(float(offset_arr[0]), float(offset_arr[1]))
		# offset 世界单位 → 地平面像素（× runtime_px_per_unit，契约字段），再投影。
		var foot := _ground * (_plane_center(axial) + offset_world * _px_per_unit)
		var cell := _ground * _plane_center(axial)
		var sort := Vector2(foot.x, maxf(foot.y, cell.y + 0.001))
		entries.append({
			"kind": 1, "axial": axial, "screen": foot, "sort": sort,
			"decor": entry, "salt": i,
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := a["sort"] as Vector2
		var sb := b["sort"] as Vector2
		if sa.y != sb.y:
			return sa.y < sb.y
		if sa.x != sb.x:
			return sa.x < sb.x
		return int(a["kind"]) < int(b["kind"])
	)

	# 画家序 = 子节点树序（按排序键升序 add_child，后加的画在上面）。不用
	# z_index：单位/marker 由 view 以兄弟节点后置画在整个地面之上（与旧网格行为一致），
	# tile/decor 间遮挡靠这里的排序（影子延伸邻格被更晚绘制的高地 tile 截断 = 正确行为）。
	for i in entries.size():
		var entry := entries[i]
		var axial := entry["axial"] as Vector2i
		if int(entry["kind"]) == -1:
			var patch_sprite := _make_patch_sprite(entry["patch"] as Dictionary, axial, int(entry["salt"]))
			if patch_sprite == null:
				continue
			_tiles_root.add_child(patch_sprite)
			_patch_count += 1
		elif int(entry["kind"]) == 0:
			_paint_order.append(axial)
			if bool(entry.get("suppressed", false)):
				continue
			# water 格（被 water_body 收录）：shader 水面 Polygon2D 替代 baked 水 tile，
			# 进同一画家序（与周围 tile 按 screen-y 正确穿插，e0 无抬升）。
			if _water_materials.has(axial):
				var water_poly := _make_water_polygon(axial)
				if water_poly != null:
					water_poly.position = entry["screen"] as Vector2 - Vector2(0.0, _lift_of(axial) - _water_recess_px)
					_tiles_root.add_child(water_poly)
					_tile_count += 1
				# 落差瀑布面：紧跟上位格入画家序（下位水面/两侧河岸更晚绘制，正确压边）。
				for face_value in _water_faces_by_cell.get(axial, []) as Array:
					_tiles_root.add_child(_make_water_face(face_value as Dictionary))
				continue
			var sprite := _make_tile_sprite(axial)
			if sprite == null:
				continue
			sprite.position = entry["screen"] as Vector2 - Vector2(0.0, _lift_of(axial))
			_tiles_root.add_child(sprite)
			_tile_count += 1
		else:
			# 影层贴地先画、本体随后：两 sprite 同画布同锚点 ⇒ 同 position/offset。
			var pos := entry["screen"] as Vector2 - Vector2(0.0, _lift_of(axial))
			for sprite in _make_decor_sprites(entry["decor"] as Dictionary, axial, int(entry["salt"])):
				sprite.position = pos
				_tiles_root.add_child(sprite)
			_decor_count += 1


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


## water 格 → shader 水面 Polygon2D（六边形顶面，UV = 平面坐标 px 跨格连续，
## material = 所属 water_body 的水面材质）。position 由 caller 设（格中心屏幕点）。
func _make_water_polygon(axial: Vector2i) -> Polygon2D:
	var water_material := _water_materials.get(axial) as ShaderMaterial
	if water_material == null:
		return null
	var center_plane := _plane_center(axial)
	var poly := Polygon2D.new()
	poly.name = "water_%d_%d" % [axial.x, axial.y]
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 6:
		var corner := _hex_corner(i)
		points.append(_ground * corner)
		uvs.append(center_plane + corner)
	poly.polygon = points
	poly.uv = uvs
	poly.texture = _water_uv_texture
	poly.material = water_material
	return poly


## flat-top 角点 i（相对格中心，显示 px）。与 InkMonRender2DWaterLayer._hex_corner 同约定。
func _hex_corner(index: int) -> Vector2:
	var angle := deg_to_rad(60.0 * float(index))
	return Vector2(cos(angle), sin(angle)) * _edge_px


## 落差边面段 → 瀑布竖直面 Polygon2D（water_face.gdshader）。顶点直接用绝对屏幕坐标
## （position 留零——画家序只看树序），顶边贴上位水面、底边贴下位水面；
## UV.x = 沿边平面坐标（px，同向直线落差跨面连续），UV.y = 自上位水面向下的屏幕 px。
func _make_water_face(face: Dictionary) -> Polygon2D:
	var a_plane := face["a_plane"] as Vector2
	var b_plane := face["b_plane"] as Vector2
	var upper_elevation := int(face["upper_elevation"])
	var lower_elevation := int(face["lower_elevation"])
	# 上下水面都按契约 recess 下沉，面随之整体下移（高度=海拔 lift 差，不变）。
	var lift_upper := _lift_of_elevation(upper_elevation) - _water_recess_px
	var lift_lower := _lift_of_elevation(lower_elevation) - _water_recess_px
	var face_height := lift_upper - lift_lower
	var screen_a := _ground * a_plane
	var screen_b := _ground * b_plane
	var upper_cell := face["upper_cell"] as Vector2i
	var poly := Polygon2D.new()
	poly.name = "waterfall_%d_%d_e%d" % [upper_cell.x, upper_cell.y, int(face["edge"])]
	poly.polygon = PackedVector2Array([
		screen_a - Vector2(0.0, lift_upper),
		screen_b - Vector2(0.0, lift_upper),
		screen_b - Vector2(0.0, lift_lower),
		screen_a - Vector2(0.0, lift_lower),
	])
	var edge_dir := (b_plane - a_plane).normalized()
	poly.uv = PackedVector2Array([
		Vector2(a_plane.dot(edge_dir), 0.0),
		Vector2(b_plane.dot(edge_dir), 0.0),
		Vector2(b_plane.dot(edge_dir), face_height),
		Vector2(a_plane.dot(edge_dir), face_height),
	])
	poly.texture = _water_uv_texture
	poly.material = _water_face_material(upper_elevation, lower_elevation, face_height)
	return poly


## 同一落差档（上位/下位海拔对）共用一份瀑布面材质（face_height 一致）。
func _water_face_material(upper_elevation: int, lower_elevation: int, face_height: float) -> ShaderMaterial:
	var key := Vector2i(upper_elevation, lower_elevation)
	if _water_face_materials.has(key):
		return _water_face_materials[key] as ShaderMaterial
	var face_material := ShaderMaterial.new()
	face_material.shader = WATER_FACE_SHADER
	face_material.set_shader_parameter("face_height", face_height)
	_water_face_materials[key] = face_material
	return face_material


## decor 条目 → [影层 sprite, 本体 sprite]（影层在前 = 先画；同画布同锚点 ⇒ 共用
## 同一 offset 公式，manifest 只有一份 size/anchor + shadow_file——adr/0004）。
## 空数组 = kind/变体/贴图任一环节失败（已 push_error）。
func _make_decor_sprites(entry: Dictionary, axial: Vector2i, salt: int) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	var kind := str(entry.get("decor", ""))
	var node := _decors.get(kind, {}) as Dictionary
	var variants := (node.get("variants", []) as Array) if node != null else []
	if variants.is_empty():
		push_error("baked_hex_map: decor set has no '%s' variants" % kind)
		return out
	var meta := _pick_decor_variant(entry, axial, salt, variants)
	if meta.is_empty():
		return out
	var body := load("%s/%s" % [_decor_set_dir, str(meta["file"])]) as Texture2D
	var shadow := load("%s/%s" % [_decor_set_dir, str(meta["shadow_file"])]) as Texture2D
	if body == null or shadow == null:
		push_error("baked_hex_map: decor texture load failed %s (+shadow)" % str(meta["file"]))
		return out
	var size := meta["size_px"] as Array
	var anchor := meta["anchor_px"] as Array
	var sprite_offset := Vector2(float(size[0]) * 0.5 - float(anchor[0]), float(size[1]) * 0.5 - float(anchor[1]))
	var shadow_sprite := Sprite2D.new()
	shadow_sprite.name = "decor_%s_shadow_%d_%d_%d" % [kind, axial.x, axial.y, salt]
	shadow_sprite.texture = shadow
	shadow_sprite.centered = true
	shadow_sprite.scale = Vector2(_sprite_scale, _sprite_scale)
	shadow_sprite.offset = sprite_offset
	shadow_sprite.modulate = decor_shadow_modulate
	out.append(shadow_sprite)
	var body_sprite := Sprite2D.new()
	body_sprite.name = "decor_%s_%d_%d_%d" % [kind, axial.x, axial.y, salt]
	body_sprite.texture = body
	body_sprite.centered = true
	body_sprite.scale = Vector2(_sprite_scale, _sprite_scale)
	body_sprite.offset = sprite_offset
	out.append(body_sprite)
	return out


## decor 变体：显式 variant 优先；否则 tile 同式抽签 + 列表序 salt（同格多 decor
## 以列表序区分——契约）。返回 {} = 显式变体名找不到（已 push_error）。
func _pick_decor_variant(entry: Dictionary, axial: Vector2i, salt: int, variants: Array) -> Dictionary:
	var explicit := str(entry.get("variant", ""))
	if explicit != "":
		for v in variants:
			var vd := v as Dictionary
			if vd != null and str(vd.get("name", "")) == explicit:
				return vd
		push_error("baked_hex_map: explicit decor variant %s missing at %s" % [explicit, str(axial)])
		return {}
	var pick := posmod(((axial.x * 73856093) ^ (axial.y * 19349663)) + salt, variants.size())
	return variants[pick] as Dictionary


## patch 放置条目 → 整图垫底 Sprite2D（摆放公式与 tile 同构：anchor = 锚定格
## 顶面中心@海拔0平面，offset = size/2 − anchor_px，按锚定格海拔 lift）。同时把
## variant 的遮挡体换算成屏幕系规格存入 _occluder_specs（build_occluders 消费）。
func _make_patch_sprite(entry: Dictionary, anchor_axial: Vector2i, salt: int) -> Sprite2D:
	var patch_name := str(entry.get("patch", ""))
	var node := _patches.get(patch_name, {}) as Dictionary
	var variants := (node.get("variants", []) as Array) if node != null else []
	if variants.is_empty():
		push_error("baked_hex_map: patch '%s' has no variants" % patch_name)
		return null
	var meta := _pick_decor_variant(entry, anchor_axial, salt, variants)
	if meta.is_empty():
		return null
	var texture := load("%s/%s" % [_patch_set_dir, str(meta["file"])]) as Texture2D
	if texture == null:
		push_error("baked_hex_map: patch texture load failed %s" % str(meta["file"]))
		return null
	var size := meta["size_px"] as Array
	var anchor := meta["anchor_px"] as Array
	var sprite := Sprite2D.new()
	sprite.name = "patch_%s_%d_%d_%d" % [patch_name, anchor_axial.x, anchor_axial.y, salt]
	sprite.texture = texture
	sprite.centered = true
	sprite.scale = Vector2(_sprite_scale, _sprite_scale)
	sprite.offset = Vector2(float(size[0]) * 0.5 - float(anchor[0]), float(size[1]) * 0.5 - float(anchor[1]))
	var pos := _ground * _plane_center(anchor_axial) - Vector2(0.0, _lift_of(anchor_axial))
	sprite.position = pos
	# 贴图左上角屏幕坐标（centered sprite：position − size·s/2 + offset·s）——
	# 遮挡体的像素→屏幕换算基准。
	var topleft := pos + (sprite.offset - Vector2(float(size[0]), float(size[1])) * 0.5) * _sprite_scale
	for occ_value in (meta.get("occluders", []) as Array):
		var occ := occ_value as Dictionary
		if occ == null:
			continue
		_occluder_specs.append({
			"texture": texture,
			"polygon_px": occ.get("polygon_px", []),
			"baseline_y": float(occ.get("baseline_y", 0.0)),
			"topleft": topleft,
			"name": "%s_occ%d" % [sprite.name, _occluder_specs.size()],
		})
	return sprite


## 把遮挡体落成 Polygon2D 加进 view 提供的 y-sort 容器（父节点须开
## y_sort_enabled；单位以脚点 y、遮挡体以 baseline_y 换算的屏幕 y 同场排序——
## ysort-occluder-marking 机制）。重复调用先清旧节点；setup 后调用一次即可。
func build_occluders(parent: Node2D) -> int:
	for old_value in _occluder_nodes:
		var old := old_value as Node
		if old != null and is_instance_valid(old):
			old.queue_free()
	_occluder_nodes = []
	for spec_value in _occluder_specs:
		var spec := spec_value as Dictionary
		var raw_poly := spec.get("polygon_px", []) as Array
		if raw_poly == null or raw_poly.size() < 3:
			continue
		var baseline := float(spec.get("baseline_y", 0.0))
		var topleft := spec.get("topleft", Vector2.ZERO) as Vector2
		var centroid_x := 0.0
		for pt_value in raw_poly:
			var pt := pt_value as Array
			centroid_x += float(pt[0])
		centroid_x /= float(raw_poly.size())
		var poly := PackedVector2Array()
		var uv := PackedVector2Array()
		for pt_value in raw_poly:
			var pt := pt_value as Array
			var px := float(pt[0])
			var py := float(pt[1])
			poly.append(Vector2((px - centroid_x) * _sprite_scale, (py - baseline) * _sprite_scale))
			uv.append(Vector2(px, py))
		var polygon := Polygon2D.new()
		polygon.name = str(spec.get("name", "patch_occluder"))
		polygon.texture = spec["texture"] as Texture2D
		# 顶点已在屏幕尺度（×_sprite_scale），uv 用纹理像素坐标显式映射——
		# 重印像素与垫底图逐像素重合。
		polygon.polygon = poly
		polygon.uv = uv
		# position.y = 基线屏幕 y —— y-sort 的排序键（单位脚点 y 同场比较）。
		polygon.position = topleft + Vector2(centroid_x, baseline) * _sprite_scale
		parent.add_child(polygon)
		_occluder_nodes.append(polygon)
	return _occluder_nodes.size()


func patch_count() -> int:
	return _patch_count


func occluder_count() -> int:
	return _occluder_nodes.size()


func decor_count() -> int:
	return _decor_count


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
	return _lift_of_elevation(int(_model.get_tile_metadata(_to_hex(axial), "elevation", 0)))


func _lift_of_elevation(elevation: int) -> float:
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
