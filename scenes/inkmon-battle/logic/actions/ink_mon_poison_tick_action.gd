class_name InkMonPoisonTickAction
extends Action.PrimitiveAction


func _init() -> void:
	super._init(InkMonTargetSelectors.ability_owner())
	type = "inkmon_poison_tick"


func execute(ctx: ExecutionContext) -> ActionResult:
	if ctx.ability_ref == null:
		return ActionResult.create_success_result([])
	var battle: InkMonWorldGI = ctx.game_state_provider
	var owner := battle.get_unit_actor(ctx.ability_ref.owner_actor_id) if battle != null else null
	if owner == null or owner.is_dead():
		return ActionResult.create_success_result([])
	var source_id := ctx.ability_ref.source_actor_id
	var source := battle.get_unit_actor(source_id) if source_id != "" and battle != null else null
	var poison_ability := ctx.ability_ref.resolve()
	var stacks := poison_ability.stacks if poison_ability != null else 1
	var base_damage := 10.0 + float(stacks) * 6.0
	if source != null:
		base_damage = source.attribute_set.ap * 0.18 + float(stacks) * 6.0

	var action := InkMonDamageAction.new(
		InkMonTargetSelectors.ability_owner(),
		Resolvers.float_val(base_damage),
		InkMonBattleEvents.DamageType.MAGICAL,
		Resolvers.str_val(InkMonElementChart.DARK)
	)
	var result := Action.execute_child(self, action, ctx)

	if poison_ability != null:
		poison_ability.remove_stacks(1)
		if poison_ability.stacks <= 0:
			poison_ability.expire("poison_depleted")

	return result
