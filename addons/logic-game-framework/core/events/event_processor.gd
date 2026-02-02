## EventProcessor - 事件处理器
##
## 统一处理 Pre/Post 双阶段事件，支持深度优先递归和追踪。
##
## ========== 核心职责 ==========
##
## 1. **Pre 阶段处理**：收集所有处理器的意图，应用修改，判断是否取消
## 2. **Post 阶段处理**：广播事件到所有监听者，深度优先处理被动产生的新事件
## 3. **追踪记录**：根据 trace_level 记录处理过程
## 4. **递归保护**：限制最大递归深度（默认 10）
##
## ========== 双阶段设计 ==========
##
## Pre 阶段（process_pre_event）：
## - 在效果应用**之前**调用
## - 允许被动技能修改或取消即将发生的效果
## - 返回 MutableEvent，包含修改后的值和取消状态
##
## Post 阶段（process_post_event）：
## - 在效果应用**之后**调用
## - 广播事件到所有存活角色的 AbilitySet
## - 可能触发被动技能（如反伤、吸血）产生新事件
##
## ========== 使用示例 ==========
##
## @example 在 Action 中使用双阶段处理
## ```gdscript
## var event_processor: EventProcessor = GameWorld.event_processor
## 
## # Pre 阶段：允许减伤/免疫
## var mutable: MutableEvent = event_processor.process_pre_event(pre_event, battle)
## 
## if not mutable.cancelled:
##     # 获取修改后的伤害值
##     var final_damage: float = mutable.get_current_value("damage")
##     
##     # 应用效果（原子操作）
##     ctx.event_collector.push(damage_event)
##     target.modify_hp(-final_damage)
##     
##     # Post 阶段：触发反伤/吸血等被动
##     var actors := HexBattleGameStateUtils.get_actors_for_event_processor(battle)
##     event_processor.process_post_event(damage_event, actors, battle)
## ```
##
## @example 查看追踪日志
## ```gdscript
## print(event_processor.export_trace_log())
## ```

extends RefCounted
class_name EventProcessor

const DEFAULT_MAX_DEPTH := 10
const DEFAULT_TRACE_LEVEL := 1

var _max_depth: int
var _trace_level: int
var _current_depth := 0
var _traces: Array = []
var _current_trace_id := ""
var _pre_handlers: Dictionary = {}

func _init(config: Dictionary = {}):
	_max_depth = int(config.get("maxDepth", DEFAULT_MAX_DEPTH))
	_trace_level = int(config.get("traceLevel", DEFAULT_TRACE_LEVEL))

func register_pre_handler(registration: Dictionary) -> Callable:
	var event_kind := str(registration.get("eventKind", ""))
	if not _pre_handlers.has(event_kind):
		_pre_handlers[event_kind] = []
	_pre_handlers[event_kind].append(registration)

	return func() -> void:
		var handlers: Array = _pre_handlers.get(event_kind, [])
		for i in range(handlers.size()):
			if handlers[i].get("id", "") == registration.get("id", ""):
				handlers.remove_at(i)
				break

func remove_handlers_by_ability_id(ability_id: String) -> void:
	for event_kind in _pre_handlers.keys():
		var handlers: Array = _pre_handlers[event_kind]
		var filtered := []
		for handler in handlers:
			if handler.get("abilityId", "") != ability_id:
				filtered.append(handler)
		_pre_handlers[event_kind] = filtered

func remove_handlers_by_owner_id(owner_id: String) -> void:
	for event_kind in _pre_handlers.keys():
		var handlers: Array = _pre_handlers[event_kind]
		var filtered := []
		for handler in handlers:
			if handler.get("ownerId", "") != owner_id:
				filtered.append(handler)
		_pre_handlers[event_kind] = filtered

