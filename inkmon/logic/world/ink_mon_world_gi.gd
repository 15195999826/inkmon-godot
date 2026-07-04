class_name InkMonWorldGI
extends WorldGameplayInstance
## 主游戏唯一的、长命的 world GI (World-owns-Battle) —— Logic 层根。
##
## 承载世界运行时 (adr/0001 统一 live-actor, 本 GI = 序列化根):player_actor + roster 活 actor +
## 主世界 overworld grid + 玩家/NPC world actors + npc 表 + (战斗期) InkMonBattleProcedure。
## 战斗是它内跑的短命 procedure, 不是独立 GI。
## 持两套 grid (第一版临时方案, docs/main-game-architecture.md §1②):
##   - overworld_grid: 主世界 hex 网格 wrapper (InkMonWorldGrid; 玩家行走 + NPC occupant)
##   - battle grid: 战斗 hex 网格 (UGridMap.model, 每场战斗 configure)
## `grid` (基类字段) = 当前 active 的那套; start_battle_procedure 切到 battle, 战斗结束切回 overworld。
## overworld grid / move controller 是 Logic(无 UI 依赖),故住 Logic 层、归 GI 持有。
##
## 持久: Host 开机建一次, 不 per-battle create→destroy; 连续多场战斗复用同一实例
## (start_battle_procedure 内 reset-on-start 清上一场)。绝不在战斗结束 end() —— end() 单向销毁世界。
## lifecycle (save/load/reset/new-game) 由 Host 重建本实例驱动 (§1 运行模型)。


## 上行信号:near_npc_id 真相变化时 emit(空 = 离开所有 NPC 邻域)。
## 移动 tick 内 refresh_near_npc 在 actor_position_changed 之后才跑,故表演不能挂位置信号刷 prompt
## (会读到陈旧 near);改挂本信号 —— emit 时 near_npc_id 已是新值。
signal near_npc_changed(near_npc_id: String)

## 上行信号(CQRS 方案 A 的结果回流):buy/npc-action command 在 tick drain 生效后,把结果
## (含 message,可含 flow intent)emit 上行。Host connect 后刷 UI message / 解释 flow intent
## (start_battle 等)。"写不走同步返回值"靠此 —— 写路径只 submit,结果异步回流。
signal command_applied(result: Dictionary)

## 上行信号(mission flow, glossary §4.8):出征开始 / 步进 / 结束。
## ended payload = 结算摘要({outcome, gold_reward, adopted, supplies_left});"丢这趟"出口不 emit
## (Host load 出发档重建世界, 本 GI 连同 mission_state 整体销毁)。
signal mission_started()
signal mission_progressed(node_id: int)
signal mission_ended(result: Dictionary)
## 全灭上行(粮尽行军掉血致全 roster HP≤0):"丢这趟"由 Host 走 load 出发档, GI 只报告不自灭
## (lifecycle 归 Host; 且 signal 从 tick drain 内 emit, mid-tick 不能销毁世界)。
signal mission_wiped()
## 踩上野群节点上行(M2.2, Q2.3"节点即内容"必战): 起战斗是 Host flow(冻结世界/回放语义),
## GI 只报告; signal 从 tick drain 内 emit, Host 须 deferred 起 flow(对称 mission_wiped)。
signal mission_battle_triggered(node_id: int)


## 单格步进时长(秒):tick 内 move_progress += dt/STEP_DURATION;与 overworld view 的单步补间时长
## 对齐 —— 逻辑每跨一格耗 STEP_DURATION 秒,view 补间同款时长 → 逻辑↔表演同步。
const STEP_DURATION := 0.22

## 存档版本 (adr/0001 统一 live-actor 模型; v3 起含 world_map 世界地理; v4 起含 quest_board
## 委托板, Phase 3)。不符即丢弃重开。
const SAVE_VERSION := 4
## 新游戏默认出战上限 (左队取 roster 前 N)。
const MAX_BATTLE_UNITS := 4
## NPC 邻近判定半径 (axial 距离 ≤ 此值 = 相邻, 可交互)。
const NPC_PROXIMITY := 1
## 战斗奖励 (从旧玩家状态类内移; 战斗结束直接落活 actor / player_actor, 无摘要回写)。
const WIN_REWARD_GOLD := 25
const WIN_EXP := 5
const LOSS_EXP := 1


var tick_count := 0
var left_team: Array[InkMonUnitActor] = []
var right_team: Array[InkMonUnitActor] = []
var overworld_grid_model: GridMapModel = null
## 主世界角色(玩家 + NPC)= InkMonWorldActor,key = "player" 或 npc_id。
## 战斗单位不进此表(走 left_team/right_team);这些只是世界态实体,战斗对其隐形
## (不 equip ability、不注册 event handler,故战斗 tick / event 广播都碰不到)。
var world_actors: Dictionary = {}

