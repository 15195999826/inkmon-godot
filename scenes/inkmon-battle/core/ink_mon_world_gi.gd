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


## 单格步进时长(秒):tick 内 move_progress += dt/STEP_DURATION;与 View3D MOVE_STEP_DURATION
## 对齐 —— 逻辑每跨一格耗 STEP_DURATION 秒,view 补间同款时长 → 逻辑↔表演同步。
const STEP_DURATION := 0.22

## 存档版本 (adr/0001 统一 live-actor 模型, 旧 session 模型档不兼容 → 不符即丢弃重开)。
const SAVE_VERSION := 2
## 新游戏默认出战上限 (左队取 roster 前 N)。
const MAX_BATTLE_UNITS := 4
## 战斗奖励 (从旧玩家状态类内移; 战斗结束直接落活 actor / player_actor, 无摘要回写)。
const WIN_REWARD_GOLD := 25
const WIN_EXP := 5
const LOSS_EXP := 1


var tick_count := 0
var left_team: Array[InkMonUnitActor] = []
var right_team: Array[InkMonUnitActor] = []
var damage_mod_seen := false
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
## 主世界 NPC 表(位置 / 显示名 / 类型)。v1 hardcode stub(CONTEXT: NPC 仍 stub)。
var npc_defs: Dictionary = {
	"shop": {
		"display_name": "Shop",
		"type": "shop",
		"coord": Vector2i(2, 0),
	},
	"trainer": {
		"display_name": "Training",
		"type": "training",
		"coord": Vector2i(-2, 1),
	},
	"cultivation": {
		"display_name": "Cultivation",
		"type": "cultivation",
		"coord": Vector2i(0, 2),
	},
	"guild": {
		"display_name": "Guild",
		"type": "guild",
		"coord": Vector2i(2, -1),
	},
	"advancement": {
		"display_name": "Trainer Advancement",
		"type": "advancement",
		"coord": Vector2i(-2, 0),
	},
	"release_adopt": {
		"display_name": "Release / Adopt",
		"type": "release_adopt",
		"coord": Vector2i(0, -2),
	},
}
## 主世界 hex 网格 wrapper(占用 / 寻路 / 重定向)。Logic 层持有(grid 无 UI 依赖)。
var overworld_grid: InkMonWorldGrid = null
## 与玩家相邻(axial 距离 ≤1)的 NPC id;玩家移动后重算,"" = 无邻近。
var near_npc_id: String = ""
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
	player_actor.bag_container_id = _register_container(&"bag")
	roster.clear()
	for unit_key in InkMonUnitConfig.get_default_roster(0):
		_add_roster_unit_from_config(str(unit_key))
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
	_ensure_started()
	_reset_item_runtime()
	var player_data := data.get("player", {}) as Dictionary
	player_actor = InkMonPlayerActor.from_dict(player_data if player_data != null else {})
	if not player_actor.hex_position.is_valid():
		player_actor.hex_position = HexCoord.new(0, 0)
	player_actor.bag_container_id = _register_container(&"bag")
	_restore_container_items(player_actor.bag_container_id, (player_data if player_data != null else {}).get("bag", []))
	roster.clear()
	var roster_data := data.get("roster", []) as Array
	if roster_data != null:
		for unit_value in roster_data:
			var unit_data := unit_value as Dictionary
			if unit_data != null:
				_add_roster_unit_from_save(unit_data)
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
	return {
		"version": SAVE_VERSION,
		"player": player_actor.to_dict() if player_actor != null else {},
		"roster": roster_data,
	}


# === 物品 / 容器 / roster 装配 (adr/0001) ===

## 重置 ItemSystem session + 装 inkmon 物品域 (new_game / from_dict 起手)。
func _reset_item_runtime() -> void:
	ItemSystem.reset_session()
	ItemSystem.configure_domain(InkMonItemDomain.new(), InkMonItemCatalog.new())


## 注册一个 ItemSystem 容器, 返回 runtime 容器 id (>0)。容器 id 不进存档, 每次 load 重建。
func _register_container(container_name: StringName, capacity: int = -1) -> int:
	var container := BaseContainer.new()
	container.container_name = container_name
	container.space_config = ContainerSpaceConfig.create_unordered(capacity)
	var cid := ItemSystem.register_container(container)
	Log.assert_crash(cid > 0, "InkMonWorldGI", "failed to register container: %s" % str(container_name))
	return cid


## 把存档物品快照还原进容器 (config_id/count/slot_index)。
func _restore_container_items(container_id: int, items: Variant) -> void:
	var item_list := items as Array
	if item_list == null:
		return
	for item_value in item_list:
		var item := item_value as Dictionary
		if item == null:
			continue
		var config_id := StringName(str(item.get("config_id", "")))
		if config_id == &"":
			continue
		var result := ItemSystem.create_item(
			container_id, config_id, int(item.get("count", 1)), int(item.get("slot_index", -1)))
		Log.assert_crash(result.success, "InkMonWorldGI",
			"failed to restore item %s: %s" % [str(config_id), result.error_message])


