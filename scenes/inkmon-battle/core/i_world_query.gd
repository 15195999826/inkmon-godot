class_name IWorldQuery
extends RefCounted
## 主世界只读查询 + 写入口的 Facade(Proxy)。Presentation 持本对象作其唯一的 Logic 句柄,**物理上够不到**
## concrete `InkMonWorldGI` 的 flow/lifecycle/internal(没有 `get_gi()` 逃逸口)。
##
## 结构仿 LGF `BaseGeneratedAttributeSet`(私有持底层对象 + 只暴露受控类型化表面),两点差异:
##   - 不留 `get_gi()` 逃逸口 —— 隔离就是目的;Host 另行**直接**持 concrete GI 做控制面(composition/lifecycle/flow/tick)。
##   - 无需 codegen —— 查询/写表面是固定的一小撮(非数据驱动的属性名),手写即可。
##
## CQRS 三通道里本 facade 只承载 ① Query(只读) + ② Command(submit)。③ Event(mutation signal)不在此:
## 由 Host(合法持 concrete GI)连 `gi.signal → Presentation handler`,故 Presentation 连 signal 也不需碰 GI。
## GDScript 无 interface 关键字 + GI 单继承位被 WorldGameplayInstance 占,故只能用这种 Facade 对象实现"持接口不持实现"。


var _gi: InkMonWorldGI


func _init(gi: InkMonWorldGI) -> void:
	_gi = gi


# === ① Query(只读) ===

## 存档根(只读;写/重建走 Host 控制面,不经本 facade)。
var session: InkMonGameSession:
	get:
		return _gi.session if _gi != null else null

## 与玩家相邻的 NPC id(""=无)。
var near_npc_id: String:
	get:
		return _gi.near_npc_id if _gi != null else ""

## 主世界 NPC 表(位置/显示名/类型)。
var npc_defs: Dictionary:
	get:
		return _gi.npc_defs if _gi != null else {}


func get_player_coord() -> Vector2i:
	return _gi.get_player_coord() if _gi != null else Vector2i.ZERO


func get_world_actor(key: String) -> InkMonWorldActor:
	return _gi.get_world_actor(key) if _gi != null else null


func get_npc_actions(npc_id: String) -> Array:
	return _gi.get_npc_actions(npc_id) if _gi != null else []


func has_npc_handler(npc_id: String) -> bool:
	return _gi != null and _gi.has_npc_handler(npc_id)


# === ② Command(写,唯一入口)===

## 入队对象化命令(异步;tick drain 时 cmd.apply(gi) 生效)。表演侧唯一的写路径。
func submit(command: InkMonWorldCommand) -> void:
	if _gi != null:
		_gi.submit(command)
