extends Action.BaseAction
class_name StageCueAction

const TYPE = "stageCue"

var cue_id_resolver: Callable
var params_resolver: Callable

## 构造函数
## @param target_selector: 目标选择器
## @param cue_id: 舞台提示 ID（String 或 Callable）
## @param cue_params: 舞台提示参数（Dictionary 或 Callable），可选
func _init(
	target_selector: TargetSelector,
	cue_id: Variant,  # String 或 Callable
	cue_params: Variant = {}  # Dictionary 或 Callable
) -> void:
	super._init(target_selector)
	type = TYPE

	if cue_id is Callable:
		cue_id_resolver = cue_id
	else:
		cue_id_resolver = func(_ctx): return cue_id

	if cue_params is Callable:
		params_resolver = cue_params
	else:
		params_resolver = func(_ctx): return cue_params

func execute(ctx: ExecutionContext) -> ActionResult:
	if not ctx.ability:
		push_error("[StageCueAction] ctx.ability is required")
		return ActionResult.create_failure_result("ctx.ability is required")

	var source_actor_id = ctx.ability.source.id

	var targets: Array[ActorRef] = get_targets(ctx)
	var target_actor_ids: Array[String] = []
	for target in targets:
		target_actor_ids.append(target.id)

	var cue_id_raw = cue_id_resolver.call(ctx)
	var params_raw = params_resolver.call(ctx)

	var cue_id: String = cue_id_raw if cue_id_raw is String else str(cue_id_raw)
	var params_value: Variant = params_raw if params_raw else {}

	var event = GameEvent.create_stage_cue_event(
		source_actor_id,
		target_actor_ids,
		cue_id,
		params_value
	)

	ctx.event_collector.push(event)

	return ActionResult.create_success_result([event])

## 工厂方法（兼容旧 API，建议直接使用 new）
static func create_stage_cue_action(
	target_selector: TargetSelector,
	cue_id: Variant,
	cue_params: Variant = {}
) -> StageCueAction:
	return StageCueAction.new(target_selector, cue_id, cue_params)