## 默认队伍单位 (新游戏): 从 UnitConfig 建活 actor + 注册装备容器, 再按 SpeciesCatalog 统一重算派生六维
## (满血)。base 源与读档路径一致 (都走 SpeciesCatalog.get_base_stats), 避免 new-game 态与 reload 态数值漂移;
## stub 物种 catalog fallback 回 UnitConfig, 数值不变 (M1 平衡保持)。
func _add_roster_unit_from_config(unit_key: String) -> InkMonUnitActor:
	var actor := InkMonUnitActor.new(unit_key)
	add_actor(actor)
	actor.equipment_container_id = _register_container(StringName("equip:%s" % actor.get_id()))
	actor.restore_persistent_state(InkMonSpeciesCatalog.get_base_stats(actor.species), -1.0)
	roster.append(actor)
	return actor


## 读档单位: 从持久切片建活 actor + 注册装备容器 + 还原装备物品 + 重算派生六维与 carryover HP + 入 roster/registry。
func _add_roster_unit_from_save(unit_data: Dictionary) -> InkMonUnitActor:
	var actor := InkMonUnitActor.from_dict(unit_data)
	add_actor(actor)
	actor.equipment_container_id = _register_container(StringName("equip:%s" % actor.get_id()))
	_restore_container_items(actor.equipment_container_id, unit_data.get("equipment", []))
	actor.restore_persistent_state(
		InkMonSpeciesCatalog.get_base_stats(actor.species), float(unit_data.get("hp", -1.0)))
	roster.append(actor)
	return actor


## 在玩家 bag 容器建物品 (shop 购买入袋)。供 NPC handler / UI 调。
func create_bag_item(config_id: StringName, count: int = 1, slot_index: int = -1) -> ItemCreateResult:
	Log.assert_crash(player_actor != null and player_actor.bag_container_id > 0,
		"InkMonWorldGI", "bag container not ready")
	return ItemSystem.create_item(player_actor.bag_container_id, config_id, count, slot_index)


## 领养 = 程序化出生 (from_birth 确定性 roll 技能槽) 建活 roster actor。供 release_adopt handler 调。
func adopt_unit(species_id: String, roll_seed: int) -> InkMonUnitActor:
	var data := {
		"species_id": species_id,
		"name_en": InkMonSpeciesCatalog.get_display_name(species_id),
		"stage": InkMonSpeciesCatalog.get_stage(species_id),
		"elements": InkMonSpeciesCatalog.get_elements(species_id),
		"level": 1,
		"exp": 0,
		"skill_slots": InkMonSpeciesCatalog.roll_birth_skill_slots(species_id, roll_seed),
		"engravings": [],
		"hp": -1.0,
	}
	var actor := InkMonUnitActor.from_dict(data)
	add_actor(actor)
	actor.equipment_container_id = _register_container(StringName("equip:%s" % actor.get_id()))
	actor.restore_persistent_state(InkMonSpeciesCatalog.get_base_stats(species_id), -1.0)
	roster.append(actor)
	return actor


## 重算某 roster actor 的派生六维 (cultivation 升级 / 进化 / 装备变更后调; species base 由 SpeciesCatalog 供)。
func refresh_unit_stats(actor: InkMonUnitActor) -> void:
	if actor == null:
		return
	actor.apply_derived_stats(InkMonSpeciesCatalog.get_base_stats(actor.species))


## 主世界运行时装配 (new_game / from_dict 共用): grid + npc handler + 放 occupant + 注册 world actor + systems。
func _setup_overworld_runtime() -> void:
	_build_npc_handlers()
	overworld_grid = InkMonWorldGrid.new()
	overworld_grid.setup(InkMonWorldGrid.MAP_RADIUS)
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
	while not _command_queue.is_empty():
		var command := _command_queue.pop_front() as InkMonWorldCommand
		if command != null:
			command.apply(self)


## command_applied 单一 emit 入口:buy/npc-action command apply 后把结果(含 message / flow intent)回流。
func emit_command_applied(result: Dictionary) -> void:
	command_applied.emit(result)


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
	for npc_id_value in npc_defs.keys():
		var npc_def := npc_defs[npc_id_value] as Dictionary
		var npc_coord := npc_def.get("coord", Vector2i.ZERO) as Vector2i
		if _axial_distance(player_coord, npc_coord) <= 1:
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


func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return int((abs(dq) + abs(dq + dr) + abs(dr)) / 2)


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
	_recording_enabled = false
	InkMonBattleSetup.configure_battle_grid(self, {})
	left_team = InkMonBattleSetup.battle_roster_slice(self)
	right_team = InkMonBattleSetup.build_training_dummies(self)
	_begin_battle_with_current_teams()


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


