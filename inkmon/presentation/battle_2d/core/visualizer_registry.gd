## InkMonBattle2DVisualizerRegistry - Visualizer 注册表
##
## 管理所有 Visualizer 的注册与事件分发。collect-all：一个事件可由多个 Visualizer 协作
## 处理（如 damage 同时产飘字 + 闪白 + 扣血）。平移自 hex frontend（见 docs/adr/0006）。
class_name InkMonBattle2DVisualizerRegistry
extends RefCounted


var _visualizers: Array[InkMonBattle2DBaseVisualizer] = []
var _debug_mode: bool = false


# ========== 注册 ==========

func register(visualizer: InkMonBattle2DBaseVisualizer) -> InkMonBattle2DVisualizerRegistry:
	_visualizers.append(visualizer)
	return self


func register_all(visualizers: Array[InkMonBattle2DBaseVisualizer]) -> InkMonBattle2DVisualizerRegistry:
	for v: InkMonBattle2DBaseVisualizer in visualizers:
		register(v)
	return self


func set_debug_mode(enabled: bool) -> InkMonBattle2DVisualizerRegistry:
	_debug_mode = enabled
	return self


# ========== 翻译 ==========

## 遍历所有注册 Visualizer，收集能处理该事件的所有动作
func translate(event: Dictionary, context: InkMonBattle2DVisualizerContext) -> Array[InkMonBattle2DVisualAction]:
	var actions: Array[InkMonBattle2DVisualAction] = []
	var event_kind: String = event.get("kind", "unknown")

	for visualizer: InkMonBattle2DBaseVisualizer in _visualizers:
		if visualizer.can_handle(event):
			var result: Array[InkMonBattle2DVisualAction] = visualizer.translate(event, context)
			actions.append_array(result)
			if _debug_mode:
				Log.debug("InkMonBattle2DVisualizerRegistry", "%s -> %s 生成 %d 个动作" % [
					event_kind, visualizer.visualizer_name, result.size()
				])

	return actions


func translate_all(events: Array[Dictionary], context: InkMonBattle2DVisualizerContext) -> Array[InkMonBattle2DVisualAction]:
	var actions: Array[InkMonBattle2DVisualAction] = []
	for event: Dictionary in events:
		actions.append_array(translate(event, context))
	return actions


# ========== 查询 ==========

func has_visualizer_for(event_kind: String) -> bool:
	var test_event := { "kind": event_kind }
	for visualizer: InkMonBattle2DBaseVisualizer in _visualizers:
		if visualizer.can_handle(test_event):
			return true
	return false


func get_count() -> int:
	return _visualizers.size()


func get_registered_names() -> Array[String]:
	var names: Array[String] = []
	for visualizer: InkMonBattle2DBaseVisualizer in _visualizers:
		names.append(visualizer.visualizer_name)
	return names