# === 主世界运行时(adr/0001 统一 live-actor;Logic 层持有真相,Host 只 delegate)===
## 玩家走路 avatar + 玩家级数据 (gold/progression/medals/bag) = 常驻 registry 的活 actor。
## 同时进 world_actors["player"] (位置/移动) 与本字段 (玩家级数据访问)。
var player_actor: InkMonPlayerActor = null
## 出战 InkMon = 常驻 registry 的活 actor (有序; 跨战斗复用; 死留 registry/HP=0; 进存档)。
## 战斗时左队取本数组前 MAX_BATTLE_UNITS 只 (原地战斗, 无投影/回写)。
var roster: Array[InkMonUnitActor] = []
## 主世界 NPC 表(位置 / 显示名 / 类型), _setup_overworld_runtime 从 InkMonNpcRegistry 单一清单派生
## (与 _npc_handlers 同源, 消双份硬编码 Dict 漂移面)。
var npc_defs: Dictionary = {}
## 主世界 hex 网格 wrapper(占用 / 寻路 / 重定向)。Logic 层持有(grid 无 UI 依赖)。
var overworld_grid: InkMonWorldGrid = null
## 世界大地图地理 (P2, glossary §4.9): 开档一次生成、永久固定、进据点档 (序列化根之一)。
## 不进 grid 机器 —— 出征大地图逻辑真相 = 趟内节点图 (MissionState), 本数据只是固定地理底。
var world_map: InkMonWorldMapData = null
## 委托板 (Phase 3, Q3.3): 据点持久态 (进档, 回城结算刷新; 接单出征即摘单, 丢趟回档自然恢复)。
var quest_board: Array[InkMonQuestDef] = []
## 与玩家相邻(axial 距离 ≤1)的 NPC id;玩家移动后重算,"" = 无邻近。
var near_npc_id: String = ""
## 出征运行态 (P1: transient 不进存档, adr/0002 三叉; P2: 趟内节点图住此)。null = 不在出征中。
var mission_state: InkMonMissionState = null
## 主世界 command 队列(CQRS 写侧):UI/Host submit(InkMonWorldCommand) → tick 的 CommandDrain System
## 抽干, drain_commands 多态 cmd.apply(self)。持对象化命令(非无类型 dict)。
var _command_queue: Array[InkMonWorldCommand] = []
## NPC 服务(P6 内移):6 个 handler,自含规则、收 GI 自身(读写 player_actor/roster);Host 只转发 UI 点击。
var _npc_handlers: Dictionary = {}

var _ended := false
var _result := ""
var _final_replay_data: Dictionary = {}
var _inkmon_procedure: InkMonBattleProcedure = null
var _recording_enabled := true
## 当前战斗的生成图 doc (M2.2 野群模板图); {} = 静态默认图 (battle_main)。
## 回放侧凭此重建同一张棋盘 (Host 经 play_battle_replay 透传给 battle 2d view)。
var _battle_map_doc: Dictionary = {}
## 当前/最近一场战斗是否野群战 (M2.2): 野群战独有的收尾语义 (胜清必战锁 / 败走丢趟) 只认本标志
## —— 训练战 (dev-agent 路径无 mission guard) 在出征中打输绝不能误触全灭回档。
var _wild_battle := false


func _init(id_value: String = "") -> void:
	super._init(id_value if id_value != "" else IdGenerator.generate("inkmon_world"))
	type = "inkmon_world"
	battle_finished.connect(_on_battle_finished)


## adr/0001 新游戏: 建默认 player_actor + 默认 roster (活 actor 常驻 registry) + 容器, 再装配主世界。
func new_game() -> void:
	_ensure_started()
	_reset_item_runtime()
	player_actor = InkMonPlayerActor.create_new()
	player_actor.hex_position = HexCoord.new(0, 0)
	player_actor.bag_container_id = InkMonRosterSetup.register_container(&"bag")
	roster.clear()
	for unit_key in InkMonUnitConfig.get_default_roster(0):
		InkMonRosterSetup.add_from_config(self, str(unit_key))
	# 世界地理: 开档一次生成、此后永久固定 (P2; 真随机 seed —— 每个存档一个独特世界)。
	world_map = InkMonWorldMapData.generate(randi())
	# 委托板 (Phase 3): 开档首刷; 之后回城结算刷新。
	quest_board = InkMonQuestGen.roll_board(world_map, randi())
	_setup_overworld_runtime()


## adr/0001 读档: 存档数据 → 建活 actor (player + roster + 物品)。version 不符 → 丢弃重开 (返回 false), 否则 true。
## 存档永不向后兼容 (旧 session 模型档 version<2 → discard)。
func from_dict(data: Dictionary) -> bool:
	if int(data.get("version", -1)) != SAVE_VERSION:
		Log.warning("InkMonWorldGI",
			"incompatible save version %s (expected %d) — discarding save, starting new game"
			% [str(data.get("version", "<missing>")), SAVE_VERSION])
		new_game()
		return false
	# 物品预检: 存档引用的 item config 必须全部被当前 catalog 识别 (adr/0003: content 文件是唯一
	# 来源, 无 stub 兜底)。有缺 = 存档与内容数据世代不符 → 同 version 不符待遇, 丢弃重开;
	# 绝不带着未知物品进装配 (restore 的 assert_crash 会炸进程 —— 那个 assert 留给真程序 bug)。
	if not _save_item_configs_known(data):
		new_game()
		return false
	_ensure_started()
	_reset_item_runtime()
	var player_data := data.get("player", {}) as Dictionary
	player_actor = InkMonPlayerActor.from_dict(player_data if player_data != null else {})
	if not player_actor.hex_position.is_valid():
		player_actor.hex_position = HexCoord.new(0, 0)
	player_actor.bag_container_id = InkMonRosterSetup.register_container(&"bag")
	InkMonRosterSetup.restore_container_items(player_actor.bag_container_id, (player_data if player_data != null else {}).get("bag", []))
	roster.clear()
	var roster_data := data.get("roster", []) as Array
	if roster_data != null:
		for unit_value in roster_data:
			var unit_data := unit_value as Dictionary
			if unit_data != null:
				InkMonRosterSetup.add_from_save(self, unit_data)
	var map_data := data.get("world_map", {}) as Dictionary
	if map_data != null and not map_data.is_empty():
		world_map = InkMonWorldMapData.from_dict(map_data)
	else:
		# v3 档理应携带; 字段缺失/损坏时重生成一张兜底 (地理换新, 好过弃档)。
		world_map = InkMonWorldMapData.generate(randi())
	quest_board.clear()
	var board_data := data.get("quest_board", []) as Array
	if board_data != null:
		for quest_value in board_data:
			var quest_data := quest_value as Dictionary
			if quest_data != null:
				quest_board.append(InkMonQuestDef.from_dict(quest_data))
	_setup_overworld_runtime()
	return true


