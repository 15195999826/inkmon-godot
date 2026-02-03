## PreEvent 组件配置
##
## 用于配置 PreEventComponent，定义事件预处理器。
class_name PreEventConfig
extends RefCounted


## 事件类型
var event_kind: String

## 过滤器函数
var filter: Callable

## 处理器函数
var handler: Callable

## 处理器名称
var name: String


func _init(
	event_kind: String = "",
	handler: Callable = Callable(),
	filter: Callable = Callable(),
	name: String = ""
) -> void:
	self.event_kind = event_kind
	self.handler = handler
	self.filter = filter
	self.name = name
