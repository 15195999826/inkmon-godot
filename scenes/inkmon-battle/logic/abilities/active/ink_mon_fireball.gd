class_name InkMonFireball


const CONFIG_ID := "inkmon_fireball"
const TIMELINE_ID := "inkmon_fireball"
const COOLDOWN_MS := 3600.0


static var FIREBALL_TIMELINE := TimelineData.new(
	TIMELINE_ID,
	600.0,
	{
		TimelineTags.HIT: 400.0,
		TimelineTags.END: 600.0,
	}
)


static var ABILITY := (
	AbilityConfig.builder()
	.config_id(CONFIG_ID)
	.display_name("Fireball")
	.description("Ranged AP fire damage")
	.ability_tags(["skill", "active", "ranged", "magic", "enemy"])
	.meta(InkMonSkillMetaKeys.RANGE, 5)
	.active_use(
		ActiveUseConfig.builder()
		.timeline_id(TIMELINE_ID)
		.on_tag(TimelineTags.HIT, [InkMonDamageAction.new(
			InkMonTargetSelectors.current_target(),
			InkMonSkillHelpers.caster_ap_damage(0.95, 14.0),
			InkMonBattleEvents.DamageType.MAGICAL,
			Resolvers.str_val(InkMonElementChart.FIRE)
		)])
		.condition(Condition.NoTagCondition.new(InkMonActionLockStatus.TAG_CANT_ACT))
		.condition(InkMonCooldownSystem.CooldownCondition.new())
		.cost(InkMonCooldownSystem.TimedCooldownCost.new(COOLDOWN_MS))
		.build()
	)
	.build()
)
