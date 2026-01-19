extends RefCounted
class_name ParamResolver

const ExecutionContext = preload("res://logic/actions/ExecutionContext.gd")

static func resolve_param(resolver, ctx: ExecutionContext):
	if resolver is Callable:
		return resolver.call(ctx)
	return resolver

static func resolve_optional_param(resolver, default_value, ctx: ExecutionContext):
	if resolver == null:
		return default_value
	return resolve_param(resolver, ctx)
