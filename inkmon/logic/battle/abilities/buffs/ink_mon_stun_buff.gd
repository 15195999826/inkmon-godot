class_name InkMonStunBuff


const CONFIG_ID := "inkmon_buff_stun"
const DEFAULT_DURATION_MS := 1600.0


static func create_config(duration_ms: float) -> AbilityConfig:
	return (
		AbilityConfig.builder()
		.config_id(CONFIG_ID)
		.display_name("Stun")
		.description("Cannot act")
		.ability_tags(["buff", "negative", "control", "stun"])
		.meta("duration_ms", duration_ms)
		.component_config(
			TagComponentConfig.builder()
			.tag(InkMonActionLockStatus.TAG_CANT_ACT)
			.build()
		)
		.component_config(TimeDurationConfig.new(duration_ms))
		.build()
	)
