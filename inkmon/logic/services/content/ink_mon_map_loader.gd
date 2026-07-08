class_name InkMonMapLoader

## content/ 地图装载器（T2 美术资产契约消费端，inkmon-map/1）。
##
## 手写区 `content/maps/*.map.json` + `content/terrains.json` → ultra-grid-map 的
## `GridMapModel`（运行时单一真相）。翻译规则（契约: inkmon-lab godot-contract.md）:
##   terrain(字符串 key) → metadata.terrain + 按 terrains.json 设 is_blocking / cost
##   elevation(int 档位) → height = elevation × elevation_step_world
##     （elevation_step_world 从绑定 tile_set manifest 的 projection 块拿——
##       Godot 只读 set manifest，不读 Lab 侧契约文件）
##   实体（NPC / 玩家）不进地图文件；occupant 是运行时态，归 world 逻辑。
##
## 纯 static 装载函数，无状态。

const CONTENT_ROOT := "res://content"


static func map_path(map_id: String) -> String:
	return "%s/maps/%s.map.json" % [CONTENT_ROOT, map_id]


static func tile_set_dir(set_id: String) -> String:
	return "%s/art/tiles/%s" % [CONTENT_ROOT, set_id]


static func decor_set_dir(set_id: String) -> String:
	return "%s/art/decor/%s" % [CONTENT_ROOT, set_id]


static func patch_set_dir(set_id: String) -> String:
	return "%s/art/patches/%s" % [CONTENT_ROOT, set_id]


static func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("[InkMonMapLoader] cannot read %s" % path)
		return {}
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		return data as Dictionary
	push_error("[InkMonMapLoader] %s is not a JSON object" % path)
	return {}


static func load_terrains() -> Dictionary:
	return _load_json("%s/terrains.json" % CONTENT_ROOT)


static func load_map(map_id: String) -> Dictionary:
	var doc := _load_json(map_path(map_id))
	if doc.is_empty():
		return {}
	if str(doc.get("schema", "")) != "inkmon-map/1":
		push_error("[InkMonMapLoader] %s: unsupported schema %s" % [map_id, str(doc.get("schema"))])
		return {}
	var config := doc.get("config", {}) as Dictionary
	if str(config.get("orientation", "")) != "flat":
		push_error("[InkMonMapLoader] %s: only flat-top maps are supported" % map_id)
		return {}
	return doc


static func load_tile_set_manifest(set_id: String) -> Dictionary:
	var manifest := _load_json("%s/manifest.json" % tile_set_dir(set_id))
	if manifest.is_empty():
		return {}
	if str(manifest.get("schema", "")) != "inkmon-tileset/1":
		push_error("[InkMonMapLoader] tile set %s: unsupported schema %s" % [set_id, str(manifest.get("schema"))])
		return {}
	return manifest


static func load_decor_set_manifest(set_id: String) -> Dictionary:
	var manifest := _load_json("%s/manifest.json" % decor_set_dir(set_id))
	if manifest.is_empty():
		return {}
	if str(manifest.get("schema", "")) != "inkmon-decorset/1":
		push_error("[InkMonMapLoader] decor set %s: unsupported schema %s" % [set_id, str(manifest.get("schema"))])
		return {}
	return manifest


static func load_patch_set_manifest(set_id: String) -> Dictionary:
	var manifest := _load_json("%s/manifest.json" % patch_set_dir(set_id))
	if manifest.is_empty():
		return {}
	if str(manifest.get("schema", "")) != "inkmon-patchset/1":
		push_error("[InkMonMapLoader] patch set %s: unsupported schema %s" % [set_id, str(manifest.get("schema"))])
		return {}
	return manifest


## flat-top 壁 i（角点 i→i+1，外法线 60i+30°）对应的邻居 axial 位移。
## 与 Lab 侧 make_patch_scaffold.py WALL_NEIGHBOR 同表（契约几何，两处 cross-ref）。
const PATCH_WALL_NEIGHBOR := {
	0: Vector2i(1, -1), 1: Vector2i(0, -1), 2: Vector2i(-1, 0),
	3: Vector2i(-1, 1), 4: Vector2i(0, 1), 5: Vector2i(1, 0),
}


