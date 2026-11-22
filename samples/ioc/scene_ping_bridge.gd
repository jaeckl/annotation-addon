@ConditionalOnMissingNode(type_name="AbsentMarker")
@Component
class_name ScenePingBridge
extends RefCounted

var heard: int = 0
var pong: int = 0


@EventListener
func on_ping(_event: ScenePing) -> ScenePong:
	heard += 1
	return ScenePong.new()


@EventListener
func on_pong(_event: ScenePong) -> void:
	pong += 1
