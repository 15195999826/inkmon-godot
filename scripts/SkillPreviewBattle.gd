class_name SkillPreviewBattle
extends RefCounted
## 技能预览战斗
##
## 最小化战斗容器，用于技能编辑器的实时预览。
## _PreviewInstance: 自管 left_team / right_team / recorder, 不走 ATB/AI/procedure。
## - start() 承担全部初始化（地图/角色/投射物/录像）
## - run_preview() 只关注：编译 → 创建 → 施法 → 收集


## 安全上限，防止技能执行死循环
const MAX_TICKS := 500

## tick 时间步长（与 HexBattleProcedure 一致）
const TICK_INTERVAL := 100.0

## 技能执行完成后的额外等待帧数（等待投射物落地等）
const POST_EXECUTION_TICKS := 10


## 执行预览，返回结果 Dictionary
## 输入:
##   skill_source: GDScript 源码字符串
##   scene_config: 场景配置 Dictionary（来自 Web 端 JSON）
## 输出:
##   { "success": bool, "replay": Dictionary | null, "errors": Array[String] }
static func run_preview(skill_source: String, scene_config: Dictionary) -> Dictionary:
	var errors: Array[String] = []

	# ========== 1. 编译技能源码 ==========
	var compile_result := _compile_skill(skill_source)
	if compile_result.error != "":
		errors.append(compile_result.error)
		return _make_result(false, {}, errors)

	var ability_config: AbilityConfig = compile_result.ability_config
	var timeline_data: TimelineData = compile_result.timeline_data  # 可能为 null

	# ========== 2. 初始化 GameWorld ==========
	GameWorld.init()

	# ========== 3. 创建并启动 _PreviewInstance ==========
	var preview_config := {
		"map_config": _build_grid_config(scene_config.get("map", {})),
		"caster": scene_config.get("caster", {}),
		"dummies": scene_config.get("dummies", []),
	}

	var battle := GameWorld.create_instance(func() -> GameplayInstance:
		var inst := _PreviewInstance.new()
		inst.start(preview_config)
		return inst
	) as _PreviewInstance

	if battle == null:
		errors.append("Failed to create preview battle instance")
		GameWorld.destroy()
		return _make_result(false, {}, errors)

	# 如果技能自带 timeline，也注册
	if timeline_data != null:
		TimelineRegistry.register(timeline_data)

	# ========== 4. 注入技能给 caster ==========
	var caster: CharacterActor = battle.left_team[0]
	var skill_ability := Ability.new(ability_config, caster.get_id())
	caster.ability_set.grant_ability(skill_ability)

	# ========== 5. 解析目标并触发施法 ==========
	var dummy_actors: Array[CharacterActor] = []
	dummy_actors.assign(battle.right_team)

	var target_config: Dictionary = scene_config.get("target", { "mode": "auto" })
	var target_actor_id := _resolve_target(target_config, caster, dummy_actors)

	var activate_event := {
		"kind": GameEvent.ABILITY_ACTIVATE_EVENT,
		"abilityInstanceId": skill_ability.id,
		"sourceId": caster.get_id(),
		"logicTime": 0.0,
	}
	if target_actor_id != "":
		activate_event["target_actor_id"] = target_actor_id

	caster.ability_set.receive_event(activate_event, battle)

	# ========== 6. Tick loop ==========
	var tick_count := 0
	var post_execution_countdown := -1  # -1 表示技能仍在执行

	while tick_count < MAX_TICKS:
		tick_count += 1

		# tick ability systems
		for actor in battle.get_all_actors():
			actor.ability_set.tick(TICK_INTERVAL, battle.get_logic_time())
			actor.ability_set.tick_executions(TICK_INTERVAL, battle)

		# tick GameplayInstance（驱动 ProjectileSystem 等 systems）
		battle.tick(TICK_INTERVAL)

		# 收集事件
		var frame_events := GameWorld.event_collector.flush()
		battle.recorder.record_frame(tick_count, frame_events)

		# 检查技能是否执行完毕
		if post_execution_countdown < 0:
			var still_executing := false
			for ability in caster.ability_set.get_abilities():
				if ability.get_executing_instances().size() > 0:
					still_executing = true
					break
			if not still_executing:
				post_execution_countdown = POST_EXECUTION_TICKS
		else:
			post_execution_countdown -= 1
			if post_execution_countdown <= 0:
				break

	# ========== 7. 收集结果 ==========
	var end_reason := "preview_complete" if tick_count < MAX_TICKS else "timeout"
	var replay_data := battle.recorder.stop_recording(end_reason)

	GameWorld.destroy()

	if tick_count >= MAX_TICKS:
		errors.append("Preview timed out after %d ticks" % MAX_TICKS)

	return _make_result(true, replay_data, errors)


