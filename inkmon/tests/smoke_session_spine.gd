extends Node
## adr/0001 统一 live-actor: GI 存档脊柱 —— new_game / to_dict / from_dict round-trip;
## 活 roster actor 持久切片 (身份+选择+进度+当前HP carryover, 派生六维不进存档);
## 装备 stat_mods 走加成层 (adr/0004) 并 round-trip; 活 roster 原地战斗 + 奖励落活 actor; 旧档丢弃重开。


const FIXTURE_PATH := "res://inkmon/tests/fixtures/sample_creature_contract.json"


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - InkMon live-actor save spine round-tripped (roster/gold/equipment/HP)")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()
	# adr/0003: load fixture items (item_NNNN) so new_game's catalog has real configs to equip/buy
	# (stub fallback was removed; new_game's configure_domain reads this static cache).
	InkMonItemCatalog.reload_static_items_for_tests(FIXTURE_PATH)

	var gi := _new_gi()
	gi.new_game()

	var model_status := _assert_roster_model(gi)
	if model_status != "":
		return _shutdown(model_status)
	var equip_status := _assert_equipment_modifier_layer(gi)
	if equip_status != "":
		return _shutdown(equip_status)
	var round_trip_status := _assert_save_round_trip(gi)
	if round_trip_status != "":
		return _shutdown(round_trip_status)
	var downed_status := _assert_downed_state_survives_round_trip()
	if downed_status != "":
		return _shutdown(downed_status)
	var lookup_status := _assert_registry_lookup()
	if lookup_status != "":
		return _shutdown(lookup_status)
	var evo_skill_status := _assert_in_session_evolution_equips_upgraded_skill()
	if evo_skill_status != "":
		return _shutdown(evo_skill_status)
	var battle_status := _assert_battle_on_live_roster()
	if battle_status != "":
		return _shutdown(battle_status)
	var cross_battle_equip_status := _assert_equipment_survives_cross_battle()
	if cross_battle_equip_status != "":
		return _shutdown(cross_battle_equip_status)
	var discard_status := _assert_old_save_discarded()
	if discard_status != "":
		return _shutdown(discard_status)

	GameWorld.shutdown()
	return ""


func _assert_roster_model(gi: InkMonWorldGI) -> String:
	if gi.roster.is_empty():
		return "new game roster should not be empty"
	if gi.roster.size() != 4:
		return "new game roster should seed 4 InkMon, got %d" % gi.roster.size()
	var lead := gi.roster[0]
	if lead.level != 1:
		return "seeded lead should start at level 1"

	var d := lead.to_dict()
	for required in ["species_id", "name_en", "stage", "elements", "level", "exp", "skill_slots", "engravings", "hp"]:
		if not d.has(required):
			return "roster actor to_dict missing key: %s" % required
	# 派生六维不进存档 (只存身份+选择+进度+当前HP)。
	for leaked in ["max_hp", "ad", "ap", "armor", "mr", "speed", "battle_stats"]:
		if d.has(leaked):
			return "roster actor to_dict leaked derived stat: %s" % leaked
	var slots := d["skill_slots"] as Array
	if slots == null or slots.is_empty():
		return "seeded roster actor should have at least one skill slot"
	if str((slots[0] as Dictionary).get("skill_id", "")) == "":
		return "seeded skill slot should reference a skill_id"

	# medals = 玩家级 (挂 player_actor, 进 player 存档)。
	if not gi.player_actor.to_dict().has("medals"):
		return "medals should live on player_actor"

	# 派生六维 = f(species, level); level-1 = 物种 base (战斗平衡不变)。
	var base_max_hp := float(InkMonUnitConfig.get_unit_config(InkMonUnitConfig.LEFT_AEGIS_PUP).stats["max_hp"])
	if absf(lead.attribute_set.max_hp - base_max_hp) > 0.01:
		return "level-1 live max_hp must equal species base (battle balance unchanged)"
	return ""


