## ActiveUse 组件配置
##
## 用于配置 ActiveUseComponent，定义主动技能的触发、条件、消耗和执行。
## 继承 ActivateInstanceConfig 的所有配置，额外增加条件和消耗。
## 推荐使用 Builder 模式构造，提供清晰的可读性和 IDE 自动补全。
##
## 示例:
## [codeblock]
## var config := ActiveUseConfig.builder() \
##     .timeline_id(HexBattleSkillTimelines.TIMELINE_ID.SLASH) \
##     .on_tag(TimelineTags.HIT, [DamageAction.new(...)]) \
##     .condition(CooldownCondition.new()) \
##     .cost(TimedCooldownCost.new(2000.0)) \
##     .build()
## [/codeblock]
class_name ActiveUseConfig
extends RefCounted


## Timeline ID
var timeline_id: String

## Tag -> Actions 映射
## key: TimelineTags 常量（如 TimelineTags.HIT）
## value: Array[Action]
var tag_actions: Dictionary

## 触发器列表（可选，默认监听 AbilityActivateEvent）
var triggers: Array

## 触发模式: "any" 或 "all"
var trigger_mode: String

## 条件列表（全部满足才能激活）
var conditions: Array

## 消耗列表（激活时扣除）
var costs: Array


func _init(
	timeline_id: String = "",
	tag_actions: Dictionary = {},
	conditions: Array = [],
	costs: Array = [],
	triggers: Array = [],
	trigger_mode: String = "any"
) -> void:
	self.timeline_id = timeline_id
	self.tag_actions = tag_actions
	self.conditions = conditions
	self.costs = costs
	self.triggers = triggers
	self.trigger_mode = trigger_mode


## 创建 Builder
static func builder() -> ActiveUseConfigBuilder:
	return ActiveUseConfigBuilder.new()


## ActiveUseConfig Builder
##
## 使用链式调用构建 ActiveUseConfig，提供清晰的可读性。
## 必填字段：timeline_id
class ActiveUseConfigBuilder:
	extends RefCounted
	
	var _timeline_id: String = ""
	var _tag_actions: Dictionary = {}
	var _triggers: Array = []
	var _trigger_mode: String = "any"
	var _conditions: Array = []
	var _costs: Array = []
	
	## 设置 Timeline ID（必填）
	func timeline_id(value: String) -> ActiveUseConfigBuilder:
		_timeline_id = value
		return self
	
	## 添加 Tag -> Actions 映射（可选）
	func on_tag(tag: String, actions: Array) -> ActiveUseConfigBuilder:
		_tag_actions[tag] = actions
		return self
	
	## 添加触发器（可选，默认监听 AbilityActivateEvent）
	func trigger(config: TriggerConfig) -> ActiveUseConfigBuilder:
		_triggers.append(config)
		return self
	
	## 设置触发模式（可选，默认 "any"）
	func trigger_mode(value: String) -> ActiveUseConfigBuilder:
		_trigger_mode = value
		return self
	
	## 添加条件（可选）
	func condition(cond) -> ActiveUseConfigBuilder:
		_conditions.append(cond)
		return self
	
	## 添加消耗（可选）
	func cost(c) -> ActiveUseConfigBuilder:
		_costs.append(c)
		return self
	
	## 构建 ActiveUseConfig
	## 验证必填字段，缺失时触发断言错误
	func build() -> ActiveUseConfig:
		assert(_timeline_id != "", "ActiveUseConfig: timeline_id is required")
		return ActiveUseConfig.new(
			_timeline_id,
			_tag_actions,
			_conditions,
			_costs,
			_triggers,
			_trigger_mode
		)
