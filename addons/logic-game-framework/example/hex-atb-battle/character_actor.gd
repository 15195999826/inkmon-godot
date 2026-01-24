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
var attributes: HexBattleCharacterAttributeSet
var ability_set: BattleAbilitySet

## 当前位置（六边形坐标）
var hex_position: Dictionary = { "q": 0, "r": 0 }

## 移动 Ability ID
var _move_ability_id: String = ""

## 职业技能 Ability ID
var _skill_ability_id: String = ""

## 队伍 ID
var _team_id: int = -1

## ATB 行动条（0-100）
var _atb_gauge: float = 0.0


# ========== 初始化 ==========

func _init(p_character_class: HexBattleClassConfig.CharacterClass) -> void:
	character_class = p_character_class
	type = "Character"
	
	var class_config := HexBattleClassConfig.get_class_config(character_class)
	_display_name = class_config.name
	
	# 创建生成式属性集
	attributes = HexBattleCharacterAttributeSet.new()
	
	# 应用职业属性
	var stats := class_config.stats
	attributes.setHpBase(stats["hp"])
	attributes.setMaxHpBase(stats["max_hp"])
	attributes.setAtkBase(stats["atk"])
	attributes.setDefBase(stats["def"])
	attributes.setSpeedBase(stats["speed"])
	
	# 创建能力集（传入底层 RawAttributeSet）
	ability_set = BattleAbilitySet.create_battle_ability_set(to_ref(), attributes._raw)


## 装备技能（在 HexBattle 初始化时调用）
func equip_abilities() -> void:
	# 装备移动 Ability
	var move_ability := Ability.new(HexBattleSkillAbilities.MOVE_ABILITY, to_ref())
	ability_set.grant_ability(move_ability)
	_move_ability_id = move_ability.id
	
	# 装备职业对应的技能
	var skill_type := HexBattleSkillConfig.get_class_skill(character_class)
	var skill_config := HexBattleSkillAbilities.get_skill_ability(skill_type)
	var skill_ability := Ability.new(skill_config, to_ref())
	ability_set.grant_ability(skill_ability)
	_skill_ability_id = skill_ability.id
	
	# 装备职业被动技能
	_grant_class_passives()


## 根据职业装备被动技能
func _grant_class_passives() -> void:
	# 战士：荆棘反伤
	if character_class == HexBattleClassConfig.CharacterClass.WARRIOR:
		var thorn_passive := Ability.new(HexBattlePassiveAbilities.THORN_PASSIVE, to_ref())
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


# ========== 属性访问 ==========

func get_hp() -> float:
	return attributes.hp


func get_max_hp() -> float:
	return attributes.maxHp


func get_atk() -> float:
	return attributes.atk


func get_def() -> float:
	return attributes.def


func get_speed() -> float:
	return attributes.speed


func set_hp(value: float) -> void:
	attributes.setHpBase(value)


func modify_hp(delta: float) -> void:
	attributes._raw.modify_base("hp", delta)


## 获取当前属性快照
func get_stats() -> Dictionary:
	return {
		"hp": get_hp(),
		"max_hp": get_max_hp(),
		"atk": get_atk(),
		"def": get_def(),
		"speed": get_speed(),
	}


# ========== ATB 系统 ==========

## 获取 ATB 值
func get_atb_gauge() -> float:
	return _atb_gauge


## 累积 ATB（按速度）
func accumulate_atb(dt: float) -> void:
	var speed := get_speed()
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
	if get_hp() <= 0 and is_active():
		on_death()
		return true
	return false


# ========== 录像支持 ==========

## 获取配置 ID（用于回放）
func get_config_id() -> String:
	return HexBattleClassConfig.class_to_string(character_class)


## 获取属性快照
func get_attribute_snapshot() -> Dictionary:
	return get_stats()


## 获取 Ability 快照
func get_ability_snapshot() -> Array:
	var result := []
	for ability in ability_set.get_abilities():
		result.append({
			"instance_id": ability.id,
			"config_id": ability.config_id,
		})
	return result


## 获取 Tag 快照
func get_tag_snapshot() -> Dictionary:
	return ability_set.get_all_tags()


## 设置录像回调（BattleRecorder 调用）
func setupRecording(_ctx: Dictionary) -> Array:
	# 返回取消订阅的回调数组（目前不需要订阅任何事件）
	return []


# ========== BattleRecorder 兼容性属性 ==========
# BattleRecorder._capture_actor_init_data() 期望这些属性

## Actor ID（BattleRecorder 兼容）
var id: String:
	get:
		return get_id()

## 配置 ID（BattleRecorder 兼容）
var config_id: String:
	get:
		return get_config_id()

## 显示名称（BattleRecorder 兼容）
var display_name: String:
	get:
		return get_display_name()

## 队伍（BattleRecorder 兼容）
var team: int:
	get:
		return _team_id

## 位置（BattleRecorder 兼容 - 返回 hex 坐标作为伪 Vector3）
var position: Variant:
	get:
		if hex_position.is_empty():
			return null
		# 返回一个带有 x, y, z 属性的对象供 BattleRecorder 使用
		return Vector3(hex_position.get("q", 0), hex_position.get("r", 0), 0)


## 获取属性快照（camelCase 兼容）
func getAttributeSnapshot() -> Dictionary:
	return get_attribute_snapshot()


## 获取 Ability 快照（camelCase 兼容）
func getAbilitySnapshot() -> Array:
	return get_ability_snapshot()


## 获取 Tag 快照（camelCase 兼容）
func getTagSnapshot() -> Dictionary:
	return get_tag_snapshot()


# ========== EventProcessor 兼容性 ==========

## 转换为 EventProcessor 兼容的字典格式
func to_event_processor_dict() -> Dictionary:
	return {
		"isActive": is_active(),
		"abilitySet": ability_set,
		"id": get_id(),
		"team": get_team(),
	}


# ========== 序列化 ==========

func serialize() -> Dictionary:
	var base := serialize_base()
	base["character_class"] = HexBattleClassConfig.class_to_string(character_class)
	base["hex_position"] = hex_position.duplicate()
	base["atb_gauge"] = _atb_gauge
	base["attributes"] = attributes._raw.serialize()
	return base
