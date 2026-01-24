extends Node

func _init() -> void:
	TestFramework.register_test("ActivateInstanceComponent any trigger", _test_any_trigger)
	TestFramework.register_test("ActivateInstanceComponent all trigger", _test_all_trigger)

func _test_any_trigger() -> void:
	TimelineRegistry.reset()
	TimelineRegistry.register({
		"id": "t-any",
		"totalDuration": 1.0,
		"tags": {},
	})

	var owner := ActorRef.new("actor-1")
	var component_config := ActivateInstanceConfig.new(
		"t-any",
		{},
		[
			TriggerConfig.new("hit"),
			TriggerConfig.new("heal"),
		],
		"any"
	)
	var component := ActivateInstanceComponent.new(component_config)
	var ability_config := AbilityConfig.new(
		"test",
		"",
		"",
		"",
		[],
		[],
		[component]
	)
	var ability := Ability.new(ability_config, owner)
	var context := {
		"owner": owner,
		"ability": ability,
	}
	ability.apply_effects(context)

	var triggered := component.on_event({"kind": "hit"}, context, null)
	TestFramework.assert_true(triggered)
	TestFramework.assert_equal(1, ability.get_executing_instances().size())

func _test_all_trigger() -> void:
	TimelineRegistry.reset()
	TimelineRegistry.register({
		"id": "t-all",
		"totalDuration": 1.0,
		"tags": {},
	})

	var owner := ActorRef.new("actor-2")
	var component_config := ActivateInstanceConfig.new(
		"t-all",
		{},
		[
			TriggerConfig.new("hit"),
			TriggerConfig.new("heal"),
		],
		"all"
	)
	var component := ActivateInstanceComponent.new(component_config)
	var ability_config := AbilityConfig.new(
		"test",
		"",
		"",
		"",
		[],
		[],
		[component]
	)
	var ability := Ability.new(ability_config, owner)
	var context := {
		"owner": owner,
		"ability": ability,
	}
	ability.apply_effects(context)

	var triggered := component.on_event({"kind": "hit"}, context, null)
	TestFramework.assert_true(not triggered)
	TestFramework.assert_equal(0, ability.get_executing_instances().size())
