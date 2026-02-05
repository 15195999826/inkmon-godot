## 技能配置
class_name HexBattleSkillConfig


# ========== 技能类型 ==========

enum SkillType {
	HOLY_HEAL,
	SLASH,
	PRECISE_SHOT,
	FIREBALL,
	CRUSHING_BLOW,
	SWIFT_STRIKE
}


# ========== 技能配置项 ==========

class SkillConfigItem:
	var id: SkillType
	var name: String
	var description: String
	var damage: float
	var heal_amount: float
	var range_value: int  # 射程（格子数）
	var is_ranged: bool
	
	func _init(
		p_id: SkillType,
		p_name: String,
		p_description: String,
		p_range: int,
		p_is_ranged: bool,
		p_damage: float = 0.0,
		p_heal_amount: float = 0.0
	) -> void:
		id = p_id
		name = p_name
		description = p_description
		range_value = p_range
		is_ranged = p_is_ranged
		damage = p_damage
		heal_amount = p_heal_amount


# ========== 技能配置表 ==========

static func get_skill_config(skill_type: SkillType) -> SkillConfigItem:
	match skill_type:
		SkillType.HOLY_HEAL:
			return SkillConfigItem.new(
				SkillType.HOLY_HEAL,
				"圣光治愈",
				"治疗友方单位，恢复生命值",
				3, true, 0.0, 40.0
			)
		SkillType.SLASH:
			return SkillConfigItem.new(
				SkillType.SLASH,
				"横扫斩",
				"近战攻击，对敌人造成物理伤害",
				1, false, 50.0, 0.0
			)
		SkillType.PRECISE_SHOT:
			return SkillConfigItem.new(
				SkillType.PRECISE_SHOT,
				"精准射击",
				"远程攻击，精准命中敌人",
				4, true, 45.0, 0.0
			)
		SkillType.FIREBALL:
			return SkillConfigItem.new(
				SkillType.FIREBALL,
				"火球术",
				"远程魔法攻击，造成高额伤害",
				5, true, 80.0, 0.0
			)
		SkillType.CRUSHING_BLOW:
			return SkillConfigItem.new(
				SkillType.CRUSHING_BLOW,
				"毁灭重击",
				"近战重击，造成毁灭性伤害",
				1, false, 90.0, 0.0
			)
		SkillType.SWIFT_STRIKE:
			return SkillConfigItem.new(
				SkillType.SWIFT_STRIKE,
				"疾风连刺",
				"快速近战攻击，伤害较低但出手快",
				1, false, 30.0, 0.0
			)
		_:
			return SkillConfigItem.new(
				SkillType.SLASH,
				"普通攻击",
				"普通攻击",
				1, false, 10.0, 0.0
			)


# ========== 职业对应技能映射 ==========

static func get_class_skill(char_class: HexBattleClassConfig.CharacterClass) -> SkillType:
	match char_class:
		HexBattleClassConfig.CharacterClass.PRIEST:
			return SkillType.HOLY_HEAL
		HexBattleClassConfig.CharacterClass.WARRIOR:
			return SkillType.SLASH
		HexBattleClassConfig.CharacterClass.ARCHER:
			return SkillType.PRECISE_SHOT
		HexBattleClassConfig.CharacterClass.MAGE:
			return SkillType.FIREBALL
		HexBattleClassConfig.CharacterClass.BERSERKER:
			return SkillType.CRUSHING_BLOW
		HexBattleClassConfig.CharacterClass.ASSASSIN:
			return SkillType.SWIFT_STRIKE
		_:
			return SkillType.SLASH


## 技能类型转字符串
static func skill_to_string(skill_type: SkillType) -> String:
	match skill_type:
		SkillType.HOLY_HEAL:
			return "HolyHeal"
		SkillType.SLASH:
			return "Slash"
		SkillType.PRECISE_SHOT:
			return "PreciseShot"
		SkillType.FIREBALL:
			return "Fireball"
		SkillType.CRUSHING_BLOW:
			return "CrushingBlow"
		SkillType.SWIFT_STRIKE:
			return "SwiftStrike"
		_:
			return "Unknown"
