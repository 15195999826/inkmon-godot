extends Node
## 出生 + 进化系统冒烟 (adr/0001 活 actor): 确定性 roll / 出生 actor 身份 round-trip /
## 进化原地变身 + X->X2 / 派生覆盖进化形态 / 刻印 round-trip / contract 进化森林。
## 进化语义住 SpeciesCatalog.evolve_actor(actor) —— 读写活 InkMonUnitActor 的 species/level/skill_slots。


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - InkMon birth roll deterministic and evolution rewrites species/skills on live actor")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var birth_status := _assert_birth_roll_deterministic()
	if birth_status != "":
		return birth_status
	var from_birth_status := _assert_from_birth_round_trips()
	if from_birth_status != "":
		return from_birth_status
	var evolve_status := _assert_evolution()
	if evolve_status != "":
		return evolve_status
	var derive_status := _assert_evolved_species_derive()
	if derive_status != "":
		return derive_status
	var engraving_status := _assert_engraving_round_trip()
	if engraving_status != "":
		return engraving_status
	var forest_status := _assert_contract_evolution_forest()
	if forest_status != "":
		return forest_status
	return ""


## adr/0010 contract 路径: 进化拓扑 + 阈值来自灌入的 edge-list 森林 (非 godot 硬编码)。
## 验证 (a) 阈值取 trigger.level (15 不进 / 16 进); (b) 多子确定性选边 (有 condition 满足者优先 →
## 否则无 condition 默认枝); (c) 原地变身 (actor 不换) + display_name 随进化更新。
func _assert_contract_evolution_forest() -> String:
	InkMonSpeciesCatalog.clear_static_content_cache_for_tests()
	var base := {"max_hp": 80.0, "ad": 40.0, "ap": 30.0, "armor": 30.0, "mr": 30.0, "speed": 60.0}
	var fire_el: Array[String] = ["fire"]
	var water_el: Array[String] = ["water"]
	InkMonSpeciesCatalog.replace_static_content_for_tests(
		{
			"mon_1001": _test_species_content_record(base, "baby", fire_el, "Branch Root"),
			"mon_1007": _test_species_content_record(base, "mature", fire_el, "Fire Branch"),
			"mon_1009": _test_species_content_record(base, "mature", water_el, "Default Branch"),
		},
		{
			"mon_1001": [
				{
					"child_species_id": "mon_1007",
					"trigger": {"level": 16, "condition": {"type": "element", "params": {"primary": "fire"}}},
				},
				{
					"child_species_id": "mon_1009",
					"trigger": {"level": 16, "condition": {}},
				},
			],
		}
	)

	# (a) Threshold = trigger.level (16), not a godot constant: level 15 must not evolve.
	var below := _make_contract_actor("mon_1001", fire_el, 15)
	if InkMonSpeciesCatalog.evolve_actor(below):
		InkMonSpeciesCatalog.clear_static_content_cache_for_tests()
		return "contract actor below trigger.level 16 must not evolve at level 15"
	if below.species != "mon_1001":
		InkMonSpeciesCatalog.clear_static_content_cache_for_tests()
		return "below-threshold contract actor species must stay unchanged"

	# (b1) At level 16 with fire primary → conditioned fire branch wins (deterministic).
	var fire := _make_contract_actor("mon_1001", fire_el, 16)
	if not InkMonSpeciesCatalog.evolve_actor(fire):
		InkMonSpeciesCatalog.clear_static_content_cache_for_tests()
		return "contract actor at trigger.level 16 should evolve"
	if fire.species != "mon_1007":
		InkMonSpeciesCatalog.clear_static_content_cache_for_tests()
		return "fire-primary actor should take the conditioned fire branch mon_1007, got %s" % fire.species
	if fire.get_display_name() != "Fire Branch":
		InkMonSpeciesCatalog.clear_static_content_cache_for_tests()
		return "evolved actor display name should update to child display_name, got %s" % fire.get_display_name()

	# (b2) Same level, NON-fire primary → condition unmet → default (no-condition) branch wins.
	var water := _make_contract_actor("mon_1001", water_el, 16)
	if not InkMonSpeciesCatalog.evolve_actor(water):
		InkMonSpeciesCatalog.clear_static_content_cache_for_tests()
		return "non-fire actor at level 16 should still evolve via the default branch"
	if water.species != "mon_1009":
		InkMonSpeciesCatalog.clear_static_content_cache_for_tests()
		return "non-fire actor should fall to the default branch mon_1009, got %s" % water.species

	InkMonSpeciesCatalog.clear_static_content_cache_for_tests()
	return ""


