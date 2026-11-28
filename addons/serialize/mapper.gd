class_name Mapper
extends RefCounted

## Builds a document from @Serialize / @Transient and asks the codec for bytes.
## Math leaves: Vector2/3/4 (+i), Rect2(+i), AABB, Plane, Quaternion, Basis,
## Transform2D/3D, Color, NodePath, StringName, and Packed* arrays. A cycle is
## a push_error and write returns no bytes. A shared reference is written twice.
## make_instance may supply nested objects (for example a pooled borrow).
## @OnBeforeSerialization / @OnAfterSerialization bracket a write.
## @OnBeforeDeserialization / @OnAfterDeserialization bracket a read.
## @Required fails when a key is missing on read; @Optional (default) leaves it.
## @ReadOnly writes but does not fill; @WriteOnly fills but does not write.

const _LEAF_NAMES := {
	"Vector2": true, "Vector2i": true, "Vector3": true, "Vector3i": true,
	"Vector4": true, "Vector4i": true, "Color": true, "Rect2": true, "Rect2i": true,
	"AABB": true, "Plane": true, "Quaternion": true, "Basis": true,
	"Transform2D": true, "Transform3D": true, "NodePath": true, "StringName": true,
	"PackedByteArray": true, "PackedInt32Array": true, "PackedInt64Array": true,
	"PackedFloat32Array": true, "PackedFloat64Array": true, "PackedStringArray": true,
	"PackedVector2Array": true, "PackedVector3Array": true, "PackedVector4Array": true,
	"PackedColorArray": true,
}

var codec: Codec
## Optional Callable(script: GDScript) -> Object. Return null to use script.new().
var make_instance: Callable
var _failed := false
var _plans: Dictionary = {}
var _plan_bad: Dictionary = {}
var _class_mode_cache: Dictionary = {}
var _mark_seen: Dictionary = {}
var _mark_bad: Dictionary = {}
var _plan_reported: Dictionary = {}
var _empty_reported: Dictionary = {}
var _scripts: Dictionary = {}
static var _advisors_ready := false
static var _advisor_list: Array = []


func write(instance: Object) -> PackedByteArray:
	_failed = false
	if codec == null:
		_error("Serialize: write needs a codec.")
		return PackedByteArray()
	if instance == null:
		_error("Serialize: write needs an object.")
		return PackedByteArray()
	var document := _write_object(instance, {}, false)
	if _failed or document.is_empty():
		return PackedByteArray()
	return codec.write(document)


func read(expected: GDScript, bytes: PackedByteArray) -> Object:
	_failed = false
	if codec == null:
		_error("Serialize: read needs a codec.")
		return null
	if expected == null:
		_error("Serialize: read needs a class.")
		return null
	var document := _document(bytes)
	if document.is_empty():
		return null
	var instance := _read_object(document)
	if _failed or instance == null:
		return null
	var actual := instance.get_script() as GDScript
	if not _script_accepts(actual, expected):
		_error("Serialize: %s is not a %s." % [_script_name(actual), _script_name(expected)])
		return null
	return instance


## True when the bytes decode as a document of the expected class. Used to
## reject a bad save before ending a run. A temporary instance may be built.
func readable(expected: GDScript, bytes: PackedByteArray) -> bool:
	var instance := read(expected, bytes)
	if instance == null:
		return false
	if instance is Node and is_instance_valid(instance):
		(instance as Node).free()
	return true


## Fills an existing instance from bytes. The root is not reconstructed.
## Nested objects still use make_instance or script.new().
func read_into(instance: Object, bytes: PackedByteArray) -> bool:
	_failed = false
	if codec == null:
		_error("Serialize: read needs a codec.")
		return false
	if instance == null:
		_error("Serialize: read_into needs an object.")
		return false
	var document := _document(bytes)
	if document.is_empty():
		return false
	var type_name := String(document.get("_type", ""))
	var script := _script_by_name(type_name)
	if script == null:
		_error("Serialize: %s is not a class." % type_name)
		return false
	var actual := instance.get_script() as GDScript
	if not _script_accepts(actual, script):
		_error("Serialize: %s is not a %s." % [_script_name(actual), type_name])
		return false
	return _fill_object(instance, document, script)


