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
	_part_c_advisory_stage5()

	if _failures.is_empty():
		print("SMOKE_TEST_RESULT: PASS - SkillValidator 回归 (P0-1 + 新-1 + 新-2 + Stage5) 全部通过")
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
# Part C — Stage 5 advisory (warn-only): determinism 扫描 + 门控存在性
# ============================================================
func _part_c_advisory_stage5() -> void:
	# 合成一个会通过前 4 阶段、但 resolver 里用 randf() 且缺 cant_act/silence 门控的技能。
	# Stage5 应在 advisory.warnings 标出 determinism + gating, 但 success 仍 true (warn 不 fail)。
	var src := "\n".join([
		'static var ADVISORY_TIMELINE := TimelineData.new("skill_test_advisory", 500.0, {TimelineTags.HIT: 250.0})',
		'',
		'static var ABILITY := (',
		'	AbilityConfig.builder()',
		'	.config_id("skill_test_advisory")',
		'	.display_name("AdvisoryProbe")',
		'	.ability_tags(["skill", "active"])',
		'	.meta(HexBattleSkillMetaKeys.RANGE, 1)',
		'	.active_use(',
		'		ActiveUseConfig.builder()',
		'		.timeline(ADVISORY_TIMELINE)',
		'		.on_tag(TimelineTags.HIT, [HexBattleDamageAction.new(',
		'			HexBattleTargetSelectors.current_target(),',
		'			Resolvers.float_fn(func(_c): return randf() * 10.0),',
		'			BattleEvents.DamageType.PHYSICAL',
		'		)])',
		'		.build()',
		'	)',
		'	.build()',
		')',
		'',
	])
	var validator := SkillValidator.new()
	var res: Dictionary = validator.validate(src)

	# warn-only: 含 randf + 缺门控仍 success=true
	if not bool(res.get("success", false)):
		_fail("Part C: advisory 是 warn-only, 含 randf/缺门控的技能应仍 success=true -> %s" % str(res.stages))
		return
	var advisory: Dictionary = res.stages.get("advisory", {})
	if not bool(advisory.get("passed", false)):
		_fail("Part C: advisory stage 未运行 -> %s" % str(advisory))
		return
	var warns: Array = advisory.get("warnings", [])
	if not _warnings_contain(warns, "determinism"):
		_fail("Part C: randf() 应产 determinism 警告; warnings=%s" % str(warns))
	if not _warnings_contain(warns, "cant_act"):
		_fail("Part C: 缺 cant_act 应产 gating 警告; warnings=%s" % str(warns))
	if not _warnings_contain(warns, "silence"):
		_fail("Part C: 缺 silence 应产 gating 警告; warnings=%s" % str(warns))

	# 反向: 一个内置标准技能 (poison, 门控齐全, 无 randf) 不应产这些警告
	var poison_warns := _builtin_advisory_warnings("skill_poison")
	if _warnings_contain(poison_warns, "determinism"):
		_fail("Part C: poison 不该有 determinism 警告; warnings=%s" % str(poison_warns))
	if _warnings_contain(poison_warns, "gating"):
		_fail("Part C: poison 门控齐全, 不该有 gating 警告; warnings=%s" % str(poison_warns))


## 跑某内置技能的 Stage5 advisory, 返回 warnings (Part B 式: 不重编译, 直接喂 config)
func _builtin_advisory_warnings(config_id: String) -> Array:
	for ability: AbilityConfig in HexBattleAllSkills.all_abilities():
		if ability.config_id != config_id:
			continue
		var validator := SkillValidator.new()
		validator._reset_result()
		validator._check_structure(ability)
		if validator.result.success:
			validator._check_advisory(ability, "")  # 内置技能源码不可得, 传空 (determinism 扫不到, 符合预期)
		return validator.result.stages.get("advisory", {}).get("warnings", [])
	return []


# ============================================================
# helpers
# ============================================================
func _warnings_contain(warnings: Array, needle: String) -> bool:
	for w in warnings:
		if str(w).contains(needle):
			return true
	return false


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
