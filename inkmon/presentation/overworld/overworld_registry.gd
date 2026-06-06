class_name InkMonOverworldRegistry

## 主世界 visualizer 注册表（adr/0007）。主世界只有「移动」一种 actor 事件，故只注册共享
## MoveVisualizer（与 battle 同一个类）。日后主世界出新事件（特效/天气/大地战斗）在此 register。
static func create() -> InkMonRender2DVisualizerRegistry:
	var registry := InkMonRender2DVisualizerRegistry.new()
	registry.register(InkMonRender2DMoveVisualizer.new())
	return registry
