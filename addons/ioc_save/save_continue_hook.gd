@Component
class_name SaveContinueHook
extends ContainerHook

## When SaveSlots.pending_slot is set, loads that slot as the scene opens —
## before @SceneScoped products are built — so injects see the restored run.

@Inject var slots: SaveSlots


func before_scene_open(root: Node) -> void:
	if slots == null:
		return
	if slots.pending_slot.strip_edges().is_empty():
		return
	if not slots.apply_pending_for_scene(root):
		push_error("Save: pending slot could not be applied for scene %s." % root.name)
