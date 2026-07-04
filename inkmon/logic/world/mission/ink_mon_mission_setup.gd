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


## 建出征态。config 可选键: "seed"(int, smoke 确定性用) / "supplies"(int)。
static func build_state(world: InkMonWorldGI, config: Dictionary) -> InkMonMissionState:
	Log.assert_crash(world.world_map != null, "InkMonMissionSetup", "world_map missing before mission build")
	var state := InkMonMissionState.new()
	state.mission_seed = int(config.get("seed", randi()))
	state.supplies = int(config.get("supplies", DEFAULT_SUPPLIES))
	var rng := RandomNumberGenerator.new()
	rng.seed = state.mission_seed
	var candidates := world.world_map.get_target_candidates()
	Log.assert_crash(not candidates.is_empty(), "InkMonMissionSetup", "world map has no target sites")
	state.target_site_coord = candidates[rng.randi_range(0, candidates.size() - 1)]
	var bounds := Rect2i(0, 0, world.world_map.width, world.world_map.height)
	state.map = InkMonMissionMapGen.generate(
		state.mission_seed, world.world_map.entry_coord, state.target_site_coord, bounds)
	state.current_node_id = state.map.entry_node_id
	state.visited_node_ids[state.map.entry_node_id] = true
	return state


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


## 主委托完成结算: 途中捕获 adopt 入 roster + 占位奖励落 player_actor + 回城全队回满
## (Q2.6 拍板: 回据点自动回满, v1 最简 —— 压力全在出征内, 据点不再加惩罚)。
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
	if world.player_actor != null:
		world.player_actor.gold += MISSION_COMPLETE_GOLD
	return {
		"outcome": "complete",
		"gold_reward": MISSION_COMPLETE_GOLD,
		"adopted": adopted,
		"supplies_left": world.mission_state.supplies,
	}
