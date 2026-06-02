extends Node
## P2 出生 + 进化系统冒烟: 确定性 roll / from_birth 往返 / 进化链 + X->X2 / 派生覆盖进化形态。


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - InkMon birth roll is deterministic and evolution rewrites species/skills")
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

	var engraving_status := _assert_engraving_projection()
	if engraving_status != "":
		return engraving_status

	var forest_status := _assert_contract_evolution_forest()
	if forest_status != "":
		return forest_status

	return ""


## adr/0010 contract 路径: 进化拓扑 + 阈值来自灌入的 edge-list 森林 (非 godot 硬编码)。
## 验证 (a) 阈值取 trigger.level (15 不进 / 16 进); (b) 多子确定性选边 (有 condition 满足者优先 →
## 否则无 condition 默认枝); (c) entry_id 不变 + name_en 随进化更新。
## 用 mon_1xxx (与 stub 物种隔离), 末尾 clear_overrides 还原纯 stub 态。
func _assert_contract_evolution_forest() -> String:
	InkMonSpeciesCatalog.clear_overrides()
	var base := {"max_hp": 80.0, "ad": 40.0, "ap": 30.0, "armor": 30.0, "mr": 30.0, "speed": 60.0}
	var fire_el: Array[String] = ["fire"]
	var water_el: Array[String] = ["water"]
	InkMonSpeciesCatalog.register_override("mon_1001", base, "baby", fire_el, "Branch Root")
	InkMonSpeciesCatalog.register_override("mon_1007", base, "mature", fire_el, "Fire Branch")
	InkMonSpeciesCatalog.register_override("mon_1009", base, "mature", water_el, "Default Branch")
	InkMonSpeciesCatalog.register_evolution_edges([
		{
			"parent_species_id": "mon_1001", "child_species_id": "mon_1007",
			"trigger": {"level": 16, "condition": {"type": "element", "params": {"primary": "fire"}}},
		},
		{
			"parent_species_id": "mon_1001", "child_species_id": "mon_1009",
			"trigger": {"level": 16},
		},
	])

	# (a) Threshold = trigger.level (16), not a godot constant: level 15 must not evolve.
	var below := _make_contract_entry("mon_1001", fire_el, 15)
	if InkMonSpeciesCatalog.evolve_entry(below):
		InkMonSpeciesCatalog.clear_overrides()
		return "contract entry below trigger.level 16 must not evolve at level 15"
	if below.species_id != "mon_1001":
		InkMonSpeciesCatalog.clear_overrides()
		return "below-threshold contract entry species_id must stay unchanged"

	# (b1) At level 16 with fire primary → conditioned fire branch wins (deterministic).
	var fire := _make_contract_entry("mon_1001", fire_el, 16)
	if not InkMonSpeciesCatalog.evolve_entry(fire):
		InkMonSpeciesCatalog.clear_overrides()
		return "contract entry at trigger.level 16 should evolve"
	if fire.species_id != "mon_1007":
		InkMonSpeciesCatalog.clear_overrides()
		return "fire-primary entry should take the conditioned fire branch mon_1007, got %s" % fire.species_id
	if fire.entry_id != 555:
		InkMonSpeciesCatalog.clear_overrides()
		return "contract evolution must keep entry_id"
	if fire.name_en != "Fire Branch":
		InkMonSpeciesCatalog.clear_overrides()
		return "evolved entry name_en should update to the child display_name, got %s" % fire.name_en

	# (b2) Same level, NON-fire primary → condition unmet → default (no-condition) branch wins.
	var water := _make_contract_entry("mon_1001", water_el, 16)
	if not InkMonSpeciesCatalog.evolve_entry(water):
		InkMonSpeciesCatalog.clear_overrides()
		return "non-fire entry at level 16 should still evolve via the default branch"
	if water.species_id != "mon_1009":
		InkMonSpeciesCatalog.clear_overrides()
		return "non-fire entry should fall to the default branch mon_1009, got %s" % water.species_id

	InkMonSpeciesCatalog.clear_overrides()
	return ""


