extends SceneTree
## Runner de tests headless. Uso:
##   godot --headless --path . -s res://tests/run_tests.gd
## Sale con código 0 si todo pasa, 1 si algo falla.

const TEST_DIR: String = "res://tests/"
const TEST_FILE_PREFIX: String = "test_"
const TEST_METHOD_PREFIX: String = "test_"
const SCRIPT_EXTENSION: String = ".gd"


func _initialize() -> void:
	var total: int = 0
	var failed: int = 0
	var files: PackedStringArray = DirAccess.get_files_at(TEST_DIR)
	files.sort()
	for file: String in files:
		if not (file.begins_with(TEST_FILE_PREFIX) and file.ends_with(SCRIPT_EXTENSION)):
			continue
		var script: GDScript = load(TEST_DIR + file) as GDScript
		if script == null:
			printerr("[ERROR] no se pudo cargar %s" % file)
			failed += 1
			continue
		var suite: Object = script.new()
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with(TEST_METHOD_PREFIX):
				continue
			total += 1
			var before: int = (suite.call("get_failures") as PackedStringArray).size()
			suite.call("begin", "%s::%s" % [file, method_name])
			suite.call(method_name)
			var failures: PackedStringArray = suite.call("get_failures")
			if failures.size() > before:
				failed += 1
				for i: int in range(before, failures.size()):
					printerr("[FALLA] " + failures[i])
			else:
				print("[OK] %s::%s" % [file, method_name])
	print("\n%d tests, %d fallidos" % [total, failed])
	quit(1 if failed > 0 else 0)
