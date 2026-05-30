class_name InkMonBattlePreEvents


const PRE_DAMAGE_EVENT := "inkmon_pre_damage"


class PreDamageEvent extends GameEvent.Base:
	var source_actor_id: String = ""
	var target_actor_id: String = ""
	var damage: float = 0.0
	var damage_type: String = "physical"
	var element: String = ""

	func _init() -> void:
		kind = PRE_DAMAGE_EVENT

	static func create(
		p_source_actor_id: String,
		p_target_actor_id: String,
		p_damage: float,
		p_damage_type: String,
		p_element: String
	) -> PreDamageEvent:
		var e := PreDamageEvent.new()
		e.source_actor_id = p_source_actor_id
		e.target_actor_id = p_target_actor_id
		e.damage = p_damage
		e.damage_type = p_damage_type
		e.element = p_element
		return e

	func to_dict() -> Dictionary:
		return {
			"kind": kind,
			"source_actor_id": source_actor_id,
			"target_actor_id": target_actor_id,
			"damage": damage,
			"damage_type": damage_type,
			"element": element,
		}

	static func is_match(d: Dictionary) -> bool:
		return d.get("kind") == PRE_DAMAGE_EVENT
