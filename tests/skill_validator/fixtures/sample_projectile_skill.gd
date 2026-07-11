extends RefCounted
## Fixture: AI 风格技能, 遵循 canonical `static var ABILITY` 模板。
##
## 故意 **不写 class_name** —— SkillValidator 在运行期 GDScript.new().reload()
## 重编译这段源码, 若带 class_name 会与已注册全局类冲突。AI 生成的待验证技能
## 同样不应依赖 class_name 注册。
##
## 覆盖回归点:
##   - P0-1: 用 `static var ABILITY`, 不用废弃的 create_ability_config()
##   - 新-1: active_use 的 flat DamageAction (float_val 25.0) 应被静态提取出数值
##   - 新-2: projectile 命中伤害住在 component_config(ActivateInstanceConfig),
##           flat DamageAction (float_val 50.0) 应在 validation summary 中可见

const CONFIG_ID := "skill_test_projectile"
const CAST_TIMELINE_ID := "skill_test_projectile"
const HIT_TIMELINE_ID := "skill_test_projectile_hit"

static var CAST_TIMELINE := TimelineData.new(
	CAST_TIMELINE_ID,
	600.0,
	{TimelineTags.HIT: 400.0}
)
static var HIT_TIMELINE := TimelineData.new(HIT_TIMELINE_ID, 1.0)


static var ABILITY := (
	AbilityConfig.builder()
	.config_id(CONFIG_ID)
	.display_name("Test Projectile")
	.description("fixture skill for SkillValidator regression")
	.ability_tags(["skill", "active", "ranged", "magic", "enemy", "projectile"])
	.meta(HexBattleSkillMetaKeys.RANGE, 5)
	.active_use(
		ActiveUseConfig.builder()
		.timeline(CAST_TIMELINE)
		.on_timeline_start([StageCueAction.new(
			HexBattleTargetSelectors.current_target(),
			Resolvers.str_val("test_cue")
		)])
		.on_tag(TimelineTags.HIT, [HexBattleDamageAction.new(
			HexBattleTargetSelectors.current_target(),
			Resolvers.float_val(25.0),
			BattleEvents.DamageType.PHYSICAL
		)])
		.build()
	)
	.component_config(
		ActivateInstanceConfig.builder()
		.trigger(TriggerConfig.new(ProjectileEvents.PROJECTILE_HIT_EVENT, Callable()))
		.timeline(HIT_TIMELINE)
		.on_timeline_start([HexBattleDamageAction.new(
			HexBattleTargetSelectors.current_target(),
			Resolvers.float_val(50.0),
			BattleEvents.DamageType.MAGICAL
		)])
		.build()
	)
	.build()
)
