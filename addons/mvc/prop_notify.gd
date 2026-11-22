class_name PropNotify
extends RefCounted

## Records a property read while listening is on, and tells listeners when
## that property is assigned. The generated getter and setter call this.
## accept runs every PropertyAdvisor before the setter stores the value.
## Preparation is one advisor and validation is another. Both are skipped
## when that addon is absent. The lookup is by global class name, so this
## file still parses without those classes.
static var armed := false
static var reads: Array = []
static var _listeners: Dictionary = {}
static var _errors: Dictionary = {}
static var _stored: Dictionary = {}
static var _error_listeners: Dictionary = {}
static var _owner_listeners: Dictionary = {}
static var _busy: Dictionary = {}
static var _modules: Dictionary = {}
static var _modules_ready := false
static var _advisor_list: Array = []
static var _advisors_ready := false


static func read(owner: Object, property: StringName) -> void:
	if not armed or owner == null:
		return
	reads.append({"owner": owner, "property": property})


static func changed(owner: Object, property: StringName, value: Variant) -> void:
	reads.clear()
	armed = false
	if owner == null:
		return
	var list: Array = _listeners.get(_key(owner, property), [])
	for callback in list.duplicate():
		if callback is Callable and (callback as Callable).is_valid():
			(callback as Callable).call(value)


static func accept(owner: Object, property: StringName, value: Variant, current: Variant) -> Dictionary:
	if owner == null:
		return {"ok": true, "value": value}
	var key := _key(owner, property)
	if bool(_busy.get(key, false)):
		push_error("MVC: %s.%s is assigned while it is being checked." % [_type_name(owner), String(property)])
		return {"ok": false}
	_busy[key] = true
	var outcome := _check(owner, property, value, current)
	_busy.erase(key)
	return outcome


static func listen(owner: Object, property: StringName, callback: Callable) -> void:
	var key := _key(owner, property)
	var list: Array = _listeners.get(key, [])
	list.append(callback)
	_listeners[key] = list


static func listen_error(owner: Object, property: StringName, callback: Callable) -> void:
	if owner == null or not callback.is_valid():
		return
	var key := _key(owner, property)
	var list: Array = _error_listeners.get(key, [])
	list.append(callback)
	_error_listeners[key] = list
	callback.call(String(_errors.get(key, "")))


static func listen_owner(owner: Object, callback: Callable) -> void:
	if owner == null or not callback.is_valid():
		return
	var id := str(owner.get_instance_id())
	var list: Array = _owner_listeners.get(id, [])
	list.append(callback)
	_owner_listeners[id] = list
	var prefix := "%s:" % owner.get_instance_id()
	for key in _stored.keys():
		if not String(key).begins_with(prefix):
			continue
		var stored: Array = _stored[key]
		for violation in stored.duplicate():
			if violation != null and callback.is_valid():
				callback.call(violation)


static func arm() -> void:
	armed = true
	reads.clear()


static func take() -> Array:
	var found := reads.duplicate()
	reads.clear()
	armed = false
	return found


static func disarm() -> void:
	armed = false
	reads.clear()


static func clear() -> void:
	disarm()
	_listeners.clear()
	_errors.clear()
	_stored.clear()
	_error_listeners.clear()
	_owner_listeners.clear()
	_busy.clear()


static func _check(owner: Object, property: StringName, value: Variant, current: Variant) -> Dictionary:
	var next: Variant = value
	for step in _steps():
		var outcome := _apply_step(owner, property, next, current, step)
		if bool(outcome.get("stop", false)):
			return {"ok": false}
		next = outcome.get("value", next)
	var key := _key(owner, property)
	_errors.erase(key)
	_stored.erase(key)
	_tell_errors(owner, property, "")
	return {"ok": true, "value": next}


static func _apply_step(owner: Object, property: StringName, next: Variant, current: Variant, step: Object) -> Dictionary:
	var result: Variant = (step as PropertyAdvisor).advise(owner, property, next)
	if not (result is Dictionary):
		var broken := "MVC: %s.%s advisor %s returned no result." % [_type_name(owner), String(property), _advisor_name(step)]
		push_error(broken)
		_reject(owner, property, broken, current, _one(_violation(String(property), _advisor_name(step), broken, next)))
		return {"stop": true}
	var outcome: Dictionary = result
	if bool(outcome.get("ok", false)):
		return {"stop": false, "value": outcome.get("value", next)}
	var quiet := bool(outcome.get("quiet", false))
	var violations: Array = []
	var carried: Variant = outcome.get("violations")
	if carried is Array:
		violations = carried
	var message := String(outcome.get("message", ""))
	if violations.is_empty():
		var constraint := String(outcome.get("name", ""))
		if constraint.is_empty():
			constraint = _advisor_name(step)
		var rejected: Variant = outcome.get("value", next)
		violations = _one(_violation(String(property), constraint, message, rejected))
		if not quiet and not message.is_empty():
			push_error("MVC: %s.%s %s." % [_type_name(owner), String(property), message])
	elif not quiet:
		var parts := PackedStringArray()
		for violation in violations:
			if violation == null:
				continue
			var text := String(violation.get("message"))
			parts.append(text)
			push_error("MVC: %s.%s %s." % [_type_name(owner), String(property), text])
		message = "; ".join(parts)
	_reject(owner, property, message, current, violations)
	return {"stop": true}


