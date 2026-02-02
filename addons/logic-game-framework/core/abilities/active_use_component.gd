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
	var filter_fn := func(event: Dictionary, ctx: Dictionary) -> bool:
		var ability_ref = ctx.get("ability", null)
		var owner_ref = ctx.get("owner", null)
		if ability_ref == null or owner_ref == null:
			return false
		return event.get("abilityInstanceId", "") == ability_ref.id and event.get("sourceId", "") == owner_ref.id
	return TriggerConfig.new(GameEvent.ABILITY_ACTIVATE_EVENT, filter_fn)

func on_event(event: Dictionary, context: Dictionary, game_state_provider) -> bool:
	if not _check_triggers(event, context):
		return false
	var ability_set = _get_ability_set(context, game_state_provider)
	if ability_set == null:
		return _activate_without_checks(event, context, game_state_provider)
	var logic_time := _get_logic_time(event, game_state_provider)
	var condition_ctx := {
		"owner": context.get("owner", null),
		"abilitySet": ability_set,
		"ability": context.get("ability", null),
		"gameplayState": game_state_provider,
	}
	if not _check_conditions(condition_ctx):
		return false
	var cost_ctx := {
		"owner": context.get("owner", null),
		"abilitySet": ability_set,
		"ability": context.get("ability", null),
		"gameplayState": game_state_provider,
		"logicTime": logic_time,
	}
	if not _check_costs(cost_ctx):
		return false
	_pay_costs(cost_ctx)
	return _activate_without_checks(event, context, game_state_provider)

func _activate_without_checks(event: Dictionary, context: Dictionary, game_state_provider) -> bool:
	_activate_execution(event, context, game_state_provider)
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

func _get_ability_set(context: Dictionary, game_state_provider):
	if game_state_provider == null or not game_state_provider.has_method("get_actor"):
		return null
	var owner_ref = context.get("owner", null)
	if owner_ref == null:
		return null
	var actor = game_state_provider.get_actor(owner_ref.id)
	return IAbilitySetOwner.get_ability_set(actor)

func _get_logic_time(event: Dictionary, game_state_provider) -> float:
	if event.has("logicTime") and typeof(event["logicTime"]) in [TYPE_INT, TYPE_FLOAT]:
		return float(event["logicTime"])
	if game_state_provider != null and game_state_provider.has_method("get_logic_time"):
		return game_state_provider.get_logic_time()
	return float(Time.get_ticks_msec())
