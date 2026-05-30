class_name InkMonStun


const CONFIG_ID := "inkmon_stun"
const TIMELINE_ID := "inkmon_stun"
const STUN_DURATION_MS := 1600.0
const COOLDOWN_MS := 5200.0


static var STUN_TIMELINE := TimelineData.new(
	TIMELINE_ID,
	500.0,
	{
		TimelineTags.HIT: 300.0,
		TimelineTags.END: 500.0,
	}
)


static var ABILITY := (
	AbilityConfig.builder()
	.config_id(CONFIG_ID)
	.display_name("Stun")
	.description("Apply a short action lock")
	.ability_tags(["skill", "active", "melee", "enemy", "control", "stun"])
	.meta(InkMonSkillMetaKeys.RANGE, 1)
	.active_use(
		ActiveUseConfig.builder()
		.timeline_id(TIMELINE_ID)
		.on_tag(TimelineTags.HIT, [InkMonApplyBuffAction.new(
			InkMonTargetSelectors.current_target(),
			InkMonStunBuff.create_config(STUN_DURATION_MS)
		)])
		.condition(Condition.NoTagCondition.new(InkMonActionLockStatus.TAG_CANT_ACT))
		.condition(InkMonCooldownSystem.CooldownCondition.new())
		.cost(InkMonCooldownSystem.TimedCooldownCost.new(COOLDOWN_MS))
		.build()
	)
	.build()
)
