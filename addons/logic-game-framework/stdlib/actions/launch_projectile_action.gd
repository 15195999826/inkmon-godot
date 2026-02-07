extends Action.BaseAction
class_name LaunchProjectileAction

const TYPE = "launchProjectile"

var _hit_callbacks: Array[Action.BaseAction] = []
var _miss_callbacks: Array[Action.BaseAction] = []
var _pierce_callbacks: Array[Action.BaseAction] = []

var _projectile_config: DictResolver
var _start_position: Vector3Resolver
var _target_position: Vector3Resolver
var _direction: Vector3Resolver
var _custom_data: DictResolver

## 构造函数
## @param target_selector: 目标选择器
## @param projectile_config: 投射物配置解析器
## @param start_position: 起始位置解析器，可选（null 表示需要从 ctx 获取）
## @param target_position: 目标位置解析器，可选（null 表示需要从 ctx 获取）
## @param direction: 方向解析器，可选
## @param custom_data: 自定义数据解析器，可选
func _init(
	target_selector: TargetSelector,
	projectile_config: DictResolver = Resolvers.dict_val({}),
	start_position: Vector3Resolver = null,
	target_position: Vector3Resolver = null,
	direction: Vector3Resolver = null,
	custom_data: DictResolver = Resolvers.dict_val({})
) -> void:
	super._init(target_selector)
	type = TYPE
	_projectile_config = projectile_config
	_start_position = start_position
	_target_position = target_position
	_direction = direction
	_custom_data = custom_data


## 重写 _freeze 以冻结回调 Action
func _freeze() -> void:
	super._freeze()
	for callback in _hit_callbacks:
		callback._freeze()
	for callback in _miss_callbacks:
		callback._freeze()
	for callback in _pierce_callbacks:
		callback._freeze()


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
	# 解析起始位置（必需）
	if _start_position == null:
		return ActionResult.create_failure_result("start_position resolver is required")
	var start_position := _start_position.resolve(ctx)

	# 解析目标位置（可选）
	var target_position: Vector3 = Vector3.ZERO
	if _target_position != null:
		target_position = _target_position.resolve(ctx)

	var targets := get_targets(ctx)
	var target: Variant = targets[0] if targets.size() > 0 else null
	var target_actor_id: String = target.id if target != null else ""

	# 解析其他参数
	var projectile_config := _projectile_config.resolve(ctx)
	var direction_value: Vector3 = Vector3.ZERO
	if _direction != null:
		direction_value = _direction.resolve(ctx)
	var custom_data_value := _custom_data.resolve(ctx)

	var source_actor_id: String = ctx.ability_ref.source_actor_id if ctx.ability_ref != null else "unknown"

	var projectile := ProjectileActor.new(projectile_config if projectile_config else {})

	var launch_params := {
		"source_actor_id": source_actor_id,
		"target_actor_id": target_actor_id,
		"startPosition": start_position,
		"targetPosition": target_position,
		"direction": direction_value,
		"customData": custom_data_value,
	}

	projectile.launch(launch_params)

	var launched_event := ProjectileEvents.create_projectile_launched_event(
		projectile.id,
		source_actor_id,
		start_position,
		projectile.config.get("projectileType", "bullet"),
		projectile.config.get("speed", 500.0),
		target_actor_id,
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
func process_hit_callbacks(hit_event: Dictionary, ctx: ExecutionContext) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for callback in _hit_callbacks:
		var callback_ctx := ExecutionContext.create_callback_context(ctx, hit_event)
		var callback_result := callback.execute(callback_ctx)
		callback._verify_unchanged()
		if callback_result != null and callback_result.event_dicts:
			events.append_array(callback_result.event_dicts)
	return events


## 处理投射物未命中回调
func process_miss_callbacks(miss_event: Dictionary, ctx: ExecutionContext) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for callback in _miss_callbacks:
		var callback_ctx := ExecutionContext.create_callback_context(ctx, miss_event)
		var callback_result := callback.execute(callback_ctx)
		callback._verify_unchanged()
		if callback_result != null and callback_result.event_dicts:
			events.append_array(callback_result.event_dicts)
	return events


## 处理投射物穿透回调
func process_pierce_callbacks(pierce_event: Dictionary, ctx: ExecutionContext) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for callback in _pierce_callbacks:
		var callback_ctx := ExecutionContext.create_callback_context(ctx, pierce_event)
		var callback_result := callback.execute(callback_ctx)
		callback._verify_unchanged()
		if callback_result != null and callback_result.event_dicts:
			events.append_array(callback_result.event_dicts)
	return events


## 创建从 Actor 获取位置的解析器
static func create_actor_position_resolver(actor_ref_resolver: Callable) -> Vector3Resolver:
	return Resolvers.vec3_fn(func(ctx: ExecutionContext) -> Vector3:
		var actor_ref: Variant = actor_ref_resolver.call(ctx)
		if not (actor_ref is Dictionary) or not actor_ref.has("id"):
			return Vector3.ZERO

		var actor := GameWorld.get_actor(actor_ref.id)
		if actor != null and "position" in actor:
			return actor.position
		return Vector3.ZERO
	)


## 创建固定位置的解析器
static func create_fixed_position_resolver(position: Vector3) -> Vector3Resolver:
	return Resolvers.vec3_val(position)


## 从事件中获取源位置的解析器
static func source_position_resolver() -> Vector3Resolver:
	return Resolvers.vec3_fn(func(ctx: ExecutionContext) -> Vector3:
		var event = ctx.get_current_event()
		if event and event.has("sourcePosition"):
			return event.sourcePosition
		return Vector3.ZERO
	)


## 从事件中获取目标位置的解析器
static func target_position_resolver() -> Vector3Resolver:
	return Resolvers.vec3_fn(func(ctx: ExecutionContext) -> Vector3:
		var event = ctx.get_current_event()
		if event and event.has("targetPosition"):
			return event.targetPosition
		return Vector3.ZERO
	)
