class_name InkMonChainLightning


const CONFIG_ID := "inkmon_chain_lightning"
const TIMELINE_ID := "inkmon_chain_lightning"
const COOLDOWN_MS := 4600.0


static var CHAIN_LIGHTNING_TIMELINE := TimelineData.new(
	TIMELINE_ID,
	650.0,
	{
		TimelineTags.HIT: 420.0,
		TimelineTags.END: 650.0,
	}
)


static var ABILITY := (
	AbilityConfig.builder()
	.config_id(CONFIG_ID)
	.display_name("Chain Lightning")
	.description("Wind AP damage that jumps up to three enemies")
	.ability_tags(["skill", "active", "ranged", "magic", "enemy"])
	.meta(InkMonSkillMetaKeys.RANGE, 5)
	.active_use(
		ActiveUseConfig.builder()
		.timeline(CHAIN_LIGHTNING_TIMELINE)
		.on_tag(TimelineTags.HIT, [InkMonChainLightningAction.new(
			InkMonTargetSelectors.current_target(),
			InkMonSkillHelpers.caster_ap_damage(0.75, 10.0),
			3,
			0.8
		)])
		.condition(Condition.NoTagCondition.new(InkMonActionLockStatus.TAG_CANT_ACT))
		.condition(InkMonCooldownSystem.CooldownCondition.new())
		.cost(InkMonCooldownSystem.TimedCooldownCost.new(COOLDOWN_MS))
		.build()
	)
	.build()
)
