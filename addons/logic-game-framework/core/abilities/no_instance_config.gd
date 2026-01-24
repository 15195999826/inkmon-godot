## NoInstance 组件配置
##
## 用于配置 NoInstanceComponent，定义被动触发的 Action 链。
## 不创建执行实例，直接执行 Action。
class_name NoInstanceConfig
extends RefCounted


## 触发器列表
var triggers: Array

## 触发模式: "any" 或 "all"
var trigger_mode: String

## Action 列表（触发时执行）
var actions: Array


func _init(
	triggers: Array = [],
	actions: Array = [],
	trigger_mode: String = "any"
) -> void:
	self.triggers = triggers
	self.actions = actions
	self.trigger_mode = trigger_mode
