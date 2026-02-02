## HealAction - 治疗 Action
##
## ========== 设计原则 ==========
##
## Action 是原子操作单元：push 事件 + 应用状态 + post 事件 必须连续执行。
## 与 DamageAction 遵循相同的设计，确保状态同步的原子性。
##
## ========== 执行流程 ==========
##
## 1. 产生治疗事件 + 立即应用治疗（原子操作）：
##    - ctx.event_collector.push(heal_event)  ← 事件入队（录像用）
##    - target.set_hp(new_hp)                 ← 立即加血
##
## 2. 处理回调：on_heal / on_overheal
##
## 3. Post 阶段：触发治疗相关被动响应
##
## ========== 支持的回调 ==========
##
## - on_heal: 每次治疗时触发
## - on_overheal: 过量治疗时触发（治疗量超过目标缺失生命值）
##
class_name HexBattleHealAction
extends Action.BaseAction


var _heal_amount: FloatResolver

# 回调列表
var _on_heal_callbacks: Array[Action.BaseAction] = []
var _on_overheal_callbacks: Array[Action.BaseAction] = []


func _init(
	target_selector: TargetSelector,
	heal_amount: FloatResolver
) -> void:
	super._init(target_selector)
	type = "heal"
	_heal_amount = heal_amount


# ============================================================
# 回调注册（链式调用）
# ============================================================

## 注册治疗回调
func on_heal(action: Action.BaseAction) -> HexBattleHealAction:
	_on_heal_callbacks.append(action)
	return self


## 注册过量治疗回调
func on_overheal(action: Action.BaseAction) -> HexBattleHealAction:
	_on_overheal_callbacks.append(action)
	return self


# ============================================================
# 执行
# ============================================================

func execute(ctx: ExecutionContext) -> ActionResult:
	var source: ActorRef = null
	if ctx.ability != null:
		source = ctx.ability.owner
	var targets := get_targets(ctx)
	
	# 解析参数
	var heal_amount := _heal_amount.resolve(ctx)
	
	# 打印日志
	var target_ids: Array[String] = []
	for t in targets:
		target_ids.append(t.id)
	var source_id := source.id if source != null else "???"
	print("  [HealAction] %s 对 [%s] 治疗 %.0f HP" % [source_id, ", ".join(target_ids), heal_amount])
	
	# 产生回放格式事件
	var all_events: Array[Dictionary] = []
	var battle: HexBattle = ctx.game_state_provider
	var event_processor: EventProcessor = GameWorld.event_processor
	var actors := HexBattleGameStateUtils.get_actors_for_event_processor(battle)
	
	for target in targets:
		var source_id_str := source.id if source != null else ""
		
		# 计算过量治疗
		var overheal := _calculate_overheal(target, heal_amount, ctx)
		
		var event := BattleEvents.HealEvent.create(
			target.id,
			heal_amount,
			source_id_str
		)
		var heal_event: Dictionary = ctx.event_collector.push(event.to_dict())
		
		# 添加过量治疗信息
		if overheal > 0:
			heal_event["overheal"] = overheal
		
		all_events.append(heal_event)
		
		# ========== 实际应用治疗 ==========
		var target_actor := battle.get_actor(target.id)
		if target_actor != null:
			var old_hp := target_actor.get_hp()
			var max_hp := target_actor.get_max_hp()
			var new_hp := minf(old_hp + heal_amount, max_hp)
			target_actor.set_hp(new_hp)
			
			# 获取目标名称
			var target_name := HexBattleGameStateUtils.get_actor_display_name(target, battle)
			
			# 日志打印（与旧 _process_frame_events 格式一致）
			print("  [治疗] %s 恢复 %.0f HP, HP: %.0f -> %.0f" % [
				target_name, heal_amount, old_hp, new_hp
			])
			
			# Logger 记录
			if battle.logger != null:
				battle.logger.heal_applied(source_id_str, target.id, heal_amount)
		
		# ========== 处理回调 ==========
		var callback_events := _process_callbacks(heal_event, overheal, ctx)
		all_events.append_array(callback_events)
		
		# ========== Post 阶段 ==========
		if actors.size() > 0:
			event_processor.process_post_event(heal_event, actors, battle)
	
	return ActionResult.create_success_result(all_events, { "heal_amount": heal_amount })


# ============================================================
# 回调处理
# ============================================================

func _process_callbacks(heal_event: Dictionary, overheal: float, ctx: ExecutionContext) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var callback_ctx := ExecutionContext.create_callback_context(ctx, heal_event)
	
	# on_heal: 每次治疗都触发
	for callback in _on_heal_callbacks:
		var result := callback.execute(callback_ctx)
		if result != null and result.events:
			events.append_array(result.events)
	
	# on_overheal: 仅过量治疗时触发
	if overheal > 0:
		for callback in _on_overheal_callbacks:
			var result := callback.execute(callback_ctx)
			if result != null and result.events:
				events.append_array(result.events)
	
	return events


func _calculate_overheal(target: ActorRef, heal_amount: float, ctx: ExecutionContext) -> float:
	if ctx.game_state_provider == null:
		return 0.0
	
	if ctx.game_state_provider.has_method("get_actor"):
		var target_actor = ctx.game_state_provider.get_actor(target.id)
		if target_actor != null:
			var current_hp := 0.0
			var max_hp := 0.0
			
			if target_actor.has_method("get_current_hp"):
				current_hp = target_actor.get_current_hp()
			if target_actor.has_method("get_max_hp"):
				max_hp = target_actor.get_max_hp()
			
			if max_hp > 0:
				var missing_hp := max_hp - current_hp
				if heal_amount > missing_hp:
					return heal_amount - missing_hp
	
	return 0.0



