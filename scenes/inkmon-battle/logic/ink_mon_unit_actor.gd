class_name InkMonUnitActor
extends InkMonBattleActor


const ATB_FULL := 100.0

## v1 占位线性成长 (adr/0001 / docs §9): level-1 = 物种 base (M1 平衡不变), 之后每级 +LEVEL_GROWTH 倍。
## 派生六维 = species_base × (1 + (level-1)*LEVEL_GROWTH) + 装备 stat_mods (flat)。
const LEVEL_GROWTH := 0.05


var unit_key: String
## adr/0001 前的投影回写映射键; live-actor 模型下 roster actor 即真相, 仅 battle 临时敌人/旧路径用, 默认 -1。
var source_entry_id := -1
## 全局唯一身份键 (= species_id, adr/0010)。一切寻址 (SpeciesCatalog 查询/进化) 走它。
var species: String
var stage: String
## AI 行为倾向(驱动选策);adr/0008 后取代 role。interim:由 species 派生。
var personality: String
var elements: Array[String] = []
## 成长状态 (持久切片, 进存档)。派生六维由它 + species base 重算, 不进存档 (adr/0001)。
var level := 1
var exp := 0
# 技能槽 [{slot_index, skill_id}]; primary = slot0 作 active skill (多技能 equip 留 future)。
var skill_slots: Array[Dictionary] = []
# 刻印 [{engraving_id, target_slot}]; equip 时每条 grant 一个刻印被动强化技能 (§8c)。
var engravings: Array[Dictionary] = []
## 装备容器 id (ItemSystem 注册, runtime; 不进存档——存档只存容器内物品)。-1 = 无装备容器。
## equip/load 时 apply_derived_stats 把容器物品 stat_mods 折进 base (取代旧投影期 _fold_equipment_stats)。
var equipment_container_id := -1
var attribute_set: InkMonUnitAttributeSet
var ai_strategy: InkMonAIStrategy

var _move_ability_id := ""
var _basic_attack_ability_id := ""
var _skill_ability_id := ""
var _team_id := -1
var _atb_gauge := 0.0
var _active_skill_config_id := ""


func _init(p_unit_key: String = "", battle_snapshot: Dictionary = {}, save_data: Dictionary = {}) -> void:
	unit_key = p_unit_key
	type = "InkMonUnit"
	attribute_set = InkMonUnitAttributeSet.new(get_id())
	if not save_data.is_empty():
		_setup_from_save_data(save_data)
	elif not battle_snapshot.is_empty():
		_setup_from_battle_snapshot(battle_snapshot)
	else:
		_setup_from_unit_config(p_unit_key)
	ability_set = InkMonBattleAbilitySet.create_battle_ability_set(get_id(), attribute_set)
	ai_strategy = InkMonAIStrategyFactory.get_strategy(personality)


static func from_battle_snapshot(battle_snapshot: Dictionary) -> InkMonUnitActor:
	return InkMonUnitActor.new("", battle_snapshot)


## adr/0001 自序列化: 从存档持久切片建活 actor。只还原身份/选择/进度字段;
## 派生六维 + 当前 HP 由编排方 (GI) 在装备容器就绪后调 apply_derived_stats(species_base) → set_current_hp(saved)
## 完成 (species base 数据住 SpeciesCatalog/main 层, 不在本 actor 引用, 保 battle 层不上引 main)。
static func from_dict(data: Dictionary) -> InkMonUnitActor:
	return InkMonUnitActor.new("", {}, data)


func _setup_from_unit_config(p_unit_key: String) -> void:
	Log.assert_crash(p_unit_key != "", "InkMonUnitActor", "unit_key is required for config path")
	var cfg := InkMonUnitConfig.get_unit_config(unit_key)
	_display_name = cfg.display_name
	species = cfg.species
	stage = cfg.stage
	personality = cfg.personality
	elements.assign(cfg.elements)
	level = 1
	exp = 0
	_active_skill_config_id = cfg.active_skill_id
	skill_slots = [{"slot_index": 0, "skill_id": cfg.active_skill_id}]

	var stats := cfg.stats
	attribute_set.set_max_hp_base(stats["max_hp"])
	attribute_set.set_hp_base(stats["hp"])
	attribute_set.set_ad_base(stats["ad"])
	attribute_set.set_ap_base(stats["ap"])
	attribute_set.set_armor_base(stats["armor"])
	attribute_set.set_mr_base(stats["mr"])
	attribute_set.set_speed_base(stats["speed"])


