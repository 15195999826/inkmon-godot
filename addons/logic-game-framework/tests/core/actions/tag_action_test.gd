extends Node


## Mock Actor 实现 IAbilitySetOwner 协议
class DummyActor:
	extends RefCounted

	var _ability_set: AbilitySet

	func _init(set_value: AbilitySet):
		_ability_set = set_value

	func get_ability_set() -> AbilitySet:
		return _ability_set


class DummyState:
	extends RefCounted

	var _actor: DummyActor
	var logicTime: float = 100.0

	func _init(set_value: AbilitySet):
		_actor = DummyActor.new(set_value)

	func get_actor(_actor_id: String) -> DummyActor:
		return _actor


func _init() -> void:
	TestFramework.register_test("ApplyTagAction adds loose tag", _test_apply_loose)
	TestFramework.register_test("ApplyTagAction adds auto-duration tag", _test_apply_auto_duration)
	TestFramework.register_test("RemoveTagAction removes loose tag", _test_remove_tag)
	TestFramework.register_test("HasTagAction executes then/else", _test_has_tag_action)


func _build_context(state, event: Dictionary = {}) -> ExecutionContext:
	return ExecutionContext.create_execution_context({
		"eventChain": [event],
		"gameplayState": state,
		"eventCollector": GameWorld.event_collector,
		"ability": {},
	})


func _test_apply_loose() -> void:
	var owner := ActorRef.new("actor-1")
	var ability_set := AbilitySet.create(owner, null)
	var state := DummyState.new(ability_set)
	var ctx := _build_context(state, {"kind": "apply"})

	var action := TagAction.ApplyTagAction.new(
		TargetSelector.fixed([owner]),
		"combo",
		Resolvers.int_val(2)  # stacks
	)
	var result = action.execute(ctx)
	TestFramework.assert_true(result.success)
	TestFramework.assert_equal(2, ability_set.get_loose_tag_stacks("combo"))


func _test_apply_auto_duration() -> void:
	var owner := ActorRef.new("actor-2")
	var ability_set := AbilitySet.create(owner, null)
	var state := DummyState.new(ability_set)
	var ctx := _build_context(state, {"kind": "apply", "logicTime": 1.0})

	var action := TagAction.ApplyTagAction.new(
		TargetSelector.fixed([owner]),
		"window",
		Resolvers.int_val(1),    # stacks
		Resolvers.float_val(5.0)   # duration
	)
	var result = action.execute(ctx)
	TestFramework.assert_true(result.success)
	TestFramework.assert_equal(1, ability_set.get_tag_stacks("window"))
	ability_set.tick(6.0, 7.0)
	TestFramework.assert_equal(0, ability_set.get_tag_stacks("window"))


func _test_remove_tag() -> void:
	var owner := ActorRef.new("actor-3")
	var ability_set := AbilitySet.create(owner, null)
	var state := DummyState.new(ability_set)
	ability_set.add_loose_tag("charge", 3)
	var ctx := _build_context(state, {"kind": "remove"})

	var action := TagAction.RemoveTagAction.new(
		TargetSelector.fixed([owner]),
		"charge",
		Resolvers.int_val(1)  # stacks to remove
	)
	var result = action.execute(ctx)
	TestFramework.assert_true(result.success)
	TestFramework.assert_equal(2, ability_set.get_loose_tag_stacks("charge"))


func _test_has_tag_action() -> void:
	var owner := ActorRef.new("actor-4")
	var ability_set := AbilitySet.create(owner, null)
	var state := DummyState.new(ability_set)
	ability_set.add_loose_tag("ready", 1)
	var ctx := _build_context(state, {"kind": "check"})

	var selector := TargetSelector.fixed([owner])
	var then_action := Action.NoopAction.new(selector)
	var else_action := Action.NoopAction.new(selector)
	var action := TagAction.HasTagAction.new(
		selector,
		"ready",
		[then_action],
		[else_action]
	)
	var result = action.execute(ctx)
	TestFramework.assert_true(result.success)
	TestFramework.assert_equal(0, result.events.size())
