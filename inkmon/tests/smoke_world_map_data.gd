extends Node
## 世界大地图 data shape 契约 (P2, glossary §4.9):
##   1. 同 seed 生成确定性 / 异 seed 不同图。
##   2. to_dict → from_dict → to_dict 深相等 (roundtrip 幂等)。
##   3. 地理契约 (多 seed 扫描): SITE_COUNT 个目标候选、界内、距入口 ≥ MIN_TARGET_DISTANCE、
##      出生点靠中心 (±ENTRY_CENTER_JITTER)、目标方向散布 (两两方位角差 ≥30° / 不全挤一侧)。
##   4. 持久点亮跨序列化存续 (地理记忆载体)。
##   5. GI 集成: new_game 生成 / v3 档 round-trip 后地理逐字节不变 (永久固定世界) / 旧版本档丢弃重开仍有图。


const SEED_A := 12345
const SEED_B := 54321
const SCAN_SEEDS := 10


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - world map data: deterministic generate + roundtrip + revealed persistence + GI v3 integration")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	# 1. 生成确定性。
	var map_a := InkMonWorldMapData.generate(SEED_A)
	var map_a2 := InkMonWorldMapData.generate(SEED_A)
	if JSON.stringify(map_a.to_dict()) != JSON.stringify(map_a2.to_dict()):
		return "same seed must generate identical map"
	var map_b := InkMonWorldMapData.generate(SEED_B)
	if JSON.stringify(map_a.to_dict()) == JSON.stringify(map_b.to_dict()):
		return "different seeds should generate different maps"

	# 2. roundtrip 幂等。
	var d1 := map_a.to_dict()
	var map_rt := InkMonWorldMapData.from_dict(d1)
	if JSON.stringify(map_rt.to_dict()) != JSON.stringify(d1):
		return "to_dict -> from_dict -> to_dict must be deep-equal"

	# 3. 地理契约 (多 seed 扫描)。
	for scan_index in range(SCAN_SEEDS):
		var check := _check_geography(InkMonWorldMapData.generate(7000 + scan_index * 131))
		if check != "":
			return check
	if map_a.terrain_at(map_a.entry_coord) != InkMonWorldMapData.TERRAIN_PLAIN:
		return "entry cell should stay plain"
	if map_a.terrain_at(Vector2i(-5, -5)) != "":
		return "out-of-bounds terrain should be empty string"
	var sites := map_a.get_target_candidates()

	# 4. 持久点亮。
	map_a.reveal_cell(map_a.entry_coord)
	map_a.reveal_cell(sites[0])
	var map_rt2 := InkMonWorldMapData.from_dict(map_a.to_dict())
	if not map_rt2.is_revealed(map_a.entry_coord) or not map_rt2.is_revealed(sites[0]):
		return "revealed cells must survive roundtrip"
	if map_rt2.is_revealed(Vector2i(9, 9)) and not map_a.revealed_cells.has(Vector2i(9, 9)):
		return "unrevealed cell must stay unrevealed"

	# 5. GI 集成。
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()
	var gi := _new_gi()
	gi.new_game()
	if gi.world_map == null:
		GameWorld.shutdown()
		return "new_game must generate world_map"
	var save := gi.to_dict()
	if int(save.get("version", -1)) != InkMonWorldGI.SAVE_VERSION:
		GameWorld.shutdown()
		return "save version should equal InkMonWorldGI.SAVE_VERSION"
	var map_json := JSON.stringify(save.get("world_map", {}))
	if map_json == "{}":
		GameWorld.shutdown()
		return "save must contain non-empty world_map"
	GameWorld.destroy_all_instances()
	var gi2 := _new_gi()
	if not gi2.from_dict(save):
		GameWorld.shutdown()
		return "from_dict(v%d save) should succeed" % InkMonWorldGI.SAVE_VERSION
	if gi2.world_map == null or JSON.stringify(gi2.world_map.to_dict()) != map_json:
		GameWorld.shutdown()
		return "world geography must be byte-identical after load (permanently fixed world)"
	GameWorld.destroy_all_instances()
	var gi3 := _new_gi()
	if gi3.from_dict({"version": InkMonWorldGI.SAVE_VERSION - 1}):
		GameWorld.shutdown()
		return "old-version save must be discarded (from_dict returns false)"
	if gi3.world_map == null:
		GameWorld.shutdown()
		return "discard path (new_game fallback) must still generate world_map"
	# 物品预检丢弃: 存档引用当前 catalog 不识别的 item config = 内容数据世代不符 →
	# 同 version 不符待遇 (丢弃重开, 不 crash) —— Continue 载旧世代档闪退的回归守卫。
	GameWorld.destroy_all_instances()
	var bad_item_save := save.duplicate(true)
	var bad_player := bad_item_save.get("player", {}) as Dictionary
	bad_player["bag"] = [{"config_id": "item_9999", "count": 1, "slot_index": -1}]
	var gi4 := _new_gi()
	if gi4.from_dict(bad_item_save):
		GameWorld.shutdown()
		return "save with unknown item config must be discarded (from_dict returns false)"
	if gi4.world_map == null:
		GameWorld.shutdown()
		return "unknown-item discard path must still start a new game"
	GameWorld.shutdown()
	return ""


