## Replay Events - 战斗回放事件类型定义
##
## 定义 hex-atb-battle 项目特有的回放事件类型。
## 这些事件由各 Action 产生，记录到回放时间线中。
##
## 命名约定:
## - 事件使用过去时态命名（表示"已发生的事实"）
## - Actor 引用使用 actor_id: String
## - 坐标使用 Dictionary { "q": int, "r": int }
class_name HexBattleReplayEvents
extends RefCounted


# ========== 伤害类型 ==========

enum DamageType {
	PHYSICAL,
	MAGICAL,
	PURE
}


# ========== 事件工厂函数 ==========

## 创建伤害事件
static func create_damage_event(
	target_actor_id: String,
	damage: float,
	damage_type: DamageType,
	source_actor_id: String = "",
	is_critical: bool = false,
	is_reflected: bool = false
) -> Dictionary:
	var event := {
		"kind": "damage",
		"target_actor_id": target_actor_id,
		"damage": damage,
		"damage_type": _damage_type_to_string(damage_type),
		"is_critical": is_critical,
		"is_reflected": is_reflected,
	}
	if source_actor_id != "":
		event["source_actor_id"] = source_actor_id
	return event


## 创建治疗事件
static func create_heal_event(
	target_actor_id: String,
	heal_amount: float,
	source_actor_id: String = ""
) -> Dictionary:
	var event := {
		"kind": "heal",
		"target_actor_id": target_actor_id,
		"heal_amount": heal_amount,
	}
	if source_actor_id != "":
		event["source_actor_id"] = source_actor_id
	return event


## 创建开始移动事件
static func create_move_start_event(
	actor_id: String,
	from_hex: Dictionary,
	to_hex: Dictionary
) -> Dictionary:
	return {
		"kind": "move_start",
		"actor_id": actor_id,
		"from_hex": from_hex,
		"to_hex": to_hex,
	}


## 创建移动完成事件
static func create_move_complete_event(
	actor_id: String,
	from_hex: Dictionary,
	to_hex: Dictionary
) -> Dictionary:
	return {
		"kind": "move_complete",
		"actor_id": actor_id,
		"from_hex": from_hex,
		"to_hex": to_hex,
	}


## 创建死亡事件
static func create_death_event(
	actor_id: String,
	killer_actor_id: String = ""
) -> Dictionary:
	var event := {
		"kind": "death",
		"actor_id": actor_id,
	}
	if killer_actor_id != "":
		event["killer_actor_id"] = killer_actor_id
	return event


# ========== 类型守卫 ==========

static func is_damage_event(event: Dictionary) -> bool:
	return event.get("kind") == "damage"


static func is_heal_event(event: Dictionary) -> bool:
	return event.get("kind") == "heal"


static func is_move_start_event(event: Dictionary) -> bool:
	return event.get("kind") == "move_start"


static func is_move_complete_event(event: Dictionary) -> bool:
	return event.get("kind") == "move_complete"


static func is_death_event(event: Dictionary) -> bool:
	return event.get("kind") == "death"


# ========== 辅助函数 ==========

static func _damage_type_to_string(damage_type: DamageType) -> String:
	match damage_type:
		DamageType.PHYSICAL:
			return "physical"
		DamageType.MAGICAL:
			return "magical"
		DamageType.PURE:
			return "pure"
		_:
			return "unknown"


static func string_to_damage_type(s: String) -> DamageType:
	match s:
		"physical":
			return DamageType.PHYSICAL
		"magical":
			return DamageType.MAGICAL
		"pure":
			return DamageType.PURE
		_:
			return DamageType.PHYSICAL