## patches[] 覆盖层进 model（T6, adr/0006）：逐格校验 footprint 相对海拔轮廓 ==
## 手写 elevation（锚定格为基准，不一致 fail loud 返 false）；被盖格打
## metadata.patch_covered（渲染层压制常规 tile sprite）；climb_edges 写
## edge_pass_overrides（高差豁免边）。tiles[] 仍是每格必有条目的逻辑真相。
static func apply_patches_to_model(model: GridMapModel, map_doc: Dictionary, patch_manifest: Dictionary) -> bool:
	var entries := map_doc.get("patches", []) as Array
	if entries == null or entries.is_empty():
		return true
	var patches := patch_manifest.get("patches", {}) as Dictionary
	var map_id := str(map_doc.get("map_id", ""))
	for entry_value in entries:
		var entry := entry_value as Dictionary
		if entry == null:
			continue
		var patch_name := str(entry.get("patch", ""))
		var node := patches.get(patch_name, null) as Dictionary
		if node == null:
			push_error("[InkMonMapLoader] %s: patch '%s' missing from patch set manifest" % [map_id, patch_name])
			return false
		var anchor := Vector2i(int(entry.get("q", 0)), int(entry.get("r", 0)))
		var anchor_hex := HexCoord.new(anchor.x, anchor.y)
		if not model.has_tile(anchor_hex):
			push_error("[InkMonMapLoader] %s: patch '%s' anchor %s has no tile" % [map_id, patch_name, str(anchor)])
			return false
		var anchor_elevation := int(model.get_tile_metadata(anchor_hex, "elevation", 0))
		var footprint := node.get("footprint", []) as Array
		if footprint == null or footprint.is_empty():
			push_error("[InkMonMapLoader] %s: patch '%s' manifest has no footprint" % [map_id, patch_name])
			return false
		for cell_value in footprint:
			var cell := cell_value as Dictionary
			if cell == null:
				continue
			var coord := anchor + Vector2i(int(cell.get("dq", 0)), int(cell.get("dr", 0)))
			var hex := HexCoord.new(coord.x, coord.y)
			if not model.has_tile(hex):
				push_error("[InkMonMapLoader] %s: patch '%s' footprint cell %s has no tile" % [map_id, patch_name, str(coord)])
				return false
			var expected := anchor_elevation + int(cell.get("rel_elevation", 0))
			var actual := int(model.get_tile_metadata(hex, "elevation", 0))
			if actual != expected:
				push_error("[InkMonMapLoader] %s: patch '%s' cell %s elevation %d != footprint 轮廓 %d（锚定 %d + rel %d）—— tiles[] 与面片不一致" % [map_id, patch_name, str(coord), actual, expected, anchor_elevation, int(cell.get("rel_elevation", 0))])
				return false
			model.set_tile_metadata(hex, "patch_covered", true)
			# climb_edges = 该边的高差豁免（台阶）；挂单侧即可（can_traverse 双向查）。
			for edge_value in cell.get("climb_edges", []) as Array:
				var edge := int(edge_value)
				if edge < 0 or edge > 5:
					push_error("[InkMonMapLoader] %s: patch '%s' cell %s 非法 climb edge %d" % [map_id, patch_name, str(coord), edge])
					return false
				var neighbor := coord + (PATCH_WALL_NEIGHBOR[edge] as Vector2i)
				var neighbor_hex := HexCoord.new(neighbor.x, neighbor.y)
				if not model.has_tile(neighbor_hex):
					push_error("[InkMonMapLoader] %s: patch '%s' climb edge %d 的邻居 %s 没有 tile" % [map_id, patch_name, edge, str(neighbor)])
					return false
				model.set_edge_pass_override(hex, neighbor_hex, true)
		# edge_context 放置校验（守则机器化）：面片图烘死的边缘假设（外邻相对海拔，
		# 锚定格基准）必须与放置处地形一致——不一致 = 外缘墙/无墙收边与邻居 tile
		# 顶面打架的视觉穿帮（资产层根源，绘制次序救不了）。未声明的外邻不校验
		# （legacy void；旧 manifest 无此字段 = 全不校验，向后兼容）。
		var edge_context := node.get("edge_context", []) as Array
		if edge_context == null:
			edge_context = []  # 字段存在但非 Array（null/坏类型）——按无声明处理
		for ctx_value in edge_context:
			var ctx := ctx_value as Dictionary
			if ctx == null:
				continue
			var ctx_coord := anchor + Vector2i(int(ctx.get("dq", 0)), int(ctx.get("dr", 0)))
			var ctx_hex := HexCoord.new(ctx_coord.x, ctx_coord.y)
			if not model.has_tile(ctx_hex):
				push_error("[InkMonMapLoader] %s: patch '%s' edge_context 格 %s 没有 tile —— 面片假设该邻居存在（rel %d），放置处却是地图外" % [map_id, patch_name, str(ctx_coord), int(ctx.get("rel_elevation", 0))])
				return false
			var ctx_expected := anchor_elevation + int(ctx.get("rel_elevation", 0))
			var ctx_actual := int(model.get_tile_metadata(ctx_hex, "elevation", 0))
			if ctx_actual != ctx_expected:
				push_error("[InkMonMapLoader] %s: patch '%s' edge_context 格 %s elevation %d != 面片边缘假设 %d（锚定 %d + rel %d）—— 挪面片或改地形，否则边缘墙穿帮" % [map_id, patch_name, str(ctx_coord), ctx_actual, ctx_expected, anchor_elevation, int(ctx.get("rel_elevation", 0))])
				return false
	return true


