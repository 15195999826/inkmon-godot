## TargetSelector - 目标选择器基类
##
## 用于在 Action 执行时选择目标 Actor。
## 通过继承此类创建自定义选择器。
##
## 使用示例:
##   var action = DamageAction.new({
##       "targetSelector": TargetSelector.current_target(),
##       "damage": 50.0,
##   })
extends RefCounted
class_name TargetSelector


## 目标引用类（简单包装 actor_id）
class TargetRef extends RefCounted:
	var id: String
	
	func _init(actor_id: String) -> void:
		id = actor_id


## 选择目标（子类必须重写）
func select(_ctx: ExecutionContext) -> Array[TargetRef]:
	return []


# ============================================================
# 预定义选择器
# ============================================================

## 从当前事件获取目标（event.target_actor_id 或 event.target_actor_ids）
class CurrentTarget extends TargetSelector:
	func select(ctx: ExecutionContext) -> Array[TargetRef]:
		var event = ctx.get_current_event()
		if event == null:
			return []
		if event is Dictionary:
			if event.has("target_actor_ids") and event["target_actor_ids"] is Array:
				var result: Array[TargetRef] = []
				for t in event["target_actor_ids"]:
					if t is String:
						result.append(TargetRef.new(t))
				return result
			if event.has("target_actor_id") and event["target_actor_id"] is String:
				return [TargetRef.new(event["target_actor_id"])]
		return []


## 选择 Ability 的 owner
class AbilityOwner extends TargetSelector:
	func select(ctx: ExecutionContext) -> Array[TargetRef]:
		if ctx.ability_ref != null and not ctx.ability_ref.owner_actor_id.is_empty():
			return [TargetRef.new(ctx.ability_ref.owner_actor_id)]
		return []


## 固定目标选择器（用于测试或预设目标）
class Fixed extends TargetSelector:
	var _targets: Array[TargetRef]
	
	func _init(targets: Array[TargetRef]):
		_targets = targets
	
	func select(_ctx: ExecutionContext) -> Array[TargetRef]:
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
static func fixed(targets: Array[TargetRef]) -> Fixed:
	return Fixed.new(targets)
