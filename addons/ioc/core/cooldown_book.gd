class_name CooldownBook
extends RefCounted

## Tracks @Cooldown and @OncePer windows per instance method. The container
## registers this as an app product and ticks it from the frame driver.

var _idle_frame := 0
var _physics_frame := 0
## instance_id -> method_name -> window dictionary
var _windows: Dictionary = {}


func tick_idle(delta: float) -> void:
	_idle_frame += 1
	for id in _windows.keys():
		var methods: Dictionary = _windows[id]
		for method in methods.keys():
			var window: Dictionary = methods[method]
			if String(window.get("kind", "")) != "cooldown":
				continue
			var spec: ScheduleSpec = window.get("spec")
			if spec == null:
				continue
			if spec.kind == ScheduleSpec.TIME:
				var left := float(window.get("left", 0.0)) - delta
				window["left"] = left
			elif spec.kind == ScheduleSpec.FRAME:
				var frames := int(window.get("frames", 0)) - 1
				window["frames"] = frames


func tick_physics() -> void:
	_physics_frame += 1
	for id in _windows.keys():
		var methods: Dictionary = _windows[id]
		for method in methods.keys():
			var window: Dictionary = methods[method]
			if String(window.get("kind", "")) != "cooldown":
				continue
			var spec: ScheduleSpec = window.get("spec")
			if spec == null or spec.kind != ScheduleSpec.PHYSICS_FRAME:
				continue
			var frames := int(window.get("frames", 0)) - 1
			window["frames"] = frames


func cooldown_open(target: Object, method: StringName, spec: ScheduleSpec) -> bool:
	if target == null or spec == null or not spec.error.is_empty():
		return false
	var window := _window(target, method)
	if window.is_empty() or String(window.get("kind", "")) != "cooldown":
		return true
	var stored: ScheduleSpec = window.get("spec")
	if stored == null:
		return true
	if stored.kind == ScheduleSpec.TIME:
		return float(window.get("left", 0.0)) <= 0.0
	return int(window.get("frames", 0)) <= 0


func arm_cooldown(target: Object, method: StringName, spec: ScheduleSpec) -> void:
	if target == null or spec == null:
		return
	var window := {
		"kind": "cooldown",
		"spec": spec,
		"left": 0.0,
		"frames": 0,
	}
	if spec.kind == ScheduleSpec.TIME:
		window["left"] = spec.period
	else:
		window["frames"] = spec.frames
	_store(target, method, window)


func once_open(target: Object, method: StringName, physics: bool) -> bool:
	if target == null:
		return false
	var window := _window(target, method)
	if window.is_empty() or String(window.get("kind", "")) != "once":
		return true
	var stamp := _physics_frame if physics else _idle_frame
	return int(window.get("stamp", -1)) != stamp


func arm_once(target: Object, method: StringName, physics: bool) -> void:
	if target == null:
		return
	_store(target, method, {
		"kind": "once",
		"physics": physics,
		"stamp": _physics_frame if physics else _idle_frame,
	})


func forget(instance: Object) -> void:
	if instance == null:
		return
	_windows.erase(instance.get_instance_id())


func _window(target: Object, method: StringName) -> Dictionary:
	var methods: Variant = _windows.get(target.get_instance_id(), {})
	if not (methods is Dictionary):
		return {}
	var window: Variant = (methods as Dictionary).get(method, {})
	return window if window is Dictionary else {}


func _store(target: Object, method: StringName, window: Dictionary) -> void:
	var id := target.get_instance_id()
	var methods: Dictionary = _windows.get(id, {})
	methods[method] = window
	_windows[id] = methods
