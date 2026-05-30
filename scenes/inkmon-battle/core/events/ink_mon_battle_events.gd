class_name InkMonBattleEvents


enum DamageType { PHYSICAL, MAGICAL, PURE }


class DamageEvent extends GameEvent.Base:
	var target_actor_id: String = ""
	var damage: float = 0.0
	var damage_type: DamageType = DamageType.PHYSICAL
	var element: String = ""
	var source_actor_id: String = ""
	var actual_life_damage: float = 0.0

	func _init() -> void:
		kind = "inkmon_damage"

	static func create(
		p_target_actor_id: String,
		p_damage: float,
		p_damage_type: DamageType,
		p_element: String,
		p_source_actor_id: String = ""
	) -> DamageEvent:
		var e := DamageEvent.new()
		e.target_actor_id = p_target_actor_id
		e.damage = p_damage
		e.damage_type = p_damage_type
		e.element = p_element
		e.source_actor_id = p_source_actor_id
		e.actual_life_damage = p_damage
		return e

	func to_dict() -> Dictionary:
		var d := {
			"kind": kind,
			"target_actor_id": target_actor_id,
			"damage": damage,
			"damage_type": InkMonBattleEvents.damage_type_to_string(damage_type),
			"element": element,
			"actual_life_damage": actual_life_damage,
		}
		if source_actor_id != "":
			d["source_actor_id"] = source_actor_id
		return d

	static func from_dict(d: Dictionary) -> DamageEvent:
		var e := DamageEvent.new()
		e.target_actor_id = d.get("target_actor_id", "") as String
		e.damage = d.get("damage", 0.0) as float
		e.damage_type = InkMonBattleEvents.string_to_damage_type(d.get("damage_type", "physical") as String)
		e.element = d.get("element", "") as String
		e.source_actor_id = d.get("source_actor_id", "") as String
		e.actual_life_damage = d.get("actual_life_damage", e.damage) as float
		return e

	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == "inkmon_damage"


class HealEvent extends GameEvent.Base:
	var target_actor_id: String = ""
	var heal_amount: float = 0.0
	var source_actor_id: String = ""

	func _init() -> void:
		kind = "inkmon_heal"

	static func create(
		p_target_actor_id: String,
		p_heal_amount: float,
		p_source_actor_id: String = ""
	) -> HealEvent:
		var e := HealEvent.new()
		e.target_actor_id = p_target_actor_id
		e.heal_amount = p_heal_amount
		e.source_actor_id = p_source_actor_id
		return e

	func to_dict() -> Dictionary:
		var d := {
			"kind": kind,
			"target_actor_id": target_actor_id,
			"heal_amount": heal_amount,
		}
		if source_actor_id != "":
			d["source_actor_id"] = source_actor_id
		return d

	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == "inkmon_heal"


class MoveStartEvent extends GameEvent.Base:
	var actor_id: String = ""
	var from_hex: Dictionary = {}
	var to_hex: Dictionary = {}

	func _init() -> void:
		kind = "inkmon_move_start"

	static func create(p_actor_id: String, p_from_hex: Dictionary, p_to_hex: Dictionary) -> MoveStartEvent:
		var e := MoveStartEvent.new()
		e.actor_id = p_actor_id
		e.from_hex = p_from_hex
		e.to_hex = p_to_hex
		return e

	func to_dict() -> Dictionary:
		return {
			"kind": kind,
			"actor_id": actor_id,
			"from_hex": from_hex,
			"to_hex": to_hex,
		}


class MoveCompleteEvent extends GameEvent.Base:
	var actor_id: String = ""
	var from_hex: Dictionary = {}
	var to_hex: Dictionary = {}

	func _init() -> void:
		kind = "inkmon_move_complete"

	static func create(p_actor_id: String, p_from_hex: Dictionary, p_to_hex: Dictionary) -> MoveCompleteEvent:
		var e := MoveCompleteEvent.new()
		e.actor_id = p_actor_id
		e.from_hex = p_from_hex
		e.to_hex = p_to_hex
		return e

	func to_dict() -> Dictionary:
		return {
			"kind": kind,
			"actor_id": actor_id,
			"from_hex": from_hex,
			"to_hex": to_hex,
		}


class DeathEvent extends GameEvent.Base:
	var actor_id: String = ""
	var killer_actor_id: String = ""

	func _init() -> void:
		kind = "inkmon_death"

	static func create(p_actor_id: String, p_killer_actor_id: String = "") -> DeathEvent:
		var e := DeathEvent.new()
		e.actor_id = p_actor_id
		e.killer_actor_id = p_killer_actor_id
		return e

	func to_dict() -> Dictionary:
		var d := {
			"kind": kind,
			"actor_id": actor_id,
		}
		if killer_actor_id != "":
			d["killer_actor_id"] = killer_actor_id
		return d

	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == "inkmon_death"


static func damage_type_to_string(p_damage_type: DamageType) -> String:
	match p_damage_type:
		DamageType.PHYSICAL:
			return "physical"
		DamageType.MAGICAL:
			return "magical"
		DamageType.PURE:
			return "pure"
		_:
			return "unknown"


static func string_to_damage_type(s: String) -> DamageType:
	match s:
		"physical":
			return DamageType.PHYSICAL
		"magical":
			return DamageType.MAGICAL
		"pure":
			return DamageType.PURE
		_:
			return DamageType.PHYSICAL
