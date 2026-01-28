## HexBattle - 六边形战斗实例
##
## 实现 ATB 战斗系统的主类
class_name HexBattle
extends GameplayInstance

# ========== 常量 ==========

const MAX_TICKS := 100


# ========== 属性 ==========

var tick_count: int = 0

## 地图（通过 UGridMap autoload 访问）
## 使用 UGridMap.model 获取当前地图实例
var grid: GridMapModel:
	get:
		return UGridMap.model

## 队伍
var left_team: Array[CharacterActor] = []
var right_team: Array[CharacterActor] = []

## 所有角色（ID -> Actor）- Dictionary 用于 O(1) 查找
var _actor_dict: Dictionary = {}

## 战斗是否结束
var _ended: bool = false

## 战斗日志管理器
var logger: HexBattleLogger

## 战斗录像器
var recorder: BattleRecorder

## 最终录像数据（战斗结束后可访问）
var _final_replay_data: Dictionary = {}

## 是否启用日志
var _logging_enabled: bool = true

## 是否启用录像
var _recording_enabled: bool = true


# ========== 初始化 ==========

func _init() -> void:
	super._init(IdGenerator.generate("battle"))
	type = "hex_battle"


## 开始战斗
## config 参数:
##   - logging: bool - 是否启用日志 (默认 true)
##   - recording: bool - 是否启用录像 (默认 true)
##   - console_log: bool - 是否输出到控制台 (默认 false)
##   - file_log: bool - 是否输出到文件 (默认 true)
##   - map_config: Dictionary - 地图配置，支持以下字段:
##       - draw_mode: "row_column" | "radius" (默认 "row_column")
##       - rows: int (默认 9)
##       - columns: int (默认 9)
##       - radius: int (默认 4，仅 radius 模式)
##       - hex_size: float (默认 10.0)
##       - orientation: "flat" | "pointy" (默认 "flat")
func start(config: Dictionary = {}) -> void:
	super.start()
	print("\n========== HexBattle 开始 ==========\n")
	
	# 确保 GameWorld 已初始化
	GameWorld.init()
	
	# 初始化日志和录像
	_logging_enabled = config.get("logging", true)
	_recording_enabled = config.get("recording", true)
	
	if _logging_enabled:
		logger = HexBattleLogger.new(id, {
			"console": config.get("console_log", false),  # 默认不输出到控制台（已有 print）
			"file": config.get("file_log", true),
		})
	
	if _recording_enabled:
		recorder = BattleRecorder.new({
			"battleId": id,
			"tickInterval": 100,
		})
	
	# 获取地图配置（支持外部传入或使用默认值）
	var map_config: Dictionary = config.get("map_config", {})
	var grid_config := _build_grid_config(map_config)
	
	# 创建地图
	UGridMap.configure_from_dict(grid_config)
	
	# 创建左方队伍
	left_team = [
		_create_actor(HexBattleClassConfig.CharacterClass.PRIEST),
		_create_actor(HexBattleClassConfig.CharacterClass.WARRIOR),
		_create_actor(HexBattleClassConfig.CharacterClass.ARCHER),
	]
	
	# 创建右方队伍
	right_team = [
		_create_actor(HexBattleClassConfig.CharacterClass.MAGE),
		_create_actor(HexBattleClassConfig.CharacterClass.BERSERKER),
		_create_actor(HexBattleClassConfig.CharacterClass.ASSASSIN),
	]
	
	# 设置队伍 ID
	for actor in left_team:
		actor.set_team_id(0)
	for actor in right_team:
		actor.set_team_id(1)
	
	# 装备技能
	for actor in get_all_actors():
		actor.equip_abilities()
	
	# 随机放置角色（根据地图大小动态计算放置区域）
	var placement_ranges := _calculate_placement_ranges(grid_config)
	_place_team_randomly(left_team, placement_ranges["left"])
	_place_team_randomly(right_team, placement_ranges["right"])
	
	# 给每个角色添加振奋 Buff
	_apply_inspire_buff_to_all()
	
	# 注册 Timeline
	_register_timelines()
	
	print("战斗开始")
	_print_battle_info()
	
	# 开始录像（传递地图配置和位置格式声明）
	if _recording_enabled and recorder != null:
		var replay_map_config: Dictionary = {}
		if UGridMap.model != null:
			replay_map_config = UGridMap.model.to_config_dict()
		var configs := {
			"positionFormats": {
				"Character": "hex",  # CharacterActor 的 position 是 hex 坐标
			}
		}
		recorder.start_recording(get_all_actors(), configs, replay_map_config)
	
	# 注册角色到日志
	if _logging_enabled and logger != null:
		for actor in get_all_actors():
			logger.register_actor(actor.get_id(), actor.get_display_name())


