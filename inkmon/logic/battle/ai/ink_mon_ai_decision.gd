class_name InkMonAIDecision
extends RefCounted
## AI → procedure 的行动决策 (typed 内部契约, 替掉 {type: "..."} 裸 dict + switch-on-string)。
## transient、不进存档 (adr/0002 三叉合规); procedure 按字段派发, strategy 可脱离战斗单测。


enum Kind { SKIP, SKILL, MOVE }


var kind: Kind = Kind.SKIP
var ability_instance_id := ""
var target_actor_id := ""
var target_coord: HexCoord = null


static func skip() -> InkMonAIDecision:
	return InkMonAIDecision.new()


static func use_skill(p_ability_instance_id: String, p_target_actor_id: String) -> InkMonAIDecision:
	var decision := InkMonAIDecision.new()
	decision.kind = Kind.SKILL
	decision.ability_instance_id = p_ability_instance_id
	decision.target_actor_id = p_target_actor_id
	return decision


static func move_to(p_ability_instance_id: String, coord: HexCoord) -> InkMonAIDecision:
	var decision := InkMonAIDecision.new()
	decision.kind = Kind.MOVE
	decision.ability_instance_id = p_ability_instance_id
	decision.target_coord = coord
	return decision


func is_skip() -> bool:
	return kind == Kind.SKIP
