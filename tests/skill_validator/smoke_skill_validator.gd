extends Node
## SkillValidator 回归 smoke (主仓上层测试; 引用 SkillValidator + addon 技能, 依赖方向正确)
##
## 锁死 A 批三连环修复, 防回归:
##   Part A — 端到端 validate() 走 P0-1 (static var ABILITY) + 新-1 (flat 伤害静态提取)
##            + 新-2 (projectile 命中伤害可见)。
##   Part B — 全部内置 active 技能跑 structure + extract, 断言:
##            (1) 30+ 技能结构全过; (2) extract 不因字段名错崩溃 (新-1 对所有真实
##            action 类型成立); (3) 三个 projectile 技能的命中伤害在 trigger 层可见 (新-2)。
##
## 注意 Part B 不重编译技能源码 (会撞已注册 class_name 全局类), 直接喂已 build 的
## AbilityConfig 给 validator 的 structure/extract 阶段。

const FIXTURE_PATH := "res://tests/skill_validator/fixtures/sample_projectile_skill.gd"

var _failures: Array[String] = []


func _ready() -> void:
	_part_a_end_to_end()
	_part_b_all_builtin_skills()

	if _failures.is_empty():
		print("SMOKE_TEST_RESULT: PASS - SkillValidator A批回归 (P0-1 + 新-1 + 新-2) 全部通过")
		get_tree().quit(0)
	else:
		for f in _failures:
			print("  [FAIL] %s" % f)
		print("SMOKE_TEST_RESULT: FAIL - %d 项断言失败" % _failures.size())
		get_tree().quit(1)


func _fail(msg: String) -> void:
	_failures.append(msg)


# ============================================================
# Part A — 端到端 validate()
# ============================================================
func _part_a_end_to_end() -> void:
	var src := FileAccess.get_file_as_string(FIXTURE_PATH)
	if src.is_empty():
		_fail("Part A: 读不到 fixture 源码 %s" % FIXTURE_PATH)
		return

	var validator := SkillValidator.new()
	var res: Dictionary = validator.validate(src)

	# 四阶段全过 (P0-1: ABILITY static var 路径)
	for stage in ["compile", "interface_check", "runtime", "structure"]:
		if not bool(res.stages.get(stage, {}).get("passed", false)):
			_fail("Part A: stage '%s' 未通过 -> %s" % [stage, str(res.stages.get(stage, {}))])
	if not bool(res.get("success", false)):
		_fail("Part A: validate() success != true -> %s" % str(res))
		return

	var actions: Array = res.get("ability_config", {}).get("actions", [])

	# 新-1: active_use HIT 的 DamageAction 被正确提取 (读 _damage_resolver/_damage_type,
	# 不再读不存在的 _damage; 提取不崩 = 字段名对)。damage 值标注 "dynamic" (见 validator 注释)。
	var hit_dmg := _find_action(actions, TimelineTags.HIT, "damage")
	if hit_dmg.is_empty():
		_fail("Part A 新-1: 未在 HIT tag 找到 damage action; actions=%s" % str(actions))
	elif str(hit_dmg.get("details", {}).get("damage_type", "")) == "":
		_fail("Part A 新-1: HIT damage 缺 damage_type (字段提取异常); details=%s" % str(hit_dmg.get("details", {})))

	# 新-2: projectile 命中伤害 (component_config) 在 trigger 层可见
	var trigger_dmg := _find_action_by_tag_prefix(actions, "trigger:", "damage")
	if trigger_dmg.is_empty():
		_fail("Part A 新-2: 未在 trigger:* tag 找到 projectile 命中 damage; actions=%s" % str(actions))


# ============================================================
# Part B — 全部内置 active 技能
# ============================================================
func _part_b_all_builtin_skills() -> void:
	var abilities := HexBattleAllSkills.all_abilities()
	if abilities.is_empty():
		_fail("Part B: all_abilities() 返回空")
		return

	var active_count := 0
	var projectile_seen: Array[String] = []
	var projectile_expected := ["skill_fireball", "skill_precise_shot", "skill_chain_lightning"]

	for ability: AbilityConfig in abilities:
		if ability.active_use_components.is_empty():
			continue  # 纯被动 / buff 不走 active-skill validator 路径
		active_count += 1

		var validator := SkillValidator.new()
		validator._reset_result()
		validator._check_structure(ability)  # 内部成功时会调 _extract_ability_config (新-1 字段名在此被全类型行使)

		if not bool(validator.result.get("success", false)):
			_fail("Part B: 技能 '%s' structure 未通过 -> %s" % [
				ability.config_id, str(validator.result.stages.get("structure", {}))])
			continue

		# 新-2: 三个 projectile 技能的命中伤害必须在 trigger 层可见
		if ability.config_id in projectile_expected:
			var acts: Array = validator.result.get("ability_config", {}).get("actions", [])
			var td := _find_action_by_tag_prefix(acts, "trigger:", "damage")
			if td.is_empty():
				_fail("Part B 新-2: projectile 技能 '%s' 命中伤害在 trigger 层不可见" % ability.config_id)
			else:
				projectile_seen.append(ability.config_id)

	if active_count < 25:
		_fail("Part B: active 技能数 %d 异常偏少 (期望 ~30)" % active_count)
	for pid in projectile_expected:
		if not (pid in projectile_seen):
			_fail("Part B: projectile 技能 '%s' 未在 manifest / 未通过 trigger 可见性检查" % pid)


# ============================================================
# helpers
# ============================================================
func _find_action(actions: Array, tag: String, action_type: String) -> Dictionary:
	for a in actions:
		if a is Dictionary and str(a.get("tag", "")) == tag and str(a.get("action_type", "")) == action_type:
			return a
	return {}


func _find_action_by_tag_prefix(actions: Array, tag_prefix: String, action_type: String) -> Dictionary:
	for a in actions:
		if a is Dictionary and str(a.get("tag", "")).begins_with(tag_prefix) and str(a.get("action_type", "")) == action_type:
			return a
	return {}
