class_name TestCase
extends RefCounted
## Base class for tests. Any method named test_* is a test.
## Override before_each() for setup. Use the assert_* helpers.

var _failures: Array[String] = []


func before_each() -> void:
	pass


func fail(msg: String) -> void:
	_failures.append(msg)


func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		fail("expected true. %s" % msg)


func assert_false(cond: bool, msg := "") -> void:
	if cond:
		fail("expected false. %s" % msg)


func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if not _equal(actual, expected):
		fail("expected %s, got %s. %s" % [_s(expected), _s(actual), msg])


func assert_ne(actual: Variant, other: Variant, msg := "") -> void:
	if _equal(actual, other):
		fail("expected value != %s. %s" % [_s(other), msg])


func assert_near(actual: float, expected: float, eps: float, msg := "") -> void:
	if absf(actual - expected) > eps:
		fail("expected %s ± %s, got %s. %s" % [expected, eps, actual, msg])


func assert_between(actual: float, lo: float, hi: float, msg := "") -> void:
	if actual < lo or actual > hi:
		fail("expected %s in [%s, %s]. %s" % [actual, lo, hi, msg])


func _equal(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	var nums := [TYPE_INT, TYPE_FLOAT]
	if ta in nums and tb in nums:
		return is_equal_approx(float(a), float(b))
	if ta == TYPE_ARRAY and tb == TYPE_ARRAY:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _equal(a[i], b[i]):
				return false
		return true
	return ta == tb and a == b


func _s(v: Variant) -> String:
	return var_to_str(v).replace("\n", " ")
