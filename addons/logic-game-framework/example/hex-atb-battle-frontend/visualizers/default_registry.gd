## DefaultRegistry - 默认 Visualizer 注册表
##
## 创建包含所有默认 Visualizer 的注册表
class_name FrontendDefaultRegistry
extends RefCounted


## 创建默认注册表
static func create() -> FrontendVisualizerRegistry:
	var registry := FrontendVisualizerRegistry.new()
	
	# 注册所有默认 Visualizer
	registry.register(FrontendMoveVisualizer.new())
	registry.register(FrontendDamageVisualizer.new())
	registry.register(FrontendHealVisualizer.new())
	registry.register(FrontendDeathVisualizer.new())
	
	return registry
