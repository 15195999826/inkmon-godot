class_name InkMonShopNpcHandler
extends InkMonNpcHandler


const ACTION_BUY_PREFIX := "buy:"


## Data-driven shop (adr/0003): every catalog item with price > 0 is buyable. action_id encodes
## the config_id (`buy:<item_id>`) so run_action can reverse-lookup without a hardcoded slug
## table — new server-synced items enter the shop automatically.
func get_actions(world: InkMonWorldGI) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var catalog := InkMonItemCatalog.new()
	for config_id in catalog.list_config_ids():
		var config := catalog.get_config(config_id)
		if int(config.get("price", 0)) > 0:
			actions.append(_buy_action(config_id, ACTION_BUY_PREFIX + str(config_id), world))
	return actions


func run_action(action_id: String, world: InkMonWorldGI) -> Dictionary:
	if action_id.begins_with(ACTION_BUY_PREFIX):
		return buy(world, StringName(action_id.substr(ACTION_BUY_PREFIX.length())))
	return super.run_action(action_id, world)


## 直接读写活 player_actor: 扣金币 + 入 bag; 失败回滚金币。供 NPC 菜单与 UI 买按钮共用。
func buy(world: InkMonWorldGI, config_id: StringName) -> Dictionary:
	var config := ItemSystem.get_item_config(config_id)
	if config.is_empty():
		return _result(false, "unknown shop item: %s" % str(config_id))
	var price := int(config.get("price", 0))
	if not world.player_actor.try_spend_gold(price):
		return _result(false, "not enough gold")
	var create_result := world.create_bag_item(config_id, 1, -1)
	if not create_result.success:
		world.player_actor.gold += price
		return _result(false, create_result.error_message)
	return _result(true, "bought %s" % str(config.get("display_name", str(config_id))))


func _buy_action(config_id: StringName, action_id: String, world: InkMonWorldGI) -> Dictionary:
	var config := ItemSystem.get_item_config(config_id)
	var price := int(config.get("price", 0))
	# display_name* = 内容字段透传 (adr/0011 内容轨), 非组装文案; 表现层 item_display 挑列。
	return _action(action_id, "shop_buy", world.player_actor.gold >= price, {
		"item_config_id": str(config_id),
		"price": price,
		"display_name": str(config.get("display_name", str(config_id))),
		"display_name_zh": str(config.get("display_name_zh", "")),
	})