func process_pre_event(event: Dictionary, game_state_provider = null) -> MutableEvent:
	var mutable := MutableEvent.new(event, EventPhase.PHASE_PRE)

	if _current_depth >= _max_depth:
		Log.error("EventProcessor", "Event recursion depth exceeded: %s" % str(_current_depth))
		return mutable

	var trace := _create_trace(event, EventPhase.PHASE_PRE)
	var parent_trace_id := _current_trace_id
	_current_depth += 1
	_current_trace_id = trace.get("traceId", "")

	var handlers: Array = _pre_handlers.get(event.get("kind", ""), [])
	for registration in handlers:
		if registration.has("filter") and registration["filter"] is Callable:
			if not registration["filter"].call(event):
				continue

		var handler_context := {
			"ownerId": registration.get("ownerId", ""),
			"abilityId": registration.get("abilityId", ""),
			"configId": registration.get("configId", ""),
		"gameplayState": game_state_provider,
	}

		var start_time := Time.get_ticks_msec()
		var intent := { "type": EventPhase.INTENT_PASS }
		var handler_error: Dictionary = {}

		if registration.has("handler") and registration["handler"] is Callable:
			var handler_call: Callable = registration["handler"]
			var result
			var call_ok := true
			result = handler_call.call(mutable, handler_context)
			intent = result if result != null else intent
			call_ok = true

		var execution_time := Time.get_ticks_msec() - start_time
		if _trace_level >= 2:
			trace["intents"].append({
				"handlerId": registration.get("id", ""),
				"handlerName": registration.get("name", registration.get("configId", "")),
				"intent": intent,
				"executionTime": execution_time,
				"error": handler_error if not handler_error.is_empty() else null,
			})
		elif _trace_level >= 1 and not handler_error.is_empty():
			trace["intents"].append({
				"handlerId": registration.get("id", ""),
				"handlerName": registration.get("name", registration.get("configId", "")),
				"intent": intent,
				"error": handler_error,
			})

		if intent.get("type", "") == EventPhase.INTENT_CANCEL:
			mutable.cancel(str(intent.get("handlerId", "")), str(intent.get("reason", "")))
			trace["cancelled"] = true
			trace["cancelReason"] = intent.get("reason", "")
			trace["cancelledBy"] = intent.get("handlerId", "")
			break
		elif intent.get("type", "") == EventPhase.INTENT_MODIFY:
			var modifications: Array = intent.get("modifications", [])
			var modifications_with_source := []
			for mod in modifications:
				var mod_with_source: Dictionary = mod.duplicate(true)
				if not mod_with_source.has("sourceId"):
					mod_with_source["sourceId"] = intent.get("handlerId", "")
				if not mod_with_source.has("sourceName"):
					mod_with_source["sourceName"] = registration.get("name", registration.get("configId", ""))
				modifications_with_source.append(mod_with_source)
			mutable.add_modifications(modifications_with_source)

	if _trace_level >= 1:
		trace["originalValues"] = mutable.get_original_values()
		trace["finalValues"] = mutable.get_final_values()

	_current_depth -= 1
	_current_trace_id = parent_trace_id
	_finalize_trace(trace)

	return mutable

func process_post_event(event: Dictionary, actors: Array[Dictionary], game_state_provider = null) -> void:
	if _current_depth >= _max_depth:
		Log.error("EventProcessor", "Event recursion depth exceeded: %s" % str(_current_depth))
		return

	var trace := _create_trace(event, EventPhase.PHASE_POST)
	var parent_trace_id := _current_trace_id
	_current_depth += 1
	_current_trace_id = trace.get("traceId", "")

	for actor in actors:
		if actor.has("abilitySet") and actor["abilitySet"] != null:
			var ability_set = actor["abilitySet"]
			if ability_set.has_method("receive_event"):
				ability_set.receive_event(event, game_state_provider)

	_current_depth -= 1
	_current_trace_id = parent_trace_id
	_finalize_trace(trace)

