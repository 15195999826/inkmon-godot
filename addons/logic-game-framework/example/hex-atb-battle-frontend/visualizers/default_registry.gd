class_name FrontendDefaultRegistry
## 纯静态工具类：默认 Visualizer 注册表工厂


## 创建默认注册表
static func create() -> FrontendVisualizerRegistry:
	var registry := FrontendVisualizerRegistry.new()
	
	# 注册所有默认 Visualizer
	registry.register(FrontendMoveVisualizer.new())
	registry.register(FrontendDamageVisualizer.new())
	registry.register(FrontendHealVisualizer.new())
	registry.register(FrontendDeathVisualizer.new())
	
	return registry