## White-box helper: from_birth then force elements + level so the branch-selection rule
## (conditioned-wins vs default-fallback) can be exercised on the same parent species.
func _make_contract_entry(species_id: String, elements: Array[String], entry_level: int) -> InkMonRosterEntry:
	var entry := InkMonRosterEntry.from_birth(555, species_id, 7)
	entry.elements = elements.duplicate()
	entry.level = entry_level
	return entry


func _assert_engraving_projection() -> String:
	# P8: 刻印 entry→dict 往返 + entry→snapshot→actor 投影/吸收 (grant 在 equip 时, 见战斗 smoke)。
	var entry := InkMonRosterEntry.from_unit_config(11, InkMonUnitConfig.LEFT_MAGE_DPS)
	entry.engravings = [{"engraving_id": "amp", "target_slot": 0}]

	var loaded := InkMonRosterEntry.from_dict(entry.to_dict())
	if loaded.engravings.size() != 1 or str(loaded.engravings[0].get("engraving_id", "")) != "amp":
		return "engravings should round-trip through to_dict/from_dict"
	if int(loaded.engravings[0].get("target_slot", -1)) != 0:
		return "engraving target_slot should round-trip"

	var snapshot := entry.project_to_battle_snapshot()
	var snap_engravings := snapshot.get("engravings", []) as Array
	if snap_engravings == null or snap_engravings.size() != 1:
		return "snapshot must project engravings"
	if str((snap_engravings[0] as Dictionary).get("engraving_id", "")) != "amp":
		return "snapshot engraving should carry engraving_id"

	var actor := InkMonUnitActor.from_battle_snapshot(snapshot)
	if actor.engravings.size() != 1:
		return "actor should absorb engravings from snapshot"
	if str(actor.engravings[0].get("engraving_id", "")) != "amp":
		return "actor engraving should carry engraving_id"
	return ""


func _assert_birth_roll_deterministic() -> String:
	var species := "cinder_kit"
	var first := InkMonSpeciesCatalog.roll_birth_skill_slots(species, 12345)
	var second := InkMonSpeciesCatalog.roll_birth_skill_slots(species, 12345)
	if JSON.stringify(first) != JSON.stringify(second):
		return "birth roll must be deterministic for the same seed"
	if first.size() != InkMonSpeciesCatalog.get_slot_count(species):
		return "birth roll must fill every slot of the species"
	# Each rolled skill must come from that slot's pool.
	for slot in first:
		var slot_index := int(slot.get("slot_index", -1))
		var pool := InkMonSpeciesCatalog.get_slot_pool(species, slot_index)
		if not pool.has(str(slot.get("skill_id", ""))):
			return "rolled skill %s not in slot %d pool" % [str(slot.get("skill_id", "")), slot_index]
	# Different seeds should be able to produce a different result across the species space
	# (at least one seed differs from another for a 2-option pool).
	var differs := false
	for s in range(8):
		if str(InkMonSpeciesCatalog.roll_skill_for_slot(species, 0, s)) != str(first[0].get("skill_id", "")):
			differs = true
			break
	if not differs:
		return "birth roll never varies across seeds (roll is not actually random within pool)"
	return ""


func _assert_from_birth_round_trips() -> String:
	var entry := InkMonRosterEntry.from_birth(7, "gale_mote", 999)
	if entry.species_id != "gale_mote":
		return "from_birth should set species_id"
	if entry.stage != InkMonSpeciesCatalog.STAGE_BABY:
		return "from_birth gale_mote should be baby stage"
	if entry.role == "":
		return "from_birth should resolve role from species"
	if entry.elements.is_empty():
		return "from_birth should resolve elements from species"
	if entry.skill_slots.is_empty():
		return "from_birth should roll skill slots"
	if entry.get_primary_skill_id() == "":
		return "from_birth should produce a usable primary skill"

	var before := entry.to_dict()
	var loaded := InkMonRosterEntry.from_dict(before)
	var after := loaded.to_dict()
	if JSON.stringify(before) != JSON.stringify(after):
		return "from_birth entry save/load is not idempotent\nbefore=%s\nafter=%s" % [JSON.stringify(before), JSON.stringify(after)]
	return ""


