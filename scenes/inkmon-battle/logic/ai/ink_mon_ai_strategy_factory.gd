class_name InkMonAIStrategyFactory


static var _tank: InkMonAIStrategy = InkMonRoleTankStrategy.new()
static var _dps: InkMonAIStrategy = InkMonRoleDpsStrategy.new()
static var _healer: InkMonAIStrategy = InkMonRoleHealerStrategy.new()
static var _default: InkMonAIStrategy = InkMonAIStrategy.new()


static func get_strategy(role: String) -> InkMonAIStrategy:
	match role:
		InkMonUnitConfig.ROLE_TANK:
			return _tank
		InkMonUnitConfig.ROLE_DPS:
			return _dps
		InkMonUnitConfig.ROLE_HEALER:
			return _healer
		_:
			return _default
