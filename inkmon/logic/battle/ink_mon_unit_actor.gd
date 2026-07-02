class_name InkMonUnitActor
extends InkMonBattleActor


const ATB_FULL := 100.0

## v1 占位线性成长 (adr/0001 / docs §9): level-1 = 物种 base (M1 平衡不变), 之后每级 +LEVEL_GROWTH 倍。
## 派生六维 base = species_base × (1 + (level-1)*LEVEL_GROWTH); 装备数值不进 base, 走加成层 (adr/0004)。
const LEVEL_GROWTH := 0.05


## 等级缩放纯函数 (docs §9 线性成长单一真相): 战斗派生六维 (apply_derived_stats) 与进化 stat-gate
## (SpeciesCatalog._eval_condition_stat) 共用 —— 缩放模型变更 (如改 f(species,level)) 只改此处, 两口径同步。
static func growth_scale(level_value: int) -> float:
	return 1.0 + float(level_value - 1) * LEVEL_GROWTH


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
## equip/load 时 apply_derived_stats 调 _refresh_equipment_abilities, 把容器物品 stat_mods 现场拼成
## 通用装备 ability grant 进加成层 (adr/0004; 不再焊进 base)。
var equipment_container_id := -1
var attribute_set: InkMonUnitAttributeSet
var ai_strategy: InkMonAIStrategy

var _move_ability_id := ""
var _basic_attack_ability_id := ""
var _skill_ability_id := ""
## 当前已 grant 的装备通用 ability 的 instance id (adr/0004; runtime, 不进存档)。
## 加成层 modifier 的 source = 这些 ability id; 重建装备时按 id 精确清旧 (remove_modifiers_by_source) 再重 grant,
## 故跨战斗 (reset_battle_runtime 换 ability_set) 与多次 apply_derived_stats 都幂等、不累加。
var _equipment_ability_ids: Array[String] = []
var _team_id := -1
var _atb_gauge := 0.0


func _init(p_unit_key: String = "", p_save_data: Dictionary = {}, p_combat_data: Dictionary = {}) -> void:
	unit_key = p_unit_key
	type = "InkMonUnit"
	attribute_set = InkMonUnitAttributeSet.new(get_id())
	if not p_save_data.is_empty():
		_setup_from_save_data(p_save_data)
	elif not p_combat_data.is_empty():
		_setup_combat_unit(p_combat_data)
	else:
		_setup_from_unit_config(p_unit_key)
	ability_set = InkMonBattleAbilitySet.create_battle_ability_set(get_id(), attribute_set)
	ai_strategy = InkMonAIStrategyFactory.get_strategy(personality)


## adr/0001 自序列化: 从存档持久切片建活 actor。只还原身份/选择/进度字段;
## 派生六维 + 当前 HP 由编排方 (GI) 在装备容器就绪后调 apply_derived_stats(species_base) → set_current_hp(saved)
## 完成 (species base 数据住 SpeciesCatalog/main 层, 不在本 actor 引用, 保 battle 层不上引 main)。
static func from_dict(data: Dictionary) -> InkMonUnitActor:
	return InkMonUnitActor.new("", data)


## 临时对战单位 (训练假人 / 敌方): 显式身份 + 显式六维, 非持久 roster
## (不进存档, battle 结束随 _reset_battle_state 整只移除)。取代旧 battle-snapshot 投影路径 ——
## 玩家 roster 不再投影成临时 actor, 唯此路径建非 roster 的对战单位。
static func create_combat_unit(combat_data: Dictionary) -> InkMonUnitActor:
	return InkMonUnitActor.new("", {}, combat_data)


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
	skill_slots = [{"slot_index": 0, "skill_id": cfg.active_skill_id}]

	var stats := cfg.stats
	attribute_set.set_max_hp_base(stats["max_hp"])
	attribute_set.set_hp_base(stats["hp"])
	attribute_set.set_ad_base(stats["ad"])
	attribute_set.set_ap_base(stats["ap"])
	attribute_set.set_armor_base(stats["armor"])
	attribute_set.set_mr_base(stats["mr"])
	attribute_set.set_speed_base(stats["speed"])


