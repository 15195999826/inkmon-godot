class_name InkMonMissionMoveCommand
extends InkMonWorldCommand
## 出征选路: 沿趟内节点图走一跳 (方案 A: submit 入队 → tick drain 生效)。
## 回流走 mission_progressed / mission_ended signal (无 UI message, view 据信号补间/刷新)。


var node_id: int


func _init(p_node_id: int) -> void:
	node_id = p_node_id


func apply(gi: InkMonWorldGI) -> void:
	gi.apply_mission_move(node_id)
