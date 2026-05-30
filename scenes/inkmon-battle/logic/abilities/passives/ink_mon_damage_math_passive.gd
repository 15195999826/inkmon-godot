class_name InkMonDamageMathPassive


const CONFIG_ID := "inkmon_damage_math_passive"
const DEFENSE_K := 100.0


static var ABILITY := (
	AbilityConfig.builder()
	.config_id(CONFIG_ID)
	.display_name("InkMon Damage Math")
	.description("Applies AD/AP mitigation and element multipliers")
	.ability_tags(["intrinsic", "inkmon_damage_math"])
	.component_config(
		PreEventConfig.new(
			InkMonBattlePreEvents.PRE_DAMAGE_EVENT,
			_handle_pre_damage,
			_is_owner_target,
			"InkMon Damage Math"
		)
	)
	.build()
)


static func _is_owner_target(event: Dictionary, ctx: AbilityLifecycleContext) -> bool:
	return str(event.get("target_actor_id", "")) == ctx.owner_actor_id


static func _handle_pre_damage(mutable: MutableEvent, ctx: AbilityLifecycleContext) -> Intent:
	var owner := GameWorld.get_actor(ctx.owner_actor_id) as InkMonUnitActor
	if owner == null or owner.is_dead():
		return EventPhase.pass_intent()

	var damage_type := str(mutable.get_current_value("damage_type"))
	var element := str(mutable.get_current_value("element"))
	var source_actor_id := str(mutable.get_current_value("source_actor_id"))
	var source := GameWorld.get_actor(source_actor_id) as InkMonUnitActor

	var defense_mult := 1.0
	match damage_type:
		"physical":
			defense_mult = DEFENSE_K / (DEFENSE_K + owner.attribute_set.armor)
		"magical":
			defense_mult = DEFENSE_K / (DEFENSE_K + owner.attribute_set.mr)
		_:
			defense_mult = 1.0

	var attacker_element := element
	if attacker_element.is_empty() and source != null:
		attacker_element = source.get_primary_element()
	var defender_element := owner.get_primary_element()
	var element_mult := InkMonElementChart.damage_multiplier(attacker_element, defender_element)
	var total_mult := defense_mult * element_mult

	return EventPhase.modify_intent(ctx.ability.id, [
		Modification.multiply("damage", total_mult, ctx.ability.id, "InkMon damage math"),
	])