## White-box helper: 建一只指定 species/elements/level 的活 actor (跑分枝选择规则)。
## contract 测试物种无技能池, 显式给一个 skill_slot 满足 actor 构造契约。
func _make_contract_actor(species_id: String, elements: Array[String], actor_level: int) -> InkMonUnitActor:
	var actor := InkMonUnitActor.from_dict({
		"species_id": species_id,
		"name_en": InkMonSpeciesCatalog.get_display_name(species_id),
		"stage": InkMonSpeciesCatalog.get_stage(species_id),
		"elements": elements.duplicate(),
		"level": actor_level,
		"exp": 0,
		"skill_slots": [{"slot_index": 0, "skill_id": InkMonFireball.CONFIG_ID}],
		"engravings": [],
		"hp": -1.0,
	})
	return actor


func _test_species_content_record(
	base_stats: Dictionary,
	stage: String,
	elements: Array[String],
	display_name: String
) -> Dictionary:
	return {
		"base_stats": base_stats.duplicate(true),
		"stage": stage,
		"elements": elements.duplicate(),
		"display_name": display_name,
	}


func _assert_engraving_round_trip() -> String:
	# 刻印 actor→dict 往返 + create_combat_unit 吸收 (grant 在 equip 时, 见战斗 smoke)。
	var actor := InkMonUnitActor.new(InkMonUnitConfig.LEFT_CINDER_KIT)
	actor.engravings = [{"engraving_id": "amp", "target_slot": 0}]

	var loaded := InkMonUnitActor.from_dict(actor.to_dict())
	if loaded.engravings.size() != 1 or str(loaded.engravings[0].get("engraving_id", "")) != "amp":
		return "engravings should round-trip through to_dict/from_dict"
	if int(loaded.engravings[0].get("target_slot", -1)) != 0:
		return "engraving target_slot should round-trip"

	var combat := InkMonUnitActor.create_combat_unit({
		"species": "cinder_kit",
		"personality": InkMonUnitConfig.PERSONALITY_AGGRESSIVE,
		"elements": ["fire"],
		"skill_slots": [{"slot_index": 0, "skill_id": InkMonFireball.CONFIG_ID}],
		"engravings": [{"engraving_id": "amp", "target_slot": 0}],
		"battle_stats": {"max_hp": 100.0, "ad": 20.0, "ap": 20.0, "armor": 10.0, "mr": 10.0, "speed": 100.0},
	})
	if combat.engravings.size() != 1 or str(combat.engravings[0].get("engraving_id", "")) != "amp":
		return "combat unit should absorb engravings from combat_data"
	return ""


func _assert_birth_roll_deterministic() -> String:
	var species := "cinder_kit"
	var first := InkMonSpeciesCatalog.roll_birth_skill_slots(species, 12345)
	var second := InkMonSpeciesCatalog.roll_birth_skill_slots(species, 12345)
	if JSON.stringify(first) != JSON.stringify(second):
		return "birth roll must be deterministic for the same seed"
	if first.size() != InkMonSpeciesCatalog.get_slot_count(species):
		return "birth roll must fill every slot of the species"
	for slot in first:
		var slot_index := int(slot.get("slot_index", -1))
		var pool := InkMonSpeciesCatalog.get_slot_pool(species, slot_index)
		if not pool.has(str(slot.get("skill_id", ""))):
			return "rolled skill %s not in slot %d pool" % [str(slot.get("skill_id", "")), slot_index]
	var differs := false
	for s in range(8):
		if str(InkMonSpeciesCatalog.roll_skill_for_slot(species, 0, s)) != str(first[0].get("skill_id", "")):
			differs = true
			break
	if not differs:
		return "birth roll never varies across seeds (roll is not actually random within pool)"
	return ""


func _assert_from_birth_round_trips() -> String:
	var actor := _birth_actor("gale_mote", 999)
	if actor.species != "gale_mote":
		return "from-birth actor should set species"
	if actor.stage != InkMonSpeciesCatalog.STAGE_BABY:
		return "from-birth gale_mote should be baby stage"
	# adr/0008: role 已删; AI personality 不存, 由 species 派生 (interim)。
	if actor.personality == "":
		return "from-birth actor should derive an interim AI personality from species"
	if actor.elements.is_empty():
		return "from-birth actor should resolve elements from species"
	if actor.skill_slots.is_empty():
		return "from-birth actor should roll skill slots"
	if actor.get_primary_skill_id() == "":
		return "from-birth actor should produce a usable primary skill"

	# 身份持久切片 round-trip (派生六维/当前HP 由 GI 编排, 不在此 standalone 断言)。
	var before := _identity_only(actor.to_dict())
	var after := _identity_only(InkMonUnitActor.from_dict(actor.to_dict()).to_dict())
	if JSON.stringify(before) != JSON.stringify(after):
		return "from-birth actor identity save/load is not idempotent\nbefore=%s\nafter=%s" % [JSON.stringify(before), JSON.stringify(after)]
	return ""


