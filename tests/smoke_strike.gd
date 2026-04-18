## Smoke test: verify HexBattleStrike reads damage from caster.atk via FloatResolver
##
## Setup:
##   - Minimal HexBattle subclass with 1 caster (WARRIOR, atk=77) + 1 target (adjacent, hp=1000)
##   - Strike is equipped via caster.equip_abilities() → should auto-use HexBattleStrike.ABILITY
##   - Fire ABILITY_ACTIVATE_EVENT against target, tick until Strike's HIT keyframe fires
##
## Assertion:
##   - Captured DamageEvent.damage should be 77 (no crit) or 115/115.5 (crit x1.5)
##   - If resolver returned 0 (missing ctx) → damage = 0 → FAIL
##   - If damage was still hardcoded 50 → damage = 50 → FAIL
##
## Exit code: 0 on PASS, 1 on FAIL. Output marker: "SMOKE_TEST_RESULT: PASS/FAIL"
extends Node


const EXPECTED_ATK := 77.0


var _captured_damages: Array[float] = []


func _ready() -> void:
	print("=== Smoke Test: Strike reads caster.atk via Resolver ===")
	print("Expected damage: 77 (no-crit) or 115.5 (crit x1.5)")
	print("")

	GameWorld.init()
	HexBattleAllSkills.register_all_timelines()

	var battle := GameWorld.create_instance(func() -> GameplayInstance:
		var b := _TestBattle.new()
		b.setup_test_battle()
		return b
	) as _TestBattle

	if battle == null:
		_fail("Failed to create test battle")
		return

	var strike := battle.caster.get_skill_ability()
	if strike == null:
		_fail("Caster has no Strike ability")
		return

	print("Caster: %s (atk=%.1f), Target: %s (hp=%.0f)" % [
		battle.caster.get_display_name(),
		battle.caster.attribute_set.atk,
		battle.target.get_display_name(),
		battle.target.attribute_set.hp,
	])
	print("")

	# 触发 Strike
	var activate_event := {
		"kind": GameEvent.ABILITY_ACTIVATE_EVENT,
		"abilityInstanceId": strike.id,
		"sourceId": battle.caster.get_id(),
		"target_actor_id": battle.target.get_id(),
		"logicTime": 0.0,
	}
	battle.caster.ability_set.receive_event(activate_event, battle)

	# Tick 到 Strike HIT 触发（Strike timeline = 500ms, HIT @ 300ms）
	var tick_count := 0
	var dt := 100.0  # 每 tick 100ms
	while tick_count < 20 and _captured_damages.is_empty():
		tick_count += 1
		for actor in battle.get_all_actors():
			actor.ability_set.tick(dt, battle.get_logic_time())
			actor.ability_set.tick_executions(dt)
		battle.tick(dt)

		# 抓取 damage event
		var events := GameWorld.event_collector.flush()
		for ev in events:
			if ev.get("kind") == "damage":
				_captured_damages.append(ev.get("damage", -1.0))

	_assert_and_exit()


func _assert_and_exit() -> void:
	print("")
	print("--- Result ---")
	if _captured_damages.is_empty():
		_fail("No damage event captured (Strike never fired in 20 ticks)")
		return

	var dmg: float = _captured_damages[0]
	print("Captured damage: %.2f" % dmg)

	# Strike base = caster.atk = 77. Final = base * (1.5 if crit else 1.0).
	# 115.5 is how crit 77*1.5 shows up as float
	var no_crit: bool = abs(dmg - EXPECTED_ATK) < 0.01
	var crit: bool = abs(dmg - EXPECTED_ATK * 1.5) < 0.01

	if no_crit:
		print("SMOKE_TEST_RESULT: PASS — Strike damage matched caster.atk (%.0f)" % EXPECTED_ATK)
		GameWorld.destroy()
		get_tree().quit(0)
	elif crit:
		print("SMOKE_TEST_RESULT: PASS — Strike damage matched caster.atk * 1.5 crit (%.1f)" % (EXPECTED_ATK * 1.5))
		GameWorld.destroy()
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL — damage %.2f is neither %.0f nor %.1f" % [dmg, EXPECTED_ATK, EXPECTED_ATK * 1.5])
		print("  (If damage==50 → Strike still hardcoded. If damage==0 → resolver returned 0.)")
		GameWorld.destroy()
		get_tree().quit(1)


func _fail(msg: String) -> void:
	print("SMOKE_TEST_RESULT: FAIL — " + msg)
	GameWorld.destroy()
	get_tree().quit(1)


# ========== Test Battle ==========

## 最小化 HexBattle：1 个 caster + 1 个 target，无 ATB/AI，只驱动 ability tick
class _TestBattle extends HexBattle:
	var caster: CharacterActor
	var target: CharacterActor

	func _init() -> void:
		super._init()
		type = "smoke_battle"

	func setup_test_battle() -> void:
		_state = "running"

		# 3x3 hex grid
		var grid_config := GridMapConfig.new()
		grid_config.grid_type = GridMapConfig.GridType.HEX
		grid_config.draw_mode = GridMapConfig.DrawMode.ROW_COLUMN
		grid_config.rows = 3
		grid_config.columns = 3
		grid_config.size = 10.0
		grid_config.orientation = GridMapConfig.Orientation.FLAT
		UGridMap.configure(grid_config)

		# Caster: atk 从默认 50 改成 77（契约改造的验证目标）
		caster = CharacterActor.new(HexBattleClassConfig.CharacterClass.WARRIOR)
		add_actor(caster)
		caster.set_team_id(0)
		caster.attribute_set.set_atk_base(77.0)  # ← 关键：验证 resolver 会读到这个
		caster.equip_abilities()
		var coord_a := HexCoord.new(0, 0)
		if UGridMap.model.has_tile(coord_a):
			UGridMap.model.place_occupant(coord_a, caster)
		caster.hex_position = coord_a.duplicate()
		left_team = [caster]

		# Target: 相邻格，高 HP
		target = CharacterActor.new(HexBattleClassConfig.CharacterClass.WARRIOR)
		add_actor(target)
		target.set_team_id(1)
		target.attribute_set.set_max_hp_base(1000.0)
		target.attribute_set.set_hp_base(1000.0)
		target.equip_abilities()
		var coord_b := HexCoord.new(1, 0)
		if UGridMap.model.has_tile(coord_b):
			UGridMap.model.place_occupant(coord_b, target)
		target.hex_position = coord_b.duplicate()
		right_team = [target]

	func tick(dt: float) -> void:
		base_tick(dt)
