class_name InkMonBattleActor
extends InkMonWorldActor
## 战斗单位骨架 = InkMonWorldActor 的位置 + BattleActor 的战斗设施(死亡锁存 / owner id
## 同步 / 录像订阅)。本类只钉住 InkMon 侧的强类型 ability_set / attribute_set。


var ability_set: InkMonBattleAbilitySet


func get_attribute_set() -> InkMonUnitAttributeSet:
	push_error("InkMonBattleActor.get_attribute_set must be overridden by subclass: %s" % type)
	return null


func get_ability_set() -> InkMonBattleAbilitySet:
	return ability_set
