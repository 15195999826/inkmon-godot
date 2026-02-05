extends Node

func _init() -> void:
	TestFramework.register_test("RawAttributeSet - should get base value", _test_get_base)
	TestFramework.register_test("RawAttributeSet - should set base value", _test_set_base)
	TestFramework.register_test("RawAttributeSet - should calculate with AddBase modifier", _test_add_base_modifier)
	TestFramework.register_test("RawAttributeSet - should calculate with MulBase modifier", _test_mul_base_modifier)
	TestFramework.register_test("RawAttributeSet - should calculate with AddFinal modifier", _test_add_final_modifier)
	TestFramework.register_test("RawAttributeSet - should calculate with MulFinal modifier", _test_mul_final_modifier)
	TestFramework.register_test("RawAttributeSet - should calculate full four-layer formula", _test_four_layer_formula)
	TestFramework.register_test("RawAttributeSet - should add modifier", _test_add_modifier)
	TestFramework.register_test("RawAttributeSet - should remove modifier", _test_remove_modifier)
	TestFramework.register_test("RawAttributeSet - should remove modifiers by source", _test_remove_by_source)
	TestFramework.register_test("RawAttributeSet - should notify base value changes", _test_base_change_notification)
	TestFramework.register_test("RawAttributeSet - should remove change listener", _test_remove_listener)
	TestFramework.register_test("RawAttributeSet - should clamp value to min constraint", _test_min_constraint)
	TestFramework.register_test("RawAttributeSet - should clamp value to max constraint", _test_max_constraint)

func _test_get_base() -> void:
	var attribute_set = RawAttributeSet.new([
		{"name": "hp", "baseValue": 100},
		{"name": "atk", "baseValue": 50},
		{"name": "def", "baseValue": 30},
	])
	TestFramework.assert_equal(100, attribute_set.get_base("hp"))
	TestFramework.assert_equal(50, attribute_set.get_base("atk"))

func _test_set_base() -> void:
	var attribute_set = RawAttributeSet.new([
		{"name": "hp", "baseValue": 100},
		{"name": "atk", "baseValue": 50},
		{"name": "def", "baseValue": 30},
	])
	attribute_set.set_base("hp", 120)
	TestFramework.assert_equal(120, attribute_set.get_base("hp"))

func _test_add_base_modifier() -> void:
	var attribute_set = RawAttributeSet.new([
		{"name": "hp", "baseValue": 100},
		{"name": "atk", "baseValue": 50},
		{"name": "def", "baseValue": 30},
	])
	# Base = 100, AddBase = +10
	# CurrentValue = ((100 + 10) × 1 + 0) × 1 = 110
	var mod = AttributeModifier.create_add_base_modifier("mod1", "hp", 10)
	attribute_set.add_modifier(mod)
	TestFramework.assert_near(110, attribute_set.get_current_value("hp"))
	TestFramework.assert_near(10, attribute_set.get_add_base_sum("hp"))

func _test_mul_base_modifier() -> void:
	var attribute_set = RawAttributeSet.new([
		{"name": "hp", "baseValue": 100},
		{"name": "atk", "baseValue": 50},
		{"name": "def", "baseValue": 30},
	])
	# Base = 100, MulBase = +20% (0.2)
	# CurrentValue = ((100 + 0) × 1.2 + 0) × 1 = 120
	var mod = AttributeModifier.create_mul_base_modifier("mod1", "hp", 0.2)
	attribute_set.add_modifier(mod)
	TestFramework.assert_near(120, attribute_set.get_current_value("hp"))
	TestFramework.assert_near(1.2, attribute_set.get_mul_base_product("hp"))

func _test_add_final_modifier() -> void:
	var attribute_set = RawAttributeSet.new([
		{"name": "hp", "baseValue": 100},
		{"name": "atk", "baseValue": 50},
		{"name": "def", "baseValue": 30},
	])
	# Base = 100, AddFinal = +50
	# CurrentValue = ((100 + 0) × 1 + 50) × 1 = 150
	var mod = AttributeModifier.create_add_final_modifier("mod1", "hp", 50)
	attribute_set.add_modifier(mod)
	TestFramework.assert_near(150, attribute_set.get_current_value("hp"))
	TestFramework.assert_near(50, attribute_set.get_add_final_sum("hp"))

func _test_mul_final_modifier() -> void:
	var attribute_set = RawAttributeSet.new([
		{"name": "hp", "baseValue": 100},
		{"name": "atk", "baseValue": 50},
		{"name": "def", "baseValue": 30},
	])
	# Base = 100, MulFinal = -30% (-0.3)
	# CurrentValue = ((100 + 0) × 1 + 0) × 0.7 = 70
	var mod = AttributeModifier.create_mul_final_modifier("mod1", "hp", -0.3)
	attribute_set.add_modifier(mod)
	TestFramework.assert_near(70, attribute_set.get_current_value("hp"))
	TestFramework.assert_near(0.7, attribute_set.get_mul_final_product("hp"))

