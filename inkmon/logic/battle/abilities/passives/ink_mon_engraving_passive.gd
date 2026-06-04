class_name InkMonEngravingPassive
## 刻印 = LGF 被动 ability (game-architecture-patterns 决策: 复用既有 passive/event 系统,
## 与 InkMonDamageMathPassive 同款 PreEvent hook)。
##
## v1: 强化拥有者的技能输出 —— hook PRE_DAMAGE, 当 owner 是伤害 SOURCE 时给伤害乘 BONUS_MULT。
## 这是"改技能行为(数值增强)"而非六维折叠 (docs §8c: 刻印不进 battle_stats 折叠)。
## 每条 engraving grant 一个本被动 (可叠); target_slot 已存/投影, 留 per-skill 精确 scoping 给 lab 内容。


const CONFIG_ID := "inkmon_engraving_passive"
const BONUS_MULT := 1.25


static var ABILITY := (
	AbilityConfig.builder()
	.config_id(CONFIG_ID)
	.display_name("InkMon Engraving")
	.description("Strengthens the engraved unit's skill output")
	.ability_tags(["intrinsic", "inkmon_engraving"])
	.component_config(
		PreEventConfig.new(
			InkMonBattlePreEvents.PRE_DAMAGE_EVENT,
			_handle_pre_damage,
			_is_owner_source,
			"InkMon Engraving"
		)
	)
	.build()
)


static func _is_owner_source(event: Dictionary, ctx: AbilityLifecycleContext) -> bool:
	return str(event.get("source_actor_id", "")) == ctx.owner_actor_id


static func _handle_pre_damage(_mutable: MutableEvent, ctx: AbilityLifecycleContext) -> Intent:
	var owner := GameWorld.get_actor(ctx.owner_actor_id) as InkMonUnitActor
	if owner == null or owner.is_dead():
		return EventPhase.pass_intent()
	return EventPhase.modify_intent(ctx.ability.id, [
		Modification.multiply("damage", BONUS_MULT, ctx.ability.id, "InkMon engraving"),
	])
