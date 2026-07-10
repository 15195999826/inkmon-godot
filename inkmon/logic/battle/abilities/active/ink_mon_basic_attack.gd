class_name InkMonBasicAttack


const CONFIG_ID := "inkmon_basic_attack"
const TIMELINE_ID := "inkmon_basic_attack"
const COOLDOWN_MS := 1600.0


static var BASIC_ATTACK_TIMELINE := TimelineData.new(
	TIMELINE_ID,
	450.0,
	{
		TimelineTags.HIT: 250.0,
		TimelineTags.END: 450.0,
	}
)


static var ABILITY := (
	AbilityConfig.builder()
	.config_id(CONFIG_ID)
	.display_name("Basic Attack")
	.description("Adjacent physical attack using AD")
	.ability_tags(["skill", "active", "melee", "enemy", "basic_attack"])
	.meta(InkMonSkillMetaKeys.RANGE, 1)
	.active_use(
		ActiveUseConfig.builder()
		.timeline(BASIC_ATTACK_TIMELINE)
		.on_tag(TimelineTags.HIT, [InkMonDamageAction.new(
			InkMonTargetSelectors.current_target(),
			InkMonSkillHelpers.caster_ad_damage(1.0),
			InkMonBattleEvents.DamageType.PHYSICAL,
			Resolvers.str_val("")
		)])
		.condition(Condition.NoTagCondition.new(InkMonActionLockStatus.TAG_CANT_ACT))
		.condition(InkMonCooldownSystem.CooldownCondition.new())
		.cost(InkMonCooldownSystem.TimedCooldownCost.new(COOLDOWN_MS))
		.build()
	)
	.build()
)