## 从已编译 AbilityConfig + 场景 dict 跑一次 preview，返回结构化结果
##
## 两类消费者共用:
##   - `tests/skill_scenarios/` scenario runner(自动断言)
##   - `scenes/SkillPreview.tscn` 开发者工具(UI 驱动 + replay 播放)
##
## scene_config 约定格式:
## [codeblock]
## {
##   "map": { "rows": int, "cols": int } | { "radius": int },
##   "caster": { "class": String, "pos": [q, r], "hp": float?, "atk": float? },
##   "caster_passives": Array[AbilityConfig],
##   "allies":  [{ "class": ..., "pos": [q, r], "hp": float? }, ...],
##   "enemies": [{ "class": ..., "pos": [q, r], "hp": float? }, ...],
##   "target":  { "mode": "auto"|"enemy_index"|"ally_index"|"fixed_pos", "index": int?, "pos": [q,r]? }
## }
## [/codeblock]
##
## 返回:
## [codeblock]
## {
##   "success": bool,
##   "replay":    Dictionary,       # BattleRecorder.stop_recording 产出，供 BattleReplayScene.load_replay 使用
##   "caster_id": String,
##   "ally_ids":  Array[String],    # 不含 caster
##   "enemy_ids": Array[String],
##   "errors":    Array[String],
## }
## [/codeblock]
static func run_with_config(
	ability_config: AbilityConfig,
	scene_config: Dictionary,
	max_ticks: int = MAX_TICKS
) -> Dictionary:
	if ability_config == null:
		return _empty_result(["ability_config is null"])
	# 单步 shim：caster 施放 ability_config,target 来自 scene_config.target(默认 auto)
	var target_cfg: Dictionary = scene_config.get("target", {"mode": "auto"})
	var target_ref := _target_cfg_to_ref(target_cfg)
	var actions: Array[Dictionary] = [{
		"caster": "caster",
		"skill": ability_config,
		"target": target_ref,
	}]
	return run_with_actions(scene_config, actions, max_ticks)


