class_name InkMonWorldGI
extends WorldGameplayInstance
## 主游戏唯一的、长命的 world GI (World-owns-Battle) —— Logic 层根。
##
## 承载世界运行时:session(存档根)+ 主世界 overworld grid + 玩家/NPC world actors +
## npc 表 + (战斗期) InkMonBattleProcedure。战斗是它内跑的短命 procedure, 不是独立 GI。
## 持两套 grid (第一版临时方案, docs/L2-ARCHITECTURE.md §1②):
##   - overworld_grid: 主世界 hex 网格 wrapper (InkMonWorldGrid; 玩家行走 + NPC occupant)
##   - battle grid: 战斗 hex 网格 (UGridMap.model, 每场战斗 configure)
## `grid` (基类字段) = 当前 active 的那套; start_battle_procedure 切到 battle, 战斗结束切回 overworld。
## overworld grid / move controller 是 Logic(无 UI 依赖),故住 Logic 层、归 GI 持有。
##
## 持久: Host 开机建一次, 不 per-battle create→destroy; 连续多场战斗复用同一实例
## (start_battle_procedure 内 reset-on-start 清上一场)。绝不在战斗结束 end() —— end() 单向销毁世界。
## lifecycle (save/load/reset/new-game) 由 Host 重建本实例驱动 (§0.5)。


## 上行信号:near_npc_id 真相变化时 emit(空 = 离开所有 NPC 邻域)。
## 移动 tick 内 refresh_near_npc 在 actor_position_changed 之后才跑,故表演不能挂位置信号刷 prompt
## (会读到陈旧 near);改挂本信号 —— emit 时 near_npc_id 已是新值。
signal near_npc_changed(near_npc_id: String)


## 单格步进时长(秒):tick 内 move_progress += dt/STEP_DURATION;与 View3D MOVE_STEP_DURATION
## 对齐 —— 逻辑每跨一格耗 STEP_DURATION 秒,view 补间同款时长 → 逻辑↔表演同步。
const STEP_DURATION := 0.22


var tick_count := 0
var left_team: Array[InkMonUnitActor] = []
var right_team: Array[InkMonUnitActor] = []
var damage_mod_seen := false
var overworld_grid_model: GridMapModel = null
## 主世界角色(玩家 + NPC)= InkMonWorldActor,key = "player" 或 npc_id。
## 战斗单位不进此表(走 left_team/right_team);这些只是世界态实体,战斗对其隐形
## (不 equip ability、不注册 event handler,故战斗 tick / event 广播都碰不到)。
var world_actors: Dictionary = {}

# === 主世界运行时(P3 从 Host 内移;Logic 层持有真相,Host 只 delegate)===
## 存档根 + 世界运行真相。Host(composition root)建好后交给 GI 持有(setup_overworld);
## Host 经只读 `session` getter 委托访问,不另存一份(单一所有权)。
var session: InkMonGameSession = null
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
## 主世界 command 队列(CQRS 写侧):UI enqueue → tick 的 CommandDrain System 抽干应用。
var _command_queue: Array[Dictionary] = []
## NPC 服务(P6 内移):6 个 handler,自含规则、收 GI 持有的 session;Host 只转发 UI 点击。
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


## P3: 主世界运行时一次性装配。Host(composition root)建好 GI 后调用 —— 把 session 交给 GI 持有,
## GI 据此建 overworld grid + 放 occupant + 注册玩家/NPC world actor + 接 move controller + 算邻近 NPC。
func setup_overworld(p_session: InkMonGameSession) -> void:
	_ensure_started()
	session = p_session
	_build_npc_handlers()
	overworld_grid = InkMonWorldGrid.new()
	overworld_grid.setup(InkMonWorldGrid.MAP_RADIUS)
	# load/new-game 侧:从 session 把玩家 + NPC 灌回 grid occupant(§3 单读不双写)。
	# actor 此刻未生成,hydrate 的 actor 同步被跳过;紧随的 _spawn_world_actors 据 grid 把玩家 actor 放对位。
	hydrate_from_session()
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


