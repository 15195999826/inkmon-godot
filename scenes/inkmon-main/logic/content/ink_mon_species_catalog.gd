class_name InkMonSpeciesCatalog
## 物种数据 = 主游戏内容真相 (出生 / 进化)。每形态 = 一条独立物种条目, 按 species_id 寻址
## (docs/main-game-architecture.md §8c)。
##
## - 物种 base 六维 (level-1 baseline): 正确模型 = 每形态独立物种、有自己的显式 base。
##   stub 占位: baby 委托 battle 层 InkMonUnitConfig; 进化形态 = root(baby) base × stat_mult
##   (没真数据时凑数, 不手敲)。canon override (server 桥) 命中时改用该物种自己的显式 base,
##   取代上面的 stub 占位 (见 _overrides)。最终战斗属性 = base × 等级缩放 (见
##   ink_mon_roster_entry.gd::derive_battle_stats), 不在本类。
## - 技能池: per-(species, slot) 候选 skill_id; 出生每槽确定性 roll 一个。
## - 进化拓扑 = edge-list 森林 (adr/0010): 每条边 (parent_species_id → child_species_id, trigger)。
##   阈值 trigger.level 是设计数据, 住 canon (经 contract 灌入 _evolution_edges); 评估住 godot
##   (condition 按 type 分派, 见 evaluate_evolution_condition)。无 contract 时降级用 _build_table
##   的 evolves_to 单边 fallback。进化改写 entry.species_id/name_en/stage, entry_id 不变。
##   注意: godot 不再持有进化阈值/拓扑 (它们随 lab→server→godot 投影); godot 只持有单位的
##   运行时 current level (entry.level 成长状态)。
## - X->X2: SKILL_EVOLUTIONS 把某技能映射到进化后技能 (改对应 slot 的 skill_id)。
##   stub X2 目标复用现有真实技能 (占位); 真正独立 X2 ability 随 lab 内容落地。与 condition 分派正交。
##
## stub fallback (Non-Goal): 下面 _build_table 物种 / 池 / 链全为手搓占位, 仅"无 contract"时生效。

const STAGE_BABY := "baby"
const STAGE_MATURE := "mature"
const STAGE_ADULT := "adult"

## X->X2: skill_id -> 进化后 skill_id (进化时改对应 slot)。
const SKILL_EVOLUTIONS := {
	"inkmon_fireball": "inkmon_chain_lightning",
}

static var _table: Dictionary = {}

## Server creature-base overrides (canon→godot bridge). Keyed by species_id (mon_NNNN,
## the unique immutable identity — no case ambiguity, so NO normalization/dual-write) →
## {base_stats, stage, elements, display_name}. An override IS the canonical per-species
## base (each stage is its own species with explicit stats); it supersedes the stub's
## placeholder root×mult derivation for that species. has_species/get_stage/get_base_stats/
## get_elements/get_display_name consult it first; skill pools / SKILL_EVOLUTIONS stay stub.
## Written by InkMonContentLoader at boot; never serialized into the stub table.
static var _overrides: Dictionary = {}

## Server evolution topology (canon→godot bridge), an edge-list forest (adr/0010) keyed by
## parent_species_id → Array[{child_species_id, trigger:{level, condition}}]. A `parent`
## with multiple entries = a branch. When non-empty it is the AUTHORITATIVE topology source
## (get_evolution_edges does NOT fall back to the stub _build_table); when empty the runtime
## reverts to the stub's per-species evolves_to. Cleared with _overrides (clear_overrides).
static var _evolution_edges: Dictionary = {}


static func has_species(species_id: String) -> bool:
	if not _override_for(species_id).is_empty():
		return true
	return _species_table().has(species_id)


static func get_stage(species_id: String) -> String:
	var ov := _override_for(species_id)
	if not ov.is_empty():
		return str(ov.get("stage", STAGE_BABY))
	return str(_species_node(species_id).get("stage", STAGE_BABY))


## 物种 base 六维 (level-1 baseline)。命中 canon override → 直接返回该物种自己的显式 base
## (每形态独立)。否则走 stub 占位: root(baby) base × stat_mult (baby root=self / mult=1.0)。
static func get_base_stats(species_id: String) -> Dictionary:
	var ov := _override_for(species_id)
	if not ov.is_empty():
		return (ov.get("base_stats", {}) as Dictionary).duplicate(true)
	var node := _species_node(species_id)
	var root := str(node.get("root", species_id))
	var mult := float(node.get("mult", 1.0))
	var base := InkMonUnitConfig.get_species_base_stats(root)
	var scaled := {}
	for key in base:
		scaled[key] = float(base[key]) * mult
	return scaled


## 物种元素。命中 canon override → server 投影的 elements;否则委托 battle 层 UnitConfig
## (stub 物种行为不变)。catalog 是物种内容真相, 故元素也由它统一供给(见 RosterEntry.from_birth)。
static func get_elements(species_id: String) -> Array[String]:
	var ov := _override_for(species_id)
	if not ov.is_empty():
		var result: Array[String] = []
		for element_value in (ov.get("elements", []) as Array):
			result.append(str(element_value))
		return result
	return InkMonUnitConfig.get_elements_for_species(species_id)


