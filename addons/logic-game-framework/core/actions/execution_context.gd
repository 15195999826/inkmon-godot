extends RefCounted
class_name ExecutionContext

## 触发事件链，记录从原始触发事件到当前回调事件的完整链路。
## 
## 每个元素是一个 Dictionary，包含 "kind" 字段标识事件类型。
## 所有事件都应继承自 GameEvent.Base，通过 .to_dict() 序列化后存入。
## 
## 示例数据：
## [code]
## [
##     # event_chain[0] - 原始触发事件（技能激活）
##     { "kind": "abilityActivate", "abilityInstanceId": "skill_001", "sourceId": "actor_001" },
##     # event_chain[1] - 回调事件（伤害事件）
##     { "kind": "damage", "target_actor_id": "actor_002", "damage": 150.0 }
## ]
## [/code]
## 
## 转换为强类型事件：
## [code]
## var dict := ctx.get_current_event()
## if BattleEvents.DamageEvent.is_match(dict):
##     var event := BattleEvents.DamageEvent.from_dict(dict)
##     print(event.damage)  # 类型安全访问
## [/code]
var event_chain: Array[Dictionary] = []

var game_state_provider = null
var event_collector: EventCollector = null
var ability: Dictionary = {}
var execution: Dictionary = {}

func _init(config: Dictionary = {}):
	event_chain.assign(config.get("eventChain", []))
	game_state_provider = config.get("gameplayState", null)
	event_collector = config.get("eventCollector", null)
	ability = config.get("ability", {})
	execution = config.get("execution", {})

func get_current_event():
	if event_chain.is_empty():
		return null
	return event_chain[event_chain.size() - 1]

func get_original_event():
	if event_chain.is_empty():
		return null
	return event_chain[0]

func push_event(event: Dictionary) -> Dictionary:
	if event_collector != null and event_collector.has_method("push"):
		return event_collector.push(event)
	return event

static func create_execution_context(config: Dictionary) -> ExecutionContext:
	return ExecutionContext.new(config)

static func create_callback_context(ctx: ExecutionContext, callback_event: Dictionary) -> ExecutionContext:
	return ExecutionContext.new({
		"eventChain": ctx.event_chain + [callback_event],
		"gameplayState": ctx.game_state_provider,
		"eventCollector": ctx.event_collector,
		"ability": ctx.ability,
		"execution": ctx.execution,
	})