## 根据外部传入的地图配置构建 UGridMap 配置
func _build_grid_config(map_config: Dictionary) -> Dictionary:
	var draw_mode: String = map_config.get("draw_mode", "row_column")
	var hex_size: float = map_config.get("size", 10.0)
	var orientation: String = map_config.get("orientation", "flat")
	
	var grid_config := {
		"size": hex_size,
		"orientation": orientation,
	}
	
	if draw_mode == "radius":
		# Radius 模式
		var radius: int = map_config.get("radius", 4)
		grid_config["draw_mode"] = "radius"
		grid_config["radius"] = radius
	else:
		# Row/Column 模式（默认）
		var rows: int = map_config.get("rows", 9)
		var columns: int = map_config.get("columns", 9)
		grid_config["draw_mode"] = "row_column"
		grid_config["rows"] = rows
		grid_config["columns"] = columns
	
	return grid_config


## 根据地图配置计算队伍放置区域
func _calculate_placement_ranges(grid_config: Dictionary) -> Dictionary:
	var draw_mode: String = grid_config.get("draw_mode", "row_column")
	
	if draw_mode == "radius":
		# Radius 模式：左队在负 q 区域，右队在正 q 区域
		var radius: int = grid_config.get("radius", 4)
		var half := maxi(1, radius / 2)
		return {
			"left": { "q_min": -radius, "q_max": -1, "r_min": -half, "r_max": half },
			"right": { "q_min": 1, "q_max": radius, "r_min": -half, "r_max": half },
		}
	else:
		# Row/Column 模式：根据行列数计算
		var rows: int = grid_config.get("rows", 9)
		var columns: int = grid_config.get("columns", 9)
		
		# 计算中心偏移（row_column 模式的坐标范围）
		var half_rows := rows / 2
		var half_cols := columns / 2
		
		# 左队在左半边，右队在右半边
		var left_q_max := -1
		var left_q_min := -half_cols
		var right_q_min := 1
		var right_q_max := half_cols
		
		# r 范围取中间区域
		var r_range := maxi(1, half_rows / 2)
		
		return {
			"left": { "q_min": left_q_min, "q_max": left_q_max, "r_min": -r_range, "r_max": r_range },
			"right": { "q_min": right_q_min, "q_max": right_q_max, "r_min": -r_range, "r_max": r_range },
		}


func _create_actor(char_class: HexBattleClassConfig.CharacterClass) -> CharacterActor:
	var actor := CharacterActor.new(char_class)
	_actor_dict[actor.get_id()] = actor
	return actor


func _place_team_randomly(team: Array[CharacterActor], range_config: Dictionary) -> void:
	var available_coords: Array = []
	
	for q in range(range_config["q_min"], range_config["q_max"] + 1):
		for r in range(range_config["r_min"], range_config["r_max"] + 1):
			var coord := HexCoord.new(q, r)
			if UGridMap.model.has_tile(coord) and not UGridMap.model.is_occupied(coord):
				available_coords.append(coord)
	
	available_coords.shuffle()
	
	for i in range(mini(team.size(), available_coords.size())):
		var coord: HexCoord = available_coords[i]
		UGridMap.model.place_occupant(coord, team[i].to_ref())
		team[i].hex_position = coord.duplicate()


