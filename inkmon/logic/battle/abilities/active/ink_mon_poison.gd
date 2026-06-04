class_name InkMonPoison


const CONFIG_ID := "inkmon_poison"
const TIMELINE_ID := "inkmon_poison"
const COOLDOWN_MS := 3200.0


static var POISON_TIMELINE := TimelineData.new(
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
	.display_name("Poison")
	.description("Apply a dark poison DOT")
	.ability_tags(["skill", "active", "melee", "enemy", "debuff"])
	.meta(InkMonSkillMetaKeys.RANGE, 1)
	.active_use(
		ActiveUseConfig.builder()
		.timeline_id(TIMELINE_ID)
		.on_tag(TimelineTags.HIT, [InkMonApplyBuffAction.new(
			InkMonTargetSelectors.current_target(),
			InkMonPoisonBuff.POISON_BUFF
		)])
		.condition(Condition.NoTagCondition.new(InkMonActionLockStatus.TAG_CANT_ACT))
		.condition(InkMonCooldownSystem.CooldownCondition.new())
		.cost(InkMonCooldownSystem.TimedCooldownCost.new(COOLDOWN_MS))
		.build()
	)
	.build()
)
