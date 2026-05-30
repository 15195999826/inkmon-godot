class_name SkillValidator
extends RefCounted
## AI 生成技能脚本验证器
## 执行五级验证：编译 → 接口 → 运行 → 结构 → 进阶建议(warn-only)

var result: Dictionary

## Stage 5 进阶建议阈值
const ADVISORY_MAX_COOLDOWN_MS := 60000.0
## cant_act (眩晕/硬控) 门控豁免: 仅 move (走 ActivateInstanceConfig, 无标准门控)。
## strike 不在此列 —— basic attack 也该被眩晕阻断, 它确实带 cant_act。
const ADVISORY_CANT_ACT_EXEMPT := ["skill_move"]
## silence (沉默) 门控豁免: strike (basic attack 不受沉默, ARPG/MOBA 惯例) + move。
## 把 strike 的 silence 豁免从"沉默的省略"固化成"具名 opt-out", 让其它技能漏写 silence
## 时能与有意豁免区分 (原 P1-2 关切: condition 门控靠逐文件手抄, 漂移不可检测)。
const ADVISORY_SILENCE_EXEMPT := ["skill_strike", "skill_move"]
## determinism 风险 token: 技能逻辑出现这些 = 可能破坏 bit-identical replay (RTS 契约)
const ADVISORY_NONDETERMINISTIC_TOKENS := [
	"randf", "randi", "randomize", "RandomNumberGenerator",
	"Time.", "OS.", "Engine.get_frames",
]


## 验证 GDScript 技能源码，返回完整的验证结果字典
func validate(source_code: String) -> Dictionary:
	_reset_result()
	
	# Stage 1: 编译检查
	var script := _check_compile(source_code)
	if script == null:
		return result
	
	# Stage 2: 接口检查
	if not _check_interface(script):
		return result
	
	# Stage 3: 运行检查
	var config := _check_runtime(script)
	if config == null:
		return result
	
	# Stage 4: 结构检查
	_check_structure(config)

	# Stage 5: 进阶建议 (warn-only; 仅结构通过后跑, 永不改 success)
	if result.success:
		_check_advisory(config, source_code)

	return result


func _reset_result() -> void:
	result = {
		"success": false,
		"config_id": null,
		"display_name": null,
		"stages": {
			"compile": { "passed": false },
			"interface_check": { "passed": false },
			"runtime": { "passed": false },
			"structure": { "passed": false },
			"advisory": { "passed": false, "warnings": [] },
		},
		"ability_config": null,
		"timeline": null,
	}