func _apply_inspire_buff_to_all() -> void:
	for actor in get_all_actors():
		var inspire_buff := Ability.new(HexBattleInspireBuff.INSPIRE_BUFF, actor.to_ref())
		actor.ability_set.grant_ability(inspire_buff)
		
		var current_def: float = actor.get_def()
		print("  %s 获得振奋 Buff: DEF %.0f -> %.0f (+%.0f)" % [
			actor.get_display_name(),
			current_def - HexBattleInspireBuff.INSPIRE_DEF_BONUS,
			current_def,
			HexBattleInspireBuff.INSPIRE_DEF_BONUS
		])


func _register_timelines() -> void:
	for timeline in HexBattleSkillTimelines.get_all_timelines():
		TimelineRegistry.register(timeline)


func _print_battle_info() -> void:
	print("\n角色信息:")
	print("-".repeat(70))
	
	for actor in get_all_actors():
		var pos = actor.hex_position
		var stats: Dictionary = actor.get_stats()
		var skill: Ability = actor.get_skill_ability()
		
		var team_label := "左方" if actor.get_team_id() == 0 else "右方"
		var pos_str := "(%d, %d)" % [pos.q, pos.r] if pos != null else "未放置"
		
		print("  [%s] %s (%s)" % [actor.get_id(), actor.get_display_name(), team_label])
		print("    位置: %s" % pos_str)
		print("    属性: HP=%.0f/%.0f ATK=%.0f DEF=%.0f SPD=%.0f" % [
			stats["hp"], stats["max_hp"], stats["atk"], stats["def"], stats["speed"]
		])
		print("    技能: %s" % (skill.display_name if skill != null else "无"))
		print("")
	
	print("-".repeat(70))


# ========== 查询方法 ==========

func get_all_actors() -> Array:
	var result: Array = []
	result.append_array(left_team)
	result.append_array(right_team)
	return result


func get_alive_actors() -> Array:
	var result: Array = []
	for actor in get_all_actors():
		if actor.is_active():
			result.append(actor)
	return result


## 重写父类方法，使用 Dictionary 实现 O(1) 查找
func get_actor(actor_id: String) -> CharacterActor:
	return _actor_dict.get(actor_id, null) as CharacterActor


## 重写父类方法，返回所有角色
func get_actors() -> Array:
	return _actor_dict.values()


func get_ability_set_for_actor(actor_id: String) -> BattleAbilitySet:
	var actor := get_actor(actor_id)
	if actor != null:
		return actor.ability_set
	return null


# ========== 战斗主循环 ==========

func tick(dt: float) -> void:
	base_tick(dt)
	
	if _ended:
		return
	
	tick_count += 1
	
	# 日志记录帧
	if _logging_enabled and logger != null:
		logger.tick(tick_count, _logic_time)
	
	for actor in get_alive_actors():
		actor.ability_set.tick(dt, _logic_time)
		
		if _is_actor_executing(actor):
			actor.ability_set.tick_executions(dt)
		else:
			actor.accumulate_atb(dt)
			
			if actor.can_act():
				_start_actor_action(actor)
	
	var frame_events: Array[Dictionary] = GameWorld.event_collector.flush()
	_process_frame_events(frame_events)
	
	# 录像记录帧
	if _recording_enabled and recorder != null:
		recorder.record_frame(tick_count, frame_events)
	
	if tick_count >= MAX_TICKS:
		print("\n战斗结束（达到最大回合数）")
		_end("timeout")
	elif _check_battle_end():
		pass  # _check_battle_end 内部会调用 _end


func _is_actor_executing(actor: CharacterActor) -> bool:
	for ability in actor.ability_set.get_abilities():
		if ability.get_executing_instances().size() > 0:
			return true
	return false


