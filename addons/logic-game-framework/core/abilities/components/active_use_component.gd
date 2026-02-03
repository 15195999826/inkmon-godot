extends ActivateInstanceComponent
class_name ActiveUseComponent

const COMPONENT_TYPE := "ActiveUseComponent"

var _conditions: Array[Condition] = []
var _costs: Array[Cost] = []

func _init(config: ActiveUseConfig):
	# 构建父类配置
	var triggers_to_use: Array = config.triggers if not config.triggers.is_empty() else [_create_default_trigger_config()]
	var parent_config := ActivateInstanceConfig.new(
		config.timeline_id,
		config.tag_actions,
		triggers_to_use,
		config.trigger_mode
	)
	super._init(parent_config)
	type = COMPONENT_TYPE
	_conditions.assign(config.conditions)
	_costs.assign(config.costs)


func _create_default_trigger_config() -> TriggerConfig:
	var filter_fn := func(event_dict: Dictionary, ctx: AbilityLifecycleContext) -> bool:
		var ability_ref: Ability = ctx.ability
		var owner_id: String = ctx.owner_actor_id
		if ability_ref == null or owner_id == "":
			return false
		return event_dict.get("abilityInstanceId", "") == ability_ref.id and event_dict.get("sourceId", "") == owner_id
	return TriggerConfig.new(GameEvent.ABILITY_ACTIVATE_EVENT, filter_fn)

func on_event(event_dict: Dictionary, context: AbilityLifecycleContext, game_state_provider: Variant) -> bool:
	if not _check_triggers(event_dict, context):
		return false
	var ability_set := _get_ability_set(context, game_state_provider)
	if ability_set == null:
		return _activate_without_checks(event_dict, context, game_state_provider)
	var logic_time := _get_logic_time(event_dict, game_state_provider)
	var condition_ctx := {
		"owner_actor_id": context.owner_actor_id,
		"abilitySet": ability_set,
		"ability": context.ability,
		"gameplayState": game_state_provider,
	}
	if not _check_conditions(condition_ctx):
		return false
	var cost_ctx := {
		"owner_actor_id": context.owner_actor_id,
		"abilitySet": ability_set,
		"ability": context.ability,
		"gameplayState": game_state_provider,
		"logicTime": logic_time,
	}
	if not _check_costs(cost_ctx):
		return false
	_pay_costs(cost_ctx)
	return _activate_without_checks(event_dict, context, game_state_provider)

func _activate_without_checks(event_dict: Dictionary, context: AbilityLifecycleContext, game_state_provider: Variant) -> bool:
	_activate_execution(event_dict, context, game_state_provider)
	return true

func _check_conditions(ctx: Dictionary) -> bool:
	for condition in _conditions:
		if not condition.check(ctx):
			var reason: String = condition.type if condition.has("type") else ""
			if condition.has_method("get_fail_reason"):
				reason = str(condition.get_fail_reason(ctx))
			Log.debug("ActiveUseComponent", "条件不满足: %s" % reason)
			return false
	return true

func _check_costs(ctx: Dictionary) -> bool:
	for cost in _costs:
		if not cost.can_pay(ctx):
			var reason: String = cost.type if cost.has("type") else ""
			if cost.has_method("get_fail_reason"):
				reason = str(cost.get_fail_reason(ctx))
			Log.debug("ActiveUseComponent", "消耗不足: %s" % reason)
			return false
	return true

func _pay_costs(ctx: Dictionary) -> void:
	for cost in _costs:
		cost.pay(ctx)

func _get_ability_set(context: AbilityLifecycleContext, _game_state_provider: Variant) -> AbilitySet:
	var owner_id: String = context.owner_actor_id
	if owner_id == "":
		return null
	var actor := GameWorld.get_actor(owner_id)
	return IAbilitySetOwner.get_ability_set(actor)

func _get_logic_time(event_dict: Dictionary, game_state_provider: Variant) -> float:
	if event_dict.has("logicTime") and typeof(event_dict["logicTime"]) in [TYPE_INT, TYPE_FLOAT]:
		return float(event_dict["logicTime"])
	if game_state_provider != null and game_state_provider.has_method("get_logic_time"):
		return game_state_provider.get_logic_time()
	return float(Time.get_ticks_msec())