## 物种显示名 (name_en)。命中 canon override → server 投影的 display_name; 否则回退 stub
## UnitConfig; 都没有 → 返回 species_id 本身 (寻址键当兜底显示, 保 stub 进化形态非空)。
## 永不 assert (显示路径 fail-soft)。供 RosterEntry name_en 派生 + evolve 后改名。
static func get_display_name(species_id: String) -> String:
	var ov := _override_for(species_id)
	if not ov.is_empty():
		var ov_name := str(ov.get("display_name", ""))
		if ov_name != "":
			return ov_name
	var stub_name := InkMonUnitConfig.get_display_name_for_species(species_id)
	return stub_name if stub_name != "" else species_id


## Register a server creature base as a runtime override (see _overrides). Keyed by the
## species_id (mon_NNNN) ALONE — species_id is the unique immutable identity, so there is
## no case ambiguity and NO normalization/dual-write. The FULL validated creature base is
## kept (stats + stage + elements + display_name) — nothing the contract carries is silently
## dropped. Stats are float-coerced to match the stub path's guarantee (JSON integer literals
## parse to int); an empty species_id/base_stats is ignored so a malformed entry falls through
## to the normal unknown-species assert rather than spawning a zero-stat unit.
static func register_override(
	species_id: String, base_stats: Dictionary, stage: String, elements: Array[String], display_name: String = ""
) -> void:
	if species_id == "" or base_stats.is_empty():
		return
	var stats := {}
	for key in base_stats:
		stats[key] = float(base_stats[key])
	_overrides[species_id] = {
		"base_stats": stats,
		"stage": stage,
		"elements": elements.duplicate(),
		"display_name": display_name,
	}


## Register the server evolution forest (edge-list). Rebuilds _evolution_edges as
## {parent_species_id → [{child_species_id, trigger:{level, condition}}]}; multiple entries
## per parent = a branch. Once registered (non-empty) the edge-list is the authoritative
## topology source (get_evolution_edges stops falling back to the stub). Edge order is
## preserved — _select_evolution_edge relies on it for deterministic branch selection.
## Malformed edges (missing parent/child) are skipped. Written by InkMonContentLoader at boot.
static func register_evolution_edges(edges: Array) -> void:
	_evolution_edges.clear()
	for edge_value in edges:
		if not (edge_value is Dictionary):
			continue
		var edge: Dictionary = edge_value
		var parent := str(edge.get("parent_species_id", ""))
		var child := str(edge.get("child_species_id", ""))
		if parent == "" or child == "":
			continue
		var trigger_value: Variant = edge.get("trigger", {})
		var trigger: Dictionary = trigger_value if trigger_value is Dictionary else {}
		var condition_value: Variant = trigger.get("condition", {})
		var condition: Dictionary = condition_value if condition_value is Dictionary else {}
		var normalized := {
			"child_species_id": child,
			"trigger": {
				"level": int(trigger.get("level", 0)),
				"condition": condition.duplicate(true),
			},
		}
		if not _evolution_edges.has(parent):
			_evolution_edges[parent] = []
		(_evolution_edges[parent] as Array).append(normalized)


## Drop all server overrides AND evolution edges (revert to pure stub). Tests must call
## this to isolate the static tables between scenes sharing a process.
static func clear_overrides() -> void:
	_overrides.clear()
	_evolution_edges.clear()


## Override payload for `species_id` (exact key, no normalization), or {} if none.
static func _override_for(species_id: String) -> Dictionary:
	# Fast path: no imports applied (the default — res://data absent) → skip the dict get.
	if _overrides.is_empty():
		return {}
	return _overrides.get(species_id, {})


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


## 进化出边查询: 返回该物种全部出边 Array[{child_species_id, trigger:{level, condition}}];
## 无出边 / 孤儿 / override-only 物种 → []。支持多子分支 (同 parent 多条边)。
## contract edge-list (register_evolution_edges 灌过, _evolution_edges 非空) = 权威真相源,
## 不回退 stub; 无 edge-list 时降级用 _build_table 的 evolves_to 单边 (无 condition) 作 fallback。
static func get_evolution_edges(species_id: String) -> Array[Dictionary]:
	if not _evolution_edges.is_empty():
		var out: Array[Dictionary] = []
		for edge_value in (_evolution_edges.get(species_id, []) as Array):
			out.append(edge_value as Dictionary)
		return out
	# stub fallback: 单子 evolves_to → 规范化成一条无 condition 的边, 与 contract 边同形。
	var evo := _node_or_empty(species_id).get("evolves_to", {}) as Dictionary
	if evo == null or evo.is_empty():
		return []
	return [{
		"child_species_id": str(evo.get("species", "")),
		"trigger": {"level": int(evo.get("level", 0)), "condition": {}},
	}]


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


