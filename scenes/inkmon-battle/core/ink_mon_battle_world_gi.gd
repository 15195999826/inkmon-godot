class_name InkMonBattleWorldGI
extends WorldGameplayInstance


var tick_count := 0
var left_team: Array[InkMonUnitActor] = []
var right_team: Array[InkMonUnitActor] = []
var damage_mod_seen := false

var _ended := false
var _result := ""
var _final_replay_data: Dictionary = {}
var _inkmon_procedure: InkMonBattleProcedure = null
var _recording_enabled := true


func _init(id_value: String = "") -> void:
	super._init(id_value if id_value != "" else IdGenerator.generate("inkmon_battle"))
	type = "inkmon_battle"
	battle_finished.connect(_on_battle_finished)


func start(config: Dictionary = {}) -> void:
	super.start()
	_recording_enabled = config.get("recording", true)

	var grid_config := config.get("map_config", null) as GridMapConfig
	if grid_config == null:
		grid_config = _build_default_grid_config()
	configure_grid(grid_config)

	_setup_teams(config)
	for actor in get_all_units():
		actor.equip_abilities(self)
	_place_team_fixed(left_team, [
		HexCoord.new(-3, -1), HexCoord.new(-3, 0), HexCoord.new(-3, 1), HexCoord.new(-2, 0),
	])
	_place_team_fixed(right_team, [
		HexCoord.new(3, -1), HexCoord.new(3, 0), HexCoord.new(3, 1), HexCoord.new(2, 0),
	])

	InkMonAllSkills.register_all_timelines()

	var participants: Array[Actor] = []
	for actor in get_all_units():
		participants.append(actor)
	start_battle(participants)


func tick(dt: float) -> void:
	super.tick(dt)
	if _inkmon_procedure != null:
		tick_count = _inkmon_procedure.get_current_tick()


func configure_grid(config: GridMapConfig) -> void:
	UGridMap.configure(config)
	grid = UGridMap.model
	grid_configured.emit(config)


func remove_actor(actor_id: String) -> bool:
	var actor := super.get_actor(actor_id)
	if actor != null and actor is InkMonBattleActor:
		var battle_actor := actor as InkMonBattleActor
		if grid != null and battle_actor.hex_position != null and battle_actor.hex_position.is_valid():
			var occupant: Variant = grid.get_occupant(battle_actor.hex_position)
			if occupant == battle_actor:
				grid.remove_occupant(battle_actor.hex_position)
			for coord in _find_reservations_by(actor_id):
				grid.cancel_reservation(coord)
	return super.remove_actor(actor_id)


func get_actor(actor_id: String) -> InkMonBattleActor:
	return super.get_actor(actor_id) as InkMonBattleActor


func get_unit_actor(actor_id: String) -> InkMonUnitActor:
	return super.get_actor(actor_id) as InkMonUnitActor


func get_all_units() -> Array[InkMonUnitActor]:
	var result: Array[InkMonUnitActor] = []
	result.append_array(left_team)
	result.append_array(right_team)
	return result


func get_alive_actor_ids() -> Array[String]:
	var result: Array[String] = []
	for actor in get_alive_actors():
		result.append(actor.get_id())
	return result


func get_alive_actors() -> Array[InkMonUnitActor]:
	var result: Array[InkMonUnitActor] = []
	for actor in get_all_units():
		if not actor.is_dead():
			result.append(actor)
	return result


func get_result() -> String:
	return _result


func is_ended() -> bool:
	return _ended


func get_replay_data() -> Dictionary:
	if not _final_replay_data.is_empty():
		return _final_replay_data
	var rec: BattleRecorder = _inkmon_procedure.get_recorder() if _inkmon_procedure != null else null
	if rec != null and rec.get_is_recording():
		return rec.stop_recording()
	return {}


