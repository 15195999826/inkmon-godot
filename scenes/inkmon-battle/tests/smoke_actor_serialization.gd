extends Node
## Phase 1 (adr/0001 统一 live-actor): InkMonUnitActor 自序列化 + 派生 + HP carryover +
## 装备折叠 + InkMonPlayerActor 持久切片。纯 additive 验证，不接 GI/battle flow。
##
## 契约：
## - from_unit_config → level=1/exp=0/hp==max_hp（满血）。
## - to_dict 只存"身份+选择+进度+当前HP"，**不**存派生六维（无 max_hp/ad 等 leak）。
## - from_dict(data) 还原身份/level/exp/skill_slots/engravings；apply_derived_stats(base) 后
##   六维 = f(species, level) + 装备 stat_mods；set_current_hp 还原 carryover（< max 不回满）。
## - 装备折叠：equipment_container_id 指向的容器里物品 stat_mods 累加进 base。
## - InkMonPlayerActor：默认 gold=100/progression/medals=[]；to_dict/from_dict round-trip。


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - InkMon actor self-serialization + carryover + equipment fold")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	GameWorld.init(EventProcessorConfig.new(20, 1))
	_reset_item_runtime()

	var s1 := _check_from_unit_config_full_hp()
	if s1 != "":
		return s1
	var s2 := _check_to_dict_no_derived_leak()
	if s2 != "":
		return s2
	var s3 := _check_round_trip_with_level_and_carryover()
	if s3 != "":
		return s3
	var s4 := _check_equipment_fold()
	if s4 != "":
		return s4
	var s5 := _check_player_actor_round_trip()
	if s5 != "":
		return s5
	return ""


func _check_from_unit_config_full_hp() -> String:
	var actor := InkMonUnitActor.new(InkMonUnitConfig.LEFT_CINDER_KIT)
	if actor.level != 1:
		return "from_unit_config level should be 1, got %d" % actor.level
	if actor.exp != 0:
		return "from_unit_config exp should be 0, got %d" % actor.exp
	if absf(actor.attribute_set.hp - actor.attribute_set.max_hp) > 0.01:
		return "from_unit_config should start at full hp (%f) but hp=%f" % [actor.attribute_set.max_hp, actor.attribute_set.hp]
	return ""


func _check_to_dict_no_derived_leak() -> String:
	var actor := InkMonUnitActor.new(InkMonUnitConfig.LEFT_CINDER_KIT)
	var d := actor.to_dict()
	for required in ["species_id", "name_en", "stage", "elements", "level", "exp", "skill_slots", "engravings", "hp"]:
		if not d.has(required):
			return "to_dict missing key: %s" % required
	for leaked in ["max_hp", "ad", "ap", "armor", "mr", "speed", "battle_stats"]:
		if d.has(leaked):
			return "to_dict leaked derived stat key: %s" % leaked
	if str(d["species_id"]) != "cinder_kit":
		return "to_dict species_id wrong: %s" % str(d["species_id"])
	return ""


func _check_round_trip_with_level_and_carryover() -> String:
	var actor := InkMonUnitActor.new(InkMonUnitConfig.LEFT_CINDER_KIT)
	actor.level = 3
	actor.add_exp(7)
	# 制造伤害态：hp 降到 10（carryover 必须保留，不回满）。
	actor.set_current_hp(10.0)
	var before := actor.to_dict()

	var restored := InkMonUnitActor.from_dict(before)
	if restored.level != 3:
		return "round-trip level lost: %d" % restored.level
	if restored.exp != 7:
		return "round-trip exp lost: %d" % restored.exp
	if str(restored.species) != "cinder_kit":
		return "round-trip species lost: %s" % str(restored.species)
	if restored.get_primary_skill_id() != actor.get_primary_skill_id():
		return "round-trip primary skill lost"

	# 读档统一入口 restore_persistent_state(base, saved_hp)：先派生六维再还原 carryover（顺序固定）。
	# max_hp = species_base.max_hp * (1 + (level-1)*LEVEL_GROWTH)；hp = 存档值（10，不回满）。
	var base := InkMonSpeciesCatalog.get_base_stats(restored.species)
	restored.restore_persistent_state(base, float(before["hp"]))
	var expected_max_hp := float(base["max_hp"]) * (1.0 + 2.0 * InkMonUnitActor.LEVEL_GROWTH)
	if absf(restored.attribute_set.max_hp - expected_max_hp) > 0.01:
		return "derived max_hp wrong: got %f expected %f" % [restored.attribute_set.max_hp, expected_max_hp]
	if absf(restored.attribute_set.hp - 10.0) > 0.01:
		return "hp carryover lost: got %f expected 10.0" % restored.attribute_set.hp
	return ""


