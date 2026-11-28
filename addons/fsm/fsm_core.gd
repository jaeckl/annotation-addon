class_name FsmCore
extends RefCounted

## Shared arm / goto / try_goto / tick for Fsm and FsmObject. The owner keeps
## the public state field; this object keeps the annotation tables.

var _owner: Object
var _armed := false
var _open := true
var _edges: Dictionary = {}
var _whiles: Dictionary = {}
var _enters: Dictionary = {}
var _exits: Dictionary = {}


func bind(owner: Object) -> void:
	if owner == null:
		return
	_owner = owner
	if _armed:
		return
	var script := owner.get_script() as GDScript
	if script == null:
		push_error("FSM: machine has no script.")
		return
	if not _scan(script):
		return
	_armed = true


func goto(next: Variant) -> void:
	bind(_owner)
	if not _armed or _owner == null:
		return
	if next == _owner.get("state"):
		return
	_run_hooks(_exits, _owner.get("state"))
	_owner.set("state", next)
	_run_hooks(_enters, next)


func try_goto(next: Variant) -> bool:
	bind(_owner)
	if not _armed or _owner == null:
		return false
	if next == _owner.get("state"):
		return true
	if not _open and not _allowed(_owner.get("state"), next):
		push_error("FSM: %s cannot try_goto from %s to %s." % [_owner_name(), str(_owner.get("state")), str(next)])
		return false
	goto(next)
	return true


func tick(delta: float) -> void:
	bind(_owner)
	if not _armed or _owner == null:
		return
	var methods: Variant = _whiles.get(_owner.get("state"), [])
	if not (methods is Array):
		return
	for method in methods:
		var value: Variant = _owner.call(method, delta)
		if value is Object and (value as Object).get_class() == "GDScriptFunctionState":
			push_error("FSM: %s.%s cannot await." % [_owner_name(), String(method)])


func _scan(script: GDScript) -> bool:
	_edges.clear()
	_whiles.clear()
	_enters.clear()
	_exits.clear()
	_open = true
	var ok := true
	var current := script
	while current != null:
		if not _take_machine(current):
			ok = false
		var bucket := {"script": current, "ok": true}
		AnnotationUtils.for_each_annotation_initialized(While, current, _take_while.bind(bucket))
		AnnotationUtils.for_each_annotation_initialized(OnEnter, current, _take_enter.bind(bucket))
		AnnotationUtils.for_each_annotation_initialized(OnExit, current, _take_exit.bind(bucket))
		if not bool(bucket["ok"]):
			ok = false
		current = current.get_base_script()
	return ok


func _take_machine(script: GDScript) -> bool:
	if not AnnotationUtils.has_annotation(script, StateMachine):
		return true
	var mark: Variant = AnnotationUtils.get_annotation_initialized(script, StateMachine)
	if not (mark is Object):
		return true
	var table: Variant = mark.get("transitions")
	if table == null:
		return true
	if not (table is Dictionary):
		push_error("FSM: %s @StateMachine transitions must be a Dictionary." % _script_name(script))
		return false
	var edges := table as Dictionary
	if edges.is_empty():
		return true
	_open = false
	for from in edges.keys():
		var dests: Variant = edges[from]
		if not (dests is Array):
			push_error("FSM: %s transition for %s must be an Array." % [_script_name(script), str(from)])
			return false
		var allowed: Array = _edges.get(from, [])
		for dest in dests:
			if not allowed.has(dest):
				allowed.append(dest)
		_edges[from] = allowed
	return true


func _take_while(annotation: Object, target: Object, bucket: Dictionary) -> void:
	_take_method(annotation, target, bucket, _whiles, "While", true)


func _take_enter(annotation: Object, target: Object, bucket: Dictionary) -> void:
	_take_method(annotation, target, bucket, _enters, "OnEnter", false)


func _take_exit(annotation: Object, target: Object, bucket: Dictionary) -> void:
	_take_method(annotation, target, bucket, _exits, "OnExit", false)


func _take_method(annotation: Object, target: Object, bucket: Dictionary, table: Dictionary, label: String, wants_delta: bool) -> void:
	var script := bucket["script"] as GDScript
	if not (target is FunctionInfo):
		push_error("FSM: @%s on %s belongs on a method." % [label, _script_name(script)])
		bucket["ok"] = false
		return
	var info := target as FunctionInfo
	if info.is_static:
		push_error("FSM: %s.%s is static and cannot be @%s." % [_script_name(script), info.name, label])
		bucket["ok"] = false
		return
	if not _arity_ok(script, info.name, wants_delta):
		if wants_delta:
			push_error("FSM: %s.%s must take one float." % [_script_name(script), info.name])
		else:
			push_error("FSM: %s.%s must take no arguments." % [_script_name(script), info.name])
		bucket["ok"] = false
		return
	var state: Variant = annotation.get("value") if annotation != null else null
	var methods: Array = table.get(state, [])
	var method := StringName(info.name)
	if not methods.has(method):
		methods.append(method)
	table[state] = methods


func _arity_ok(script: GDScript, method: StringName, wants_delta: bool) -> bool:
	for entry in script.get_script_method_list():
		if StringName(String(entry.get("name", ""))) != method:
			continue
		var args: Array = entry.get("args", [])
		if wants_delta:
			if args.size() != 1:
				return false
			return int(args[0].get("type", TYPE_NIL)) == TYPE_FLOAT
		return args.is_empty()
	return false


func _allowed(from: Variant, to: Variant) -> bool:
	var dests: Variant = _edges.get(from, [])
	return dests is Array and (dests as Array).has(to)


func _run_hooks(table: Dictionary, state: Variant) -> void:
	var methods: Variant = table.get(state, [])
	if not (methods is Array):
		return
	for method in methods:
		var value: Variant = _owner.call(method)
		if value is Object and (value as Object).get_class() == "GDScriptFunctionState":
			push_error("FSM: %s.%s cannot await." % [_owner_name(), String(method)])


func _owner_name() -> String:
	if _owner == null:
		return "?"
	var script := _owner.get_script() as GDScript
	if script != null:
		var label := String(script.get_global_name())
		if not label.is_empty():
			return label
	return _owner.get_class()


func _script_name(script: GDScript) -> String:
	if script == null:
		return "?"
	var label := String(script.get_global_name())
	if not label.is_empty():
		return label
	return script.resource_path.get_file()
