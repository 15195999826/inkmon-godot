extends Node

const TestFramework = preload("res://tests/test_framework.gd")
const AttributeCalculator = preload("res://logic/attributes/AttributeCalculator.gd")
const AttributeModifier = preload("res://logic/attributes/AttributeModifier.gd")
const RawAttributeSet = preload("res://logic/attributes/AttributeSet.gd")

func _init() -> void:
	TestFramework.register_test("RawAttributeSet calculates modifiers", _test_calculations)
	TestFramework.register_test("RawAttributeSet clamps current value", _test_clamping)
	TestFramework.register_test("RawAttributeSet handles modifiers add/remove", _test_modifier_add_remove)

func _test_calculations() -> void:
	TestFramework.assert_near(100.0, AttributeCalculator.calculate_current_value(100.0, []))
	var mods := []
	mods.append(AttributeModifier.create_add_base_modifier("m1", "attack", 10.0))
	mods.append(AttributeModifier.create_mul_base_modifier("m2", "attack", 0.2))
	mods.append(AttributeModifier.create_add_final_modifier("m3", "attack", 5.0))
	mods.append(AttributeModifier.create_mul_final_modifier("m4", "attack", 0.5))

	var breakdown := AttributeCalculator.calculate_attribute(100.0, mods)
	TestFramework.assert_near(100.0, float(breakdown["base"]))
	TestFramework.assert_near(10.0, float(breakdown["addBaseSum"]))
	TestFramework.assert_near(1.2, float(breakdown["mulBaseProduct"]))
	TestFramework.assert_near(132.0, float(breakdown["bodyValue"]))
	TestFramework.assert_near(5.0, float(breakdown["addFinalSum"]))
	TestFramework.assert_near(1.5, float(breakdown["mulFinalProduct"]))
	TestFramework.assert_near(205.5, float(breakdown["currentValue"]))

func _test_clamping() -> void:
	var set := RawAttributeSet.new([
		{
			"name": "hp",
			"baseValue": 100.0,
			"minValue": 0.0,
			"maxValue": 150.0,
		},
	])
	set.set_base("hp", 200.0)
	TestFramework.assert_near(150.0, set.get_current_value("hp"))

func _test_modifier_add_remove() -> void:
	var set := RawAttributeSet.new([
		{
			"name": "attack",
			"baseValue": 50.0,
		},
	])
	var mod := AttributeModifier.create_add_base_modifier("buff", "attack", 10.0)
	set.add_modifier(mod)
	TestFramework.assert_near(60.0, set.get_current_value("attack"))
	TestFramework.assert_true(set.has_modifier("buff"))
	TestFramework.assert_true(set.remove_modifier("buff"))
	TestFramework.assert_near(50.0, set.get_current_value("attack"))
	TestFramework.assert_true(not set.has_modifier("buff"))
