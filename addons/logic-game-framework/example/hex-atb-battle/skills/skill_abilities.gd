## Ability 定义
##
## 使用框架 Ability 系统实现的技能和行动配置。
## 包括移动、攻击技能、治疗技能等。
class_name HexBattleSkillAbilities
extends RefCounted


# ========== 技能冷却配置（毫秒） ==========

const SKILL_COOLDOWNS := {
	"slash": 2000.0,
	"precise_shot": 2500.0,
	"fireball": 4000.0,
	"crushing_blow": 5000.0,
	"swift_strike": 3000.0,
	"holy_heal": 4000.0,
}


# ========== 目标选择器 ==========
# 使用框架提供的 TargetSelector 类

## 获取 Ability Owner 的选择器
static func get_ability_owner_selector() -> TargetSelector:
	return TargetSelector.ability_owner()


## 获取当前事件目标的选择器
static func get_current_target_selector() -> TargetSelector:
	return TargetSelector.current_target()


# ========== 辅助函数 ==========

## 从事件中获取目标坐标的解析器
static func _get_target_coord_from_event() -> Resolver:
	return Resolvers.dict_fn(func(ctx: ExecutionContext) -> Dictionary:
		var evt: Variant = ctx.get_current_event()
		if evt is Dictionary:
			return evt.get("target_coord", {}) as Dictionary
		return {}
	)


# ========== 移动 Ability ==========

## 移动 - 移动到相邻格子（两阶段）
static var MOVE_ABILITY := AbilityConfig.builder() \
	.config_id("action_move") \
	.display_name("移动") \
	.description("移动到相邻格子") \
	.tags(["action", "move"]) \
	.component(ActivateInstanceConfig.builder() \
		.timeline_id(HexBattleSkillTimelines.TIMELINE_ID.MOVE) \
		.on_tag(TimelineTags.START, [HexBattleStartMoveAction.new(
			TargetSelector.ability_owner(),
			_get_target_coord_from_event()
		)]) \
		.on_tag(TimelineTags.EXECUTE, [HexBattleApplyMoveAction.new(
			TargetSelector.ability_owner(),
			_get_target_coord_from_event()
		)]) \
		.trigger(TriggerConfig.new(
			GameEvent.ABILITY_ACTIVATE_EVENT,
			func(event: Dictionary, ctx: Dictionary) -> bool:
				var ability = ctx.get("ability", null)
				if ability == null:
					return false
				return event.get("abilityInstanceId", "") == ability.id
		)) \
		.build() \
	) \
	.build()


# ========== 技能 Ability ==========

## 横扫斩 - 近战物理攻击
## 示例：使用 on_critical 回调，暴击时额外造成 10 点伤害
static var SLASH_ABILITY := AbilityConfig.builder() \
	.config_id("skill_slash") \
	.display_name("横扫斩") \
	.description("近战攻击，对敌人造成物理伤害（暴击时额外伤害）") \
	.tags(["skill", "active", "melee", "enemy"]) \
	.active_use(ActiveUseConfig.builder() \
		.timeline_id(HexBattleSkillTimelines.TIMELINE_ID.SLASH) \
		.on_tag(TimelineTags.START, [StageCueAction.new(
			TargetSelector.current_target(),
			Resolvers.str_val("melee_slash")
		)]) \
		.on_tag(TimelineTags.HIT, [
			# 主伤害，带暴击回调
			HexBattleDamageAction.new(
				TargetSelector.current_target(),
				50.0,
				HexBattleReplayEvents.DamageType.PHYSICAL
			).on_critical(
				# 暴击时额外造成 10 点伤害
				HexBattleDamageAction.new(
					TargetSelector.current_target(),
					10.0,
					HexBattleReplayEvents.DamageType.PHYSICAL
				)
			),
		]) \
		.condition(HexBattleCooldownSystem.CooldownCondition.new()) \
		.cost(HexBattleCooldownSystem.TimedCooldownCost.new(SKILL_COOLDOWNS["slash"])) \
		.build() \
	) \
	.build()


## 精准射击 - 远程物理攻击（发射箭矢）
static var PRECISE_SHOT_ABILITY := AbilityConfig.builder() \
	.config_id("skill_precise_shot") \
	.display_name("精准射击") \
	.description("远程攻击，发射箭矢精准命中敌人") \
	.tags(["skill", "active", "ranged", "enemy", "projectile"]) \
	.active_use(ActiveUseConfig.builder() \
		.timeline_id(HexBattleSkillTimelines.TIMELINE_ID.PRECISE_SHOT) \
		.on_tag(TimelineTags.START, [StageCueAction.new(
			TargetSelector.current_target(),
			Resolvers.str_val("ranged_arrow")
		)]) \
		.on_tag(TimelineTags.HIT, [HexBattleDamageAction.new(
			TargetSelector.current_target(),
			45.0,
			HexBattleReplayEvents.DamageType.PHYSICAL
		)]) \
		.condition(HexBattleCooldownSystem.CooldownCondition.new()) \
		.cost(HexBattleCooldownSystem.TimedCooldownCost.new(SKILL_COOLDOWNS["precise_shot"])) \
		.build() \
	) \
	.build()


