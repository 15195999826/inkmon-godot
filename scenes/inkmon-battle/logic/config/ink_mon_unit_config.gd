class_name InkMonUnitConfig


## personality = AI 行为倾向(决定 choose_skill_target),驱动 InkMonAIStrategyFactory 选策略。
## ⚠ INTERIM(adr/0008):role 战斗定位字段已彻底废弃;personality 接管 AI 路由,但当前是 **godot-internal
## 临时实现**(由 species 派生 + 路由),用于在 role 删除后保留 per-unit AI 差异。adr/0008 的 proper 设计 =
## canon `personality` 字段投影到 godot,等 AI 策略系统语义明确后再做(不是 role 的重命名/兼容层)。
const PERSONALITY_AGGRESSIVE := "aggressive"
const PERSONALITY_FRONTLINE := "frontline"
const PERSONALITY_SUPPORT := "support"

const STAGE_BABY := "baby"

## 派生属性用的六维 key (本层自有词汇, 不上引 main 层的 RosterEntry.STAT_KEYS)。
const BASE_STAT_KEYS: Array[String] = ["max_hp", "ad", "ap", "armor", "mr", "speed"]

# Demo M1 队伍槽位 key (内部标识 8 个 demo 单位, 按 team + species 命名; 非战斗定位字段)。
const LEFT_AEGIS_PUP := "left_aegis_pup"
const LEFT_CINDER_KIT := "left_cinder_kit"
const LEFT_HALO_SPROUT := "left_halo_sprout"
const LEFT_GALE_MOTE := "left_gale_mote"
const RIGHT_BRINE_BULWARK := "right_brine_bulwark"
const RIGHT_EMBER_WISP := "right_ember_wisp"
const RIGHT_LUMEN_BUD := "right_lumen_bud"
const RIGHT_UMBRAL_PIN := "right_umbral_pin"


class UnitConfigItem:
	extends RefCounted

	var key: String
	var display_name: String
	var species: String
	var stage: String
	var personality: String
	var elements: Array[String]
	var stats: Dictionary
	var active_skill_id: String

	func _init(
		p_key: String,
		p_display_name: String,
		p_species: String,
		p_stage: String,
		p_personality: String,
		p_elements: Array[String],
		p_stats: Dictionary,
		p_active_skill_id: String
	) -> void:
		key = p_key
		display_name = p_display_name
		species = p_species
		stage = p_stage
		personality = p_personality
		elements = p_elements
		stats = p_stats
		active_skill_id = p_active_skill_id


static func get_default_roster(team_id: int) -> Array[String]:
	if team_id == 0:
		return [LEFT_AEGIS_PUP, LEFT_CINDER_KIT, LEFT_HALO_SPROUT, LEFT_GALE_MOTE]
	return [RIGHT_BRINE_BULWARK, RIGHT_EMBER_WISP, RIGHT_LUMEN_BUD, RIGHT_UMBRAL_PIN]


static func get_unit_config(unit_key: String) -> UnitConfigItem:
	var configs := _configs()
	Log.assert_crash(configs.has(unit_key), "InkMonUnitConfig", "unknown unit key: %s" % unit_key)
	return configs[unit_key]


## 物种 base 六维 (= level-1 baseline)。供 RosterEntry.derive_battle_stats 的 f(species, level) 用。
static func get_species_base_stats(species: String) -> Dictionary:
	var cfg := _find_config_by_species(species)
	Log.assert_crash(cfg != null, "InkMonUnitConfig", "no base stats for species: %s" % species)
	if cfg == null:
		return {}
	var base := {}
	for stat_key in BASE_STAT_KEYS:
		base[stat_key] = float(cfg.stats[stat_key])
	return base


## INTERIM(adr/0008):由 species 派生 AI personality。无配置 → AGGRESSIVE(default)。
## 未来 personality 走 canon 字段投影,这里的 godot 派生会被替换。
static func get_personality_for_species(species: String) -> String:
	var cfg := _find_config_by_species(species)
	return cfg.personality if cfg != null else PERSONALITY_AGGRESSIVE


## stub 物种显示名 (name_en 风格), 无配置则 ""。供 SpeciesCatalog.get_display_name 在
## 无 canon override 时回退 (override-only / server 物种走 override 的 display_name)。
static func get_display_name_for_species(species: String) -> String:
	var cfg := _find_config_by_species(species)
	return cfg.display_name if cfg != null else ""