func _assert_evolution() -> String:
	# Below threshold: no evolution.
	var young := InkMonRosterEntry.from_unit_config(3, InkMonUnitConfig.LEFT_MAGE_DPS)  # cinder_kit
	young.level = 1
	if InkMonSpeciesCatalog.evolve_entry(young):
		return "cinder_kit should not evolve below the level threshold"
	if young.species_id != "cinder_kit":
		return "below-threshold entry species_id must stay unchanged"

	# At threshold: evolves, rewrites species/stage, keeps entry_id, applies X->X2, adds a slot.
	var evolving := InkMonRosterEntry.from_unit_config(3, InkMonUnitConfig.LEFT_MAGE_DPS)
	evolving.level = 5
	# Pin slot 0 to fireball so the X->X2 upgrade is observable.
	evolving.skill_slots = [{"slot_index": 0, "skill_id": InkMonFireball.CONFIG_ID}]
	var old_slot_count := evolving.skill_slots.size()
	if not InkMonSpeciesCatalog.evolve_entry(evolving):
		return "cinder_kit at level 5 should evolve"
	if evolving.entry_id != 3:
		return "evolution must keep the same entry_id (same individual)"
	if evolving.species_id != "cinder_fox":
		return "cinder_kit should evolve into cinder_fox"
	if evolving.stage != InkMonSpeciesCatalog.STAGE_MATURE:
		return "evolved cinder_fox should be mature stage"
	if str(evolving.skill_slots[0].get("skill_id", "")) != InkMonChainLightning.CONFIG_ID:
		return "X->X2 should upgrade slot 0 fireball into chain_lightning"
	if evolving.skill_slots.size() <= old_slot_count:
		return "evolution to a higher slot count should add at least one new slot"
	# Newly added slot must come from cinder_fox's pool for that slot.
	var new_slot_index := old_slot_count
	var new_pool := InkMonSpeciesCatalog.get_slot_pool("cinder_fox", new_slot_index)
	if not new_pool.has(str(evolving.skill_slots[new_slot_index].get("skill_id", ""))):
		return "newly rolled slot skill must come from the evolved species pool"

	# Round-trip after evolution.
	var before := evolving.to_dict()
	var after := InkMonRosterEntry.from_dict(before).to_dict()
	if JSON.stringify(before) != JSON.stringify(after):
		return "evolved entry save/load is not idempotent"
	return ""


func _assert_evolved_species_derive() -> String:
	# Evolved species must derive battle stats (not in unit_config; sourced from catalog).
	var baby := InkMonSpeciesCatalog.get_base_stats("cinder_kit")
	var evolved := InkMonSpeciesCatalog.get_base_stats("cinder_fox")
	for key in InkMonRosterEntry.STAT_KEYS:
		if not evolved.has(key):
			return "evolved species base stats missing key: %s" % key
		if float(evolved[key]) <= float(baby[key]):
			return "evolved species base should exceed baby base for key: %s" % key

	# A live evolved entry projects to battle without crashing and yields scaled stats.
	var entry := InkMonRosterEntry.from_unit_config(9, InkMonUnitConfig.LEFT_MAGE_DPS)
	entry.level = 5
	entry.skill_slots = [{"slot_index": 0, "skill_id": InkMonFireball.CONFIG_ID}]
	InkMonSpeciesCatalog.evolve_entry(entry)
	var derived := entry.derive_battle_stats()
	if float(derived.get("max_hp", 0.0)) <= float(baby["max_hp"]):
		return "evolved + leveled entry should derive higher max_hp than baby base"
	var snapshot := entry.project_to_battle_snapshot()
	if (snapshot.get("battle_stats", {}) as Dictionary).is_empty():
		return "evolved entry projection must still emit battle_stats"
	# Snapshot must carry the evolved stage so the battle actor doesn't default it to baby.
	if str(snapshot.get("stage", "")) != InkMonSpeciesCatalog.STAGE_MATURE:
		return "evolved entry snapshot should carry stage=mature, got %s" % str(snapshot.get("stage", ""))
	return ""