func _document(bytes: PackedByteArray) -> Dictionary:
	var document: Variant = codec.read(bytes)
	if typeof(document) != TYPE_DICTIONARY or not (document as Dictionary).has("_type"):
		if typeof(document) != TYPE_DICTIONARY or (document as Dictionary).is_empty():
			return {}
		_error("Serialize: the bytes are not a document.")
		return {}
	return document as Dictionary


func _write_object(instance: Object, stack: Dictionary, force_all: bool) -> Dictionary:
	if instance == null or instance.get_script() == null:
		_error("Serialize: %s has no script." % (instance.get_class() if instance != null else "null"))
		return {}
	var script := instance.get_script() as GDScript
	if String(script.get_global_name()).is_empty():
		_error("Serialize: %s needs a class_name." % _script_name(script))
		return {}
	var id := instance.get_instance_id()
	if stack.has(id):
		_error("Serialize: %s contains a cycle." % _script_name(script))
		return {}
	stack[id] = true
	var plan := _plan(script, force_all)
	if _failed or plan.is_empty():
		stack.erase(id)
		return {}
	var fields: Array = plan["fields"]
	if fields.is_empty():
		var empty_key := script.get_instance_id()
		if _empty_reported.has(empty_key):
			_failed = true
		else:
			_empty_reported[empty_key] = true
			_error("Serialize: %s is not a document." % _script_name(script))
		stack.erase(id)
		return {}
	_run_hooks(instance, plan["before_write"])
	if _failed:
		stack.erase(id)
		return {}
	var nested_force := force_all or _class_mode(script)
	var document := {"_type": String(script.get_global_name())}
	for field in fields:
		if bool(field.get("write_only", false)):
			continue
		var prop_name := String(field["name"])
		var advised: Variant = _advise_field(instance, StringName(prop_name), instance.get(prop_name))
		if _failed:
			stack.erase(id)
			return {}
		document[String(field["key"])] = _write_value(advised, stack, nested_force)
		if _failed:
			stack.erase(id)
			return {}
	_run_hooks(instance, plan["after_write"])
	if _failed:
		stack.erase(id)
		return {}
	stack.erase(id)
	return document


