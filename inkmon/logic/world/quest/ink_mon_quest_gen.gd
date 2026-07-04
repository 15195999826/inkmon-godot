class_name InkMonQuestGen
## 委托生成 static service (Phase 3; adr/0002 杂活归 static)。参数全代码常量
## (Q3.5 拍板 v1 不进 lab; 数值占位, 正式经济归 lab 侧)。seed 确定性: 同 seed 同板。


## 委托板张数域 (Q3.3 拍板: 回城刷新 3-5 张)。
const BOARD_MIN := 3
const BOARD_MAX := 5
## 主委托奖励域 (占位; 讨伐比抵达多付)。
const REWARD_REACH_MIN := 40
const REWARD_REACH_MAX := 60
const REWARD_HUNT_MIN := 60
const REWARD_HUNT_MAX := 90
## 奖励物品概率 (Q3.4 金币+物品; roll 自 catalog price>0 池)。
const REWARD_ITEM_CHANCE := 0.3
## 讨伐型占比。
const HUNT_CHANCE := 0.5
## 副委托上限 (Q3.2 主 1 + 副 2) 与奖励域。
const SIDE_QUEST_MAX := 2
const SIDE_REWARD_MIN := 20
const SIDE_REWARD_MAX := 40


## 回城刷新委托板: 3-5 张主委托候选 (type/目标地标/奖励 roll)。quest_id 含 seed 保全局可辨。
static func roll_board(world_map: InkMonWorldMapData, seed_value: int) -> Array[InkMonQuestDef]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var site_ids: Array[String] = []
	for landmark in world_map.landmarks:
		if str(landmark.get("kind", "")) == InkMonWorldMapData.LANDMARK_SITE:
			site_ids.append(str(landmark.get("id", "")))
	var board: Array[InkMonQuestDef] = []
	if site_ids.is_empty():
		return board
	var count := rng.randi_range(BOARD_MIN, BOARD_MAX)
	for i in range(count):
		var def := InkMonQuestDef.new()
		def.quest_id = "q_%d_%d" % [seed_value, i]
		def.target_site_id = site_ids[rng.randi_range(0, site_ids.size() - 1)]
		if rng.randf() < HUNT_CHANCE:
			def.type = InkMonQuestDef.TYPE_HUNT
			def.reward_gold = rng.randi_range(REWARD_HUNT_MIN, REWARD_HUNT_MAX)
		else:
			def.type = InkMonQuestDef.TYPE_REACH
			def.reward_gold = rng.randi_range(REWARD_REACH_MIN, REWARD_REACH_MAX)
		def.reward_item_id = _roll_reward_item(rng)
		board.append(def)
	return board


## 出征附带副委托 (≤2 张, 纯 bonus; 与主委托同 seed 派生 → 复跑同单)。
## 两张时强制异型 (同型双张 = 变相一张更高 goal 的单, 观感重复)。
static func roll_side_quests(seed_value: int) -> Array[InkMonQuestDef]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 1000003 + 17
	var result: Array[InkMonQuestDef] = []
	var count := rng.randi_range(1, SIDE_QUEST_MAX)
	var used_hunt_count := false
	for i in range(count):
		var def := InkMonQuestDef.new()
		def.quest_id = "side_%d_%d" % [seed_value, i]
		var pick_hunt := rng.randf() < 0.5
		if i > 0:
			pick_hunt = not used_hunt_count
		if pick_hunt:
			def.type = InkMonQuestDef.TYPE_HUNT_COUNT
			def.goal_count = rng.randi_range(1, 2)
			used_hunt_count = true
		else:
			def.type = InkMonQuestDef.TYPE_CAPTURE_COUNT
			def.goal_count = 1
		def.reward_gold = rng.randi_range(SIDE_REWARD_MIN, SIDE_REWARD_MAX)
		result.append(def)
	return result


## 奖励物品 roll: catalog price>0 池 (与 shop 可买面同源; 池随 lab 内容自动扩)。无池 → ""。
static func _roll_reward_item(rng: RandomNumberGenerator) -> String:
	if rng.randf() >= REWARD_ITEM_CHANCE:
		return ""
	var catalog := InkMonItemCatalog.new()
	var pool: Array[String] = []
	for config_id in catalog.list_config_ids():
		if int(catalog.get_config(config_id).get("price", 0)) > 0:
			pool.append(str(config_id))
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]
