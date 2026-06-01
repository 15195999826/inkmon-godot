class_name InkMonWorldActor
extends Actor
## 主世界里一切"有位置的实体"的基类(玩家 / NPC / 战斗单位共有)。
##
## hex_position 是三者共有的状态,也是 WorldGI `actor_position_changed` mutation
## signal 报告的东西 —— 所以它住在基类,而非战斗特化。死亡 / ability / attribute
## 等战斗专属能力下沉到 InkMonBattleActor。
##
## 玩家 / NPC = 直接 InkMonWorldActor(只有位置,无 ability / timeline);
## 战斗单位 = InkMonBattleActor → InkMonUnitActor 特化。


var hex_position: HexCoord = HexCoord.invalid()


func _get_position() -> Vector3:
	if not hex_position.is_valid():
		return Vector3.ZERO
	return Vector3(hex_position.q, hex_position.r, 0.0)
