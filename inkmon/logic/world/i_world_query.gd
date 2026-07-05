class_name IWorldQuery
extends RefCounted
## 主世界只读查询 + 写入口的 Facade(Proxy)。Presentation 持本对象作其唯一的 Logic 句柄,**物理上够不到**
## concrete `InkMonWorldGI` 的 flow/lifecycle/internal(没有 `get_gi()` 逃逸口)。
##
## 读通道只出 **snapshot/DTO**(值拷贝), 不外递活 actor / 内部 Dict 引用 —— 域写隔离从"约定级"升到
## 结构级: UI 物理上拿不到可变域对象, 写只能走 submit(command)。
## (旧版曾直接暴露 player_actor / roster / npc_defs 引用, R2 五 codex + R3 判为写隔离缝隙, Wave 3 收紧。)
##
## CQRS 三通道里本 facade 只承载 ① Query(只读) + ② Command(submit)。③ Event(mutation signal)不在此:
## 由 Host(合法持 concrete GI)连 `gi.signal → Presentation handler`,故 Presentation 连 signal 也不需碰 GI。
## GDScript 无 interface 关键字 + GI 单继承位被 WorldGameplayInstance 占,故只能用这种 Facade 对象实现"持接口不持实现"。


var _gi: InkMonWorldGI


func _init(gi: InkMonWorldGI) -> void:
	_gi = gi


# === ① Query(只读 snapshot) ===

## 与玩家相邻的 NPC id(""=无)。
var near_npc_id: String:
	get:
		return _gi.near_npc_id if _gi != null else ""


func get_player_coord() -> Vector2i:
	return _gi.get_player_coord() if _gi != null else Vector2i.ZERO


## 玩家 world actor 的 registry id (位置信号过滤用; 只出 id, 不外递 actor 本体)。
func get_player_actor_id() -> String:
	if _gi == null or _gi.player_actor == null:
		return ""
	return _gi.player_actor.get_id()


func is_player_moving() -> bool:
	if _gi == null:
		return false
	var player := _gi.get_world_actor(InkMonWorldGrid.PLAYER_ID)
	return player != null and player.is_moving()


## HUD 级玩家摘要: {gold, progression(深拷贝)}。
func get_player_hud_summary() -> Dictionary:
	if _gi == null or _gi.player_actor == null:
		return {"gold": -1, "progression": {}}
	return {
		"gold": _gi.player_actor.gold,
		"progression": _gi.player_actor.progression.duplicate(true),
	}


## roster 快照 (UI chips/party 与 dev-agent debug 共用一份投影; 全值拷贝)。
func get_roster_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _gi == null:
		return result
	for actor in _gi.roster:
		result.append({
			"actor_id": actor.get_id(),
			"species_id": actor.species,
			"level": actor.level,
			"exp": actor.exp,
			"elements": actor.elements.duplicate(),
			"primary_skill_id": actor.get_primary_skill_id(),
			"hp": actor.attribute_set.hp,
			"max_hp": actor.attribute_set.max_hp,
			"stats": actor.get_stats(),
		})
	return result


## 玩家背包快照 (含 item config 解析后的展示字段, UI 不再直触 ItemSystem)。
func get_bag_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _gi == null or _gi.player_actor == null or _gi.player_actor.bag_container_id <= 0:
		return result
	for item_id in ItemSystem.get_items_in_container(_gi.player_actor.bag_container_id):
		var snapshot := ItemSystem.get_item_snapshot(item_id)
		var config_id := str(snapshot.get("config_id", ""))
		var config := ItemSystem.get_item_config(StringName(config_id))
		result.append({
			"config_id": config_id,
			"count": int(snapshot.get("count", 1)),
			"slot_index": int(snapshot.get("slot_index", -1)),
			"display_name": str(config.get("display_name", config_id)),
			"display_name_zh": str(config.get("display_name_zh", "")),
			"description": str(config.get("description", "")),
		})
	return result


## 主世界 NPC 表快照(位置/显示名/类型; 深拷贝, 堵旧版 Dict 引用泄露)。
func get_npc_defs_snapshot() -> Dictionary:
	return _gi.npc_defs.duplicate(true) if _gi != null else {}


func get_npc_actions(npc_id: String) -> Array:
	return _gi.get_npc_actions(npc_id) if _gi != null else []


func has_npc_handler(npc_id: String) -> bool:
	return _gi != null and _gi.has_npc_handler(npc_id)


## 出征快照(出征中大地图 view 的唯一数据源; 全值拷贝, 不外递 MissionState/MapData 引用)。
## 不在出征中返回 {}。
func get_mission_snapshot() -> Dictionary:
	if _gi == null or not _gi.has_active_mission():
		return {}
	var state := _gi.mission_state
	# 迷雾三态 (Phase 4, 逻辑真相在此投影): lit = 当前视野圆内 / seen = 趟内快照 (灰) / hidden = 黑。
	var sight := _gi.player_actor.sight_range if _gi.player_actor != null else InkMonPlayerActor.DEFAULT_SIGHT_RANGE
	var center := state.map.get_node_info(state.current_node_id).get("coord", Vector2i.ZERO) as Vector2i
	var center_hex := HexCoord.new(center.x, center.y)
	var nodes: Array[Dictionary] = []
	for node in state.map.nodes:
		var node_id := int(node.get("id", -1))
		var node_coord := node.get("coord", Vector2i.ZERO) as Vector2i
		var visibility := "hidden"
		if center_hex.distance_to(HexCoord.new(node_coord.x, node_coord.y)) <= sight:
			visibility = "lit"
		elif state.seen_node_kinds.has(node_id):
			visibility = "seen"
		nodes.append({
			"id": node_id,
			"layer": int(node.get("layer", 0)),
			"coord": node.get("coord", Vector2i.ZERO),
			"kind": str(node.get("kind", "")),
			"visited": state.visited_node_ids.has(node_id),
			"visibility": visibility,
			"seen_kind": str(state.seen_node_kinds.get(node_id, "")),
		})
	var quests: Array[Dictionary] = []
	for quest_entry in state.quests:
		var def := quest_entry.get("def", null) as InkMonQuestDef
		if def == null:
			continue
		quests.append({
			"quest": def.to_dict(),
			"role": str(quest_entry.get("role", "")),
			"progress": int(quest_entry.get("progress", 0)),
			"goal_count": def.goal_count,
		})
	return {
		"nodes": nodes,
		"edges": state.map.edges.duplicate(true),
		"entry_node_id": state.map.entry_node_id,
		"target_node_id": state.map.target_node_id,
		"current_node_id": state.current_node_id,
		"next_node_ids": state.map.next_node_ids(state.current_node_id),
		"supplies": state.supplies,
		"target_site_coord": state.target_site_coord,
		"quests": quests,
		"sight_range": sight,
		"current_coord": center,
	}


## 世界地理快照(大地图底图数据; 复用 to_dict 序列化投影, 天然值拷贝)。
func get_world_map_snapshot() -> Dictionary:
	if _gi == null or _gi.world_map == null:
		return {}
	return _gi.world_map.to_dict()


# === ② Command(写,唯一入口)===

## 入队对象化命令(异步;tick drain 时 cmd.apply(gi) 生效)。表演侧唯一的写路径。
func submit(command: InkMonWorldCommand) -> void:
	if _gi != null:
		_gi.submit(command)
