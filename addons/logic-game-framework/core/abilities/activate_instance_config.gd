## ActivateInstance 组件配置
##
## 用于配置 ActivateInstanceComponent，定义触发器和 Timeline 执行。
## 推荐使用 Builder 模式构造，提供清晰的可读性和 IDE 自动补全。
##
## 示例:
## [codeblock]
## var config := ActivateInstanceConfig.builder() \
##     .timeline_id(HexBattleSkillTimelines.TIMELINE_ID.MOVE) \
##     .on_tag(TimelineTags.START, [StartMoveAction.new(...)]) \
##     .on_tag(TimelineTags.EXECUTE, [ApplyMoveAction.new(...)]) \
##     .trigger(TriggerConfig.new(...)) \
##     .build()
## [/codeblock]
class_name ActivateInstanceConfig
extends RefCounted


## Timeline ID
var timeline_id: String

## Tag -> Actions 映射
## key: TimelineTags 常量（如 TimelineTags.HIT）
## value: Array[Action]
var tag_actions: Dictionary

## 触发器列表
var triggers: Array

## 触发模式: "any" 或 "all"
var trigger_mode: String


func _init(
	timeline_id: String = "",
	tag_actions: Dictionary = {},
	triggers: Array = [],
	trigger_mode: String = "any"
) -> void:
	self.timeline_id = timeline_id
	self.tag_actions = tag_actions
	self.triggers = triggers
	self.trigger_mode = trigger_mode


## 创建 Builder
static func builder() -> ActivateInstanceConfigBuilder:
	return ActivateInstanceConfigBuilder.new()


## ActivateInstanceConfig Builder
##
## 使用链式调用构建 ActivateInstanceConfig，提供清晰的可读性。
## 必填字段：timeline_id
class ActivateInstanceConfigBuilder:
	extends RefCounted
	
	var _timeline_id: String = ""
	var _tag_actions: Dictionary = {}
	var _triggers: Array = []
	var _trigger_mode: String = "any"
	
	## 设置 Timeline ID（必填）
	func timeline_id(value: String) -> ActivateInstanceConfigBuilder:
		_timeline_id = value
		return self
	
	## 添加 Tag -> Actions 映射（可选）
	func on_tag(tag: String, actions: Array) -> ActivateInstanceConfigBuilder:
		_tag_actions[tag] = actions
		return self
	
	## 添加触发器（可选，默认监听 AbilityActivateEvent）
	func trigger(config: TriggerConfig) -> ActivateInstanceConfigBuilder:
		_triggers.append(config)
		return self
	
	## 设置触发模式（可选，默认 "any"）
	func trigger_mode(value: String) -> ActivateInstanceConfigBuilder:
		_trigger_mode = value
		return self
	
	## 构建 ActivateInstanceConfig
	## 验证必填字段，缺失时触发断言错误
	func build() -> ActivateInstanceConfig:
		assert(_timeline_id != "", "ActivateInstanceConfig: timeline_id is required")
		return ActivateInstanceConfig.new(
			_timeline_id,
			_tag_actions,
			_triggers,
			_trigger_mode
		)
