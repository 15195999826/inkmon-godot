class_name InkMonBattleTargeting
## 战斗目标筛选 / 技能使用规则的无状态 helper (adr/0002 傀儡测试 → static 纯函数)。


## 技能可否对 target 使用: 阵营 tag (enemy/ally/self) + 射程。纯规则不读全局态
## (曾住 InkMonWorldGI, 零 self 引用, 按三叉退回 static)。
static func can_use_skill_on(actor: InkMonUnitActor, skill: Ability, target: InkMonBattleActor) -> bool:
	if actor == null or skill == null or target == null or target.is_dead():
		return false

	if target is InkMonUnitActor:
		var unit_target := target as InkMonUnitActor
		var same_team := actor.get_team_id() == unit_target.get_team_id()
		var is_self := actor.get_id() == unit_target.get_id()
		if skill.has_ability_tag("enemy") and same_team:
			return false
		if skill.has_ability_tag("ally") and not same_team:
			return false
		if skill.has_ability_tag("ally") and is_self and not skill.has_ability_tag("self"):
			return false

	var skill_range := skill.get_meta_int(InkMonSkillMetaKeys.RANGE, 1)
	if not actor.hex_position.is_valid() or not target.hex_position.is_valid():
		return false
	return actor.hex_position.distance_to(target.hex_position) <= skill_range


## 距 from_pos 最近的敌方存活单位; exclude_ids 内的跳过 (如链式弹跳已访问目标); 无候选返回 null。
## AI 普攻/移动寻标 与 chain lightning 弹跳寻标 共用 (曾两处手写同一份最小化循环)。
static func nearest_enemy(
	battle: InkMonWorldGI,
	team_id: int,
	from_pos: HexCoord,
	exclude_ids: Array[String] = []
) -> InkMonUnitActor:
	var best: InkMonUnitActor = null
	var best_distance := 1 << 30
	for candidate in battle.get_alive_actors():
		if candidate.get_team_id() == team_id or candidate.get_id() in exclude_ids:
			continue
		var distance := from_pos.distance_to(candidate.hex_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