## 多步 action 序列版本。一个 action 描述 "谁施放什么技能打谁"。
##
## 适合:反伤/尸爆等被动触发场景(让 enemy 来施放 Strike 打 caster)、多单位协同场景。
##
## action 字典格式:
## [codeblock]
## {
##   "caster": "caster" | "ally_<N>" | "enemy_<N>",  # 默认 "caster"
##   "skill":  AbilityConfig,                         # 必填
##   "target": "auto" | "caster" | "ally_<N>" | "enemy_<N>",  # 默认 "auto"
## }
## [/codeblock]
##
## 所有 actions 在 tick 开始前**一次性 grant + activate**(等价于多个施法者同帧动手)。
## 返回结构与 run_with_config 相同。
static func run_with_actions(
	scene_config: Dictionary,
	actions: Array[Dictionary],
	max_ticks: int = MAX_TICKS
) -> Dictionary:
	var errors: Array[String] = []

	GameWorld.init()

	var preview_config := _build_preview_config(scene_config)
	var battle := GameWorld.create_instance(func() -> GameplayInstance:
		var inst := _PreviewInstance.new()
		inst.start(preview_config)
		return inst
	) as _PreviewInstance

	if battle == null:
		GameWorld.destroy()
		return _empty_result(["Failed to create preview battle instance"])

	var caster: CharacterActor = battle.left_team[0]
	var ally_actors: Array[CharacterActor] = []
	var enemy_actors: Array[CharacterActor] = []
	for actor in battle.right_team:
		if actor.get_team_id() == caster.get_team_id():
			ally_actors.append(actor as CharacterActor)
		else:
			enemy_actors.append(actor as CharacterActor)

	# Grant caster 的 passives(只挂 caster,需要挂其他 actor 的被动请用 actor_passives 扩展)
	var passives: Array = scene_config.get("caster_passives", [])
	for passive_config in passives:
		if passive_config is AbilityConfig:
			var passive_ability := Ability.new(passive_config, caster.get_id())
			caster.ability_set.grant_ability(passive_ability, battle)

	# 依次 grant + activate 所有 actions
	for action in actions:
		var caster_ref := str(action.get("caster", "caster"))
		var skill_config := action.get("skill") as AbilityConfig
		var target_ref := str(action.get("target", "auto"))
		if skill_config == null:
			errors.append("action missing skill AbilityConfig: %s" % str(action))
			continue
		var action_caster := _resolve_actor_ref(caster_ref, caster, ally_actors, enemy_actors)
		if action_caster == null:
			errors.append("action caster ref unresolved: %s" % caster_ref)
			continue
		var action_ability := Ability.new(skill_config, action_caster.get_id())
		action_caster.ability_set.grant_ability(action_ability, battle)
		var action_target_id := _resolve_target_ref(target_ref, action_caster, caster, ally_actors, enemy_actors)
		var activate_event := {
			"kind": GameEvent.ABILITY_ACTIVATE_EVENT,
			"abilityInstanceId": action_ability.id,
			"sourceId": action_caster.get_id(),
			"logicTime": 0.0,
		}
		if action_target_id != "":
			activate_event["target_actor_id"] = action_target_id
		action_caster.ability_set.receive_event(activate_event, battle)

	# Tick 循环
	var tick_count := 0
	var post_execution_countdown := -1
	while tick_count < max_ticks:
		tick_count += 1
		for actor in battle.get_all_actors():
			actor.ability_set.tick(TICK_INTERVAL, battle.get_logic_time())
			actor.ability_set.tick_executions(TICK_INTERVAL, battle)
		battle.tick(TICK_INTERVAL)
		var frame_events := GameWorld.event_collector.flush()
		battle.recorder.record_frame(tick_count, frame_events)

		if post_execution_countdown < 0:
			# 判定"结束":
			#   1. 所有 CharacterActor 的 ability 都没有 executing instance(cover DOT/HOT loop)
			#   2. 场上没有飞行中的 projectile(cover 投射物命中前的飞行阶段)
			# 用 battle.get_actors() (registry) 而非 get_all_actors() (staging)
			var still_executing := false
			for actor in battle.get_actors():
				if actor is ProjectileActor:
					if (actor as ProjectileActor).is_flying():
						still_executing = true
						break
					continue
				if not (actor is CharacterActor):
					continue
				for ability in (actor as CharacterActor).ability_set.get_abilities():
					if ability.is_expired():
						continue
					if ability.get_executing_instances().size() > 0:
						still_executing = true
						break
				if still_executing:
					break
			if not still_executing:
				post_execution_countdown = POST_EXECUTION_TICKS
		else:
			post_execution_countdown -= 1
			if post_execution_countdown <= 0:
				break

	var end_reason := "preview_complete" if tick_count < max_ticks else "timeout"
	var replay_data := battle.recorder.stop_recording(end_reason)

	var caster_id := caster.get_id()
	var ally_ids: Array[String] = []
	for a in ally_actors:
		ally_ids.append(a.get_id())
	var enemy_ids: Array[String] = []
	for e in enemy_actors:
		enemy_ids.append(e.get_id())

	# grant/revoke 不经 event_collector,在 destroy 前抓 ability 状态 + hp 快照
	var final_ability_states: Dictionary = {}
	var final_actor_hps: Dictionary = {}
	for actor in battle.get_all_actors():
		if not (actor is CharacterActor):
			continue
		var c_actor := actor as CharacterActor
		var config_ids: Array[String] = []
		for ability in c_actor.ability_set.get_abilities():
			if not ability.is_expired():
				config_ids.append(ability.config_id)
		final_ability_states[c_actor.get_id()] = config_ids
		final_actor_hps[c_actor.get_id()] = c_actor.attribute_set.hp

	# 死者也加到 final_actor_hps(check_death 会 remove_actor,得从 ally/enemy_ids 补)
	for aid in ally_ids + enemy_ids + [caster_id]:
		if not final_actor_hps.has(aid):
			final_actor_hps[aid] = 0.0

	GameWorld.destroy()

	if tick_count >= max_ticks:
		errors.append("Preview timed out after %d ticks" % max_ticks)

	return {
		"success": errors.is_empty(),
		"replay": replay_data,
		"caster_id": caster_id,
		"ally_ids": ally_ids,
		"enemy_ids": enemy_ids,
		"final_ability_states": final_ability_states,
		"final_actor_hps": final_actor_hps,
		"errors": errors,
	}


