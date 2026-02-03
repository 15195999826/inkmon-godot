## 触发器配置
##
## 定义事件触发器的配置，用于 ActivateInstanceConfig 和 ActiveUseConfig。
class_name TriggerConfig
extends RefCounted


## 事件类型（如 GameEvent.ABILITY_ACTIVATE_EVENT）
var event_kind: String

## 过滤器函数，签名: func(event: Dictionary, ctx: Dictionary) -> bool
var filter: Callable


func _init(
	event_kind: String = "",
	filter: Callable = Callable()
) -> void:
	self.event_kind = event_kind
	self.filter = filter
