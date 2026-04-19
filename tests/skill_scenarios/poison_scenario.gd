## Poison DOT 场景：caster 对相邻 enemy 施毒，验证 3→2→1 层衰减伤害 + 耗尽自毁
class_name PoisonScenario
extends SkillScenario


func get_name() -> String:
	return "Poison DOT 3→2→1 (total=6)"


func get_scene_config() -> Dictionary:
	return {
		"map": {"rows": 3, "cols": 3},
		"caster":  {"class": "WARRIOR", "pos": [0, 0]},
		"enemies": [{"class": "WARRIOR", "pos": [1, 0], "hp": 1000}],
		"target":  {"mode": "auto"},
	}


func get_active_skill() -> AbilityConfig:
	return HexBattlePoison.ABILITY


## 足够跑完 cast(500ms) + 3 次 DOT tick(2s interval) + 尾巴 = 7500ms = 75 ticks
func get_max_ticks() -> int:
	return 100


func assert_replay(ctx: ScenarioAssertContext) -> void:
	var target := ctx.enemy_id(0)

	# 只看对 target 的 PURE 伤害 = DOT tick 事件（过滤掉其他 damage_type）
	var dmgs := ctx.filter_damage_events({
		"target_actor_id": target,
		"damage_type": "pure",
	})
	var dmg_values: Array = []
	for e in dmgs:
		dmg_values.append(e.get("damage", -1.0))

	ctx.assert_array_float_eq(dmg_values, [3.0, 2.0, 1.0], "DOT damage sequence")
	ctx.assert_float_eq(ctx.total_damage_to(target), 6.0, "total DOT damage")

	# caster 不应受自残伤害
	ctx.assert_float_eq(ctx.total_damage_to(ctx.caster_id), 0.0, "caster took no self-damage")

	# buff 耗尽后应被 revoke
	ctx.assert_actor_ability_absent(target, HexBattlePoisonBuff.CONFIG_ID,
		"PoisonBuff revoked after stacks exhausted")