## 火球术 - 远程魔法攻击
static var FIREBALL_ABILITY := AbilityConfig.builder() \
	.config_id("skill_fireball") \
	.display_name("火球术") \
	.description("远程魔法攻击，造成高额伤害") \
	.tags(["skill", "active", "ranged", "magic", "enemy"]) \
	.active_use(ActiveUseConfig.builder() \
		.timeline_id(HexBattleSkillTimelines.TIMELINE_ID.FIREBALL) \
		.on_tag(TimelineTags.START, [StageCueAction.new(
			TargetSelector.current_target(),
			Resolvers.str_val("magic_fireball")
		)]) \
		.on_tag(TimelineTags.HIT, [HexBattleDamageAction.new(
			TargetSelector.current_target(),
			80.0,
			HexBattleReplayEvents.DamageType.MAGICAL
		)]) \
		.condition(HexBattleCooldownSystem.CooldownCondition.new()) \
		.cost(HexBattleCooldownSystem.TimedCooldownCost.new(SKILL_COOLDOWNS["fireball"])) \
		.build() \
	) \
	.build()


## 毁灭重击 - 近战重击
static var CRUSHING_BLOW_ABILITY := AbilityConfig.builder() \
	.config_id("skill_crushing_blow") \
	.display_name("毁灭重击") \
	.description("近战重击，造成毁灭性伤害") \
	.tags(["skill", "active", "melee", "enemy"]) \
	.active_use(ActiveUseConfig.builder() \
		.timeline_id(HexBattleSkillTimelines.TIMELINE_ID.CRUSHING_BLOW) \
		.on_tag(TimelineTags.START, [StageCueAction.new(
			TargetSelector.current_target(),
			Resolvers.str_val("melee_heavy")
		)]) \
		.on_tag(TimelineTags.HIT, [HexBattleDamageAction.new(
			TargetSelector.current_target(),
			90.0,
			HexBattleReplayEvents.DamageType.PHYSICAL
		)]) \
		.condition(HexBattleCooldownSystem.CooldownCondition.new()) \
		.cost(HexBattleCooldownSystem.TimedCooldownCost.new(SKILL_COOLDOWNS["crushing_blow"])) \
		.build() \
	) \
	.build()


## 疾风连刺 - 快速多段攻击
static var SWIFT_STRIKE_ABILITY := AbilityConfig.builder() \
	.config_id("skill_swift_strike") \
	.display_name("疾风连刺") \
	.description("快速近战攻击，三连击") \
	.tags(["skill", "active", "melee", "enemy"]) \
	.active_use(ActiveUseConfig.builder() \
		.timeline_id(HexBattleSkillTimelines.TIMELINE_ID.SWIFT_STRIKE) \
		.on_tag(TimelineTags.START, [StageCueAction.new(
			TargetSelector.current_target(),
			Resolvers.str_val("melee_combo"),
			Resolvers.dict_val({ "hits": 3 })
		)]) \
		.on_tag(TimelineTags.HIT1, [HexBattleDamageAction.new(
			TargetSelector.current_target(),
			10.0,
			HexBattleReplayEvents.DamageType.PHYSICAL
		)]) \
		.on_tag(TimelineTags.HIT2, [HexBattleDamageAction.new(
			TargetSelector.current_target(),
			10.0,
			HexBattleReplayEvents.DamageType.PHYSICAL
		)]) \
		.on_tag(TimelineTags.HIT3, [HexBattleDamageAction.new(
			TargetSelector.current_target(),
			10.0,
			HexBattleReplayEvents.DamageType.PHYSICAL
		)]) \
		.condition(HexBattleCooldownSystem.CooldownCondition.new()) \
		.cost(HexBattleCooldownSystem.TimedCooldownCost.new(SKILL_COOLDOWNS["swift_strike"])) \
		.build() \
	) \
	.build()


## 圣光治愈 - 治疗技能
static var HOLY_HEAL_ABILITY := AbilityConfig.builder() \
	.config_id("skill_holy_heal") \
	.display_name("圣光治愈") \
	.description("治疗友方单位，恢复生命值") \
	.tags(["skill", "active", "heal", "ally"]) \
	.active_use(ActiveUseConfig.builder() \
		.timeline_id(HexBattleSkillTimelines.TIMELINE_ID.HOLY_HEAL) \
		.on_tag(TimelineTags.START, [StageCueAction.new(
			TargetSelector.current_target(),
			Resolvers.str_val("magic_heal")
		)]) \
		.on_tag(TimelineTags.HEAL, [HexBattleHealAction.new(
			TargetSelector.current_target(),
			Resolvers.float_val(40.0)
		)]) \
		.condition(HexBattleCooldownSystem.CooldownCondition.new()) \
		.cost(HexBattleCooldownSystem.TimedCooldownCost.new(SKILL_COOLDOWNS["holy_heal"])) \
		.build() \
	) \
	.build()


# ========== 技能映射 ==========

## 根据技能类型获取 Ability 配置
static func get_skill_ability(skill_type: HexBattleSkillConfig.SkillType) -> AbilityConfig:
	match skill_type:
		HexBattleSkillConfig.SkillType.SLASH:
			return SLASH_ABILITY
		HexBattleSkillConfig.SkillType.PRECISE_SHOT:
			return PRECISE_SHOT_ABILITY
		HexBattleSkillConfig.SkillType.FIREBALL:
			return FIREBALL_ABILITY
		HexBattleSkillConfig.SkillType.CRUSHING_BLOW:
			return CRUSHING_BLOW_ABILITY
		HexBattleSkillConfig.SkillType.SWIFT_STRIKE:
			return SWIFT_STRIKE_ABILITY
		HexBattleSkillConfig.SkillType.HOLY_HEAL:
			return HOLY_HEAL_ABILITY
		_:
			return SLASH_ABILITY
