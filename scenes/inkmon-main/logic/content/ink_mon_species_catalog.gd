class_name InkMonSpeciesCatalog
## 物种数据 = 主游戏内容真相 (出生 / 进化)。每形态 = 一条独立 species 条目 (docs/main-game-architecture.md §8c)。
##
## - 物种 base 六维 (level-1 baseline): 正确模型 = 每形态独立物种、有自己的显式 base。
##   v1 stub 占位: baby 委托 battle 层 InkMonUnitConfig; 进化形态 = root(baby) base × stat_mult
##   (没真数据时凑数, 不手敲)。canon override (server 桥) 命中时改用该物种自己的显式 base,
##   取代上面的 stub 占位 (见 _overrides)。最终战斗属性 = base × 等级缩放 (见
##   ink_mon_roster_entry.gd::derive_battle_stats), 不在本类。
## - 技能池: per-(species, slot) 候选 skill_id; 出生每槽确定性 roll 一个。
## - 进化链: species -> {species: <next>, level: <阈值>}; species 字段改写, entry_id 不变。
## - X->X2: SKILL_EVOLUTIONS 把某技能映射到进化后技能 (改对应 slot 的 skill_id)。
##   v1 X2 目标复用现有真实技能 (占位); 真正独立 X2 ability 随 lab 内容落地。
##
## 不接 lab 真数据 (Non-Goal): 下面物种 / 池 / 链全为手搓 stub。

const STAGE_BABY := "baby"
const STAGE_MATURE := "mature"
const STAGE_ADULT := "adult"

## X->X2: skill_id -> 进化后 skill_id (进化时改对应 slot)。
const SKILL_EVOLUTIONS := {
	"inkmon_fireball": "inkmon_chain_lightning",
}

static var _table: Dictionary = {}

## Server creature-base overrides (canon→godot bridge). Keyed by BOTH the original
## species key and its snake_case normalization → {base_stats, stage}. An override IS
## the canonical per-species base (each stage is its own species with explicit stats);
## it supersedes the v1 stub's placeholder root×mult derivation for that species.
## has_species/get_stage/get_base_stats consult it first; skill pools / SKILL_EVOLUTIONS
## stay stub. Written by InkMonContentLoader at boot; never serialized into the stub table.
static var _overrides: Dictionary = {}


static func has_species(species: String) -> bool:
	if not _override_for(species).is_empty():
		return true
	return _species_table().has(species)


static func get_stage(species: String) -> String:
	var ov := _override_for(species)
	if not ov.is_empty():
		return str(ov.get("stage", STAGE_BABY))
	return str(_species_node(species).get("stage", STAGE_BABY))


## 物种 base 六维 (level-1 baseline)。命中 canon override → 直接返回该物种自己的显式 base
## (每形态独立)。否则走 v1 stub 占位: root(baby) base × stat_mult (baby root=self / mult=1.0)。
static func get_base_stats(species: String) -> Dictionary:
	var ov := _override_for(species)
	if not ov.is_empty():
		return (ov.get("base_stats", {}) as Dictionary).duplicate(true)
	var node := _species_node(species)
	var root := str(node.get("root", species))
	var mult := float(node.get("mult", 1.0))
	var base := InkMonUnitConfig.get_species_base_stats(root)
	var scaled := {}
	for key in base:
		scaled[key] = float(base[key]) * mult
	return scaled


## 物种元素。命中 canon override → server 投影的 elements;否则委托 battle 层 UnitConfig
## (stub 物种行为不变)。catalog 是物种内容真相, 故元素也由它统一供给(见 RosterEntry.from_birth)。
static func get_elements(species: String) -> Array[String]:
	var ov := _override_for(species)
	if not ov.is_empty():
		var result: Array[String] = []
		for element_value in (ov.get("elements", []) as Array):
			result.append(str(element_value))
		return result
	return InkMonUnitConfig.get_elements_for_species(species)


## Register a server creature base as a runtime override (see _overrides). Stored
## under both the original key and its snake_case form so callers can query either.
## The FULL validated creature base is kept (stats + stage + elements) — nothing the
## contract carries is silently dropped. Stats are float-coerced to match the stub
## path's guarantee (JSON integer literals parse to int); an empty species/base_stats
## is ignored so a malformed entry falls through to the normal unknown-species assert
## rather than spawning a zero-stat unit.
static func register_override(
	species: String, base_stats: Dictionary, stage: String, elements: Array[String]
) -> void:
	if species == "" or base_stats.is_empty():
		return
	var stats := {}
	for key in base_stats:
		stats[key] = float(base_stats[key])
	var payload := {"base_stats": stats, "stage": stage, "elements": elements.duplicate()}
	_overrides[species] = payload
	var norm := normalize_species_key(species)
	if norm != species:
		_overrides[norm] = payload


