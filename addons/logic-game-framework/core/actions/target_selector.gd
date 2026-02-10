## TargetSelector - 目标选择器基类
##
## 用于在 Action 执行时选择目标 Actor。
## 通过继承此类创建自定义选择器。
## select() 返回 Array[String]，每个元素是 actor_id。
##
## 使用示例:
##   var action = DamageAction.new({
##       "targetSelector": TargetSelector.current_target(),
##       "damage": 50.0,
##   })
class_name TargetSelector
extends RefCounted


## 选择目标（子类必须重写）
## 返回目标 actor_id 列表
func select(_ctx: ExecutionContext) -> Array[String]:
	return []


# ============================================================
# 预定义选择器
# ============================================================

## 从当前事件获取目标（event.target_actor_id 或 event.target_actor_ids）
class CurrentTarget extends TargetSelector:
	func select(ctx: ExecutionContext) -> Array[String]:
		var event := ctx.get_current_event()
		if event.is_empty():
			return []
		if event.has("target_actor_ids") and event["target_actor_ids"] is Array:
			var result: Array[String] = []
			for t in event["target_actor_ids"]:
				if t is String:
					result.append(t)
			return result
		if event.has("target_actor_id") and event["target_actor_id"] is String:
			return [event["target_actor_id"]]
		return []


## 选择 Ability 的 owner
class AbilityOwner extends TargetSelector:
	func select(ctx: ExecutionContext) -> Array[String]:
		if ctx.ability_ref != null and not ctx.ability_ref.owner_actor_id.is_empty():
			return [ctx.ability_ref.owner_actor_id]
		return []


## 固定目标选择器（用于测试或预设目标）
class Fixed extends TargetSelector:
	var _targets: Array[String]
	
	func _init(targets: Array[String]):
		_targets = targets
	
	func select(_ctx: ExecutionContext) -> Array[String]:
		return _targets


# ============================================================
# 工厂方法
# ============================================================

## 创建从当前事件获取目标的选择器
static func current_target() -> CurrentTarget:
	return CurrentTarget.new()


## 创建选择 Ability owner 的选择器
static func ability_owner() -> AbilityOwner:
	return AbilityOwner.new()


## 创建固定目标选择器
static func fixed(targets: Array[String]) -> Fixed:
	return Fixed.new(targets)


## 自定义选择器（通过 Callable 实现）
class Custom extends TargetSelector:
	var _fn: Callable
	
	func _init(fn: Callable):
		_fn = fn
	
	func select(ctx: ExecutionContext) -> Array[String]:
		return _fn.call(ctx)


## 创建自定义选择器
## fn 签名: func(ctx: ExecutionContext) -> Array[String]
static func custom(fn: Callable) -> Custom:
	return Custom.new(fn)
