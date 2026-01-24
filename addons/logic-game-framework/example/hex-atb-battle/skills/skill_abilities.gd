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
static func _get_target_coord_from_event() -> DictResolver:
	return Resolvers.dict_fn(func(ctx: ExecutionContext) -> Dictionary:
		var evt: Variant = ctx.get_current_event()
		if evt is Dictionary:
			return evt.get("target_coord", {}) as Dictionary
		return {}
	)


# ========== 移动 Ability ==========

## 移动 - 移动到相邻格子（两阶段）
static var MOVE_ABILITY := {
	"configId": "action_move",
	"displayName": "移动",
	"description": "移动到相邻格子",
	"tags": ["action", "move"],
	"components": [
		func():
			return ActivateInstanceComponent.new({
				"triggers": [{
					"eventKind": GameEvent.ABILITY_ACTIVATE_EVENT,
					"filter": func(event: Dictionary, ctx: Dictionary) -> bool:
						var ability = ctx.get("ability", null)
						if ability == null:
							return false
						return event.get("abilityInstanceId", "") == ability.id,
				}],
				"timelineId": HexBattleSkillTimelines.TIMELINE_ID["MOVE"],
				"tagActions": {
					"start": [HexBattleStartMoveAction.new(
						TargetSelector.ability_owner(),
						_get_target_coord_from_event()
					)],
					"execute": [HexBattleApplyMoveAction.new(
						TargetSelector.ability_owner(),
						_get_target_coord_from_event()
					)],
				},
			}),
	],
}


# ========== 技能 Ability ==========

## 横扫斩 - 近战物理攻击
## 示例：使用 on_critical 回调，暴击时额外造成 10 点伤害
static var SLASH_ABILITY := {
	"configId": "skill_slash",
	"displayName": "横扫斩",
	"description": "近战攻击，对敌人造成物理伤害（暴击时额外伤害）",
	"tags": ["skill", "active", "melee", "enemy"],
	"activeUseComponents": [
		func():
			return ActiveUseComponent.new({
				"conditions": [HexBattleCooldownSystem.CooldownCondition.new()],
				"costs": [HexBattleCooldownSystem.TimedCooldownCost.new(SKILL_COOLDOWNS["slash"])],
				"timelineId": HexBattleSkillTimelines.TIMELINE_ID["SLASH"],
				"tagActions": {
					"start": [StageCueAction.new(
						TargetSelector.current_target(),
						Resolvers.str_val("melee_slash")
					)],
					"hit": [
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
					],
				},
			}),
	],
}


## 精准射击 - 远程物理攻击（发射箭矢）
static var PRECISE_SHOT_ABILITY := {
	"configId": "skill_precise_shot",
	"displayName": "精准射击",
	"description": "远程攻击，发射箭矢精准命中敌人",
	"tags": ["skill", "active", "ranged", "enemy", "projectile"],
	"activeUseComponents": [
		func():
			return ActiveUseComponent.new({
				"conditions": [HexBattleCooldownSystem.CooldownCondition.new()],
				"costs": [HexBattleCooldownSystem.TimedCooldownCost.new(SKILL_COOLDOWNS["precise_shot"])],
				"timelineId": HexBattleSkillTimelines.TIMELINE_ID["PRECISE_SHOT"],
				"tagActions": {
					"start": [StageCueAction.new(
						TargetSelector.current_target(),
						Resolvers.str_val("ranged_arrow")
					)],
					"hit": [HexBattleDamageAction.new(
						TargetSelector.current_target(),
						45.0,
						HexBattleReplayEvents.DamageType.PHYSICAL
					)],
				},
			}),
	],
}


## 火球术 - 远程魔法攻击
static var FIREBALL_ABILITY := {
	"configId": "skill_fireball",
	"displayName": "火球术",
	"description": "远程魔法攻击，造成高额伤害",
	"tags": ["skill", "active", "ranged", "magic", "enemy"],
	"activeUseComponents": [
		func():
			return ActiveUseComponent.new({
				"conditions": [HexBattleCooldownSystem.CooldownCondition.new()],
				"costs": [HexBattleCooldownSystem.TimedCooldownCost.new(SKILL_COOLDOWNS["fireball"])],
				"timelineId": HexBattleSkillTimelines.TIMELINE_ID["FIREBALL"],
				"tagActions": {
					"start": [StageCueAction.new(
						TargetSelector.current_target(),
						Resolvers.str_val("magic_fireball")
					)],
					"hit": [HexBattleDamageAction.new(
						TargetSelector.current_target(),
						80.0,
						HexBattleReplayEvents.DamageType.MAGICAL
					)],
				},
			}),
	],
}


