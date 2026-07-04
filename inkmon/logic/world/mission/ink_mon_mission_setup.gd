class_name InkMonMissionSetup
## 出征杂活 static service (对称 InkMonBattleSetup; adr/0002: 杂活归 static 纯函数, 不抽有状态域对象)。
##
## build_state = 出征装配 (选目标地标 + 蔓延生成趟内节点图 + 初始补给);
## settle_complete = 主委托完成结算 (奖励落活 actor + 途中捕获 adopt 入库, "落袋为安"闭环)。


## v1 占位数值 (正式数值归 lab 侧设计, godot 被动跟随)。
const DEFAULT_SUPPLIES := 10
## 占位主委托完成奖励 (quest 系统数据化 = Phase 3, 届时由 QuestDef.reward 取代)。
const MISSION_COMPLETE_GOLD := 50
## 粮尽行军每步掉血比例 (v1 占位: max_hp 的 15%, 至少 1 点)。
const STARVATION_HP_RATIO := 0.15
## 带粮单价 (M2.4 拍板 B: gold 直接换粮, 无粮 item; 占位 2g/粮) 与可带上限 (UI 步进域)。
const SUPPLY_UNIT_COST := 2
const MAX_SUPPLIES := 99


## 出发付粮款 (M2.4, Host 顺序契约第①步): 按 supplies × 单价扣 gold。
## 必须在写出发档**之前**调 —— 档里记扣后余额, 丢趟回档粮款沉没 (防出征零成本)。
static func try_pay_departure(world: InkMonWorldGI, supplies_count: int) -> bool:
	if world.player_actor == null or supplies_count < 0:
		return false
	return world.player_actor.try_spend_gold(supplies_count * SUPPLY_UNIT_COST)


## 建出征态。config 可选键: "seed"(int, smoke 确定性用) / "supplies"(int) /
## "quest_id"(String, Phase 3 接单出征: 主委托从 quest_board 摘单; 缺省 = 占位 reach 单, 不摘板)。
static func build_state(world: InkMonWorldGI, config: Dictionary) -> InkMonMissionState:
	Log.assert_crash(world.world_map != null, "InkMonMissionSetup", "world_map missing before mission build")
	var state := InkMonMissionState.new()
	state.mission_seed = int(config.get("seed", randi()))
	state.supplies = int(config.get("supplies", DEFAULT_SUPPLIES))
	var rng := RandomNumberGenerator.new()
	rng.seed = state.mission_seed
	# 主委托: 接单 (从板上摘, 丢趟回档自然恢复) 或占位 reach 单 (无单出征的兼容路径/smoke)。
	var main_quest := _take_board_quest(world, str(config.get("quest_id", "")))
	if main_quest == null:
		main_quest = _placeholder_main_quest(world, rng)
	state.quests.append({"def": main_quest, "role": "main", "progress": 0})
	# 副委托 (Q3.2 ≤2, 纯 bonus): 与本趟 seed 同源派生。
	for side_quest in InkMonQuestGen.roll_side_quests(state.mission_seed):
		state.quests.append({"def": side_quest, "role": "side", "progress": 0})
	state.target_site_coord = world.world_map.landmark_coord(main_quest.target_site_id)
	var bounds := Rect2i(0, 0, world.world_map.width, world.world_map.height)
	state.map = InkMonMissionMapGen.generate(
		state.mission_seed, world.world_map.entry_coord, state.target_site_coord, bounds,
		main_quest.type == InkMonQuestDef.TYPE_HUNT)
	state.current_node_id = state.map.entry_node_id
	state.visited_node_ids[state.map.entry_node_id] = true
	return state


## 从委托板摘单 (找到即移除); 未命中返回 null。
static func _take_board_quest(world: InkMonWorldGI, quest_id: String) -> InkMonQuestDef:
	if quest_id == "":
		return null
	for i in range(world.quest_board.size()):
		if world.quest_board[i].quest_id == quest_id:
			var def := world.quest_board[i]
			world.quest_board.remove_at(i)
			return def
	return null


