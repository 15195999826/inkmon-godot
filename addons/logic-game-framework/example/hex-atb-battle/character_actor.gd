## CharacterActor - 角色 Actor
##
## 继承自 Actor，实现 ATB 系统和战斗属性
class_name CharacterActor
extends Actor


# ========== 常量 ==========

const ATB_FULL := 100.0


# ========== 属性 ==========

var character_class: HexBattleClassConfig.CharacterClass
## 生成式属性集
var attribute_set: HexBattleCharacterAttributeSet
var ability_set: BattleAbilitySet
var _is_dead: bool = false

## 当前位置（六边形坐标）
## 使用 HexCoord.invalid() 表示未设置位置，在 _init 中初始化
var hex_position: HexCoord = HexCoord.invalid()

## 移动 Ability ID
var _move_ability_id: String = ""

## 职业技能 Ability ID
var _skill_ability_id: String = ""

## 队伍 ID
var _team_id: int = -1

## ATB 行动条（0-100）
var _atb_gauge: float = 0.0


# ========== 初始化 ==========

func _init(p_character_class: HexBattleClassConfig.CharacterClass, instance_id: String = "") -> void:
	character_class = p_character_class
	type = "Character"
	
	# 生成完整 ID（如果提供了 instance_id，则使用 instance_id:local_id 格式）
	var local_id := IdGenerator.generate(type)
	if instance_id != "":
		_id = "%s:%s" % [instance_id, local_id]
	else:
		_id = local_id
	
	var class_config := HexBattleClassConfig.get_class_config(character_class)
	_display_name = class_config.name
	
	# 创建生成式属性集
	attribute_set = HexBattleCharacterAttributeSet.new()
	
	# 应用职业属性
	var stats := class_config.stats
	attribute_set.set_hp_base(stats["hp"])
	attribute_set.set_max_hp_base(stats["max_hp"])
	attribute_set.set_atk_base(stats["atk"])
	attribute_set.set_def_base(stats["def"])
	attribute_set.set_speed_base(stats["speed"])
	
	# 创建能力集（此时 ID 已确定）
	ability_set = BattleAbilitySet.create_battle_ability_set(get_id(), attribute_set)


## 装备技能（在 HexBattle 初始化时调用）
func equip_abilities() -> void:
	# 装备移动 Ability
	var move_ability := Ability.new(HexBattleSkillAbilities.MOVE_ABILITY, get_id())
	ability_set.grant_ability(move_ability)
	_move_ability_id = move_ability.id
	
	# 装备职业对应的技能
	var skill_type := HexBattleSkillConfig.get_class_skill(character_class)
	var skill_config := HexBattleSkillAbilities.get_skill_ability(skill_type)
	var skill_ability := Ability.new(skill_config, get_id())
	ability_set.grant_ability(skill_ability)
	_skill_ability_id = skill_ability.id
	
	# 装备职业被动技能
	_grant_class_passives()


## 根据职业装备被动技能
func _grant_class_passives() -> void:
	# 战士：荆棘反伤
	if character_class == HexBattleClassConfig.CharacterClass.WARRIOR:
		var thorn_passive := Ability.new(HexBattlePassiveAbilities.THORN_PASSIVE, get_id())
		ability_set.grant_ability(thorn_passive)


# ========== 队伍 ==========

func set_team_id(id: int) -> void:
	_team_id = id
	_team = str(id)


func get_team_id() -> int:
	return _team_id


# ========== Ability 访问 ==========

## 获取移动 Ability
func get_move_ability() -> Ability:
	return ability_set.find_ability_by_id(_move_ability_id)


## 获取技能 Ability
func get_skill_ability() -> Ability:
	return ability_set.find_ability_by_id(_skill_ability_id)


## 获取 AbilitySet（实现 IAbilitySetOwner 协议）
func get_ability_set() -> BattleAbilitySet:
	return ability_set

## 获取当前属性快照
func get_stats() -> Dictionary:
	return {
		"hp": attribute_set.hp,
		"max_hp": attribute_set.max_hp,
		"atk": attribute_set.atk,
		"def": attribute_set.def,
		"speed": attribute_set.speed,
	}


# ========== ATB 系统 ==========

## 获取 ATB 值
func get_atb_gauge() -> float:
	return _atb_gauge


## 累积 ATB（按速度）
func accumulate_atb(dt: float) -> void:
	var speed: float = attribute_set.speed
	# 速度 100 时，1000ms 充满
	_atb_gauge += (speed / 1000.0) * dt


## 是否可以行动
func can_act() -> bool:
	return _atb_gauge >= ATB_FULL


## 重置 ATB
func reset_atb() -> void:
	_atb_gauge = 0.0


# ========== 生命周期 ==========

## 检查是否死亡
func check_death() -> bool:
	if attribute_set.hp <= 0 and not _is_dead:
		_is_dead = true
		return true
	return false

func is_dead() -> bool:
	return _is_dead

func is_active() -> bool:
	return attribute_set.hp > 0


# ========== 录像支持（覆盖 Actor 基类方法） ==========

## 获取配置 ID（覆盖基类）
func _get_config_id() -> String:
	return HexBattleClassConfig.class_to_string(character_class)


## 获取队伍 ID（覆盖基类）
func _get_team_int() -> int:
	return _team_id


## 获取位置（覆盖基类，返回 hex 坐标作为 Vector3）
## 格式：Vector3(q, r, 0)，第三个分量保留用于高度扩展
## 具体含义由 configs.positionFormats["Character"] = "hex" 声明
func _get_position() -> Vector3:
	if not hex_position.is_valid():
		return Vector3.ZERO
	return Vector3(hex_position.q, hex_position.r, 0)


## 获取属性快照（覆盖基类）
func get_attribute_snapshot() -> Dictionary:
	return get_stats()


## 获取 Ability 快照（覆盖基类）
func get_ability_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ability in ability_set.get_abilities():
		result.append({
			"instance_id": ability.id,
			"config_id": ability.config_id,
		})
	return result


## 获取 Tag 快照（覆盖基类）
func get_tag_snapshot() -> Dictionary:
	return ability_set.get_all_tags()


## 设置录像回调（覆盖基类）
## 订阅所有框架事件：属性变化、Ability 生命周期、触发、执行、Tag 变化
func setup_recording(ctx: Dictionary) -> Array:
	var unsubscribes := []
	
	# 录制属性变化
	unsubscribes.append_array(RecordingUtils.record_attribute_changes(attribute_set, ctx))
	
	# 录制 AbilitySet 相关事件（Ability 授予/移除、触发、执行、Tag 变化）
	unsubscribes.append_array(RecordingUtils.record_ability_set_changes(ability_set, ctx))
	
	# 录制 Actor 生命周期（生成/销毁）
	unsubscribes.append_array(RecordingUtils.record_actor_lifecycle(self, ctx))
	
	return unsubscribes


# ========== 序列化 ==========

func serialize() -> Dictionary:
	var base := serialize_base()
	base["character_class"] = HexBattleClassConfig.class_to_string(character_class)
	base["hex_position"] = hex_position.to_dict() if hex_position.is_valid() else {}
	base["atb_gauge"] = _atb_gauge
	base["attribute_set"] = attribute_set._raw.serialize()
	return base
