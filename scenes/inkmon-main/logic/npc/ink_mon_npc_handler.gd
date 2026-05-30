class_name InkMonNpcHandler
extends RefCounted


const ACTION_ID := "id"
const ACTION_LABEL := "label"
const ACTION_DETAIL := "detail"
const ACTION_KIND := "kind"
const ACTION_ENABLED := "enabled"


var npc_id := ""
var display_name := ""


func _init(p_npc_id: String = "", p_display_name: String = "") -> void:
	npc_id = p_npc_id
	display_name = p_display_name


func get_actions(_app_root: InkMonAppRoot) -> Array[Dictionary]:
	return []


func run_action(action_id: String, _app_root: InkMonAppRoot) -> Dictionary:
	return _result(false, "unsupported action: %s" % action_id)


func _action(
	action_id: String,
	label: String,
	detail: String,
	kind: String = "command",
	enabled: bool = true
) -> Dictionary:
	return {
		ACTION_ID: action_id,
		ACTION_LABEL: label,
		ACTION_DETAIL: detail,
		ACTION_KIND: kind,
		ACTION_ENABLED: enabled,
	}


func _result(ok: bool, message: String) -> Dictionary:
	return {
		"ok": ok,
		"message": message,
	}
