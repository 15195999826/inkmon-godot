class_name InkMonPlayerState
extends RefCounted


const DEFAULT_GOLD := 100
const WIN_REWARD_GOLD := 25
const WIN_EXP := 5
const LOSS_EXP := 1


var gold := 0
var roster: Array[InkMonRosterEntry] = []
var overworld: Dictionary = {}
var progression: Dictionary = {}
# 勋章是玩家级 (非单只; 影响所有 InkMon, 对标 TFT 海克斯), 从 RosterEntry 移来 (§8c-gap)。
var medals: Array[String] = []


static func create_new_game() -> InkMonPlayerState:
	var state := InkMonPlayerState.new()
	state.gold = DEFAULT_GOLD
	state.overworld = {
		"player_coord": {"q": 0, "r": 0},
		"visited_flags": {},
		"npc_states": {},
	}
	state.progression = {
		"trainer_rank": 1,
		"guild_joined": false,
		"cultivation_points": 0,
	}
	var next_entry_id := 1
	for unit_key in InkMonUnitConfig.get_default_roster(0):
		state.roster.append(InkMonRosterEntry.from_unit_config(next_entry_id, unit_key))
		next_entry_id += 1
	return state


static func from_dict(data: Dictionary) -> InkMonPlayerState:
	var state := InkMonPlayerState.new()
	state.gold = int(data.get("gold", 0))
	state.overworld = (data.get("overworld", {}) as Dictionary).duplicate(true)
	state.progression = (data.get("progression", {}) as Dictionary).duplicate(true)
	state.medals = _string_array(data.get("medals", []))
	state.roster = []
	var roster_data := data.get("roster", []) as Array
	if roster_data != null:
		for item in roster_data:
			var entry_data := item as Dictionary
			if entry_data != null:
				state.roster.append(InkMonRosterEntry.from_dict(entry_data))
	return state


func to_dict() -> Dictionary:
	var roster_data: Array[Dictionary] = []
	for entry in roster:
		roster_data.append(entry.to_dict())
	return {
		"gold": gold,
		"roster": roster_data,
		"overworld": overworld.duplicate(true),
		"progression": progression.duplicate(true),
		"medals": medals.duplicate(),
	}


func project_battle_roster(max_units: int = 4) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var limit := mini(max_units, roster.size())
	for i in range(limit):
		result.append(roster[i].project_to_battle_snapshot())
	return result


func get_roster_entry(p_entry_id: int) -> InkMonRosterEntry:
	for entry in roster:
		if entry.entry_id == p_entry_id:
			return entry
	return null


func apply_battle_result(result: Dictionary) -> void:
	var winner_team := str(result.get("winner_team", ""))
	var reward_gold := int(result.get("reward_gold", WIN_REWARD_GOLD if winner_team == "left" else 0))
	gold += max(0, reward_gold)

	var survivors := _int_array(result.get("survivors", []))
	var casualties := _int_array(result.get("casualties", []))
	for entry_id in survivors:
		var survivor := get_roster_entry(entry_id)
		if survivor != null:
			survivor.add_exp(WIN_EXP if winner_team == "left" else LOSS_EXP)
	for entry_id in casualties:
		var casualty := get_roster_entry(entry_id)
		if casualty != null:
			casualty.add_exp(LOSS_EXP)


func add_roster_entry(entry: InkMonRosterEntry) -> void:
	Log.assert_crash(entry != null, "InkMonPlayerState", "cannot add null roster entry")
	roster.append(entry)


func get_next_roster_entry_id() -> int:
	var next_id := 1
	for entry in roster:
		next_id = maxi(next_id, entry.entry_id + 1)
	return next_id


func remove_roster_entry(entry_id: int) -> bool:
	for i in range(roster.size()):
		if roster[i].entry_id == entry_id:
			roster.remove_at(i)
			return true
	return false


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	var source := value as Array
	if source == null:
		return result
	for item in source:
		result.append(str(item))
	return result


static func _int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	var source := value as Array
	if source == null:
		return result
	for item in source:
		result.append(int(item))
	return result