## 占位主委托 (无单出征): 随机地标 reach 型, 奖励 = 旧占位值 (兼容 quest 前的 flow 语义)。
static func _placeholder_main_quest(world: InkMonWorldGI, rng: RandomNumberGenerator) -> InkMonQuestDef:
	var site_ids: Array[String] = []
	for landmark in world.world_map.landmarks:
		if str(landmark.get("kind", "")) == InkMonWorldMapData.LANDMARK_SITE:
			site_ids.append(str(landmark.get("id", "")))
	Log.assert_crash(not site_ids.is_empty(), "InkMonMissionSetup", "world map has no target sites")
	var def := InkMonQuestDef.new()
	def.quest_id = "placeholder"
	def.type = InkMonQuestDef.TYPE_REACH
	def.target_site_id = site_ids[rng.randi_range(0, site_ids.size() - 1)]
	def.reward_gold = MISSION_COMPLETE_GOLD
	return def


## 趟内事件计数 (Phase 3 副委托): 野群战胜 / 捕获成功时 GI 调, 对应类型 progress+1。
static func record_mission_event(state: InkMonMissionState, event_type: String) -> void:
	for quest_entry in state.quests:
		var def := quest_entry.get("def", null) as InkMonQuestDef
		if def != null and def.type == event_type:
			quest_entry["progress"] = int(quest_entry.get("progress", 0)) + 1


## 粮尽行军 (补给钟, game-vision 前进压力三重之②): 全队活 roster 掉真 HP (carryover, adr/0001),
## 死者语义经 sync_downed_state 保 is_dead 与 HP 一致。返回是否全灭 (全 roster HP≤0)
## —— 全灭 = "丢这趟"出口 (P1), 由 GI emit mission_wiped 交 Host 走 load 出发档。
static func apply_starvation(world: InkMonWorldGI) -> bool:
	for actor in world.roster:
		if actor.attribute_set.hp <= 0.0:
			continue
		var loss := maxf(1.0, ceilf(actor.attribute_set.max_hp * STARVATION_HP_RATIO))
		# ⚠ 写 HP 必须走 set_current_hp (set_hp_base + sync_downed_state):
		# attribute_set.hp 是只读投影 property, 直接赋值会被 GDScript 静默丢弃。
		actor.set_current_hp(maxf(0.0, actor.attribute_set.hp - loss))
	for actor in world.roster:
		if actor.attribute_set.hp > 0.0:
			return false
	return true


## 主委托完成结算: 途中捕获 adopt 入 roster + 委托奖励落账 (主必发, 副按 progress 达标发;
## gold 进 player_actor, 奖励物品入 bag) + 回城全队回满 (Q2.6 拍板) + 委托板回城刷新 (Q3.3)。
## 返回结果摘要 (mission_ended payload)。
static func settle_complete(world: InkMonWorldGI) -> Dictionary:
	var adopted := 0
	for captured in world.mission_state.captured_pending:
		var species := str(captured.get("species_id", ""))
		if species != "":
			world.adopt_unit(species, int(captured.get("roll_seed", 0)))
			adopted += 1
	for actor in world.roster:
		actor.set_current_hp(-1.0)
	# 委托奖励 (Phase 3): 主委托 = 本趟完成条件, 必发; 副委托逐张判 progress ≥ goal。
	var gold_reward := 0
	var quest_results: Array[Dictionary] = []
	for quest_entry in world.mission_state.quests:
		var def := quest_entry.get("def", null) as InkMonQuestDef
		if def == null:
			continue
		var fulfilled: bool = str(quest_entry.get("role", "")) == "main" \
			or int(quest_entry.get("progress", 0)) >= def.goal_count
		if fulfilled:
			gold_reward += def.reward_gold
			if def.reward_item_id != "":
				world.create_bag_item(StringName(def.reward_item_id))
		quest_results.append({
			"quest_id": def.quest_id,
			"title": def.title(),
			"role": str(quest_entry.get("role", "")),
			"fulfilled": fulfilled,
			"reward_gold": def.reward_gold if fulfilled else 0,
		})
	if world.player_actor != null:
		world.player_actor.gold += gold_reward
	# 回城刷新委托板 (Q3.3: 3-5 张; 真随机 —— 每次回城新一批)。
	world.quest_board = InkMonQuestGen.roll_board(world.world_map, randi())
	return {
		"outcome": "complete",
		"gold_reward": gold_reward,
		"adopted": adopted,
		"supplies_left": world.mission_state.supplies,
		"quests": quest_results,
	}
