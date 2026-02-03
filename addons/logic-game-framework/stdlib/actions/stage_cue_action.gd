extends Action.BaseAction
class_name StageCueAction

const TYPE = "stageCue"

var _cue_id: StringResolver
var _cue_params: DictResolver

## 构造函数
## @param target_selector: 目标选择器
## @param cue_id: 舞台提示 ID 解析器
## @param cue_params: 舞台提示参数解析器，可选
func _init(
	target_selector: TargetSelector,
	cue_id: StringResolver,
	cue_params: DictResolver = Resolvers.dict_val({})
) -> void:
	super._init(target_selector)
	type = TYPE
	_cue_id = cue_id
	_cue_params = cue_params

func execute(ctx: ExecutionContext) -> ActionResult:
	if ctx.ability.is_empty():
		push_error("[StageCueAction] ctx.ability is required")
		return ActionResult.create_failure_result("ctx.ability is required")

	var source_actor_id: String = ctx.ability.get("source_actor_id", "")

	var targets := get_targets(ctx)
	var target_actor_ids: Array[String] = []
	for target in targets:
		target_actor_ids.append(target.id)

	var cue_id_value := _cue_id.resolve(ctx)
	var params_value := _cue_params.resolve(ctx)

	var event := GameEvent.StageCue.create(
		source_actor_id,
		target_actor_ids,
		cue_id_value,
		params_value
	)

	ctx.event_collector.push(event.to_dict())

	return ActionResult.create_success_result([event.to_dict()])
