## HexBattle - 六边形战斗实例
##
## 实现 ATB 战斗系统的主类
class_name HexBattle
extends RefCounted


# ========== 常量 ==========

const MAX_TICKS := 100


# ========== 属性 ==========

var id: String
var logic_time: float = 0.0
var logicTime: float:
	get:
		return logic_time
var tick_count: int = 0

## 地图（通过 HexGrid autoload 访问）
## 使用 HexGrid.model 获取当前地图实例
var grid: HexGridWorld:
	get:
		return HexGrid.model

## 队伍
var left_team: Array = []
var right_team: Array = []

## 所有角色（ID -> Actor）
var _actors: Dictionary = {}

## 战斗是否结束
var _ended: bool = false

## 战斗日志管理器
var logger  # BattleLoggerClass instance

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
	id = IdGenerator.generate("battle")


## 开始战斗
func start(config: Dictionary = {}) -> void:
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
	
	# 创建地图（9x9 中心对称）
	HexGrid.configure_from_dict({
		"rows": 9,
		"columns": 9,
		"hex_size": 10.0,
		"orientation": "flat",
	})
	
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
	
	# 随机放置角色
	_place_team_randomly(left_team, { "q_min": -4, "q_max": -1, "r_min": -4, "r_max": -1 })
	_place_team_randomly(right_team, { "q_min": 1, "q_max": 4, "r_min": 1, "r_max": 4 })
	
	# 给每个角色添加振奋 Buff
	_apply_inspire_buff_to_all()
	
	# 注册 Timeline
	_register_timelines()
	
	print("战斗开始")
	_print_battle_info()
	
	# 开始录像（传递地图配置）
	if _recording_enabled and recorder != null:
		var map_config: Dictionary = {}
		if HexGrid.model != null:
			map_config = HexGrid.model.to_map_config()
		recorder.start_recording(get_all_actors(), {}, map_config)
	
	# 注册角色到日志
	if _logging_enabled and logger != null:
		for actor in get_all_actors():
			logger.register_actor(actor.get_id(), actor.get_display_name())


func _create_actor(char_class: HexBattleClassConfig.CharacterClass) -> CharacterActor:
	var actor := CharacterActor.new(char_class)
	_actors[actor.get_id()] = actor
	return actor


func _place_team_randomly(team: Array, range_config: Dictionary) -> void:
	var available_coords: Array = []
	
	for q in range(range_config["q_min"], range_config["q_max"] + 1):
		for r in range(range_config["r_min"], range_config["r_max"] + 1):
			var coord := { "q": q, "r": r }
			if HexGrid.model.has_tile_dict(coord) and not HexGrid.model.is_occupied_dict(coord):
				available_coords.append(coord)
	
	available_coords.shuffle()
	
	for i in range(mini(team.size(), available_coords.size())):
		var coord: Dictionary = available_coords[i]
		HexGrid.model.place_occupant_dict(coord, team[i].to_ref())
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
		var pos: Dictionary = actor.hex_position
		var stats: Dictionary = actor.get_stats()
		var skill: Ability = actor.get_skill_ability()
		
		var team_label := "左方" if actor.get_team_id() == 0 else "右方"
		var pos_str := "(%d, %d)" % [pos["q"], pos["r"]] if not pos.is_empty() else "未放置"
		
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


func get_actor(actor_id: String) -> CharacterActor:
	return _actors.get(actor_id, null)


func get_ability_set_for_actor(actor_id: String) -> BattleAbilitySet:
	var actor := get_actor(actor_id)
	if actor != null:
		return actor.ability_set
	return null


# ========== 战斗主循环 ==========

func tick(dt: float) -> void:
	if _ended:
		return
	
	logic_time += dt
	tick_count += 1
	
	# 日志记录帧
	if _logging_enabled and logger != null:
		logger.tick(tick_count, logic_time)
	
	for actor in get_alive_actors():
		actor.ability_set.tick(dt, logic_time)
		
		if _is_actor_executing(actor):
			actor.ability_set.tick_executions(dt)
		else:
			actor.accumulate_atb(dt)
			
			if actor.can_act():
				_start_actor_action(actor)
	
	var frame_events: Array = GameWorld.event_collector.flush()
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
		var coord: Dictionary = decision["target_coord"]
		decision_text = "移动到 (%d, %d)" % [coord["q"], coord["r"]]
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
	var my_pos: Dictionary = actor.hex_position
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
		if not my_pos.is_empty():
			var neighbors := HexGridCompat.hex_neighbors(my_pos)
			var valid_neighbors: Array = []
			for n in neighbors:
				if HexGrid.model.has_tile_dict(n) and not HexGrid.model.is_occupied_dict(n) and not HexGrid.model.is_reserved_dict(n):
					valid_neighbors.append(n)
			
			if valid_neighbors.size() > 0:
				var target_coord: Dictionary = valid_neighbors[randi() % valid_neighbors.size()]
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
		"logicTime": logic_time,  # 添加逻辑时间，避免框架尝试从 gameplay_state 获取
	}
	if target != null:
		event["target"] = target
	if target_coord is Dictionary and not target_coord.is_empty():
		event["target_coord"] = target_coord
	return event


func _process_frame_events(events: Array) -> void:
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
	_ended = true
	print("\n========== HexBattle 结束 ==========")
	print("总帧数: %d" % tick_count)
	print("逻辑时间: %.1f ms" % logic_time)
	
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