func _check_equipment_fold() -> String:
	var actor := InkMonUnitActor.new(InkMonUnitConfig.LEFT_CINDER_KIT)
	var base := InkMonSpeciesCatalog.get_base_stats(actor.species)
	var base_ad := float(base["ad"])

	var container := BaseContainer.new()
	container.container_name = &"equip:test"
	container.space_config = ContainerSpaceConfig.create_unordered(-1)
	var cid := ItemSystem.register_container(container)
	if cid <= 0:
		return "failed to register equipment container"
	var create_result := ItemSystem.create_item(cid, InkMonItemCatalog.TRAINING_SWORD, 1, -1)
	if not create_result.success:
		return "failed to create equipment item: %s" % create_result.error_message
	actor.equipment_container_id = cid
	actor.apply_derived_stats(base)

	var expected_ad := base_ad + 5.0  # TRAINING_SWORD stat_mods {ad: 5.0}
	if absf(actor.attribute_set.ad - expected_ad) > 0.01:
		return "equipment fold failed: ad=%f expected %f" % [actor.attribute_set.ad, expected_ad]

	# to_dict 捕获装备容器内物品（write 侧；restore 侧由 GI Phase 2 编排）。
	var equip := actor.to_dict().get("equipment", []) as Array
	if equip.size() != 1:
		return "to_dict equipment capture wrong size: %d" % equip.size()
	if str((equip[0] as Dictionary).get("config_id", "")) != str(InkMonItemCatalog.TRAINING_SWORD):
		return "to_dict equipment capture wrong item: %s" % str((equip[0] as Dictionary).get("config_id", ""))
	return ""


func _check_player_actor_round_trip() -> String:
	var player := InkMonPlayerActor.create_new()
	if player.gold != InkMonPlayerActor.DEFAULT_GOLD:
		return "create_new PlayerActor gold should be %d, got %d" % [InkMonPlayerActor.DEFAULT_GOLD, player.gold]
	if not (player.medals is Array):
		return "PlayerActor medals should be an Array"
	if int(player.progression.get("trainer_rank", -1)) != 1:
		return "create_new PlayerActor progression should default trainer_rank=1"
	player.gold = 250
	player.progression["trainer_rank"] = 4
	player.medals.append("first_win")
	player.hex_position = HexCoord.new(2, -1)

	var restored := InkMonPlayerActor.from_dict(player.to_dict())
	if restored.gold != 250:
		return "PlayerActor gold round-trip lost: %d" % restored.gold
	if int(restored.progression.get("trainer_rank", -1)) != 4:
		return "PlayerActor progression round-trip lost"
	if not restored.medals.has("first_win"):
		return "PlayerActor medals round-trip lost"
	if restored.hex_position.to_axial() != Vector2i(2, -1):
		return "PlayerActor coord round-trip lost: %s" % str(restored.hex_position.to_axial())
	return ""


func _reset_item_runtime() -> void:
	ItemSystem.reset_session()
	ItemSystem.configure_domain(InkMonItemDomain.new(), InkMonItemCatalog.new())