func _setup_from_battle_snapshot(battle_snapshot: Dictionary) -> void:
	source_entry_id = int(battle_snapshot.get("source_entry_id", -1))
	Log.assert_crash(source_entry_id >= 0, "InkMonUnitActor", "battle snapshot missing source_entry_id")
	species = str(battle_snapshot.get("species", ""))
	personality = str(battle_snapshot.get("personality", InkMonUnitConfig.PERSONALITY_AGGRESSIVE))
	stage = str(battle_snapshot.get("stage", InkMonUnitConfig.STAGE_BABY))
	unit_key = "snapshot:%d" % source_entry_id
	_display_name = str(battle_snapshot.get("display_name", species))
	skill_slots = _read_skill_slots(battle_snapshot.get("skill_slots", []))
	Log.assert_crash(not skill_slots.is_empty(), "InkMonUnitActor", "battle snapshot missing skill_slots")
	_active_skill_config_id = str(skill_slots[0].get("skill_id", ""))
	Log.assert_crash(_active_skill_config_id != "", "InkMonUnitActor", "battle snapshot primary slot missing skill_id")
	engravings = _read_engravings(battle_snapshot.get("engravings", []))
	elements.clear()
	var raw_elements := battle_snapshot.get("elements", []) as Array
	Log.assert_crash(raw_elements != null and not raw_elements.is_empty(), "InkMonUnitActor",
		"battle snapshot missing elements")
	for raw_element in raw_elements:
		elements.append(str(raw_element))

	var stats := battle_snapshot.get("battle_stats", {}) as Dictionary
	Log.assert_crash(stats != null, "InkMonUnitActor", "battle snapshot battle_stats must be a Dictionary")
	for key in InkMonUnitConfig.BASE_STAT_KEYS:
		Log.assert_crash(stats.has(key), "InkMonUnitActor", "battle snapshot stats missing key: %s" % key)
	var max_hp := float(stats["max_hp"])
	attribute_set.set_max_hp_base(max_hp)
	attribute_set.set_hp_base(max_hp)
	attribute_set.set_ad_base(float(stats["ad"]))
	attribute_set.set_ap_base(float(stats["ap"]))
	attribute_set.set_armor_base(float(stats["armor"]))
	attribute_set.set_mr_base(float(stats["mr"]))
	attribute_set.set_speed_base(float(stats["speed"]))


## adr/0001 自序列化 load 路径: 从存档持久切片还原身份/选择/进度。
## 派生六维不在此设 (留默认), 由编排方在装备容器就绪后调 apply_derived_stats(species_base);
## 当前 HP 同理由编排方 set_current_hp(saved hp) 还原 (carryover)。
func _setup_from_save_data(data: Dictionary) -> void:
	species = str(data.get("species_id", ""))
	Log.assert_crash(species != "", "InkMonUnitActor", "save data missing species_id")
	_display_name = str(data.get("name_en", species))
	stage = str(data.get("stage", InkMonUnitConfig.STAGE_BABY))
	# personality 派生不存 (adr/0008 interim): 读档时由 species 重新派生。
	personality = InkMonUnitConfig.get_personality_for_species(species)
	unit_key = "save:%s" % species
	level = maxi(1, int(data.get("level", 1)))
	exp = maxi(0, int(data.get("exp", 0)))
	skill_slots = _read_skill_slots(data.get("skill_slots", []))
	Log.assert_crash(not skill_slots.is_empty(), "InkMonUnitActor", "save data missing skill_slots")
	_active_skill_config_id = str(skill_slots[0].get("skill_id", ""))
	Log.assert_crash(_active_skill_config_id != "", "InkMonUnitActor", "save data primary slot missing skill_id")
	engravings = _read_engravings(data.get("engravings", []))
	elements.clear()
	var raw_elements := data.get("elements", []) as Array
	if raw_elements != null:
		for raw_element in raw_elements:
			elements.append(str(raw_element))


