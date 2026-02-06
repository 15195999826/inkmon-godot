## StatModifier 组件配置
##
## 定义属性修改器的配置数据，由 Ability._resolve_components() 解析为 StatModifierComponent 实例。
## 每个 Ability 实例独立创建 Component，避免共享状态污染。
##
## 推荐使用 Builder 模式构造：
## [codeblock]
## var config := StatModifierConfig.builder() \
##     .modifier("def", AttributeModifier.MODIFIER_TYPE_ADD_BASE, 10.0) \
##     .modifier("atk", AttributeModifier.MODIFIER_TYPE_MULTIPLY, 1.2) \
##     .build()
## [/codeblock]
class_name StatModifierConfig
extends RefCounted


## 修改器配置数组
## 每个元素为 Dictionary: { "attributeName": String, "modifierType": String, "value": float }
var modifier_configs: Array


func _init(configs: Array = []) -> void:
	modifier_configs = configs


## 创建 Builder
static func builder() -> StatModifierConfigBuilder:
	return StatModifierConfigBuilder.new()


## StatModifierConfig Builder
##
## 使用链式调用构建 StatModifierConfig，避免手写 Dictionary。
## 至少需要一个 modifier。
class StatModifierConfigBuilder:
	extends RefCounted

	var _configs: Array = []

	## 添加属性修改器
	## [br][param attribute_name] 属性名（如 "def", "atk", "hp"）
	## [br][param modifier_type] 修改器类型（使用 AttributeModifier 常量）
	## [br][param value] 修改值
	func modifier(attribute_name: String, modifier_type: String, value: float) -> StatModifierConfigBuilder:
		_configs.append({
			"attributeName": attribute_name,
			"modifierType": modifier_type,
			"value": value,
		})
		return self

	## 构建 StatModifierConfig
	## 验证至少有一个 modifier
	func build() -> StatModifierConfig:
		assert(_configs.size() > 0, "StatModifierConfig: at least one modifier is required")
		return StatModifierConfig.new(_configs)