func _assert_equipment_modifier_layer(gi: InkMonWorldGI) -> String:
	# adr/0004: 装备 stat_mods 走加成层 (modifier), 不焊 base; equip 容器已挂 actor (new_game 注册)。
	var lead := gi.roster[0]
	if lead.equipment_container_id <= 0:
		return "lead should own an equipment container"
	var base_ad := float(InkMonSpeciesCatalog.get_base_stats(lead.species).get("ad", 0.0))
	var sword_ad := float((ItemSystem.get_item_config(&"item_0001").get("stat_mods", {}) as Dictionary).get("ad", 0.0))
	if sword_ad <= 0.0:
		return "training sword should define an ad stat_mod"
	var equip_result := ItemSystem.create_item(lead.equipment_container_id, &"item_0001", 1)
	if not equip_result.success:
		return "failed to equip training sword: %s" % equip_result.error_message
	gi.refresh_unit_stats(lead)
	# current = base + modifier; base 不含装备 (加成层, 非 base 折叠)。
	var bd := lead.attribute_set.get_ad_breakdown()
	if absf(bd.base - base_ad) > 0.01:
		return "equipment must not fold into base (ad base=%.1f want %.1f)" % [bd.base, base_ad]
	if absf(bd.add_base_sum - sword_ad) > 0.01:
		return "equipment ad should land in the additive layer (add_base_sum=%.1f want %.1f)" % [bd.add_base_sum, sword_ad]
	if absf(lead.attribute_set.ad - (base_ad + sword_ad)) > 0.01:
		return "equipped sword ad should reach base+mod via modifier layer (got %.1f want %.1f)" % [lead.attribute_set.ad, base_ad + sword_ad]

	# 幂等重授 (注册态 actor → _clear_equipment_abilities 走 revoke 分支): 再 refresh, 加成层恰好一层、不累加。
	gi.refresh_unit_stats(lead)
	if lead.attribute_set.get_raw().get_modifiers("ad").size() != 1:
		return "re-refresh must keep exactly one equipment ad modifier, got %d" % lead.attribute_set.get_raw().get_modifiers("ad").size()
	if absf(lead.attribute_set.ad - (base_ad + sword_ad)) > 0.01:
		return "idempotent re-refresh must not double-stack equipment (got %.1f want %.1f)" % [lead.attribute_set.ad, base_ad + sword_ad]

	# 脱下复原 (注册态): 清容器 → refresh → ad 回 base, 加成层无残留装备 modifier。
	ItemSystem.clear_container(lead.equipment_container_id)
	gi.refresh_unit_stats(lead)
	if not lead.attribute_set.get_raw().get_modifiers("ad").is_empty():
		return "unequip should leave no equipment modifier on ad (registered path)"
	if absf(lead.attribute_set.ad - base_ad) > 0.01:
		return "unequip should restore ad to base (got %.1f want %.1f)" % [lead.attribute_set.ad, base_ad]

	# 重穿回 (后续 _assert_save_round_trip 依赖 lead 已装剑): ad 复为 base+mod。
	var re_equip := ItemSystem.create_item(lead.equipment_container_id, &"item_0001", 1)
	if not re_equip.success:
		return "failed to re-equip training sword: %s" % re_equip.error_message
	gi.refresh_unit_stats(lead)
	if absf(lead.attribute_set.ad - (base_ad + sword_ad)) > 0.01:
		return "re-equip should restore base+mod (got %.1f want %.1f)" % [lead.attribute_set.ad, base_ad + sword_ad]
	return ""


