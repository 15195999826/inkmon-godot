## 冷却系统 - 条件和消耗
##
## 实现技能冷却的条件检查和消耗支付
class_name HexBattleCooldownSystem
extends RefCounted


# ========== 冷却就绪条件 ==========

## 检查技能是否不在冷却中
class CooldownCondition:
	extends RefCounted
	
	var type := "cooldown_ready"
	
	func check(ctx: Dictionary) -> bool:
		var ability_set = ctx.get("abilitySet", null)
		var ability = ctx.get("ability", null)
		if ability_set == null or ability == null:
			return true
		if ability_set.has_method("is_on_cooldown"):
			return not ability_set.is_on_cooldown(ability.config_id)
		return true
	
	func get_fail_reason(_ctx: Dictionary) -> String:
		return "技能冷却中"


# ========== 定时冷却消耗 ==========

## 支付冷却时间
class TimedCooldownCost:
	extends RefCounted
	
	var type := "timed_cooldown"
	var _duration: float
	
	func _init(duration: float) -> void:
		_duration = duration
	
	func can_pay(_ctx: Dictionary) -> bool:
		# 冷却消耗总是可以支付（条件检查在 CooldownCondition 中）
		return true
	
	func pay(ctx: Dictionary) -> void:
		var ability_set = ctx.get("abilitySet", null)
		var ability = ctx.get("ability", null)
		if ability_set == null or ability == null:
			return
		if ability_set.has_method("start_cooldown"):
			ability_set.start_cooldown(ability.config_id, _duration)
	
	func get_fail_reason(_ctx: Dictionary) -> String:
		return "冷却消耗失败"


# ========== 便捷别名 ==========

## 创建冷却条件
static func create_cooldown_condition() -> CooldownCondition:
	return CooldownCondition.new()


## 创建定时冷却消耗
static func create_timed_cooldown_cost(duration: float) -> TimedCooldownCost:
	return TimedCooldownCost.new(duration)
