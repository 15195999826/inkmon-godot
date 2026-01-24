## 振奋 Buff - 防御力 +10，持续 2 秒
class_name HexBattleInspireBuff
extends RefCounted


## 振奋 Buff 持续时间（毫秒）
const INSPIRE_DURATION_MS := 2000.0

## 振奋 Buff 防御力加成
const INSPIRE_DEF_BONUS := 10.0


## 振奋 Buff 配置
##
## - 效果：防御力 +10（AddBase）
## - 持续：2 秒
## - 标签：buff, inspire
static var INSPIRE_BUFF := AbilityConfig.new(
	"buff_inspire",
	"振奋",
	"防御力 +10，持续 2 秒",
	"",
	["buff", "inspire"],
	[],
	[
		# 属性修改：防御力 +10
		StatModifierComponent.new([
			{
				"attributeName": "def",
				"modifierType": AttributeModifier.MODIFIER_TYPE_ADD_BASE,
				"value": INSPIRE_DEF_BONUS,
			},
		]),
		# 持续时间：2 秒
		TimeDurationComponent.new(INSPIRE_DURATION_MS),
	]
)


## 获取振奋 Buff 配置
static func get_config() -> AbilityConfig:
	return INSPIRE_BUFF