func _start_actor_action(actor: CharacterActor) -> void:
	print("\n[Tick %d] %s 准备行动 (ATB: %.1f)" % [tick_count, actor.get_display_name(), actor.get_atb_gauge()])
	
	# 记录角色获得行动机会
	if _logging_enabled and logger != null:
		logger.actor_ready(actor.get_id(), actor.get_display_name(), actor.get_atb_gauge())
	
	var decision := _decide_action(actor)
	
	if decision["type"] == "skip":
		print("  %s 无法行动，跳过本次决策" % actor.get_display_name())
		if _logging_enabled and logger != null:
			logger.ai_decision(actor.get_id(), actor.get_display_name(), "跳过（无可用行动）")
		actor.reset_atb()
		return
	
	var decision_text := ""
	if decision["type"] == "move":
		var coord = decision["target_coord"]
		decision_text = "移动到 (%d, %d)" % [coord.q, coord.r]
	else:
		var target_ref = decision.get("target", null)
		var target_id: String = target_ref.id if target_ref != null else ""
		var target_actor := get_actor(target_id)
		var target_name := target_actor.get_display_name() if target_actor != null else "未知"
		var skill := actor.get_skill_ability()
		var skill_name := skill.display_name if skill != null else "技能"
		decision_text = "%s -> %s" % [skill_name, target_name]
	
	print("  AI 决策: %s" % decision_text)
	
	# 记录 AI 决策
	if _logging_enabled and logger != null:
		logger.ai_decision(actor.get_id(), actor.get_display_name(), decision_text)
	
	var event := _create_action_use_event(
		decision["ability_instance_id"],
		actor.get_id(),
		decision.get("target", null),
		decision.get("target_coord", null)
	)
	
	actor.ability_set.receive_event(event, self)
	actor.reset_atb()


func _decide_action(actor: CharacterActor) -> Dictionary:
	var my_pos = actor.hex_position
	var enemies: Array = []
	var allies: Array = []
	
	for a in get_alive_actors():
		if a.get_team_id() != actor.get_team_id():
			enemies.append(a)
		elif a.get_id() != actor.get_id():
			allies.append(a)
	
	var skill := actor.get_skill_ability()
	var skill_ready := not actor.ability_set.is_on_cooldown(skill.config_id)
	var use_skill := skill_ready and randf() > 0.1
	
	if use_skill and enemies.size() > 0:
		var is_heal := skill.has_tag("ally")
		
		if is_heal and allies.size() > 0:
			var target_actor = allies[randi() % allies.size()]
			return {
				"type": "skill",
				"ability_instance_id": skill.id,
				"target": ActorRef.new(target_actor.get_id()),
			}
		else:
			var target_actor = enemies[randi() % enemies.size()]
			return {
				"type": "skill",
				"ability_instance_id": skill.id,
				"target": ActorRef.new(target_actor.get_id()),
			}
	else:
		if my_pos.is_valid():
			var neighbors: Array = my_pos.get_neighbors()
			var valid_neighbors: Array = []
			for n in neighbors:
				if UGridMap.model.has_tile(n) and not UGridMap.model.is_occupied(n) and not UGridMap.model.is_reserved(n):
					valid_neighbors.append(n)
			
			if valid_neighbors.size() > 0:
				var target_coord = valid_neighbors[randi() % valid_neighbors.size()]
				return {
					"type": "move",
					"ability_instance_id": actor.get_move_ability().id,
					"target_coord": target_coord,
				}
		
		if skill_ready and enemies.size() > 0:
			var target_actor = enemies[randi() % enemies.size()]
			return {
				"type": "skill",
				"ability_instance_id": skill.id,
				"target": ActorRef.new(target_actor.get_id()),
			}
		
		return { "type": "skip" }


func _create_action_use_event(ability_instance_id: String, source_id: String, target: ActorRef, target_coord: Variant) -> Dictionary:
	var event := {
		"kind": GameEvent.ABILITY_ACTIVATE_EVENT,
		"abilityInstanceId": ability_instance_id,
		"sourceId": source_id,
		"logicTime": _logic_time,  # 添加逻辑时间，避免框架尝试从 game_state_provider 获取
	}
	if target != null:
		event["target"] = target
	if target_coord != null and target_coord is HexCoord:
		# 转换为 Dictionary 以便 JSON 序列化
		event["target_coord"] = target_coord.to_dict()
	return event


