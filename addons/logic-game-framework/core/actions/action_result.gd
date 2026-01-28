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

static func merge_results(results: Array) -> ActionResult:
	var all_events: Array[Dictionary] = []
	var all_data: Dictionary = {}
	var all_success := true
	var first_failure_reason := ""

	for result in results:
		if result == null:
			continue
			
		if result.has_method("get"):
			all_events.append_array(result.get("events", []))
			var data_value = result.get("data", null)
			if data_value is Dictionary:
				for key in data_value.keys():
					all_data[key] = data_value[key]
			if not result.get("success", false):
				all_success = false
				if first_failure_reason == "":
					first_failure_reason = str(result.get("failure_reason", result.get("failureReason", "")))
			continue

		if "events" in result:
			all_events.append_array(result.events)
		if "data" in result and result.data is Dictionary:
			for key in result.data.keys():
				all_data[key] = result.data[key]
		if "success" in result and not result.success:
			all_success = false
			if first_failure_reason == "" and "failure_reason" in result and str(result.failure_reason) != "":
				first_failure_reason = str(result.failure_reason)

	var data_result := {}
	if not all_data.is_empty():
		data_result = all_data

	return ActionResult.new(all_success, all_events, first_failure_reason, data_result)
