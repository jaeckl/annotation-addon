class_name PropNotify
extends RefCounted

## Records a property read while listening is on, and tells listeners when
## that property is assigned. The generated getter and setter call this.
static var armed := false
static var reads: Array = []
static var _listeners: Dictionary = {}


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


static func listen(owner: Object, property: StringName, callback: Callable) -> void:
	var key := _key(owner, property)
	var list: Array = _listeners.get(key, [])
	list.append(callback)
	_listeners[key] = list


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


static func _key(owner: Object, property: StringName) -> String:
	return "%s:%s" % [owner.get_instance_id(), String(property)]
