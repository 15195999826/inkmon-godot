extends Action.BaseAction
class_name StageCueAction

const TYPE = "stageCue"

var cue_id_resolver: Callable
var params_resolver: Callable

func _init(params: Dictionary):
	super._init(params)
	type = TYPE

	var cue_id_input = params.get("cueId", "")
	if cue_id_input is Callable:
		cue_id_resolver = cue_id_input
	else:
		cue_id_resolver = func(_ctx): return cue_id_input

	var params_input = params.get("params", {})
	if params_input is Callable:
		params_resolver = params_input
	else:
		params_resolver = func(_ctx): return params_input

func execute(ctx: ExecutionContext) -> ActionResult:
	if not ctx.ability:
		push_error("[StageCueAction] ctx.ability is required")
		return ActionResult.create_failure_result("ctx.ability is required")

	var source_actor_id = ctx.ability.source.id

	var targets = get_targets(ctx)
	var target_actor_ids := []
	for target in targets:
		if target is Dictionary and target.has("id"):
			target_actor_ids.append(target.id)

	var cue_id = ParamResolver.resolve_param(cue_id_resolver.call(ctx), ctx)
	var params_value = ParamResolver.resolve_param(params_resolver.call(ctx), ctx)

	var event = GameEvent.create_stage_cue_event(
		source_actor_id,
		target_actor_ids,
		cue_id,
		params_value
	)

	ctx.eventCollector.push(event)

	return ActionResult.create_success_result([event])

static func create_stage_cue_action(params: Dictionary) -> StageCueAction:
	return StageCueAction.new(params)
