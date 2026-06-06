## InkMonBattle2DBaseVisualizer - Visualizer 抽象基类
##
## Visualizer 把逻辑层事件 Dictionary 翻译为声明式 VisualAction。纯函数、只读 context、
## 不改状态。平移自 hex frontend（见 docs/adr/0006）。子类绑 inkmon 的 `inkmon_*` kind。
class_name InkMonBattle2DBaseVisualizer
extends RefCounted


## Visualizer 名称（调试用）
var visualizer_name: String = "BaseVisualizer"


# ========== 抽象方法 ==========

## 检查是否能处理该事件（子类必须覆盖）
func can_handle(_event: Dictionary) -> bool:
	push_error("[%s] can_handle() not implemented" % visualizer_name)
	return false


## 将事件翻译为视觉动作（子类必须覆盖）
func translate(_event: Dictionary, _context: InkMonBattle2DVisualizerContext) -> Array[InkMonBattle2DVisualAction]:
	push_error("[%s] translate() not implemented" % visualizer_name)
	return []


# ========== 辅助方法 ==========

static func get_event_kind(event: Dictionary) -> String:
	return event.get("kind", "") as String


static func get_string_field(event: Dictionary, field: String, default_value: String = "") -> String:
	return event.get(field, default_value) as String


static func get_float_field(event: Dictionary, field: String, default_value: float = 0.0) -> float:
	return event.get(field, default_value) as float


static func get_bool_field(event: Dictionary, field: String, default_value: bool = false) -> bool:
	return event.get(field, default_value) as bool


## 从事件 {"q": int, "r": int} 解析 HexCoord
static func get_hex_field(event: Dictionary, field: String) -> HexCoord:
	var hex_dict: Dictionary = event.get(field, {})
	return HexCoord.from_dict(hex_dict)
