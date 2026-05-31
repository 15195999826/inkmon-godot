class_name InkMonApplyBuffAction
extends Action.PrimitiveAction


var _buff_config: AbilityConfig


func _init(target_selector: TargetSelector, buff_config: AbilityConfig) -> void:
	super._init(target_selector)
	type = "inkmon_apply_buff"
	_buff_config = buff_config


func execute(ctx: ExecutionContext) -> ActionResult:
	var battle: InkMonWorldGI = ctx.game_state_provider
	if battle == null:
		return ActionResult.create_success_result([])

	var source_id := ctx.ability_ref.owner_actor_id if ctx.ability_ref != null else ""
	for target_id in get_targets(ctx):
		var target_actor := battle.get_unit_actor(target_id)
		if target_actor == null or target_actor.is_dead():
			continue
		var new_buff := Ability.new(_buff_config, target_id, source_id)
		target_actor.ability_set.grant_ability(new_buff, battle)
		print("  [InkMonBuff] %s gains %s" % [target_actor.get_display_name(), _buff_config.config_id])

	return ActionResult.create_success_result([], { "buff_config_id": _buff_config.config_id })
