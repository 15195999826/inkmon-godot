class_name InkMonShopNpcHandler
extends InkMonNpcHandler


const ACTION_BUY_SWORD := "buy_training_sword"
const ACTION_BUY_RUNE := "buy_minor_rune"


func get_actions(session: InkMonGameSession) -> Array[Dictionary]:
	return [
		_buy_action(InkMonItemCatalog.TRAINING_SWORD, ACTION_BUY_SWORD, session),
		_buy_action(InkMonItemCatalog.MINOR_RUNE, ACTION_BUY_RUNE, session),
	]


func run_action(action_id: String, session: InkMonGameSession) -> Dictionary:
	match action_id:
		ACTION_BUY_SWORD:
			return buy(session, InkMonItemCatalog.TRAINING_SWORD)
		ACTION_BUY_RUNE:
			return buy(session, InkMonItemCatalog.MINOR_RUNE)
		_:
			return super.run_action(action_id, session)


## 直接读写 session: 扣金币 + 入袋; 失败回滚金币。供 NPC 菜单与 UI 买按钮共用。
func buy(session: InkMonGameSession, config_id: StringName) -> Dictionary:
	var config := ItemSystem.get_item_config(config_id)
	if config.is_empty():
		return _result(false, "unknown shop item: %s" % str(config_id))
	var price := int(config.get("price", 0))
	if not session.player_state.try_spend_gold(price):
		return _result(false, "not enough gold")
	var create_result := session.create_bag_item(config_id, 1, -1)
	if not create_result.success:
		session.player_state.gold += price
		return _result(false, create_result.error_message)
	return _result(true, "bought %s" % str(config.get("display_name", str(config_id))))


func _buy_action(config_id: StringName, action_id: String, session: InkMonGameSession) -> Dictionary:
	var config := ItemSystem.get_item_config(config_id)
	var price := int(config.get("price", 0))
	var action := _action(
		action_id,
		str(config.get("display_name", str(config_id))),
		"%d Gold" % price,
		"shop_buy",
		session.player_state.gold >= price
	)
	action["item_config_id"] = str(config_id)
	action["price"] = price
	return action