static func _empty_result(errs: Array) -> Dictionary:
	var typed_errs: Array[String] = []
	for e in errs:
		typed_errs.append(str(e))
	return {
		"success": false,
		"replay": {},
		"caster_id": "",
		"ally_ids": [] as Array[String],
		"enemy_ids": [] as Array[String],
		"final_ability_states": {},
		"final_actor_hps": {},
		"errors": typed_errs,
	}


## 把 scene_config.target dict 转成 action target_ref 字符串
static func _target_cfg_to_ref(target_cfg: Dictionary) -> String:
	var mode: String = target_cfg.get("mode", "auto")
	match mode:
		"enemy_index":
			return "enemy_%d" % int(target_cfg.get("index", 0))
		"ally_index":
			return "ally_%d" % int(target_cfg.get("index", 0))
		_:
			return "auto"


## 解析 actor ref ("caster" / "ally_N" / "enemy_N") → 具体 CharacterActor
static func _resolve_actor_ref(
	ref: String,
	caster: CharacterActor,
	ally_actors: Array[CharacterActor],
	enemy_actors: Array[CharacterActor]
) -> CharacterActor:
	if ref == "caster":
		return caster
	if ref.begins_with("ally_"):
		var idx := int(ref.substr(5))
		if idx >= 0 and idx < ally_actors.size():
			return ally_actors[idx]
	if ref.begins_with("enemy_"):
		var idx := int(ref.substr(6))
		if idx >= 0 and idx < enemy_actors.size():
			return enemy_actors[idx]
	return null


## 解析 target ref → actor id 字符串("auto" 相对于 action 施法者找最近敌人)
static func _resolve_target_ref(
	ref: String,
	action_caster: CharacterActor,
	scene_caster: CharacterActor,
	ally_actors: Array[CharacterActor],
	enemy_actors: Array[CharacterActor]
) -> String:
	if ref == "auto":
		# action_caster 的敌方列表 = 所有非同队
		var candidates: Array[CharacterActor] = []
		for a in [scene_caster] + ally_actors + enemy_actors:
			if a.get_team_id() != action_caster.get_team_id():
				candidates.append(a)
		var best: CharacterActor = null
		var best_dist: int = 999999
		for c in candidates:
			var dist := action_caster.hex_position.distance_to(c.hex_position)
			if dist < best_dist:
				best_dist = dist
				best = c
		return best.get_id() if best != null else ""
	var resolved := _resolve_actor_ref(ref, scene_caster, ally_actors, enemy_actors)
	return resolved.get_id() if resolved != null else ""


