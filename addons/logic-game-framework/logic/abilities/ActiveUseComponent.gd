extends ActivateInstanceComponent
class_name ActiveUseComponent

const COMPONENT_TYPE := "ActiveUseComponent"

var _conditions: Array = []
var _costs: Array = []

func _init(config: Dictionary):
	var triggers: Array = []
	if config.has("triggers"):
		triggers = config.get("triggers", [])
	else:
		triggers = [_create_default_trigger()]
	var inner_config := config.duplicate(true)
	inner_config["triggers"] = triggers
	super._init(inner_config)
	type = COMPONENT_TYPE
	_conditions = config.get("conditions", [])
	_costs = config.get("costs", [])

func on_event(event: Dictionary, context: Dictionary, gameplay_state) -> bool:
	if not _check_triggers(event, context):
		return false
	var ability_set = _get_ability_set(context, gameplay_state)
	if ability_set == null:
		return _activate_without_checks(event, context, gameplay_state)
	var logic_time := _get_logic_time(event, gameplay_state)
	var condition_ctx := {
		"owner": context.get("owner", null),
		"abilitySet": ability_set,
		"ability": context.get("ability", null),
		"gameplayState": gameplay_state,
	}
	if not _check_conditions(condition_ctx):
		return false
	var cost_ctx := {
		"owner": context.get("owner", null),
		"abilitySet": ability_set,
		"ability": context.get("ability", null),
		"gameplayState": gameplay_state,
		"logicTime": logic_time,
	}
	if not _check_costs(cost_ctx):
		return false
	_pay_costs(cost_ctx)
	return _activate_without_checks(event, context, gameplay_state)

func _activate_without_checks(event: Dictionary, context: Dictionary, gameplay_state) -> bool:
	_activate_execution(event, context, gameplay_state)
	return true

func _check_conditions(ctx: Dictionary) -> bool:
	for condition in _conditions:
		if condition != null and condition.has_method("check"):
			if not condition.check(ctx):
				var reason: String = condition.type if condition.has("type") else ""
				if condition.has_method("get_fail_reason"):
					reason = str(condition.get_fail_reason(ctx))
				Log.debug("ActiveUseComponent", "条件不满足: %s" % reason)
				return false
	return true

func _check_costs(ctx: Dictionary) -> bool:
	for cost in _costs:
		if cost != null and cost.has_method("can_pay"):
			if not cost.can_pay(ctx):
				var reason: String = cost.type if cost.has("type") else ""
				if cost.has_method("get_fail_reason"):
					reason = str(cost.get_fail_reason(ctx))
				Log.debug("ActiveUseComponent", "消耗不足: %s" % reason)
				return false
	return true

func _pay_costs(ctx: Dictionary) -> void:
	for cost in _costs:
		if cost != null and cost.has_method("pay"):
			cost.pay(ctx)

func _get_ability_set(context: Dictionary, gameplay_state):
	if gameplay_state != null and gameplay_state.has_method("get_ability_set_for_actor"):
		var owner_ref = context.get("owner", null)
		if owner_ref != null:
			return gameplay_state.get_ability_set_for_actor(owner_ref.id)
	return null

func _get_logic_time(event: Dictionary, gameplay_state) -> float:
	if event.has("logicTime") and typeof(event["logicTime"]) in [TYPE_INT, TYPE_FLOAT]:
		return float(event["logicTime"])
	if gameplay_state != null and gameplay_state.has("logicTime"):
		return float(gameplay_state.logicTime)
	return float(Time.get_ticks_msec())

func _create_default_trigger() -> Dictionary:
	return {
		"eventKind": GameEvent.ABILITY_ACTIVATE_EVENT,
		"filter": func(event: Dictionary, ctx: Dictionary) -> bool:
			var ability_ref = ctx.get("ability", null)
			var owner_ref = ctx.get("owner", null)
			if ability_ref == null or owner_ref == null:
				return false
			return event.get("abilityInstanceId", "") == ability_ref.id and event.get("sourceId", "") == owner_ref.id,
	}
