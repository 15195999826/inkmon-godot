class_name InkMonMissionMapData
extends RefCounted
## 趟内节点图 (P2 拍板, glossary §4.9): 接委托后在固定地理上蔓延生成的选路 DAG。
##
## transient —— 住 InkMonMissionState, 不进存档 (P1), 刻意无 to_dict/from_dict 序列化通道
## (to_debug_dict 仅供测试比较, 不是存档)。大地图逻辑真相 = 本节点图; 节点 coord 是长在
## InkMonWorldMapData 固定地理上的 hex 锚格 (纯渲染皮肤, 不参与图逻辑)。
## 分层 DAG: 层 0 = 起点(单节点), 末层 = 目标(单节点), 沿有向边单向前进不可回头。


const NODE_START := "start"
const NODE_EMPTY := "empty"
const NODE_TARGET := "target"


## 节点: {id: int, layer: int, coord: Vector2i(hex 锚格), kind: String}。
var nodes: Array[Dictionary] = []
## 有向出边: from_id(int) -> Array[int]。
var edges: Dictionary = {}
var entry_node_id := 0
var target_node_id := 0

var _node_index: Dictionary = {}


## 生成器填完 nodes 后调用, 建 id -> node 查询索引。
func rebuild_index() -> void:
	_node_index.clear()
	for node in nodes:
		_node_index[int(node.get("id", -1))] = node


func get_node_info(node_id: int) -> Dictionary:
	var info := _node_index.get(node_id, {}) as Dictionary
	return info if info != null else {}


## from_id 的可去下一节点 (返回拷贝, 防调用方污染内部边表)。
func next_node_ids(from_id: int) -> Array[int]:
	var result: Array[int] = []
	var list := edges.get(from_id, []) as Array
	if list != null:
		for to_value in list:
			result.append(int(to_value))
	return result


func has_edge(from_id: int, to_id: int) -> bool:
	var list := edges.get(from_id, []) as Array
	return list != null and list.has(to_id)


func node_count() -> int:
	return nodes.size()


## 仅测试/调试比较用 (确定性断言); 本类 transient, 这不是存档序列化通道。
func to_debug_dict() -> Dictionary:
	return {
		"nodes": nodes.duplicate(true),
		"edges": edges.duplicate(true),
		"entry": entry_node_id,
		"target": target_node_id,
	}