static func _build_preview_config(scene_config: Dictionary) -> Dictionary:
	var map_cfg: Dictionary = scene_config.get("map", {"rows": 5, "cols": 5})
	var grid_config := GridMapConfig.new()
	grid_config.grid_type = GridMapConfig.GridType.HEX
	grid_config.size = map_cfg.get("size", 10.0) as float
	# 读 orientation, 默认 FLAT。接受 string ("flat"/"pointy") 或 enum int。
	var orient_val: Variant = map_cfg.get("orientation", "flat")
	if orient_val is String:
		grid_config.orientation = (
			GridMapConfig.Orientation.POINTY if (orient_val as String) == "pointy"
			else GridMapConfig.Orientation.FLAT
		)
	else:
		grid_config.orientation = int(orient_val) as GridMapConfig.Orientation
	if map_cfg.has("radius"):
		grid_config.draw_mode = GridMapConfig.DrawMode.RADIUS
		grid_config.radius = map_cfg.get("radius") as int
	else:
		grid_config.draw_mode = GridMapConfig.DrawMode.ROW_COLUMN
		grid_config.rows = map_cfg.get("rows", 5) as int
		grid_config.columns = map_cfg.get("cols", map_cfg.get("columns", 5)) as int

	var caster_src: Dictionary = scene_config.get("caster", {})
	var caster_cfg := _actor_src_to_preview_cfg(caster_src)

	var dummies_cfg: Array = []
	var allies: Array = scene_config.get("allies", [])
	for i in range(allies.size()):
		var cfg := _actor_src_to_preview_cfg(allies[i] as Dictionary)
		cfg["team"] = "A"  # 与 caster 同队
		cfg["id"] = "ally_%d" % i
		dummies_cfg.append(cfg)
	var enemies: Array = scene_config.get("enemies", [])
	for i in range(enemies.size()):
		var cfg := _actor_src_to_preview_cfg(enemies[i] as Dictionary)
		cfg["team"] = "B"
		cfg["id"] = "enemy_%d" % i
		dummies_cfg.append(cfg)

	return {"map_config": grid_config, "caster": caster_cfg, "dummies": dummies_cfg}


static func _actor_src_to_preview_cfg(src: Dictionary) -> Dictionary:
	var pos_val: Variant = src.get("pos", [0, 0])
	var q := 0
	var r := 0
	if pos_val is Array and (pos_val as Array).size() >= 2:
		q = (pos_val as Array)[0] as int
		r = (pos_val as Array)[1] as int
	var attrs: Dictionary = {}
	if src.has("hp"):
		attrs["hp"] = src.get("hp")
		attrs["max_hp"] = src.get("hp")
	if src.has("atk"):
		attrs["atk"] = src.get("atk")
	return {
		"class": src.get("class", "WARRIOR"),
		"position": {"q": q, "r": r},
		"attributes": attrs,
	}


static func _resolve_target_v2(
	target_cfg: Dictionary,
	caster: CharacterActor,
	ally_actors: Array[CharacterActor],
	enemy_actors: Array[CharacterActor]
) -> String:
	var mode: String = target_cfg.get("mode", "auto")

	if mode == "enemy_index":
		var idx: int = target_cfg.get("index", 0) as int
		if idx >= 0 and idx < enemy_actors.size():
			return enemy_actors[idx].get_id()
		return ""

	if mode == "ally_index":
		var idx: int = target_cfg.get("index", 0) as int
		if idx >= 0 and idx < ally_actors.size():
			return ally_actors[idx].get_id()
		return ""

	if mode == "fixed_pos":
		var pos_val: Variant = target_cfg.get("pos", [0, 0])
		if pos_val is Array and (pos_val as Array).size() >= 2:
			var target_coord := HexCoord.new((pos_val as Array)[0] as int, (pos_val as Array)[1] as int)
			var best_actor: CharacterActor = null
			var best_fixed_dist: int = 999999
			for actor in enemy_actors + ally_actors:
				var dist := actor.hex_position.distance_to(target_coord)
				if dist < best_fixed_dist:
					best_fixed_dist = dist
					best_actor = actor
			if best_actor != null:
				return best_actor.get_id()
		return ""

	# mode == "auto":最近敌人
	var best_enemy: CharacterActor = null
	var best_auto_dist: int = 999999
	for enemy in enemy_actors:
		var dist := caster.hex_position.distance_to(enemy.hex_position)
		if dist < best_auto_dist:
			best_auto_dist = dist
			best_enemy = enemy
	if best_enemy != null:
		return best_enemy.get_id()
	if enemy_actors.size() > 0:
		return enemy_actors[0].get_id()
	return ""


# ========== 内部 Battle Instance ==========

