extends Node

const TestFramework = preload("res://tests/test_framework.gd")
const AttributeFactory = preload("res://logic/attributes/defineAttributes.gd")
const AttributeModifier = preload("res://logic/attributes/AttributeModifier.gd")

func _init() -> void:
	TestFramework.register_test("AttributeFactory provides accessors", _test_accessors)
	TestFramework.register_test("AttributeFactory supports modifiers", _test_modifiers)
	TestFramework.register_test("AttributeFactory supports listeners", _test_listeners)
	TestFramework.register_test("AttributeFactory serialize/restore", _test_serialize_restore)

func _test_accessors() -> void:
	var attrs := AttributeFactory.define_attributes({
		"attack": { "baseValue": 10.0 },
		"speed": { "baseValue": 5.0 },
	})

	TestFramework.assert_near(10.0, attrs["attack"].call())
	TestFramework.assert_near(5.0, attrs["speed"].call())
	TestFramework.assert_equal("attack", attrs["attackAttribute"])
	TestFramework.assert_equal("speed", attrs["speedAttribute"])

	attrs["setAttackBase"].call(20.0)
	TestFramework.assert_near(20.0, attrs["attack"].call())

func _test_modifiers() -> void:
	var attrs := AttributeFactory.define_attributes({
		"attack": { "baseValue": 10.0 },
	})
	var modifier_target: Dictionary = attrs["_modifierTarget"]
	modifier_target["addModifier"].call(AttributeModifier.create_add_base_modifier("buff", "attack", 5.0))
	TestFramework.assert_near(15.0, attrs["attack"].call())
	TestFramework.assert_near(15.0, attrs["getCurrentValue"].call("attack"))

func _test_listeners() -> void:
	var attrs := AttributeFactory.define_attributes({
		"hp": { "baseValue": 100.0 },
	})
	var hit := false
	var unsubscribe: Callable = attrs["onHpChanged"].call(func(event: Dictionary) -> void:
		hit = true
		TestFramework.assert_near(100.0, float(event["oldValue"]))
		TestFramework.assert_near(90.0, float(event["newValue"]))
	)
	attrs["setHpBase"].call(90.0)
	TestFramework.assert_true(hit)
	unsubscribe.call()

func _test_serialize_restore() -> void:
	var attrs := AttributeFactory.define_attributes({
		"attack": { "baseValue": 10.0 },
	})
	var modifier_target: Dictionary = attrs["_modifierTarget"]
	modifier_target["addModifier"].call(AttributeModifier.create_add_base_modifier("buff", "attack", 5.0, "source"))

	var data: Dictionary = attrs["serialize"].call()
	var restored := AttributeFactory.restore_attributes(data)
	TestFramework.assert_near(15.0, restored["attack"].call())
