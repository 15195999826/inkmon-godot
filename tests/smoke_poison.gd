## Smoke test: HexBattlePoison + PoisonBuff DOT 全链路
##
## Setup:
##   - Minimal HexBattle with 1 caster + 1 adjacent target (hp=1000, atk 无关)
##   - Caster 手动装备 HexBattlePoison 主动技能
##
## 步骤:
##   1. 触发 Poison ABILITY_ACTIVATE_EVENT 对 target
##   2. Tick 到 HIT (300ms) → ApplyBuffAction grant PoisonBuff(stacks=3) → GRANTED_SELF 启动 loop timeline
##   3. 继续 tick，每 2s 一次 PoisonTick → 造成 3 / 2 / 1 的 PURE 伤害 → 第 4 次 tick 前 buff 应已 expire
##
## Assertion:
##   - 按顺序捕获三次 DOT damage: 3, 2, 1（前面可能还有非 DOT 伤害，过滤 damage_type=pure + source==target 即自残 DOT）
##   - 总 DOT 伤害 = 6
##   - 三轮 DOT 之后 buff_poison ability 应从 target 的 ability_set 消失（expire → revoke）
##   - 再继续 tick 2s，不再有新 DOT damage（loop 停了）
##
## Exit code: 0 on PASS, 1 on FAIL. Output marker: "SMOKE_TEST_RESULT: PASS/FAIL"
extends Node


const INITIAL_STACKS := 3
const EXPECTED_DOT_DAMAGES: Array[float] = [3.0, 2.0, 1.0]
const EXPECTED_TOTAL := 6.0


var _dot_damages: Array[float] = []


func _ready() -> void:
	print("=== Smoke Test: Poison DOT (stacks=3 → 3+2+1=6) ===")

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

	# 手动给 caster 装备 Poison 主动（替代 equip_abilities 的默认 skill）
	var poison_ability := Ability.new(HexBattlePoison.ABILITY, battle.caster.get_id())
	battle.caster.ability_set.grant_ability(poison_ability, battle)

	print("Caster: %s, Target: %s (hp=%.0f)" % [
		battle.caster.get_display_name(),
		battle.target.get_display_name(),
		battle.target.attribute_set.hp,
	])

	# 触发 Poison
	var activate_event := {
		"kind": GameEvent.ABILITY_ACTIVATE_EVENT,
		"abilityInstanceId": poison_ability.id,
		"sourceId": battle.caster.get_id(),
		"target_actor_id": battle.target.get_id(),
		"logicTime": 0.0,
	}
	battle.caster.ability_set.receive_event(activate_event, battle)

	# Tick：Poison cast 500ms 完成 → HIT 300ms 施加 buff → 每 2s 一次 DOT
	# 总时间上限：7s（足够跑完 3 次 DOT + 验证停止）
	var dt := 100.0
	var total_time := 0.0
	var max_time := 7500.0
	var target_id := battle.target.get_id()

	while total_time < max_time:
		total_time += dt
		for actor in battle.get_all_actors():
			actor.ability_set.tick(dt, battle.get_logic_time())
			actor.ability_set.tick_executions(dt, battle)
		battle.tick(dt)

		var events := GameWorld.event_collector.flush()
		for ev in events:
			if ev.get("kind") != "damage":
				continue
			# 只抓对 target 自己的 PURE 伤害 = DOT tick（不是主动技能的直接伤害）
			var dtype := str(ev.get("damage_type", ""))
			var tgt := str(ev.get("target_actor_id", ""))
			if dtype == "pure" and tgt == target_id:
				_dot_damages.append(ev.get("damage", -1.0))

	_assert_and_exit(battle, target_id)


func _assert_and_exit(battle: _TestBattle, target_id: String) -> void:
	print("")
	print("--- Result ---")
	print("Captured DOT damages: %s" % str(_dot_damages))

	if _dot_damages.size() != 3:
		_fail("Expected 3 DOT ticks, got %d" % _dot_damages.size())
		return

	for i in range(3):
		var expected: float = EXPECTED_DOT_DAMAGES[i]
		var actual: float = _dot_damages[i]
		if abs(actual - expected) > 0.01:
			_fail("Tick #%d damage mismatch: expected %.0f, got %.2f" % [i + 1, expected, actual])
			return

	var total: float = 0.0
	for d in _dot_damages:
		total += d
	if abs(total - EXPECTED_TOTAL) > 0.01:
		_fail("Total DOT damage mismatch: expected %.0f, got %.2f" % [EXPECTED_TOTAL, total])
		return

	# 验证 buff 已从 target 的 ability_set 被 revoke
	var target_actor := battle.get_actor(target_id) as CharacterActor
	if target_actor == null:
		_fail("Target actor missing after DOT sequence")
		return
	var still_has_buff := target_actor.ability_set.has_ability(HexBattlePoisonBuff.CONFIG_ID)
	if still_has_buff:
		_fail("PoisonBuff still present on target after stacks exhausted")
		return

	print("SMOKE_TEST_RESULT: PASS - Poison DOT 3→2→1 total=6, buff revoked after exhaustion")
	GameWorld.destroy()
	get_tree().quit(0)


func _fail(msg: String) -> void:
	print("SMOKE_TEST_RESULT: FAIL - " + msg)
	GameWorld.destroy()
	get_tree().quit(1)


# ========== Test Battle ==========

class _TestBattle extends HexBattle:
	var caster: CharacterActor
	var target: CharacterActor

	func _init() -> void:
		super._init()
		type = "smoke_battle"

	func setup_test_battle() -> void:
		_state = "running"

		var grid_config := GridMapConfig.new()
		grid_config.grid_type = GridMapConfig.GridType.HEX
		grid_config.draw_mode = GridMapConfig.DrawMode.ROW_COLUMN
		grid_config.rows = 3
		grid_config.columns = 3
		grid_config.size = 10.0
		grid_config.orientation = GridMapConfig.Orientation.FLAT
		UGridMap.configure(grid_config)

		caster = CharacterActor.new(HexBattleClassConfig.CharacterClass.WARRIOR)
		add_actor(caster)
		caster.set_team_id(0)
		var coord_a := HexCoord.new(0, 0)
		if UGridMap.model.has_tile(coord_a):
			UGridMap.model.place_occupant(coord_a, caster)
		caster.hex_position = coord_a.duplicate()
		left_team = [caster]

		target = CharacterActor.new(HexBattleClassConfig.CharacterClass.WARRIOR)
		add_actor(target)
		target.set_team_id(1)
		target.attribute_set.set_max_hp_base(1000.0)
		target.attribute_set.set_hp_base(1000.0)
		var coord_b := HexCoord.new(1, 0)
		if UGridMap.model.has_tile(coord_b):
			UGridMap.model.place_occupant(coord_b, target)
		target.hex_position = coord_b.duplicate()
		right_team = [target]

	func tick(dt: float) -> void:
		base_tick(dt)