## web 桥接 godot_preview_skill 的轻量 world instance: 自拼 grid/projectile/actor/
## recorder, 不走 procedure 的 ATB/AI/队伍流程。addon 编辑器场景对应类是
## SkillPreviewWorldGI(独立实现, 含 reset/queue_preview)。
class _PreviewInstance extends HexWorldGameplayInstance:

	## SkillPreviewBattle 外部直接读 battle.left_team[0] / battle.right_team。
	var left_team: Array[CharacterActor] = []
	var right_team: Array[CharacterActor] = []

	## 不走 procedure 路径, 自管。
	var recorder: BattleRecorder = null

	var _projectile_system: ProjectileSystem = null

	func _init() -> void:
		super._init(IdGenerator.generate("preview"))
		type = "skill_preview"

	## 承担全部初始化：地图/投射物/timeline/角色/录像
	func start(config: Dictionary = {}) -> void:
		_state = "running"

		# 地图
		var grid_config: GridMapConfig = config.get("map_config")
		if grid_config != null:
			UGridMap.configure(grid_config)

		# 投射物系统
		var collision_detector := MobaCollisionDetector.new()
		_projectile_system = ProjectileSystem.new(
			collision_detector, GameWorld.event_collector, false
		)
		add_system(_projectile_system)

		# Timeline 注册
		HexBattleAllSkills.register_all_timelines()

		# 创建角色 → 放入 left_team / right_team
		var caster_cfg: Dictionary = config.get("caster", {})
		var dummies_cfg: Array = config.get("dummies", [])

		var caster := _create_actor(caster_cfg, 0, "caster")
		left_team = [caster]

		for i in range(dummies_cfg.size()):
			var dcfg: Dictionary = dummies_cfg[i]
			var team_int := 1 if dcfg.get("team", "B") == "B" else 0
			var did: String = dcfg.get("id", "dummy_%d" % (i + 1))
			var dummy := _create_actor(dcfg, team_int, did)
			right_team.append(dummy)

		# 录像
		recorder = BattleRecorder.new({
			"battleId": id,
			"tickInterval": int(SkillPreviewBattle.TICK_INTERVAL),
		})
		var replay_map_config: Dictionary = {}
		if UGridMap.model != null:
			replay_map_config = UGridMap.model.to_config_dict()
		var all_actors: Array[CharacterActor] = []
		all_actors.append_array(left_team)
		all_actors.append_array(right_team)
		recorder.start_recording(all_actors, {
			"positionFormats": { "Character": "hex" }
		}, replay_map_config)

	func _create_actor(cfg: Dictionary, team_id: int, id_hint: String) -> CharacterActor:
		var class_str: String = cfg.get("class", "WARRIOR")
		var char_class := HexBattleClassConfig.string_to_class(class_str)
		var actor := CharacterActor.new(char_class)
		actor._display_name = cfg.get("displayName", id_hint)
		add_actor(actor)
		actor.set_team_id(team_id)
		# 属性
		var attrs: Dictionary = cfg.get("attributes", {})
		var max_hp: float = attrs.get("maxHp", attrs.get("max_hp", 100.0)) as float
		actor.attribute_set.set_max_hp_base(max_hp)
		actor.attribute_set.set_hp_base(attrs.get("hp", max_hp) as float)
		if attrs.has("atk"):
			actor.attribute_set.set_atk_base(attrs.get("atk") as float)
		# 位置
		var pos: Dictionary = cfg.get("position", {})
		var coord := HexCoord.new(pos.get("q", 0) as int, pos.get("r", 0) as int)
		if UGridMap.model.has_tile(coord):
			UGridMap.model.place_occupant(coord, actor)
		actor.hex_position = coord.duplicate()
		return actor

	## projectile_hit 必须从 event_collector 广播出去, 否则 Fireball/PreciseShot
	## 的 ActivateInstanceConfig(trigger=PROJECTILE_HIT_EVENT) 收不到事件。
	func tick(dt: float) -> void:
		base_tick(dt)
		broadcast_projectile_events()

	## 走 left_team + right_team staging, 不走 actor registry。
	func get_all_actors() -> Array[CharacterActor]:
		var result: Array[CharacterActor] = []
		result.append_array(left_team)
		result.append_array(right_team)
		return result

	func get_alive_actors() -> Array[CharacterActor]:
		var result: Array[CharacterActor] = []
		for actor in get_all_actors():
			if not actor.is_dead():
				result.append(actor)
		return result


