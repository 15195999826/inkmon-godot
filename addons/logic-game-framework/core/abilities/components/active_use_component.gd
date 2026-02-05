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
	if not _check_conditions(context, event_dict, game_state_provider):
		return false
	if not _check_costs(context, event_dict, game_state_provider):
		return false
	_pay_costs(context, event_dict, game_state_provider)
	return _activate_without_checks(event_dict, context, game_state_provider)

func _activate_without_checks(event_dict: Dictionary, context: AbilityLifecycleContext, game_state_provider: Variant) -> bool:
	_activate_execution(event_dict, context, game_state_provider)
	return true

func _check_conditions(ctx: AbilityLifecycleContext, event: Dictionary, game_state: Variant) -> bool:
	for condition in _conditions:
		if not condition.check(ctx, event, game_state):
			var reason := condition.get_fail_reason(ctx, event, game_state)
			if reason == "":
				reason = condition.get_condition_type()
			Log.debug("ActiveUseComponent", "条件不满足: %s" % reason)
			return false
	return true

func _check_costs(ctx: AbilityLifecycleContext, event: Dictionary, game_state: Variant) -> bool:
	for cost in _costs:
		if not cost.can_pay(ctx, event, game_state):
			var reason := cost.get_fail_reason(ctx, event, game_state)
			if reason == "":
				reason = cost.type
			Log.debug("ActiveUseComponent", "消耗不足: %s" % reason)
			return false
	return true

func _pay_costs(ctx: AbilityLifecycleContext, event: Dictionary, game_state: Variant) -> void:
	for cost in _costs:
		cost.pay(ctx, event, game_state)