func _process_frame_events(events: Array[Dictionary]) -> void:
	for event in events:
		var kind: String = event.get("kind", "")
		
		if kind == "damage":
			var source_id: String = event.get("source_actor_id", "")
			var target_id: String = event.get("target_actor_id", "")
			var damage: float = event.get("damage", 0.0)
			var damage_type: String = event.get("damage_type", "physical")
			var is_reflected: bool = event.get("is_reflected", false)
			var target_actor := get_actor(target_id)
			
			if target_actor != null:
				target_actor.modify_hp(-damage)
				print("  [伤害] %s 受到 %.0f 伤害, HP: %.0f" % [
					target_actor.get_display_name(), damage, target_actor.get_hp()
				])
				
				# 记录伤害
				if _logging_enabled and logger != null:
					logger.damage_dealt(source_id, target_id, damage, damage_type, is_reflected)
				
				if target_actor.check_death():
					print("  [死亡] %s 已阵亡" % target_actor.get_display_name())
					# 记录死亡
					if _logging_enabled and logger != null:
						logger.actor_died(target_id, source_id)
		
		elif kind == "heal":
			var source_id: String = event.get("source_actor_id", "")
			var target_id: String = event.get("target_actor_id", "")
			var heal_amount: float = event.get("heal_amount", 0.0)
			var target_actor := get_actor(target_id)
			
			if target_actor != null:
				var old_hp := target_actor.get_hp()
				var max_hp := target_actor.get_max_hp()
				var new_hp := minf(old_hp + heal_amount, max_hp)
				target_actor.set_hp(new_hp)
				print("  [治疗] %s 恢复 %.0f HP, HP: %.0f -> %.0f" % [
					target_actor.get_display_name(), heal_amount, old_hp, new_hp
				])
				
				# 记录治疗
				if _logging_enabled and logger != null:
					logger.heal_applied(source_id, target_id, heal_amount)
		
		elif kind == "move":
			var actor_id: String = event.get("actor_id", "")
			var from_hex: Dictionary = event.get("from_hex", {})
			var to_hex: Dictionary = event.get("to_hex", {})
			
			# 记录移动
			if _logging_enabled and logger != null and not from_hex.is_empty() and not to_hex.is_empty():
				logger.actor_moved(actor_id, from_hex, to_hex)


func _check_battle_end() -> bool:
	var left_alive := 0
	var right_alive := 0
	
	for actor in left_team:
		if actor.is_active():
			left_alive += 1
	
	for actor in right_team:
		if actor.is_active():
			right_alive += 1
	
	if left_alive == 0:
		print("\n战斗结束: 右方胜利!")
		_end("right_win")
		return true
	elif right_alive == 0:
		print("\n战斗结束: 左方胜利!")
		_end("left_win")
		return true
	
	return false


func _end(result: String = "") -> void:
	super.end()
	_ended = true
	print("\n========== HexBattle 结束 ==========")
	print("总帧数: %d" % tick_count)
	print("逻辑时间: %.1f ms" % _logic_time)
	
	# 保存日志
	if _logging_enabled and logger != null:
		logger.save()
	
	# 停止录像并保存
	if _recording_enabled and recorder != null:
		_final_replay_data = recorder.stop_recording(result)
		_save_replay(_final_replay_data)


func _save_replay(replay_data: Dictionary) -> void:
	if replay_data.is_empty():
		return
	
	# 保存到文件
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var replay_path := "user://Replays/battle_%s_%s.json" % [timestamp, id]
	
	# 确保目录存在
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("Replays"):
		dir.make_dir("Replays")
	
	var file := FileAccess.open(replay_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(replay_data, "\t"))
		file.close()
		print("📼 录像已保存到: %s" % replay_path)
	else:
		push_error("[HexBattle] 无法保存录像: %s" % replay_path)


## 获取录像数据（用于外部访问）
## 战斗进行中返回当前录像，战斗结束后返回最终录像
func get_replay_data() -> Dictionary:
	# 战斗结束后，返回保存的最终录像数据
	if not _final_replay_data.is_empty():
		return _final_replay_data
	# 战斗进行中，返回当前录像（会停止录像）
	if recorder != null and recorder.get_is_recording():
		return recorder.stop_recording()
	return {}


## 获取日志目录
func get_log_dir() -> String:
	if logger != null:
		return logger.get_battle_dir()
	return ""
