extends RefCounted
class_name TestFramework

static var _tests: Array = []
static var _failures: int = 0

static func register_test(name: String, callback: Callable) -> void:
	_tests.append({
		"name": name,
		"callback": callback,
	})

static func run() -> int:
	_failures = 0
	for test in _tests:
		var name := str(test.get("name", ""))
		var callback: Callable = test.get("callback", Callable())
		if not callback.is_valid():
			push_error("Invalid test callback: %s" % name)
			_failures += 1
			continue
		print("[TEST] %s" % name)
		callback.call()
	return _failures

static func assert_true(condition: bool, message: String = "") -> bool:
	if condition:
		return true
	if message == "":
		message = "Expected condition to be true"
	push_error(message)
	_failures += 1
	return false

static func assert_equal(expected, actual, message: String = "") -> bool:
	if expected == actual:
		return true
	if message == "":
		message = "Expected %s, got %s" % [str(expected), str(actual)]
	push_error(message)
	_failures += 1
	return false

static func assert_near(expected: float, actual: float, epsilon: float = 0.0001, message: String = "") -> bool:
	if abs(expected - actual) <= epsilon:
		return true
	if message == "":
		message = "Expected %s, got %s" % [str(expected), str(actual)]
	push_error(message)
	_failures += 1
	return false
