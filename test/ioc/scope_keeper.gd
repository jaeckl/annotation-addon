@ConditionalOnProperty(key="ioc/scene_scope_fixtures", having_value="yes")
@Lazy
@Component
class_name ScopeKeeper
extends RefCounted

## App product that must not inject a scene product.
@Inject var room: ScopeRoom
