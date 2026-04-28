## Smoke: SkillPreviewProcedure 单 actor 多 keyframe (违法间隔, procedure 兜底)
##
## 配置: caster t=0 / t=300 / t=600 三发 Strike → dummy
##   间隔 < cooldown (2000ms) —— UI 在编辑期会拦住, 但 procedure 收到这种配置
##   (例如外部 preset / 测试场景手工 queue) 必须不崩, 走 cooldown silently reject。
##
## 期望: 1 条 damage (第一发), procedure 正常 emit battle_finished, 不崩。
##   后两发被 CooldownCondition reject; 因为去重 grant, caster 上仍只有 1 个 instance,
##   说明改动 1 不会因为后续 keyframe fire 失败而堆积/泄漏 ability。
##
## 这是 改动 1 的反向 invariant 测试: "UI 失守时 procedure 不崩"。
extends Node


const TIMEOUT_SEC := 30.0


var _world: SkillPreviewWorldGI
var _caster_id: String = ""
var _dummy_id: String = ""
var _elapsed: float = 0.0
var _finished: bool = false


func _ready() -> void:
	Log.set_level(Log.LogLevel.WARNING)
	print("=== Smoke: skill_preview proc multi-keyframe illegal ===")

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
				{"time_ms": 0,   "ability_config": HexBattleStrike.ABILITY, "target_id": _dummy_id},
				{"time_ms": 300, "ability_config": HexBattleStrike.ABILITY, "target_id": _dummy_id},
				{"time_ms": 600, "ability_config": HexBattleStrike.ABILITY, "target_id": _dummy_id},
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

	var dmg_count := 0
	var grant_count := 0
	for frame_data in timeline.get("timeline", []) as Array:
		if not (frame_data is Dictionary):
			continue
		for ev in (frame_data as Dictionary).get("events", []) as Array:
			if not (ev is Dictionary):
				continue
			var kind := str((ev as Dictionary).get("kind", ""))
			if kind == "damage" and str((ev as Dictionary).get("target_actor_id", "")) == _dummy_id:
				dmg_count += 1
			elif kind == "abilityGranted" and str((ev as Dictionary).get("actorId", "")) == _caster_id:
				grant_count += 1

	if dmg_count != 1:
		_fail("expected exactly 1 damage (others cooldown-rejected), got %d" % dmg_count)
		return
	if grant_count != 1:
		_fail("expected exactly 1 abilityGranted (no duplicate grants from rejected fires), got %d" % grant_count)
		return

	_pass("cooldown reject works: damage=1, grant=1")


func _pass(reason: String) -> void:
	_finished = true
	print("SMOKE_TEST_RESULT: PASS - %s" % reason)
	get_tree().quit(0)


func _fail(reason: String) -> void:
	_finished = true
	push_error("SMOKE_TEST_RESULT: FAIL - %s" % reason)
	print("SMOKE_TEST_RESULT: FAIL - %s" % reason)
	get_tree().quit(1)