static func get_elements_for_species(species: String) -> Array[String]:
	var cfg := _find_config_by_species(species)
	var result: Array[String] = []
	if cfg != null:
		result.assign(cfg.elements)
	return result


static func _find_config_by_species(species: String) -> UnitConfigItem:
	var configs := _configs()
	for unit_key in configs:
		var cfg := configs[unit_key] as UnitConfigItem
		if cfg.species == species:
			return cfg
	return null


static func _configs() -> Dictionary:
	return {
		LEFT_AEGIS_PUP: UnitConfigItem.new(LEFT_AEGIS_PUP, "Aegis Pup", "aegis_pup", STAGE_BABY, PERSONALITY_FRONTLINE, [InkMonElementChart.WATER], {
			"hp": 220.0, "max_hp": 220.0, "ad": 34.0, "ap": 24.0, "armor": 62.0, "mr": 40.0, "speed": 112.0,
		}, InkMonStun.CONFIG_ID),
		LEFT_CINDER_KIT: UnitConfigItem.new(LEFT_CINDER_KIT, "Cinder Kit", "cinder_kit", STAGE_BABY, PERSONALITY_AGGRESSIVE, [InkMonElementChart.FIRE], {
			"hp": 138.0, "max_hp": 138.0, "ad": 24.0, "ap": 92.0, "armor": 20.0, "mr": 34.0, "speed": 108.0,
		}, InkMonFireball.CONFIG_ID),
		LEFT_HALO_SPROUT: UnitConfigItem.new(LEFT_HALO_SPROUT, "Halo Sprout", "halo_sprout", STAGE_BABY, PERSONALITY_SUPPORT, [InkMonElementChart.LIGHT], {
			"hp": 152.0, "max_hp": 152.0, "ad": 22.0, "ap": 76.0, "armor": 26.0, "mr": 48.0, "speed": 104.0,
		}, InkMonHolyHeal.CONFIG_ID),
		LEFT_GALE_MOTE: UnitConfigItem.new(LEFT_GALE_MOTE, "Gale Mote", "gale_mote", STAGE_BABY, PERSONALITY_AGGRESSIVE, [InkMonElementChart.WIND], {
			"hp": 156.0, "max_hp": 156.0, "ad": 34.0, "ap": 82.0, "armor": 26.0, "mr": 32.0, "speed": 118.0,
		}, InkMonChainLightning.CONFIG_ID),
		RIGHT_BRINE_BULWARK: UnitConfigItem.new(RIGHT_BRINE_BULWARK, "Brine Bulwark", "brine_bulwark", STAGE_BABY, PERSONALITY_FRONTLINE, [InkMonElementChart.WATER], {
			"hp": 178.0, "max_hp": 178.0, "ad": 30.0, "ap": 20.0, "armor": 48.0, "mr": 34.0, "speed": 96.0,
		}, InkMonStun.CONFIG_ID),
		RIGHT_EMBER_WISP: UnitConfigItem.new(RIGHT_EMBER_WISP, "Ember Wisp", "ember_wisp", STAGE_BABY, PERSONALITY_AGGRESSIVE, [InkMonElementChart.FIRE], {
			"hp": 118.0, "max_hp": 118.0, "ad": 20.0, "ap": 66.0, "armor": 18.0, "mr": 28.0, "speed": 98.0,
		}, InkMonFireball.CONFIG_ID),
		RIGHT_LUMEN_BUD: UnitConfigItem.new(RIGHT_LUMEN_BUD, "Lumen Bud", "lumen_bud", STAGE_BABY, PERSONALITY_SUPPORT, [InkMonElementChart.LIGHT], {
			"hp": 124.0, "max_hp": 124.0, "ad": 18.0, "ap": 56.0, "armor": 20.0, "mr": 36.0, "speed": 96.0,
		}, InkMonHolyHeal.CONFIG_ID),
		RIGHT_UMBRAL_PIN: UnitConfigItem.new(RIGHT_UMBRAL_PIN, "Umbral Pin", "umbral_pin", STAGE_BABY, PERSONALITY_AGGRESSIVE, [InkMonElementChart.DARK], {
			"hp": 132.0, "max_hp": 132.0, "ad": 28.0, "ap": 58.0, "armor": 22.0, "mr": 28.0, "speed": 102.0,
		}, InkMonPoison.CONFIG_ID),
	}
