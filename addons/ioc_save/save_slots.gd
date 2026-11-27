class_name SaveSlots
extends RefCounted

## Writes and loads @Persist run products into one zip per slot under root.
## Default root is user://saves. Slot names are [A-Za-z0-9_-]. SaveConfig
## publishes this product unless a game factory already did.

const HEADER := "header"
const SLOT_PATTERN := "^[A-Za-z0-9_-]+$"

var root: String = "user://saves"
var body_parent: Node

@Inject var mapper: Mapper
@Inject var runs: Runs
@Inject var pools: InstancePools
@Inject var hook: PersistHook


func write(slot: String) -> bool:
	if not _slot_ok(slot):
		return false
	if not runs.is_open():
		push_error("Save: no run is open.")
		return false
	var products := _built_persist()
	if products.is_empty() and _failed_duplicate:
		return false
	if not _ensure_root():
		return false
	var path := _path(slot)
	var sink := FileSink.new()
	sink.path = path
	var bundle := ZipBundle.new()
	bundle.sink = sink
	var names: Array = []
	for product in products:
		var script := _product_script(product)
		var label := String(script.get_global_name())
		names.append(label)
		var bytes := mapper.write(product)
		if bytes.is_empty():
			push_error("Save: %s could not be written." % label)
			return false
		bundle.add(label, bytes)
	var header := mapper.codec.write({"products": names})
	if header.is_empty():
		push_error("Save: the header could not be written.")
		return false
	bundle.add(HEADER, header)
	bundle.finish()
	return FileAccess.file_exists(path)


func load(slot: String) -> bool:
	if not _slot_ok(slot):
		return false
	var path := _path(slot)
	if not FileAccess.file_exists(path):
		push_error("Save: slot %s is missing." % slot)
		return false
	var packed := FileAccess.get_file_as_bytes(path)
	var entries := ZipBundle.read_entries(packed)
	if entries.is_empty() or not entries.has(HEADER):
		push_error("Save: slot %s has no header." % slot)
		return false
	var header: Variant = mapper.codec.read(entries[HEADER])
	if typeof(header) != TYPE_DICTIONARY or not (header as Dictionary).has("products"):
		push_error("Save: slot %s has a bad header." % slot)
		return false
	var names: Array = (header as Dictionary)["products"]
	var pending := {}
	for item in names:
		var label := String(item)
		if label.is_empty() or not entries.has(label):
			push_error("Save: slot %s is missing %s." % [slot, label])
			return false
		var script := _script_by_name(label)
		if script == null:
			push_error("Save: %s is not a class." % label)
			return false
		if not mapper.readable(script, entries[label]):
			push_error("Save: slot %s could not be read." % slot)
			return false
		pending[label] = entries[label]
	if runs.is_open() and not runs.end():
		return false
	if pools.container != null:
		pools.container.release_pool_holds(_release_root())
	if not runs.start():
		return false
	hook.arm(pending, body_parent)
	for label in names:
		var script := _script_by_name(String(label))
		if script == null:
			hook.clear()
			return false
		var instance := runs.resolve(script)
		if instance == null:
			hook.clear()
			push_error("Save: %s could not be built." % label)
			return false
	hook.clear()
	return true


func has(slot: String) -> bool:
	if not _slot_ok(slot, false):
		return false
	return FileAccess.file_exists(_path(slot))


func list() -> PackedStringArray:
	var found := PackedStringArray()
	if not DirAccess.dir_exists_absolute(root):
		return found
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".zip"):
			var slot := name.trim_suffix(".zip")
			if _name_ok(slot):
				found.append(slot)
		name = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found


func erase(slot: String) -> bool:
	if not _slot_ok(slot):
		return false
	var path := _path(slot)
	if not FileAccess.file_exists(path):
		push_error("Save: slot %s is missing." % slot)
		return false
	var err := DirAccess.remove_absolute(path)
	if err != OK:
		push_error("Save: slot %s could not be erased." % slot)
		return false
	return true


var _failed_duplicate := false


func _built_persist() -> Array:
	_failed_duplicate = false
	var found: Array = []
	var seen := {}
	if runs.container == null:
		return found
	for instance in runs.container.built_run():
		var script := _product_script(instance)
		if script == null or not _is_persist(script):
			continue
		var label := String(script.get_global_name())
		if label.is_empty():
			push_error("Save: a persist product needs a class_name.")
			_failed_duplicate = true
			return []
		if seen.has(label):
			push_error("Save: two products of class %s." % label)
			_failed_duplicate = true
			return []
		seen[label] = true
		found.append(instance)
	return found


func _release_root() -> Node:
	if _in_scene(body_parent):
		return body_parent
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene


func _in_scene(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var current := node
	while current != null:
		if String(current.scene_file_path) != "":
			return true
		current = current.get_parent()
	return false


func _slot_ok(slot: String, report: bool = true) -> bool:
	if _name_ok(slot):
		return true
	if report:
		push_error("Save: slot name %s is invalid." % slot)
	return false


func _name_ok(slot: String) -> bool:
	if slot.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile(SLOT_PATTERN)
	return regex.search(slot) != null and regex.search(slot).get_string() == slot


func _path(slot: String) -> String:
	return root.path_join("%s.zip" % slot)


func _ensure_root() -> bool:
	if DirAccess.dir_exists_absolute(root):
		return true
	var err := DirAccess.make_dir_recursive_absolute(root)
	if err != OK:
		push_error("Save: could not create %s." % root)
		return false
	return true


func _product_script(instance: Object) -> GDScript:
	var script := instance.get_script() as GDScript
	while script != null:
		if not String(script.get_global_name()).is_empty():
			return script
		script = script.get_base_script()
	return instance.get_script() as GDScript


func _is_persist(script: GDScript) -> bool:
	var current := script
	while current != null:
		if AnnotationUtils.has_annotation(current, Persist):
			return true
		current = current.get_base_script()
	return false


func _script_by_name(type_name: String) -> GDScript:
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) != type_name:
			continue
		var loaded: Variant = load(String(entry.get("path", "")))
		if loaded is GDScript:
			return loaded as GDScript
		return null
	return null