## 单张图的地理契约: site 数量/界内/距离 + 出生点靠中心 + 目标方向散布。
## 角度阈值 29°/211° 是实现硬保证 (扇区 120° + margin 15°) 加浮点余量, 不 flaky。
func _check_geography(map: InkMonWorldMapData) -> String:
	var center := Vector2i(int(map.width / 2.0), int(map.height / 2.0))
	var offset := InkMonWorldMapData.axial_to_offset(map.entry_coord) - center
	if absi(offset.x) > InkMonWorldMapData.ENTRY_CENTER_JITTER \
			or absi(offset.y) > InkMonWorldMapData.ENTRY_CENTER_JITTER:
		return "seed %d: entry %s not near center %s" % [map.generation_seed, str(map.entry_coord), str(center)]
	var sites := map.get_target_candidates()
	if sites.size() != InkMonWorldMapData.SITE_COUNT:
		return "seed %d: expected %d sites, got %d" % [map.generation_seed, InkMonWorldMapData.SITE_COUNT, sites.size()]
	var entry_plane := InkMonWorldMapData.axial_to_plane(map.entry_coord)
	var angles: Array[float] = []
	for site in sites:
		if not map.in_bounds(site):
			return "seed %d: site %s out of bounds" % [map.generation_seed, str(site)]
		var dist := HexCoord.from_axial(map.entry_coord).distance_to(HexCoord.from_axial(site))
		if dist < InkMonWorldMapData.MIN_TARGET_DISTANCE:
			return "seed %d: site %s too close to entry (dist %d)" % [map.generation_seed, str(site), dist]
		angles.append(fposmod((InkMonWorldMapData.axial_to_plane(site) - entry_plane).angle(), TAU))
	for i in range(angles.size()):
		for j in range(i + 1, angles.size()):
			var raw := absf(angles[i] - angles[j])
			if minf(raw, TAU - raw) < deg_to_rad(29.0):
				return "seed %d: sites %d/%d angular separation %.1f deg < 30" % [
					map.generation_seed, i, j, rad_to_deg(minf(raw, TAU - raw))]
	angles.sort()
	var max_gap := 0.0
	for i in range(angles.size()):
		var next_index := (i + 1) % angles.size()
		var gap := angles[next_index] - angles[i] + (TAU if next_index == 0 else 0.0)
		max_gap = maxf(max_gap, gap)
	if max_gap > deg_to_rad(211.0):
		return "seed %d: sites bunched to one side (max angular gap %.1f deg)" % [map.generation_seed, rad_to_deg(max_gap)]
	return ""


func _new_gi() -> InkMonWorldGI:
	return GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
