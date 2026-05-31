class_name InkMonUnitConfig


const ROLE_TANK := "tank"
const ROLE_DPS := "dps"
const ROLE_HEALER := "healer"
const ROLE_FLEX := "flex"

const STAGE_BABY := "baby"

## 派生属性用的六维 key (本层自有词汇, 不上引 main 层的 RosterEntry.STAT_KEYS)。
const BASE_STAT_KEYS: Array[String] = ["max_hp", "ad", "ap", "armor", "mr", "speed"]

const LEFT_TANK := "left_tank"
const LEFT_MAGE_DPS := "left_mage_dps"
const LEFT_HEALER := "left_healer"
const LEFT_FLEX := "left_flex"
const RIGHT_TANK := "right_tank"
const RIGHT_MAGE_DPS := "right_mage_dps"
const RIGHT_HEALER := "right_healer"
const RIGHT_FLEX := "right_flex"


class UnitConfigItem:
	extends RefCounted

	var key: String
	var display_name: String
	var species: String
	var stage: String
	var role: String
	var elements: Array[String]
	var stats: Dictionary
	var active_skill_id: String

	func _init(
		p_key: String,
		p_display_name: String,
		p_species: String,
		p_stage: String,
		p_role: String,
		p_elements: Array[String],
		p_stats: Dictionary,
		p_active_skill_id: String
	) -> void:
		key = p_key
		display_name = p_display_name
		species = p_species
		stage = p_stage
		role = p_role
		elements = p_elements
		stats = p_stats
		active_skill_id = p_active_skill_id


static func get_default_roster(team_id: int) -> Array[String]:
	if team_id == 0:
		return [LEFT_TANK, LEFT_MAGE_DPS, LEFT_HEALER, LEFT_FLEX]
	return [RIGHT_TANK, RIGHT_MAGE_DPS, RIGHT_HEALER, RIGHT_FLEX]


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


static func get_role_for_species(species: String) -> String:
	var cfg := _find_config_by_species(species)
	return cfg.role if cfg != null else ROLE_FLEX


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
		LEFT_TANK: UnitConfigItem.new(LEFT_TANK, "Aegis Pup", "aegis_pup", STAGE_BABY, ROLE_TANK, [InkMonElementChart.WATER], {
			"hp": 220.0, "max_hp": 220.0, "ad": 34.0, "ap": 24.0, "armor": 62.0, "mr": 40.0, "speed": 112.0,
		}, InkMonStun.CONFIG_ID),
		LEFT_MAGE_DPS: UnitConfigItem.new(LEFT_MAGE_DPS, "Cinder Kit", "cinder_kit", STAGE_BABY, ROLE_DPS, [InkMonElementChart.FIRE], {
			"hp": 138.0, "max_hp": 138.0, "ad": 24.0, "ap": 92.0, "armor": 20.0, "mr": 34.0, "speed": 108.0,
		}, InkMonFireball.CONFIG_ID),
		LEFT_HEALER: UnitConfigItem.new(LEFT_HEALER, "Halo Sprout", "halo_sprout", STAGE_BABY, ROLE_HEALER, [InkMonElementChart.LIGHT], {
			"hp": 152.0, "max_hp": 152.0, "ad": 22.0, "ap": 76.0, "armor": 26.0, "mr": 48.0, "speed": 104.0,
		}, InkMonHolyHeal.CONFIG_ID),
		LEFT_FLEX: UnitConfigItem.new(LEFT_FLEX, "Gale Mote", "gale_mote", STAGE_BABY, ROLE_FLEX, [InkMonElementChart.WIND], {
			"hp": 156.0, "max_hp": 156.0, "ad": 34.0, "ap": 82.0, "armor": 26.0, "mr": 32.0, "speed": 118.0,
		}, InkMonChainLightning.CONFIG_ID),
		RIGHT_TANK: UnitConfigItem.new(RIGHT_TANK, "Brine Bulwark", "brine_bulwark", STAGE_BABY, ROLE_TANK, [InkMonElementChart.WATER], {
			"hp": 178.0, "max_hp": 178.0, "ad": 30.0, "ap": 20.0, "armor": 48.0, "mr": 34.0, "speed": 96.0,
		}, InkMonStun.CONFIG_ID),
		RIGHT_MAGE_DPS: UnitConfigItem.new(RIGHT_MAGE_DPS, "Ember Wisp", "ember_wisp", STAGE_BABY, ROLE_DPS, [InkMonElementChart.FIRE], {
			"hp": 118.0, "max_hp": 118.0, "ad": 20.0, "ap": 66.0, "armor": 18.0, "mr": 28.0, "speed": 98.0,
		}, InkMonFireball.CONFIG_ID),
		RIGHT_HEALER: UnitConfigItem.new(RIGHT_HEALER, "Lumen Bud", "lumen_bud", STAGE_BABY, ROLE_HEALER, [InkMonElementChart.LIGHT], {
			"hp": 124.0, "max_hp": 124.0, "ad": 18.0, "ap": 56.0, "armor": 20.0, "mr": 36.0, "speed": 96.0,
		}, InkMonHolyHeal.CONFIG_ID),
		RIGHT_FLEX: UnitConfigItem.new(RIGHT_FLEX, "Umbral Pin", "umbral_pin", STAGE_BABY, ROLE_FLEX, [InkMonElementChart.DARK], {
			"hp": 132.0, "max_hp": 132.0, "ad": 28.0, "ap": 58.0, "armor": 22.0, "mr": 28.0, "speed": 102.0,
		}, InkMonPoison.CONFIG_ID),
	}