## map 文档 + 目录表 + projection 块 → GridMapModel。
## size = 逻辑格几何尺寸（get_adjacent_world_distance 等），调用方各自沿用历史值。
static func build_grid_model(map_doc: Dictionary, terrains: Dictionary, elevation_step_world: float, size: float = 1.0) -> GridMapModel:
	var config := GridMapConfig.new()
	config.grid_type = GridMapConfig.GridType.HEX
	config.orientation = GridMapConfig.Orientation.FLAT
	config.size = size
	config.max_height_step = INKMON_MAX_HEIGHT_STEP
	var tiles: Array = []
	for entry_value in map_doc.get("tiles", []) as Array:
		var entry := entry_value as Dictionary
		if entry == null:
			continue
		var terrain := str(entry.get("terrain", ""))
		var rules := terrains.get(terrain, null) as Dictionary
		if rules == null:
			push_error("[InkMonMapLoader] %s: terrain %s missing from terrains.json" % [str(map_doc.get("map_id")), terrain])
			continue
		var elevation := int(entry.get("elevation", 0))
		var metadata := {"terrain": terrain, "elevation": elevation}
		var variant := str(entry.get("variant", ""))
		if variant != "":
			metadata["variant"] = variant
		tiles.append({
			"coord": Vector2i(int(entry.get("q", 0)), int(entry.get("r", 0))),
			"height": float(elevation) * elevation_step_world,
			"cost": float(rules.get("move_cost", 1.0)),
			"is_blocking": not bool(rules.get("passable", true)),
			"metadata": metadata,
		})
	var model := GridMapModel.new()
	model.initialize_from_tiles(config, tiles)
	return model


## inkmon 启用高差通行规则（T6, adr/0006「先立规则再开例外」）：max_height_step=0
## （带 epsilon 的严格同高——同 elevation 档可走、跨档不可），例外全靠面片
## climb_edges 写入的 edge_pass_overrides。对既有全平地图（battle_main）零影响。
const INKMON_MAX_HEIGHT_STEP := 0.0