# ========== 私有辅助方法 ==========

## 编译技能源码，返回 AbilityConfig 和可选的 TimelineData
static func _compile_skill(source_code: String) -> Dictionary:
	var result := { "ability_config": null, "timeline_data": null, "error": "" }

	# 编译 GDScript
	var script := GDScript.new()
	script.source_code = source_code
	var err := script.reload()
	if err != OK:
		result.error = "GDScript compilation failed (error code: %d)" % err
		return result

	# 检查 create_ability_config 方法
	var has_method := false
	for method in script.get_script_method_list():
		if method.name == "create_ability_config":
			has_method = true
			break
	if not has_method:
		result.error = "Missing required method: create_ability_config()"
		return result

	# 执行 create_ability_config()
	var instance = script.new()
	if instance == null:
		result.error = "Failed to instantiate script"
		return result

	var config = instance.call("create_ability_config")
	if config == null:
		result.error = "create_ability_config() returned null"
		return result
	if not (config is AbilityConfig):
		result.error = "create_ability_config() must return AbilityConfig, got: %s" % str(typeof(config))
		return result

	result.ability_config = config

	# 尝试获取 timeline（可选）
	var has_timeline := false
	for method in script.get_script_method_list():
		if method.name == "create_timeline":
			has_timeline = true
			break
	if has_timeline:
		var timeline = instance.call("create_timeline")
		if timeline != null and timeline is TimelineData:
			result.timeline_data = timeline

	return result


## 构建 GridMapConfig（从 Web 端 scene_config.map 转换）
static func _build_grid_config(map_config: Dictionary) -> GridMapConfig:
	var config := GridMapConfig.new()
	config.grid_type = GridMapConfig.GridType.HEX
	config.draw_mode = GridMapConfig.DrawMode.RADIUS
	config.radius = map_config.get("radius", 3) as int
	var orientation_str: String = map_config.get("orientation", "pointy")
	if orientation_str == "flat":
		config.orientation = GridMapConfig.Orientation.FLAT
	else:
		config.orientation = GridMapConfig.Orientation.POINTY
	config.size = map_config.get("hexSize", 50.0) as float
	return config


## 解析目标配置，返回目标 actor ID
static func _resolve_target(
	target_config: Dictionary,
	caster: CharacterActor,
	dummy_actors: Array[CharacterActor],
) -> String:
	var mode: String = target_config.get("mode", "auto")

	if mode == "dummy":
		var dummy_id: String = target_config.get("dummyId", "")
		for dummy in dummy_actors:
			if dummy.get_id().ends_with(dummy_id) or dummy._display_name == dummy_id:
				return dummy.get_id()
		if dummy_actors.size() > 0:
			return dummy_actors[0].get_id()
		return ""

	if mode == "coordinate":
		var hex: Dictionary = target_config.get("hex", {})
		var target_q: int = hex.get("q", 0) as int
		var target_r: int = hex.get("r", 0) as int
		var target_coord := HexCoord.new(target_q, target_r)
		var best_dummy: CharacterActor = null
		var best_dist := 999999
		for dummy in dummy_actors:
			var dist := dummy.hex_position.distance_to(target_coord)
			if dist < best_dist:
				best_dist = dist
				best_dummy = dummy
		if best_dummy != null:
			return best_dummy.get_id()
		return ""

	# mode == "auto": 找最近的敌方 dummy
	var best_dummy: CharacterActor = null
	var best_dist := 999999
	for dummy in dummy_actors:
		if dummy.get_team_id() != caster.get_team_id():
			var dist := caster.hex_position.distance_to(dummy.hex_position)
			if dist < best_dist:
				best_dist = dist
				best_dummy = dummy
	if best_dummy == null and dummy_actors.size() > 0:
		best_dummy = dummy_actors[0]
	if best_dummy != null:
		return best_dummy.get_id()
	return ""


## 构造返回结果
static func _make_result(success: bool, replay: Dictionary, errors: Array[String]) -> Dictionary:
	return {
		"success": success,
		"replay": replay if not replay.is_empty() else null,
		"errors": errors,
	}
