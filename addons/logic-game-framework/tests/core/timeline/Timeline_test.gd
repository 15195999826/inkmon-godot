extends Node

func _init() -> void:
	TestFramework.register_test("TimelineRegistry registers and queries", _test_register)
	TestFramework.register_test("TimelineRegistry validates timelines", _test_validate)

func _test_register() -> void:
	var registry := TimelineRegistry.new()
	registry.register({ "id": "timeline-1", "totalDuration": 1.0, "tags": { "start": 0.0 } })
	TimelineRegistry.set_timeline_registry(registry)

	TestFramework.assert_true(registry.has("timeline-1"))
	TestFramework.assert_true(registry.get_timeline("timeline-1") != null)
	TestFramework.assert_equal(1, registry.get_all_ids().size())

	var tags := TimelineRegistry.get_sorted_tags(registry.get_timeline("timeline-1"))
	TestFramework.assert_equal(1, tags.size())
	TestFramework.assert_equal("start", tags[0]["name"])

func _test_validate() -> void:
	var errors := TimelineRegistry.validate_timeline({
		"id": "",
		"totalDuration": 0.0,
		"tags": { "late": 2.0, "neg": -1.0 },
	})
	TestFramework.assert_true(errors.size() >= 2)