func _assert_save_round_trip(gi: InkMonWorldGI) -> String:
	# 制造可观测的玩家态变化: 买袋物 + 给 lead 制造伤害态 (carryover) + lead 已装剑 (上一断言)。
	var bag_result := gi.create_bag_item(&"item_0002", 3, 0)
	if not bag_result.success:
		return "failed to create bag item: %s" % bag_result.error_message
	gi.player_actor.gold = 175
	var lead := gi.roster[0]
	lead.set_current_hp(50.0)
	var expected_ad := lead.attribute_set.ad

	var before := gi.to_dict()
	if _has_key_recursive(before, "container_id") or _has_key_recursive(before, "item_id"):
		return "save data leaked runtime item/container ids"

	# 新 GI 读档 → 建活 actor。
	var loaded := _new_gi()
	if not loaded.from_dict(before):
		return "round-trip from_dict should accept its own save"

	# round-trip 幂等 (再序列化逐字一致)。
	var after := loaded.to_dict()
	if JSON.stringify(before) != JSON.stringify(after):
		return "save/load is not idempotent\nbefore=%s\nafter=%s" % [JSON.stringify(before), JSON.stringify(after)]

	# 字段一致: gold / roster / 装备生效 / 当前HP carryover (完成条件覆盖)。
	if loaded.player_actor.gold != 175:
		return "gold lost on round-trip: %d" % loaded.player_actor.gold
	if loaded.roster.size() != 4:
		return "roster size lost on round-trip: %d" % loaded.roster.size()
	var loaded_lead := loaded.roster[0]
	if loaded_lead.species != lead.species or loaded_lead.level != lead.level:
		return "roster lead identity/level lost on round-trip"
	if absf(loaded_lead.attribute_set.hp - 50.0) > 0.01:
		return "current HP carryover lost on round-trip: got %.1f want 50.0" % loaded_lead.attribute_set.hp
	if absf(loaded_lead.attribute_set.ad - expected_ad) > 0.01:
		return "equipment did not survive round-trip: ad=%.1f want %.1f" % [loaded_lead.attribute_set.ad, expected_ad]
	return ""


## adr/0001 死单位留 registry/HP=0 进存档: 0 血单位 round-trip 后 is_dead() 与 HP=0 须保持一致
## (回归守卫: from_dict 新建 actor _is_dead 默认 false, set_current_hp(0) 须按 HP 重建 downed)。
func _assert_downed_state_survives_round_trip() -> String:
	GameWorld.destroy_all_instances()
	var gi := _new_gi()
	gi.new_game()
	var victim := gi.roster[1]
	victim.set_current_hp(0.0)
	if not victim.is_dead():
		return "a 0-HP roster actor must report is_dead() == true"

	var loaded := _new_gi()
	if not loaded.from_dict(gi.to_dict()):
		return "downed round-trip from_dict should accept its own save"
	var loaded_victim := loaded.roster[1]
	if absf(loaded_victim.attribute_set.hp) > 0.01:
		return "downed actor HP=0 should survive round-trip, got %.1f" % loaded_victim.attribute_set.hp
	if not loaded_victim.is_dead():
		return "downed actor must reload as is_dead() == true (downed state survives save)"
	# 存活单位 round-trip 仍判活。
	if gi.roster[0].is_dead() or loaded.roster[0].is_dead():
		return "a full-HP roster actor must not be flagged downed before/after round-trip"
	return ""


func _assert_battle_on_live_roster() -> String:
	# 活 roster 原地战斗: request_training_battle 左队 = roster actor (无投影), 打弱假人 → 左胜 → 奖励落活 actor。
	# 清掉前面 round-trip 累积的 GI 实例, 隔离本场战斗的 tick_all。
	GameWorld.destroy_all_instances()
	var gi := _new_gi()
	gi.new_game()
	var lead := gi.roster[0]
	# 给 lead 挂刻印 → 出战时 equip_abilities 走刻印被动 grant 分支 (在真战斗里跑, 不只是数据 round-trip)。
	lead.engravings = [{"engraving_id": "amp", "target_slot": 0}]
	var gold_before := gi.player_actor.gold
	var exp_before := lead.exp

	gi.request_training_battle()
	GameWorld.tick_all(BattleProcedure.DEFAULT_TICK_INTERVAL)
	if gi.has_active_battle():
		return "live-roster battle did not finish in one world tick"
	if gi.left_team.is_empty() or gi.left_team[0] != lead:
		return "left team should be the live roster actors (no projection)"
	var summary := gi.finalize_battle_rewards()
	if str(summary.get("winner_team", "")) != "left":
		return "live-roster battle expected left winner, got %s" % str(summary.get("winner_team", ""))
	if gi.player_actor.gold <= gold_before:
		return "battle win did not award gold to player_actor"
	if lead.exp <= exp_before:
		return "battle did not grant exp to live roster actor"

	# 持久 world GI 复用跑第二场 (reset-on-start; roster 留 registry + HP carryover)。
	gi.request_training_battle()
	GameWorld.tick_all(BattleProcedure.DEFAULT_TICK_INTERVAL)
	if gi.has_active_battle():
		return "reused world GI: second live-roster battle did not finish"
	if str(gi.get_result_summary().get("winner_team", "")) != "left":
		return "reused world GI: second battle expected left winner"
	return ""


