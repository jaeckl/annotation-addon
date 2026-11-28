@ConditionalOnProperty(key="ioc/scene_scope_fixtures", having_value="yes")
@SceneScoped
@Component
class_name ScopeRoom
extends RefCounted

var ready_hits := 0
var destroy_hits := 0


@Ready
func boot() -> void:
	ready_hits += 1


@OnDestroy
func down() -> void:
	destroy_hits += 1
