class_name InkMonHolyHeal


const CONFIG_ID := "inkmon_holy_heal"
const TIMELINE_ID := "inkmon_holy_heal"
const COOLDOWN_MS := 3400.0


static var HOLY_HEAL_TIMELINE := TimelineData.new(
	TIMELINE_ID,
	600.0,
	{
		TimelineTags.HEAL: 400.0,
		TimelineTags.END: 600.0,
	}
)


static var ABILITY := (
	AbilityConfig.builder()
	.config_id(CONFIG_ID)
	.display_name("Holy Heal")
	.description("Heal an allied InkMon")
	.ability_tags(["skill", "active", "heal", "ally", "self"])
	.meta(InkMonSkillMetaKeys.RANGE, 4)
	.active_use(
		ActiveUseConfig.builder()
		.timeline(HOLY_HEAL_TIMELINE)
		.on_tag(TimelineTags.HEAL, [InkMonHealAction.new(
			InkMonTargetSelectors.current_target(),
			InkMonSkillHelpers.caster_ap_heal(0.70, 18.0)
		)])
		.condition(Condition.NoTagCondition.new(InkMonActionLockStatus.TAG_CANT_ACT))
		.condition(InkMonCooldownSystem.CooldownCondition.new())
		.cost(InkMonCooldownSystem.TimedCooldownCost.new(COOLDOWN_MS))
		.build()
	)
	.build()
)
