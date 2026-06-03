class_name InkMonBattleSetup
## 战斗装配无状态服务 (adr/0002 "logic→static service")。
##
## 把 `InkMonWorldGI` 里**无状态**的战斗装配杂活(建队 / 布阵 / 配 battle grid / 发奖)集中到此处:
## 全 `static func`,收 `gi: InkMonWorldGI` 当参数,**无字段、无状态、不存 gi 引用**。
## GI 保留薄入口 / 薄委派 wrapper;LGF battle-host 钩子(start_battle / configure_grid / 等)仍钉死在 GI。


# === 建队 ===

## 建**临时**队伍 (m1/默认路径): 从 config.left_roster/right_roster 或默认 roster key 建 transient actor,
## append 进 gi.left_team / gi.right_team。玩家活 roster 出战不走此路 (走 battle_roster_slice)。
static func setup_teams(gi: InkMonWorldGI, config: Dictionary) -> void:
	var left_roster: Array = config.get("left_roster", InkMonUnitConfig.get_default_roster(0))
	for key in left_roster:
		gi.left_team.append(create_team_actor(gi, str(key), 0))
	var right_roster: Array = config.get("right_roster", InkMonUnitConfig.get_default_roster(1))
	for key in right_roster:
		gi.right_team.append(create_team_actor(gi, str(key), 1))


static func create_team_actor(gi: InkMonWorldGI, unit_key: String, team_id: int) -> InkMonUnitActor:
	var actor := InkMonUnitActor.new(unit_key)
	actor.set_team_id(team_id)
	return gi.add_actor(actor) as InkMonUnitActor


## 出战队 = 活 roster 前 MAX_BATTLE_UNITS 只 (常驻 registry, 已 add_actor; 此处只取切片 + 标队伍)。
static func battle_roster_slice(gi: InkMonWorldGI) -> Array[InkMonUnitActor]:
	var result: Array[InkMonUnitActor] = []
	for i in range(mini(gi.MAX_BATTLE_UNITS, gi.roster.size())):
		gi.roster[i].set_team_id(0)
		result.append(gi.roster[i])
	return result


## 训练假人队 (临时对战单位, stub 弱数值保训练可胜)。非 roster, battle 结束随 _reset_battle_state 移除。
static func build_training_dummies(gi: InkMonWorldGI) -> Array[InkMonUnitActor]:
	var result: Array[InkMonUnitActor] = []
	var skills := [
		InkMonStun.CONFIG_ID,
		InkMonFireball.CONFIG_ID,
		InkMonHolyHeal.CONFIG_ID,
		InkMonPoison.CONFIG_ID,
	]
	for i in range(gi.MAX_BATTLE_UNITS):
		var actor := InkMonUnitActor.create_combat_unit({
			"species": "training_dummy_%d" % i,
			"personality": InkMonUnitConfig.PERSONALITY_AGGRESSIVE,
			"elements": [InkMonElementChart.WATER],
			"skill_slots": [{"slot_index": 0, "skill_id": skills[i]}],
			"battle_stats": {
				"max_hp": 30.0,
				"ad": 6.0,
				"ap": 6.0,
				"armor": 0.0,
				"mr": 0.0,
				"speed": 70.0,
			},
		})
		actor.set_team_id(1)
		gi.add_actor(actor)
		result.append(actor)
	return result
