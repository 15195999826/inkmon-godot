extends Action.BaseAction
class_name LaunchProjectileAction

const TYPE = "launchProjectile"

var _hit_callbacks: Array = []
var _miss_callbacks: Array = []
var _pierce_callbacks: Array = []

var projectile_config_resolver: Callable
var start_position_resolver: Callable
var target_position_resolver: Callable
var direction_resolver: Callable
var custom_data_resolver: Callable

func _init(params: Dictionary):
	super._init(params)
	type = TYPE

	var projectile_config_input = params.get("projectileConfig", {})
	if projectile_config_input is Callable:
		projectile_config_resolver = projectile_config_input
	else:
		projectile_config_resolver = func(_ctx): return projectile_config_input

	start_position_resolver = _get_position_resolver(params.get("startPositionResolver", null))
	target_position_resolver = _get_position_resolver(params.get("targetPositionResolver", null))

	if params.has("direction") and params["direction"] is Callable:
		direction_resolver = params["direction"]
	else:
		direction_resolver = func(_ctx): return null

	if params.has("customData") and params["customData"] is Callable:
		custom_data_resolver = params["customData"]
	else:
		custom_data_resolver = func(_ctx): return null


func _get_position_resolver(resolver) -> Callable:
	if resolver == null:
		return func(_ctx): return null
	if resolver is Callable:
		return resolver
	if resolver is Vector3:
		return func(_ctx): return resolver
	return func(_ctx): return null


func on_projectile_hit(action: Action.BaseAction) -> LaunchProjectileAction:
	_hit_callbacks.append(action)
	return self


func on_projectile_miss(action: Action.BaseAction) -> LaunchProjectileAction:
	_miss_callbacks.append(action)
	return self


func on_projectile_pierce(action: Action.BaseAction) -> LaunchProjectileAction:
	_pierce_callbacks.append(action)
	return self


func execute(ctx: ExecutionContext) -> ActionResult:
	var start_position := start_position_resolver.call(ctx)
	if start_position == null:
		return ActionResult.create_failure_result("Cannot resolve start position")

	var target_position = target_position_resolver.call(ctx)
	var targets := get_targets(ctx)
	var target = targets[0] if targets.size() > 0 else null

	var projectile_config_raw = projectile_config_resolver.call(ctx)
	var direction_raw = direction_resolver.call(ctx)
	var custom_data_raw = custom_data_resolver.call(ctx)

	var projectile_config: Dictionary = projectile_config_raw if projectile_config_raw is Dictionary else {}
	var direction_value = direction_raw
	var custom_data_value = custom_data_raw if custom_data_raw else {}

	var source = ctx.ability.source if ctx.ability else {"id": "unknown"}

	var projectile := ProjectileActor.new(projectile_config if projectile_config else {})

	var launch_params := {
		"source": source,
		"target": target,
		"startPosition": start_position,
		"targetPosition": target_position,
		"direction": direction_value,
		"customData": custom_data_value,
	}

	projectile.launch(launch_params)

	var launched_event = ProjectileEvents.create_projectile_launched_event(
		projectile.id,
		source,
		start_position,
		projectile.config.get("projectileType", "bullet"),
		projectile.config.get("speed", 500.0),
		target,
		target_position
	)

	ctx.event_collector.push(launched_event)

	var result := ActionResult.create_success_result([launched_event])
	result.data = {
		"projectile": projectile,
		"projectileId": projectile.id,
	}

	return result


## 处理投射物命中回调
func process_hit_callbacks(hit_event: Dictionary, ctx: ExecutionContext) -> Array:
	var events: Array = []
	for callback in _hit_callbacks:
		if callback.has_method("execute"):
			var callback_ctx = ExecutionContext.create_callback_context(ctx, hit_event)
			var callback_result = callback.execute(callback_ctx)
			if callback_result != null and callback_result.events:
				events.append_array(callback_result.events)
	return events


## 处理投射物未命中回调
func process_miss_callbacks(miss_event: Dictionary, ctx: ExecutionContext) -> Array:
	var events: Array = []
	for callback in _miss_callbacks:
		if callback.has_method("execute"):
			var callback_ctx = ExecutionContext.create_callback_context(ctx, miss_event)
			var callback_result = callback.execute(callback_ctx)
			if callback_result != null and callback_result.events:
				events.append_array(callback_result.events)
	return events


## 处理投射物穿透回调
func process_pierce_callbacks(pierce_event: Dictionary, ctx: ExecutionContext) -> Array:
	var events: Array = []
	for callback in _pierce_callbacks:
		if callback.has_method("execute"):
			var callback_ctx = ExecutionContext.create_callback_context(ctx, pierce_event)
			var callback_result = callback.execute(callback_ctx)
			if callback_result != null and callback_result.events:
				events.append_array(callback_result.events)
	return events


static func create_actor_position_resolver(actor_ref_resolver: Callable) -> Callable:
	return func(ctx: ExecutionContext):
		var actor_ref = actor_ref_resolver.call(ctx)
		if not (actor_ref is Dictionary) or not actor_ref.has("id"):
			return null

		var state = ctx.gameplay_state
		if state and state.has_method("get_actor"):
			var actor = state.get_actor(actor_ref.id)
			if actor and actor.has("position"):
				return actor.position
		return null


static func create_fixed_position_resolver(position: Vector3) -> Callable:
	return func(_ctx): return position


static func source_position_resolver(ctx: ExecutionContext) -> Vector3:
	var event = ctx.get_current_event()
	if event and event.has("sourcePosition"):
		return event.sourcePosition
	return Vector3.ZERO


static func get_target_position_from_event(ctx: ExecutionContext) -> Vector3:
	var event = ctx.get_current_event()
	if event and event.has("targetPosition"):
		return event.targetPosition
	return Vector3.ZERO
