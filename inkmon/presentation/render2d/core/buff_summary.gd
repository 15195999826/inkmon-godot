## InkMonRender2DBuffSummary - render 层 buff 摘要数据
##
## ActorRenderState.buffs 数组元素。dormant slot（buff 机制落地前不产生），
## 保留以保持 render-state 形状完整。平移自 hex frontend（见 docs/adr/0006）。
class_name InkMonRender2DBuffSummary
extends RefCounted


var id: String = ""
var config_id: String = ""
var display_name: String = ""
var short: String = ""
var color: Color = Color.WHITE
var primary: float = 0.0


func duplicate() -> InkMonRender2DBuffSummary:
	var copy := InkMonRender2DBuffSummary.new()
	copy.id = id
	copy.config_id = config_id
	copy.display_name = display_name
	copy.short = short
	copy.color = color
	copy.primary = primary
	return copy