## 进化 (模型 B, 森林多子): 遍历 species_id 的出边 → entry.level >= trigger.level 过滤 →
## 确定性选边 (_select_evolution_edge) → 改写 species_id/name_en/stage, 保留旧 slot, X->X2
## 升级, 新阶段补槽 roll。entry_id 不变 (进化是变身非换只)。返回是否发生进化。
## 阈值 trigger.level 来自 contract edge-list (无 contract 时 stub evolves_to fallback),
## godot 不再硬编码进化阈值 (adr/0010); 单位运行时等级 entry.level 仍 godot 持有。
static func evolve_entry(entry: InkMonRosterEntry) -> bool:
	var edges := get_evolution_edges(entry.species_id)
	if edges.is_empty():
		return false
	var chosen := _select_evolution_edge(edges, entry)
	if chosen.is_empty():
		return false
	var next_species := str(chosen.get("child_species_id", ""))
	if next_species == "" or not has_species(next_species):
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
	# 3. 改写 species_id + name_en + stage (entry_id 不变)。
	entry.species_id = next_species
	entry.name_en = get_display_name(next_species)
	entry.stage = get_stage(next_species)
	return true


## 确定性选边 (同 level 多枝互斥由此定死, canon 语义盲 → godot 兜底, 见 spec §2.1 + adr/0010):
## 在所有 level 达标 (entry.level >= trigger.level) 的出边中 ——
##   1) 有 condition 且评估通过者优先, 取边表顺序第一条 (register 保序);
##   2) 否则取第一条无 condition 的默认枝;
##   3) 都没有 → {} (本级不进化)。
## entry.level 未达任何 trigger.level → {} (没有达标边)。
static func _select_evolution_edge(edges: Array[Dictionary], entry: InkMonRosterEntry) -> Dictionary:
	var default_edge := {}
	for edge in edges:
		var trigger := edge.get("trigger", {}) as Dictionary
		if entry.level < int(trigger.get("level", 0)):
			continue
		var condition := trigger.get("condition", {}) as Dictionary
		if condition == null or condition.is_empty():
			if default_edge.is_empty():
				default_edge = edge
			continue
		if evaluate_evolution_condition(condition, entry):
			return edge
	return default_edge


## 进化 condition 评估 (语义住 godot, 按 type 分派, adr/0010 + spec §2.1)。返回是否满足。
## - element: entry 主元素匹配 params.primary。
## - stat: entry 派生属性 (derive_battle_stats, hp→max_hp) 与 params.value 按 params.cmp 比较。
## - item: ⛔ BLOCKED — item 域未迁 server, 无"按 entry 查持有"接口 → stub false + 软警告, 勿假进化。
## - 未知 type → fail-safe false + 软警告 (遇生成端新 type 不假进化)。
## 空 condition 由 _select_evolution_edge 当默认枝处理 (不进本函数)。
static func evaluate_evolution_condition(condition: Dictionary, entry: InkMonRosterEntry) -> bool:
	var cond_type := str(condition.get("type", ""))
	var params_value: Variant = condition.get("params", {})
	var params: Dictionary = params_value if params_value is Dictionary else {}
	match cond_type:
		"element":
			return _eval_condition_element(params, entry)
		"stat":
			return _eval_condition_stat(params, entry)
		"item":
			Log.warning(
				"InkMonSpeciesCatalog",
				"evolution condition type:item not supported yet (item domain pending server sync); treated as unmet"
			)
			return false
		_:
			Log.warning(
				"InkMonSpeciesCatalog",
				"unknown evolution condition type '%s' (treated as unmet)" % cond_type
			)
			return false


static func _eval_condition_element(params: Dictionary, entry: InkMonRosterEntry) -> bool:
	var primary := str(params.get("primary", ""))
	if primary == "":
		return false
	return not entry.elements.is_empty() and entry.elements[0] == primary


static func _eval_condition_stat(params: Dictionary, entry: InkMonRosterEntry) -> bool:
	var stat := str(params.get("stat", ""))  # hp|ad|ap|armor|mr|speed (hp→max_hp)
	var comparator := str(params.get("cmp", ""))
	if stat == "" or comparator == "" or not params.has("value"):
		return false
	var key := "max_hp" if stat == "hp" else stat
	var stats := entry.derive_battle_stats()
	if not stats.has(key):
		return false
	var lhs := float(stats.get(key, 0.0))
	var rhs := float(params.get("value", 0.0))
	match comparator:
		">=": return lhs >= rhs
		">": return lhs > rhs
		"<=": return lhs <= rhs
		"<": return lhs < rhs
		"==": return is_equal_approx(lhs, rhs)
		"!=": return not is_equal_approx(lhs, rhs)
		_: return false


static func _slot_seed(roll_seed: int, slot_index: int) -> int:
	return roll_seed * 1000003 + slot_index


static func _species_node(species: String) -> Dictionary:
	var table := _species_table()
	Log.assert_crash(table.has(species), "InkMonSpeciesCatalog", "unknown species: %s" % species)
	return table[species]


## stub 表节点, 或 {} 表示 override-only 物种(有 override 但不在 stub 表 → 无技能池/无 stub 进化:
## 契约只搬 creature 基底, 技能元数据是后续阶段)。仅"既非 stub 又无 override"的真未知物种
## assert(保留响亮失败)。供 get_slot_count/get_slot_pool/get_evolution_edges(stub fallback)用。
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