func _assert_evolution() -> String:
	# Below threshold: no evolution.
	var young := InkMonUnitActor.new(InkMonUnitConfig.LEFT_CINDER_KIT)
	young.level = 1
	if InkMonSpeciesCatalog.evolve_actor(young):
		return "cinder_kit should not evolve below the level threshold"
	if young.species != "cinder_kit":
		return "below-threshold actor species must stay unchanged"

	# At threshold: evolves, rewrites species/stage, applies X->X2, adds a slot (same actor individual).
	var evolving := InkMonUnitActor.new(InkMonUnitConfig.LEFT_CINDER_KIT)
	evolving.level = 5
	evolving.skill_slots = [{"slot_index": 0, "skill_id": InkMonFireball.CONFIG_ID}]
	var old_slot_count := evolving.skill_slots.size()
	if not InkMonSpeciesCatalog.evolve_actor(evolving):
		return "cinder_kit at level 5 should evolve"
	if evolving.species != "cinder_fox":
		return "cinder_kit should evolve into cinder_fox"
	if evolving.stage != InkMonSpeciesCatalog.STAGE_MATURE:
		return "evolved cinder_fox should be mature stage"
	if str(evolving.skill_slots[0].get("skill_id", "")) != InkMonChainLightning.CONFIG_ID:
		return "X->X2 should upgrade slot 0 fireball into chain_lightning"
	if evolving.skill_slots.size() <= old_slot_count:
		return "evolution to a higher slot count should add at least one new slot"
	var new_slot_index := old_slot_count
	var new_pool := InkMonSpeciesCatalog.get_slot_pool("cinder_fox", new_slot_index)
	if not new_pool.has(str(evolving.skill_slots[new_slot_index].get("skill_id", ""))):
		return "newly rolled slot skill must come from the evolved species pool"

	# 进化后身份持久切片 round-trip。
	var before := _identity_only(evolving.to_dict())
	var after := _identity_only(InkMonUnitActor.from_dict(evolving.to_dict()).to_dict())
	if JSON.stringify(before) != JSON.stringify(after):
		return "evolved actor identity save/load is not idempotent"
	return ""


func _assert_evolved_species_derive() -> String:
	# Evolved species must derive battle stats (not in unit_config; sourced from catalog).
	var baby := InkMonSpeciesCatalog.get_base_stats("cinder_kit")
	var evolved := InkMonSpeciesCatalog.get_base_stats("cinder_fox")
	for key in InkMonUnitConfig.BASE_STAT_KEYS:
		if not evolved.has(key):
			return "evolved species base stats missing key: %s" % key
		if float(evolved[key]) <= float(baby[key]):
			return "evolved species base should exceed baby base for key: %s" % key

	# A live evolved actor derives scaled stats from the evolved species base.
	var actor := InkMonUnitActor.new(InkMonUnitConfig.LEFT_CINDER_KIT)
	actor.level = 5
	actor.skill_slots = [{"slot_index": 0, "skill_id": InkMonFireball.CONFIG_ID}]
	InkMonSpeciesCatalog.evolve_actor(actor)
	if actor.stage != InkMonSpeciesCatalog.STAGE_MATURE:
		return "evolved actor should carry stage=mature, got %s" % actor.stage
	actor.apply_derived_stats(InkMonSpeciesCatalog.get_base_stats(actor.species))
	if actor.attribute_set.max_hp <= float(baby["max_hp"]):
		return "evolved + leveled actor should derive higher max_hp than baby base"
	return ""


func _birth_actor(species_id: String, roll_seed: int) -> InkMonUnitActor:
	return InkMonUnitActor.from_dict({
		"species_id": species_id,
		"name_en": InkMonSpeciesCatalog.get_display_name(species_id),
		"stage": InkMonSpeciesCatalog.get_stage(species_id),
		"elements": InkMonSpeciesCatalog.get_elements(species_id),
		"level": 1,
		"exp": 0,
		"skill_slots": InkMonSpeciesCatalog.roll_birth_skill_slots(species_id, roll_seed),
		"engravings": [],
		"hp": -1.0,
	})


## 身份持久切片 (剥离 hp/equipment —— 那两者由 GI restore_persistent_state 在装备容器就绪后实现,
## standalone (无 GI) round-trip 只断言身份/选择/进度的幂等)。
func _identity_only(d: Dictionary) -> Dictionary:
	var c := d.duplicate(true)
	c.erase("hp")
	c.erase("equipment")
	return c
