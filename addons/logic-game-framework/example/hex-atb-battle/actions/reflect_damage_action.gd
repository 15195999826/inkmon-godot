## ReflectDamageAction - 反伤 Action
##
## ========== 设计原则 ==========
##
## Action 是原子操作单元：push 事件 + 应用状态 + post 事件 必须连续执行。
## 与 DamageAction 遵循相同的设计，确保状态同步的原子性。
##
## ========== 用途 ==========
##
## 用于被动技能触发时，对攻击来源造成固定伤害。
## 从触发事件中获取 source（攻击者），对其造成伤害。
##
## ========== 执行流程 ==========
##
## 1. 从 current_event 获取 source_actor_id（攻击者）
## 2. 产生反伤事件 + 立即应用伤害（原子操作）
## 3. 死亡检测：push(death_event) → process_post_event → remove_actor
## 4. Post 阶段：触发其他被动（如吸血）
##
## ========== 反伤链防护 ==========
##
## 反伤产生的 damage 事件带有 is_reflected: true 标记，
## 荆棘被动应在 filter 中排除这类事件，避免无限循环。
##
class_name HexBattleReflectDamageAction
extends Action.BaseAction


var _damage: float
var _damage_type: BattleEvents.DamageType


## 构造函数
## @param damage: 反伤伤害值
## @param damage_type: 伤害类型（默认 PURE）
func _init(
	damage: float,
	damage_type: BattleEvents.DamageType = BattleEvents.DamageType.PURE
) -> void:
	super._init(HexBattleTargetSelectors.event_source())
	type = "reflect_damage"
	_damage = damage
	_damage_type = damage_type


func execute(ctx: ExecutionContext) -> ActionResult:
	var targets := get_targets(ctx)
	if targets.is_empty():
		print("  [ReflectDamageAction] 无攻击来源，跳过反伤")
		return ActionResult.create_success_result([], { "skipped": true })
	
	var attacker_id := targets[0]
	
	var owner_actor_id := ctx.ability_ref.owner_actor_id if ctx.ability_ref != null else ""
	var battle: HexBattle = ctx.game_state_provider
	var owner_name := HexBattleGameStateUtils.get_actor_display_name(owner_actor_id, battle)
	var attacker_name := HexBattleGameStateUtils.get_actor_display_name(attacker_id, battle)
	var damage_type_str := BattleEvents._damage_type_to_string(_damage_type)
	print("  [ReflectDamageAction] %s 反伤 %s %.0f 点 %s 伤害" % [owner_name, attacker_name, _damage, damage_type_str])
	
	var event := BattleEvents.DamageEvent.create(
		attacker_id,
		_damage,
		_damage_type,
		owner_actor_id,
		false,  # is_critical
		true    # is_reflected
	)
	var reflect_event: Dictionary = ctx.event_collector.push(event.to_dict())
	var attacker_actor := battle.get_actor(attacker_id)
	if attacker_actor != null:
		attacker_actor.attribute_set.set_hp_base(attacker_actor.attribute_set.hp - _damage)
		
		print("  [伤害] %s 受到 %.0f 伤害, HP: %.0f (反伤)" % [
			attacker_name, _damage, attacker_actor.attribute_set.hp
		])
		
		if battle.logger != null:
			battle.logger.damage_dealt(owner_actor_id, attacker_id, _damage, damage_type_str, true)
		
		if attacker_actor.check_death():
			print("  [死亡] %s 已阵亡" % attacker_name)
			
			if battle.logger != null:
				battle.logger.actor_died(attacker_id, owner_actor_id)
			
			var death_event := BattleEvents.DeathEvent.create(attacker_id, owner_actor_id)
			var death_dict: Dictionary = ctx.event_collector.push(death_event.to_dict())
			
			var alive_for_death_event := battle.get_alive_actor_ids()
			if alive_for_death_event.size() > 0:
				GameWorld.event_processor.process_post_event(death_dict, alive_for_death_event, battle)
			
			battle.remove_actor(attacker_id)
	
	var alive_actor_ids := battle.get_alive_actor_ids()
	if alive_actor_ids.size() > 0:
		GameWorld.event_processor.process_post_event(reflect_event, alive_actor_ids, battle)
	
	return ActionResult.create_success_result([reflect_event], { "damage": _damage, "target": attacker_id })
