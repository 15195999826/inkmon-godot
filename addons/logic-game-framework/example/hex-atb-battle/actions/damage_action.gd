## DamageAction - 伤害 Action
##
## ========== 设计原则 ==========
##
## Action 是原子操作单元：push 事件 + 应用状态 + post 事件 必须连续执行。
## EventCollector 仅供录像/表演层消费，不参与逻辑状态同步。
##
## 分层职责：
## - AbilityComponent 决定「何时执行」
## - Action 决定「做什么」
## - BattleEvent 记录「结果」
##
## ========== 执行流程 ==========
##
## 1. Pre 阶段：创建 pre_damage 事件
##    - 允许减伤/免疫等被动修改或取消伤害
##    - 如果 mutable.cancelled，跳过此目标
##
## 2. 产生事件 + 应用状态（原子操作）：
##    - ctx.event_collector.push(damage_event)  ← 事件入队（录像用）
##    - target.modify_hp(-damage)               ← 立即扣血
##
## 3. 死亡检测：
##    - if check_death(): 
##        push(death_event) → process_post_event(death_event) → remove_actor()
##
## 4. 处理回调：on_hit / on_critical / on_kill
##
## 5. Post 阶段：触发反伤/吸血等被动响应
##
## ========== 支持的回调 ==========
##
## - on_hit: 每次命中时触发
## - on_critical: 暴击时触发
## - on_kill: 击杀时触发
##
class_name HexBattleDamageAction
extends Action.BaseAction


var _damage: float
var _damage_type: BattleEvents.DamageType

# 回调列表
var _on_hit_callbacks: Array[Action.BaseAction] = []
var _on_critical_callbacks: Array[Action.BaseAction] = []
var _on_kill_callbacks: Array[Action.BaseAction] = []


func _init(
	target_selector: TargetSelector,
	damage: float,
	damage_type: BattleEvents.DamageType = BattleEvents.DamageType.PHYSICAL
) -> void:
	super._init(target_selector)
	type = "damage"
	_damage = damage
	_damage_type = damage_type


# ============================================================
# 回调注册（链式调用）
# ============================================================

## 注册命中回调
func on_hit(action: Action.BaseAction) -> HexBattleDamageAction:
	_on_hit_callbacks.append(action)
	return self


## 注册暴击回调
func on_critical(action: Action.BaseAction) -> HexBattleDamageAction:
	_on_critical_callbacks.append(action)
	return self


## 注册击杀回调
func on_kill(action: Action.BaseAction) -> HexBattleDamageAction:
	_on_kill_callbacks.append(action)
	return self


# ============================================================
# 执行
# ============================================================

