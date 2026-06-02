class_name InkMonAIStrategyFactory
## personality → AI 策略路由。
## ⚠ INTERIM(adr/0008):role 路由已废弃;现按 personality 选策(godot-internal 临时实现),
## 未来 personality 走 canon 字段,策略集与映射可能随 personality 语义重设。


static var _frontline: InkMonAIStrategy = InkMonFrontlineStrategy.new()
static var _aggressive: InkMonAIStrategy = InkMonAggressiveStrategy.new()
static var _support: InkMonAIStrategy = InkMonSupportStrategy.new()


static func get_strategy(personality: String) -> InkMonAIStrategy:
	match personality:
		InkMonUnitConfig.PERSONALITY_FRONTLINE:
			return _frontline
		InkMonUnitConfig.PERSONALITY_SUPPORT:
			return _support
		_:
			# aggressive = default(含未知 personality):InkMonAggressiveStrategy 即 base 默认行为。
			return _aggressive
