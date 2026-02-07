## 被动技能配置
##
## 使用 NoInstanceComponent 实现被动触发效果。
## 被动技能监听游戏事件，满足条件时自动执行 Action 链。
class_name HexBattlePassiveAbilities


# ========== 被动技能配置 ==========

## 荆棘反伤 - 受到伤害时反弹固定伤害
##
## 触发条件：自己受到伤害时
## 效果：对攻击者造成 2 点纯粹伤害
static var THORN_PASSIVE := (
	AbilityConfig.builder()
	.config_id("passive_thorn")
	.display_name("荆棘反伤")
	.description("受到伤害时，对攻击者造成 2 点伤害")
	.ability_tags(["passive", "defensive", "reflect"])
	.component_config(
		NoInstanceConfig.builder()
		.trigger(TriggerConfig.new("damage", _thorn_filter()))
		.action(HexBattleReflectDamageAction.new(
			2.0,
			BattleEvents.DamageType.PURE
		))
		.build()
	)
	.build()
)


## 荆棘反伤过滤器
static func _thorn_filter() -> Callable:
	return func(event_dict: Dictionary, ctx: AbilityLifecycleContext) -> bool:
		var owner_id := ctx.owner_actor_id
		if owner_id.is_empty():
			return false
		var target_id := event_dict.get("target_actor_id", "") as String
		var source_id := event_dict.get("source_actor_id", "") as String
		var is_reflected := event_dict.get("is_reflected", false) as bool
		var is_target := target_id == owner_id
		var has_source := not source_id.is_empty()
		var not_self_damage := source_id != owner_id
		return is_target and has_source and not_self_damage and not is_reflected


# ========== 导出 ==========

## 所有被动技能
static func get_passive_ability(passive_type: String) -> AbilityConfig:
	match passive_type:
		"Thorn":
			return THORN_PASSIVE
		_:
			return null
