extends RefCounted
class_name ActionResult

var success: bool
var events: Array[Dictionary]
var failure_reason: String = ""
var data: Dictionary = {}

func _init(success_value: bool, events_value: Array[Dictionary], failure_reason_value: String = "", data_value: Dictionary = {}):
	success = success_value
	events = events_value
	failure_reason = failure_reason_value
	data = data_value

static func create_success_result(events_value: Array[Dictionary], data_value: Dictionary = {}) -> ActionResult:
	return ActionResult.new(true, events_value, "", data_value)

static func create_failure_result(reason: String, events_value: Array[Dictionary] = []) -> ActionResult:
	return ActionResult.new(false, events_value, reason, {})