## 一步到位：map + terrains + 绑定 tile_set manifest + 翻译好的 model。
## 返回 {} 表示任一环节失败（已 push_error）。version 漂移只警告不拦（map 钉的是
## 发布时点；重发布后地图未跟着改版号是常态，摆放契约由 projection 块保证）。
static func load_bundle(map_id: String, size: float = 1.0) -> Dictionary:
	return build_bundle_from_doc(load_map(map_id), size)


## doc 直入版 (M2.2 野群战斗模板生成图走此): map doc 不来自 content/maps 文件而是
## 生成器产物 (InkMonWildBattleMapGen), terrains/tile_set manifest 装配同 load_bundle。
static func build_bundle_from_doc(map_doc: Dictionary, size: float = 1.0) -> Dictionary:
	if map_doc.is_empty():
		return {}
	var terrains := load_terrains()
	if terrains.is_empty():
		return {}
	var tile_set_ref := map_doc.get("tile_set", {}) as Dictionary
	var set_id := str(tile_set_ref.get("id", ""))
	var manifest := load_tile_set_manifest(set_id)
	if manifest.is_empty():
		return {}
	var pinned_version := str(tile_set_ref.get("version", ""))
	if pinned_version != "" and pinned_version != str(manifest.get("version", "")):
		push_warning("[InkMonMapLoader] %s pins tile_set %s v%s but published manifest is v%s" % [str(map_doc.get("map_id", "")), set_id, pinned_version, str(manifest.get("version"))])
	var projection := manifest.get("projection", {}) as Dictionary
	if projection == null or projection.is_empty():
		push_error("[InkMonMapLoader] tile set %s manifest has no projection block" % set_id)
		return {}
	var model := build_grid_model(map_doc, terrains, float(projection.get("elevation_step_world", 0.5)), size)
	# decor（T3 契约, adr/0004）: `decor_set` + `decors[]` 均可选——无则不渲装饰物。
	# decors 不进 GridMapModel（纯表演层）：这里只装 manifest，条目由渲染视图直接
	# 从 map doc 读。map 引用了 set 但 manifest 装不上 = 内容坏档，fail loud。
	var decor_set_ref := map_doc.get("decor_set", {}) as Dictionary
	var decor_set_id := str(decor_set_ref.get("id", "")) if decor_set_ref != null else ""
	var decor_manifest := {}
	if decor_set_id != "":
		decor_manifest = load_decor_set_manifest(decor_set_id)
		if decor_manifest.is_empty():
			return {}
		var decor_pinned := str(decor_set_ref.get("version", ""))
		if decor_pinned != "" and decor_pinned != str(decor_manifest.get("version", "")):
			push_warning("[InkMonMapLoader] %s pins decor_set %s v%s but published manifest is v%s" % [str(map_doc.get("map_id", "")), decor_set_id, decor_pinned, str(decor_manifest.get("version"))])
	# patch（T6 契约, adr/0006）: `patch_set` + `patches[]` 均可选。footprint 校验/
	# 被盖格标记/climb 例外进 model（fail loud）；渲染条目由视图从 map doc 读。
	var patch_set_ref := map_doc.get("patch_set", {}) as Dictionary
	var patch_set_id := str(patch_set_ref.get("id", "")) if patch_set_ref != null else ""
	var patch_manifest := {}
	if patch_set_id != "":
		patch_manifest = load_patch_set_manifest(patch_set_id)
		if patch_manifest.is_empty():
			return {}
		var patch_pinned := str(patch_set_ref.get("version", ""))
		if patch_pinned != "" and patch_pinned != str(patch_manifest.get("version", "")):
			push_warning("[InkMonMapLoader] %s pins patch_set %s v%s but published manifest is v%s" % [str(map_doc.get("map_id", "")), patch_set_id, patch_pinned, str(patch_manifest.get("version"))])
		if not apply_patches_to_model(model, map_doc, patch_manifest):
			return {}
	elif (map_doc.get("patches", []) as Array).size() > 0:
		push_error("[InkMonMapLoader] %s has patches[] but no patch_set reference" % str(map_doc.get("map_id", "")))
		return {}
	# water_bodies（inkmon-map/1 扩展, shader 水面表演层）: cells 必须都是 terrain==water 的格。
	# 不进 GridMapModel（纯表演层，渲染视图从 bundle 读，同 decor/patch 语义）。
	var water_bodies := map_doc.get("water_bodies", []) as Array
	if not validate_water_bodies(model, map_doc, water_bodies):
		return {}
	return {
		"map": map_doc,
		"terrains": terrains,
		"set_id": set_id,
		"set_dir": tile_set_dir(set_id),
		"manifest": manifest,
		"projection": projection,
		"decor_set_id": decor_set_id,
		"decor_set_dir": decor_set_dir(decor_set_id) if decor_set_id != "" else "",
		"decor_manifest": decor_manifest,
		"patch_set_id": patch_set_id,
		"patch_set_dir": patch_set_dir(patch_set_id) if patch_set_id != "" else "",
		"patch_manifest": patch_manifest,
		"water_bodies": water_bodies,
		"model": model,
	}


