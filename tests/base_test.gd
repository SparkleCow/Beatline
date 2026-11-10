extends RefCounted
## Base mínima para tests (sin plugins externos). Cada método `test_*` de una subclase
## es un caso. tests/run_tests.gd los descubre y ejecuta.

var _failures: PackedStringArray = PackedStringArray()
var _current: String = ""


func begin(test_name: String) -> void:
	_current = test_name


func get_failures() -> PackedStringArray:
	return _failures


func fail(message: String) -> void:
	_failures.append("%s: %s" % [_current, message])


func assert_true(condition: bool, message: String = "se esperaba true") -> void:
	if not condition:
		fail(message)


func assert_false(condition: bool, message: String = "se esperaba false") -> void:
	if condition:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		fail("%s (obtenido: %s, esperado: %s)" % [message, str(actual), str(expected)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if actual == unexpected:
		fail("%s (no debía ser: %s)" % [message, str(unexpected)])


func assert_almost(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		fail("%s (obtenido: %f, esperado: %f ± %f)" % [message, actual, expected, tolerance])
