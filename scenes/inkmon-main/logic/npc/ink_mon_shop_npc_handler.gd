class_name InkMonShopNpcHandler
extends InkMonNpcHandler


const ACTION_BUY_SWORD := "buy_training_sword"
const ACTION_BUY_RUNE := "buy_minor_rune"


func get_actions(app_root: InkMonAppRoot) -> Array[Dictionary]:
	return [
		_buy_action(InkMonItemCatalog.TRAINING_SWORD, ACTION_BUY_SWORD, app_root),
		_buy_action(InkMonItemCatalog.MINOR_RUNE, ACTION_BUY_RUNE, app_root),
	]


func run_action(action_id: String, app_root: InkMonAppRoot) -> Dictionary:
	match action_id:
		ACTION_BUY_SWORD:
			return app_root.purchase_shop_item(InkMonItemCatalog.TRAINING_SWORD)
		ACTION_BUY_RUNE:
			return app_root.purchase_shop_item(InkMonItemCatalog.MINOR_RUNE)
		_:
			return super.run_action(action_id, app_root)


func _buy_action(config_id: StringName, action_id: String, app_root: InkMonAppRoot) -> Dictionary:
	var config := ItemSystem.get_item_config(config_id)
	var price := int(config.get("price", 0))
	var action := _action(
		action_id,
		str(config.get("display_name", str(config_id))),
		"%d Gold" % price,
		"shop_buy",
		app_root.session.player_state.gold >= price
	)
	action["item_config_id"] = str(config_id)
	action["price"] = price
	return action