func _write_value(value: Variant, stack: Dictionary, force_all: bool) -> Variant:
	if _failed:
		return null
	if value == null:
		return null
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_VECTOR2:
			return {"_type": "Vector2", "x": value.x, "y": value.y}
		TYPE_VECTOR2I:
			return {"_type": "Vector2i", "x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"_type": "Vector3", "x": value.x, "y": value.y, "z": value.z}
		TYPE_VECTOR3I:
			return {"_type": "Vector3i", "x": value.x, "y": value.y, "z": value.z}
		TYPE_VECTOR4:
			return {"_type": "Vector4", "x": value.x, "y": value.y, "z": value.z, "w": value.w}
		TYPE_VECTOR4I:
			return {"_type": "Vector4i", "x": value.x, "y": value.y, "z": value.z, "w": value.w}
		TYPE_COLOR:
			return {"_type": "Color", "r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_RECT2:
			return {
				"_type": "Rect2",
				"position": _write_value(value.position, stack, force_all),
				"size": _write_value(value.size, stack, force_all),
			}
		TYPE_RECT2I:
			return {
				"_type": "Rect2i",
				"position": _write_value(value.position, stack, force_all),
				"size": _write_value(value.size, stack, force_all),
			}
		TYPE_AABB:
			return {
				"_type": "AABB",
				"position": _write_value(value.position, stack, force_all),
				"size": _write_value(value.size, stack, force_all),
			}
		TYPE_PLANE:
			return {
				"_type": "Plane",
				"normal": _write_value(value.normal, stack, force_all),
				"d": value.d,
			}
		TYPE_QUATERNION:
			return {"_type": "Quaternion", "x": value.x, "y": value.y, "z": value.z, "w": value.w}
		TYPE_BASIS:
			return {
				"_type": "Basis",
				"x": _write_value(value.x, stack, force_all),
				"y": _write_value(value.y, stack, force_all),
				"z": _write_value(value.z, stack, force_all),
			}
		TYPE_TRANSFORM2D:
			return {
				"_type": "Transform2D",
				"x": _write_value(value.x, stack, force_all),
				"y": _write_value(value.y, stack, force_all),
				"origin": _write_value(value.origin, stack, force_all),
			}
		TYPE_TRANSFORM3D:
			return {
				"_type": "Transform3D",
				"basis": _write_value(value.basis, stack, force_all),
				"origin": _write_value(value.origin, stack, force_all),
			}
		TYPE_NODE_PATH:
			return {"_type": "NodePath", "path": String(value)}
		TYPE_STRING_NAME:
			return {"_type": "StringName", "name": String(value)}
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, \
		TYPE_PACKED_VECTOR4_ARRAY:
			return _write_packed(value, stack, force_all)
		TYPE_ARRAY:
			var items: Array = []
			for item in value:
				items.append(_write_value(item, stack, force_all))
				if _failed:
					return null
			return items
		TYPE_DICTIONARY:
			var mapped := {}
			for key in value:
				var key_type := typeof(key)
				if key_type != TYPE_STRING and key_type != TYPE_STRING_NAME:
					_error("Serialize: a dictionary key must be a string.")
					return null
				var key_text := String(key)
				if key_text == "_type":
					_error("Serialize: a dictionary key cannot be _type.")
					return null
				mapped[key_text] = _write_value(value[key], stack, force_all)
				if _failed:
					return null
			return mapped
		TYPE_OBJECT:
			return _write_object(value, stack, force_all)
		_:
			_error("Serialize: %s is not a document value." % type_string(typeof(value)))
			return null


func _write_packed(value: Variant, stack: Dictionary, force_all: bool) -> Variant:
	var label := type_string(typeof(value))
	var items: Array = []
	for item in value:
		items.append(_write_value(item, stack, force_all))
		if _failed:
			return null
	return {"_type": label, "items": items}


func _read_object(document: Dictionary) -> Object:
	var type_name := String(document.get("_type", ""))
	if _is_value_type(type_name):
		_error("Serialize: %s is not a class." % type_name)
		return null
	var script := _script_by_name(type_name)
	if script == null:
		_error("Serialize: %s is not a class." % type_name)
		return null
	var instance := _construct(script)
	if instance == null:
		_error("Serialize: %s could not be constructed." % type_name)
		return null
	if not _fill_object(instance, document, script):
		if instance is Node and is_instance_valid(instance):
			(instance as Node).free()
		return null
	return instance


func _construct(script: GDScript) -> Object:
	if not make_instance.is_valid():
		return script.new()
	# When set, the callable builds every nested object. null is a failure.
	var made: Variant = make_instance.call(script)
	if made is Object:
		return made as Object
	_failed = true
	return null


func _fill_object(instance: Object, document: Dictionary, script: GDScript) -> bool:
	var type_name := String(script.get_global_name())
	if type_name.is_empty():
		type_name = String(document.get("_type", ""))
	var plan := _plan(script, true)
	if _failed or plan.is_empty():
		return false
	_run_hooks(instance, plan["before_read"])
	if _failed:
		return false
	var by_key := {}
	for field in plan["fields"]:
		by_key[String(field["key"])] = field
		if bool(field.get("required", false)) and not document.has(String(field["key"])):
			_error("Serialize: %s.%s is required." % [type_name, String(field["key"])])
			return false
	var transient: Dictionary = plan["transient"]
	for key in document:
		var key_text := String(key)
		if key_text == "_type":
			continue
		if transient.has(key_text):
			_error("Serialize: %s.%s is transient." % [type_name, key_text])
			return false
		if not by_key.has(key_text):
			_error("Serialize: %s has no field %s." % [type_name, key_text])
			return false
		var field: Dictionary = by_key[key_text]
		if bool(field.get("read_only", false)):
			continue
		var decoded: Variant = _read_value(document[key])
		if _failed:
			return false
		var coerced: Variant = _coerce(int(field["type"]), decoded)
		if _failed:
			return false
		var prop_name := String(field["name"])
		var advised: Variant = _advise_field(instance, StringName(prop_name), coerced)
		if _failed:
			return false
		instance.set(prop_name, advised)
	if _failed:
		return false
	_run_hooks(instance, plan["after_read"])
	return not _failed


func _read_value(value: Variant) -> Variant:
	if _failed:
		return null
	if value == null:
		return null
	var kind := typeof(value)
	if kind == TYPE_ARRAY:
		var items: Array = []
		for item in value:
			items.append(_read_value(item))
			if _failed:
				return null
		return items
	if kind != TYPE_DICTIONARY:
		return value
	if not value.has("_type"):
		var mapped := {}
		for key in value:
			mapped[key] = _read_value(value[key])
			if _failed:
				return null
		return mapped
	var type_name := String(value["_type"])
	if _LEAF_NAMES.has(type_name):
		return _read_leaf(type_name, value)
	return _read_object(value)


func _read_leaf(type_name: String, value: Dictionary) -> Variant:
	match type_name:
		"Vector2":
			return Vector2(_number(value, "x"), _number(value, "y"))
		"Vector2i":
			return Vector2i(_int(value, "x"), _int(value, "y"))
		"Vector3":
			return Vector3(_number(value, "x"), _number(value, "y"), _number(value, "z"))
		"Vector3i":
			return Vector3i(_int(value, "x"), _int(value, "y"), _int(value, "z"))
		"Vector4":
			return Vector4(_number(value, "x"), _number(value, "y"), _number(value, "z"), _number(value, "w"))
		"Vector4i":
			return Vector4i(_int(value, "x"), _int(value, "y"), _int(value, "z"), _int(value, "w"))
		"Color":
			return Color(_number(value, "r"), _number(value, "g"), _number(value, "b"), _number(value, "a"))
		"Rect2":
			return Rect2(_vector2_field(value, "position"), _vector2_field(value, "size"))
		"Rect2i":
			return Rect2i(_vector2i_field(value, "position"), _vector2i_field(value, "size"))
		"AABB":
			return AABB(_vector3_field(value, "position"), _vector3_field(value, "size"))
		"Plane":
			return Plane(_vector3_field(value, "normal"), _number(value, "d"))
		"Quaternion":
			return Quaternion(_number(value, "x"), _number(value, "y"), _number(value, "z"), _number(value, "w"))
		"Basis":
			return Basis(_vector3_field(value, "x"), _vector3_field(value, "y"), _vector3_field(value, "z"))
		"Transform2D":
			return Transform2D(_vector2_field(value, "x"), _vector2_field(value, "y"), _vector2_field(value, "origin"))
		"Transform3D":
			return Transform3D(_basis_field(value, "basis"), _vector3_field(value, "origin"))
		"NodePath":
			if not value.has("path") or typeof(value["path"]) != TYPE_STRING:
				_error("Serialize: NodePath needs path.")
				return NodePath()
			return NodePath(String(value["path"]))
		"StringName":
			if not value.has("name") or typeof(value["name"]) != TYPE_STRING:
				_error("Serialize: StringName needs name.")
				return StringName()
			return StringName(String(value["name"]))
		"PackedByteArray", "PackedInt32Array", "PackedInt64Array", "PackedFloat32Array", \
		"PackedFloat64Array", "PackedStringArray", "PackedVector2Array", "PackedVector3Array", \
		"PackedVector4Array", "PackedColorArray":
			return _read_packed(type_name, value)
		_:
			return null


func _read_packed(type_name: String, value: Dictionary) -> Variant:
	if not value.has("items") or typeof(value["items"]) != TYPE_ARRAY:
		_error("Serialize: %s needs items." % type_name)
		return null
	var decoded: Array = []
	for item in value["items"]:
		decoded.append(_read_value(item))
		if _failed:
			return null
	match type_name:
		"PackedByteArray":
			return PackedByteArray(decoded)
		"PackedInt32Array":
			return PackedInt32Array(decoded)
		"PackedInt64Array":
			return PackedInt64Array(decoded)
		"PackedFloat32Array":
			return PackedFloat32Array(decoded)
		"PackedFloat64Array":
			return PackedFloat64Array(decoded)
		"PackedStringArray":
			return PackedStringArray(decoded)
		"PackedVector2Array":
			return PackedVector2Array(decoded)
		"PackedVector3Array":
			return PackedVector3Array(decoded)
		"PackedVector4Array":
			return PackedVector4Array(decoded)
		"PackedColorArray":
			return PackedColorArray(decoded)
		_:
			_error("Serialize: %s is not a packed array." % type_name)
			return null


func _number(value: Dictionary, key: String) -> float:
	if not value.has(key):
		_error("Serialize: %s needs %s." % [String(value.get("_type", "")), key])
		return 0.0
	var number: Variant = value[key]
	var kind := typeof(number)
	if kind != TYPE_INT and kind != TYPE_FLOAT:
		_error("Serialize: %s.%s is not a number." % [String(value.get("_type", "")), key])
		return 0.0
	return float(number)


func _int(value: Dictionary, key: String) -> int:
	return int(_number(value, key))


func _vector2_field(value: Dictionary, key: String) -> Vector2:
	var found: Variant = _nested_leaf(value, key, "Vector2")
	return found as Vector2 if found is Vector2 else Vector2.ZERO


func _vector2i_field(value: Dictionary, key: String) -> Vector2i:
	var found: Variant = _nested_leaf(value, key, "Vector2i")
	return found as Vector2i if found is Vector2i else Vector2i.ZERO


func _vector3_field(value: Dictionary, key: String) -> Vector3:
	var found: Variant = _nested_leaf(value, key, "Vector3")
	return found as Vector3 if found is Vector3 else Vector3.ZERO


func _basis_field(value: Dictionary, key: String) -> Basis:
	var found: Variant = _nested_leaf(value, key, "Basis")
	return found as Basis if found is Basis else Basis.IDENTITY


func _nested_leaf(value: Dictionary, key: String, expected: String) -> Variant:
	if not value.has(key):
		_error("Serialize: %s needs %s." % [String(value.get("_type", "")), key])
		return null
	var decoded: Variant = _read_value(value[key])
	if _failed:
		return null
	if typeof(decoded) != _leaf_typeof(expected):
		_error("Serialize: %s.%s needs %s." % [String(value.get("_type", "")), key, expected])
		return null
	return decoded


func _leaf_typeof(type_name: String) -> int:
	match type_name:
		"Vector2":
			return TYPE_VECTOR2
		"Vector2i":
			return TYPE_VECTOR2I
		"Vector3":
			return TYPE_VECTOR3
		"Basis":
			return TYPE_BASIS
		_:
			return TYPE_NIL


func _coerce(field_type: int, value: Variant) -> Variant:
	if _failed:
		return null
	if value == null:
		if field_type == TYPE_NIL or field_type == TYPE_OBJECT:
			return null
		_error("Serialize: null cannot fill %s." % type_string(field_type))
		return null
	var got := typeof(value)
	if field_type == TYPE_NIL or field_type == got:
		return value
	if field_type == TYPE_FLOAT and got == TYPE_INT:
		return float(value)
	if field_type == TYPE_INT and got == TYPE_FLOAT and float(value) == float(int(value)):
		return int(value)
	_error("Serialize: expected %s and found %s." % [type_string(field_type), type_string(got)])
	return null


func _plan(script: GDScript, force_all: bool) -> Dictionary:
	var cache_key := "%s:%s" % [script.get_instance_id(), force_all]
	if _plans.has(cache_key):
		return _plans[cache_key]
	if _plan_bad.has(cache_key):
		_failed = true
		return {}
	var fields: Array = []
	var transient := {}
	var seen_names := {}
	var seen_keys := {}
	var mode := force_all or _class_mode(script)
	var current := script
	var bad := false
	while current != null and not bad:
		_check_marks(current)
		if _failed:
			bad = true
			break
		for info in _own_properties(current):
			var prop_name := String(info.get("name", ""))
			if prop_name.is_empty() or seen_names.has(prop_name):
				continue
			seen_names[prop_name] = true
			var marked: Variant = AnnotationUtils.get_annotation_initialized(current, Serialize, prop_name)
			var has_mark := marked is Object
			var is_transient := AnnotationUtils.has_annotation(current, Transient, prop_name)
			var is_required := AnnotationUtils.has_annotation(current, Required, prop_name)
			var is_optional := AnnotationUtils.has_annotation(current, Optional, prop_name)
			var is_read_only := AnnotationUtils.has_annotation(current, ReadOnly, prop_name)
			var is_write_only := AnnotationUtils.has_annotation(current, WriteOnly, prop_name)
			if has_mark and is_transient:
				_plan_error(current, "Serialize: %s.%s is @Serialize and @Transient." % [_script_name(current), prop_name])
				bad = true
				break
			if is_required and is_optional:
				_plan_error(current, "Serialize: %s.%s is @Required and @Optional." % [_script_name(current), prop_name])
				bad = true
				break
			if is_read_only and is_write_only:
				_plan_error(current, "Serialize: %s.%s is @ReadOnly and @WriteOnly." % [_script_name(current), prop_name])
				bad = true
				break
			if is_transient and (is_required or is_optional or is_read_only or is_write_only):
				var clash := "Required" if is_required else ("Optional" if is_optional else ("ReadOnly" if is_read_only else "WriteOnly"))
				_plan_error(current, "Serialize: %s.%s is @Transient and @%s." % [_script_name(current), prop_name, clash])
				bad = true
				break
			if prop_name == "_type":
				_plan_error(current, "Serialize: %s._type cannot be a field." % _script_name(current))
				bad = true
				break
			var key := prop_name
			if has_mark:
				var custom := String((marked as Object).get("value")).strip_edges()
				if custom != "":
					key = custom
			if is_transient:
				transient[key] = true
				continue
			if not mode and not has_mark:
				if is_required or is_optional or is_read_only or is_write_only:
					var unused := "Required" if is_required else ("Optional" if is_optional else ("ReadOnly" if is_read_only else "WriteOnly"))
					_plan_error(current, "Serialize: %s.%s @%s needs @Serialize." % [_script_name(current), prop_name, unused])
					bad = true
					break
				continue
			if key == "_type":
				_plan_error(current, "Serialize: %s.%s cannot use the key _type." % [_script_name(current), prop_name])
				bad = true
				break
			if seen_keys.has(key):
				_plan_error(current, "Serialize: %s uses the key %s twice." % [_script_name(script), key])
				bad = true
				break
			seen_keys[key] = true
			fields.append({
				"name": prop_name,
				"key": key,
				"type": int(info.get("type", TYPE_NIL)),
				"required": is_required,
				"read_only": is_read_only,
				"write_only": is_write_only,
			})
		current = current.get_base_script()
	if bad or _failed:
		_plan_bad[cache_key] = true
		return {}
	var before_write := _collect_hooks(script, OnBeforeSerialization, "OnBeforeSerialization")
	var after_write := _collect_hooks(script, OnAfterSerialization, "OnAfterSerialization")
	var before_read := _collect_hooks(script, OnBeforeDeserialization, "OnBeforeDeserialization")
	var after_read := _collect_hooks(script, OnAfterDeserialization, "OnAfterDeserialization")
	if _failed:
		_plan_bad[cache_key] = true
		return {}
	var plan := {
		"fields": fields,
		"transient": transient,
		"before_write": before_write,
		"after_write": after_write,
		"before_read": before_read,
		"after_read": after_read,
	}
	_plans[cache_key] = plan
	return plan


func _collect_hooks(root: GDScript, kind: GDScript, label: String) -> Array:
	var names: Array = []
	var current := root
	# Keep walking after a bad mark so every illegal hook is reported.
	while current != null:
		var bucket := {"root": root, "script": current, "label": label, "names": []}
		AnnotationUtils.for_each_annotation_initialized(kind, current, _take_hook.bind(bucket))
		for method_name in bucket["names"]:
			names.append(method_name)
		current = current.get_base_script()
	return names


func _take_hook(_annotation: Object, target: Object, bucket: Dictionary) -> void:
	var root := bucket["root"] as GDScript
	var script := bucket["script"] as GDScript
	var label := String(bucket["label"])
	if not (target is FunctionInfo):
		_plan_error(root, "Serialize: @%s on %s belongs on a method." % [label, _script_name(script)])
		return
	var info := target as FunctionInfo
	if info.is_static:
		_plan_error(root, "Serialize: %s.%s @%s cannot be static." % [_script_name(script), info.name, label])
		return
	if _method_argc(script, StringName(String(info.name))) != 0:
		_plan_error(root, "Serialize: %s.%s @%s must take nothing." % [_script_name(script), info.name, label])
		return
	(bucket["names"] as Array).append(String(info.name))


func _method_argc(script: GDScript, method: StringName) -> int:
	for info in script.get_script_method_list():
		if StringName(info.get("name", "")) != method:
			continue
		return (info.get("args", []) as Array).size()
	return -1


func _run_hooks(instance: Object, methods: Array) -> void:
	if instance == null or methods.is_empty():
		return
	for method_name in methods:
		var result: Variant = instance.call(StringName(String(method_name)))
		if result is Object and String((result as Object).get_class()) == "GDScriptFunctionState":
			_error("Serialize: %s.%s cannot await." % [_owner_name(instance), String(method_name)])
			return


func _own_properties(script: GDScript) -> Array:
	var counts := {}
	var infos: Array = []
	for info in script.get_script_property_list():
		if not _is_script_variable(info):
			continue
		var prop_name := String(info.get("name", ""))
		counts[prop_name] = int(counts.get(prop_name, 0)) + 1
		infos.append(info)
	var base_counts := {}
	var base := script.get_base_script()
	if base != null:
		for info in base.get_script_property_list():
			if not _is_script_variable(info):
				continue
			var prop_name := String(info.get("name", ""))
			base_counts[prop_name] = int(base_counts.get(prop_name, 0)) + 1
	var own: Array = []
	var emitted := {}
	for info in infos:
		var prop_name := String(info.get("name", ""))
		if emitted.has(prop_name):
			continue
		if int(counts.get(prop_name, 0)) - int(base_counts.get(prop_name, 0)) <= 0:
			continue
		emitted[prop_name] = true
		own.append(info)
	return own


func _is_script_variable(info: Dictionary) -> bool:
	return (int(info.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0


func _class_mode(script: GDScript) -> bool:
	if _class_mode_cache.has(script):
		return bool(_class_mode_cache[script])
	var current := script
	var found := false
	while current != null:
		if AnnotationUtils.has_annotation(current, Serialize):
			found = true
			break
		current = current.get_base_script()
	_class_mode_cache[script] = found
	return found


func _check_marks(script: GDScript) -> void:
	if _mark_seen.has(script):
		if bool(_mark_bad.get(script, false)):
			_failed = true
		return
	var failed_before := _failed
	AnnotationUtils.for_each_annotation_initialized(Serialize, script, _on_serialize.bind(script))
	AnnotationUtils.for_each_annotation_initialized(Transient, script, _on_transient.bind(script))
	AnnotationUtils.for_each_annotation_initialized(Required, script, _on_field_mark.bind(script, "Required"))
	AnnotationUtils.for_each_annotation_initialized(Optional, script, _on_field_mark.bind(script, "Optional"))
	AnnotationUtils.for_each_annotation_initialized(ReadOnly, script, _on_field_mark.bind(script, "ReadOnly"))
	AnnotationUtils.for_each_annotation_initialized(WriteOnly, script, _on_field_mark.bind(script, "WriteOnly"))
	_mark_seen[script] = true
	_mark_bad[script] = _failed and not failed_before


func _on_serialize(annotation: Object, target: Object, script: GDScript) -> void:
	if target is ScriptInfo:
		if String(annotation.get("value")).strip_edges() != "":
			_plan_error(script, "Serialize: a class mark on %s does not take a name." % _script_name(script))
		return
	if target is VariableInfo:
		return
	_plan_error(script, "Serialize: @Serialize on %s belongs on a class or a field." % _script_name(script))


func _on_transient(_annotation: Object, target: Object, script: GDScript) -> void:
	if target is VariableInfo:
		return
	_plan_error(script, "Serialize: @Transient on %s belongs on a field." % _script_name(script))


func _on_field_mark(_annotation: Object, target: Object, script: GDScript, label: String) -> void:
	if target is VariableInfo:
		return
	_plan_error(script, "Serialize: @%s on %s belongs on a field." % [label, _script_name(script)])


func _plan_error(script: GDScript, message: String) -> void:
	var key := script.get_instance_id()
	_failed = true
	if _plan_reported.has(key):
		return
	_plan_reported[key] = true
	push_error(message)


func _script_by_name(type_name: String) -> GDScript:
	if _scripts.has(type_name):
		return _scripts[type_name] as GDScript
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) != type_name:
			continue
		var loaded: Variant = load(String(entry.get("path", "")))
		if loaded is GDScript:
			_scripts[type_name] = loaded
			return loaded
		return null
	return null


func _script_accepts(actual: GDScript, expected: GDScript) -> bool:
	var current := actual
	while current != null:
		if current == expected:
			return true
		current = current.get_base_script()
	return false


func _is_value_type(type_name: String) -> bool:
	return _LEAF_NAMES.has(type_name)


func _script_name(script: GDScript) -> String:
	if script == null:
		return "?"
	var global_name := String(script.get_global_name())
	if global_name.is_empty():
		return script.resource_path.get_file()
	return global_name


func _advise_field(owner: Object, property: StringName, value: Variant) -> Variant:
	var next: Variant = value
	for step in _steps():
		var result: Variant = (step as FieldAdvisor).advise(owner, property, next)
		if not (result is Dictionary):
			_error("Serialize: %s.%s advisor %s returned no result." % [_owner_name(owner), String(property), _advisor_name(step)])
			return null
		var outcome: Dictionary = result
		if not bool(outcome.get("ok", false)):
			var message := String(outcome.get("message", "")).strip_edges()
			if message.is_empty():
				message = "rejected by %s" % _advisor_name(step)
			_error("Serialize: %s.%s %s." % [_owner_name(owner), String(property), message])
			return null
		next = outcome.get("value", next)
	return next


func _steps() -> Array:
	if _advisors_ready:
		return _advisor_list
	_advisors_ready = true
	var bases := {}
	var entries: Array = ProjectSettings.get_global_class_list()
	for entry in entries:
		bases[String(entry.get("class", ""))] = String(entry.get("base", ""))
	for entry in entries:
		var listed := String(entry.get("class", ""))
		if listed.is_empty() or listed == "FieldAdvisor":
			continue
		if String(entry.get("language", "")) != "GDScript":
			continue
		if not _is_advisor(listed, bases):
			continue
		var script := load(String(entry.get("path", ""))) as GDScript
		if script == null:
			continue
		var advisor: Object = script.new()
		if advisor is FieldAdvisor:
			_advisor_list.append(advisor)
	_advisor_list.sort_custom(func(a: Object, b: Object) -> bool: return _step_before(a, b))
	return _advisor_list


func _is_advisor(listed: String, bases: Dictionary) -> bool:
	var seen := {}
	var current := String(bases.get(listed, ""))
	while not current.is_empty() and not seen.has(current):
		if current == "FieldAdvisor":
			return true
		seen[current] = true
		current = String(bases.get(current, ""))
	return false


func _step_before(a: Object, b: Object) -> bool:
	var left := int(a.get("order")) if a is FieldAdvisor else 0
	var right := int(b.get("order")) if b is FieldAdvisor else 0
	if left == right:
		return _advisor_name(a) < _advisor_name(b)
	return left < right


func _advisor_name(step: Object) -> String:
	var script := step.get_script() as GDScript
	while script != null:
		var global_name := script.get_global_name()
		if global_name != &"":
			return String(global_name)
		script = script.get_base_script()
	return "FieldAdvisor"


func _owner_name(owner: Object) -> String:
	if owner == null:
		return "?"
	var script := owner.get_script() as GDScript
	if script != null:
		return _script_name(script)
	return owner.get_class()


func _error(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
