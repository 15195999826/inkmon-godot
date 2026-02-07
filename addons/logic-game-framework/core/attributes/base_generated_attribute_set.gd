class_name BaseGeneratedAttributeSet
extends RefCounted
## 生成的 AttributeSet 基类
##
## 所有由 AttributeSetGeneratorScript 生成的类都继承此基类。
## 提供统一的变化监听接口，供 RecordingUtils 使用。

## 底层属性集（子类在 _init 中通过 _raw.apply_config() 配置）
var _raw: RawAttributeSet


func _init() -> void:
	_raw = RawAttributeSet.new()


## 添加变化监听器
## @param listener 监听回调，接收 Dictionary 参数：{ attributeName, oldValue, newValue }
## @return 取消订阅函数
func add_change_listener(listener: Callable) -> Callable:
	_raw.add_change_listener(listener)
	return func() -> void:
		_raw.remove_change_listener(listener)


## 获取底层 RawAttributeSet（供高级用法）
func get_raw() -> RawAttributeSet:
	return _raw


## 设置 current 值变化前的回调（用于跨属性约束，如 hp ≤ max_hp）
## 签名: func(attr_name: String, inout_value: Dictionary) -> void
## inout_value = { "value": float }，可直接修改 inout_value["value"] 来调整最终值
##
## 示例：
##   attribute_set.set_pre_change(func(attr_name: String, inout_value: Dictionary) -> void:
##       if attr_name == "hp":
##           if inout_value["value"] > attribute_set.max_hp:
##               inout_value["value"] = attribute_set.max_hp
##   )
func set_pre_change(callback: Callable) -> void:
	_raw.set_pre_change(callback)
