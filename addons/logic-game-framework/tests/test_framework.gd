extends RefCounted
class_name TestFramework

static var _tests: Array = []
static var _failures: int = 0

static func register_test(name: String, callback: Callable) -> void:
	_tests.append({ "name": name, "callback": callback })

static func run() -> int:
	_failures = 0
	print("[TEST] Running %d tests" % _tests.size())
	for test in _tests:
		_run_single_test(test)
	print("[TEST] Done. Failures: %d" % _failures)
	return _failures

static func assert_true(condition: bool, message: String = "") -> bool:
	if condition:
		return true
	return _fail(message if message else "Expected condition to be true")

static func assert_equal(expected, actual, message: String = "") -> bool:
	if expected == actual:
		return true
	return _fail(message if message else "Expected %s, got %s" % [str(expected), str(actual)])

static func assert_near(expected: float, actual: float, epsilon: float = 0.0001, message: String = "") -> bool:
	if abs(expected - actual) <= epsilon:
		return true
	return _fail(message if message else "Expected %s, got %s" % [str(expected), str(actual)])

static func _run_single_test(test: Dictionary) -> void:
	var name := str(test.get("name", ""))
	var callback: Callable = test.get("callback", Callable())
	if not callback.is_valid():
		push_error("Invalid test callback: %s" % name)
		_failures += 1
		print("[FAIL] %s (invalid callback)" % name)
		return
	print("[TEST] %s" % name)
	var failures_before := _failures
	callback.call()
	print("[PASS] %s" % name if _failures == failures_before else "[FAIL] %s" % name)

static func _fail(message: String) -> bool:
	push_error(message)
	_failures += 1
	return false