## 临时对战单位装配 (训练假人/敌方): 显式身份 + 显式六维。无 source_entry_id (新模型不投影回写)。
func _setup_combat_unit(combat_data: Dictionary) -> void:
	species = str(combat_data.get("species", ""))
	Log.assert_crash(species != "", "InkMonUnitActor", "combat unit missing species")
	personality = str(combat_data.get("personality", InkMonUnitConfig.PERSONALITY_AGGRESSIVE))
	stage = str(combat_data.get("stage", InkMonUnitConfig.STAGE_BABY))
	unit_key = "combat:%s" % species
	_display_name = str(combat_data.get("display_name", species))
	level = 1
	exp = 0
	skill_slots = _read_skill_slots(combat_data.get("skill_slots", []))
	Log.assert_crash(not skill_slots.is_empty(), "InkMonUnitActor", "combat unit missing skill_slots")
	Log.assert_crash(get_primary_skill_id() != "", "InkMonUnitActor", "combat unit primary slot missing skill_id")
	engravings = _read_engravings(combat_data.get("engravings", []))
	elements.clear()
	var raw_elements := combat_data.get("elements", []) as Array
	Log.assert_crash(raw_elements != null and not raw_elements.is_empty(), "InkMonUnitActor",
		"combat unit missing elements")
	for raw_element in raw_elements:
		elements.append(str(raw_element))

	var stats := combat_data.get("battle_stats", {}) as Dictionary
	Log.assert_crash(stats != null, "InkMonUnitActor", "combat unit battle_stats must be a Dictionary")
	for key in InkMonUnitConfig.BASE_STAT_KEYS:
		Log.assert_crash(stats.has(key), "InkMonUnitActor", "combat unit stats missing key: %s" % key)
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
	Log.assert_crash(get_primary_skill_id() != "", "InkMonUnitActor", "save data primary slot missing skill_id")
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

	# primary skill = 当前 skill_slots[0] (单一真相; 局内进化改写 slot0 后此处即取到升级技能, 无陈旧缓存)。
	# basic_attack 已无条件授予, 不重复授予 (防 primary==basic)。
	var primary_skill := get_primary_skill_id()
	if primary_skill != "" and primary_skill != InkMonBasicAttack.CONFIG_ID:
		var skill_config := InkMonAllSkills.get_skill_config(primary_skill)
		var skill_ability := Ability.new(skill_config, get_id())
		ability_set.grant_ability(skill_ability, game_state_provider)
		_skill_ability_id = skill_ability.id

	var math_passive := Ability.new(InkMonDamageMathPassive.ABILITY, get_id())
	ability_set.grant_ability(math_passive, game_state_provider)

	# 刻印: 每条 engraving grant 一个刻印被动 (LGF passive 强化技能输出, §8c)。
	for _engraving in engravings:
		var engraving_passive := Ability.new(InkMonEngravingPassive.ABILITY, get_id())
		ability_set.grant_ability(engraving_passive, game_state_provider)

	# 装备数值 (adr/0004): 把当前装备 stat_mods 现场拼通用 ability grant 进加成层。reset_battle_runtime 换了
	# 新 ability_set, 此处把装备 ability 重建到当前 ability_set (channel ② 富效果 future 也将在此就位);
	# 与 apply_derived_stats 共用同一幂等 reconcile (clear-then-grant), 故重授不累加 —— "每场重授天然对齐"。
	_refresh_equipment_abilities()


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


## 持久 roster actor 跨战斗复用前的战斗运行时重置: 全新 ability_set (避免上一场授予残留导致重复 grant) +
## 清 ability 引用 + 归零 ATB。**不动** attribute_set (HP carryover) / 持久切片 (level/exp/装备)。
## 调用方 (GI) 须在 actor 已注册 (get_id 有效) 后调, 随后 equip_abilities 重新授予。
func reset_battle_runtime() -> void:
	ability_set = InkMonBattleAbilitySet.create_battle_ability_set(get_id(), attribute_set)
	_move_ability_id = ""
	_basic_attack_ability_id = ""
	_skill_ability_id = ""
	_atb_gauge = 0.0
	# 跨战斗复用按 carryover HP 对齐 downed 标记 (上一场 0 血单位下一场仍 downed; 满血则活)。
	sync_downed_state()


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


