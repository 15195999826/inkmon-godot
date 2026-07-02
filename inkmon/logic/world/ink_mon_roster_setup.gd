class_name InkMonRosterSetup
## roster / 容器装配无状态服务 (adr/0002 "无状态杂活 → static service", 比照 InkMonBattleSetup):
## 全 static func, 收 gi 当参数, 无字段、无状态、不存 gi 引用。
## 三条建 roster actor 的路径 (新游戏 config / 读档 save / 领养 adopt) 共用 _install 装配骨架
## —— 曾在 GI 内三处手抄 (add_actor + 装备容器 + restore + 入 roster)。


## 注册一个 ItemSystem 容器, 返回 runtime 容器 id (>0)。容器 id 不进存档, 每次 load 重建。
static func register_container(container_name: StringName, capacity: int = -1) -> int:
	var container := BaseContainer.new()
	container.container_name = container_name
	container.space_config = ContainerSpaceConfig.create_unordered(capacity)
	var cid := ItemSystem.register_container(container)
	Log.assert_crash(cid > 0, "InkMonRosterSetup", "failed to register container: %s" % str(container_name))
	return cid


## 把存档物品快照还原进容器 (config_id/count/slot_index)。
static func restore_container_items(container_id: int, items: Variant) -> void:
	var item_list := items as Array
	if item_list == null:
		return
	for item_value in item_list:
		var item := item_value as Dictionary
		if item == null:
			continue
		var config_id := StringName(str(item.get("config_id", "")))
		if config_id == &"":
			continue
		var result := ItemSystem.create_item(
			container_id, config_id, int(item.get("count", 1)), int(item.get("slot_index", -1)))
		Log.assert_crash(result.success, "InkMonRosterSetup",
			"failed to restore item %s: %s" % [str(config_id), result.error_message])


## 默认队伍单位 (新游戏): 从 UnitConfig 建活 actor (满血)。base 源与读档路径一致 (都走
## SpeciesCatalog.get_base_stats), 避免 new-game 态与 reload 态数值漂移; stub 物种 catalog
## fallback 回 UnitConfig, 数值不变 (M1 平衡保持)。
static func add_from_config(gi: InkMonWorldGI, unit_key: String) -> InkMonUnitActor:
	return _install(gi, InkMonUnitActor.new(unit_key), -1.0, [])


## 读档单位: 从持久切片建活 actor + 还原装备物品 + carryover HP。
static func add_from_save(gi: InkMonWorldGI, unit_data: Dictionary) -> InkMonUnitActor:
	return _install(gi, InkMonUnitActor.from_dict(unit_data),
		float(unit_data.get("hp", -1.0)), unit_data.get("equipment", []))


## 领养 = 程序化出生 (确定性 roll 技能槽) 建活 roster actor (满血)。
static func adopt(gi: InkMonWorldGI, species_id: String, roll_seed: int) -> InkMonUnitActor:
	var actor := InkMonUnitActor.from_dict({
		"species_id": species_id,
		"name_en": InkMonSpeciesCatalog.get_display_name(species_id),
		"stage": InkMonSpeciesCatalog.get_stage(species_id),
		"elements": InkMonSpeciesCatalog.get_elements(species_id),
		"level": 1,
		"exp": 0,
		"skill_slots": InkMonSpeciesCatalog.roll_birth_skill_slots(species_id, roll_seed),
		"engravings": [],
		"hp": -1.0,
	})
	return _install(gi, actor, -1.0, [])


## 共用装配骨架: 进 registry → 注册装备容器 (+还原物品) → 按 species base 重算派生六维与 HP → 入 roster。
static func _install(gi: InkMonWorldGI, actor: InkMonUnitActor, saved_hp: float, equipment_items: Variant) -> InkMonUnitActor:
	gi.add_actor(actor)
	actor.equipment_container_id = register_container(StringName("equip:%s" % actor.get_id()))
	restore_container_items(actor.equipment_container_id, equipment_items)
	actor.restore_persistent_state(InkMonSpeciesCatalog.get_base_stats(actor.species), saved_hp)
	gi.roster.append(actor)
	return actor