## Drop all server overrides (revert to pure stub). Tests must call this to isolate
## the static override table between scenes sharing a process.
static func clear_overrides() -> void:
	_overrides.clear()


## CamelCase / mixed → snake_case species key, e.g. "MossBear" → "moss_bear".
## Idempotent on already-snake keys. Char-based (no RegEx alloc on the stat path).
static func normalize_species_key(name: String) -> String:
	var out := ""
	for i in range(name.length()):
		var ch := name[i]
		var is_upper := ch != ch.to_lower() and ch == ch.to_upper()
		if is_upper and i > 0:
			out += "_"
		out += ch.to_lower()
	return out


## Override payload for `species` (exact key first, then normalized), or {} if none.
static func _override_for(species: String) -> Dictionary:
	# Fast path: no imports applied (the default — res://data absent) → never pay the
	# normalize_species_key string build on the runtime stat-read path.
	if _overrides.is_empty():
		return {}
	if _overrides.has(species):
		return _overrides[species]
	var norm := normalize_species_key(species)
	if _overrides.has(norm):
		return _overrides[norm]
	return {}


## 技能池 / 进化只在 stub 表里。override-only 的 server 物种(creature 基底, 无技能/进化元数据,
## skill 是后续阶段 Non-Goal) → 优雅返回 0 槽 / 空池 / 无进化, 而非 assert。用 _node_or_empty
## 而非 _species_node: override-only 给 {}, 真未知才 assert。
static func get_slot_count(species: String) -> int:
	return (_node_or_empty(species).get("pools", []) as Array).size()


static func get_slot_pool(species: String, slot_index: int) -> Array[String]:
	var pools := _node_or_empty(species).get("pools", []) as Array
	var result: Array[String] = []
	if slot_index < 0 or slot_index >= pools.size():
		return result
	for skill_id in pools[slot_index]:
		result.append(str(skill_id))
	return result


## 进化链查询: 返回 {species, level} 或空 {} (无下一形态 / override-only 物种)。
static func get_evolution(species: String) -> Dictionary:
	var evo := _node_or_empty(species).get("evolves_to", {}) as Dictionary
	if evo == null or evo.is_empty():
		return {}
	return {"species": str(evo.get("species", "")), "level": int(evo.get("level", 0))}


## X->X2 查询: 返回进化后 skill_id, 无则 ""。
static func get_skill_evolution(skill_id: String) -> String:
	return str(SKILL_EVOLUTIONS.get(skill_id, ""))


## 确定性: 给定 (species, slot_index, seed) 总是 roll 出同一 skill_id。
static func roll_skill_for_slot(species: String, slot_index: int, roll_seed: int) -> String:
	var pool := get_slot_pool(species, slot_index)
	if pool.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = _slot_seed(roll_seed, slot_index)
	var idx := int(rng.randi() % pool.size())
	return pool[idx]


## 出生 roll: 每槽确定性 roll 一个技能 (§8c 出生唯一随机)。
static func roll_birth_skill_slots(species: String, roll_seed: int) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var count := get_slot_count(species)
	for i in range(count):
		slots.append({"slot_index": i, "skill_id": roll_skill_for_slot(species, i, roll_seed)})
	return slots


## 进化 (模型 B): 阈值达成则改写 species/stage, 保留旧 slot, X->X2 升级, 新阶段新增 slot roll 一次。
## entry_id 不变 (进化是变身非换只)。返回是否发生进化。
static func evolve_entry(entry: InkMonRosterEntry) -> bool:
	var evo := get_evolution(entry.species)
	if evo.is_empty():
		return false
	if entry.level < int(evo.get("level", 0)):
		return false
	var next_species := str(evo.get("species", ""))
	if not has_species(next_species):
		return false

	# 1. X->X2: 旧 slot 中可进化的技能改写 skill_id。
	for slot in entry.skill_slots:
		var upgraded := get_skill_evolution(str(slot.get("skill_id", "")))
		if upgraded != "":
			slot["skill_id"] = upgraded
	# 2. 新阶段新增 slot (高于旧 slot 数的部分) → roll 一次写 skill_id。
	var old_count := entry.skill_slots.size()
	var new_count := get_slot_count(next_species)
	for i in range(old_count, new_count):
		entry.skill_slots.append({
			"slot_index": i,
			"skill_id": roll_skill_for_slot(next_species, i, entry.entry_id),
		})
	# 3. 改写 species + stage (entry_id 不变)。
	entry.species = next_species
	entry.stage = get_stage(next_species)
	return true