## CQRS 写侧:UI 把"移动玩家到目标格"意图入队(异步)。不立即移动 —— 下个 tick 的
## CommandDrain 抽干应用,Movement 逐格推进,经 actor_position_changed 回流给表演。
func enqueue_move_player(target_coord: Vector2i) -> void:
	_command_queue.append({"kind": "move_player", "target": target_coord})


## tick 第一阶段(CommandDrain System 调):抽干命令队列,应用为 world actor 移动意图。
func drain_commands() -> void:
	while not _command_queue.is_empty():
		var cmd := _command_queue.pop_front() as Dictionary
		if str(cmd.get("kind", "")) == "move_player":
			_apply_move_player_command(cmd.get("target", Vector2i.ZERO) as Vector2i)


## latest-wins(方案 A):新目标 → 走完正在进入的当前格(occupant 自然 flip 到 moving_to),
## moving_to 之后的旧路立即丢弃换 astar(moving_to, target);静止则从当前格起步。
func _apply_move_player_command(target_coord: Vector2i) -> void:
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


## 运行时玩家位置真相 = 主世界 grid 的 occupant(§3 不双写)。grid 未建时回退存档字段。
func get_player_coord() -> Vector2i:
	if overworld_grid != null:
		return overworld_grid.get_player_coord()
	return saved_player_coord()


## 存档字段里的玩家位置:只在 load 侧读(放 occupant)/ save 侧写,中间不双写(§3)。
func saved_player_coord() -> Vector2i:
	if session == null or session.player_state == null:
		return Vector2i.ZERO
	var coord := session.player_state.overworld.get("player_coord", {}) as Dictionary
	if coord == null:
		return Vector2i.ZERO
	return Vector2i(int(coord.get("q", 0)), int(coord.get("r", 0)))


## capture(save 侧,P7):把运行时世界态(玩家 occupant 位置)写回持有的 session 存档字段一次。
## 单写不双写(§3):移动期间绝不写 session,只有 capture(save 触发)写这一次。
func capture_to_session() -> void:
	if session == null or session.player_state == null:
		return
	var coord := get_player_coord()
	session.player_state.overworld["player_coord"] = {
		"q": coord.x,
		"r": coord.y,
	}


## hydrate(load/new-game 侧,P7):把 session 存档字段灌回运行时世界态 —— 玩家 + NPC occupant,
## 且玩家 actor hex_position 同步到存档坐标、清在途移动态。单读不双写(§3)。
## setup_overworld 内调用时玩家 actor 尚未 spawn(get_world_actor 返回 null,actor 同步跳过)。
func hydrate_from_session() -> void:
	if overworld_grid == null:
		return
	var coord := saved_player_coord()
	overworld_grid.sync_occupants(coord, npc_defs)
	var player := get_world_actor(InkMonWorldGrid.PLAYER_ID)
	if player != null:
		player.hex_position = HexCoord.new(coord.x, coord.y)
		player.moving_to = HexCoord.invalid()
		player.move_progress = 0.0
		player.pending_path = []


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


## 玩家 + 6 NPC 注册为 InkMonWorldActor 进本 GI registry(world actors 表)。
func _spawn_world_actors() -> void:
	spawn_world_actor(InkMonWorldGrid.PLAYER_ID, "Player", get_player_coord())
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
func start_battle_procedure(config: Dictionary = {}) -> void:
	_ensure_started()
	_reset_battle_state()
	_recording_enabled = config.get("recording", true)

	var grid_config := config.get("map_config", null) as GridMapConfig
	if grid_config == null:
		grid_config = _build_default_grid_config()
	configure_grid(grid_config)

	_setup_teams(config)
	for actor in get_all_units():
		actor.equip_abilities(self)
	_place_team_fixed(left_team, [
		HexCoord.new(-3, -1), HexCoord.new(-3, 0), HexCoord.new(-3, 1), HexCoord.new(-2, 0),
	])
	_place_team_fixed(right_team, [
		HexCoord.new(3, -1), HexCoord.new(3, 0), HexCoord.new(3, 1), HexCoord.new(2, 0),
	])

	InkMonAllSkills.register_all_timelines()

	var participants: Array[Actor] = []
	for actor in get_all_units():
		participants.append(actor)
	start_battle(participants)