func can_use_skill_on(actor: InkMonUnitActor, skill: Ability, target: InkMonBattleActor) -> bool:
	if actor == null or skill == null or target == null or target.is_dead():
		return false

	if target is InkMonUnitActor:
		var unit_target := target as InkMonUnitActor
		var same_team := actor.get_team_id() == unit_target.get_team_id()
		var is_self := actor.get_id() == unit_target.get_id()
		if skill.has_ability_tag("enemy") and same_team:
			return false
		if skill.has_ability_tag("ally") and not same_team:
			return false
		if skill.has_ability_tag("ally") and is_self and not skill.has_ability_tag("self"):
			return false

	var skill_range := skill.get_meta_int(InkMonSkillMetaKeys.RANGE, 1)
	if not actor.hex_position.is_valid() or not target.hex_position.is_valid():
		return false
	return actor.hex_position.distance_to(target.hex_position) <= skill_range


func _create_battle_procedure(_participants: Array[Actor]) -> BattleProcedure:
	_inkmon_procedure = InkMonBattleProcedure.new(self, left_team, right_team, {
		"recording": _recording_enabled,
	})
	return _inkmon_procedure


func _on_battle_finished(timeline: Dictionary) -> void:
	_ended = true
	_final_replay_data = timeline
	if _inkmon_procedure != null:
		_result = _inkmon_procedure.get_result()
		tick_count = _inkmon_procedure.get_current_tick()
	print("[InkMonBattleWorldGI] finished result=%s ticks=%d" % [_result, tick_count])
	end()
	_inkmon_procedure = null


func _setup_teams(config: Dictionary) -> void:
	var left_roster: Array = config.get("left_roster", InkMonUnitConfig.get_default_roster(0))
	var right_roster: Array = config.get("right_roster", InkMonUnitConfig.get_default_roster(1))
	for key in left_roster:
		left_team.append(_create_team_actor(str(key), 0))
	for key in right_roster:
		right_team.append(_create_team_actor(str(key), 1))


func _create_team_actor(unit_key: String, team_id: int) -> InkMonUnitActor:
	var actor := InkMonUnitActor.new(unit_key)
	actor.set_team_id(team_id)
	return add_actor(actor) as InkMonUnitActor


func _place_team_fixed(team: Array[InkMonUnitActor], preferred_coords: Array[HexCoord]) -> void:
	var fallback := _available_coords()
	for i in range(team.size()):
		var coord := preferred_coords[i] if i < preferred_coords.size() else null
		if coord == null or not grid.has_tile(coord) or grid.is_occupied(coord):
			coord = _pop_first_available(fallback)
		if coord == null:
			continue
		grid.place_occupant(coord, team[i])
		team[i].hex_position = coord.duplicate()


func _available_coords() -> Array[HexCoord]:
	var result: Array[HexCoord] = []
	for coord in grid.get_all_coords():
		if grid.is_passable(coord) and not grid.is_reserved(coord):
			result.append(coord)
	result.sort_custom(func(a: HexCoord, b: HexCoord) -> bool:
		if a.q == b.q:
			return a.r < b.r
		return a.q < b.q
	)
	return result


func _pop_first_available(coords: Array[HexCoord]) -> HexCoord:
	while not coords.is_empty():
		var coord := coords.pop_front() as HexCoord
		if grid.has_tile(coord) and grid.is_passable(coord):
			return coord
	return null


func _find_reservations_by(actor_id: String) -> Array[HexCoord]:
	var result: Array[HexCoord] = []
	if grid == null:
		return result
	for coord in grid.get_all_coords():
		if grid.get_reservation(coord) == actor_id:
			result.append(coord)
	return result


func _build_default_grid_config() -> GridMapConfig:
	var config := GridMapConfig.new()
	config.grid_type = GridMapConfig.GridType.HEX
	config.draw_mode = GridMapConfig.DrawMode.RADIUS
	config.radius = 5
	config.size = 10.0
	config.orientation = GridMapConfig.Orientation.FLAT
	return config