## 派生六维 base = species_base × 等级缩放 (装备数值不进 base, 走加成层 —— 见 _refresh_equipment_abilities, adr/0004)。
## 不动当前 HP (carryover 由 set_current_hp 单独管)。species_base 由编排方 (持 SpeciesCatalog 的 GI) 传入,
## 保 battle 层不上引 main 层 SpeciesCatalog。可重复调 (equip/level-up 后重算, 幂等)。
func apply_derived_stats(species_base: Dictionary) -> void:
	var scale := growth_scale(level)
	attribute_set.set_max_hp_base(float(species_base.get("max_hp", 0.0)) * scale)
	attribute_set.set_ad_base(float(species_base.get("ad", 0.0)) * scale)
	attribute_set.set_ap_base(float(species_base.get("ap", 0.0)) * scale)
	attribute_set.set_armor_base(float(species_base.get("armor", 0.0)) * scale)
	attribute_set.set_mr_base(float(species_base.get("mr", 0.0)) * scale)
	attribute_set.set_speed_base(float(species_base.get("speed", 0.0)) * scale)
	# 装备数值进加成层 (modifier): base 设好后重建装备 ability, 这样 max_hp 已含装备再做 HP 钳制。
	_refresh_equipment_abilities()
	# set_max_hp_base 只改上限、不回钳已有 hp (cross-attr clamp 仅在 set hp 时触发); max 下调后 hp 可能越界。
	# 重算后把当前 HP 钳回 [0, max_hp] 保派生幂等 (set_current_hp 经 set_hp_base 触发 clamp + 同步 downed)。
	set_current_hp(minf(attribute_set.hp, attribute_set.max_hp))


## 设置当前 HP (carryover)。value < 0 = 满血 (= max_hp);否则按值设 (attribute_set 对 hp>max_hp 自动 clamp)。
func set_current_hp(value: float) -> void:
	var hp := value
	if hp < 0.0:
		hp = attribute_set.max_hp
	attribute_set.set_hp_base(hp)
	# 读档/还原后按 carryover HP 对齐 downed 标记 (0 血 → is_dead, 否则活)。
	sync_downed_state()


## adr/0001 读档统一入口: 先按 species_base 重算派生六维 (含装备加成层重建), 再还原 carryover HP。
## 顺序固定于此, 消除"apply_derived_stats 必须先于 set_current_hp"的调用方锐边
## (set_current_hp 满血分支读 max_hp, 须在 apply 之后才正确)。
## 前置: 调用方 (GI) 若有装备须已注册容器 + 还原物品 + 设 equipment_container_id, 装备 ability 才会被重建进加成层。
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


## adr/0004 装备数值进加成层: 幂等重建装备通用 ability。先清上一轮装备 modifier (按 source 精确), 再按
## 当前装备容器内物品的 stat_mods 现场拼 StatModifierConfig grant 进加成层。装备变更 / 升级 / 读档 / 备战
## (equip_abilities) 时调; 多次调或跨战斗 (ability_set 被 reset 换新) 均不累加。容器未设 → 仅清旧。
func _refresh_equipment_abilities() -> void:
	_clear_equipment_abilities()
	if equipment_container_id <= 0:
		return
	for item_id in ItemSystem.get_items_in_container(equipment_container_id):
		var snap := ItemSystem.get_item_snapshot(item_id)
		if snap.is_empty():
			continue
		var item_config_id := str(snap.get("config_id", ""))
		var config := ItemSystem.get_item_config(StringName(item_config_id))
		var stat_mods := config.get("stat_mods", {}) as Dictionary
		if stat_mods == null or stat_mods.is_empty():
			continue
		var ability := InkMonEquipmentStatAbility.build_ability(
			stat_mods, get_id(), item_config_id, int(snap.get("count", 1)))
		if ability == null:
			continue
		# 不传 game_state_provider: 装备 ability 无 self-trigger 需求 (对齐 hex Phase G)。
		ability_set.grant_ability(ability)
		_equipment_ability_ids.append(ability.id)


## 清除上一轮 grant 的装备 ability 留在加成层的 modifier (source = ability.id), 精确不误伤其它来源。
## 直接对常驻 attribute_set 按 source 移除 (robust): reset_battle_runtime 换了 ability_set 后旧装备 ability
## 已不在当前 set, 其 modifier 仍在常驻 attribute_set 上 —— 故不能靠 revoke 的 on_remove 清。
## 已注册 GameWorld 的 actor 再 revoke 一把清掉残留 ability 对象 (StatModifierComponent.on_remove 经 GameWorld
## 取 attribute_set, 未注册的隔离单元测试 actor 直接 revoke 会 null-deref, 此时加成层已被上面按 source 清净)。
func _clear_equipment_abilities() -> void:
	if _equipment_ability_ids.is_empty():
		return
	var raw := attribute_set.get_raw()
	var registered := GameWorld.get_actor(get_id()) != null
	for ability_id in _equipment_ability_ids:
		raw.remove_modifiers_by_source(ability_id)
		if registered and ability_set != null:
			ability_set.revoke_ability(ability_id)
	_equipment_ability_ids.clear()


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
