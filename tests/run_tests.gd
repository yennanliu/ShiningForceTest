extends SceneTree
## Minimal headless test runner (no dependencies).
## Usage: tools/test.sh [filter] [--dir=core|e2e|view] [--filter=name]
## Finds every res://tests/**/test_*.gd, runs each test_* method,
## and counts engine/script errors raised during a test as failures.

var _errors := ErrorCounter.new()


class ErrorCounter extends Logger:
	var count := 0
	var last := ""

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		count += 1
		last = "%s:%d %s %s" % [file, line, code, rationale]

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	OS.add_logger(_errors)
	var filter := ""
	var dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
		elif arg.begins_with("--dir="):
			dir = arg.trim_prefix("--dir=")

	var files: Array[String] = []
	_collect("res://tests" if dir == "" else "res://tests/" + dir, files)
	files.sort()

	var passed := 0
	var failed := 0
	var t0 := Time.get_ticks_msec()
	for path in files:
		var script := load(path) as GDScript
		if script == null:
			print("FAIL  %s (could not load)" % path)
			failed += 1
			continue
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var id := "%s::%s" % [path.get_file().get_basename(), name]
			if filter != "" and not id.contains(filter):
				continue
			var inst: TestCase = script.new()
			var errors_before := _errors.count
			inst.before_each()
			inst.call(name)
			var problems := inst._failures.duplicate()
			if _errors.count > errors_before:
				problems.append("engine/script error: " + _errors.last)
			if problems.is_empty():
				passed += 1
			else:
				failed += 1
				print("FAIL  %s" % id)
				for p in problems:
					print("        %s" % p)

	print("\n%d passed, %d failed (%d ms)" % [passed, failed, Time.get_ticks_msec() - t0])
	OS.remove_logger(_errors)
	quit(1 if failed > 0 else 0)


func _collect(dir: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), out)
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir.path_join(f))
