class_name InkMonNpcActionCommand
extends InkMonWorldCommand
## 运行 NPC action(方案 A)。apply 委托 GI 的 handler(收 GI 持有的 session 自含规则);结果经
## `gi.emit_command_applied(result)` 回流。结果可含 flow intent(如 training 的 start_battle),
## **由 Host 解释执行 flow**(handler/command/GI 都不碰 flow,docs §5)。


var npc_id: String
var action_id: String


func _init(p_npc_id: String, p_action_id: String) -> void:
	npc_id = p_npc_id
	action_id = p_action_id


func apply(gi: InkMonWorldGI) -> void:
	gi.emit_command_applied(gi.run_npc_action(npc_id, action_id))
