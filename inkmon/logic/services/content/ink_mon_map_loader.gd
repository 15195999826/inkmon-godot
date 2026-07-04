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


## map 文档 + 目录表 + projection 块 → GridMapModel。
## size = 逻辑格几何尺寸（get_adjacent_world_distance 等），调用方各自沿用历史值。
static func build_grid_model(map_doc: Dictionary, terrains: Dictionary, elevation_step_world: float, size: float = 1.0) -> GridMapModel:
	var config := GridMapConfig.new()
	config.grid_type = GridMapConfig.GridType.HEX
	config.orientation = GridMapConfig.Orientation.FLAT
	config.size = size
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
	return {
		"map": map_doc,
		"terrains": terrains,
		"set_id": set_id,
		"set_dir": tile_set_dir(set_id),
		"manifest": manifest,
		"projection": projection,
		"model": model,
	}
