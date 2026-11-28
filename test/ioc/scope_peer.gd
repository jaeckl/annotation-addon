@ConditionalOnProperty(key="ioc/scene_scope_fixtures", having_value="yes")
@SceneScoped
@Component
class_name ScopePeer
extends RefCounted

@Inject var room: ScopeRoom
