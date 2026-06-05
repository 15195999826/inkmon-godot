class_name InkMonEquipmentStatAbility
## 装备数值通用 ability (adr/0004 甲案): 穿戴瞬间拿 item 的 stat_mods **现场拼** StatModifierConfig,
## 塞进通用 ability shell, 经 StatModifierComponent 进**加成层** (AttributeModifier ADD_BASE), 不焊进 base;
## 脱下时按这条 ability 在加成层的 source (= ability.id) 精确移除。
##
## 数字归 item 数据 (lab canon, adr/0003), 本 ability 是 godot 纯机制、与具体数值无关 ——
## 不写死 godot 配置、不进契约、不 godot->server 上行。
##
## v1 只承载**基础属性数值** (adr/0004 决定 #5 的 channel ①)。**装备送技能**
## (channel ② = itemconfig.granted_abilities 指向预制 ability) 共用同一套 grant 生命周期, 留 future。
##
## 授予/移除生命周期由 InkMonUnitActor._refresh_equipment_abilities 编排 (装备变更 / 升级 / 读档 / 备战时
## 幂等重建); 见该方法注释与 adr/0004 落地状态。


const CONFIG_ID := "inkmon_equipment_stat"

## ability.metadata attribution key —— 让加成层 modifier (source = ability.id) 能溯源到具体 item。
## 对齐 hex HexActorEquipmentContainer 的 META_* 约定 (debug / breakdown introspect 用)。
const META_SOURCE := "source"
const META_ITEM_CONFIG_ID := "item_config_id"
const SOURCE_EQUIPMENT := "equipment"


## 从 item 的 stat_mods 现场构造一个携 StatModifierComponent 的通用装备 ability。
## stat_mods 为空 / 无有效项 → 返回 null (调用方跳过, 不 grant 空壳 ability)。
## value × count: 同一 item 实例 stack count 线性叠加 (对齐旧 base-fold 的 × count 语义)。
static func build_ability(stat_mods: Dictionary, owner_actor_id: String, item_config_id: String, count: int = 1) -> Ability:
	if stat_mods == null or stat_mods.is_empty():
		return null
	var stat_builder := StatModifierConfig.builder()
	var entries := 0
	var stack := float(maxi(count, 1))
	for attr in stat_mods.keys():
		stat_builder.modifier(str(attr), AttributeModifier.Type.ADD_BASE, float(stat_mods[attr]) * stack)
		entries += 1
	if entries == 0:
		return null

	var config := (
		AbilityConfig.builder()
		.config_id(CONFIG_ID)
		.display_name("InkMon Equipment")
		.description("Equipment stat_mods granted into the additive layer (adr/0004)")
		.ability_tags(["intrinsic", "inkmon_equipment"])
		.component_config(stat_builder.build())
		.build()
	)
	var ability := Ability.new(config, owner_actor_id)
	# 不 mutate 共享 config.metadata; runtime attribution 写在 duplicate 后的副本 (对齐 hex Phase G)。
	ability.metadata = ability.metadata.duplicate(true)
	ability.metadata[META_SOURCE] = SOURCE_EQUIPMENT
	ability.metadata[META_ITEM_CONFIG_ID] = item_config_id
	return ability
