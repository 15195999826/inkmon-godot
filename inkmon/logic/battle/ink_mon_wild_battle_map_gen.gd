class_name InkMonWildBattleMapGen
## 野群战斗地图模板生成 (M2.2, Q2.2 拍板"模板制"): 固定小棋盘 + 按区域地形皮肤 + 随机 0-3 障碍。
##
## 产物 = inkmon-map/1 形状的 map doc (与 content/maps/*.map.json 同形), 逻辑侧经
## InkMonMapLoader.build_bundle_from_doc 进 GridMapModel, 回放侧同一 doc 进 baked hex map ——
## 一份 doc 两端消费, 无第二真相。seed 确定性: 同 (seed, 皮肤) 必产同 doc (复跑/回放一致)。
## 纯生成 (非模板) = Q2.2 留后。


## 固定小棋盘 = radius-4 hex 盘 (61 格)。布阵点沿用训练战 (±3/±2 列), 恰在界内。
const BOARD_RADIUS := 4
## 皮肤/障碍复用 battle_main 的发布 tile set (grass/dirt/stone/water 四族)。
const TILE_SET_ID := "inkmon-tiles-hard"
const OBSTACLE_MAX := 3
## 障碍候选带 |q| ≤ 1: 远离两侧布阵列 (|q| ≥ 2), 且 3 格不可能切断 25 格中带 (无需连通性检查)。
const OBSTACLE_ZONE_Q := 1
## 障碍 = water (terrains.json 唯一 passable=false 地形; 逻辑挡格 + 皮肤现成)。
const OBSTACLE_TERRAIN := "water"

## 区域地形 → 战斗棋盘皮肤 (按野群节点所在世界格地形换肤, Q2.2)。
const SKIN_TO_TERRAIN := {
	InkMonWorldMapData.TERRAIN_PLAIN: "grass",
	InkMonWorldMapData.TERRAIN_FOREST: "dirt",
	InkMonWorldMapData.TERRAIN_HILL: "stone",
}


## 生成野群战斗地图 doc。world_terrain = 节点所在世界格地形 (TERRAIN_*); 未知值落 grass。
static func generate_doc(seed_value: int, world_terrain: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var base_terrain := str(SKIN_TO_TERRAIN.get(world_terrain, "grass"))
	var tiles: Array = []
	var obstacle_candidates: Array[int] = []
	for q in range(-BOARD_RADIUS, BOARD_RADIUS + 1):
		for r in range(maxi(-BOARD_RADIUS, -q - BOARD_RADIUS), mini(BOARD_RADIUS, -q + BOARD_RADIUS) + 1):
			if absi(q) <= OBSTACLE_ZONE_Q:
				obstacle_candidates.append(tiles.size())
			tiles.append({"q": q, "r": r, "terrain": base_terrain, "elevation": 0})
	var obstacle_count := rng.randi_range(0, OBSTACLE_MAX)
	for _i in range(obstacle_count):
		var pick := rng.randi_range(0, obstacle_candidates.size() - 1)
		var tile_index := obstacle_candidates.pop_at(pick) as int
		(tiles[tile_index] as Dictionary)["terrain"] = OBSTACLE_TERRAIN
	return {
		"schema": "inkmon-map/1",
		# 皮肤编进 id: 回放视图按 map_id 判"同图跳过重建", 同 seed 不同皮肤必须是不同 id。
		"map_id": "wild_%d_%s" % [seed_value, base_terrain],
		"tile_set": {"id": TILE_SET_ID},
		"config": {"grid_type": "hex", "orientation": "flat"},
		"tiles": tiles,
	}
