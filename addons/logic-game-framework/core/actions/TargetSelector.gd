## TargetSelector - 目标选择器基类
##
## 用于在 Action 执行时选择目标 Actor。
## 通过继承此类创建自定义选择器。
##
## 使用示例:
##   var action = DamageAction.new({
##       "targetSelector": TargetSelector.CurrentTarget.new(),
##       "damage": 50.0,
##   })
extends RefCounted
class_name TargetSelector


## 选择目标（子类必须重写）
func select(_ctx: ExecutionContext) -> Array[ActorRef]:
	return []


# ============================================================
# 预定义选择器
# ============================================================

## 从当前事件获取目标（event.target 或 event.targets）
class CurrentTarget extends TargetSelector:
	func select(ctx: ExecutionContext) -> Array[ActorRef]:
		var event = ctx.get_current_event()
		if event == null:
			return []
		if event is Dictionary:
			if event.has("targets") and event["targets"] is Array:
				var result: Array[ActorRef] = []
				for t in event["targets"]:
					if t is ActorRef:
						result.append(t)
				return result
			if event.has("target") and event["target"] is ActorRef:
				return [event["target"]]
		return []


## 选择 Ability 的 owner
class AbilityOwner extends TargetSelector:
	func select(ctx: ExecutionContext) -> Array[ActorRef]:
		if ctx.ability is Dictionary and ctx.ability.has("owner"):
			var owner = ctx.ability["owner"]
			if owner is ActorRef:
				return [owner]
		return []


## 从 Callable 创建选择器（兼容旧代码）
class FromCallable extends TargetSelector:
	var _callable: Callable
	
	func _init(callable: Callable):
		_callable = callable
	
	func select(ctx: ExecutionContext) -> Array[ActorRef]:
		var result = _callable.call(ctx)
		if result is Array[ActorRef]:
			return result
		# 兼容返回普通 Array 的 callable
		var typed_result: Array[ActorRef] = []
		for item in result:
			if item is ActorRef:
				typed_result.append(item)
		return typed_result


# ============================================================
# 工厂方法
# ============================================================

## 创建从当前事件获取目标的选择器
static func current_target() -> CurrentTarget:
	return CurrentTarget.new()


## 创建选择 Ability owner 的选择器
static func ability_owner() -> AbilityOwner:
	return AbilityOwner.new()


## 从 Callable 创建选择器（兼容旧代码）
static func from_callable(callable: Callable) -> FromCallable:
	return FromCallable.new(callable)