## Stage 1: 编译检查 — 返回 GDScript 或 null
func _check_compile(source_code: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source_code
	
	var err: int = script.reload()
	
	if err != OK:
		result.stages.compile = {
			"passed": false,
			"error": "GDScript compilation failed (error code: %d)" % err,
		}
		return null
	
	result.stages.compile = { "passed": true }
	return script


## Stage 2: 接口检查
##
## 技能脚本契约 = 暴露 `static var ABILITY := AbilityConfig.builder()...build()`,
## 与 all_skills.gd 注册的 30 个内置技能模板一致。旧的 `create_ability_config()`
## 方法契约从未被任何技能实现 (全用 static var ABILITY),已弃用。
func _check_interface(script: GDScript) -> bool:
	if not ("ABILITY" in script):
		result.stages.interface_check = {
			"passed": false,
			"error": "Missing required static var: ABILITY (expected `static var ABILITY := AbilityConfig.builder()...build()`)",
		}
		return false

	result.stages.interface_check = { "passed": true }
	return true


## Stage 3: 运行检查 — 返回 AbilityConfig 或 null
func _check_runtime(script: GDScript) -> AbilityConfig:
	# 直接读 static var ABILITY (无需实例化; GDScript.get 对 static var 返回其值)
	var config_value: Variant = script.get("ABILITY")

	if config_value == null:
		result.stages.runtime = {
			"passed": false,
			"error": "static var ABILITY is null",
		}
		return null

	if not (config_value is AbilityConfig):
		result.stages.runtime = {
			"passed": false,
			"error": "ABILITY must be AbilityConfig, got type: %d" % typeof(config_value),
		}
		return null

	var config := config_value as AbilityConfig
	result.stages.runtime = { "passed": true }

	# 尝试获取 timeline（可选, best-effort）。
	# 技能 timeline 是独立 static var,经 all_skills.gd 注册到 TimelineRegistry;
	# AI 新技能若未注册则查不到,留空不报错。
	var tl_id := ""
	if config.active_use_components.size() > 0:
		tl_id = config.active_use_components[0].timeline_id
	if tl_id != "":
		var timeline: TimelineData = TimelineRegistry.get_timeline(tl_id)
		if timeline != null:
			result.timeline = {
				"id": timeline.id,
				"duration": timeline.total_duration,
				"tags": timeline.tags,
			}

	return config


## Stage 4: 结构检查
func _check_structure(config: AbilityConfig) -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# 必填字段检查
	if config.config_id.is_empty():
		errors.append("config_id is required and cannot be empty")
	
	if config.display_name.is_empty():
		errors.append("display_name is required and cannot be empty")
	
	# 检查是否至少有一个 active_use 或其他组件
	var has_active: bool = config.active_use_components.size() > 0
	var has_components: bool = config.components.size() > 0
	
	if not has_active and not has_components:
		errors.append("AbilityConfig must have at least one active_use or component")
	
	# 警告检查
	if config.description.is_empty():
		warnings.append("description is empty (recommended)")
	
	if config.ability_tags.is_empty():
		warnings.append("ability_tags is empty (recommended)")
	
	# 构建结果
	if errors.size() > 0:
		result.stages.structure = {
			"passed": false,
			"errors": errors,
			"warnings": warnings,
		}
		return
	
	result.stages.structure = { "passed": true, "warnings": warnings }
	
	# 提取 AbilityConfig 数据
	result.ability_config = _extract_ability_config(config)
	result.config_id = config.config_id
	result.display_name = config.display_name
	result.success = true


## 提取 AbilityConfig 结构为可序列化字典
func _extract_ability_config(config: AbilityConfig) -> Dictionary:
	var first_active: ActiveUseConfig = config.active_use_components[0] if config.active_use_components.size() > 0 else null

	var tl_id: Variant = null
	if first_active != null:
		tl_id = first_active.timeline_id

	var data := {
		"config_id": config.config_id,
		"display_name": config.display_name,
		"description": config.description,
		"tags": config.ability_tags,
		"has_active_use": first_active != null,
		"has_passive": config.components.size() > 0,
		"timeline_id": tl_id,
		"actions": [],
	}
	
	# 提取 active_use 的 actions: on_timeline_start + 各 tag keyframe
	if first_active != null:
		for action in first_active.on_timeline_start_actions:
			data.actions.append(_extract_action(action, "start"))
		for entry: TagActionsEntry in first_active.tag_actions:
			var tag_name: String = entry.get_tag()
			for action in entry.get_actions():
				data.actions.append(_extract_action(action, tag_name))

	# 提取触发式组件 (ActivateInstanceConfig) 的 actions。
	# 投射物技能 (fireball / precise_shot / chain_lightning) 的真实命中伤害住在这里
	# (component_config(ActivateInstanceConfig).trigger(PROJECTILE_HIT_EVENT,...).on_timeline_start([DamageAction])),
	# 不在 active_use 里。不提取这层就会让 validation summary 完全看不到投射物伤害。
	for comp in config.components:
		if comp is ActivateInstanceConfig:
			# 触发事件类型住在 comp.triggers[i].event_kind (TriggerConfig.event_kind)
			var evt_kind := ""
			if comp.triggers.size() > 0:
				evt_kind = comp.triggers[0].event_kind
			var trigger_prefix := "trigger:%s" % evt_kind
			for action in comp.on_timeline_start_actions:
				data.actions.append(_extract_action(action, trigger_prefix))
			for entry: TagActionsEntry in comp.tag_actions:
				var ctag: String = entry.get_tag()
				for action in entry.get_actions():
					data.actions.append(_extract_action(action, "%s/%s" % [trigger_prefix, ctag]))

	return data


## 提取单个 Action 数据
func _extract_action(action: Variant, tag: String) -> Dictionary:
	var data := {
		"tag": tag,
		"action_type": "",
		"details": {},
	}

	if action is HexBattleDamageAction:
		data.action_type = "damage"
		# damage 值由 FloatResolver 在执行期按 ExecutionContext 解析。
		# Resolvers.float_val / float_fn 都返回同一个 FloatResolver (无类型区分),
		# 且 atk-scaled / 事件数据驱动的 resolver 解引用 ctx,验证期 (无 ctx) 调
		# resolve() 会崩。故这里只标注 "dynamic", 不静态求值。
		# (静态读 flat 数值需要框架给 resolver 加 is_static 标记 —— 见 C 批设计债。)
		data.details = {
			"damage": "dynamic",
			"damage_type": str(action._damage_type),
		}
	elif action is StageCueAction:
		data.action_type = "stage_cue"
	elif action is HexBattleHealAction:
		data.action_type = "heal"
		data.details = { "heal": "dynamic" }
	else:
		data.action_type = action.type if "type" in action else "unknown"

	return data


# ============================================================
# Stage 5: 进阶建议 (warn-only)
# ============================================================

## 前 4 阶段只验"能否编译/实例化/结构完整"; 本阶段补"该不该这么写", 全部以 warnings
## 暴露, 永不 fail success。覆盖:
##   - determinism: 源码出现非确定性 API → 破坏 bit-identical replay
##   - balance: cooldown 数值离谱 (flat 伤害无法静态读, 见 _extract_action 注释)
##   - gating: 缺 cant_act / silence 门控 (strike/move 具名豁免) → 可被控/沉默时施放
##   - metadata: 缺 range 声明 → 消费方默认按 1
func _check_advisory(config: AbilityConfig, source_code: String) -> void:
	var warnings: Array[String] = []

	# determinism: 源码 token 扫描
	for tok in ADVISORY_NONDETERMINISTIC_TOKENS:
		if source_code.contains(tok):
			warnings.append("determinism: 源码含 '%s', 可能破坏 bit-identical replay (技能逻辑应避免非确定性 API)" % tok)

	# metadata: range 声明 (AbilityConfig.metadata 是普通 Dictionary)
	if config.metadata.get(HexBattleSkillMetaKeys.RANGE, null) == null:
		warnings.append("metadata: 未声明 range meta (consumer 默认按 1 处理)")

	var exempt_cant_act: bool = config.config_id in ADVISORY_CANT_ACT_EXEMPT
	var exempt_silence: bool = config.config_id in ADVISORY_SILENCE_EXEMPT
	for au in config.active_use_components:
		# balance: cooldown (仅检查已声明的 timed_cooldown cost)
		for cost in au.costs:
			if cost != null and ("type" in cost) and cost.type == "timed_cooldown" and ("_duration" in cost):
				var cd := float(cost.get("_duration"))
				if cd <= 0.0:
					warnings.append("balance: cooldown <= 0 (无冷却, 通常非预期)")
				elif cd > ADVISORY_MAX_COOLDOWN_MS:
					warnings.append("balance: cooldown %.0fms 异常偏大 (> %.0fms)" % [cd, ADVISORY_MAX_COOLDOWN_MS])
		# gating: cant_act 存在性 (move 豁免)
		if not exempt_cant_act and not _au_has_no_tag_condition(au, HexBattleActionLockStatus.TAG_CANT_ACT):
			warnings.append("gating: active_use 缺 cant_act 条件, 可能在眩晕/硬控时施放 (仅 move 应豁免)")
		# gating: silence 存在性 (strike/move 豁免)
		if not exempt_silence and not _au_has_no_tag_condition(au, HexBattleSilenceBuff.TAG_CANT_USE_SKILL):
			warnings.append("gating: active_use 缺 silence (cant_use_skill) 条件, 可能在沉默时施放 (仅 basic-attack/move 应豁免)")

	result.stages.advisory = { "passed": true, "warnings": warnings }


## active_use 是否带某 tag 的 NoTagCondition (门控存在性检查)
func _au_has_no_tag_condition(au: ActiveUseConfig, tag: String) -> bool:
	for cond in au.conditions:
		if cond is Condition.NoTagCondition and cond.tag == tag:
			return true
	return false
