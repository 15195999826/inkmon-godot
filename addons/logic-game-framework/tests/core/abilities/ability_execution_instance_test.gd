extends Node

class TestAction:
	extends Action.BaseAction

	var calls: Array = []

	func _init() -> void:
		super._init()

	func execute(ctx: ExecutionContext) -> ActionResult:
		calls.append(ctx)
		return ActionResult.create_success_result([])

func _init() -> void:
	TestFramework.register_test("AbilityExecutionInstance triggers tags", _test_trigger_tags)
	TestFramework.register_test("AbilityExecutionInstance matches wildcard", _test_wildcard)
	TestFramework.register_test("AbilityExecutionInstance completes and cancels", _test_complete_cancel)

func _test_trigger_tags() -> void:
	TimelineRegistry.reset()
	TimelineRegistry.register({
		"id": "t-tags",
		"totalDuration": 1.0,
		"tags": {
			"start": 0.0,
			"impact": 0.5,
		},
	})
	GameWorld.init()

	var action := TestAction.new()
	var instance := AbilityExecutionInstance.new({
		"timelineId": "t-tags",
		"tagActions": {
			"start": [action],
			"impact": [action],
		},
		"eventChain": [],
		"gameplayState": null,
		"abilityInfo": {
			"id": "a1",
			"configId": "c1",
			"owner": null,
			"source": null,
		},
	})

	var triggered := instance.tick(0.0)
	TestFramework.assert_equal(1, triggered.size())
	TestFramework.assert_equal("start", triggered[0])
	TestFramework.assert_equal(1, action.calls.size())

	triggered = instance.tick(0.5)
	TestFramework.assert_equal(1, triggered.size())
	TestFramework.assert_equal("impact", triggered[0])
	TestFramework.assert_equal(2, action.calls.size())

func _test_wildcard() -> void:
	TimelineRegistry.reset()
	TimelineRegistry.register({
		"id": "t-wild",
		"totalDuration": 1.0,
		"tags": {
			"hit-1": 0.2,
		},
	})
	GameWorld.init()

	var action := TestAction.new()
	var instance := AbilityExecutionInstance.new({
		"timelineId": "t-wild",
		"tagActions": {
			"hit*": [action],
		},
		"eventChain": [],
		"gameplayState": null,
		"abilityInfo": {
			"id": "a2",
			"configId": "c2",
			"owner": null,
			"source": null,
		},
	})

	var triggered := instance.tick(0.2)
	TestFramework.assert_equal(1, triggered.size())
	TestFramework.assert_equal("hit-1", triggered[0])
	TestFramework.assert_equal(1, action.calls.size())

func _test_complete_cancel() -> void:
	TimelineRegistry.reset()
	TimelineRegistry.register({
		"id": "t-complete",
		"totalDuration": 0.1,
		"tags": {},
	})

	var instance := AbilityExecutionInstance.new({
		"timelineId": "t-complete",
		"tagActions": {},
		"eventChain": [],
		"gameplayState": null,
		"abilityInfo": {},
	})

	TestFramework.assert_true(instance.is_executing())
	instance.tick(0.1)
	TestFramework.assert_true(instance.is_completed())

	TimelineRegistry.reset()
	TimelineRegistry.register({
		"id": "t-cancel",
		"totalDuration": 1.0,
		"tags": {},
	})

	var cancelled := AbilityExecutionInstance.new({
		"timelineId": "t-cancel",
		"tagActions": {},
		"eventChain": [],
		"gameplayState": null,
		"abilityInfo": {},
	})
	cancelled.cancel()
	TestFramework.assert_true(cancelled.is_cancelled())