## adr/0001 写档: 遍历 player_actor + roster actors (各自序列化持久切片含容器物品)。Host 编排落盘。
func to_dict() -> Dictionary:
	# capture: 先把运行时玩家位置 (grid occupant 真相) 同步进 avatar, 再序列化 (§3 单写)。
	var coord := get_player_coord()
	if player_actor != null:
		player_actor.hex_position = HexCoord.new(coord.x, coord.y)
	var roster_data: Array[Dictionary] = []
	for actor in roster:
		roster_data.append(actor.to_dict())
	var board_data: Array[Dictionary] = []
	for quest in quest_board:
		board_data.append(quest.to_dict())
	return {
		"version": SAVE_VERSION,
		"player": player_actor.to_dict() if player_actor != null else {},
		"roster": roster_data,
		"world_map": world_map.to_dict() if world_map != null else {},
		"quest_board": board_data,
	}


## 物品预检 (from_dict 丢弃判定): 扫存档全部物品引用 (player.bag + roster[].equipment) 的
## config_id, 任一不被当前 catalog 识别 → false (调用方按不兼容档丢弃重开)。
func _save_item_configs_known(data: Dictionary) -> bool:
	var catalog := InkMonItemCatalog.new()
	for config_id in _collect_save_item_config_ids(data):
		if not catalog.has_config(StringName(config_id)):
			Log.warning("InkMonWorldGI",
				"save references unknown item config '%s' (content data generation mismatch) — discarding save, starting new game"
				% config_id)
			return false
	return true


