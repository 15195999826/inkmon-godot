class_name InkMonPoisonBuff


const CONFIG_ID := "inkmon_buff_poison"
const TICK_TIMELINE_ID := "inkmon_buff_poison_tick"
const TICK_INTERVAL_MS := 1800.0
const DEFAULT_INITIAL_STACKS := 3
const POISON_MAX_STACKS := 999


static var POISON_TICK_TIMELINE := TimelineData.periodic(TICK_TIMELINE_ID, TICK_INTERVAL_MS)


static var POISON_BUFF := (
	AbilityConfig.builder()
	.config_id(CONFIG_ID)
	.display_name("Poison")
	.description("Periodic dark damage; stacks decay per tick")
	.ability_tags(["buff", "negative", "poison"])
	.stacks(DEFAULT_INITIAL_STACKS, POISON_MAX_STACKS, Ability.OVERFLOW_CAP)
	.component_config(
		ActivateInstanceConfig.builder()
		.trigger(TriggerConfig.GRANTED_SELF)
		.timeline_id(TICK_TIMELINE_ID)
		.on_timeline_end([InkMonPoisonTickAction.new()])
		.build()
	)
	.build()
)