func equip_abilities(game_state_provider: Variant = null) -> void:
	var move_ability := Ability.new(InkMonMove.ABILITY, get_id())
	ability_set.grant_ability(move_ability, game_state_provider)
	_move_ability_id = move_ability.id

	var basic_attack := Ability.new(InkMonBasicAttack.ABILITY, get_id())
	ability_set.grant_ability(basic_attack, game_state_provider)
	_basic_attack_ability_id = basic_attack.id

	# primary skill = slot0; basic_attack 已无条件授予, 不重复授予 (防 primary==basic)。
	if _active_skill_config_id != "" and _active_skill_config_id != InkMonBasicAttack.CONFIG_ID:
		var skill_config := InkMonAllSkills.get_skill_config(_active_skill_config_id)
		var skill_ability := Ability.new(skill_config, get_id())
		ability_set.grant_ability(skill_ability, game_state_provider)
		_skill_ability_id = skill_ability.id

	var math_passive := Ability.new(InkMonDamageMathPassive.ABILITY, get_id())
	ability_set.grant_ability(math_passive, game_state_provider)

	# 刻印: 每条 engraving grant 一个刻印被动 (LGF passive 强化技能输出, §8c)。
	for _engraving in engravings:
		var engraving_passive := Ability.new(InkMonEngravingPassive.ABILITY, get_id())
		ability_set.grant_ability(engraving_passive, game_state_provider)


