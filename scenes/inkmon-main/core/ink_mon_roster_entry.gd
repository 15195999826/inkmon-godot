class_name InkMonRosterEntry
extends RefCounted


const STAT_KEYS: Array[String] = ["max_hp", "ad", "ap", "armor", "mr", "speed"]

## v1 占位线性成长: level-1 = 物种 base (战斗平衡不变), 之后每级 +LEVEL_GROWTH 倍。
## 公式由 lab 待定 (docs/main-game-architecture.md §9); 调整不影响 entry 结构 (只存 level)。
const LEVEL_GROWTH := 0.05


var entry_id := 0
## 全局唯一身份键 (adr/0010)。stub 模式 = 物种字符串 (cinder_kit); contract 模式 = mon_NNNN。
## 一切寻址 (SpeciesCatalog 查询 / 进化) 走它; 进化只改它不换 entry_id。
var species_id := ""
## 显示名 (name_en)。仅展示用, 非 key; 进化时随 species_id 一并更新。
var name_en := ""
var stage := ""
var elements: Array[String] = []
var level := 1
var exp := 0
# 存"哪槽选了哪技能", 不存数值变异 (§8c-decision)。
var skill_slots: Array[Dictionary] = []
# 刻印: 每条显式指明强化哪个 skill_slot (target_slot 对应 skill_slots[].slot_index)。
var engravings: Array[Dictionary] = []
var equipment_container := ""


static func from_unit_config(p_entry_id: int, unit_key: String) -> InkMonRosterEntry:
	var cfg := InkMonUnitConfig.get_unit_config(unit_key)
	var entry := InkMonRosterEntry.new()
	entry.entry_id = p_entry_id
	entry.species_id = cfg.species
	entry.name_en = cfg.display_name
	entry.stage = cfg.stage
	entry.elements.assign(cfg.elements)
	entry.skill_slots = [{"slot_index": 0, "skill_id": cfg.active_skill_id}]
	entry.engravings = []
	entry.equipment_container = "equip:%d" % p_entry_id
	return entry


## 出生 = 确定性 roll 每槽技能 (§8c)。用于程序化出生 (领养/未来捕获);
## 起始队伍仍走 from_unit_config (设计出生, 不 roll, 保 M1 平衡)。
static func from_birth(p_entry_id: int, p_species_id: String, p_roll_seed: int) -> InkMonRosterEntry:
	var entry := InkMonRosterEntry.new()
	entry.entry_id = p_entry_id
	entry.species_id = p_species_id
	# Display name + stage + elements via the catalog so a static-content species
	# gets its projected values; stub species delegate back to UnitConfig (identical
	# behaviour). get_display_name falls back to the species_id itself when no name exists.
	entry.name_en = InkMonSpeciesCatalog.get_display_name(p_species_id)
	entry.stage = InkMonSpeciesCatalog.get_stage(p_species_id)
	entry.elements = InkMonSpeciesCatalog.get_elements(p_species_id)
	entry.skill_slots = InkMonSpeciesCatalog.roll_birth_skill_slots(p_species_id, p_roll_seed)
	entry.engravings = []
	entry.equipment_container = "equip:%d" % p_entry_id
	return entry


static func from_dict(data: Dictionary) -> InkMonRosterEntry:
	var entry := InkMonRosterEntry.new()
	entry.entry_id = int(data.get("entry_id", 0))
	entry.species_id = str(data.get("species_id", ""))
	entry.name_en = str(data.get("name_en", ""))
	entry.stage = str(data.get("stage", ""))
	entry.elements = _string_array(data.get("elements", []))
	entry.level = int(data.get("level", 1))
	entry.exp = int(data.get("exp", 0))
	entry.skill_slots = _skill_slots_from_data(data.get("skill_slots", []))
	entry.engravings = _engravings_from_data(data.get("engravings", []))
	entry.equipment_container = str(data.get("equipment_container", "equip:%d" % entry.entry_id))
	return entry


func to_dict() -> Dictionary:
	return {
		"entry_id": entry_id,
		"species_id": species_id,
		"name_en": name_en,
		"stage": stage,
		"elements": elements.duplicate(),
		"level": level,
		"exp": exp,
		"skill_slots": _dup_dict_array(skill_slots),
		"engravings": _dup_dict_array(engravings),
		"equipment_container": equipment_container,
	}


## 六维属性 = f(species, level) 运行时派生, 不进 entry (§8c-decision)。
## base 走 SpeciesCatalog (覆盖进化形态; baby 委托回 unit_config)。
func derive_battle_stats() -> Dictionary:
	var base := InkMonSpeciesCatalog.get_base_stats(species_id)
	var scale := 1.0 + float(level - 1) * LEVEL_GROWTH
	var stats := {}
	for key in STAT_KEYS:
		stats[key] = float(base.get(key, 0.0)) * scale
	return stats


func get_primary_skill_id() -> String:
	if skill_slots.is_empty():
		return ""
	return str(skill_slots[0].get("skill_id", ""))


func project_to_battle_snapshot() -> Dictionary:
	# P3: snapshot 投影 skill_slots (集合) + 派生 stats。actor primary = slot0。
	# P8: 投影 engravings (刻印), actor grant 刻印被动强化技能。
	return {
		"source_entry_id": entry_id,
		# battle 层 InkMonUnitActor 读 snapshot["species"] (身份/显示兜底) + snapshot["display_name"]
		# (显示)。其 species 词汇 = 本层 species_id (跨层映射在此边界翻译), 故 battle 层零改动。
		"species": species_id,
		"display_name": name_en,
		# stage 投影: actor 读 snapshot.get("stage", BABY); 不发会让进化后的 mature/adult 单位
		# 在 battle 层退回 baby。entry.stage 进化时已更新 (evolve_entry), 此处随身份一并过边界。
		"stage": stage,
		# INTERIM(adr/0008):AI personality 投影时由 species 派生(不存 entry,§8c 派生不存);
		# 未来 personality 走 canon 字段,这里换成投影的 canon 值。
		"personality": InkMonUnitConfig.get_personality_for_species(species_id),
		"elements": elements.duplicate(),
		"skill_slots": _dup_dict_array(skill_slots),
		"engravings": _dup_dict_array(engravings),
		"battle_stats": derive_battle_stats(),
	}


func add_exp(amount: int) -> void:
	exp = max(0, exp + amount)


static func _skill_slots_from_data(value: Variant) -> Array[Dictionary]:
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


static func _engravings_from_data(value: Variant) -> Array[Dictionary]:
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


static func _dup_dict_array(source: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in source:
		result.append(item.duplicate(true))
	return result


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	var source := value as Array
	if source == null:
		return result
	for item in source:
		result.append(str(item))
	return result
