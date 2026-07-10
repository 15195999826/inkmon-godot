class_name InkMonMove


const CONFIG_ID := "inkmon_action_move"
const TIMELINE_ID := "inkmon_action_move"


static var MOVE_TIMELINE := TimelineData.new(
	TIMELINE_ID,
	200.0,
	{
		TimelineTags.EXECUTE: 100.0,
		TimelineTags.END: 200.0,
	}
)


static var ABILITY := (
	AbilityConfig.builder()
	.config_id(CONFIG_ID)
	.display_name("Move")
	.description("Move to an adjacent hex")
	.ability_tags(["action", "move"])
	.active_use(
		ActiveUseConfig.builder()
		.timeline(MOVE_TIMELINE)
		.on_timeline_start([InkMonStartMoveAction.new(
			InkMonTargetSelectors.ability_owner(),
			InkMonSkillHelpers.target_coord_from_event()
		)])
		.on_tag(TimelineTags.EXECUTE, [InkMonApplyMoveAction.new(
			InkMonTargetSelectors.ability_owner(),
			InkMonSkillHelpers.target_coord_from_event()
		)])
		.condition(Condition.NoTagCondition.new(InkMonActionLockStatus.TAG_CANT_ACT))
		.build()
	)
	.build()
)
