## DamageAction - 伤害 Action
##
## 实现完整的 Pre/Post 双阶段事件处理：
## 1. Pre 阶段：创建 pre_damage 事件，允许减伤/免疫等被动修改或取消
## 2. 如果未取消，使用修改后的伤害值产生 damage 事件
## 3. Post 阶段：立即触发反伤/吸血等被动响应
##
## 支持的回调：
## - on_hit: 每次命中时触发
## - on_critical: 暴击时触发
## - on_kill: 击杀时触发
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
	
	var event_processor: Variant = GameWorld.event_processor
	var all_events: Array = []
	
	# 获取 actors 列表（用于 Post 阶段广播）
	var actors := HexBattleGameStateUtils.get_actors_for_event_processor(battle)
	
	for target in targets:
		# ========== Pre 阶段 ==========
		var pre_event := {
			"kind": "pre_damage",
			"source": source,
			"target": target,
			"damage": _damage,
			"damage_type": BattleEvents._damage_type_to_string(_damage_type),
		}
		
		var mutable: Variant = event_processor.process_pre_event(pre_event, battle)
		
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
		
		# ========== 处理回调 ==========
		var callback_events := _process_callbacks(damage_event, is_critical, ctx)
		all_events.append_array(callback_events)
		
		# ========== Post 阶段 ==========
		# 立即触发被动响应（如反伤、吸血）
		if actors.size() > 0:
			event_processor.process_post_event(damage_event, actors, battle)
	
	return ActionResult.create_success_result(all_events, { "damage": _damage })


# ============================================================
# 回调处理
# ============================================================

func _process_callbacks(damage_event: Dictionary, is_critical: bool, ctx: ExecutionContext) -> Array:
	var events: Array = []
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