## water_bodies 校验（inkmon-map/1 扩展, shader 水面表演层）: 每个 body 的 cells 必须都是
## 地图里 terrain==water 的格（否则 shader 水面会摆到旱地/空格上），不被多个 body 重复收录，
## 且 body 内所有格同 elevation（一片水面一个水位；落差用相邻两个 body 表达，瀑布由渲染层
## 从 elevation 差自动推导——不需要显式 waterfall_edges 字段）。
## 空/缺省 = 无 shader 水面，放行。纯表演层数据（不进 GridMapModel），校验在此 fail loud。
static func validate_water_bodies(model: GridMapModel, map_doc: Dictionary, water_bodies: Array) -> bool:
	if water_bodies == null or water_bodies.is_empty():
		return true
	var map_id := str(map_doc.get("map_id", ""))
	var seen: Dictionary = {}
	for body_value in water_bodies:
		var body := body_value as Dictionary
		if body == null:
			continue
		var body_id := str(body.get("id", ""))
		var cells := body.get("cells", []) as Array
		if cells == null or cells.is_empty():
			push_error("[InkMonMapLoader] %s: water_body '%s' 无 cells" % [map_id, body_id])
			return false
		var body_elevation := 0
		var body_elevation_known := false
		for cell_value in cells:
			var cell := cell_value as Array
			if cell == null or cell.size() != 2:
				push_error("[InkMonMapLoader] %s: water_body '%s' 非法 cell %s" % [map_id, body_id, str(cell_value)])
				return false
			var coord := Vector2i(int(cell[0]), int(cell[1]))
			var hex := HexCoord.new(coord.x, coord.y)
			if not model.has_tile(hex):
				push_error("[InkMonMapLoader] %s: water_body '%s' cell %s 没有 tile" % [map_id, body_id, str(coord)])
				return false
			if str(model.get_tile_metadata(hex, "terrain", "")) != "water":
				push_error("[InkMonMapLoader] %s: water_body '%s' cell %s 不是 water 格" % [map_id, body_id, str(coord)])
				return false
			var cell_elevation := int(model.get_tile_metadata(hex, "elevation", 0))
			if not body_elevation_known:
				body_elevation = cell_elevation
				body_elevation_known = true
			elif cell_elevation != body_elevation:
				push_error("[InkMonMapLoader] %s: water_body '%s' cell %s elevation %d != body 水位 %d（一片水面一个水位，落差请拆成相邻两个 body）" % [map_id, body_id, str(coord), cell_elevation, body_elevation])
				return false
			if seen.has(coord):
				push_error("[InkMonMapLoader] %s: cell %s 被多个 water_body 收录" % [map_id, str(coord)])
				return false
			seen[coord] = body_id
	return true
