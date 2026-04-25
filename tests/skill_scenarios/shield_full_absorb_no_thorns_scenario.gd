## Shield 完全吸收时 Thorn 不触发反伤
##
## 验证 on-damage-taken 反应（如 Thorn）的 filter 规则：
##   actual_life_damage > 0 才触发；若伤害被护盾完全吸收，反伤静默。
##
## 设定：enemy.atk = 20（< ward 30），单次 Strike 必被全吸。
##   - 暴击：30 = ward 30 → 全吸 + ward 破
##   - 无暴击：20 < 30 → 全吸 + ward 未破
## 两种情况 actual_life_damage 都为 0，Thorn 都不应反弹。
class_name ShieldFullAbsorbNoThornsScenario
extends SkillScenario


func get_name() -> String:
	return "Full shield absorption does NOT trigger thorn"


func get_scene_config() -> Dictionary:
	return {
		"map": {"rows": 3, "cols": 3},
		"caster":  {"class": "WARRIOR", "pos": [0, 0], "hp": 1000},
		"enemies": [{"class": "WARRIOR", "pos": [1, 0], "atk": 20, "hp": 500}],
	}


func get_passives() -> Array[AbilityConfig]:
	return [HexBattleThorn.ABILITY, HexBattleWardBuff.WARD_BUFF]


func get_actions() -> Array[Dictionary]:
	return [{"caster": "enemy_0", "skill": HexBattleStrike.ABILITY, "target": "caster"}]


func get_max_ticks() -> int:
	return 30


func assert_replay(ctx: ScenarioAssertContext) -> void:
	var dmgs := ctx.filter_damage_events({"target_actor_id": ctx.caster_id})
	if dmgs.is_empty():
		ctx.fail("no damage event captured")
		return

	# 第一次主伤害：20 (no crit) 或 30 (crit)，都 ≤ ward 30 → 全部吸收
	var first: Dictionary = dmgs[0]
	var damage_value: float = first.get("damage", 0.0) as float
	var absorbed: float = first.get("shield_absorbed", -1.0) as float
	var actual_life: float = first.get("actual_life_damage", -1.0) as float

	ctx.assert_float_eq(absorbed, damage_value,
		"all damage absorbed (damage=%.0f)" % damage_value)
	ctx.assert_float_eq(actual_life, 0.0, "actual_life_damage = 0 on full absorption")

	# Thorn 应静默：所有 reflected 反伤为 0
	var enemy := ctx.enemy_id(0)
	var reflected := ctx.filter_damage_events({
		"target_actor_id": enemy,
		"damage_type": "pure",
	})
	ctx.assert_eq(reflected.size(), 0,
		"thorn does NOT reflect on full absorption (got %d reflects)" % reflected.size())