## adr/0004 回归守卫: 装备加成层跨真实战斗既不消失也不累加 —— 这是唯一有
## battle-transient ability_set ↔ 常驻 attribute_set 跨集交互的路径 (reset_battle_runtime 换集 →
## equip_abilities 重 grant): 旧装备 ability 随旧 ability_set 被丢, 其 modifier 仍在常驻 attribute_set 上,
## _refresh_equipment_abilities 须按 source 清旧再重 grant, 否则每场 +5 累加或装备丢失。
func _assert_equipment_survives_cross_battle() -> String:
	GameWorld.destroy_all_instances()
	var gi := _new_gi()
	gi.new_game()
	var lead := gi.roster[0]
	var base_ad := float(InkMonSpeciesCatalog.get_base_stats(lead.species).get("ad", 0.0))
	var sword_ad := float((ItemSystem.get_item_config(&"item_0001").get("stat_mods", {}) as Dictionary).get("ad", 0.0))
	if sword_ad <= 0.0:
		return "training sword should define an ad stat_mod"
	var equip := ItemSystem.create_item(lead.equipment_container_id, &"item_0001", 1)
	if not equip.success:
		return "failed to equip sword for cross-battle check: %s" % equip.error_message
	gi.refresh_unit_stats(lead)
	if absf(lead.attribute_set.ad - (base_ad + sword_ad)) > 0.01:
		return "pre-battle equipped ad should be base+mod (got %.1f want %.1f)" % [lead.attribute_set.ad, base_ad + sword_ad]

	for battle_index in 2:
		gi.request_training_battle()
		GameWorld.tick_all(BattleProcedure.DEFAULT_TICK_INTERVAL)
		if gi.has_active_battle():
			return "cross-battle equip: battle %d did not finish in one world tick" % (battle_index + 1)
		# reset_battle_runtime 换集后 equip_abilities 重 grant: 加成层恰好一层 (不累加 / 不丢失)。
		var ad_mods := lead.attribute_set.get_raw().get_modifiers("ad").size()
		if ad_mods != 1:
			return "equipment ad must stay exactly one layer after battle %d, got %d" % [battle_index + 1, ad_mods]
		if absf(lead.attribute_set.ad - (base_ad + sword_ad)) > 0.01:
			return "equipment ad must hold base+mod after battle %d (got %.1f want %.1f)" % [battle_index + 1, lead.attribute_set.ad, base_ad + sword_ad]
	return ""


func _assert_old_save_discarded() -> String:
	# 存档永不向后兼容: 缺 version / 旧 session 模型档 (version<2) → from_dict 丢弃重开, 不读旧形状、不崩。
	var legacy_save := {
		"player": {"gold": 99999, "roster": [{"entry_id": 1, "species": "legacy_mon", "level": 7}]},
		"inventory": {},
	}
	var loaded := _new_gi()
	if loaded.from_dict(legacy_save):
		return "legacy save (missing version) should be discarded, not loaded"
	if loaded.roster.size() != 4:
		return "discarded legacy save should reseed new-game roster (4), got %d" % loaded.roster.size()
	if loaded.player_actor.gold == 99999:
		return "discarded legacy save must not retain old gold"

	# 显式 (未来) 版本号同样丢弃重开。
	var future_save := loaded.to_dict()
	future_save["version"] = InkMonWorldGI.SAVE_VERSION + 1
	var loaded2 := _new_gi()
	if loaded2.from_dict(future_save):
		return "save with future version should be discarded, not loaded"
	return ""


