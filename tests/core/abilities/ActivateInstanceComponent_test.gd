extends Node

const TestFramework = preload("res://tests/test_framework.gd")
const ActivateInstanceComponent = preload("res://logic/abilities/ActivateInstanceComponent.gd")
const Ability = preload("res://logic/abilities/Ability.gd")
const TimelineRegistry = preload("res://logic/timeline/Timeline.gd")
const ActorRef = preload("res://logic/types/ActorRef.gd")

func _init() -> void:
	TestFramework.register_test("ActivateInstanceComponent any trigger", _test_any_trigger)
	TestFramework.register_test("ActivateInstanceComponent all trigger", _test_all_trigger)

func _test_any_trigger() -> void:
	var registry := TimelineRegistry.new()
	registry.register({
		"id": "t-any",
		"totalDuration": 1.0,
		"tags": {},
	})
	TimelineRegistry.set_timeline_registry(registry)

	var owner := ActorRef.new("actor-1")
	var component := ActivateInstanceComponent.new({
		"triggers": [
			ActivateInstanceComponent.create_event_trigger("hit"),
			ActivateInstanceComponent.create_event_trigger("heal"),
		],
		"triggerMode": "any",
		"timelineId": "t-any",
		"tagActions": {},
	})
	var ability := Ability.new({
		"configId": "test",
		"components": [func(): return component],
	}, owner)
	var context := {
		"owner": owner,
		"ability": ability,
	}
	ability.apply_effects(context)

	var triggered := component.on_event({"kind": "hit"}, context, null)
	TestFramework.assert_true(triggered)
	TestFramework.assert_equal(1, ability.get_executing_instances().size())

func _test_all_trigger() -> void:
	var registry := TimelineRegistry.new()
	registry.register({
		"id": "t-all",
		"totalDuration": 1.0,
		"tags": {},
	})
	TimelineRegistry.set_timeline_registry(registry)

	var owner := ActorRef.new("actor-2")
	var component := ActivateInstanceComponent.new({
		"triggers": [
			ActivateInstanceComponent.create_event_trigger("hit"),
			ActivateInstanceComponent.create_event_trigger("heal"),
		],
		"triggerMode": "all",
		"timelineId": "t-all",
		"tagActions": {},
	})
	var ability := Ability.new({
		"configId": "test",
		"components": [func(): return component],
	}, owner)
	var context := {
		"owner": owner,
		"ability": ability,
	}
	ability.apply_effects(context)

	var triggered := component.on_event({"kind": "hit"}, context, null)
	TestFramework.assert_true(not triggered)
	TestFramework.assert_equal(0, ability.get_executing_instances().size())
