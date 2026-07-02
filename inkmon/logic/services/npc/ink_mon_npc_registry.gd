class_name InkMonNpcRegistry
## 主世界 NPC 单一注册清单 (加 NPC 只加一行): id → {display_name, type, coord, handler_script}。
## gi.npc_defs (读模型) 与 gi._npc_handlers (行为) 都从本表派生 —— 消掉曾经的两份硬编码 Dict
## (id / display_name 各抄一遍) 漂移面。
## 刻意 static func 每次重建而非 static var 缓存: static 容器持对象有引擎退出析构坑 (见 all_skills 同注)。


static func defs() -> Dictionary:
	return {
		"shop": _def("Shop", "shop", Vector2i(2, 0), InkMonShopNpcHandler),
		"trainer": _def("Training", "training", Vector2i(-2, 1), InkMonTrainingNpcHandler),
		"cultivation": _def("Cultivation", "cultivation", Vector2i(0, 2), InkMonCultivationNpcHandler),
		"guild": _def("Guild", "guild", Vector2i(2, -1), InkMonGuildNpcHandler),
		"advancement": _def("Trainer Advancement", "advancement", Vector2i(-2, 0), InkMonAdvancementNpcHandler),
		"release_adopt": _def("Release / Adopt", "release_adopt", Vector2i(0, -2), InkMonReleaseAdoptNpcHandler),
	}


## npc_defs 读模型视图 (display_name/type/coord, 不含 handler_script) —— GI 持有并经 IWorldQuery 暴露。
static func build_npc_defs() -> Dictionary:
	var result := {}
	var table := defs()
	for npc_id in table:
		var def := table[npc_id] as Dictionary
		result[npc_id] = {
			"display_name": def["display_name"],
			"type": def["type"],
			"coord": def["coord"],
		}
	return result


## handler 表 (id → InkMonNpcHandler 实例), new_game / from_dict 的世界装配期构建。
static func build_npc_handlers() -> Dictionary:
	var result := {}
	var table := defs()
	for npc_id in table:
		var def := table[npc_id] as Dictionary
		result[npc_id] = (def["handler_script"] as GDScript).new(str(npc_id), str(def["display_name"]))
	return result


static func _def(display_name: String, type_value: String, coord: Vector2i, handler_script: GDScript) -> Dictionary:
	return {
		"display_name": display_name,
		"type": type_value,
		"coord": coord,
		"handler_script": handler_script,
	}
