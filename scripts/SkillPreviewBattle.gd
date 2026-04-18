class_name SkillPreviewBattle
extends RefCounted
## 技能预览战斗
##
## 最小化战斗容器，用于技能编辑器的实时预览。
## _PreviewInstance 继承 HexBattle 并顺着其设计走：
## - 正确使用 left_team/right_team（无需重写 get_all_actors）
## - start() 承担全部初始化（地图/角色/投射物/录像）
## - run_preview() 只关注：编译 → 创建 → 施法 → 收集


## 安全上限，防止技能执行死循环
const MAX_TICKS := 500

## tick 时间步长（与 HexBattle 一致）
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


# ========== 内部 Battle Instance ==========

## 最小化 HexBattle 子类
## 正确使用 left_team/right_team，无需重写 get_all_actors 等查询方法
class _PreviewInstance extends HexBattle:

	func _init() -> void:
		super._init()  # HexBattle._init() → 生成 battle ID
		type = "skill_preview"

	## 承担全部初始化：地图/投射物/timeline/角色/录像
	## 跳过 HexBattle.start() 的 ATB/队伍/日志流程
	func start(config: Dictionary = {}) -> void:
		_state = "running"

		# 地图
		var grid_config: GridMapConfig = config.get("map_config")
		if grid_config != null:
			UGridMap.configure(grid_config)

		# 投射物系统
		var collision_detector := MobaCollisionDetector.new()
		projectile_system = ProjectileSystem.new(
			collision_detector, GameWorld.event_collector, false
		)
		add_system(projectile_system)

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
		recorder.start_recording(get_all_actors(), {
			"positionFormats": { "Character": "hex" }
		}, replay_map_config)

	func _create_actor(cfg: Dictionary, team_id: int, id_hint: String) -> CharacterActor:
		var actor := CharacterActor.new(HexBattleClassConfig.CharacterClass.WARRIOR)
		actor._display_name = cfg.get("displayName", id_hint)
		add_actor(actor)
		actor.set_team_id(team_id)
		# 属性
		var attrs: Dictionary = cfg.get("attributes", {})
		var max_hp: float = attrs.get("maxHp", attrs.get("max_hp", 100.0)) as float
		actor.attribute_set.set_max_hp_base(max_hp)
		actor.attribute_set.set_hp_base(attrs.get("hp", max_hp) as float)
		# 位置
		var pos: Dictionary = cfg.get("position", {})
		var coord := HexCoord.new(pos.get("q", 0) as int, pos.get("r", 0) as int)
		if UGridMap.model.has_tile(coord):
			UGridMap.model.place_occupant(coord, actor)
		actor.hex_position = coord.duplicate()
		return actor

	# tick 只驱动 base_tick（systems），不走 ATB/AI
	func tick(dt: float) -> void:
		base_tick(dt)


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