## adr/0001 "一切实体常驻 registry": 标准 lookup (gi.get_actor / GameWorld.get_actor) 须能取回
## 非战斗 actor (player/NPC = InkMonWorldActor), 不被窄化成 null (回归守卫: get_actor 曾误返 InkMonBattleActor)。
func _assert_registry_lookup() -> String:
	GameWorld.destroy_all_instances()
	var gi := _new_gi()
	gi.new_game()
	var player_id := gi.player_actor.get_id()
	if gi.get_actor(player_id) != gi.player_actor:
		return "gi.get_actor(player_id) must return the live player actor (not null-narrowed)"
	if GameWorld.get_actor(player_id) != gi.player_actor:
		return "GameWorld.get_actor(player_id) must resolve player actor via registry delegation"
	var shop := gi.get_world_actor("shop")
	if shop == null or gi.get_actor(shop.get_id()) != shop:
		return "gi.get_actor must return NPC world actors too"
	var unit := gi.roster[0]
	if gi.get_battle_actor(unit.get_id()) != unit:
		return "gi.get_battle_actor must return a roster unit (battle-actor lookup)"
	if gi.get_battle_actor(player_id) != null:
		return "get_battle_actor(player) should be null (player_actor is not a battle actor)"
	return ""


## 回归守卫 (adr/0001 持久复用 actor 暴露): 局内进化改写 skill_slots[0] (X->X2) 后, 下一场复用战斗
## equip 的必须是升级技能 (从 skill_slots[0] 派生), 不是构造期缓存的旧技能。旧投影模型每战重投影无此问题。
func _assert_in_session_evolution_equips_upgraded_skill() -> String:
	GameWorld.destroy_all_instances()
	var gi := _new_gi()
	gi.new_game()
	var mon := gi.roster[1]  # 默认 roster[1] = cinder_kit (primary = fireball)
	if mon.species != "cinder_kit":
		return "expected default roster[1] to be cinder_kit for evolution test, got %s" % mon.species
	mon.level = 5
	if not InkMonSpeciesCatalog.evolve_actor(mon):
		return "cinder_kit at level 5 should evolve in-session"
	gi.refresh_unit_stats(mon)
	if mon.get_primary_skill_id() != InkMonChainLightning.CONFIG_ID:
		return "evolution should upgrade skill_slots[0] to chain_lightning, got %s" % mon.get_primary_skill_id()

	# 关键: 局内进化后出战 → equip 必须装当前 slot0 升级技能 (非陈旧缓存)。
	gi.request_training_battle()
	var skill := mon.get_skill_ability()
	if skill == null:
		return "evolved unit should have a primary skill ability equipped"
	if str(skill.config_id) != mon.get_primary_skill_id():
		return "in-session evolved unit equipped stale skill: equipped=%s slot0=%s" % [str(skill.config_id), mon.get_primary_skill_id()]
	return ""


func _new_gi() -> InkMonWorldGI:
	return GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI


func _has_key_recursive(value: Variant, key: String) -> bool:
	# 用 is 守卫 (非 `as` 转换) —— 对 primitive 叶子值 `x as Dictionary` 会抛 Invalid cast。
	if value is Dictionary:
		var dict_value := value as Dictionary
		if dict_value.has(key):
			return true
		for child in dict_value.values():
			if _has_key_recursive(child, key):
				return true
		return false
	if value is Array:
		for child in (value as Array):
			if _has_key_recursive(child, key):
				return true
	return false


func _shutdown(status: String) -> String:
	GameWorld.shutdown()
	return status
