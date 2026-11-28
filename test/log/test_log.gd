extends GutTest

var box: IOCContainer
var scan_errors: PackedStringArray = PackedStringArray()


func before_each() -> void:
	box = IOCContainer.new()
	box.setup(get_tree())
	box.discover()
	scan_errors = PackedStringArray()
	for err in get_errors():
		if err.handled:
			continue
		var text := "%s %s" % [err.code, err.rationale]
		if text.find("Log:") != -1:
			scan_errors.append(text)
		err.handled = true


func after_each() -> void:
	if box != null:
		box.shutdown()
	box = null


func _has(fragment: String) -> bool:
	for line in scan_errors:
		if line.find(fragment) != -1:
			return true
	return false


func _memory() -> MemoryLogger:
	return box.resolve(MemoryLogger) as MemoryLogger


func test_logged_writes_debug_and_warn() -> void:
	var desk := box.resolve(LogDesk) as LogDesk
	var memory := _memory()
	assert_not_null(desk, "LogDesk resolves")
	assert_not_null(memory, "MemoryLogger resolves")
	memory.lines.clear()
	assert_eq(desk.ping(), "pong", "method return is kept")
	assert_eq(desk.hits, 1, "body ran")
	assert_true(memory.lines.size() >= 1, "logged a line")
	assert_true(String(memory.lines.back()).begins_with("debug:LogDesk.ping"), "debug level")
	memory.lines.clear()
	assert_eq(desk.warn_ping(), "careful", "warn method returns")
	assert_true(String(memory.lines.back()).begins_with("warn:LogDesk.warn_ping"), "warn level")


func test_timed_respects_threshold() -> void:
	var slow := box.resolve(LogSlow) as LogSlow
	var memory := _memory()
	assert_not_null(slow, "LogSlow resolves")
	memory.lines.clear()
	assert_eq(slow.always(), 1, "always returns")
	assert_true(memory.lines.size() >= 1, "threshold 0 always logs")
	assert_true(String(memory.lines.back()).find("took") != -1, "duration line")
	memory.lines.clear()
	assert_eq(slow.fast(), 2, "fast returns")
	assert_eq(memory.lines.size(), 0, "under threshold stays quiet")


func test_scan_rejects_bad_shapes() -> void:
	assert_true(_has("LogBadLevel.bad @Logged level must be"), "bad level")
	assert_true(_has("LogBadTimed.bad @Timed threshold must be >= 0"), "bad threshold")
