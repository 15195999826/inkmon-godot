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

## 离散跳格移动态(P4):逻辑真相永远是离散 hex 格(hex_position = 当前 occupant 格),
## 只多一个 [0,1) 进度标量,非连续浮点(sim-nav 不借)。
## moving_to = 正在进入的下一格(invalid = 静止);move_progress ∈ [0,1) 从 hex_position 朝 moving_to;
## pending_path = moving_to 之后待走的格(axial 序列,不含 moving_to)。
var moving_to: HexCoord = HexCoord.invalid()
var move_progress: float = 0.0
var pending_path: Array[Vector2i] = []


func _get_position() -> Vector3:
	if not hex_position.is_valid():
		return Vector3.ZERO
	return Vector3(hex_position.q, hex_position.r, 0.0)


func is_moving() -> bool:
	return moving_to.is_valid()
