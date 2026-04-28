## Smoke: SkillPreviewProcedure 单 actor 多 keyframe (合法间隔)
##
## 配置: caster t=0 / t=2100 / t=4200 三发 Strike → dummy
##   Strike occupy = max(timeline=500ms, cooldown=2000ms) = 2000ms
##   间隔 2100ms / 4200ms 都 > 2000ms, UI 会接受这个排布。
##
## 期望:
##   1. 3 条 damage 事件指向 dummy
##   2. caster 上只 grant 一个 Strike Ability instance —— 后两次 fire 复用 (去重 grant 后)
##   3. 3 个 executionActivated 事件 abilityInstanceId 全部相同
##
## 退出码: 0 PASS / 1 FAIL; 标记 "SMOKE_TEST_RESULT: PASS|FAIL - <reason>"
extends Node


const TIMEOUT_SEC := 30.0


var _world: SkillPreviewWorldGI
var _caster_id: String = ""
var _dummy_id: String = ""
var _elapsed: float = 0.0
var _finished: bool = false


func _ready() -> void:
	Log.set_level(Log.LogLevel.WARNING)
	print("=== Smoke: skill_preview proc multi-keyframe legal ===")

	GameWorld.init()
	_world = SkillPreviewWorldGI.new()
	GameWorld.create_instance(func() -> GameplayInstance: return _world)
	_world.start()
	_world.battle_finished.connect(_on_battle_finished)

	var cfg := GridMapConfig.new()
	cfg.grid_type = GridMapConfig.GridType.HEX
	cfg.draw_mode = GridMapConfig.DrawMode.RADIUS
	cfg.radius = 3
	cfg.orientation = GridMapConfig.Orientation.FLAT
	cfg.size = 1.0
	_world.configure_grid(cfg)

	var collision_detector := MobaCollisionDetector.new()
	_world.add_system(ProjectileSystem.new(collision_detector, GameWorld.event_collector, false))
	HexBattleAllSkills.register_all_timelines()

	var caster := CharacterActor.new(HexBattleClassConfig.CharacterClass.WARRIOR)
	caster._display_name = "caster"
	_world.add_actor(caster)
	caster.set_team_id(0)
	caster.attribute_set.set_max_hp_base(1000.0)
	caster.attribute_set.set_hp_base(1000.0)
	_world.grid.place_occupant(HexCoord.new(0, 0), caster)
	caster.hex_position = HexCoord.new(0, 0)

	var dummy := CharacterActor.new(HexBattleClassConfig.CharacterClass.WARRIOR)
	dummy._display_name = "dummy"
	_world.add_actor(dummy)
	dummy.set_team_id(1)
	dummy.attribute_set.set_max_hp_base(1000.0)
	dummy.attribute_set.set_hp_base(1000.0)
	_world.grid.place_occupant(HexCoord.new(1, 0), dummy)
	dummy.hex_position = HexCoord.new(1, 0)

	_caster_id = caster.get_id()
	_dummy_id = dummy.get_id()

	_world.queue_preview([
		{
			"actor_id": _caster_id,
			"passives": [] as Array[AbilityConfig],
			"track": [
				{"time_ms": 0,    "ability_config": HexBattleStrike.ABILITY, "target_id": _dummy_id},
				{"time_ms": 2100, "ability_config": HexBattleStrike.ABILITY, "target_id": _dummy_id},
				{"time_ms": 4200, "ability_config": HexBattleStrike.ABILITY, "target_id": _dummy_id},
			],
		},
		{
			"actor_id": _dummy_id,
			"passives": [] as Array[AbilityConfig],
			"track": [] as Array[Dictionary],
		},
	], false)

	var participants: Array[Actor] = []
	for actor in _world.get_actors():
		participants.append(actor)
	_world.start_battle(participants)
	_world.tick(100.0)


func _process(dt: float) -> void:
	if _finished:
		return
	_elapsed += dt
	if _elapsed > TIMEOUT_SEC:
		_fail("timeout")


func _on_battle_finished(timeline: Dictionary) -> void:
	if _finished:
		return
	if timeline.is_empty():
		_fail("Empty timeline")
		return

	var dmg_frames: Array[int] = []
	var grant_count := 0
	var exec_instance_ids: Array[String] = []
	for frame_data in timeline.get("timeline", []) as Array:
		if not (frame_data is Dictionary):
			continue
		var frame := int((frame_data as Dictionary).get("frame", 0))
		for ev in (frame_data as Dictionary).get("events", []) as Array:
			if not (ev is Dictionary):
				continue
			var kind := str((ev as Dictionary).get("kind", ""))
			if kind == "damage" and str((ev as Dictionary).get("target_actor_id", "")) == _dummy_id:
				dmg_frames.append(frame)
			elif kind == "abilityGranted" and str((ev as Dictionary).get("actorId", "")) == _caster_id:
				grant_count += 1
			elif kind == "executionActivated" and str((ev as Dictionary).get("actorId", "")) == _caster_id:
				exec_instance_ids.append(str((ev as Dictionary).get("abilityInstanceId", "")))

	if dmg_frames.size() != 3:
		_fail("expected 3 damage events, got %d (frames=%s)" % [dmg_frames.size(), str(dmg_frames)])
		return
	if grant_count != 1:
		_fail("expected exactly 1 abilityGranted on caster (instance reuse), got %d" % grant_count)
		return
	if exec_instance_ids.size() != 3:
		_fail("expected 3 executionActivated, got %d" % exec_instance_ids.size())
		return
	if exec_instance_ids[0] != exec_instance_ids[1] or exec_instance_ids[1] != exec_instance_ids[2]:
		_fail("execution abilityInstanceId 应该全部相同 (复用), got %s" % str(exec_instance_ids))
		return

	_pass("3 damage frames=%s; grant=1 (reused); exec_instance=%s" %
			[str(dmg_frames), exec_instance_ids[0]])


func _pass(reason: String) -> void:
	_finished = true
	print("SMOKE_TEST_RESULT: PASS - %s" % reason)
	get_tree().quit(0)


func _fail(reason: String) -> void:
	_finished = true
	push_error("SMOKE_TEST_RESULT: FAIL - %s" % reason)
	print("SMOKE_TEST_RESULT: FAIL - %s" % reason)
	get_tree().quit(1)
