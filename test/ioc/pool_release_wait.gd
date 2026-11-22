@Pooled
@Component
class_name PoolReleaseWait
extends Node2D


@OnRelease
func linger() -> void:
	await get_tree().process_frame