## 毁灭重击 - 近战重击
static var CRUSHING_BLOW_ABILITY := {
	"configId": "skill_crushing_blow",
	"displayName": "毁灭重击",
	"description": "近战重击，造成毁灭性伤害",
	"tags": ["skill", "active", "melee", "enemy"],
	"activeUseComponents": [
		func():
			return ActiveUseComponent.new({
				"conditions": [HexBattleCooldownSystem.CooldownCondition.new()],
				"costs": [HexBattleCooldownSystem.TimedCooldownCost.new(SKILL_COOLDOWNS["crushing_blow"])],
				"timelineId": HexBattleSkillTimelines.TIMELINE_ID["CRUSHING_BLOW"],
				"tagActions": {
					"start": [StageCueAction.new(
						TargetSelector.current_target(),
						Resolvers.str_val("melee_heavy")
					)],
					"hit": [HexBattleDamageAction.new(
						TargetSelector.current_target(),
						90.0,
						HexBattleReplayEvents.DamageType.PHYSICAL
					)],
				},
			}),
	],
}


## 疾风连刺 - 快速多段攻击
static var SWIFT_STRIKE_ABILITY := {
	"configId": "skill_swift_strike",
	"displayName": "疾风连刺",
	"description": "快速近战攻击，三连击",
	"tags": ["skill", "active", "melee", "enemy"],
	"activeUseComponents": [
		func():
			return ActiveUseComponent.new({
				"conditions": [HexBattleCooldownSystem.CooldownCondition.new()],
				"costs": [HexBattleCooldownSystem.TimedCooldownCost.new(SKILL_COOLDOWNS["swift_strike"])],
				"timelineId": HexBattleSkillTimelines.TIMELINE_ID["SWIFT_STRIKE"],
				"tagActions": {
					"start": [StageCueAction.new(
						TargetSelector.current_target(),
						Resolvers.str_val("melee_combo"),
						Resolvers.dict_val({ "hits": 3 })
					)],
					"hit1": [HexBattleDamageAction.new(
						TargetSelector.current_target(),
						10.0,
						HexBattleReplayEvents.DamageType.PHYSICAL
					)],
					"hit2": [HexBattleDamageAction.new(
						TargetSelector.current_target(),
						10.0,
						HexBattleReplayEvents.DamageType.PHYSICAL
					)],
					"hit3": [HexBattleDamageAction.new(
						TargetSelector.current_target(),
						10.0,
						HexBattleReplayEvents.DamageType.PHYSICAL
					)],
				},
			}),
	],
}


## 圣光治愈 - 治疗技能
static var HOLY_HEAL_ABILITY := {
	"configId": "skill_holy_heal",
	"displayName": "圣光治愈",
	"description": "治疗友方单位，恢复生命值",
	"tags": ["skill", "active", "heal", "ally"],
	"activeUseComponents": [
		func():
			return ActiveUseComponent.new({
				"conditions": [HexBattleCooldownSystem.CooldownCondition.new()],
				"costs": [HexBattleCooldownSystem.TimedCooldownCost.new(SKILL_COOLDOWNS["holy_heal"])],
				"timelineId": HexBattleSkillTimelines.TIMELINE_ID["HOLY_HEAL"],
				"tagActions": {
					"start": [StageCueAction.new(
						TargetSelector.current_target(),
						Resolvers.str_val("magic_heal")
					)],
					"heal": [HexBattleHealAction.new(
						TargetSelector.current_target(),
						Resolvers.float_val(40.0)
					)],
				},
			}),
	],
}


# ========== 技能映射 ==========

## 根据技能类型获取 Ability 配置
static func get_skill_ability(skill_type: HexBattleSkillConfig.SkillType) -> Dictionary:
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