## P5:在本 GI 内起一场 training 战斗(World-owns-Battle)。config 由 GI 自建 —— player roster
## 投影自持有的 session,敌方为训练假人;Host 只说"打 training",不再在 main 层拼 config。
func request_training_battle() -> void:
	start_battle_procedure({
		"recording": false,
		"left_roster_snapshots": session.project_player_battle_roster(4),
		"right_roster_snapshots": _build_training_enemy_snapshots(),
	})


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
		var battle_actor := actor as InkMonBattleActor
		if grid != null and battle_actor.hex_position != null and battle_actor.hex_position.is_valid():
			var occupant: Variant = grid.get_occupant(battle_actor.hex_position)
			if occupant == battle_actor:
				grid.remove_occupant(battle_actor.hex_position)
			for coord in _find_reservations_by(actor_id):
				grid.cancel_reservation(coord)
	return super.remove_actor(actor_id)


func get_actor(actor_id: String) -> InkMonBattleActor:
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
	var player_team := left_team
	var survivors := _source_entry_ids(player_team, false)
	var casualties := _source_entry_ids(player_team, true)
	return {
		"result": _result,
		"winner_team": winner_team,
		"source_team": "left",
		"survivors": survivors,
		"casualties": casualties,
		"per_entry": _per_entry_summary(player_team),
		"reward_gold": 25 if winner_team == "left" else 0,
	}


## P5:战斗结束把结果写回持有的 session(GI 持 session,结果应用内移)。返回结果摘要供表演展示。
func apply_battle_result() -> Dictionary:
	var result := get_result_summary()
	if session != null and session.player_state != null:
		session.player_state.apply_battle_result(result)
	return result


## 训练假人队(stub)。从 Host 内移 —— 战斗 config 由 GI 自建(它持 session + 战斗规则)。
func _build_training_enemy_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var skills := [
		InkMonStun.CONFIG_ID,
		InkMonFireball.CONFIG_ID,
		InkMonHolyHeal.CONFIG_ID,
		InkMonPoison.CONFIG_ID,
	]
	for i in range(4):
		result.append({
			"source_entry_id": 2000 + i,
			"species": "training_dummy_%d" % i,
			"role": InkMonUnitConfig.ROLE_DPS,
			"elements": [InkMonElementChart.WATER],
			"skill_slots": [{"slot_index": 0, "skill_id": skills[i]}],
			"battle_stats": {
				"max_hp": 30.0,
				"ad": 6.0,
				"ap": 6.0,
				"armor": 0.0,
				"mr": 0.0,
				"speed": 70.0,
			},
		})
	return result


# === NPC 服务(P6 从 Host 内移;Logic 持有,Host 转发 UI 点击)===

## 6 个 handler 自含规则,收 GI 持有的 session;不碰 UI / flow。
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


## Query(读):某 NPC 的可选 action 列表(表演据此建按钮,纯只读)。
func get_npc_actions(npc_id: String) -> Array:
	if not _npc_handlers.has(npc_id):
		return []
	return (_npc_handlers[npc_id] as InkMonNpcHandler).get_actions(session)


## 运行 NPC action:handler 收 GI 持有的 session 自含规则;返回结果
## (training 含 flow intent,Host 解释起战斗 —— 战斗 flow/app_state 归 Host)。
func run_npc_action(npc_id: String, action_id: String) -> Dictionary:
	if not _npc_handlers.has(npc_id):
		return {"ok": false, "message": "unknown NPC handler: %s" % npc_id}
	return (_npc_handlers[npc_id] as InkMonNpcHandler).run_action(action_id, session)


## 购买商店物品:规则住 shop handler,收 GI 持有的 session。
func buy_shop_item(config_id: StringName) -> Dictionary:
	var shop := _npc_handlers.get("shop", null) as InkMonShopNpcHandler
	if shop == null:
		return {"ok": false, "message": "shop handler not available"}
	return shop.buy(session, config_id)


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


## 清上一场战斗的 actor / handler / 状态, 让本实例可被下一场复用。
func _reset_battle_state() -> void:
	for actor in get_all_units():
		var aid := actor.get_id()
		if GameWorld.event_processor != null:
			GameWorld.event_processor.remove_handlers_by_owner_id(aid)
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