func process_post_event_to_related(event: Dictionary, actors: Array[Dictionary], related_actor_ids: Dictionary, game_state_provider = null) -> void:
	if _current_depth >= _max_depth:
		Log.error("EventProcessor", "Event recursion depth exceeded: %s" % str(_current_depth))
		return

	var trace := _create_trace(event, EventPhase.PHASE_POST)
	var parent_trace_id := _current_trace_id
	_current_depth += 1
	_current_trace_id = trace.get("traceId", "")

	for actor in actors:
		if not related_actor_ids.has(actor.get("id", "")):
			continue
		if actor.has("abilitySet") and actor["abilitySet"] != null:
			var ability_set = actor["abilitySet"]
			if ability_set.has_method("receive_event"):
				ability_set.receive_event(event, game_state_provider)

	_current_depth -= 1
	_current_trace_id = parent_trace_id
	_finalize_trace(trace)

func get_traces() -> Array:
	return _traces

func clear_traces() -> void:
	_traces = []

func get_current_depth() -> int:
	return _current_depth

func get_current_trace_id() -> String:
	return _current_trace_id

func export_trace_log() -> String:
	if _traces.is_empty():
		return "(No traces recorded)"

	var lines := []
	for trace in _traces:
		lines.append("")
		lines.append("[Trace %s] %s (%s, depth: %s)" % [
			trace.get("traceId", ""),
			trace.get("eventKind", ""),
			trace.get("phase", ""),
			trace.get("depth", ""),
		])
		if trace.has("parentTraceId") and str(trace["parentTraceId"]) != "":
			lines.append("  Parent: %s" % trace["parentTraceId"])

		if trace.get("phase", "") == EventPhase.PHASE_PRE:
			var original_values: Dictionary = trace.get("originalValues", {})
			if not original_values.is_empty():
				lines.append("  Original: %s" % JSON.stringify(original_values))
			var intents: Array = trace.get("intents", [])
			for record in intents:
				var intent = record.get("intent", {})
				var intent_type: String = intent.get("type", "")
				var error_suffix := ""
				if record.get("error", null) != null:
					error_suffix = " ERROR"
				lines.append("  [%s] -> %s%s" % [record.get("handlerName", record.get("handlerId", "")), intent_type, error_suffix])
				if record.get("error", null) != null:
					lines.append("    Error: %s" % record["error"].get("message", ""))
				elif intent_type == EventPhase.INTENT_CANCEL:
					lines.append("    Reason: %s" % intent.get("reason", ""))
				elif intent_type == EventPhase.INTENT_MODIFY:
					for mod in intent.get("modifications", []):
						lines.append("    %s: %s %s" % [mod.get("field", ""), mod.get("operation", ""), mod.get("value", "")])

			if trace.get("cancelled", false):
				lines.append("  CANCELLED by %s: %s" % [trace.get("cancelledBy", ""), trace.get("cancelReason", "")])
			else:
				var final_values: Dictionary = trace.get("finalValues", {})
				if not final_values.is_empty():
					lines.append("  Final: %s" % JSON.stringify(final_values))

		var duration := 0
		if trace.has("endTime") and trace.get("endTime", null) != null:
			duration = int(trace.get("endTime", 0)) - int(trace.get("startTime", 0))
		lines.append("  Duration: %sms" % duration)

	return "\n".join(lines)

func _create_trace(event: Dictionary, phase: String) -> Dictionary:
	var trace := {
		"traceId": EventPhase.create_trace_id(),
		"eventKind": event.get("kind", ""),
		"phase": phase,
		"depth": _current_depth,
		"parentTraceId": _current_trace_id,
		"intents": [],
		"originalValues": {},
		"finalValues": {},
		"cancelled": false,
		"startTime": Time.get_ticks_msec(),
	}
	if _trace_level > 0:
		_traces.append(trace)
	return trace

func _finalize_trace(trace: Dictionary) -> void:
	trace["endTime"] = Time.get_ticks_msec()

static func create_event_processor(config: Dictionary = {}) -> EventProcessor:
	return EventProcessor.new(config)
