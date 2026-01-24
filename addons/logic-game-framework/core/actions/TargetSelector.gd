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


## 固定目标选择器（用于测试或预设目标）
class Fixed extends TargetSelector:
	var _targets: Array[ActorRef]
	
	func _init(targets: Array[ActorRef]):
		_targets = targets
	
	func select(_ctx: ExecutionContext) -> Array[ActorRef]:
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
static func fixed(targets: Array[ActorRef]) -> Fixed:
	return Fixed.new(targets)
