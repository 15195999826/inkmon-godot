## InkMonBattle2DDefaultRegistry - 默认 Visualizer 注册表工厂
##
## 纯静态工具类。首版只注册 active 4 件（move/damage/heal/death）；dormant 机制落地后
## 在此 register 对应 visualizer（见 docs/adr/0006 的 dormant slot 清单）。
class_name InkMonBattle2DDefaultRegistry


static func create() -> InkMonRender2DVisualizerRegistry:
	var registry := InkMonRender2DVisualizerRegistry.new()
	registry.register(InkMonRender2DMoveVisualizer.new())
	registry.register(InkMonBattle2DDamageVisualizer.new())
	registry.register(InkMonBattle2DHealVisualizer.new())
	registry.register(InkMonBattle2DDeathVisualizer.new())
	return registry
