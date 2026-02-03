extends RefCounted
class_name BaseGeneratedAttributeSet
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
