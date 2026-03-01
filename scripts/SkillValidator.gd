class_name SkillValidator
extends RefCounted
## AI 生成技能脚本验证器
## 执行四级验证：编译 → 接口 → 运行 → 结构

var result: Dictionary


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
func _check_interface(script: GDScript) -> bool:
	# 检查脚本是否有 create_ability_config 方法
	var found := false
	for method in script.get_script_method_list():
		if method.name == "create_ability_config":
			found = true
			break
	
	if not found:
		result.stages.interface_check = {
			"passed": false,
			"error": "Missing required method: create_ability_config()",
		}
		return false
	
	result.stages.interface_check = { "passed": true }
	return true


## Stage 3: 运行检查 — 返回 AbilityConfig 或 null
func _check_runtime(script: GDScript) -> AbilityConfig:
	# 创建脚本实例
	var instance = script.new()
	if instance == null:
		result.stages.runtime = {
			"passed": false,
			"error": "Failed to instantiate script",
		}
		return null
	
	# 调用 create_ability_config()
	var config = instance.call("create_ability_config")
	
	if config == null:
		result.stages.runtime = {
			"passed": false,
			"error": "create_ability_config() returned null",
		}
		return null
	
	if not (config is AbilityConfig):
		result.stages.runtime = {
			"passed": false,
			"error": "create_ability_config() must return AbilityConfig, got: %s" % str(typeof(config)),
		}
		return null
	
	result.stages.runtime = { "passed": true }
	
	# 尝试获取 timeline（可选）
	var has_timeline := false
	for method in script.get_script_method_list():
		if method.name == "create_timeline":
			has_timeline = true
			break
	
	if has_timeline:
		var timeline = instance.call("create_timeline")
		if timeline != null and timeline is TimelineData:
			result.timeline = {
				"id": timeline.id,
				"duration": timeline.duration,
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
	
	var data := {
		"config_id": config.config_id,
		"display_name": config.display_name,
		"description": config.description,
		"tags": config.ability_tags,
		"has_active_use": first_active != null,
		"has_passive": config.components.size() > 0,
		"timeline_id": first_active.timeline_id if first_active else null,
		"actions": [],
	}
	
	# 提取 actions
	if first_active != null:
		for entry: TagActionsEntry in first_active.tag_actions:
			var tag_name: String = entry.get_tag()
			for action in entry.get_actions():
				data.actions.append(_extract_action(action, tag_name))
	
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
		data.details = {
			"damage": action._damage,
			"damage_type": str(action._damage_type),
		}
	elif action is StageCueAction:
		data.action_type = "stage_cue"
	elif action is HexBattleHealAction:
		data.action_type = "heal"
	else:
		data.action_type = action.type if "type" in action else "unknown"
	
	return data