func _test_four_layer_formula() -> void:
	var attribute_set = RawAttributeSet.new([
		{"name": "hp", "baseValue": 100},
		{"name": "atk", "baseValue": 50},
		{"name": "def", "baseValue": 30},
	])
	# Base = 100
	# AddBase = +10
	# MulBase = +20% (0.2)
	# AddFinal = +50
	# MulFinal = +10% (0.1)
	#
	# BodyValue = (100 + 10) × 1.2 = 132
	# CurrentValue = (132 + 50) × 1.1 = 200.2
	attribute_set.add_modifier(AttributeModifier.create_add_base_modifier("mod1", "hp", 10))
	attribute_set.add_modifier(AttributeModifier.create_mul_base_modifier("mod2", "hp", 0.2))
	attribute_set.add_modifier(AttributeModifier.create_add_final_modifier("mod3", "hp", 50))
	attribute_set.add_modifier(AttributeModifier.create_mul_final_modifier("mod4", "hp", 0.1))

	var breakdown = attribute_set.get_breakdown("hp")
	TestFramework.assert_equal(100, breakdown["base"])
	TestFramework.assert_near(10, breakdown["addBaseSum"])
	TestFramework.assert_near(1.2, breakdown["mulBaseProduct"])
	TestFramework.assert_near(132, breakdown["bodyValue"])
	TestFramework.assert_near(50, breakdown["addFinalSum"])
	TestFramework.assert_near(1.1, breakdown["mulFinalProduct"])
	TestFramework.assert_near(200.2, breakdown["currentValue"])

func _test_add_modifier() -> void:
	var attribute_set = RawAttributeSet.new([
		{"name": "hp", "baseValue": 100},
		{"name": "atk", "baseValue": 50},
		{"name": "def", "baseValue": 30},
	])
	var mod = AttributeModifier.create_add_base_modifier("mod1", "atk", 5)
	attribute_set.add_modifier(mod)
	TestFramework.assert_near(55, attribute_set.get_current_value("atk"))

func _test_remove_modifier() -> void:
	var attribute_set = RawAttributeSet.new([
		{"name": "hp", "baseValue": 100},
		{"name": "atk", "baseValue": 50},
		{"name": "def", "baseValue": 30},
	])
	var mod = AttributeModifier.create_add_base_modifier("mod1", "atk", 5)
	attribute_set.add_modifier(mod)
	attribute_set.remove_modifier("mod1")
	TestFramework.assert_near(50, attribute_set.get_current_value("atk"))

func _test_remove_by_source() -> void:
	var attribute_set = RawAttributeSet.new([
		{"name": "hp", "baseValue": 100},
		{"name": "atk", "baseValue": 50},
		{"name": "def", "baseValue": 30},
	])
	attribute_set.add_modifier(AttributeModifier.create_add_base_modifier("mod1", "hp", 10, "buff1"))
	attribute_set.add_modifier(AttributeModifier.create_add_base_modifier("mod2", "hp", 20, "buff1"))
	attribute_set.add_modifier(AttributeModifier.create_add_base_modifier("mod3", "hp", 15, "buff2"))
	attribute_set.remove_modifiers_by_source("buff1")
	TestFramework.assert_near(115, attribute_set.get_current_value("hp"))

func _test_base_change_notification() -> void:
	var attribute_set = RawAttributeSet.new([
		{"name": "hp", "baseValue": 100},
		{"name": "atk", "baseValue": 50},
		{"name": "def", "baseValue": 30},
	])
	var changes := []

	var listener = func(event):
		if event.get("attributeName") == "hp":
			changes.append(event)

	attribute_set.add_change_listener(listener)
	attribute_set.set_base("hp", 150)

	TestFramework.assert_equal(1, changes.size())
	TestFramework.assert_equal("hp", changes[0].get("attributeName"))
	TestFramework.assert_equal(100, changes[0].get("oldValue"))
	TestFramework.assert_equal(150, changes[0].get("newValue"))

func _test_remove_listener() -> void:
	var attribute_set = RawAttributeSet.new([
		{"name": "hp", "baseValue": 100},
		{"name": "atk", "baseValue": 50},
		{"name": "def", "baseValue": 30},
	])
	var changes := []

	var listener = func(event):
		if event.get("attributeName") == "hp":
			changes.append(event)

	attribute_set.add_change_listener(listener)
	attribute_set.remove_change_listener(listener)
	attribute_set.set_base("hp", 150)

	TestFramework.assert_equal(0, changes.size())

func _test_min_constraint() -> void:
	var constrained_set = RawAttributeSet.new([
		{"name": "hp", "baseValue": 100, "minValue": 10},
	])
	constrained_set.set_base("hp", 5)
	TestFramework.assert_equal(10, constrained_set.get_base("hp"))

func _test_max_constraint() -> void:
	var constrained_set = RawAttributeSet.new([
		{"name": "mp", "baseValue": 50, "maxValue": 100},
	])
	constrained_set.set_base("mp", 150)
	TestFramework.assert_equal(100, constrained_set.get_base("mp"))
