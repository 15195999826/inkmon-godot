class_name InkMonMissionState
extends RefCounted
## 出征 (mission, glossary §4.8) 运行态 —— transient (P1 拍板): 不进存档, 刻意无 to_dict/from_dict。
##
## GI 持有 (adr/0002 三叉: 需保留且 transient → GI 持的 RefCounted); Presentation 一份真相不持。
## "丢这趟" = Host load 出发档重建世界, 本对象随旧 GI 一起整体丢弃 —— 可整体丢弃性是设计要求,
## 别把出征态散落到本对象之外。将来要"退出续玩"时给本类加序列化即可 (game-vision §1 末, 不烧桥)。


var mission_seed := 0
## 本趟节点图 (趟内蔓延生成, transient)。
var map: InkMonMissionMapData = null
var current_node_id := 0
## 主委托目标对应的大地图地标格 (占位主委托 v1 = 抵达型; quest 数据化 = Phase 3)。
var target_site_coord := Vector2i.ZERO
## 剩余补给 (每步节点跳扣 1; 粮尽掉血 = M1.4 补给钟)。
var supplies := 0
## 途中捕获 (Phase 2 填充: {species_id, roll_seed}); 回城结算 adopt 入 roster ("落袋为安")。
var captured_pending: Array[Dictionary] = []
## 趟内足迹: node_id -> true (趟内视野/回访判定的底料)。
var visited_node_ids: Dictionary = {}
## 待打的野群节点 (M2.2): 踩上 battle 节点即置 (节点即内容, 必战不可绕), 期间选路移动一律拒;
## 战斗非败收尾清回 -1 解锁。败 = 全灭不清 —— 世界被 Host load 出发档整体重建, 本对象随之销毁。
var pending_battle_node_id := -1


func has_pending_battle() -> bool:
	return pending_battle_node_id >= 0


func is_at_target() -> bool:
	return map != null and current_node_id == map.target_node_id
