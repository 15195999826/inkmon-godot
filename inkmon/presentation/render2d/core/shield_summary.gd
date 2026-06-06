## InkMonRender2DShieldSummary - render 层护盾摘要数据
##
## ActorRenderState.shields 数组元素。dormant slot（shield 机制落地前不产生），
## 保留以保持 render-state 形状完整。平移自 hex frontend（见 docs/adr/0006）。
class_name InkMonRender2DShieldSummary
extends RefCounted


var id: String = ""
var config_id: String = ""
var current: float = 0.0
var capacity: float = 0.0
var color: Color = Color.WHITE
var priority: int = 0


func duplicate() -> InkMonRender2DShieldSummary:
	var copy := InkMonRender2DShieldSummary.new()
	copy.id = id
	copy.config_id = config_id
	copy.current = current
	copy.capacity = capacity
	copy.color = color
	copy.priority = priority
	return copy
