class_name InkMonCooldownSystem


class CooldownCondition:
	extends Condition

	func get_condition_type() -> String:
		return "inkmon_cooldown_ready"

	func check(ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> bool:
		var battle_ability_set := ctx.ability_set as InkMonBattleAbilitySet
		Log.assert_crash(battle_ability_set != null, "InkMonCooldownCondition", "requires InkMonBattleAbilitySet")
		return not battle_ability_set.is_on_cooldown(ctx.ability.config_id)

	func get_fail_reason(_ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> String:
		return "skill cooldown"


class TimedCooldownCost:
	extends Cost

	var _duration: float

	func _init(duration: float) -> void:
		type = "inkmon_timed_cooldown"
		_duration = duration

	func can_pay(_ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> bool:
		return true

	func pay(ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> void:
		var battle_ability_set := ctx.ability_set as InkMonBattleAbilitySet
		Log.assert_crash(battle_ability_set != null, "InkMonTimedCooldownCost", "requires InkMonBattleAbilitySet")
		battle_ability_set.start_cooldown(ctx.ability.config_id, _duration)

	func get_fail_reason(_ctx: AbilityLifecycleContext, _event: Dictionary, _game_state: Variant) -> String:
		return "cooldown cost failed"
