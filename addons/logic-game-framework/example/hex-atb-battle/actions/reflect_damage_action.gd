## ReflectDamageAction - 反伤 Action
##
## 用于被动技能触发时，对攻击来源造成固定伤害。
## 从触发事件中获取 source（攻击者），对其造成伤害。
##
## 反伤链防护：
## 反伤产生的 damage 事件带有 is_reflected: true 标记，
## 荆棘被动应在 filter 中排除这类事件，避免无限循环。
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
	super._init(null)  # ReflectDamageAction 不使用 target_selector
	type = "reflect_damage"
	_damage = damage
	_damage_type = damage_type


func execute(ctx: ExecutionContext) -> ActionResult:
	var current_event: Dictionary = ctx.get_current_event()
	
	# 从触发事件获取攻击来源（使用回放格式）
	var attacker_id: String = ""
	if current_event is Dictionary:
		attacker_id = current_event.get("source_actor_id", "")
	
	if attacker_id == "":
		print("  [ReflectDamageAction] 无攻击来源，跳过反伤")
		return ActionResult.create_success_result([], { "skipped": true })
	
	var owner: ActorRef = null
	if ctx.ability != null:
		owner = ctx.ability.owner
	
	var battle: HexBattle = ctx.game_state_provider
	
	# 获取显示名称
	var owner_name := HexBattleGameStateUtils.get_actor_display_name(owner, battle)
	var attacker_name := HexBattleGameStateUtils.get_actor_display_name(ActorRef.new(attacker_id), battle)
	var damage_type_str := BattleEvents._damage_type_to_string(_damage_type)
	print("  [ReflectDamageAction] %s 反伤 %s %.0f 点 %s 伤害" % [owner_name, attacker_name, _damage, damage_type_str])
	
	# 产生伤害事件（回放格式），带 is_reflected 标记防止无限循环
	var owner_id := owner.id if owner != null else ""
	var event := BattleEvents.DamageEvent.create(
		attacker_id,
		_damage,
		_damage_type,
		owner_id,
		false,  # is_critical
		true    # is_reflected
	)
	var reflect_event: Dictionary = ctx.event_collector.push(event.to_dict())
	
	# Post 阶段：触发其他被动（如吸血），但不会触发反伤（因为有 is_reflected 标记）
	var actors := HexBattleGameStateUtils.get_actors_for_event_processor(battle)
	if actors.size() > 0:
		var event_processor: EventProcessor = GameWorld.event_processor
		event_processor.process_post_event(reflect_event, actors, battle)
	
	return ActionResult.create_success_result([reflect_event], { "damage": _damage, "target": attacker_id })
