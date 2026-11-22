class_name PropNotify
extends RefCounted

## Records a property read while listening is on, and tells listeners when
## that property is assigned. The generated getter and setter call this.
## accept runs preparations and constraints for one field before the setter
## stores it. The lookup is by global class name, so this file still parses
## when those addons are absent.
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
	var preparer := _module("Preparer")
	if preparer != null:
		var prepared: Variant = preparer.call(&"prepare_member", owner.get_script(), property, next)
		if not (prepared is Dictionary) or not bool((prepared as Dictionary).get("ok", false)):
			var message := ""
			var prep_name := "Preparation"
			if prepared is Dictionary:
				message = String((prepared as Dictionary).get("message", ""))
				var listed := String((prepared as Dictionary).get("name", ""))
				if not listed.is_empty():
					prep_name = listed
			_reject(owner, property, message, current, _one(_violation(String(property), prep_name, message)))
			return {"ok": false}
		next = (prepared as Dictionary).get("value", next)
	var validator := _module("Validator")
	if validator != null:
		var found: Variant = validator.call(&"validate_member", owner.get_script(), property, next)
		if found is Array and not (found as Array).is_empty():
			var violations: Array = found
			var parts := PackedStringArray()
			for violation in violations:
				if violation == null:
					continue
				var text := String(violation.get("message"))
				parts.append(text)
				push_error("MVC: %s.%s %s." % [_type_name(owner), String(property), text])
			_reject(owner, property, "; ".join(parts), current, violations)
			return {"ok": false}
	var key := _key(owner, property)
	_errors.erase(key)
	_stored.erase(key)
	_tell_errors(owner, property, "")
	return {"ok": true, "value": next}


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


static func _violation(member: String, constraint: String, message: String) -> Object:
	var script := _module("Violation")
	if script == null:
		return null
	return script.new(member, constraint, message)


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
