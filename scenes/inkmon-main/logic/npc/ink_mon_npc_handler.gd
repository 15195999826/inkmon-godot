class_name InkMonNpcHandler
extends RefCounted
## NPC handler 基类: 只收 session, 规则住 handler 内, 不碰 UI / flow / app_root (docs/main-game-architecture.md §5)。
##
## 纯数据 NPC (shop/cultivation/guild/advancement/release_adopt) 直接读写 session。
## 要触发流程的 NPC (training→战斗) 在 run_action 结果里带 intent 字段 (Command-as-data),
## 由薄场景导播解释并执行 (handler 自己不起 battle / 不切场景)。


const ACTION_ID := "id"
const ACTION_LABEL := "label"
const ACTION_DETAIL := "detail"
const ACTION_KIND := "kind"
const ACTION_ENABLED := "enabled"

## run_action 结果里可选的 flow intent 字段; 形状 {kind: <intent kind>, ...config}。
const RESULT_INTENT := "intent"
const INTENT_KIND := "kind"


var npc_id := ""
var display_name := ""


func _init(p_npc_id: String = "", p_display_name: String = "") -> void:
	npc_id = p_npc_id
	display_name = p_display_name


func get_actions(_session: InkMonGameSession) -> Array[Dictionary]:
	return []


func run_action(action_id: String, _session: InkMonGameSession) -> Dictionary:
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