func execute(ctx: ExecutionContext) -> ActionResult:
	var source: ActorRef = null
	if ctx.ability != null:
		source = ctx.ability.owner
	var targets := get_targets(ctx)
	var battle: HexBattle = ctx.game_state_provider
	
	var event_processor: EventProcessor = GameWorld.event_processor
	var all_events: Array[Dictionary] = []
	
	# 获取存活角色 ID 列表（用于 Post 阶段广播）
	var alive_actor_ids: Array[String] = battle.get_alive_actor_ids()
	
	for target in targets:
		# ========== Pre 阶段 ==========
		var pre_event := {
			"kind": "pre_damage",
			"source": source,
			"target": target,
			"damage": _damage,
			"damage_type": BattleEvents._damage_type_to_string(_damage_type),
		}
		
		var mutable: MutableEvent = event_processor.process_pre_event(pre_event, battle)
		
		# 如果被取消（如免疫），跳过此目标
		if mutable.cancelled:
			var target_name := HexBattleGameStateUtils.get_actor_display_name(target, battle)
			print("  [DamageAction] %s 的伤害被取消" % target_name)
			continue
		
		# 获取修改后的伤害值
		var final_damage: float = mutable.get_current_value("damage")
		
		# TODO: 暴击判定（示例：10% 暴击率，1.5 倍伤害）
		var is_critical := randf() < 0.1
		if is_critical:
			final_damage *= 1.5
		
		# 打印日志
		var source_name := HexBattleGameStateUtils.get_actor_display_name(source, battle)
		var target_name := HexBattleGameStateUtils.get_actor_display_name(target, battle)
		var damage_type_str := BattleEvents._damage_type_to_string(_damage_type)
		var crit_text := " (暴击!)" if is_critical else ""
		if final_damage != _damage:
			print("  [DamageAction] %s 对 %s 造成 %.0f %s 伤害%s (原始: %.0f)" % [source_name, target_name, final_damage, damage_type_str, crit_text, _damage])
		else:
			print("  [DamageAction] %s 对 %s 造成 %.0f %s 伤害%s" % [source_name, target_name, final_damage, damage_type_str, crit_text])
		
		# ========== 产生最终事件（回放格式） ==========
		var source_id := source.id if source != null else ""
		var event := BattleEvents.DamageEvent.create(
			target.id,
			final_damage,
			_damage_type,
			source_id,
			is_critical
		)
		var damage_event: Dictionary = ctx.event_collector.push(event.to_dict())
		all_events.append(damage_event)
		
		# ========== 实际应用伤害 ==========
		var target_actor := battle.get_actor(target.id)
		if target_actor != null:
			target_actor.modify_hp(-final_damage)
			
			# 日志打印（与旧 _process_frame_events 格式一致）
			print("  [伤害] %s 受到 %.0f 伤害, HP: %.0f" % [
				target_name, final_damage, target_actor.get_hp()
			])
			
			# Logger 记录
			if battle.logger != null:
				battle.logger.damage_dealt(source_id, target.id, final_damage, damage_type_str, false)
			
			# 检查死亡
			if target_actor.check_death():
				print("  [死亡] %s 已阵亡" % target_name)
				
				# Logger 记录死亡
				if battle.logger != null:
					battle.logger.actor_died(target.id, source_id)
				
				# 推送死亡事件
				var death_event := BattleEvents.DeathEvent.create(target.id, source_id)
				var death_dict: Dictionary = ctx.event_collector.push(death_event.to_dict())
				all_events.append(death_dict)
				
				# Post 阶段处理死亡事件（可能触发死亡相关被动）
				if alive_actor_ids.size() > 0:
					event_processor.process_post_event(death_dict, alive_actor_ids, battle)
				
				# 移除角色
				battle.remove_actor(target.id)
		
		# ========== 处理回调 ==========
		var callback_events := _process_callbacks(damage_event, is_critical, ctx)
		all_events.append_array(callback_events)
		
		# ========== Post 阶段 ==========
		# 立即触发被动响应（如反伤、吸血）
		if alive_actor_ids.size() > 0:
			event_processor.process_post_event(damage_event, alive_actor_ids, battle)
	
	return ActionResult.create_success_result(all_events, { "damage": _damage })


# ============================================================
# 回调处理
# ============================================================

func _process_callbacks(damage_event: Dictionary, is_critical: bool, ctx: ExecutionContext) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var callback_ctx := ExecutionContext.create_callback_context(ctx, damage_event)
	
	# on_hit: 每次命中都触发
	for callback in _on_hit_callbacks:
		var result := callback.execute(callback_ctx)
		if result != null and result.events:
			events.append_array(result.events)
	
	# on_critical: 仅暴击时触发
	if is_critical:
		for callback in _on_critical_callbacks:
			var result := callback.execute(callback_ctx)
			if result != null and result.events:
				events.append_array(result.events)
	
	# on_kill: 检查目标是否死亡
	var is_kill := _check_target_killed(damage_event, ctx)
	if is_kill:
		for callback in _on_kill_callbacks:
			var result := callback.execute(callback_ctx)
			if result != null and result.events:
				events.append_array(result.events)
	
	return events


func _check_target_killed(damage_event: Dictionary, ctx: ExecutionContext) -> bool:
	var target_id: String = damage_event.get("target_actor_id", "")
	if target_id.is_empty():
		return false
	return HexBattleGameStateUtils.is_actor_dead(target_id, ctx.game_state_provider)
