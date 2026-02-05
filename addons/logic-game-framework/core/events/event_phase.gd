class_name EventPhase
## 纯静态工具类：事件阶段常量和工厂函数

const PHASE_PRE := "pre"
const PHASE_POST := "post"

const INTENT_PASS := "pass"
const INTENT_CANCEL := "cancel"
const INTENT_MODIFY := "modify"

static func pass_intent() -> Dictionary:
	return { "type": INTENT_PASS }

static func cancel_intent(handler_id: String, reason: String) -> Dictionary:
	return {
		"type": INTENT_CANCEL,
		"handlerId": handler_id,
		"reason": reason,
	}

static func modify_intent(handler_id: String, modifications: Array) -> Dictionary:
	return {
		"type": INTENT_MODIFY,
		"handlerId": handler_id,
		"modifications": modifications.duplicate(),
	}

static func create_trace_id() -> String:
	return "t-%s-%s" % [str(Time.get_ticks_msec(), 36), _random_suffix()]

static func _random_suffix() -> String:
	var value := randi()
	return str(value, 36).pad_zeros(4)