static func _reject(owner: Object, property: StringName, message: String, current: Variant, violations: Array) -> void:
	var key := _key(owner, property)
	_errors[key] = message
	_stored[key] = violations
	_tell_errors(owner, property, message)
	for violation in violations:
		if violation != null:
			_tell_owner(owner, violation)
	changed(owner, property, current)


static func _one(violation: Object) -> Array:
	if violation == null:
		return []
	return [violation]


static func _tell_errors(owner: Object, property: StringName, message: String) -> void:
	var list: Array = _error_listeners.get(_key(owner, property), [])
	for callback in list.duplicate():
		if callback is Callable and (callback as Callable).is_valid():
			(callback as Callable).call(message)


static func _tell_owner(owner: Object, violation: Object) -> void:
	var list: Array = _owner_listeners.get(str(owner.get_instance_id()), [])
	for callback in list.duplicate():
		if callback is Callable and (callback as Callable).is_valid():
			(callback as Callable).call(violation)


static func _violation(member: String, constraint: String, message: String, rejected: Variant) -> Object:
	var script := _module("Violation")
	if script == null:
		return null
	return script.new(member, constraint, message, rejected)


static func _steps() -> Array:
	if _advisors_ready:
		return _advisor_list
	_advisors_ready = true
	_advisor_list.append(_PrepareStep.new())
	_advisor_list.append(_ValidateStep.new())
	var bases := {}
	var entries: Array = ProjectSettings.get_global_class_list()
	for entry in entries:
		bases[String(entry.get("class", ""))] = String(entry.get("base", ""))
	for entry in entries:
		var listed := String(entry.get("class", ""))
		if listed.is_empty() or listed == "PropertyAdvisor":
			continue
		if String(entry.get("language", "")) != "GDScript":
			continue
		if not _is_advisor(listed, bases):
			continue
		var script := load(String(entry.get("path", ""))) as GDScript
		if script == null:
			continue
		var advisor: Object = script.new()
		if advisor is PropertyAdvisor:
			_advisor_list.append(advisor)
	_advisor_list.sort_custom(func(a: Object, b: Object) -> bool: return _step_before(a, b))
	return _advisor_list


static func _is_advisor(listed: String, bases: Dictionary) -> bool:
	var seen := {}
	var current := String(bases.get(listed, ""))
	while not current.is_empty() and not seen.has(current):
		if current == "PropertyAdvisor":
			return true
		seen[current] = true
		current = String(bases.get(current, ""))
	return false


static func _step_before(a: Object, b: Object) -> bool:
	var left := int(a.get("order")) if a is PropertyAdvisor else 0
	var right := int(b.get("order")) if b is PropertyAdvisor else 0
	if left == right:
		return _advisor_name(a) < _advisor_name(b)
	return left < right


static func _advisor_name(step: Object) -> String:
	var script := step.get_script() as GDScript
	while script != null:
		var global_name := script.get_global_name()
		if global_name != &"":
			return String(global_name)
		script = script.get_base_script()
	return "PropertyAdvisor"


static func _module(global_name: String) -> GDScript:
	if not _modules_ready:
		_modules_ready = true
		for entry in ProjectSettings.get_global_class_list():
			var listed := String(entry.get("class", ""))
			if listed != "Preparer" and listed != "Validator" and listed != "Violation":
				continue
			if String(entry.get("language", "")) != "GDScript":
				continue
			_modules[listed] = load(String(entry.get("path", "")))
	return _modules.get(global_name) as GDScript


static func _type_name(owner: Object) -> String:
	var script := owner.get_script() as GDScript
	while script != null:
		var global_name := script.get_global_name()
		if global_name != &"":
			return String(global_name)
		script = script.get_base_script()
	return owner.get_class()


static func _key(owner: Object, property: StringName) -> String:
	return "%s:%s" % [owner.get_instance_id(), String(property)]


class _PrepareStep:
	extends PropertyAdvisor

	func _init() -> void:
		order = -100


	func advise(owner: Object, property: StringName, value: Variant) -> Dictionary:
		var preparer := PropNotify._module("Preparer")
		if preparer == null or owner == null:
			return {"ok": true, "value": value}
		var prepared: Variant = preparer.call(&"prepare_member", owner.get_script(), property, value)
		if prepared is Dictionary and bool((prepared as Dictionary).get("ok", false)):
			return {"ok": true, "value": (prepared as Dictionary).get("value", value)}
		var message := ""
		var prep_name := "Preparation"
		if prepared is Dictionary:
			message = String((prepared as Dictionary).get("message", ""))
			var listed := String((prepared as Dictionary).get("name", ""))
			if not listed.is_empty():
				prep_name = listed
		return {"ok": false, "message": message, "name": prep_name, "value": value, "quiet": true}


class _ValidateStep:
	extends PropertyAdvisor

	func _init() -> void:
		order = 100


	func advise(owner: Object, property: StringName, value: Variant) -> Dictionary:
		var validator := PropNotify._module("Validator")
		if validator == null or owner == null:
			return {"ok": true, "value": value}
		var found: Variant = validator.call(&"validate_member", owner.get_script(), property, value)
		if not (found is Array) or (found as Array).is_empty():
			return {"ok": true, "value": value}
		return {"ok": false, "value": value, "violations": found}