static func _collect_save_item_config_ids(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var item_lists: Array = []
	var player_data := data.get("player", {}) as Dictionary
	if player_data != null:
		item_lists.append(player_data.get("bag", []))
	var roster_data := data.get("roster", []) as Array
	if roster_data != null:
		for unit_value in roster_data:
			var unit_data := unit_value as Dictionary
			if unit_data != null:
				item_lists.append(unit_data.get("equipment", []))
	for list_value in item_lists:
		var item_list := list_value as Array
		if item_list == null:
			continue
		for item_value in item_list:
			var item := item_value as Dictionary
			if item == null:
				continue
			var config_id := str(item.get("config_id", ""))
			if config_id != "" and not result.has(config_id):
				result.append(config_id)
	# Phase 3: 委托板奖励物品同样进预检面 —— 引用已删 item 的档按世代不符丢弃重开,
	# 不让 settle 时 create_bag_item 静默失败吞掉奖励。
	var board_data := data.get("quest_board", []) as Array
	if board_data != null:
		for quest_value in board_data:
			var quest_data := quest_value as Dictionary
			if quest_data == null:
				continue
			var reward_item := str(quest_data.get("reward_item_id", ""))
			if reward_item != "" and not result.has(reward_item):
				result.append(reward_item)
	return result


# === 物品 / 容器 / roster 装配 (adr/0001) ===

## 重置 ItemSystem session + 装 inkmon 物品域 (new_game / from_dict 起手)。
func _reset_item_runtime() -> void:
	ItemSystem.reset_session()
	ItemSystem.configure_domain(InkMonItemDomain.new(), InkMonItemCatalog.new())


## 在玩家 bag 容器建物品 (shop 购买入袋)。供 NPC handler / UI 调。
func create_bag_item(config_id: StringName, count: int = 1, slot_index: int = -1) -> ItemCreateResult:
	Log.assert_crash(player_actor != null and player_actor.bag_container_id > 0,
		"InkMonWorldGI", "bag container not ready")
	return ItemSystem.create_item(player_actor.bag_container_id, config_id, count, slot_index)


## 领养 = 程序化出生 (确定性 roll 技能槽) 建活 roster actor。供 release_adopt handler 调; 装配在 InkMonRosterSetup。
func adopt_unit(species_id: String, roll_seed: int) -> InkMonUnitActor:
	return InkMonRosterSetup.adopt(self, species_id, roll_seed)


## 重算某 roster actor 的派生六维 (cultivation 升级 / 进化 / 装备变更后调; species base 由 SpeciesCatalog 供)。
func refresh_unit_stats(actor: InkMonUnitActor) -> void:
	if actor == null:
		return
	actor.apply_derived_stats(InkMonSpeciesCatalog.get_base_stats(actor.species))


## 主世界运行时装配 (new_game / from_dict 共用): grid + npc handler + 放 occupant + 注册 world actor + systems。
func _setup_overworld_runtime() -> void:
	# npc_defs (读模型) 与 _npc_handlers (行为) 同源自 InkMonNpcRegistry 单一清单派生。
	npc_defs = InkMonNpcRegistry.build_npc_defs()
	_npc_handlers = InkMonNpcRegistry.build_npc_handlers()
	overworld_grid = InkMonWorldGrid.new()
	overworld_grid.setup()
	# 用 player_actor 持久坐标 (存档真相) 灌 grid occupant —— 不能用 get_player_coord() (此刻 grid 刚建、
	# 占用未放, 会读回 (0,0) 丢掉存档坐标)。player_actor 随后在 _spawn_world_actors 进 registry。
	overworld_grid.sync_occupants(_player_actor_coord(), npc_defs)
	overworld_grid_model = overworld_grid.model
	grid = overworld_grid.model
	_register_world_systems()
	_spawn_world_actors()
	refresh_near_npc()


## 注册主世界 tick 两阶段 System:CommandDrain(抽干命令)→ Movement(逐格推进)。
## base_tick 按 priority 跑;有战斗时 GI.tick 走 battle 分支不跑 systems(移动战斗期冻结)。
func _register_world_systems() -> void:
	add_system(InkMonCommandDrainSystem.new())
	add_system(InkMonWorldMovementSystem.new())


## CQRS 写侧唯一入口:UI/Host submit(InkMonWorldCommand) 入队(异步)。不立即生效 ——
## 下个 tick 的 CommandDrain 抽干, drain_commands 多态 cmd.apply(self),结果经 command_applied / 位置信号回流。
func submit(command: InkMonWorldCommand) -> void:
	if command == null:
		return
	_command_queue.append(command)


## tick 第一阶段(CommandDrain System 调):抽干命令队列, 多态派发 cmd.apply(self)。
## 加新命令只加一个 InkMonWorldCommand 子类 —— 此处不动(替掉了旧的无类型 {"kind":...} + if kind== 阶梯)。
func drain_commands() -> void:
	# 战斗期世界冻结 (docs §2②): battle procedure.tick_once 直调 base_tick 仍会跑 CommandDrain System,
	# 本守卫对称 advance_world_movement 的战斗守卫 —— 战斗期入队的 command 留队列, 战后 tick 再生效。
	if has_active_battle():
		return
	while not _command_queue.is_empty():
		var command := _command_queue.pop_front() as InkMonWorldCommand
		if command != null:
			command.apply(self)


## command_applied 单一 emit 入口:buy/npc-action command apply 后把结果(含 message / flow intent)回流。
func emit_command_applied(result: Dictionary) -> void:
	command_applied.emit(result)


# === mission:出征 flow(P1/P2 拍板, 术语 glossary §4.8)===

## 出征开始(Host flow 调, 且必须在写出发档**之后**):建出征态(选目标地标 + 蔓延生成趟内节点图)。
## Host 控制面同步调用(非 command 通道), 返回 {ok, message}。
func start_mission(config: Dictionary = {}) -> Dictionary:
	if has_active_battle():
		return {"ok": false, "message": "cannot start mission during battle"}
	if has_active_mission():
		return {"ok": false, "message": "mission already active"}
	mission_state = InkMonMissionSetup.build_state(self, config)
	# 迷雾 (Phase 4): 出发即点亮入口视野圆 (持久层) + 记圆内节点快照 (趟内 seen)。
	_update_mission_sight()
	mission_started.emit()
	return {"ok": true, "message": "mission started"}


func has_active_mission() -> bool:
	return mission_state != null


## tick drain 时由 InkMonMissionMoveCommand.apply 调:沿趟内节点图走一跳。
## 非法移动(无边 / 不在出征中 / 野群战斗未打)静默拒(对称 apply_move_player 的宽容风格)。
func apply_mission_move(node_id: int) -> void:
	if not has_active_mission():
		return
	# M2.2 必战锁: 踩上野群节点后战斗未收尾前, 选路一律拒 (节点即内容, 不可绕/不可跑)。
	if mission_state.has_pending_battle():
		return
	if not mission_state.map.has_edge(mission_state.current_node_id, node_id):
		return
	mission_state.current_node_id = node_id
	mission_state.visited_node_ids[node_id] = true
	# 补给钟(M1.4): 有粮扣粮; 粮尽行军 = 全队掉真 HP(carryover), 全灭 → "丢这趟"出口。
	if mission_state.supplies > 0:
		mission_state.supplies -= 1
	elif InkMonMissionSetup.apply_starvation(self):
		# 全灭: 不再 emit progressed / 不判抵达 —— 世界即将被 Host load 出发档整体重建。
		mission_wiped.emit()
		return
	# 迷雾 (Phase 4): 每步点亮当前视野圆 (持久) + 记圆内节点快照 (趟内 seen)。
	_update_mission_sight()
	mission_progressed.emit(node_id)
	# M2.2 踩野群节点必战 (Q2.3): 置必战锁 + 上行交 Host 起战斗 flow。判据 = 带野群 payload
	# (中间层 battle 节点 / 讨伐型主委托的把守 target 节点, Phase 3), 与抵达结算互斥 ——
	# 把守 target 的完成判定延到战胜离场 (resolve_wild_battle_encounter)。
	var wild_pack := mission_state.map.get_node_info(node_id).get("wild", []) as Array
	if wild_pack != null and not wild_pack.is_empty():
		mission_state.pending_battle_node_id = node_id
		mission_battle_triggered.emit(node_id)
		return
	if mission_state.is_at_target():
		# 抵达目标节点 = 主委托完成 (reach 型) → 自动结算回城。
		end_mission("complete")


## 迷雾维护 (Phase 4, 出发/每步调): ①视野圆内世界格进持久点亮 (revealed_cells, 黑→灰的永久层)
## ②视野圆内节点记类型快照进趟内 seen (Q4.5 灰态"最后所见")。
## 当前视野圆 = 以当前节点锚格为圆心、玩家 sight_range 为半径的 hex 圆 (拍板 Q4.2)。
func _update_mission_sight() -> void:
	if not has_active_mission() or world_map == null:
		return
	var center := mission_state.map.get_node_info(mission_state.current_node_id).get("coord", Vector2i.ZERO) as Vector2i
	var sight := player_actor.sight_range if player_actor != null else InkMonPlayerActor.DEFAULT_SIGHT_RANGE
	var center_hex := HexCoord.new(center.x, center.y)
	for row in range(world_map.height):
		for col in range(world_map.width):
			var cell := InkMonWorldMapData.offset_to_axial(col, row)
			if center_hex.distance_to(HexCoord.new(cell.x, cell.y)) <= sight:
				world_map.reveal_cell(cell)
	for node in mission_state.map.nodes:
		var node_coord := node.get("coord", Vector2i.ZERO) as Vector2i
		if center_hex.distance_to(HexCoord.new(node_coord.x, node_coord.y)) <= sight:
			mission_state.seen_node_kinds[int(node.get("id", -1))] = str(node.get("kind", ""))


## 出征结束 —— 两出口(P1)之一"主委托完成"走此;"丢这趟"**不经此**(Host load 出发档重建世界,
## 本 GI 连同 mission_state 整体销毁, 天然回滚)。
func end_mission(outcome: String) -> void:
	if not has_active_mission():
		return
	var result := {"outcome": outcome}
	if outcome == "complete":
		result = InkMonMissionSetup.settle_complete(self)
	mission_state = null
	mission_ended.emit(result)


## latest-wins(方案 A):新目标 → 走完正在进入的当前格(occupant 自然 flip 到 moving_to),
## moving_to 之后的旧路立即丢弃换 astar(moving_to, target);静止则从当前格起步。
## 由 InkMonMoveCommand.apply 调用(写路径:submit(InkMonMoveCommand) → tick drain → 此)。
func apply_move_player(target_coord: Vector2i) -> void:
	var player := get_world_actor(InkMonWorldGrid.PLAYER_ID)
	if player == null or overworld_grid == null:
		return
	var resolved := overworld_grid.resolve_target_for_actor(InkMonWorldGrid.PLAYER_ID, target_coord)
	if not bool(resolved.get("ok", false)):
		return
	var resolved_target := resolved.get("target", target_coord) as Vector2i
	if player.is_moving():
		# 正在进入的当前格不打断;只替换 moving_to 之后的路。
		player.pending_path = overworld_grid.find_path(InkMonWorldGrid.PLAYER_ID, player.moving_to.to_axial(), resolved_target)
	else:
		var path := overworld_grid.find_path(InkMonWorldGrid.PLAYER_ID, player.hex_position.to_axial(), resolved_target)
		if path.is_empty():
			return
		player.moving_to = HexCoord.new(path[0].x, path[0].y)
		player.pending_path = path.slice(1)
		player.move_progress = 0.0


## tick 第二阶段(Movement System 调):推进每个移动中 world actor 的进度,逐格跨越。
func advance_world_movement(dt: float) -> void:
	# P5 双 grid 边界加固:主世界移动只读 overworld_grid(稳定),绝不读会在战斗期翻转到 battle grid
	# 的基类 `grid`;且战斗期 base_tick 不跑(GI.tick 走 battle 分支)→ Movement 天然冻结,此处再兜一层。
	if has_active_battle() or overworld_grid == null:
		return
	var player_crossed := false
	for actor_value in world_actors.values():
		var actor := actor_value as InkMonWorldActor
		if actor == null or not actor.is_moving():
			continue
		if _advance_actor_movement(actor, dt):
			player_crossed = true
	if player_crossed:
		refresh_near_npc()


## 推进单个 actor 的逐格移动:progress += dt/步时长;≥1 → occupant 跨一格 + emit signal + 取下一格。
## 返回本帧是否至少跨了一格(用于触发 near-npc 重算)。
func _advance_actor_movement(actor: InkMonWorldActor, dt: float) -> bool:
	if STEP_DURATION <= 0.0:
		return false
	actor.move_progress += dt / STEP_DURATION
	var crossed := false
	while actor.move_progress >= 1.0 and actor.is_moving():
		var from_cell := actor.hex_position
		var to_cell := actor.moving_to
		if not overworld_grid.move_occupant(from_cell.to_axial(), to_cell.to_axial()):
			# 目标格意外被占(静止 NPC + find_path 下不该发生);停在当前格。
			actor.moving_to = HexCoord.invalid()
			actor.move_progress = 0.0
			break
		actor.hex_position = to_cell
		actor_position_changed.emit(actor.get_id(), from_cell, to_cell)
		crossed = true
		actor.move_progress -= 1.0
		if not actor.pending_path.is_empty():
			var next := actor.pending_path[0]
			actor.pending_path = actor.pending_path.slice(1)
			actor.moving_to = HexCoord.new(next.x, next.y)
		else:
			actor.moving_to = HexCoord.invalid()
			actor.move_progress = 0.0
	return crossed


## 运行时玩家位置真相 = 主世界 grid 的 occupant(§3 不双写)。grid 未建时回退 avatar 持久坐标。
func get_player_coord() -> Vector2i:
	if overworld_grid != null:
		return overworld_grid.get_player_coord()
	return _player_actor_coord()


## avatar (player_actor) 自身的持久坐标:grid 未建时的回退源 (new_game/from_dict 已设好)。
func _player_actor_coord() -> Vector2i:
	if player_actor == null or not player_actor.hex_position.is_valid():
		return Vector2i.ZERO
	return player_actor.hex_position.to_axial()


## 重算与玩家相邻(axial 距离 ≤1)的 NPC;写入 near_npc_id("" = 无邻近),变化则 emit。
func refresh_near_npc() -> void:
	_set_near_npc(_compute_near_npc())


## 当前玩家邻域(axial 距离 ≤1)第一个 NPC id;无邻近返回 ""。
## npc_defs 插入序稳定 → 多 NPC 同时相邻时结果确定(取首个)。
func _compute_near_npc() -> String:
	var player_coord := get_player_coord()
	var player_hex := HexCoord.new(player_coord.x, player_coord.y)
	for npc_id_value in npc_defs.keys():
		var npc_def := npc_defs[npc_id_value] as Dictionary
		var npc_coord := npc_def.get("coord", Vector2i.ZERO) as Vector2i
		if player_hex.distance_to(HexCoord.new(npc_coord.x, npc_coord.y)) <= NPC_PROXIMITY:
			return str(npc_id_value)
	return ""


func clear_near_npc() -> void:
	_set_near_npc("")


## near-npc 真相单一写入口:仅在值变化时落地并 emit near_npc_changed。
## 集中于此 → 任何改 near 的路径(tick 重算 / reset / load / clear)都自动通知表演,无遗漏。
func _set_near_npc(value: String) -> void:
	if near_npc_id == value:
		return
	near_npc_id = value
	near_npc_changed.emit(near_npc_id)


## 玩家 (持久 player_actor) + 6 NPC (InkMonWorldActor) 进本 GI registry(world actors 表)。
## 玩家 avatar = new_game/from_dict 已建的 player_actor 本体 (非新建), 进 registry + world_actors。
func _spawn_world_actors() -> void:
	var player_coord := get_player_coord()
	player_actor.hex_position = HexCoord.new(player_coord.x, player_coord.y)
	player_actor.moving_to = HexCoord.invalid()
	player_actor.move_progress = 0.0
	player_actor.pending_path = []
	add_actor(player_actor)
	world_actors[InkMonWorldGrid.PLAYER_ID] = player_actor
	for npc_id_value in npc_defs.keys():
		var npc_id := str(npc_id_value)
		var npc_def := npc_defs[npc_id] as Dictionary
		if npc_def == null:
			continue
		var coord := npc_def.get("coord", Vector2i.ZERO) as Vector2i
		spawn_world_actor(npc_id, str(npc_def.get("display_name", npc_id)), coord)


## 注册一个主世界角色(玩家 / NPC)为 InkMonWorldActor 进 registry。
## key = 调方约定的稳定标识("player" 或 npc_id),用于 query / movement 回查。
## 只收 string key + coord,不引 main 层 grid wrapper(保 battle 不依赖 main)。
func spawn_world_actor(key: String, display_name: String, coord: Vector2i) -> InkMonWorldActor:
	_ensure_started()
	var actor := InkMonWorldActor.new()
	actor.type = "inkmon_world_actor"
	actor.set_display_name(display_name)
	actor.hex_position = HexCoord.new(coord.x, coord.y)
	add_actor(actor)
	world_actors[key] = actor
	return actor


## 按稳定 key 取主世界角色(玩家 / NPC);不存在返回 null。
func get_world_actor(key: String) -> InkMonWorldActor:
	return world_actors.get(key, null) as InkMonWorldActor


## 战斗录像范围 = 战斗单位。常驻 registry 里的 overworld 实体（InkMonPlayerActor /
## InkMonWorldActor）不进 world_snapshot, 否则 2D 回放会为它们建战斗替身。
func should_record_actor(actor: Actor) -> bool:
	return actor is InkMonUnitActor


## 在本 world GI 内起一场战斗 (procedure 模式)。可重复调用 (reset-on-start 清上一场)。
## 此路径建**临时**队伍 (从 config / 默认 roster key); 玩家 roster 出战走 request_training_battle。
func start_battle_procedure(config: Dictionary = {}) -> void:
	_reset_battle_state()
	_recording_enabled = config.get("recording", true)
	InkMonBattleSetup.configure_battle_grid(self, config)
	InkMonBattleSetup.setup_teams(self, config)
	_begin_battle_with_current_teams()


## adr/0001:在本 GI 内起 training 战斗 (World-owns-Battle), 左队 = **活 roster** (原地战斗, 无投影/回写),
## 右队 = 临时训练假人。Host 只说"打 training"。
func request_training_battle() -> void:
	_reset_battle_state()
	# adr/0005:打开录像 → world_snapshot 供 2D 回放 animator 独立重建开战阵容。
	_recording_enabled = true
	InkMonBattleSetup.configure_battle_grid(self, {})
	left_team = InkMonBattleSetup.battle_roster_slice(self)
	right_team = InkMonBattleSetup.build_training_dummies(self)
	_begin_battle_with_current_teams()


## M2.2 野群战斗 (Host wild battle flow 调, 前置 = apply_mission_move 已置必战锁):
## 战斗地图 = 模板生成 (seed 从 mission_seed+节点 id 派生 → 复跑同图; 皮肤 = 节点所在世界格地形),
## 左队 = 活 roster, 右队 = 节点 wild payload 建临时野生 actor (训练假人同款生命周期)。
func request_wild_battle() -> void:
	Log.assert_crash(has_active_mission() and mission_state.has_pending_battle(),
		"InkMonWorldGI", "wild battle requested without a pending battle node")
	var node_id := mission_state.pending_battle_node_id
	var node_info := mission_state.map.get_node_info(node_id)
	var wild_pack := node_info.get("wild", []) as Array
	Log.assert_crash(wild_pack != null and not wild_pack.is_empty(),
		"InkMonWorldGI", "battle node %d missing wild payload" % node_id)
	_reset_battle_state()
	_wild_battle = true
	_recording_enabled = true
	var node_coord := node_info.get("coord", Vector2i.ZERO) as Vector2i
	var map_seed := mission_state.mission_seed * 1000003 + node_id
	_battle_map_doc = InkMonWildBattleMapGen.generate_doc(map_seed, world_map.terrain_at(node_coord))
	InkMonBattleSetup.configure_battle_grid(self, {"map_doc": _battle_map_doc})
	left_team = InkMonBattleSetup.battle_roster_slice(self)
	right_team = InkMonBattleSetup.build_wild_pack(self, wild_pack, InkMonBattleSetup.party_battle_level(self))
	_begin_battle_with_current_teams()


## 当前战斗生成图 doc ({} = 静态默认图)。Host 收战斗时透传回放侧重建同一张棋盘。
func get_battle_map_doc() -> Dictionary:
	return _battle_map_doc


## 当前/最近一场战斗是否野群战 (下一场战斗 reset 时翻回 false)。Host 收战斗时据此分派野群败局出口。
func is_wild_battle() -> bool:
	return _wild_battle


# === 战后捕捉 (M2.3, Q2.1 气绝制: 胜利后留在战斗场景, 对气绝野生个体逐只扔球一次) ===

## 胜利收尾建捕捉池: 节点 wild payload × 右队 actor (下标对齐, build_wild_pack 保序)。
## roll_seed 进池 —— 捕获后 adopt 复用同一 seed, "场上什么技能, 捕来就什么技能" (M2.1 拍板)。
func _build_capture_pool() -> void:
	mission_state.capture_pool.clear()
	var node_info := mission_state.map.get_node_info(mission_state.pending_battle_node_id)
	var wild_pack := node_info.get("wild", []) as Array
	if wild_pack == null:
		return
	for i in range(wild_pack.size()):
		var entry := wild_pack[i] as Dictionary
		if entry == null:
			continue
		var wild_actor := right_team[i] if i < right_team.size() else null
		mission_state.capture_pool.append({
			"slot_index": i,
			"actor_id": wild_actor.get_id() if wild_actor != null else "",
			"species_id": str(entry.get("species_id", "")),
			"roll_seed": int(entry.get("roll_seed", 0)),
			"display_name": wild_actor.get_display_name() if wild_actor != null else str(entry.get("species_id", "")),
			"attempted": false,
			"captured": false,
		})


## 掷球捕捉 (Host 控制面调 —— 回放观看期世界泵冻结, command 不 drain, 捕捉走 Host 直调,
## 对称 save/load 槽位的控制面路由)。每只恰好一次尝试; 成功暂存 captured_pending (回城 adopt 结算)。
func attempt_wild_capture(slot_index: int) -> Dictionary:
	if not has_active_mission() or not mission_state.has_pending_battle():
		return {"ok": false, "message": "no capture window"}
	for entry in mission_state.capture_pool:
		if int(entry.get("slot_index", -1)) != slot_index:
			continue
		if bool(entry.get("attempted", false)):
			return {"ok": false, "message": "already attempted", "slot_index": slot_index}
		entry["attempted"] = true
		var species := str(entry.get("species_id", ""))
		var chance := InkMonCaptureRules.capture_chance(species)
		var roll := InkMonCaptureRules.capture_roll(
			mission_state.mission_seed, mission_state.pending_battle_node_id, slot_index)
		var captured := roll < chance
		entry["captured"] = captured
		if captured:
			mission_state.captured_pending.append({
				"species_id": species,
				"roll_seed": int(entry.get("roll_seed", 0)),
			})
			# 副委托计数 (Phase 3): 捕获成功 +1。
			InkMonMissionSetup.record_mission_event(mission_state, InkMonQuestDef.TYPE_CAPTURE_COUNT)
		return {
			"ok": true,
			"slot_index": slot_index,
			"captured": captured,
			"species_id": species,
			"display_name": str(entry.get("display_name", species)),
			"chance": chance,
		}
	return {"ok": false, "message": "unknown capture slot %d" % slot_index}


## 离开战场 = 野群遭遇收尾 (Host 在 battle_view_left / 无回放降级路径调): 清必战锁 + 作废
## 未尝试的捕捉机会 ("扔球窗口 = 留在战斗场景期间")。幂等; 败局不经此 (世界整体重建)。
## _wild_battle 门: Host 对任何战斗离场都会调此 —— pending 锁定期混入的训练战 (dev-agent 路径)
## 离场绝不能清掉还没打的野群锁, 只有"刚结束的战斗就是这场野群战"才收尾。
## Phase 3 讨伐型: 把守 target 的野群清掉后离场即主委托完成 → 结算回城 (胜后捕捉窗口仍完整)。
func resolve_wild_battle_encounter() -> void:
	if not _wild_battle or not has_active_mission():
		return
	mission_state.pending_battle_node_id = -1
	mission_state.capture_pool.clear()
	# 讨伐完成必须是**打赢**离场 (_result 仍是这场结果): timeout 等非胜结局清锁但不算清剿 ——
	# 站在把守 target 上无出边, 玩家只剩放弃出口 (诚实败局; 4v4 自动战 timeout 是万 tick 级极端)。
	if _result == "left_win" and mission_state.is_at_target():
		end_mission("complete")


## 捕捉池值拷贝快照 (Host 推给回放视图做点选交互; 不外递内部 Dict 引用)。
func get_capture_pool_snapshot() -> Array[Dictionary]:
	if not has_active_mission():
		return []
	var result: Array[Dictionary] = []
	for entry in mission_state.capture_pool:
		result.append(entry.duplicate(true))
	return result


## 用当前 left_team/right_team 起战斗: 每只备战 (全新 ability_set + 装技能 + 归零 ATB) → 布阵 → 注册 timeline → 开打。
func _begin_battle_with_current_teams() -> void:
	for actor in get_all_units():
		_prepare_actor_for_battle(actor)
	InkMonBattleSetup.place_team_fixed(self, left_team, [
		HexCoord.new(-3, -1), HexCoord.new(-3, 0), HexCoord.new(-3, 1), HexCoord.new(-2, 0),
	])
	InkMonBattleSetup.place_team_fixed(self, right_team, [
		HexCoord.new(3, -1), HexCoord.new(3, 0), HexCoord.new(3, 1), HexCoord.new(2, 0),
	])
	InkMonAllSkills.register_all_timelines()
	var participants: Array[Actor] = []
	for actor in get_all_units():
		participants.append(actor)
	start_battle(participants)


## 备战单只: 全新 ability_set (持久 roster actor 跨战斗复用须清上场授予, 防重复 grant) + 重新装技能。
func _prepare_actor_for_battle(actor: InkMonUnitActor) -> void:
	actor.reset_battle_runtime()
	actor.equip_abilities(self)


func tick(dt: float) -> void:
	super.tick(dt)
	if _inkmon_procedure != null:
		tick_count = _inkmon_procedure.get_current_tick()


## battle grid backend = UGridMap autoload。
func configure_grid(config: GridMapConfig) -> void:
	UGridMap.configure(config)
	grid = UGridMap.model
	grid_configured.emit(config)


## 数据驱动版（T2 契约）：地图文件 → GridMapModel（initialize_from_tiles 产物）灌进
## UGridMap 单例（一次一图，battle 进场重灌）。
func configure_grid_model(model: GridMapModel) -> void:
	UGridMap.configure_model(model)
	grid = UGridMap.model
	grid_configured.emit(model.get_config())


func remove_actor(actor_id: String) -> bool:
	var actor := super.get_actor(actor_id)
	if actor != null and actor is InkMonBattleActor:
		InkMonBattleSetup.clear_actor_footprint(self, actor as InkMonBattleActor)
	return super.remove_actor(actor_id)


## registry lookup (adr/0001: 一切实体常驻 registry, 标准 lookup 须能取回 player/NPC/unit)。
## 返回 InkMonWorldActor 广义基类 (player_actor/NPC = InkMonWorldActor, unit = InkMonUnitActor 均 is-a);
## 绝不窄化成 InkMonBattleActor —— 否则非战斗 actor 被 as 转成 null, GameWorld.get_actor(player_id) 拿不到。
## 战斗调用点 (需 is_dead/attribute_set/ability_set) 走 get_battle_actor / get_unit_actor。
func get_actor(actor_id: String) -> InkMonWorldActor:
	return super.get_actor(actor_id) as InkMonWorldActor


## 战斗 actor 窄化 lookup (需 is_dead / attribute_set / ability_set 的战斗调用点用)。非战斗 actor 返回 null。
func get_battle_actor(actor_id: String) -> InkMonBattleActor:
	return super.get_actor(actor_id) as InkMonBattleActor


func get_unit_actor(actor_id: String) -> InkMonUnitActor:
	return super.get_actor(actor_id) as InkMonUnitActor


func get_all_units() -> Array[InkMonUnitActor]:
	var result: Array[InkMonUnitActor] = []
	result.append_array(left_team)
	result.append_array(right_team)
	return result


func get_alive_actor_ids() -> Array[String]:
	var result: Array[String] = []
	for actor in get_alive_actors():
		result.append(actor.get_id())
	return result


func get_alive_actors() -> Array[InkMonUnitActor]:
	var result: Array[InkMonUnitActor] = []
	for actor in get_all_units():
		if not actor.is_dead():
			result.append(actor)
	return result


func get_result() -> String:
	return _result


## 结果摘要 (winner_team / source_team / reward_gold);逻辑在 InkMonBattleSetup, 此处薄委派 (公开 API)。
func get_result_summary() -> Dictionary:
	return InkMonBattleSetup.get_result_summary(self)


## 战斗结束发奖 (公开 API, Host 调);逻辑在 InkMonBattleSetup, 此处薄委派。
func finalize_battle_rewards() -> Dictionary:
	return InkMonBattleSetup.finalize_battle_rewards(self)


# === NPC 服务(P6 从 Host 内移;Logic 持有,Host 转发 UI 点击;清单派生见 InkMonNpcRegistry)===

func has_npc_handler(npc_id: String) -> bool:
	return _npc_handlers.has(npc_id)


## Query(读):某 NPC 的可选 action 列表(表演据此建按钮,纯只读)。handler 收 GI 自身 (读 player_actor/roster)。
func get_npc_actions(npc_id: String) -> Array:
	if not _npc_handlers.has(npc_id):
		return []
	return (_npc_handlers[npc_id] as InkMonNpcHandler).get_actions(self)


## 运行 NPC action:handler 收 GI 自身自含规则 (读写 player_actor/roster + 调 GI 物品/领养/进化方法);返回结果
## (training 含 flow intent,Host 解释起战斗 —— 战斗 flow/app_state 归 Host)。
## 写路径请走 submit(InkMonNpcActionCommand) —— 本方法是其 apply 目标(tick drain 内调用),结果经 command_applied 回流。
func run_npc_action(npc_id: String, action_id: String) -> Dictionary:
	if not _npc_handlers.has(npc_id):
		return {"ok": false, "message": "unknown NPC handler: %s" % npc_id}
	return (_npc_handlers[npc_id] as InkMonNpcHandler).run_action(action_id, self)


## 购买商店物品:规则住 shop handler,收 GI 自身。
## 写路径请走 submit(InkMonBuyCommand) —— 本方法是其 apply 目标(tick drain 内调用),结果经 command_applied 回流。
func buy_shop_item(config_id: StringName) -> Dictionary:
	var shop := _npc_handlers.get("shop", null) as InkMonShopNpcHandler
	if shop == null:
		return {"ok": false, "message": "shop handler not available"}
	return shop.buy(self, config_id)


func is_ended() -> bool:
	return _ended


func get_replay_data() -> Dictionary:
	if not _final_replay_data.is_empty():
		return _final_replay_data
	var rec: BattleRecorder = _inkmon_procedure.get_recorder() if _inkmon_procedure != null else null
	if rec != null and rec.get_is_recording():
		return rec.stop_recording()
	return {}


func _create_battle_procedure(_participants: Array[Actor]) -> BattleProcedure:
	_inkmon_procedure = InkMonBattleProcedure.new(self, left_team, right_team, {
		"recording": _recording_enabled,
	})
	return _inkmon_procedure


func _on_battle_finished(timeline: Dictionary) -> void:
	_ended = true
	_final_replay_data = timeline
	if _inkmon_procedure != null:
		_result = _inkmon_procedure.get_result()
		tick_count = _inkmon_procedure.get_current_tick()
	print("[InkMonWorldGI] battle finished result=%s ticks=%d" % [_result, tick_count])
	# M2.2/M2.3 野群战斗收尾 (只认野群战: 出征中混入的训练战胜负都不碰必战锁/捕捉池):
	#   胜 (left_win) → 建捕捉池, 必战锁**保持**到离开战场 (resolve_wild_battle_encounter);
	#   败 (right_win) → 全灭不清 —— Host 据 result 走"丢这趟", 世界连同 mission_state 整体重建;
	#   超时等其它 → 无捕捉窗口, 即刻清锁解锁选路。
	if _wild_battle and has_active_mission() and mission_state.has_pending_battle():
		if _result == "left_win":
			_build_capture_pool()
			# 副委托计数 (Phase 3): 野群战胜 +1。
			InkMonMissionSetup.record_mission_event(mission_state, InkMonQuestDef.TYPE_HUNT_COUNT)
		elif _result != "right_win":
			mission_state.pending_battle_node_id = -1
	# 持久 world: 不 end() (那会单向销毁世界)。切回主世界 grid (若已 bind)。
	_inkmon_procedure = null
	if overworld_grid_model != null:
		grid = overworld_grid_model


## 清上一场战斗, 让本实例可被下一场复用。adr/0001:持久 roster actor **留 registry + 留 HP carryover**,
## 只清其外部战斗态 (P021: handler / grid occupant / reservation) + 重置战斗运行时;临时对战单位整只移除。
func _reset_battle_state() -> void:
	for actor in get_all_units():
		var aid := actor.get_id()
		if GameWorld.event_processor != null:
			GameWorld.event_processor.remove_handlers_by_owner_id(aid)
		if roster.has(actor):
			InkMonBattleSetup.clear_actor_footprint(self, actor)
			actor.reset_battle_runtime()
		else:
			remove_actor(aid)
	left_team.clear()
	right_team.clear()
	_ended = false
	_result = ""
	_final_replay_data = {}
	_battle_map_doc = {}
	_wild_battle = false
	tick_count = 0


func _ensure_started() -> void:
	if get_state() == "created":
		super.start()