static func _read_skill_slots(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var source := value as Array
	if source == null:
		return result
	for item in source:
		var slot := item as Dictionary
		if slot == null:
			continue
		result.append({
			"slot_index": int(slot.get("slot_index", result.size())),
			"skill_id": str(slot.get("skill_id", "")),
		})
	return result


static func _read_engravings(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var source := value as Array
	if source == null:
		return result
	for item in source:
		var engraving := item as Dictionary
		if engraving == null:
			continue
		result.append({
			"engraving_id": str(engraving.get("engraving_id", "")),
			"target_slot": int(engraving.get("target_slot", -1)),
		})
	return result


func get_attribute_set() -> InkMonUnitAttributeSet:
	return attribute_set


func set_team_id(id: int) -> void:
	_team_id = id
	_team = str(id)


func get_team_id() -> int:
	return _team_id


func get_primary_element() -> String:
	if elements.is_empty():
		return ""
	return elements[0]


func get_move_ability() -> Ability:
	return ability_set.find_ability_by_id(_move_ability_id)


func get_basic_attack_ability() -> Ability:
	return ability_set.find_ability_by_id(_basic_attack_ability_id)


func get_skill_ability() -> Ability:
	return ability_set.find_ability_by_id(_skill_ability_id)


func get_atb_gauge() -> float:
	return _atb_gauge


func accumulate_atb(dt: float) -> void:
	_atb_gauge += (attribute_set.speed / 1000.0) * dt


func can_act() -> bool:
	if _atb_gauge < ATB_FULL:
		return false
	if ability_set != null and ability_set.has_tag(InkMonActionLockStatus.TAG_CANT_ACT):
		return false
	return true


func reset_atb() -> void:
	_atb_gauge = 0.0


func get_stats() -> Dictionary:
	return {
		"hp": attribute_set.hp,
		"max_hp": attribute_set.max_hp,
		"ad": attribute_set.ad,
		"ap": attribute_set.ap,
		"armor": attribute_set.armor,
		"mr": attribute_set.mr,
		"speed": attribute_set.speed,
	}


func get_primary_skill_id() -> String:
	if skill_slots.is_empty():
		return ""
	return str(skill_slots[0].get("skill_id", ""))


func add_exp(amount: int) -> void:
	exp = maxi(0, exp + amount)


## 派生六维 = species_base × 等级缩放 + 装备 stat_mods (flat)。写进 attribute base (取代旧投影折叠)。
## 不动当前 HP (carryover 由 set_current_hp 单独管)。species_base 由编排方 (持 SpeciesCatalog 的 GI) 传入,
## 保 battle 层不上引 main 层 SpeciesCatalog。可重复调 (equip/level-up 后重算, 幂等)。
func apply_derived_stats(species_base: Dictionary) -> void:
	var scale := 1.0 + float(level - 1) * LEVEL_GROWTH
	var mods := _equipment_mods()
	attribute_set.set_max_hp_base(float(species_base.get("max_hp", 0.0)) * scale + float(mods.get("max_hp", 0.0)))
	attribute_set.set_ad_base(float(species_base.get("ad", 0.0)) * scale + float(mods.get("ad", 0.0)))
	attribute_set.set_ap_base(float(species_base.get("ap", 0.0)) * scale + float(mods.get("ap", 0.0)))
	attribute_set.set_armor_base(float(species_base.get("armor", 0.0)) * scale + float(mods.get("armor", 0.0)))
	attribute_set.set_mr_base(float(species_base.get("mr", 0.0)) * scale + float(mods.get("mr", 0.0)))
	attribute_set.set_speed_base(float(species_base.get("speed", 0.0)) * scale + float(mods.get("speed", 0.0)))


## 设置当前 HP (carryover)。value < 0 = 满血 (= max_hp);否则按值设 (attribute_set 对 hp>max_hp 自动 clamp)。
func set_current_hp(value: float) -> void:
	var hp := value
	if hp < 0.0:
		hp = attribute_set.max_hp
	attribute_set.set_hp_base(hp)


## adr/0001 读档统一入口: 先按 species_base 重算派生六维 (含装备折叠), 再还原 carryover HP。
## 顺序固定于此, 消除"apply_derived_stats 必须先于 set_current_hp"的调用方锐边
## (set_current_hp 满血分支读 max_hp, 须在 apply 之后才正确)。
## 前置: 调用方 (GI) 若有装备须已注册容器 + 还原物品 + 设 equipment_container_id, 装备 mods 才会被折入。
func restore_persistent_state(species_base: Dictionary, saved_hp: float) -> void:
	apply_derived_stats(species_base)
	set_current_hp(saved_hp)


## adr/0001 持久切片: 身份 + 选择 + 进度 + 当前 HP (carryover) + 装备容器内物品。
## **不**含派生六维 (max_hp/ad/...) —— 读档时 apply_derived_stats(species_base) 重算。
func to_dict() -> Dictionary:
	return {
		"species_id": species,
		"name_en": _display_name,
		"stage": stage,
		"elements": elements.duplicate(),
		"level": level,
		"exp": exp,
		"skill_slots": _dup_dict_array(skill_slots),
		"engravings": _dup_dict_array(engravings),
		"hp": attribute_set.hp,
		"equipment": _capture_equipment_items(),
	}


## 装备容器内物品的 stat_mods flat 累加 (× count)。容器未设 → 空。取代旧 _fold_equipment_stats。
func _equipment_mods() -> Dictionary:
	var mods := {}
	if equipment_container_id <= 0:
		return mods
	for item_id in ItemSystem.get_items_in_container(equipment_container_id):
		var snap := ItemSystem.get_item_snapshot(item_id)
		if snap.is_empty():
			continue
		var config := ItemSystem.get_item_config(StringName(str(snap.get("config_id", ""))))
		var stat_mods := config.get("stat_mods", {}) as Dictionary
		if stat_mods == null:
			continue
		var count := int(snap.get("count", 1))
		for key in stat_mods:
			mods[key] = float(mods.get(key, 0.0)) + float(stat_mods[key]) * count
	return mods


## 装备容器内物品快照 (config_id/count/slot_index), 进存档; 容器 id (runtime) 不进。
func _capture_equipment_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if equipment_container_id <= 0:
		return result
	for item_id in ItemSystem.get_items_in_container(equipment_container_id):
		var snap := ItemSystem.get_item_snapshot(item_id)
		if snap.is_empty():
			continue
		result.append({
			"config_id": str(snap.get("config_id", "")),
			"count": int(snap.get("count", 1)),
			"slot_index": int(snap.get("slot_index", -1)),
		})
	return result


static func _dup_dict_array(source: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in source:
		result.append(item.duplicate(true))
	return result


func _get_config_id() -> String:
	return unit_key


func _get_team_int() -> int:
	return _team_id


func get_attribute_snapshot() -> Dictionary:
	var snap := get_stats()
	snap["unit_key"] = unit_key
	snap["source_entry_id"] = source_entry_id
	snap["personality"] = personality
	snap["elements"] = elements.duplicate()
	return snap


func serialize() -> Dictionary:
	var base := super.serialize()
	base["unit_key"] = unit_key
	base["source_entry_id"] = source_entry_id
	base["personality"] = personality
	base["atb_gauge"] = _atb_gauge
	return base