func remove_actor(actor_id: String) -> bool:
	var actor := super.get_actor(actor_id)
	if actor != null and actor is InkMonBattleActor:
		_clear_battle_grid_state(actor as InkMonBattleActor)
	return super.remove_actor(actor_id)


## 清一个 battle actor 在 grid 上的外部状态 (occupant + reservation), 不动 registry (P021)。
## remove_actor (整只移除) 与持久 roster actor 的战斗 teardown (留 registry) 共用此清理。
func _clear_battle_grid_state(battle_actor: InkMonBattleActor) -> void:
	if grid == null:
		return
	if battle_actor.hex_position != null and battle_actor.hex_position.is_valid():
		var occupant: Variant = grid.get_occupant(battle_actor.hex_position)
		# 守卫 occupant is InkMonBattleActor: 主世界 grid 的 occupant 是 string id, 直接 == Object 会报
		# Invalid operands; 且 reset-on-start 时 grid 已切回 overworld + actor 仍持上场 battle 坐标,
		# 故对 overworld grid 此处天然 no-op (battle grid 每场 reconfigure 重置占用)。
		if occupant is InkMonBattleActor and occupant == battle_actor:
			grid.remove_occupant(battle_actor.hex_position)
	for coord in InkMonBattleSetup.find_reservations_by(self, battle_actor.get_id()):
		grid.cancel_reservation(coord)


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


func get_result_summary() -> Dictionary:
	if _result == "":
		return {}
	var winner_team := "left" if _result == "left_win" else "right"
	return {
		"result": _result,
		"winner_team": winner_team,
		"source_team": "left",
		"reward_gold": WIN_REWARD_GOLD if winner_team == "left" else 0,
	}


## adr/0001:战斗结束直接把奖励落在活 actor 上 —— gold 加 player_actor, exp 加左队中属 roster 的活 actor。
## 无"摘要回写"(actor 即真相, HP 已在战斗中原地变)。返回结果摘要供表演展示。
func finalize_battle_rewards() -> Dictionary:
	var summary := get_result_summary()
	if summary.is_empty():
		return summary
	var winner_team := str(summary.get("winner_team", ""))
	if player_actor != null:
		player_actor.gold += maxi(0, int(summary.get("reward_gold", 0)))
	for actor in left_team:
		if not roster.has(actor):
			continue
		if actor.is_dead():
			actor.add_exp(LOSS_EXP)
		else:
			actor.add_exp(WIN_EXP if winner_team == "left" else LOSS_EXP)
	return summary


# === NPC 服务(P6 从 Host 内移;Logic 持有,Host 转发 UI 点击)===

## 6 个 handler 自含规则,收 GI 自身(读写 player_actor/roster);不碰 UI / flow。
func _build_npc_handlers() -> void:
	_npc_handlers = {
		"shop": InkMonShopNpcHandler.new("shop", "Shop"),
		"trainer": InkMonTrainingNpcHandler.new("trainer", "Training"),
		"cultivation": InkMonCultivationNpcHandler.new("cultivation", "Cultivation"),
		"guild": InkMonGuildNpcHandler.new("guild", "Guild"),
		"advancement": InkMonAdvancementNpcHandler.new("advancement", "Trainer Advancement"),
		"release_adopt": InkMonReleaseAdoptNpcHandler.new("release_adopt", "Release / Adopt"),
	}


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


func can_use_skill_on(actor: InkMonUnitActor, skill: Ability, target: InkMonBattleActor) -> bool:
	if actor == null or skill == null or target == null or target.is_dead():
		return false

	if target is InkMonUnitActor:
		var unit_target := target as InkMonUnitActor
		var same_team := actor.get_team_id() == unit_target.get_team_id()
		var is_self := actor.get_id() == unit_target.get_id()
		if skill.has_ability_tag("enemy") and same_team:
			return false
		if skill.has_ability_tag("ally") and not same_team:
			return false
		if skill.has_ability_tag("ally") and is_self and not skill.has_ability_tag("self"):
			return false

	var skill_range := skill.get_meta_int(InkMonSkillMetaKeys.RANGE, 1)
	if not actor.hex_position.is_valid() or not target.hex_position.is_valid():
		return false
	return actor.hex_position.distance_to(target.hex_position) <= skill_range


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
			_clear_battle_grid_state(actor)
			actor.reset_battle_runtime()
		else:
			remove_actor(aid)
	left_team.clear()
	right_team.clear()
	_ended = false
	_result = ""
	_final_replay_data = {}
	tick_count = 0
	damage_mod_seen = false


func _ensure_started() -> void:
	if get_state() == "created":
		super.start()