func _setup_teams(config: Dictionary) -> void:
	if config.has("left_roster_snapshots"):
		var left_snapshots := config.get("left_roster_snapshots", []) as Array
		Log.assert_crash(left_snapshots != null, "InkMonWorldGI", "left_roster_snapshots must be an Array")
		for snapshot in left_snapshots:
			left_team.append(_create_team_actor_from_snapshot(snapshot as Dictionary, 0))
	else:
		var left_roster: Array = config.get("left_roster", InkMonUnitConfig.get_default_roster(0))
		for key in left_roster:
			left_team.append(_create_team_actor(str(key), 0))

	if config.has("right_roster_snapshots"):
		var right_snapshots := config.get("right_roster_snapshots", []) as Array
		Log.assert_crash(right_snapshots != null, "InkMonWorldGI", "right_roster_snapshots must be an Array")
		for snapshot in right_snapshots:
			right_team.append(_create_team_actor_from_snapshot(snapshot as Dictionary, 1))
	else:
		var right_roster: Array = config.get("right_roster", InkMonUnitConfig.get_default_roster(1))
		for key in right_roster:
			right_team.append(_create_team_actor(str(key), 1))


func _create_team_actor(unit_key: String, team_id: int) -> InkMonUnitActor:
	var actor := InkMonUnitActor.new(unit_key)
	actor.set_team_id(team_id)
	return add_actor(actor) as InkMonUnitActor


func _create_team_actor_from_snapshot(snapshot: Dictionary, team_id: int) -> InkMonUnitActor:
	Log.assert_crash(snapshot != null, "InkMonWorldGI", "roster snapshot must be a Dictionary")
	var actor := InkMonUnitActor.from_battle_snapshot(snapshot)
	actor.set_team_id(team_id)
	return add_actor(actor) as InkMonUnitActor


func _source_entry_ids(team: Array[InkMonUnitActor], only_dead: bool) -> Array[int]:
	var result: Array[int] = []
	for actor in team:
		if actor.source_entry_id < 0:
			continue
		if actor.is_dead() == only_dead:
			result.append(actor.source_entry_id)
	return result


func _per_entry_summary(team: Array[InkMonUnitActor]) -> Dictionary:
	var result := {}
	for actor in team:
		if actor.source_entry_id < 0:
			continue
		result[actor.source_entry_id] = {
			"hp_remaining": actor.attribute_set.hp,
			"max_hp": actor.attribute_set.max_hp,
			"alive": not actor.is_dead(),
		}
	return result


func _place_team_fixed(team: Array[InkMonUnitActor], preferred_coords: Array[HexCoord]) -> void:
	var fallback := _available_coords()
	for i in range(team.size()):
		var coord := preferred_coords[i] if i < preferred_coords.size() else null
		if coord == null or not grid.has_tile(coord) or grid.is_occupied(coord):
			coord = _pop_first_available(fallback)
		if coord == null:
			continue
		grid.place_occupant(coord, team[i])
		team[i].hex_position = coord.duplicate()


func _available_coords() -> Array[HexCoord]:
	var result: Array[HexCoord] = []
	for coord in grid.get_all_coords():
		if grid.is_passable(coord) and not grid.is_reserved(coord):
			result.append(coord)
	result.sort_custom(func(a: HexCoord, b: HexCoord) -> bool:
		if a.q == b.q:
			return a.r < b.r
		return a.q < b.q
	)
	return result


func _pop_first_available(coords: Array[HexCoord]) -> HexCoord:
	while not coords.is_empty():
		var coord := coords.pop_front() as HexCoord
		if grid.has_tile(coord) and grid.is_passable(coord):
			return coord
	return null


func _find_reservations_by(actor_id: String) -> Array[HexCoord]:
	var result: Array[HexCoord] = []
	if grid == null:
		return result
	for coord in grid.get_all_coords():
		if grid.get_reservation(coord) == actor_id:
			result.append(coord)
	return result


func _build_default_grid_config() -> GridMapConfig:
	var config := GridMapConfig.new()
	config.grid_type = GridMapConfig.GridType.HEX
	config.draw_mode = GridMapConfig.DrawMode.RADIUS
	config.radius = 5
	config.size = 10.0
	config.orientation = GridMapConfig.Orientation.FLAT
	return config
