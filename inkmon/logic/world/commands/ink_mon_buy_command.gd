class_name InkMonBuyCommand
extends InkMonWorldCommand
## 购买商店物品(方案 A:入队,tick drain 才扣金币 + 入袋)。apply 委托 GI 的 shop handler(收 GI 持有的
## session),结果经 `gi.emit_command_applied(result)` 回流给 Host 刷 UI message —— 不同步返回值。


var config_id: StringName


func _init(p_config_id: StringName) -> void:
	config_id = p_config_id


func apply(gi: InkMonWorldGI) -> void:
	gi.emit_command_applied(gi.buy_shop_item(config_id))