static func _slot_seed(roll_seed: int, slot_index: int) -> int:
	return roll_seed * 1000003 + slot_index


static func _species_node(species: String) -> Dictionary:
	var table := _species_table()
	Log.assert_crash(table.has(species), "InkMonSpeciesCatalog", "unknown species: %s" % species)
	return table[species]


## stub 表节点, 或 {} 表示 override-only 物种(有 override 但不在 stub 表 → 无技能池/无进化:
## 契约只搬 creature 基底, 技能/进化元数据是后续阶段)。仅"既非 stub 又无 override"的真未知
## 物种 assert(保留响亮失败)。供 get_slot_count/get_slot_pool/get_evolution 用。
static func _node_or_empty(species: String) -> Dictionary:
	var table := _species_table()
	if table.has(species):
		return table[species]
	if not _override_for(species).is_empty():
		return {}
	Log.assert_crash(false, "InkMonSpeciesCatalog", "unknown species: %s" % species)
	return {}


static func _species_table() -> Dictionary:
	if _table.is_empty():
		_table = _build_table()
	return _table


static func _build_table() -> Dictionary:
	# 技能池只放"可选主动技能"; basic_attack 是通用平A (每只 equip 时自动授予),
	# 不进池 —— 否则 roll 进 slot0 会让 equip_abilities 重复授予 basic 且无真正主动技能。
	var fireball := InkMonFireball.CONFIG_ID
	var chain := InkMonChainLightning.CONFIG_ID
	var poison := InkMonPoison.CONFIG_ID
	var heal := InkMonHolyHeal.CONFIG_ID
	var stun := InkMonStun.CONFIG_ID
	return {
		# --- 起始队伍 4 物种 (带进化链) ---
		"aegis_pup": {
			"stage": STAGE_BABY, "root": "aegis_pup", "mult": 1.0,
			"pools": [[stun, poison]],
			"evolves_to": {"species": "aegis_warden", "level": 5},
		},
		"aegis_warden": {
			"stage": STAGE_MATURE, "root": "aegis_pup", "mult": 1.4,
			"pools": [[stun, poison], [heal, stun]],
			"evolves_to": {},
		},
		"cinder_kit": {
			"stage": STAGE_BABY, "root": "cinder_kit", "mult": 1.0,
			"pools": [[fireball, chain]],
			"evolves_to": {"species": "cinder_fox", "level": 5},
		},
		"cinder_fox": {
			"stage": STAGE_MATURE, "root": "cinder_kit", "mult": 1.4,
			"pools": [[fireball, chain], [poison, fireball]],
			"evolves_to": {"species": "cinder_drake", "level": 10},
		},
		"cinder_drake": {
			"stage": STAGE_ADULT, "root": "cinder_kit", "mult": 1.8,
			"pools": [[fireball, chain], [poison, fireball], [stun, chain]],
			"evolves_to": {},
		},
		"halo_sprout": {
			"stage": STAGE_BABY, "root": "halo_sprout", "mult": 1.0,
			"pools": [[heal, stun]],
			"evolves_to": {"species": "halo_bloom", "level": 5},
		},
		"halo_bloom": {
			"stage": STAGE_MATURE, "root": "halo_sprout", "mult": 1.4,
			"pools": [[heal, stun], [heal, poison]],
			"evolves_to": {},
		},
		"gale_mote": {
			"stage": STAGE_BABY, "root": "gale_mote", "mult": 1.0,
			"pools": [[chain, fireball]],
			"evolves_to": {"species": "gale_sprite", "level": 5},
		},
		"gale_sprite": {
			"stage": STAGE_MATURE, "root": "gale_mote", "mult": 1.4,
			"pools": [[chain, fireball], [poison, stun]],
			"evolves_to": {},
		},
		# --- 其余 baby 物种 (敌方/领养来源; 无进化链, 单技能池; 收录以覆盖 derive) ---
		"brine_bulwark": {"stage": STAGE_BABY, "root": "brine_bulwark", "mult": 1.0, "pools": [[stun]], "evolves_to": {}},
		"ember_wisp": {"stage": STAGE_BABY, "root": "ember_wisp", "mult": 1.0, "pools": [[fireball]], "evolves_to": {}},
		"lumen_bud": {"stage": STAGE_BABY, "root": "lumen_bud", "mult": 1.0, "pools": [[heal]], "evolves_to": {}},
		"umbral_pin": {"stage": STAGE_BABY, "root": "umbral_pin", "mult": 1.0, "pools": [[poison]], "evolves_to": {}},
	}
