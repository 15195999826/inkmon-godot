extends Node


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - InkMon M1 battle resolved with valid winner")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var gate_status := _assert_attribute_gate()
	if gate_status != "":
		return gate_status

	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()

	var battle := GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonBattleWorldGI.new()
	) as InkMonBattleWorldGI
	if battle == null:
		return "failed to create InkMonBattleWorldGI"

	battle.start({
		"recording": false,
	})
	GameWorld.tick_all(BattleProcedure.DEFAULT_TICK_INTERVAL)

	if battle.has_active_battle():
		return "battle did not finish in one world tick"

	var result := battle.get_result()
	if result != "left_win" and result != "right_win":
		return "invalid result: %s" % result

	var losing_alive := _count_alive(battle.right_team if result == "left_win" else battle.left_team)
	if losing_alive != 0:
		return "losing side still has %d alive units" % losing_alive

	if not battle.damage_mod_seen:
		return "no damage calculation had final damage differ from base damage"

	return ""


func _assert_attribute_gate() -> String:
	var attrs := InkMonUnitAttributeSet.new("gate")
	attrs.set_max_hp_base(80.0)
	attrs.set_hp_base(120.0)
	if absf(attrs.hp - 80.0) > 0.01:
		return "hp did not clamp to max_hp"
	attrs.set_ad_base(11.0)
	attrs.set_ap_base(12.0)
	attrs.set_armor_base(13.0)
	attrs.set_mr_base(14.0)
	attrs.set_speed_base(15.0)
	if attrs.ad != 11.0 or attrs.ap != 12.0 or attrs.armor != 13.0 or attrs.mr != 14.0 or attrs.speed != 15.0:
		return "InkMonUnitAttributeSet missing AD/AP/Armor/MR/Speed channel"
	return ""


func _count_alive(team: Array[InkMonUnitActor]) -> int:
	var count := 0
	for actor in team:
		if not actor.is_dead():
			count += 1
	return count
