@Pooled
@Component
class_name PoolReset
extends RefCounted

var token := 0
var clears := 0


@OnRelease
func clear() -> void:
	token = 0
	clears += 1
