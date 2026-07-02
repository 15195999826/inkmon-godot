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


# === 布阵 ===

## 按 preferred_coords 定点布阵, 占位/越界/已占时回退到 available_coords 首个可用格。
static func place_team_fixed(gi: InkMonWorldGI, team: Array[InkMonUnitActor], preferred_coords: Array[HexCoord]) -> void:
	var fallback := available_coords(gi)
	for i in range(team.size()):
		var coord := preferred_coords[i] if i < preferred_coords.size() else null
		if coord == null or not gi.grid.has_tile(coord) or gi.grid.is_occupied(coord):
			coord = pop_first_available(gi, fallback)
		if coord == null:
			continue
		gi.grid.place_occupant(coord, team[i])
		team[i].hex_position = coord.duplicate()


static func available_coords(gi: InkMonWorldGI) -> Array[HexCoord]:
	var result: Array[HexCoord] = []
	for coord in gi.grid.get_all_coords():
		if gi.grid.is_passable(coord) and not gi.grid.is_reserved(coord):
			result.append(coord)
	result.sort_custom(func(a: HexCoord, b: HexCoord) -> bool:
		if a.q == b.q:
			return a.r < b.r
		return a.q < b.q
	)
	return result


static func pop_first_available(gi: InkMonWorldGI, coords: Array[HexCoord]) -> HexCoord:
	while not coords.is_empty():
		var coord := coords.pop_front() as HexCoord
		if gi.grid.has_tile(coord) and gi.grid.is_passable(coord):
			return coord
	return null


## 找出某 actor 在 grid 上持有的所有 reservation 坐标 (battle teardown 清理用)。
static func find_reservations_by(gi: InkMonWorldGI, actor_id: String) -> Array[HexCoord]:
	var result: Array[HexCoord] = []
	if gi.grid == null:
		return result
	for coord in gi.grid.get_all_coords():
		if gi.grid.get_reservation(coord) == actor_id:
			result.append(coord)
	return result


## 清一个 battle actor 在 grid 上的外部状态 (occupant + reservation), 不动 registry (P021)。
## 三个调用点唯一共用实现: 死亡即清 (damage_utils) / 战斗 teardown / remove_actor ——
## reservation 存储语义变更只改此处, 不再有第二份手写扫描可漏改。
static func clear_actor_footprint(gi: InkMonWorldGI, battle_actor: InkMonBattleActor) -> void:
	if gi.grid == null or battle_actor == null:
		return
	if battle_actor.hex_position != null and battle_actor.hex_position.is_valid():
		var occupant: Variant = gi.grid.get_occupant(battle_actor.hex_position)
		# 守卫 occupant is InkMonBattleActor: 主世界 grid 的 occupant 是 string id, 直接 == Object 会报
		# Invalid operands; 且 reset-on-start 时 grid 已切回 overworld + actor 仍持上场 battle 坐标,
		# 故对 overworld grid 此处天然 no-op (battle grid 每场 reconfigure 重置占用)。
		if occupant is InkMonBattleActor and occupant == battle_actor:
			gi.grid.remove_occupant(battle_actor.hex_position)
	for coord in find_reservations_by(gi, battle_actor.get_id()):
		gi.grid.cancel_reservation(coord)


# === battle grid 配置 ===

## 战斗 grid 配置 (config.map_config 或默认)。configure_grid 是 LGF battle-host 钩子, 留 GI、此处委派回去。
static func configure_battle_grid(gi: InkMonWorldGI, config: Dictionary) -> void:
	gi._ensure_started()
	var grid_config := config.get("map_config", null) as GridMapConfig
	if grid_config == null:
		grid_config = build_default_grid_config()
	gi.configure_grid(grid_config)


static func build_default_grid_config() -> GridMapConfig:
	var config := GridMapConfig.new()
	config.grid_type = GridMapConfig.GridType.HEX
	config.draw_mode = GridMapConfig.DrawMode.RADIUS
	config.radius = 5
	config.size = 10.0
	config.orientation = GridMapConfig.Orientation.FLAT
	return config


# === 发奖 ===

## 结果摘要: winner_team / source_team / reward_gold (按胜负)。_result 为空 = 无战斗结果, 返回 {}。
static func get_result_summary(gi: InkMonWorldGI) -> Dictionary:
	if gi._result == "":
		return {}
	var winner_team := "left" if gi._result == "left_win" else "right"
	return {
		"result": gi._result,
		"winner_team": winner_team,
		"source_team": "left",
		"reward_gold": gi.WIN_REWARD_GOLD if winner_team == "left" else 0,
	}


## adr/0001:战斗结束直接把奖励落在活 actor 上 —— gold 加 player_actor, exp 加左队中属 roster 的活 actor。
## 无"摘要回写"(actor 即真相, HP 已在战斗中原地变)。返回结果摘要供表演展示。
static func finalize_battle_rewards(gi: InkMonWorldGI) -> Dictionary:
	var summary := get_result_summary(gi)
	if summary.is_empty():
		return summary
	var winner_team := str(summary.get("winner_team", ""))
	if gi.player_actor != null:
		gi.player_actor.gold += maxi(0, int(summary.get("reward_gold", 0)))
	for actor in gi.left_team:
		if not gi.roster.has(actor):
			continue
		if actor.is_dead():
			actor.add_exp(gi.LOSS_EXP)
		else:
			actor.add_exp(gi.WIN_EXP if winner_team == "left" else gi.LOSS_EXP)
	return summary
